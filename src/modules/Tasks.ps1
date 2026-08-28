function Read-JsonFile([string]$path) {
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-Tasks {
    $data = Read-JsonFile $tasksPath
    if ($null -eq $data.tasks) { return @() }
    @($data.tasks)
}



function Read-IconCatalog {
    if (-not (Test-Path $iconsPath)) {
        return [pscustomobject]@{ icons = @() }
    }

    $data = Read-JsonFile $iconsPath

    if ($null -eq $data.icons) {
        $data | Add-Member -NotePropertyName icons -NotePropertyValue @()
    }

    $data
}

function Get-IconEntry([string]$id) {
    $catalog = Read-IconCatalog
    @($catalog.icons | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
}

function Get-RandomTaskIconId {
    $icons = @(
        (Read-IconCatalog).icons | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.id) -and
            -not [string]::IsNullOrWhiteSpace([string]$_.file) -and
            (Test-Path (Join-Path $base ([string]$_.file)))
        }
    )
    if ($icons.Count -eq 0) { return Get-DefaultTaskIconId }
    [string]($icons | Get-Random).id
}

function Get-RelativeAssetPath([string]$path) {
    ([System.IO.Path]::GetFullPath($path).Substring([System.IO.Path]::GetFullPath($base).Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/')
}

function Get-BadgeAssets([bool]$labels = $false) {
    if (-not (Test-Path $backgroundsDir)) { return @() }
    @(
        Get-ChildItem -LiteralPath $backgroundsDir -Recurse -File -Filter '*.png' |
            Where-Object {
                $relative = Get-RelativeAssetPath $_.FullName
                $isLabel = $relative -match '(?i)/badges/label/'
                if ($labels) { $isLabel } else { $relative -match '(?i)/badges/' -and -not $isLabel }
            } |
            Sort-Object FullName |
            ForEach-Object { Get-RelativeAssetPath $_.FullName }
    )
}

function Get-DominantIconColor([string]$iconId) {
    $entry = Get-IconEntry $iconId
    if ($null -eq $entry) { return '#FF8B4A58' }
    if (Test-Path $iconColorsPath) {
        $colorCatalog = Read-JsonFile $iconColorsPath
        $iconFileName = [System.IO.Path]::GetFileName([string]$entry.file)
        $configured = @($colorCatalog.icons | Where-Object { [string]$_.id -eq $iconId -or [string]$_.file -eq $iconFileName }) | Select-Object -First 1
        if ($null -ne $configured -and [string]$configured.color -match '^#[0-9A-Fa-f]{6}$') {
            return '#FF' + ([string]$configured.color).Substring(1).ToUpperInvariant()
        }
    }
    $path = Join-Path $base ([string]$entry.file)
    if (-not (Test-Path $path)) { return '#FF8B4A58' }
    $bitmap = [System.Drawing.Bitmap]::new($path)
    try {
        $bins = @{}
        $step = [Math]::Max(1, [Math]::Floor([Math]::Min($bitmap.Width, $bitmap.Height) / 32))
        for ($y = 0; $y -lt $bitmap.Height; $y += $step) {
            for ($x = 0; $x -lt $bitmap.Width; $x += $step) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -lt 80) { continue }
                $max = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
                $min = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
                if ($max -lt 35 -or $min -gt 235) { continue }
                $saturation = if ($max -eq 0) { 0.0 } else { ($max - $min) / [double]$max }
                $key = '{0},{1},{2}' -f ([Math]::Floor($pixel.R / 32)), ([Math]::Floor($pixel.G / 32)), ([Math]::Floor($pixel.B / 32))
                if (-not $bins.ContainsKey($key)) { $bins[$key] = [pscustomobject]@{ score = 0.0; r = 0.0; g = 0.0; b = 0.0; weight = 0.0 } }
                $weight = 0.25 + ($saturation * 1.75)
                $bin = $bins[$key]
                $bin.score += $weight
                $bin.r += $pixel.R * $weight
                $bin.g += $pixel.G * $weight
                $bin.b += $pixel.B * $weight
                $bin.weight += $weight
            }
        }
        $winner = @($bins.Values | Sort-Object score -Descending | Select-Object -First 1)
        if ($winner.Count -eq 0) { return '#FF8B4A58' }
        $color = $winner[0]
        '#FF{0:X2}{1:X2}{2:X2}' -f [int]($color.r / $color.weight), [int]($color.g / $color.weight), [int]($color.b / $color.weight)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Add-TaskBadgeMetadata($task, [bool]$randomize) {
    $badges = @(Get-BadgeAssets)
    $labels = @(Get-BadgeAssets $true)
    if ($badges.Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$task.badge)) {
        $index = if ($randomize) { Get-Random -Minimum 0 -Maximum $badges.Count } else { [Math]::Abs(([string]$task.id).GetHashCode()) % $badges.Count }
        $task | Add-Member -NotePropertyName badge -NotePropertyValue ([string]$badges[$index]) -Force
    }
    if ($labels.Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$task.label)) {
        $index = if ($randomize) { Get-Random -Minimum 0 -Maximum $labels.Count } else { [Math]::Abs((([string]$task.id) + 'label').GetHashCode()) % $labels.Count }
        $task | Add-Member -NotePropertyName label -NotePropertyValue ([string]$labels[$index]) -Force
    }
    $task | Add-Member -NotePropertyName badgeColor -NotePropertyValue (Get-DominantIconColor ([string]$task.icon)) -Force
}

function Initialize-LegacyTaskBadges {
    $changed = $false
    foreach ($task in @($script:tasks)) {
        if ([string]::IsNullOrWhiteSpace([string]$task.badge) -or [string]::IsNullOrWhiteSpace([string]$task.badgeColor)) {
            Add-TaskBadgeMetadata $task $false
            $changed = $true
        }
        $configuredColor = Get-DominantIconColor ([string]$task.icon)
        if ([string]$task.badgeColor -ne $configuredColor) {
            $task | Add-Member -NotePropertyName badgeColor -NotePropertyValue $configuredColor -Force
            $changed = $true
        }
    }
    if ($changed) { Save-Tasks }
}

function New-TaskBadgeVisual($task, [double]$size) {
    $grid = New-Object System.Windows.Controls.Grid
    $badgePath = [string]$task.badge
    if (-not [string]::IsNullOrWhiteSpace($badgePath) -and (Test-Path (Join-Path $base $badgePath))) {
        $mask = New-Object System.Windows.Media.ImageBrush
        $mask.ImageSource = (New-ImageControl $badgePath $size).Source
        $mask.Stretch = 'Uniform'
        $colorLayer = New-Object System.Windows.Controls.Border
        $colorLayer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$task.badgeColor)
        $colorLayer.OpacityMask = $mask
        $colorLayer.Margin = 2
        $grid.Children.Add($colorLayer) | Out-Null
        $texture = New-ImageControl $badgePath $size
        $texture.Opacity = 0.58
        $grid.Children.Add($texture) | Out-Null
    }
    $labelPath = [string]$task.label
    if (-not [string]::IsNullOrWhiteSpace($labelPath) -and (Test-Path (Join-Path $base $labelPath))) {
        $label = New-ImageControl $labelPath ($size * 0.48)
        $grid.Children.Add($label) | Out-Null
    }
    else {
        $symbol = New-Object System.Windows.Controls.TextBlock
        $symbol.Text = if ([string]::IsNullOrWhiteSpace([string]$task.title)) { '?' } else { ([string]$task.title).Substring(0, 1).ToUpperInvariant() }
        $symbol.Foreground = [System.Windows.Media.Brushes]::White
        $symbol.FontWeight = 'Bold'
        $symbol.FontSize = [Math]::Max(12, $size * 0.32)
        $symbol.HorizontalAlignment = 'Center'
        $symbol.VerticalAlignment = 'Center'
        $symbol.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect
        $grid.Children.Add($symbol) | Out-Null
    }
    $grid
}

function New-ImageControl([string]$relativePath, [double]$size) {
    $image = New-Object System.Windows.Controls.Image
    $image.Width = $size
    $image.Height = $size
    $image.Stretch = [System.Windows.Media.Stretch]::Uniform
    $image.IsHitTestVisible = $false

    $path = Join-Path $base $relativePath

    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $image.Source = $bitmap
    }

    $image
}

function Populate-IconGrid($panel, [string]$selectedId, [int]$columns, [string]$target) {
    if ($null -eq $panel) { return }
    $panel.Children.Clear()
    $columns = [Math]::Max(1, [Math]::Min(8, $columns))
    $panelWidth = 320.0
    $cellSize = [Math]::Max(34.0, [Math]::Floor($panelWidth / [double]$columns) - 6.0)
    $imageSize = [Math]::Max(26.0, $cellSize - 10.0)
    $panel.Width = $panelWidth

    $catalog = Read-IconCatalog

    foreach ($entry in @($catalog.icons)) {
        $button = New-Object System.Windows.Controls.Button
        $button.Tag = [string]$entry.id
        $button.Width = $cellSize
        $button.Height = $cellSize
        $button.Margin = '3'
        $button.Padding = '3'
        $button.ToolTip = [string]$entry.name
        $button.Content = New-ImageControl ([string]$entry.file) $imageSize

        if ([string]$entry.id -eq $selectedId) {
            $button.BorderThickness = 3
            $button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF2ECC71')
        }

        $mode = $target

        $button.Add_Click({
            param($s, $e)

            $id = [string]$s.Tag

            switch ($mode) {
                'add' {
                    $script:addSelectedIcon = $id
                    Populate-IconGrid $script:addIconGrid $script:addSelectedIcon ([int]$script:config.icons.columns) 'add'
                }
                'detail' {
                    $script:detailSelectedIcon = $id
                    $entry = Get-IconEntry $id
                    if ($null -ne $entry -and $null -ne $script:detailCurrentIcon) { $script:detailCurrentIcon.Child = New-ImageControl ([string]$entry.file) 62 }
                    if ($null -ne $script:detailChooser) { $script:detailChooser.Visibility = 'Collapsed' }
                }
                'preview' {
                }
            }
        }.GetNewClosure())

        $panel.Children.Add($button) | Out-Null
    }
}


function Get-DefaultTaskIconId {
    $catalog = Read-IconCatalog
    $icons = @($catalog.icons)

    if ($icons.Count -eq 0) { return $null }

    $preferred = @($icons | Where-Object { [string]$_.id -eq 'icon-01' }) | Select-Object -First 1
    if ($null -ne $preferred) { return [string]$preferred.id }

    return [string]$icons[0].id
}

function Refresh-AddIconSelection {
    $entry = Get-IconEntry ([string]$script:addSelectedIcon)
    if ($null -ne $script:addSelectedIconHost) {
        $script:addSelectedIconHost.Child = if ($null -eq $entry) { $null } else { New-ImageControl ([string]$entry.file) 64 }
    }

    if ($null -eq $script:addIconGrid) { return }

    foreach ($child in @($script:addIconGrid.Children)) {
        if (-not ($child -is [System.Windows.Controls.Button])) { continue }

        if ([string]$child.Tag -eq [string]$script:addSelectedIcon) {
            $child.BorderThickness = 3
            $child.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF2ECC71')
        }
        else {
            $child.BorderThickness = 1
            $child.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
        }
    }
}

function Populate-AddIconGrid {
    if ($null -eq $script:addIconGrid) { return }

    $script:addIconGrid.Children.Clear()

    $catalog = Read-IconCatalog
    $icons = @($catalog.icons)

    if ($icons.Count -eq 0) { return }

    $columns = [Math]::Max(1, [Math]::Min(8, [int]$script:config.icons.columns))
    $panelWidth = 210.0
    $cellSize = [Math]::Max(34.0, [Math]::Floor($panelWidth / [double]$columns) - 6.0)
    $imageSize = [Math]::Max(26.0, $cellSize - 10.0)

    $script:addIconGrid.Width = $panelWidth

    foreach ($entry in $icons) {
        $button = New-Object System.Windows.Controls.Button
        $button.Tag = [string]$entry.id
        $button.Width = $cellSize
        $button.Height = $cellSize
        $button.Margin = '3'
        $button.Padding = '3'
        $button.ToolTip = [string]$entry.name
        $button.Content = New-ImageControl ([string]$entry.file) $imageSize

        $button.Add_Click({
            param($sender, $eventArgs)

            $iconId = [string]$sender.Tag
            if ([string]::IsNullOrWhiteSpace($iconId)) { return }
            if ($null -eq (Get-IconEntry $iconId)) { return }

            $script:addSelectedIcon = $iconId
            Refresh-AddIconSelection
            $eventArgs.Handled = $true
        })

        $script:addIconGrid.Children.Add($button) | Out-Null
    }

    Refresh-AddIconSelection
}

function Open-AddTaskPanel {
    if ($script:editMode) { return }
    if ($null -eq $script:addPanel) { return }
    if ($null -eq $script:addTitleBox) { return }
    if ($null -eq $script:addDescriptionBox) { return }

    $script:addTitleBox.Text = ''
    $script:addDescriptionBox.Text = ''
    $script:addSelectedIcon = Get-RandomTaskIconId
    $script:pendingNewTask = $null
    $script:addBody.Visibility = 'Visible'
    $script:addSavingPanel.Visibility = 'Collapsed'
    $script:addCreateButton.IsEnabled = $true
    $script:addCloseButton.IsEnabled = $true

    Populate-AddIconGrid
    Refresh-AddIconSelection

    $script:addPanel.Visibility = 'Visible'
    if ($null -ne $script:addWindow) {
        $script:addWindow.Show()
        Center-WindowOnPrimaryScreen $script:addWindow
        $script:addWindow.Activate() | Out-Null
    }
    $script:addTitleBox.Focus() | Out-Null
}

function Close-AddTaskPanel {
    if ($null -ne $script:addFailureTimer) {
        $script:addFailureTimer.Stop()
        $script:addFailureTimer = $null
    }
    $script:pendingNewTask = $null
    if ($null -ne $script:addPanel) {
        $script:addPanel.Visibility = 'Collapsed'
    }
    if ($null -ne $script:addWindow -and $script:addWindow.IsVisible) {
        $script:addWindow.Hide()
    }
}

function Show-AddFailure([string]$message) {
    $script:addSavingTitleText.Text = 'COULD NOT ADD ITEM'
    $script:addSavingStatusText.Text = $message
    $script:addFailureTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:addFailureTimer.Interval = [TimeSpan]::FromMilliseconds(2600)
    $script:addFailureTimer.Add_Tick({
        $script:addFailureTimer.Stop()
        $script:addFailureTimer = $null
        Close-AddTaskPanel
    })
    $script:addFailureTimer.Start()
}

function Commit-NewTask($newTask) {
    try {
        $script:tasks = @($script:tasks) + @($newTask)
        Save-Tasks
        Render-Tasks
        Close-AddTaskPanel
        Request-PositionCacheRefill 2100
    }
    catch {
        $failedTaskId = [string]$newTask.id
        $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $failedTaskId })
        Show-AddFailure 'The item could not be added. Please try again.'
    }
}

function Complete-NewTask {
    $newTask = $script:pendingNewTask
    if ($null -eq $newTask) { return }

    try {
        $size = [double]$script:area.taskSize
        $position = @(Find-FreePosition $size)

        if ($position.Count -lt 2) {
            $smile = [char]::ConvertFromUtf32(0x1F60A)
            Show-AddFailure "No space is available on the board. Taking on too many tasks at once is not responsible.`nFinish your tasks before creating more. $smile"
            return
        }

        $newTask | Add-Member -NotePropertyName x -NotePropertyValue ([Math]::Round([double]$position[0], 1)) -Force
        $newTask | Add-Member -NotePropertyName y -NotePropertyValue ([Math]::Round([double]$position[1], 1)) -Force
        Start-TaskPlacementAnimation $newTask $position $size {
            param($task)
            Commit-NewTask $task
        }
    }
    catch {
        $failedTaskId = [string]$newTask.id
        $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $failedTaskId })
        Show-AddFailure 'The item could not be added. Please try again.'
    }
}

function Create-NewTask {
    if ($null -eq $script:addTitleBox -or $null -eq $script:addDescriptionBox) { return }
    if (-not $script:addCreateButton.IsEnabled) { return }

    $title = $script:addTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $iconId = [string]$script:addSelectedIcon

    if ([string]::IsNullOrWhiteSpace($iconId) -or $null -eq (Get-IconEntry $iconId)) {
        $iconId = Get-DefaultTaskIconId
    }

    if ([string]::IsNullOrWhiteSpace([string]$iconId)) { return }

    $newTask = [pscustomobject][ordered]@{
        id = 'task-' + [Guid]::NewGuid().ToString('N')
        title = $title
        description = $script:addDescriptionBox.Text.Trim()
        icon = [string]$iconId
        isNew = $true
        createdAt = [DateTime]::Now.ToString('o')
    }

    Add-TaskBadgeMetadata $newTask $true
    $script:pendingNewTask = $newTask
    $script:addBody.Visibility = 'Collapsed'
    $script:addSavingPanel.Visibility = 'Visible'
    $script:addSavingVisualHost.Child = New-TaskBadgeVisual $newTask 92
    $script:addSavingTitleText.Text = [string]$newTask.title
    $script:addSavingStatusText.Text = 'SAVING...'
    $script:addCreateButton.IsEnabled = $false
    $script:addCloseButton.IsEnabled = $false
    $script:window.Dispatcher.BeginInvoke(
        [System.Action]{ Complete-NewTask },
        [System.Windows.Threading.DispatcherPriority]::ContextIdle
    ) | Out-Null
}
