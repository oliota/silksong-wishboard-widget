$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $base 'config.json'
$areaPath = Join-Path $base 'area.json'
$defaultAreaPath = Join-Path $base 'default-area.json'
$tasksPath = Join-Path $base 'tasks.json'
$backgroundsPath = Join-Path $base 'backgrounds.json'
$backgroundsDir = Join-Path $base 'backgrounds'
$iconsPath = Join-Path $base 'icons.json'
$script:editMode = $false
$script:draggingEditorNode = $null
$script:draggingEditorIndex = -1
$script:editSnapshot = $null
$script:editWorkingArea = $null
$script:editUndoStack = New-Object System.Collections.Stack
$script:editBackgroundFile = $null
$script:editSnapshotBackgroundFile = $null
$script:editBackgroundScale = 1.0
$script:editBackgroundOffsetX = 0.0
$script:editBackgroundOffsetY = 0.0
$script:editSnapshotBackgroundScale = 1.0
$script:editSnapshotBackgroundOffsetX = 0.0
$script:editSnapshotBackgroundOffsetY = 0.0
$script:editSnapshotAddX = $null
$script:editSnapshotAddY = $null
$script:editSnapshotAddSize = $null
$script:editAddX = $null
$script:editAddY = $null
$script:editGridColumns = 3
$script:editSnapshotGridColumns = 3
$script:addSelectedIcon = 'icon-01'
$script:detailSelectedIcon = 'icon-01'
$script:selectedTaskId = $null


$script:pendingDeletedBackgroundIds = New-Object System.Collections.Generic.HashSet[string]


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
    $panelWidth = 320.0
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
    $script:addSelectedIcon = Get-DefaultTaskIconId

    Populate-AddIconGrid

    $script:addPanel.Visibility = 'Visible'
    $script:addTitleBox.Focus() | Out-Null
}

function Close-AddTaskPanel {
    if ($null -ne $script:addPanel) {
        $script:addPanel.Visibility = 'Collapsed'
    }
}

function Create-NewTask {
    if ($null -eq $script:addTitleBox -or $null -eq $script:addDescriptionBox) { return }

    $title = $script:addTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $iconId = [string]$script:addSelectedIcon

    if ([string]::IsNullOrWhiteSpace($iconId) -or $null -eq (Get-IconEntry $iconId)) {
        $iconId = Get-DefaultTaskIconId
    }

    if ([string]::IsNullOrWhiteSpace([string]$iconId)) { return }

    $size = [double]$script:area.taskSize
    $position = @(Find-FreePosition $size)

    if ($position.Count -lt 2) { return }

    $x = [double]$position[0]
    $y = [double]$position[1]
    $clamped = Clamp-ToPolygon $x $y $size

    if ($null -ne $clamped) {
        $x = [double]$clamped.X
        $y = [double]$clamped.Y
    }

    $newTask = [pscustomobject][ordered]@{
        id = 'task-' + [Guid]::NewGuid().ToString('N')
        title = $title
        description = $script:addDescriptionBox.Text.Trim()
        icon = [string]$iconId
        x = [Math]::Round($x, 1)
        y = [Math]::Round($y, 1)
    }

    $script:tasks = @($script:tasks) + @($newTask)

    Save-Tasks
    Render-Tasks
    Close-AddTaskPanel
}

function Set-EditButtonVisual([bool]$saveMode) {
    $viewbox = New-Object System.Windows.Controls.Viewbox
    $viewbox.Width = 17
    $viewbox.Height = 17

    $path = New-Object System.Windows.Shapes.Path
    $path.Stroke = [System.Windows.Media.Brushes]::White
    $path.StrokeThickness = 1.8
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.StrokeLineJoin = 'Round'
    $path.Fill = [System.Windows.Media.Brushes]::Transparent

    if ($saveMode) {
        $path.Data = [System.Windows.Media.Geometry]::Parse('M3,3 L14,3 L17,6 L17,17 L3,17 Z M6,3 L6,8 L13,8 L13,3 M6,12 L14,12 L14,17 L6,17 Z')
        $script:editButton.ToolTip = 'Save'
    }
    else {
        $path.Data = [System.Windows.Media.Geometry]::Parse('M3,15 L5,10 L13,2 L16,5 L8,13 Z M12,3 L15,6')
        $script:editButton.ToolTip = 'Edit'
    }

    $viewbox.Child = $path
    $script:editButton.Content = $viewbox
}

function Read-BackgroundRegistry {
    if (-not (Test-Path $backgroundsPath)) {
        return [pscustomobject]@{ backgrounds = @() }
    }

    $data = Read-JsonFile $backgroundsPath

    if ($null -eq $data.backgrounds) {
        $data | Add-Member -NotePropertyName backgrounds -NotePropertyValue @()
    }

    $data
}

function Save-BackgroundRegistry($registry) {
    $tempPath = "$backgroundsPath.tmp"
    $json = $registry | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $backgroundsPath -Force
}

function Get-DefaultBackground {
    $registry = Read-BackgroundRegistry
    @($registry.backgrounds | Where-Object { [string]$_.id -eq 'default' }) | Select-Object -First 1
}


function Get-ActiveBackgroundScale {
    if ($script:editMode) { return [double]$script:editBackgroundScale }
    return [double]$script:config.background.scale
}

function Get-ActiveBackgroundOffsetX {
    if ($script:editMode) { return [double]$script:editBackgroundOffsetX }
    return [double]$script:config.background.offsetX
}

function Get-ActiveBackgroundOffsetY {
    if ($script:editMode) { return [double]$script:editBackgroundOffsetY }
    return [double]$script:config.background.offsetY
}

function Get-ActiveAddX {
    if ($script:editMode -and $null -ne $script:editAddX) { return [double]$script:editAddX }
    if ($null -ne $script:config.buttons.addX) { return [double]$script:config.buttons.addX }
    return $null
}

function Get-ActiveAddY {
    if ($script:editMode -and $null -ne $script:editAddY) { return [double]$script:editAddY }
    if ($null -ne $script:config.buttons.addY) { return [double]$script:config.buttons.addY }
    return $null
}

function Get-ActiveBackgroundFile {
    if ($script:editMode -and -not [string]::IsNullOrWhiteSpace([string]$script:editBackgroundFile)) {
        return [string]$script:editBackgroundFile
    }

    [string]$script:config.background.file
}

function New-EditCheckpoint {
    [pscustomobject][ordered]@{
        area = Copy-JsonObject $script:editWorkingArea
        backgroundFile = [string]$script:editBackgroundFile
        backgroundScale = [double]$script:editBackgroundScale
        backgroundOffsetX = [double]$script:editBackgroundOffsetX
        backgroundOffsetY = [double]$script:editBackgroundOffsetY
        addX = $script:editAddX
        addY = $script:editAddY
        gridColumns = [int]$script:editGridColumns
    }
}

function Save-Tasks {
    $payload = [ordered]@{ tasks = @($script:tasks) }
    $tempPath = "$tasksPath.tmp"
    $json = $payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $tasksPath -Force
    $script:tasks = @(Read-Tasks)
    $script:tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc
}

function Get-TaskById([string]$id) {
    @($script:tasks | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
}

function New-RoundButton([string]$text, [double]$size) {
    $button = New-Object System.Windows.Controls.Button
    $button.Width = $size
    $button.Height = $size
    $button.Content = $text
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(180, 22, 22, 26))
    $button.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 225, 225, 225))
    $button.BorderThickness = '1'
    $button.FontSize = 12
    $button.FontWeight = 'SemiBold'
    $button.Cursor = 'Hand'
    $button.Template = [System.Windows.Markup.XamlReader]::Parse(@"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
  <Border CornerRadius="999" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="4"/>
  </Border>
</ControlTemplate>
"@)
    $button
}


function Copy-JsonObject($value) {
    if ($null -eq $value) { return $null }
    $value | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Read-DefaultArea {
    if (Test-Path $defaultAreaPath) {
        return Copy-JsonObject (Read-JsonFile $defaultAreaPath)
    }

    return New-FactoryArea
}

function New-FactoryArea {
    $cx = 260.0
    $cy = 255.0
    $radius = 150.0
    $points = @()

    for ($i = 0; $i -lt 10; $i++) {
        $angle = (-90.0 + ($i * 36.0)) * [Math]::PI / 180.0
        $points += [pscustomobject][ordered]@{
            x = [Math]::Round($cx + ([Math]::Cos($angle) * $radius), 1)
            y = [Math]::Round($cy + ([Math]::Sin($angle) * $radius), 1)
        }
    }

    [pscustomobject][ordered]@{
        type = 'polygon'
        borderVisible = $true
        borderThickness = 2
        borderColor = '#D8FFFFFF'
        fillColor = '#1600A8FF'
        taskSize = 48
        padding = 8
        points = $points
    }
}

function Get-ActiveArea {
    if ($script:editMode -and $null -ne $script:editWorkingArea) {
        return $script:editWorkingArea
    }
    $script:area
}

function Update-EditButtons {
    if ($null -eq $script:undoButton) { return }

    $script:undoButton.Visibility = if ($script:editMode -and $script:editUndoStack.Count -gt 0) { 'Visible' } else { 'Collapsed' }

    if ($script:editMode -and $null -ne $script:editWorkingArea) {
        $enabled = [bool]$script:editWorkingArea.borderVisible
        $script:borderToggle.Content = if ($enabled) { 'LINE ON' } else { 'LINE OFF' }
        $script:borderToggle.ToolTip = if ($enabled) { 'Hide Border After Save' } else { 'Show Border After Save' }
        $script:borderToggle.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
            $(if ($enabled) { '#CC198754' } else { '#CCD93025' })
        )
    }
}

function Push-EditUndo {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return }
    $script:editUndoStack.Push((New-EditCheckpoint))
    Update-EditButtons
}

function Cancel-EditSession {
    if (-not $script:editMode) { return }

    if ($null -ne $script:draggingEditorNode) {
        $script:draggingEditorNode.ReleaseMouseCapture()
        $script:draggingEditorNode = $null
        $script:draggingEditorIndex = -1
    }

    $script:editMode = $false
    $script:editWorkingArea = $null
    $script:editUndoStack.Clear()
    $script:editBackgroundFile = $null
    $script:editBackgroundScale = [double]$script:editSnapshotBackgroundScale
    $script:editBackgroundOffsetX = [double]$script:editSnapshotBackgroundOffsetX
    $script:editBackgroundOffsetY = [double]$script:editSnapshotBackgroundOffsetY
    $script:editAddX = $script:editSnapshotAddX
    $script:editAddY = $script:editSnapshotAddY
    if ($null -ne $script:editSnapshotAddSize) {
        $script:config.buttons.addSize = $script:editSnapshotAddSize
    }
    $script:editGridColumns = [int]$script:editSnapshotGridColumns
    $script:editSnapshotBackgroundFile = $null
    $script:pendingDeletedBackgroundIds.Clear()

    if ($null -ne $script:editSnapshot) {
        $script:area = Copy-JsonObject $script:editSnapshot
    }

    $script:editSnapshot = $null
    Set-EditButtonVisual $false
    $script:undoButton.Visibility = 'Collapsed'
    $script:clearButton.Visibility = 'Collapsed'
    $script:borderToggle.Visibility = 'Collapsed'
    $script:cancelEditButton.Visibility = 'Collapsed'
    $script:backgroundButton.Visibility = 'Collapsed'
    $script:gridButton.Visibility = 'Collapsed'
    
    $script:backgroundPanel.Visibility = 'Collapsed'
    $script:gridPanel.Visibility = 'Collapsed'
    $script:taskLayer.IsHitTestVisible = $true
    $script:editorLayer.IsHitTestVisible = $false

    Apply-Config
    Render-Background
    Render-Area
    Render-EditorNodes
    Render-Tasks
}

function Get-AreaPoints {
    $activeArea = Get-ActiveArea
    $points = New-Object System.Collections.Generic.List[System.Windows.Point]
    foreach ($p in @($activeArea.points)) {
        $points.Add([System.Windows.Point]::new([double]$p.x, [double]$p.y))
    }
    $points
}

function Point-InPolygon([double]$x, [double]$y) {
    $points = @(Get-AreaPoints)
    $count = [int]$points.Count
    if ($count -lt 3) { return $false }

    $inside = $false
    $j = $count - 1

    for ($i = 0; $i -lt $count; $i++) {
        $xi = [double]$points[$i].X
        $yi = [double]$points[$i].Y
        $xj = [double]$points[$j].X
        $yj = [double]$points[$j].Y

        if (($yi -gt $y) -ne ($yj -gt $y)) {
            $denominator = [double]($yj - $yi)

            if ([Math]::Abs($denominator) -gt 0.000001) {
                $ratio = [double](($y - $yi) * (1.0 / $denominator))
                $intersectionX = [double]($xi + (($xj - $xi) * $ratio))

                if ($x -lt $intersectionX) {
                    $inside = -not $inside
                }
            }
        }

        $j = $i
    }

    return [bool]$inside
}

function Test-TaskInsidePolygon([double]$x, [double]$y, [double]$size) {
    $half = [double]($size * 0.5)
    $cx = [double]($x + $half)
    $cy = [double]($y + $half)
    $radius = [double][Math]::Max(1.0, ($half - 2.0))
    $diagonal = [double]($radius * 0.70710678118)

    $samples = @(
        [pscustomobject]@{ X = $cx; Y = $cy },
        [pscustomobject]@{ X = [double]($cx - $radius); Y = $cy },
        [pscustomobject]@{ X = [double]($cx + $radius); Y = $cy },
        [pscustomobject]@{ X = $cx; Y = [double]($cy - $radius) },
        [pscustomobject]@{ X = $cx; Y = [double]($cy + $radius) },
        [pscustomobject]@{ X = [double]($cx - $diagonal); Y = [double]($cy - $diagonal) },
        [pscustomobject]@{ X = [double]($cx + $diagonal); Y = [double]($cy - $diagonal) },
        [pscustomobject]@{ X = [double]($cx - $diagonal); Y = [double]($cy + $diagonal) },
        [pscustomobject]@{ X = [double]($cx + $diagonal); Y = [double]($cy + $diagonal) }
    )

    foreach ($sample in $samples) {
        $sampleX = [double]$sample.X
        $sampleY = [double]$sample.Y

        if (-not (Point-InPolygon $sampleX $sampleY)) {
            return $false
        }
    }

    return $true
}

function Test-TaskCollision(
    [string]$movingTaskId,
    [double]$x,
    [double]$y,
    [double]$size
) {
    $margin = if ($null -ne $script:config.tasks.collisionMargin) {
        [double]$script:config.tasks.collisionMargin
    }
    else {
        6.0
    }

    $radius = ($size * 0.5) + ($margin * 0.5)
    $movingCenterX = $x + ($size * 0.5)
    $movingCenterY = $y + ($size * 0.5)
    $minimumDistance = $radius * 2.0
    $minimumDistanceSquared = $minimumDistance * $minimumDistance

    foreach ($task in @($script:tasks)) {
        if ([string]$task.id -eq $movingTaskId) { continue }

        $otherCenterX = [double]$task.x + ($size * 0.5)
        $otherCenterY = [double]$task.y + ($size * 0.5)
        $dx = $movingCenterX - $otherCenterX
        $dy = $movingCenterY - $otherCenterY
        $distanceSquared = ($dx * $dx) + ($dy * $dy)

        if ($distanceSquared -lt $minimumDistanceSquared) {
            return $true
        }
    }

    return $false
}

function Test-TaskPlacementValid(
    [string]$movingTaskId,
    [double]$x,
    [double]$y,
    [double]$size
) {
    if (-not (Test-TaskInsidePolygon $x $y $size)) {
        return $false
    }

    if (Test-TaskCollision $movingTaskId $x $y $size) {
        return $false
    }

    return $true
}

function Find-TaskSlidePosition(
    [string]$movingTaskId,
    [double]$fromX,
    [double]$fromY,
    [double]$targetX,
    [double]$targetY,
    [double]$size
) {
    if (Test-TaskPlacementValid $movingTaskId $targetX $targetY $size) {
        return [pscustomobject]@{ X = $targetX; Y = $targetY }
    }

    $dx = $targetX - $fromX
    $dy = $targetY - $fromY
    $length = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))

    if ($length -lt 0.0001) {
        return [pscustomobject]@{ X = $fromX; Y = $fromY }
    }

    $normalX = -$dy / $length
    $normalY = $dx / $length
    $best = $null
    $bestScore = [double]::PositiveInfinity

    foreach ($direction in @(-1.0, 1.0)) {
        foreach ($offset in @(4.0, 8.0, 12.0, 18.0, 24.0, 32.0, 42.0)) {
            $candidateX = $targetX + ($normalX * $offset * $direction)
            $candidateY = $targetY + ($normalY * $offset * $direction)

            if (-not (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size)) {
                continue
            }

            $scoreX = $candidateX - $targetX
            $scoreY = $candidateY - $targetY
            $score = ($scoreX * $scoreX) + ($scoreY * $scoreY)

            if ($score -lt $bestScore) {
                $bestScore = $score
                $best = [pscustomobject]@{
                    X = $candidateX
                    Y = $candidateY
                }
            }
        }
    }

    if ($null -ne $best) {
        return $best
    }

    $low = 0.0
    $high = 1.0
    $bestX = $fromX
    $bestY = $fromY

    for ($i = 0; $i -lt 18; $i++) {
        $mid = ($low + $high) * 0.5
        $candidateX = $fromX + (($targetX - $fromX) * $mid)
        $candidateY = $fromY + (($targetY - $fromY) * $mid)

        if (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size) {
            $bestX = $candidateX
            $bestY = $candidateY
            $low = $mid
        }
        else {
            $high = $mid
        }
    }

    return [pscustomobject]@{
        X = $bestX
        Y = $bestY
    }
}

function Constrain-TaskDrag(
    [string]$movingTaskId,
    [double]$fromX,
    [double]$fromY,
    [double]$targetX,
    [double]$targetY,
    [double]$size
) {
    if (Test-TaskPlacementValid $movingTaskId $targetX $targetY $size) {
        return [pscustomobject]@{ X = $targetX; Y = $targetY }
    }

    if (Test-TaskInsidePolygon $targetX $targetY $size) {
        return Find-TaskSlidePosition $movingTaskId $fromX $fromY $targetX $targetY $size
    }

    if (-not (Test-TaskInsidePolygon $fromX $fromY $size)) {
        $fallback = Clamp-ToPolygon $fromX $fromY $size
        $fromX = [double]$fallback.X
        $fromY = [double]$fallback.Y
    }

    $low = 0.0
    $high = 1.0
    $bestX = $fromX
    $bestY = $fromY

    for ($i = 0; $i -lt 18; $i++) {
        $mid = ($low + $high) * 0.5
        $candidateX = $fromX + (($targetX - $fromX) * $mid)
        $candidateY = $fromY + (($targetY - $fromY) * $mid)

        if (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size) {
            $bestX = $candidateX
            $bestY = $candidateY
            $low = $mid
        }
        else {
            $high = $mid
        }
    }

    return [pscustomobject]@{ X = $bestX; Y = $bestY }
}

function Clamp-ToPolygon([double]$x, [double]$y, [double]$size) {
    $points = @(Get-AreaPoints)
    $count = [int]$points.Count

    if ($count -lt 3) {
        return [pscustomobject]@{ X = [double]$x; Y = [double]$y }
    }

    $half = [double]($size * 0.5)
    $cx = [double]($x + $half)
    $cy = [double]($y + $half)

    if (Point-InPolygon $cx $cy) {
        return [pscustomobject]@{ X = [double]$x; Y = [double]$y }
    }

    $sumX = 0.0
    $sumY = 0.0

    foreach ($point in $points) {
        $sumX += [double]$point.X
        $sumY += [double]$point.Y
    }

    $inverseCount = [double](1.0 / [double]$count)
    $targetX = [double]($sumX * $inverseCount)
    $targetY = [double]($sumY * $inverseCount)

    for ($step = 1; $step -le 100; $step++) {
        $t = [double]($step * 0.01)
        $candidateX = [double]($cx + (($targetX - $cx) * $t))
        $candidateY = [double]($cy + (($targetY - $cy) * $t))

        if (Point-InPolygon $candidateX $candidateY) {
            return [pscustomobject]@{
                X = [double]($candidateX - $half)
                Y = [double]($candidateY - $half)
            }
        }
    }

    return [pscustomobject]@{
        X = [double]($targetX - $half)
        Y = [double]($targetY - $half)
    }
}


function Normalize-Tasks-ToArea {
    $activeArea = Get-ActiveArea
    $size = [double]$activeArea.taskSize
    $half = [double]($size * 0.5)
    $changed = $false

    foreach ($task in @($script:tasks)) {
        $taskX = [double]$task.x
        $taskY = [double]$task.y
        $centerX = [double]($taskX + $half)
        $centerY = [double]($taskY + $half)

        if (-not (Point-InPolygon $centerX $centerY)) {
            $position = Clamp-ToPolygon $taskX $taskY $size
            $task.x = [Math]::Round([double]$position.X, 1)
            $task.y = [Math]::Round([double]$position.Y, 1)
            $changed = $true
        }
    }

    if ($changed) {
        Save-Tasks
        Load-All
    }

    Render-Tasks
}

function Find-FreePosition([double]$size) {
    $points = @(Get-AreaPoints)
    if ($points.Count -lt 3) { return @(20.0, 20.0) }

    $minX = ($points | Measure-Object -Property X -Minimum).Minimum
    $maxX = ($points | Measure-Object -Property X -Maximum).Maximum
    $minY = ($points | Measure-Object -Property Y -Minimum).Minimum
    $maxY = ($points | Measure-Object -Property Y -Maximum).Maximum
    $best = $null
    $bestScore = -1.0
    $step = [Math]::Max(18, $size * 0.65)

    for ($cy = $minY; $cy -le $maxY; $cy += $step) {
        for ($cx = $minX; $cx -le $maxX; $cx += $step) {
            if (-not (Point-InPolygon $cx $cy)) { continue }
            $x = $cx - $size / 2
            $y = $cy - $size / 2
            if (Test-TaskCollision '' $x $y $size) { continue }
            $score = [double]::PositiveInfinity
            foreach ($t in @($script:tasks)) {
                $tx = [double]$t.x + $size / 2
                $ty = [double]$t.y + $size / 2
                $dx = $cx - $tx
                $dy = $cy - $ty
                $distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
                if ($distance -lt $score) { $score = $distance }
            }
            if ($script:tasks.Count -eq 0) { $score = 999999 }
            if ($score -gt $bestScore) {
                $bestScore = $score
                $best = @($x, $y)
            }
        }
    }

    if ($null -eq $best) {
        $cx = ($points | Measure-Object -Property X -Average).Average
        $cy = ($points | Measure-Object -Property Y -Average).Average
        return @($cx - $size / 2, $cy - $size / 2)
    }
    $best
}

function Save-Area {
    param($AreaToSave = $null)

    $target = if ($null -ne $AreaToSave) { $AreaToSave } else { $script:area }
    $tempPath = "$areaPath.tmp"
    $json = $target | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $areaPath -Force
    $script:areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
}

function Distance-ToSegment([double]$px, [double]$py, [double]$ax, [double]$ay, [double]$bx, [double]$by) {
    $vx = $bx - $ax
    $vy = $by - $ay
    $len2 = ($vx * $vx) + ($vy * $vy)

    if ($len2 -le 0.000001) {
        $dx = $px - $ax
        $dy = $py - $ay
        return [pscustomobject]@{
            Distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
            X = $ax
            Y = $ay
        }
    }

    $t = (($px - $ax) * $vx + ($py - $ay) * $vy) / $len2
    $t = [Math]::Max(0, [Math]::Min(1, $t))
    $x = $ax + ($t * $vx)
    $y = $ay + ($t * $vy)
    $dx = $px - $x
    $dy = $py - $y

    [pscustomobject]@{
        Distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        X = $x
        Y = $y
    }
}

function Insert-Node-OnNearestSegment([double]$x, [double]$y) {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return $false }

    $points = @($script:editWorkingArea.points)
    if ($points.Count -lt 2) { return $false }

    $best = $null

    for ($i = 0; $i -lt $points.Count; $i++) {
        $j = ($i + 1) % $points.Count
        $hit = Distance-ToSegment $x $y ([double]$points[$i].x) ([double]$points[$i].y) ([double]$points[$j].x) ([double]$points[$j].y)

        if ($null -eq $best -or $hit.Distance -lt $best.Distance) {
            $best = [pscustomobject]@{
                Distance = $hit.Distance
                X = $hit.X
                Y = $hit.Y
                InsertAt = $j
            }
        }
    }

    if ($null -eq $best -or [double]$best.Distance -gt 18.0) { return $false }

    Push-EditUndo

    $list = New-Object System.Collections.ArrayList
    foreach ($p in $points) {
        [void]$list.Add([pscustomobject][ordered]@{ x = [double]$p.x; y = [double]$p.y })
    }

    [void]$list.Insert(
        [int]$best.InsertAt,
        [pscustomobject][ordered]@{
            x = [Math]::Round([double]$best.X, 1)
            y = [Math]::Round([double]$best.Y, 1)
        }
    )

    $script:editWorkingArea.points = @($list)
    Render-Area
    Render-EditorNodes
    Update-EditButtons
    return $true
}

function Insert-EditorNodeOnSegment([int]$segmentStartIndex) {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return }

    $points = @($script:editWorkingArea.points)
    if ($points.Count -lt 2) { return }
    if ($segmentStartIndex -lt 0 -or $segmentStartIndex -ge $points.Count) { return }

    $segmentEndIndex = ($segmentStartIndex + 1) % $points.Count
    $a = $points[$segmentStartIndex]
    $b = $points[$segmentEndIndex]

    Push-EditUndo

    $newPoints = New-Object System.Collections.ArrayList
    foreach ($point in $points) {
        [void]$newPoints.Add(
            [pscustomobject][ordered]@{
                x = [double]$point.x
                y = [double]$point.y
            }
        )
    }

    $newPoint = [pscustomobject][ordered]@{
        x = [Math]::Round((([double]$a.x + [double]$b.x) * 0.5), 1)
        y = [Math]::Round((([double]$a.y + [double]$b.y) * 0.5), 1)
    }

    $insertAt = $segmentStartIndex + 1

    if ($insertAt -ge $newPoints.Count) {
        [void]$newPoints.Add($newPoint)
    }
    else {
        [void]$newPoints.Insert($insertAt, $newPoint)
    }

    $script:editWorkingArea.points = @($newPoints)
    Render-Area
    Render-EditorNodes
    Update-EditButtons
}

function New-NodeAddButton {
    $button = New-RoundButton '' 16
    $button.ToolTip = 'Insert Node'

    $view = New-Object System.Windows.Controls.Viewbox
    $view.Width = 10
    $view.Height = 10

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 10
    $canvas.Height = 10

    $horizontal = New-Object System.Windows.Shapes.Line
    $horizontal.X1 = 1
    $horizontal.Y1 = 5
    $horizontal.X2 = 9
    $horizontal.Y2 = 5
    $horizontal.Stroke = [System.Windows.Media.Brushes]::White
    $horizontal.StrokeThickness = 2
    $horizontal.StrokeStartLineCap = 'Round'
    $horizontal.StrokeEndLineCap = 'Round'

    $vertical = New-Object System.Windows.Shapes.Line
    $vertical.X1 = 5
    $vertical.Y1 = 1
    $vertical.X2 = 5
    $vertical.Y2 = 9
    $vertical.Stroke = [System.Windows.Media.Brushes]::White
    $vertical.StrokeThickness = 2
    $vertical.StrokeStartLineCap = 'Round'
    $vertical.StrokeEndLineCap = 'Round'

    $canvas.Children.Add($horizontal) | Out-Null
    $canvas.Children.Add($vertical) | Out-Null
    $view.Child = $canvas
    $button.Content = $view
    $button
}

function Render-EditorNodes {
    if ($null -eq $script:editorLayer) { return }
    $script:editorLayer.Children.Clear()

    if (-not $script:editMode -or $null -eq $script:editWorkingArea) {
        $script:editorLayer.IsHitTestVisible = $false
        $script:editorLayer.Background = [System.Windows.Media.Brushes]::Transparent
        return
    }

    $script:editorLayer.IsHitTestVisible = $true
    $script:editorLayer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#01000000')
    $points = @($script:editWorkingArea.points)

    if ($points.Count -ge 2) {
        for ($i = 0; $i -lt $points.Count; $i++) {
            $j = ($i + 1) % $points.Count
            $a = $points[$i]
            $b = $points[$j]

            $line = New-Object System.Windows.Shapes.Line
            $line.X1 = [double]$a.x
            $line.Y1 = [double]$a.y
            $line.X2 = [double]$b.x
            $line.Y2 = [double]$b.y
            $line.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
                $(if ([bool]$script:editWorkingArea.borderVisible) { '#FF2ECC71' } else { '#FFE74C3C' })
            )
            $line.StrokeThickness = 2
            $line.IsHitTestVisible = $false
            $script:editorLayer.Children.Add($line) | Out-Null
        }
    }

    for ($index = 0; $index -lt $points.Count; $index++) {
        $point = $points[$index]
        $prevIndex = ($index - 1 + $points.Count) % $points.Count
        $nextIndex = ($index + 1) % $points.Count
        $prev = $points[$prevIndex]
        $next = $points[$nextIndex]

        $node = New-RoundButton ([string]($index + 1)) 28
        $node.Tag = $index
        $node.ToolTip = 'Move Node ' + ([string]($index + 1))
        $node.Cursor = [System.Windows.Input.Cursors]::SizeAll
        $node.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 20, 110, 190))
        [System.Windows.Controls.Panel]::SetZIndex($node, 510)
        [System.Windows.Controls.Canvas]::SetLeft($node, [double]$point.x - 14)
        [System.Windows.Controls.Canvas]::SetTop($node, [double]$point.y - 14)

        $midPrevX = ([double]$prev.x + [double]$point.x) * 0.5
        $midPrevY = ([double]$prev.y + [double]$point.y) * 0.5
        $midNextX = ([double]$point.x + [double]$next.x) * 0.5
        $midNextY = ([double]$point.y + [double]$next.y) * 0.5

        $leftButtonX = [double]$point.x - 38.0
        $leftButtonY = [double]$point.y
        $rightButtonX = [double]$point.x + 38.0
        $rightButtonY = [double]$point.y

        $leftPrevDistance = [Math]::Sqrt(
            (($leftButtonX - $midPrevX) * ($leftButtonX - $midPrevX)) +
            (($leftButtonY - $midPrevY) * ($leftButtonY - $midPrevY))
        )
        $leftNextDistance = [Math]::Sqrt(
            (($leftButtonX - $midNextX) * ($leftButtonX - $midNextX)) +
            (($leftButtonY - $midNextY) * ($leftButtonY - $midNextY))
        )

        $rightPrevDistance = [Math]::Sqrt(
            (($rightButtonX - $midPrevX) * ($rightButtonX - $midPrevX)) +
            (($rightButtonY - $midPrevY) * ($rightButtonY - $midPrevY))
        )
        $rightNextDistance = [Math]::Sqrt(
            (($rightButtonX - $midNextX) * ($rightButtonX - $midNextX)) +
            (($rightButtonY - $midNextY) * ($rightButtonY - $midNextY))
        )

        $assignmentA = $leftPrevDistance + $rightNextDistance
        $assignmentB = $leftNextDistance + $rightPrevDistance

        if ($assignmentA -le $assignmentB) {
            $leftSegmentStart = $prevIndex
            $rightSegmentStart = $index
        }
        else {
            $leftSegmentStart = $index
            $rightSegmentStart = $prevIndex
        }

        $leftPreviewX = if ($leftSegmentStart -eq $prevIndex) { $midPrevX } else { $midNextX }
        $leftPreviewY = if ($leftSegmentStart -eq $prevIndex) { $midPrevY } else { $midNextY }
        $rightPreviewX = if ($rightSegmentStart -eq $prevIndex) { $midPrevX } else { $midNextX }
        $rightPreviewY = if ($rightSegmentStart -eq $prevIndex) { $midPrevY } else { $midNextY }

        $leftPreview = New-Object System.Windows.Shapes.Ellipse
        $leftPreview.Width = 28
        $leftPreview.Height = 28
        $leftPreview.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E6E53935')
        $leftPreview.Stroke = [System.Windows.Media.Brushes]::White
        $leftPreview.StrokeThickness = 1
        $leftPreview.Visibility = 'Collapsed'
        $leftPreview.IsHitTestVisible = $false
        [System.Windows.Controls.Canvas]::SetLeft($leftPreview, $leftPreviewX - 14)
        [System.Windows.Controls.Canvas]::SetTop($leftPreview, $leftPreviewY - 14)
        [System.Windows.Controls.Panel]::SetZIndex($leftPreview, 505)
        $script:editorLayer.Children.Add($leftPreview) | Out-Null

        $rightPreview = New-Object System.Windows.Shapes.Ellipse
        $rightPreview.Width = 28
        $rightPreview.Height = 28
        $rightPreview.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E6E53935')
        $rightPreview.Stroke = [System.Windows.Media.Brushes]::White
        $rightPreview.StrokeThickness = 1
        $rightPreview.Visibility = 'Collapsed'
        $rightPreview.IsHitTestVisible = $false
        [System.Windows.Controls.Canvas]::SetLeft($rightPreview, $rightPreviewX - 14)
        [System.Windows.Controls.Canvas]::SetTop($rightPreview, $rightPreviewY - 14)
        [System.Windows.Controls.Panel]::SetZIndex($rightPreview, 505)
        $script:editorLayer.Children.Add($rightPreview) | Out-Null

        $leftAdd = New-NodeAddButton
        $leftAdd.Tag = [string]$leftSegmentStart
        [System.Windows.Controls.Canvas]::SetLeft($leftAdd, [double]$point.x - 37)
        [System.Windows.Controls.Canvas]::SetTop($leftAdd, [double]$point.y - 8)
        [System.Windows.Controls.Panel]::SetZIndex($leftAdd, 520)

        $rightAdd = New-NodeAddButton
        $rightAdd.Tag = [string]$rightSegmentStart
        [System.Windows.Controls.Canvas]::SetLeft($rightAdd, [double]$point.x + 21)
        [System.Windows.Controls.Canvas]::SetTop($rightAdd, [double]$point.y - 8)
        [System.Windows.Controls.Panel]::SetZIndex($rightAdd, 520)

        $leftAdd.Add_MouseEnter({
            $leftPreview.Visibility = 'Visible'
        }.GetNewClosure())

        $leftAdd.Add_MouseLeave({
            $leftPreview.Visibility = 'Collapsed'
        }.GetNewClosure())

        $rightAdd.Add_MouseEnter({
            $rightPreview.Visibility = 'Visible'
        }.GetNewClosure())

        $rightAdd.Add_MouseLeave({
            $rightPreview.Visibility = 'Collapsed'
        }.GetNewClosure())

        $leftAdd.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)
            Insert-EditorNodeOnSegment ([int]$sender.Tag)
            $eventArgs.Handled = $true
        })

        $rightAdd.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)
            Insert-EditorNodeOnSegment ([int]$sender.Tag)
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseLeftButtonDown({
            param($sender, $eventArgs)
            Push-EditUndo
            $script:draggingEditorNode = $sender
            $script:draggingEditorIndex = [int]$sender.Tag
            [void]$sender.CaptureMouse()
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseMove({
            param($sender, $eventArgs)

            if ($null -eq $script:draggingEditorNode) { return }
            if ($script:draggingEditorNode -ne $sender) { return }
            if ($eventArgs.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

            $position = $eventArgs.GetPosition($script:root)
            $dragIndex = [int]$script:draggingEditorIndex
            if ($dragIndex -lt 0 -or $dragIndex -ge @($script:editWorkingArea.points).Count) { return }

            $script:editWorkingArea.points[$dragIndex].x = [Math]::Round([double]$position.X, 1)
            $script:editWorkingArea.points[$dragIndex].y = [Math]::Round([double]$position.Y, 1)

            [System.Windows.Controls.Canvas]::SetLeft($sender, [double]$position.X - 14)
            [System.Windows.Controls.Canvas]::SetTop($sender, [double]$position.Y - 14)

            Render-Area
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)

            if ($script:draggingEditorNode -eq $sender) {
                $sender.ReleaseMouseCapture()
                $script:draggingEditorNode = $null
                $script:draggingEditorIndex = -1
                Render-Area
                Render-EditorNodes
                Update-EditButtons
            }

            $eventArgs.Handled = $true
        })

        $script:editorLayer.Children.Add($leftAdd) | Out-Null
        $script:editorLayer.Children.Add($rightAdd) | Out-Null
        $script:editorLayer.Children.Add($node) | Out-Null
    }
}

function Hide-Panel {
    if ($script:detailsPanel) {  }
    if ($script:addPanel) { $script:addPanel.Visibility = 'Collapsed' }
    if ($script:backgroundPanel) { $script:backgroundPanel.Visibility = 'Collapsed' }
    if ($script:gridPanel) { $script:gridPanel.Visibility = 'Collapsed' }
}


function New-DetailOrnament {
    $view = New-Object System.Windows.Controls.Viewbox
    $view.Stretch = 'Uniform'
    $view.Height = 26
    $view.HorizontalAlignment = 'Stretch'

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 420
    $canvas.Height = 28

    $path = New-Object System.Windows.Shapes.Path
    $path.Stroke = [System.Windows.Media.Brushes]::White
    $path.StrokeThickness = 2
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.Fill = [System.Windows.Media.Brushes]::Transparent
    $path.Data = [System.Windows.Media.Geometry]::Parse(
        'M5,15 C55,15 75,5 105,8 C135,11 145,15 185,15 ' +
        'M235,15 C275,15 285,11 315,8 C345,5 365,15 415,15 ' +
        'M185,15 C198,15 200,5 210,5 C220,5 222,15 235,15 ' +
        'M202,15 L210,8 L218,15 L210,22 Z'
    )
    $canvas.Children.Add($path) | Out-Null
    $view.Child = $canvas
    $view
}

function Set-DetailEditVisual($button, [bool]$saveMode) {
    $view = New-Object System.Windows.Controls.Viewbox
    $view.Width = 17
    $view.Height = 17

    $path = New-Object System.Windows.Shapes.Path
    $path.Stroke = [System.Windows.Media.Brushes]::White
    $path.StrokeThickness = 1.8
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.StrokeLineJoin = 'Round'
    $path.Fill = [System.Windows.Media.Brushes]::Transparent

    if ($saveMode) {
        $path.Data = [System.Windows.Media.Geometry]::Parse(
            'M3,3 L14,3 L17,6 L17,17 L3,17 Z M6,3 L6,8 L13,8 L13,3 M6,12 L14,12 L14,17 L6,17 Z'
        )
        $button.ToolTip = 'Save'
    }
    else {
        $path.Data = [System.Windows.Media.Geometry]::Parse(
            'M3,14 L4,10 L12,2 L16,6 L8,14 Z M11,3 L15,7'
        )
        $button.ToolTip = 'Edit'
    }

    $view.Child = $path
    $button.Content = $view
}

function Show-TaskIconChooser(
    [System.Windows.Window]$Owner,
    [string]$SelectedIcon
) {
    $chooser = New-Object System.Windows.Window
    $chooser.WindowStyle = 'None'
    $chooser.ResizeMode = 'NoResize'
    $chooser.AllowsTransparency = $true
    $chooser.Background = [System.Windows.Media.Brushes]::Transparent
    $chooser.ShowInTaskbar = $false
    $chooser.Topmost = $true
    $chooser.Width = 390
    $chooser.Height = 430
    $chooser.WindowStartupLocation = 'CenterOwner'

    if ($null -ne $Owner) {
        $chooser.Owner = $Owner
    }

    $chooser.Tag = $null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F51A1A1E')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#99FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 10
    $card.Padding = 14
    $chooser.Content = $card

    $layout = New-Object System.Windows.Controls.Grid
    $card.Child = $layout

    $topRow = New-Object System.Windows.Controls.RowDefinition
    $topRow.Height = New-Object System.Windows.GridLength(40)
    $contentRow = New-Object System.Windows.Controls.RowDefinition
    $contentRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($topRow)
    $layout.RowDefinitions.Add($contentRow)

    $header = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $layout.Children.Add($header) | Out-Null

    $hc1 = New-Object System.Windows.Controls.ColumnDefinition
    $hc1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $hc2 = New-Object System.Windows.Controls.ColumnDefinition
    $hc2.Width = New-Object System.Windows.GridLength(36)
    $header.ColumnDefinitions.Add($hc1)
    $header.ColumnDefinitions.Add($hc2)

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'Choose Icon'
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 17
    $title.FontWeight = 'SemiBold'
    $title.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($title, 0)
    $header.Children.Add($title) | Out-Null

    $close = New-RoundButton 'X' 30
    $close.ToolTip = 'Close'
    [System.Windows.Controls.Grid]::SetColumn($close, 1)
    $header.Children.Add($close) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $layout.Children.Add($scroll) | Out-Null

    $grid = New-Object System.Windows.Controls.WrapPanel
    $grid.Orientation = 'Horizontal'
    $scroll.Content = $grid

    $columns = [Math]::Max(1, [Math]::Min(8, [int]$script:config.icons.columns))
    $availableWidth = 340.0
    $cell = [Math]::Max(42.0, [Math]::Floor($availableWidth / [double]$columns) - 6.0)
    $imageSize = [Math]::Max(30.0, $cell - 10.0)

    $catalog = Read-IconCatalog

    foreach ($entry in @($catalog.icons)) {
        $button = New-Object System.Windows.Controls.Button
        $button.Tag = [string]$entry.id
        $button.Width = $cell
        $button.Height = $cell
        $button.Margin = '3'
        $button.Padding = '3'
        $button.ToolTip = [string]$entry.name
        $button.Content = New-ImageControl ([string]$entry.file) $imageSize

        if ([string]$entry.id -eq $SelectedIcon) {
            $button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF2ECC71')
            $button.BorderThickness = 3
        }

        $button.Add_Click({
            param($s, $e)
            $chooser.Tag = [string]$s.Tag
            $chooser.DialogResult = $true
            $chooser.Close()
        }.GetNewClosure())

        $grid.Children.Add($button) | Out-Null
    }

    $close.Add_Click({
        $chooser.Tag = $null
        $chooser.DialogResult = $false
        $chooser.Close()
    }.GetNewClosure())

    $result = $chooser.ShowDialog()

    $selected = [string]$chooser.Tag

    if ($result -eq $true -and -not [string]::IsNullOrWhiteSpace($selected)) {
        return $selected
    }

    return $null
}


function Set-DetailIconById([string]$iconId) {
    if ($null -eq $script:detailIconHost) { return }

    $entry = Get-IconEntry $iconId

    if ($null -eq $entry) {
        $script:detailIconHost.Child = $null
        return
    }

    $script:detailIconHost.Child = New-ImageControl ([string]$entry.file) 68
}

function Set-DetailReadMode {
    if ($null -eq $script:detailEditButton) { return }

    $script:detailEditing = $false
    $script:detailDeleteTopButton.Visibility = 'Visible'
    Set-DetailEditVisual $script:detailEditButton $false
    $script:detailTitleText.Visibility = 'Visible'
    $script:detailDescriptionScroll.Visibility = 'Visible'
    $script:detailTitleBox.Visibility = 'Collapsed'
    $script:detailDescriptionBox.Visibility = 'Collapsed'
    $script:detailChangeIconButton.Visibility = 'Collapsed'
    $script:detailEditActions.Visibility = 'Collapsed'
}

function Set-DetailEditMode {
    $task = Get-TaskById ([string]$script:detailCurrentTaskId)
    if ($null -eq $task) { return }

    $script:detailEditing = $true
    $script:detailDeleteTopButton.Visibility = 'Collapsed'
    Set-DetailEditVisual $script:detailEditButton $true

    $script:detailTitleBox.Text = [string]$task.title
    $script:detailDescriptionBox.Text = [string]$task.description
    $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) { 'icon-01' } else { [string]$task.icon }

    Set-DetailIconById $script:detailPendingIconId

    $script:detailTitleText.Visibility = 'Collapsed'
    $script:detailDescriptionScroll.Visibility = 'Collapsed'
    $script:detailTitleBox.Visibility = 'Visible'
    $script:detailDescriptionBox.Visibility = 'Visible'
    $script:detailChangeIconButton.Visibility = 'Visible'
    $script:detailEditActions.Visibility = 'Visible'
}

function Save-DetailItem {
    $task = Get-TaskById ([string]$script:detailCurrentTaskId)
    if ($null -eq $task) { return }

    $title = $script:detailTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = 'Untitled'
    }

    $task.title = $title
    $task.description = $script:detailDescriptionBox.Text.Trim()
    $task.icon = [string]$script:detailPendingIconId

    Save-Tasks

    $script:detailTitleText.Text = [string]$task.title
    $script:detailDescriptionText.Text = [string]$task.description
    Set-DetailIconById ([string]$task.icon)
    Set-DetailReadMode
    Render-Tasks
}

function Close-DetailWindow {
    $detailRef = $script:activeDetailWindow

    $script:activeDetailWindow = $null
    $script:detailCurrentTaskId = $null
    $script:detailEditing = $false

    if ($null -ne $detailRef) {
        try {
            $detailRef.Close()
        }
        catch {
        }
    }
}

function Delete-DetailItem {
    if ($script:detailEditing) { return }

    $targetId = [string]$script:detailCurrentTaskId
    if ([string]::IsNullOrWhiteSpace($targetId)) { return }

    $script:tasks = @(
        $script:tasks | Where-Object { [string]$_.id -ne $targetId }
    )

    Save-Tasks
    Render-Tasks
    Close-DetailWindow
}

function Show-DetailsById([string]$taskId) {
    $task = Get-TaskById $taskId
    if ($null -eq $task) { return }

    $script:detailCurrentTaskId = [string]$taskId
    $script:detailEditing = $false

    if ($null -ne $script:activeDetailWindow) {
        try {
            if ($script:activeDetailWindow.IsVisible) {
                $script:activeDetailWindow.Close()
            }
        }
        catch {
        }

        $script:activeDetailWindow = $null
    }

    $detailWindow = New-Object System.Windows.Window
    $detailWindow.WindowStyle = 'None'
    $detailWindow.ResizeMode = 'NoResize'
    $detailWindow.AllowsTransparency = $true
    $detailWindow.Background = [System.Windows.Media.Brushes]::Transparent
    $detailWindow.ShowInTaskbar = $false
    $detailWindow.Topmost = $true
    $detailWindow.Width = [Math]::Max(
        [double]$script:config.detailWindow.minWidth,
        [double]$script:config.detailWindow.width
    )
    $detailWindow.Height = [Math]::Max(
        [double]$script:config.detailWindow.minHeight,
        [double]$script:config.detailWindow.height
    )
    $detailWindow.MinWidth = [double]$script:config.detailWindow.minWidth
    $detailWindow.MinHeight = [double]$script:config.detailWindow.minHeight
    $detailWindow.WindowStartupLocation = 'CenterScreen'
    $script:activeDetailWindow = $detailWindow

    $outer = New-Object System.Windows.Controls.Grid
    $detailWindow.Content = $outer

    $ornamentTopRow = New-Object System.Windows.Controls.RowDefinition
    $ornamentTopRow.Height = New-Object System.Windows.GridLength(30)
    $cardRow = New-Object System.Windows.Controls.RowDefinition
    $cardRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $ornamentBottomRow = New-Object System.Windows.Controls.RowDefinition
    $ornamentBottomRow.Height = New-Object System.Windows.GridLength(30)
    $outer.RowDefinitions.Add($ornamentTopRow)
    $outer.RowDefinitions.Add($cardRow)
    $outer.RowDefinitions.Add($ornamentBottomRow)

    $topOrnament = New-DetailOrnament
    [System.Windows.Controls.Grid]::SetRow($topOrnament, 0)
    $outer.Children.Add($topOrnament) | Out-Null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F4070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#44FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    $card.Padding = 18
    [System.Windows.Controls.Grid]::SetRow($card, 1)
    $outer.Children.Add($card) | Out-Null

    $bottomOrnament = New-DetailOrnament
    $bottomOrnament.RenderTransformOrigin = '0.5,0.5'
    $bottomOrnament.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1, -1)
    [System.Windows.Controls.Grid]::SetRow($bottomOrnament, 2)
    $outer.Children.Add($bottomOrnament) | Out-Null

    $layout = New-Object System.Windows.Controls.Grid
    $card.Child = $layout

    $toolbarRow = New-Object System.Windows.Controls.RowDefinition
    $toolbarRow.Height = New-Object System.Windows.GridLength(38)
    $bodyRow = New-Object System.Windows.Controls.RowDefinition
    $bodyRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($toolbarRow)
    $layout.RowDefinitions.Add($bodyRow)

    $toolbar = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $layout.Children.Add($toolbar) | Out-Null

    $toolbarSpacer = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarSpacer.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $toolbarEditCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarEditCol.Width = New-Object System.Windows.GridLength(36)
    $toolbarDeleteCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarDeleteCol.Width = New-Object System.Windows.GridLength(36)
    $toolbarResizeCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarResizeCol.Width = New-Object System.Windows.GridLength(36)
    $toolbarCloseCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarCloseCol.Width = New-Object System.Windows.GridLength(36)
    $toolbar.ColumnDefinitions.Add($toolbarSpacer)
    $toolbar.ColumnDefinitions.Add($toolbarEditCol)
    $toolbar.ColumnDefinitions.Add($toolbarDeleteCol)
    $toolbar.ColumnDefinitions.Add($toolbarResizeCol)
    $toolbar.ColumnDefinitions.Add($toolbarCloseCol)

    $detailEditButton = New-RoundButton '' 30
    $script:detailEditButton = $detailEditButton
    Set-DetailEditVisual $detailEditButton $false
    [System.Windows.Controls.Grid]::SetColumn($detailEditButton, 1)
    $toolbar.Children.Add($detailEditButton) | Out-Null

    $detailDeleteTopButton = New-RoundButton '' 30
    $script:detailDeleteTopButton = $detailDeleteTopButton
    $detailDeleteTopButton.ToolTip = 'Delete'
    $trashView = New-Object System.Windows.Controls.Viewbox
    $trashView.Width = 16
    $trashView.Height = 16
    $trashPath = New-Object System.Windows.Shapes.Path
    $trashPath.Stroke = [System.Windows.Media.Brushes]::White
    $trashPath.StrokeThickness = 1.8
    $trashPath.StrokeStartLineCap = 'Round'
    $trashPath.StrokeEndLineCap = 'Round'
    $trashPath.StrokeLineJoin = 'Round'
    $trashPath.Fill = [System.Windows.Media.Brushes]::Transparent
    $trashPath.Data = [System.Windows.Media.Geometry]::Parse('M4,5 L14,5 M6,5 L7,16 L12,16 L13,5 M8,3 L11,3 M8,8 L8,13 M11,8 L11,13')
    $trashView.Child = $trashPath
    $detailDeleteTopButton.Content = $trashView
    [System.Windows.Controls.Grid]::SetColumn($detailDeleteTopButton, 2)
    $toolbar.Children.Add($detailDeleteTopButton) | Out-Null

    $detailResizeThumb = New-Object System.Windows.Controls.Primitives.Thumb
    $detailResizeThumb.Width = 30
    $detailResizeThumb.Height = 30
    $detailResizeThumb.Cursor = [System.Windows.Input.Cursors]::SizeNWSE
    $detailResizeThumb.ToolTip = 'Resize'
    $detailResizeThumb.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0202024')
    $detailResizeThumb.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0FFFFFF')
    $detailResizeThumb.BorderThickness = 1
    $detailResizeThumb.Template = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Thumb">
  <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="15">
    <Grid Width="18" Height="18" HorizontalAlignment="Center" VerticalAlignment="Center">
      <Path Stroke="White" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M 4,14 L 14,4 M 9,4 L 14,4 L 14,9 M 4,9 L 4,14 L 9,14"/>
    </Grid>
  </Border>
</ControlTemplate>
'@)
    [System.Windows.Controls.Grid]::SetColumn($detailResizeThumb, 3)
    $toolbar.Children.Add($detailResizeThumb) | Out-Null

    $detailCloseButton = New-RoundButton 'X' 30
    $script:detailCloseButton = $detailCloseButton
    $detailCloseButton.ToolTip = 'Close'
    [System.Windows.Controls.Grid]::SetColumn($detailCloseButton, 4)
    $toolbar.Children.Add($detailCloseButton) | Out-Null

    $body = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($body, 1)
    $layout.Children.Add($body) | Out-Null

    $iconRow = New-Object System.Windows.Controls.RowDefinition
    $iconRow.Height = New-Object System.Windows.GridLength(82)
    $titleRow = New-Object System.Windows.Controls.RowDefinition
    $titleRow.Height = New-Object System.Windows.GridLength(38)
    $descriptionRow = New-Object System.Windows.Controls.RowDefinition
    $descriptionRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $actionsRow = New-Object System.Windows.Controls.RowDefinition
    $actionsRow.Height = New-Object System.Windows.GridLength(42)
    $body.RowDefinitions.Add($iconRow)
    $body.RowDefinitions.Add($titleRow)
    $body.RowDefinitions.Add($descriptionRow)
    $body.RowDefinitions.Add($actionsRow)

    $iconHostGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($iconHostGrid, 0)
    $body.Children.Add($iconHostGrid) | Out-Null

    $detailIconHost = New-Object System.Windows.Controls.Border
    $script:detailIconHost = $detailIconHost
    $detailIconHost.Width = 72
    $detailIconHost.Height = 72
    $detailIconHost.HorizontalAlignment = 'Center'
    $detailIconHost.VerticalAlignment = 'Center'
    $iconHostGrid.Children.Add($detailIconHost) | Out-Null

    $changeIconButton = New-Object System.Windows.Controls.Button
    $script:detailChangeIconButton = $changeIconButton
    $changeIconButton.Content = 'Change'
    $changeIconButton.Width = 76
    $changeIconButton.Height = 28
    $changeIconButton.HorizontalAlignment = 'Right'
    $changeIconButton.VerticalAlignment = 'Center'
    $changeIconButton.Visibility = 'Collapsed'
    $iconHostGrid.Children.Add($changeIconButton) | Out-Null

    $detailTitleText = New-Object System.Windows.Controls.TextBlock
    $script:detailTitleText = $detailTitleText
    $detailTitleText.Foreground = [System.Windows.Media.Brushes]::White
    $detailTitleText.FontSize = 18
    $detailTitleText.FontWeight = 'SemiBold'
    $detailTitleText.HorizontalAlignment = 'Center'
    $detailTitleText.VerticalAlignment = 'Center'
    $detailTitleText.TextAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetRow($detailTitleText, 1)
    $body.Children.Add($detailTitleText) | Out-Null

    $detailDescriptionText = New-Object System.Windows.Controls.TextBlock
    $script:detailDescriptionText = $detailDescriptionText
    $detailDescriptionText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F0E9E9E9')
    $detailDescriptionText.FontSize = 14
    $detailDescriptionText.TextWrapping = 'Wrap'
    $detailDescriptionText.TextAlignment = 'Left'
    $detailDescriptionText.VerticalAlignment = 'Top'
    $detailDescriptionText.Margin = '8,4,8,4'

    $detailDescriptionScroll = New-Object System.Windows.Controls.ScrollViewer
    $script:detailDescriptionScroll = $detailDescriptionScroll
    $detailDescriptionScroll.VerticalScrollBarVisibility = 'Auto'
    $detailDescriptionScroll.HorizontalScrollBarVisibility = 'Disabled'
    $detailDescriptionScroll.Margin = '4,0,4,0'
    $detailDescriptionScroll.Content = $detailDescriptionText
    [System.Windows.Controls.Grid]::SetRow($detailDescriptionScroll, 2)
    $body.Children.Add($detailDescriptionScroll) | Out-Null

    $titleBox = New-Object System.Windows.Controls.TextBox
    $script:detailTitleBox = $titleBox
    $titleBox.Height = 30
    $titleBox.Margin = '8,4,8,4'
    $titleBox.Visibility = 'Collapsed'
    [System.Windows.Controls.Grid]::SetRow($titleBox, 1)
    $body.Children.Add($titleBox) | Out-Null

    $descriptionBox = New-Object System.Windows.Controls.TextBox
    $script:detailDescriptionBox = $descriptionBox
    $descriptionBox.AcceptsReturn = $true
    $descriptionBox.TextWrapping = 'Wrap'
    $descriptionBox.VerticalScrollBarVisibility = 'Auto'
    $descriptionBox.Margin = '8,4,8,4'
    $descriptionBox.Visibility = 'Collapsed'
    [System.Windows.Controls.Grid]::SetRow($descriptionBox, 2)
    $body.Children.Add($descriptionBox) | Out-Null

    $editActions = New-Object System.Windows.Controls.StackPanel
    $script:detailEditActions = $editActions
    $editActions.Orientation = 'Horizontal'
    $editActions.HorizontalAlignment = 'Right'
    $editActions.Visibility = 'Collapsed'
    [System.Windows.Controls.Grid]::SetRow($editActions, 3)
    $body.Children.Add($editActions) | Out-Null

    $cancelButton = New-Object System.Windows.Controls.Button
    $script:detailCancelButton = $cancelButton
    $cancelButton.Content = 'Cancel'
    $cancelButton.Width = 78
    $cancelButton.Height = 30
    $cancelButton.Margin = '0,5,8,5'
    $editActions.Children.Add($cancelButton) | Out-Null

    $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) {
        'icon-01'
    }
    else {
        [string]$task.icon
    }

    Set-DetailIconById $script:detailPendingIconId

    $detailTitleText.Text = [string]$task.title
    $detailDescriptionText.Text = [string]$task.description

    $detailEditButton.Add_Click({
        if ($script:detailEditing) {
            Save-DetailItem
        }
        else {
            Set-DetailEditMode
        }
    })

    $cancelButton.Add_Click({
        $task = Get-TaskById ([string]$script:detailCurrentTaskId)

        if ($null -ne $task) {
            $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) { 'icon-01' } else { [string]$task.icon }
            Set-DetailIconById $script:detailPendingIconId
        }

        Set-DetailReadMode
    })

    $changeIconButton.Add_Click({
        $selectedIconId = Show-TaskIconChooser `
            -Owner $script:activeDetailWindow `
            -SelectedIcon $script:detailPendingIconId

        if ([string]::IsNullOrWhiteSpace([string]$selectedIconId)) { return }

        $entry = Get-IconEntry ([string]$selectedIconId)
        if ($null -eq $entry) { return }

        $script:detailPendingIconId = [string]$selectedIconId
        Set-DetailIconById $script:detailPendingIconId
    })

    $detailDeleteTopButton.Add_Click({
        Delete-DetailItem
    })

    $detailCloseButton.Add_Click({
        Close-DetailWindow
    })

    $detailResizeThumb.Add_DragDelta({
        param($s, $e)

        $detailRef = $script:activeDetailWindow

        if ($null -eq $detailRef) { return }
        if (-not $detailRef.IsVisible) { return }

        $ratio = [double]$script:config.detailWindow.aspectRatio
        if ($ratio -le 0.0) { $ratio = 1.7222 }

        $dx = [double]$e.HorizontalChange
        $dy = [double]$e.VerticalChange

        if ([Math]::Abs($dy) -gt [Math]::Abs($dx)) {
            $dx = $dy * $ratio
        }

        $newWidth = [Math]::Max(
            [double]$script:config.detailWindow.minWidth,
            [double]$detailRef.Width + $dx
        )

        $newHeight = $newWidth / $ratio

        if ($newHeight -lt [double]$script:config.detailWindow.minHeight) {
            $newHeight = [double]$script:config.detailWindow.minHeight
            $newWidth = $newHeight * $ratio
        }

        $detailRef.Width = $newWidth
        $detailRef.Height = $newHeight
    }.GetNewClosure())

    $detailResizeThumb.Add_DragCompleted({
        $detailRef = $script:activeDetailWindow

        if ($null -eq $detailRef) { return }

        $script:config.detailWindow.width = [Math]::Round([double]$detailRef.Width, 1)
        $script:config.detailWindow.height = [Math]::Round([double]$detailRef.Height, 1)
        $script:config.detailWindow.aspectRatio = [Math]::Round(
            ([double]$detailRef.Width / [double]$detailRef.Height),
            4
        )
        Save-Config
    }.GetNewClosure())

    $card.Add_MouseLeftButtonDown({
        param($s, $e)

        if ($e.OriginalSource -is [System.Windows.Controls.Button]) { return }
        if ($e.OriginalSource -is [System.Windows.Controls.Primitives.Thumb]) { return }
        if ($e.OriginalSource -is [System.Windows.Controls.TextBox]) { return }

        $detailRef = $script:activeDetailWindow
        if ($null -eq $detailRef) { return }

        try {
            $detailRef.DragMove()
        }
        catch {
        }
    }.GetNewClosure())

    $detailWindow.Add_Closed({
        $script:activeDetailWindow = $null
        $script:detailCurrentTaskId = $null
        $script:detailEditing = $false
    })

    $detailWindow.Show()
    $detailWindow.Activate() | Out-Null
}

function Render-Background {
    $script:background.Source = $null
    $activeFile = Get-ActiveBackgroundFile
    $path = Join-Path $base $activeFile

    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $script:background.Source = $bitmap
    }

    $scale = [Math]::Max(0.2, [Math]::Min(4.0, [double](Get-ActiveBackgroundScale)))
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight

    $script:background.Width = $designWidth * $scale
    $script:background.Height = $designHeight * $scale

    [System.Windows.Controls.Canvas]::SetLeft(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetX) - (($script:background.Width - $designWidth) * 0.5))
    )

    [System.Windows.Controls.Canvas]::SetTop(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetY) - (($script:background.Height - $designHeight) * 0.5))
    )

    $script:background.Opacity = [double]$script:config.background.opacity
    $script:background.Stretch = [System.Enum]::Parse(
        [System.Windows.Media.Stretch],
        [string]$script:config.background.stretch,
        $true
    )
}

function Render-Area {
    $activeArea = Get-ActiveArea
    $points = New-Object System.Windows.Media.PointCollection

    foreach ($p in @($activeArea.points)) {
        $points.Add([System.Windows.Point]::new([double]$p.x, [double]$p.y))
    }

    $script:taskArea.Points = $points
    $showBorder = $script:editMode -or [bool]$activeArea.borderVisible
    $script:taskArea.Visibility = if ($showBorder) { 'Visible' } else { 'Collapsed' }
    $script:taskArea.StrokeThickness = [double]$activeArea.borderThickness

    if ($script:editMode) {
        $color = if ([bool]$activeArea.borderVisible) { '#FF2ECC71' } else { '#FFE74C3C' }
        $script:taskArea.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
        $script:taskArea.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$activeArea.fillColor)
    }
    else {
        $script:taskArea.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$activeArea.borderColor)
        $script:taskArea.Fill = [System.Windows.Media.Brushes]::Transparent
    }

    $script:taskArea.IsHitTestVisible = $false
}

function Render-Tasks {
    foreach ($child in @($script:taskLayer.Children)) {
        $script:taskLayer.Children.Remove($child)
    }

    $size = [double]$script:area.taskSize

    foreach ($taskItem in @($script:tasks)) {
        $button = New-Object System.Windows.Controls.Button
        $button.Width = $size
        $button.Height = $size
        $button.Tag = [string]$taskItem.id
        $button.Cursor = [System.Windows.Input.Cursors]::Hand
        $button.ToolTip = [string]$taskItem.title
        $button.Background = [System.Windows.Media.Brushes]::Transparent
        $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $button.BorderThickness = 0
        $button.Padding = 2

        $iconId = if ([string]::IsNullOrWhiteSpace([string]$taskItem.icon)) { 'icon-01' } else { [string]$taskItem.icon }
        $iconEntry = Get-IconEntry $iconId

        if ($null -ne $iconEntry) {
            $taskVisual = New-Object System.Windows.Controls.Grid
            $plate = New-ImageControl 'item-background.png' ($size - 2)
            $plate.Stretch = 'Fill'
            $taskVisual.Children.Add($plate) | Out-Null
            $taskIcon = New-ImageControl ([string]$iconEntry.file) ($size * 0.72)
            $taskIcon.HorizontalAlignment = 'Center'
            $taskIcon.VerticalAlignment = 'Center'
            $taskVisual.Children.Add($taskIcon) | Out-Null
            $button.Content = $taskVisual
        }

        [System.Windows.Controls.Canvas]::SetLeft($button, [double]$taskItem.x)
        [System.Windows.Controls.Canvas]::SetTop($button, [double]$taskItem.y)

        $state = [pscustomobject]@{
            dragging = $false
            moved = $false
            startScreenX = 0.0
            startScreenY = 0.0
            originX = [double]$taskItem.x
            originY = [double]$taskItem.y
            lastX = [double]$taskItem.x
            lastY = [double]$taskItem.y
        }

        $button.Add_PreviewMouseLeftButtonDown({
            param($s, $e)

            if ($script:editMode) {
                $e.Handled = $true
                return
            }

            $cursor = [System.Windows.Forms.Cursor]::Position
            $state.dragging = $true
            $state.moved = $false
            $state.startScreenX = [double]$cursor.X
            $state.startScreenY = [double]$cursor.Y
            $state.originX = [double][System.Windows.Controls.Canvas]::GetLeft($s)
            $state.originY = [double][System.Windows.Controls.Canvas]::GetTop($s)
            $state.lastX = [double]$state.originX
            $state.lastY = [double]$state.originY
            [void]$s.CaptureMouse()
            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_PreviewMouseMove({
            param($s, $e)

            if ($script:editMode -or -not $state.dragging) { return }
            if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

            $cursor = [System.Windows.Forms.Cursor]::Position
            $cursorX = [double]$cursor.X
            $cursorY = [double]$cursor.Y
            $startScreenX = [double]$state.startScreenX
            $startScreenY = [double]$state.startScreenY
            $designWidth = [double]$script:config.widget.designWidth
            $designHeight = [double]$script:config.widget.designHeight
            $viewportWidth = [double]$script:viewport.ActualWidth
            $viewportHeight = [double]$script:viewport.ActualHeight

            $scaleX = if ($designWidth -gt 0.0) { $viewportWidth / $designWidth } else { 1.0 }
            $scaleY = if ($designHeight -gt 0.0) { $viewportHeight / $designHeight } else { 1.0 }
            $scale = [Math]::Min([double]$scaleX, [double]$scaleY)
            if ($scale -le 0.0001) { $scale = 1.0 }

            $deltaX = ($cursorX - $startScreenX) / $scale
            $deltaY = ($cursorY - $startScreenY) / $scale
            $candidateX = [double]$state.originX + $deltaX
            $candidateY = [double]$state.originY + $deltaY

            if (([Math]::Abs($deltaX) + [Math]::Abs($deltaY)) -gt 2.0) {
                $state.moved = $true
            }

            if ($state.moved) {
                $position = Constrain-TaskDrag `
                    ([string]$s.Tag) `
                    ([double]$state.lastX) `
                    ([double]$state.lastY) `
                    ([double]$candidateX) `
                    ([double]$candidateY) `
                    $size

                $state.lastX = [double]$position.X
                $state.lastY = [double]$position.Y

                [System.Windows.Controls.Canvas]::SetLeft($s, [double]$position.X)
                [System.Windows.Controls.Canvas]::SetTop($s, [double]$position.Y)
            }

            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_PreviewMouseLeftButtonUp({
            param($s, $e)

            if (-not $state.dragging) { return }

            $state.dragging = $false
            $s.ReleaseMouseCapture()

            $taskId = [string]$s.Tag
            $selectedTask = Get-TaskById $taskId

            if ($null -ne $selectedTask) {
                if ($state.moved) {
                    $selectedTask.x = [Math]::Round([double][System.Windows.Controls.Canvas]::GetLeft($s), 1)
                    $selectedTask.y = [Math]::Round([double][System.Windows.Controls.Canvas]::GetTop($s), 1)
                    Save-Tasks
                    Render-Tasks
                }
                else {
                    Show-DetailsById $taskId
                }
            }

            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_LostMouseCapture({
            $state.dragging = $false
        }.GetNewClosure())

        $script:taskLayer.Children.Add($button) | Out-Null
    }
}


function Get-DisplaySignature {
    (($screens = [System.Windows.Forms.Screen]::AllScreens) | ForEach-Object {
        $w = $_.WorkingArea
        '{0}:{1},{2},{3},{4}:{5}' -f $_.DeviceName, $w.Left, $w.Top, $w.Width, $w.Height, $_.Primary
    }) -join '|'
}

function Get-WindowScreen([double]$left, [double]$top, [double]$width, [double]$height) {
    $centerX = [int][Math]::Round($left + ($width * 0.5))
    $centerY = [int][Math]::Round($top + ($height * 0.5))
    [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new($centerX, $centerY))
}

function Update-DisplayAnchor {
    if ($null -eq $script:window -or $null -eq $script:config) { return }

    $width = [double]$script:window.Width
    $height = [double]$script:window.Height
    $left = [double]$script:window.Left
    $top = [double]$script:window.Top
    $screen = Get-WindowScreen $left $top $width $height
    $work = $screen.WorkingArea
    $rangeX = [Math]::Max(1.0, [double]$work.Width - $width)
    $rangeY = [Math]::Max(1.0, [double]$work.Height - $height)
    $relativeX = [Math]::Max(0.0, [Math]::Min(1.0, ($left - [double]$work.Left) / $rangeX))
    $relativeY = [Math]::Max(0.0, [Math]::Min(1.0, ($top - [double]$work.Top) / $rangeY))

    $anchor = [pscustomobject]@{
        deviceName = [string]$screen.DeviceName
        workLeft = [double]$work.Left
        workTop = [double]$work.Top
        workWidth = [double]$work.Width
        workHeight = [double]$work.Height
        relativeX = [Math]::Round($relativeX, 4)
        relativeY = [Math]::Round($relativeY, 4)
    }

    if ($null -eq $script:config.widget.PSObject.Properties['displayAnchor']) {
        $script:config.widget | Add-Member -NotePropertyName displayAnchor -NotePropertyValue $anchor
    }
    else {
        $script:config.widget.displayAnchor = $anchor
    }
}

function Save-WidgetPlacement {
    if ($null -eq $script:window -or $script:suppressPositionSave) { return }
    $script:config.widget.left = [Math]::Round([double]$script:window.Left, 1)
    $script:config.widget.top = [Math]::Round([double]$script:window.Top, 1)
    Update-DisplayAnchor
    Save-Config
}

function Get-VisibleWindowArea([double]$left, [double]$top, [double]$width, [double]$height) {
    $right = $left + $width
    $bottom = $top + $height
    $best = 0.0

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $work = $screen.WorkingArea
        $intersectionWidth = [Math]::Max(0.0, [Math]::Min($right, [double]$work.Right) - [Math]::Max($left, [double]$work.Left))
        $intersectionHeight = [Math]::Max(0.0, [Math]::Min($bottom, [double]$work.Bottom) - [Math]::Max($top, [double]$work.Top))
        $best = [Math]::Max($best, $intersectionWidth * $intersectionHeight)
    }

    $best
}

function Ensure-WidgetOnVisibleDisplay([bool]$displayChanged = $false) {
    if ($null -eq $script:window -or -not $script:positionInitialized) { return $false }

    $width = [double]$script:window.Width
    $height = [double]$script:window.Height
    $left = [double]$script:window.Left
    $top = [double]$script:window.Top
    $visibleArea = Get-VisibleWindowArea $left $top $width $height
    $minimumVisibleArea = [Math]::Min($width, 160.0) * [Math]::Min($height, 100.0)

    if ($visibleArea -ge $minimumVisibleArea) {
        if ($displayChanged) { Update-DisplayAnchor; Save-Config }
        return $false
    }

    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    if ($screens.Count -eq 0) { return $false }

    $target = @($screens | Where-Object { $_.Primary } | Select-Object -First 1)[0]
    if ($null -eq $target) { $target = $screens[0] }
    $work = $target.WorkingArea
    $rangeX = [Math]::Max(0.0, [double]$work.Width - $width)
    $rangeY = [Math]::Max(0.0, [double]$work.Height - $height)
    $relativeX = $null
    $relativeY = $null
    $anchor = $script:config.widget.displayAnchor

    if ($null -ne $anchor) {
        $relativeX = [Math]::Max(0.0, [Math]::Min(1.0, [double]$anchor.relativeX))
        $relativeY = [Math]::Max(0.0, [Math]::Min(1.0, [double]$anchor.relativeY))
    }

    if ($null -eq $relativeX -or $null -eq $relativeY) {
        $newLeft = [Math]::Max([double]$work.Left, [Math]::Min([double]$work.Right - $width, $left))
        $newTop = [Math]::Max([double]$work.Top, [Math]::Min([double]$work.Bottom - $height, $top))
    }
    else {
        $newLeft = [double]$work.Left + ($rangeX * $relativeX)
        $newTop = [double]$work.Top + ($rangeY * $relativeY)
    }

    if ($width -gt [double]$work.Width) { $newLeft = [double]$work.Left }
    if ($height -gt [double]$work.Height) { $newTop = [double]$work.Top }

    $script:suppressPositionSave = $true
    try {
        $script:window.Left = [Math]::Round($newLeft, 1)
        $script:window.Top = [Math]::Round($newTop, 1)
    }
    finally {
        $script:suppressPositionSave = $false
    }

    Save-WidgetPlacement
    $true
}

function Save-Config {
    $tempPath = "$configPath.tmp"
    $json = $script:config | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $configPath -Force
    $script:configStamp = (Get-Item $configPath).LastWriteTimeUtc
}


function Persist-WidgetScale {
    Save-Config
}

function Apply-Config {
    $windowWidth = [double]$script:config.widget.width
    $windowHeight = [double]$script:config.widget.height
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight

    $script:window.Width = $windowWidth
    $script:window.Height = $windowHeight
    $script:window.Topmost = [bool]$script:config.widget.topmost
    $script:window.Opacity = [Math]::Max(0.2, [Math]::Min(1.0, [double]$script:config.widget.opacity))

    if (-not $script:positionInitialized) {
        $script:window.Left = [double]$script:config.widget.left
        $script:window.Top = [double]$script:config.widget.top
        $script:positionInitialized = $true
    }

    $script:root.Width = $designWidth
    $script:root.Height = $designHeight
    $script:taskLayer.Width = $designWidth
    $script:taskLayer.Height = $designHeight
    $script:editorLayer.Width = $designWidth
    $script:editorLayer.Height = $designHeight

    Render-Background
    Render-Area

    $toolbarBottom = if ($null -ne $script:config.buttons.toolbarBottom) { [double]$script:config.buttons.toolbarBottom } else { 12.0 }
    $toolbarY = $designHeight - 42.0 - $toolbarBottom
    $toolbarWidth = 318.0
    $toolbarStartX = ($designWidth - $toolbarWidth) * 0.5

    [System.Windows.Controls.Canvas]::SetLeft($script:opacitySlider, $toolbarStartX)
    [System.Windows.Controls.Canvas]::SetTop($script:opacitySlider, $toolbarY + 2.0)
    [System.Windows.Controls.Canvas]::SetLeft($script:opacityLabel, $toolbarStartX + 114.0)
    [System.Windows.Controls.Canvas]::SetTop($script:opacityLabel, $toolbarY + 9.0)
    [System.Windows.Controls.Canvas]::SetLeft($script:editButton, $toolbarStartX + 154.0)
    [System.Windows.Controls.Canvas]::SetTop($script:editButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:resizeButton, $toolbarStartX + 194.0)
    [System.Windows.Controls.Canvas]::SetTop($script:resizeButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:minimizeButton, $toolbarStartX + 234.0)
    [System.Windows.Controls.Canvas]::SetTop($script:minimizeButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:closeButton, $toolbarStartX + 274.0)
    [System.Windows.Controls.Canvas]::SetTop($script:closeButton, $toolbarY)

    $script:opacitySliderUpdating = $true
    $script:opacitySlider.Value = [double]$script:config.widget.opacity * 100.0
    $script:opacityLabel.Text = ([int][Math]::Round([double]$script:opacitySlider.Value)).ToString() + '%'
    $script:opacitySliderUpdating = $false

    $addSize = if ($null -ne $script:config.buttons.addSize) { [double]$script:config.buttons.addSize } else { 44.0 }
    $script:addButton.Width = $addSize
    $script:addButton.Height = $addSize

    $customAddX = Get-ActiveAddX
    $customAddY = Get-ActiveAddY
    $maxAddY = $toolbarY - $addSize - 10.0

    if ($null -eq $customAddX -or $null -eq $customAddY) {
        $customAddX = ($designWidth - $addSize) * 0.5
        $customAddY = 120.0
    }

    $safeX = [Math]::Max(0.0, [Math]::Min($designWidth - $addSize, [double]$customAddX))
    $safeY = [Math]::Max(0.0, [Math]::Min($maxAddY, [double]$customAddY))

    $centerX = $safeX + ($addSize * 0.5)
    $centerY = $safeY + ($addSize * 0.5)

    if (Point-InPolygon $centerX $centerY) {
        $safeX = ($designWidth - $addSize) * 0.5
        $safeY = 90.0

        while ((Point-InPolygon ($safeX + ($addSize * 0.5)) ($safeY + ($addSize * 0.5))) -and $safeY -gt 8.0) {
            $safeY -= 10.0
        }

        if (Point-InPolygon ($safeX + ($addSize * 0.5)) ($safeY + ($addSize * 0.5))) {
            $safeX = 12.0
            $safeY = 90.0
        }

        if ($script:editMode) {
            $script:editAddX = [Math]::Round($safeX, 1)
            $script:editAddY = [Math]::Round($safeY, 1)
        }
        else {
            $script:config.buttons.addX = [Math]::Round($safeX, 1)
            $script:config.buttons.addY = [Math]::Round($safeY, 1)
        }
    }

    [System.Windows.Controls.Canvas]::SetLeft($script:addButton, $safeX)
    [System.Windows.Controls.Canvas]::SetTop($script:addButton, $safeY)

    [System.Windows.Controls.Canvas]::SetLeft($script:addSizeSlider, [Math]::Min($designWidth - 108.0, $safeX + $addSize + 8.0))
    [System.Windows.Controls.Canvas]::SetTop($script:addSizeSlider, $safeY + (($addSize - 30.0) * 0.5))

    $script:addSizeSliderUpdating = $true
    $script:addSizeSlider.Value = $addSize
    $script:addSizeSliderUpdating = $false
    $script:addSizeSlider.Visibility = if ($script:editMode) { 'Visible' } else { 'Collapsed' }

    $editY = 50.0
    [System.Windows.Controls.Canvas]::SetLeft($script:undoButton, 92.0)
    [System.Windows.Controls.Canvas]::SetTop($script:undoButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:clearButton, 142.0)
    [System.Windows.Controls.Canvas]::SetTop($script:clearButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:borderToggle, 192.0)
    [System.Windows.Controls.Canvas]::SetTop($script:borderToggle, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:cancelEditButton, 242.0)
    [System.Windows.Controls.Canvas]::SetTop($script:cancelEditButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:backgroundButton, 292.0)
    [System.Windows.Controls.Canvas]::SetTop($script:backgroundButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:gridButton, 342.0)
    [System.Windows.Controls.Canvas]::SetTop($script:gridButton, $editY)

    $script:opacitySlider.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
    $script:opacityLabel.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
    $script:resizeButton.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
}

function Reload-Files {
    $configStamp = (Get-Item $configPath).LastWriteTimeUtc
    $areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
    $tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc

    if ($configStamp -ne $script:configStamp) {
        $script:config = Read-JsonFile $configPath
        $script:configStamp = $configStamp
        Apply-Config
        Render-Background

        if ($null -ne $script:reloadTimer) {
            $script:reloadTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(5, [double]$script:config.refreshSeconds))
        }
    }

    if ($areaStamp -ne $script:areaStamp) {
        $script:area = Read-JsonFile $areaPath
        $script:areaStamp = $areaStamp
        Apply-Config
        Render-Tasks
        Render-EditorNodes
    }

    if ($tasksStamp -ne $script:tasksStamp) {
        $script:tasks = @(Read-Tasks)
        $script:tasksStamp = $tasksStamp
        Render-Tasks
    }
}
$script:config = Read-JsonFile $configPath
$script:area = Read-JsonFile $areaPath
$script:tasks = @(Read-Tasks)
$script:configStamp = (Get-Item $configPath).LastWriteTimeUtc
$script:areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
$script:tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc
$script:positionInitialized = $false
$script:userHidden = $false
$script:exiting = $false
$script:widgetDragActive = $false
$script:widgetDragStartMouseX = 0.0
$script:widgetDragStartMouseY = 0.0
$script:widgetDragStartLeft = 0.0
$script:widgetDragStartTop = 0.0
$script:widgetNormalOpacity = 1.0
$script:suppressPositionSave = $false
$script:displaySignature = Get-DisplaySignature


$window = New-Object System.Windows.Window
$window.WindowStyle = 'None'
$window.ResizeMode = 'NoResize'
$window.AllowsTransparency = $true
$window.Background = [System.Windows.Media.Brushes]::Transparent
$window.ShowInTaskbar = $false
$window.Topmost = $true
$window.SizeToContent = 'Manual'
$script:window = $window

$viewport = New-Object System.Windows.Controls.Viewbox
$viewport.Stretch = [System.Windows.Media.Stretch]::Uniform
$viewport.StretchDirection = [System.Windows.Controls.StretchDirection]::Both
$script:viewport = $viewport

$root = New-Object System.Windows.Controls.Canvas
$root.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(1, 0, 0, 0))
$script:root = $root
$viewport.Child = $root
$window.Content = $viewport

$background = New-Object System.Windows.Controls.Image
$background.IsHitTestVisible = $false
$script:background = $background
$root.Children.Add($background) | Out-Null

$taskArea = New-Object System.Windows.Shapes.Polygon
$taskArea.Fill = [System.Windows.Media.Brushes]::Transparent
$taskArea.Stroke = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(130, 255, 255, 255))
$taskArea.IsHitTestVisible = $false
$script:taskArea = $taskArea
$root.Children.Add($taskArea) | Out-Null

$taskLayer = New-Object System.Windows.Controls.Canvas
$taskLayer.Width = 1000
$taskLayer.Height = 1000
$script:taskLayer = $taskLayer
$root.Children.Add($taskLayer) | Out-Null

$editorLayer = New-Object System.Windows.Controls.Canvas
$editorLayer.Width = 1000
$editorLayer.Height = 1000
$editorLayer.Background = [System.Windows.Media.Brushes]::Transparent
$editorLayer.IsHitTestVisible = $false
[System.Windows.Controls.Panel]::SetZIndex($editorLayer, 100)
$script:editorLayer = $editorLayer
$root.Children.Add($editorLayer) | Out-Null



$closeButton = New-RoundButton 'X' 30
$closeButton.FontSize = 13
$closeButton.ToolTip = 'Close'
$script:closeButton = $closeButton
$root.Children.Add($closeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($closeButton, 2000)

$minimizeButton = New-RoundButton '_' 30
$minimizeButton.FontSize = 16
$minimizeButton.ToolTip = 'Minimize'
$script:minimizeButton = $minimizeButton
$root.Children.Add($minimizeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($minimizeButton, 2000)

$resizeButton = New-Object System.Windows.Controls.Primitives.Thumb
$resizeButton.Width = 30
$resizeButton.Height = 30
$resizeButton.Cursor = [System.Windows.Input.Cursors]::SizeNESW
$resizeButton.ToolTip = 'Resize'
$resizeButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0202024')
$resizeButton.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0FFFFFF')
$resizeButton.BorderThickness = 1
$resizeButton.Template = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Thumb">
    <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="15">
        <Grid Width="18" Height="18" HorizontalAlignment="Center" VerticalAlignment="Center">
            <Path Stroke="White" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M 4,14 L 14,4 M 9,4 L 14,4 L 14,9 M 4,9 L 4,14 L 9,14"/>
        </Grid>
    </Border>
</ControlTemplate>
'@)
$script:resizeButton = $resizeButton
$root.Children.Add($resizeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($resizeButton, 2000)

$opacitySlider = New-Object System.Windows.Controls.Slider
$opacitySlider.Minimum = 20
$opacitySlider.Maximum = 100
$opacitySlider.Width = 110
$opacitySlider.Height = 30
$opacitySlider.TickFrequency = 10
$opacitySlider.IsSnapToTickEnabled = $false
$opacitySlider.ToolTip = 'Opacity'
$script:opacitySlider = $opacitySlider
$root.Children.Add($opacitySlider) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($opacitySlider, 2000)

$opacityLabel = New-Object System.Windows.Controls.TextBlock
$opacityLabel.Foreground = [System.Windows.Media.Brushes]::White
$opacityLabel.FontSize = 10
$opacityLabel.TextAlignment = 'Center'
$opacityLabel.Width = 34
$opacityLabel.Height = 18
$script:opacityLabel = $opacityLabel
$root.Children.Add($opacityLabel) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($opacityLabel, 2000)

$addButton = New-RoundButton '+' 44
$addButton.FontSize = 22
$addButton.ToolTip = 'Add Task'
$script:addButton = $addButton
$root.Children.Add($addButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($addButton, 2000)

$addSizeSlider = New-Object System.Windows.Controls.Slider
$addSizeSlider.Minimum = 28
$addSizeSlider.Maximum = 84
$addSizeSlider.Width = 100
$addSizeSlider.Height = 30
$addSizeSlider.Visibility = 'Collapsed'
$addSizeSlider.ToolTip = 'Add Button Size'
$script:addSizeSlider = $addSizeSlider
$root.Children.Add($addSizeSlider) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($addSizeSlider, 2000)

$editButton = New-RoundButton '' 30
$editButton.ToolTip = 'Edit'
$script:editButton = $editButton
$root.Children.Add($editButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($editButton, 2000)
Set-EditButtonVisual $false

$undoButton = New-RoundButton 'UNDO' 44
$undoButton.FontSize = 8
$undoButton.Visibility = 'Collapsed'
$undoButton.ToolTip = 'Undo'
$script:undoButton = $undoButton
$root.Children.Add($undoButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($undoButton, 2000)

$clearButton = New-RoundButton 'CLEAR' 44
$clearButton.FontSize = 8
$clearButton.Visibility = 'Collapsed'
$clearButton.ToolTip = 'Reset'
$script:clearButton = $clearButton
$root.Children.Add($clearButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($clearButton, 2000)

$borderToggle = New-RoundButton 'LINE' 44
$borderToggle.FontSize = 8
$borderToggle.Visibility = 'Collapsed'
$borderToggle.ToolTip = 'Toggle Border'
$script:borderToggle = $borderToggle
$root.Children.Add($borderToggle) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($borderToggle, 2000)

$cancelEditButton = New-RoundButton 'CANCEL' 44
$cancelEditButton.FontSize = 7
$cancelEditButton.Visibility = 'Collapsed'
$cancelEditButton.ToolTip = 'Cancel'
$script:cancelEditButton = $cancelEditButton
$root.Children.Add($cancelEditButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($cancelEditButton, 2000)

$backgroundButton = New-RoundButton 'BG' 44
$backgroundButton.FontSize = 9
$backgroundButton.Visibility = 'Collapsed'
$backgroundButton.ToolTip = 'Choose Background'
$script:backgroundButton = $backgroundButton
$root.Children.Add($backgroundButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($backgroundButton, 2000)


$gridButton = New-RoundButton 'GRID' 44
$gridButton.FontSize = 8
$gridButton.Visibility = 'Collapsed'
$gridButton.ToolTip = 'Icon Grid'
$script:gridButton = $gridButton
$root.Children.Add($gridButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($gridButton, 2000)

$backgroundPanel = New-Object System.Windows.Controls.Border
$backgroundPanel.Width = 300
$backgroundPanel.MaxHeight = 390
$backgroundPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$backgroundPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$backgroundPanel.BorderThickness = 1
$backgroundPanel.CornerRadius = 10
$backgroundPanel.Padding = 12
$backgroundPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($backgroundPanel, 108)
[System.Windows.Controls.Canvas]::SetTop($backgroundPanel, 92)
[System.Windows.Controls.Panel]::SetZIndex($backgroundPanel, 3500)
$script:backgroundPanel = $backgroundPanel

$backgroundPanelStack = New-Object System.Windows.Controls.StackPanel
$backgroundHeader = New-Object System.Windows.Controls.TextBlock
$backgroundHeader.Text = 'Choose Background'
$backgroundHeader.Foreground = [System.Windows.Media.Brushes]::White
$backgroundHeader.FontSize = 17
$backgroundHeader.FontWeight = 'Bold'
$backgroundHeader.Margin = '0,0,0,10'
$headerGrid = New-Object System.Windows.Controls.Grid
$headerGrid.Height = 34
$headerCol1 = New-Object System.Windows.Controls.ColumnDefinition
$headerCol1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$headerCol2 = New-Object System.Windows.Controls.ColumnDefinition
$headerCol2.Width = New-Object System.Windows.GridLength(34)
$headerGrid.ColumnDefinitions.Add($headerCol1)
$headerGrid.ColumnDefinitions.Add($headerCol2)

[System.Windows.Controls.Grid]::SetColumn($backgroundHeader, 0)
$headerGrid.Children.Add($backgroundHeader) | Out-Null

$backgroundClose = New-Object System.Windows.Controls.Button
$backgroundClose.Content = 'X'
$backgroundClose.Width = 30
$backgroundClose.Height = 28
$backgroundClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($backgroundClose, 1)
$headerGrid.Children.Add($backgroundClose) | Out-Null
$backgroundPanelStack.Children.Add($headerGrid) | Out-Null

$backgroundTransformPanel = New-Object System.Windows.Controls.StackPanel
$backgroundTransformPanel.Margin = '0,0,0,10'

$scaleLabel = New-Object System.Windows.Controls.TextBlock
$scaleLabel.Text = 'Scale'
$scaleLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($scaleLabel) | Out-Null

$backgroundScaleSlider = New-Object System.Windows.Controls.Slider
$backgroundScaleSlider.Minimum = 20
$backgroundScaleSlider.Maximum = 300
$backgroundScaleSlider.Width = 250
$backgroundScaleSlider.Margin = '0,2,0,6'
$script:backgroundScaleSlider = $backgroundScaleSlider
$backgroundTransformPanel.Children.Add($backgroundScaleSlider) | Out-Null

$xLabel = New-Object System.Windows.Controls.TextBlock
$xLabel.Text = 'Horizontal position'
$xLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($xLabel) | Out-Null

$backgroundXSlider = New-Object System.Windows.Controls.Slider
$backgroundXSlider.Minimum = -260
$backgroundXSlider.Maximum = 260
$backgroundXSlider.Width = 250
$backgroundXSlider.Margin = '0,2,0,6'
$script:backgroundXSlider = $backgroundXSlider
$backgroundTransformPanel.Children.Add($backgroundXSlider) | Out-Null

$yLabel = New-Object System.Windows.Controls.TextBlock
$yLabel.Text = 'Vertical position'
$yLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($yLabel) | Out-Null

$backgroundYSlider = New-Object System.Windows.Controls.Slider
$backgroundYSlider.Minimum = -280
$backgroundYSlider.Maximum = 280
$backgroundYSlider.Width = 250
$backgroundYSlider.Margin = '0,2,0,8'
$script:backgroundYSlider = $backgroundYSlider
$backgroundTransformPanel.Children.Add($backgroundYSlider) | Out-Null

$backgroundPanelStack.Children.Add($backgroundTransformPanel) | Out-Null

$backgroundScroll = New-Object System.Windows.Controls.ScrollViewer
$backgroundScroll.VerticalScrollBarVisibility = 'Auto'
$backgroundScroll.MaxHeight = 310
$backgroundList = New-Object System.Windows.Controls.StackPanel
$script:backgroundList = $backgroundList
$backgroundScroll.Content = $backgroundList
$backgroundPanelStack.Children.Add($backgroundScroll) | Out-Null
$backgroundPanel.Child = $backgroundPanelStack
$root.Children.Add($backgroundPanel) | Out-Null


$gridPanel = New-Object System.Windows.Controls.Border
$gridPanel.Width = 360
$gridPanel.MaxHeight = 450
$gridPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$gridPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$gridPanel.BorderThickness = 1
$gridPanel.CornerRadius = 10
$gridPanel.Padding = 12
$gridPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($gridPanel, 80)
[System.Windows.Controls.Canvas]::SetTop($gridPanel, 96)
[System.Windows.Controls.Panel]::SetZIndex($gridPanel, 3600)
$script:gridPanel = $gridPanel

$gridStack = New-Object System.Windows.Controls.StackPanel

$gridHeaderRow = New-Object System.Windows.Controls.Grid
$gridHeaderCol1 = New-Object System.Windows.Controls.ColumnDefinition
$gridHeaderCol1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$gridHeaderCol2 = New-Object System.Windows.Controls.ColumnDefinition
$gridHeaderCol2.Width = New-Object System.Windows.GridLength(34)
$gridHeaderRow.ColumnDefinitions.Add($gridHeaderCol1)
$gridHeaderRow.ColumnDefinitions.Add($gridHeaderCol2)

$gridHeader = New-Object System.Windows.Controls.TextBlock
$gridHeader.Text = 'Icon Grid'
$gridHeader.Foreground = [System.Windows.Media.Brushes]::White
$gridHeader.FontSize = 17
$gridHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($gridHeader, 0)
$gridHeaderRow.Children.Add($gridHeader) | Out-Null

$gridClose = New-Object System.Windows.Controls.Button
$gridClose.Content = 'X'
$gridClose.Width = 30
$gridClose.Height = 28
$gridClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($gridClose, 1)
$gridHeaderRow.Children.Add($gridClose) | Out-Null
$gridStack.Children.Add($gridHeaderRow) | Out-Null

$columnsRow = New-Object System.Windows.Controls.StackPanel
$columnsRow.Orientation = 'Horizontal'
$columnsRow.Margin = '0,10,0,10'

$columnsLabel = New-Object System.Windows.Controls.TextBlock
$columnsLabel.Text = 'Items per row'
$columnsLabel.Foreground = [System.Windows.Media.Brushes]::White
$columnsLabel.VerticalAlignment = 'Center'
$columnsLabel.Margin = '0,0,10,0'
$columnsRow.Children.Add($columnsLabel) | Out-Null

$columnsBox = New-Object System.Windows.Controls.TextBox
$columnsBox.Width = 52
$columnsBox.Height = 28
$columnsBox.VerticalContentAlignment = 'Center'
$script:columnsBox = $columnsBox
$columnsRow.Children.Add($columnsBox) | Out-Null
$gridStack.Children.Add($columnsRow) | Out-Null

$gridPreviewScroll = New-Object System.Windows.Controls.ScrollViewer
$gridPreviewScroll.VerticalScrollBarVisibility = 'Auto'
$gridPreviewScroll.HorizontalScrollBarVisibility = 'Disabled'
$gridPreviewScroll.MaxHeight = 320

$gridPreview = New-Object System.Windows.Controls.WrapPanel
$script:gridPreview = $gridPreview
$gridPreviewScroll.Content = $gridPreview
$gridStack.Children.Add($gridPreviewScroll) | Out-Null

$gridPanel.Child = $gridStack
$root.Children.Add($gridPanel) | Out-Null

$detailsPanel = New-Object System.Windows.Controls.Border
$detailsPanel.Width = [double]$script:config.detail.width
$detailsPanel.Height = [double]$script:config.detail.height
$detailsPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$detailsPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$detailsPanel.BorderThickness = 1
$detailsPanel.CornerRadius = 10
$detailsPanel.Padding = 14
$detailsPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($detailsPanel, ([double]$script:config.widget.designWidth - [double]$script:config.detail.width) / 2)
[System.Windows.Controls.Canvas]::SetTop($detailsPanel, ([double]$script:config.widget.designHeight - [double]$script:config.detail.height) / 2)
$script:detailsPanel = $detailsPanel

$detailScroll = New-Object System.Windows.Controls.ScrollViewer
$detailScroll.VerticalScrollBarVisibility = 'Auto'
$detailStack = New-Object System.Windows.Controls.StackPanel

$detailHeaderGrid = New-Object System.Windows.Controls.Grid
$detailHeaderGrid.Margin = '0,0,0,10'
$detailHeaderCol = New-Object System.Windows.Controls.ColumnDefinition
$detailHeaderCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$detailHeaderCloseCol = New-Object System.Windows.Controls.ColumnDefinition
$detailHeaderCloseCol.Width = New-Object System.Windows.GridLength(34)
$detailHeaderGrid.ColumnDefinitions.Add($detailHeaderCol)
$detailHeaderGrid.ColumnDefinitions.Add($detailHeaderCloseCol)

$detailHeader = New-Object System.Windows.Controls.TextBlock
$detailHeader.Text = 'Edit Task'
$detailHeader.Foreground = [System.Windows.Media.Brushes]::White
$detailHeader.FontSize = 18
$detailHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($detailHeader, 0)
$detailHeaderGrid.Children.Add($detailHeader) | Out-Null

$detailClose = New-Object System.Windows.Controls.Button
$detailClose.Content = 'X'
$detailClose.Width = 30
$detailClose.Height = 28
$detailClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($detailClose, 1)
$detailHeaderGrid.Children.Add($detailClose) | Out-Null
$detailStack.Children.Add($detailHeaderGrid) | Out-Null

$detailIconLabel = New-Object System.Windows.Controls.TextBlock
$detailIconLabel.Text = 'Icon'
$detailIconLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailIconLabel.Margin = '0,0,0,4'
$detailStack.Children.Add($detailIconLabel) | Out-Null

$detailIconRow = New-Object System.Windows.Controls.StackPanel
$detailIconRow.Orientation = 'Horizontal'
$detailIconRow.Margin = '0,0,0,8'
$detailCurrentIcon = New-Object System.Windows.Controls.Border
$detailCurrentIcon.Width = 72
$detailCurrentIcon.Height = 72
$detailCurrentIcon.BorderBrush = [System.Windows.Media.Brushes]::Gray
$detailCurrentIcon.BorderThickness = 1
$detailCurrentIcon.Padding = 5
$script:detailCurrentIcon = $detailCurrentIcon
$detailIconRow.Children.Add($detailCurrentIcon) | Out-Null
$detailChangeIcon = New-Object System.Windows.Controls.Button
$detailChangeIcon.Content = 'Change'
$detailChangeIcon.Width = 90
$detailChangeIcon.Height = 32
$detailChangeIcon.Margin = '12,20,0,0'
$detailChangeIcon.ToolTip = 'Change Icon'
$detailIconRow.Children.Add($detailChangeIcon) | Out-Null
$detailStack.Children.Add($detailIconRow) | Out-Null

$detailChooser = New-Object System.Windows.Controls.Border
$detailChooser.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(252, 18, 18, 22))
$detailChooser.BorderBrush = [System.Windows.Media.Brushes]::Gray
$detailChooser.BorderThickness = 1
$detailChooser.Padding = 10
$detailChooser.Visibility = 'Collapsed'
$detailChooserStack = New-Object System.Windows.Controls.StackPanel
$detailChooserHeader = New-Object System.Windows.Controls.DockPanel
$detailChooserTitle = New-Object System.Windows.Controls.TextBlock
$detailChooserTitle.Text = 'Choose Icon'
$detailChooserTitle.Foreground = [System.Windows.Media.Brushes]::White
$detailChooserTitle.FontWeight = 'Bold'
$detailChooserClose = New-Object System.Windows.Controls.Button
$detailChooserClose.Content = 'X'
$detailChooserClose.Width = 28
$detailChooserClose.Height = 26
$detailChooserClose.ToolTip = 'Close'
[System.Windows.Controls.DockPanel]::SetDock($detailChooserClose,'Right')
$detailChooserHeader.Children.Add($detailChooserClose) | Out-Null
$detailChooserHeader.Children.Add($detailChooserTitle) | Out-Null
$detailChooserStack.Children.Add($detailChooserHeader) | Out-Null
$detailIconScroll = New-Object System.Windows.Controls.ScrollViewer
$detailIconScroll.MaxHeight = 190
$detailIconScroll.VerticalScrollBarVisibility = 'Auto'
$detailIconGrid = New-Object System.Windows.Controls.WrapPanel
$script:detailIconGrid = $detailIconGrid
$detailIconScroll.Content = $detailIconGrid
$detailChooserStack.Children.Add($detailIconScroll) | Out-Null
$detailChooser.Child = $detailChooserStack
$detailStack.Children.Add($detailChooser) | Out-Null
$script:detailChooser = $detailChooser

$detailTitleLabel = New-Object System.Windows.Controls.TextBlock
$detailTitleLabel.Text = 'Title'
$detailTitleLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailTitleLabel.Margin = '0,10,0,4'
$detailStack.Children.Add($detailTitleLabel) | Out-Null

$detailTitleBox = New-Object System.Windows.Controls.TextBox
$detailTitleBox.Height = 30
$script:detailTitleBox = $detailTitleBox
$detailStack.Children.Add($detailTitleBox) | Out-Null

$detailDescriptionLabel = New-Object System.Windows.Controls.TextBlock
$detailDescriptionLabel.Text = 'Description'
$detailDescriptionLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailDescriptionLabel.Margin = '0,10,0,4'
$detailStack.Children.Add($detailDescriptionLabel) | Out-Null

$detailDescriptionBox = New-Object System.Windows.Controls.TextBox
$detailDescriptionBox.Height = 82
$detailDescriptionBox.AcceptsReturn = $true
$detailDescriptionBox.TextWrapping = 'Wrap'
$script:detailDescriptionBox = $detailDescriptionBox
$detailStack.Children.Add($detailDescriptionBox) | Out-Null

$detailActions = New-Object System.Windows.Controls.StackPanel
$detailActions.Orientation = 'Horizontal'
$detailActions.HorizontalAlignment = 'Right'
$detailActions.Margin = '0,14,0,0'

$detailDelete = New-Object System.Windows.Controls.Button
$detailDelete.Content = 'Delete'
$detailDelete.Width = 78
$detailDelete.Height = 30
$detailDelete.Margin = '0,0,8,0'
$detailDelete.ToolTip = 'Delete Task'

$detailSave = New-Object System.Windows.Controls.Button
$detailSave.Content = 'Save'
$detailSave.Width = 78
$detailSave.Height = 30
$detailSave.ToolTip = 'Save Task'

$detailActions.Children.Add($detailDelete) | Out-Null
$detailActions.Children.Add($detailSave) | Out-Null
$detailStack.Children.Add($detailActions) | Out-Null

$detailScroll.Content = $detailStack
$detailsPanel.Child = $detailScroll
$root.Children.Add($detailsPanel) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($detailsPanel, 4000)

$addPanel = New-Object System.Windows.Controls.Border
$addPanel.Width = 360
$addPanel.MaxHeight = 500
$addPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$addPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$addPanel.BorderThickness = 1
$addPanel.CornerRadius = 10
$addPanel.Padding = 14
$addPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($addPanel, 80)
[System.Windows.Controls.Canvas]::SetTop($addPanel, 78)
$script:addPanel = $addPanel

$addScroll = New-Object System.Windows.Controls.ScrollViewer
$addScroll.VerticalScrollBarVisibility = 'Auto'
$addStack = New-Object System.Windows.Controls.StackPanel

$addHeaderGrid = New-Object System.Windows.Controls.Grid
$addHeaderGrid.Margin = '0,0,0,10'
$addHeaderCol = New-Object System.Windows.Controls.ColumnDefinition
$addHeaderCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$addHeaderCloseCol = New-Object System.Windows.Controls.ColumnDefinition
$addHeaderCloseCol.Width = New-Object System.Windows.GridLength(34)
$addHeaderGrid.ColumnDefinitions.Add($addHeaderCol)
$addHeaderGrid.ColumnDefinitions.Add($addHeaderCloseCol)

$addHeader = New-Object System.Windows.Controls.TextBlock
$addHeader.Text = 'New Task'
$addHeader.Foreground = [System.Windows.Media.Brushes]::White
$addHeader.FontSize = 18
$addHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($addHeader, 0)
$addHeaderGrid.Children.Add($addHeader) | Out-Null

$addClose = New-Object System.Windows.Controls.Button
$script:addCloseButton = $addClose
$addClose.Content = 'X'
$addClose.Width = 30
$addClose.Height = 28
$addClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($addClose, 1)
$addHeaderGrid.Children.Add($addClose) | Out-Null
$addStack.Children.Add($addHeaderGrid) | Out-Null

$addIconLabel = New-Object System.Windows.Controls.TextBlock
$addIconLabel.Text = 'Icon'
$addIconLabel.Foreground = [System.Windows.Media.Brushes]::White
$addIconLabel.Margin = '0,0,0,4'
$addStack.Children.Add($addIconLabel) | Out-Null

$addIconScroll = New-Object System.Windows.Controls.ScrollViewer
$addIconScroll.HorizontalScrollBarVisibility = 'Disabled'
$addIconScroll.VerticalScrollBarVisibility = 'Auto'
$addIconScroll.MaxHeight = 180
$addIconGrid = New-Object System.Windows.Controls.WrapPanel
$script:addIconGrid = $addIconGrid
$addIconScroll.Content = $addIconGrid
$addStack.Children.Add($addIconScroll) | Out-Null

$titleLabel = New-Object System.Windows.Controls.TextBlock
$titleLabel.Text = 'Title'
$titleLabel.Foreground = [System.Windows.Media.Brushes]::White
$titleLabel.Margin = '0,10,0,4'
$addStack.Children.Add($titleLabel) | Out-Null

$titleBox = New-Object System.Windows.Controls.TextBox
$script:addTitleBox = $titleBox
$titleBox.Height = 30
$addStack.Children.Add($titleBox) | Out-Null

$descLabel = New-Object System.Windows.Controls.TextBlock
$descLabel.Text = 'Description'
$descLabel.Foreground = [System.Windows.Media.Brushes]::White
$descLabel.Margin = '0,10,0,4'
$addStack.Children.Add($descLabel) | Out-Null

$descBox = New-Object System.Windows.Controls.TextBox
$script:addDescriptionBox = $descBox
$descBox.Height = 82
$descBox.AcceptsReturn = $true
$descBox.TextWrapping = 'Wrap'
$addStack.Children.Add($descBox) | Out-Null

$createButton = New-Object System.Windows.Controls.Button
$script:addCreateButton = $createButton
$createButton.Content = 'Create'
$createButton.Width = 90
$createButton.Height = 32
$createButton.HorizontalAlignment = 'Right'
$createButton.Margin = '0,14,0,0'
$createButton.ToolTip = 'Create Task'
$addStack.Children.Add($createButton) | Out-Null

$addScroll.Content = $addStack
$addPanel.Child = $addScroll
$root.Children.Add($addPanel) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($addPanel, 4000)

$script:opacitySliderUpdating = $false

$opacitySlider.Add_ValueChanged({
    param($s, $e)

    if ($script:opacitySliderUpdating) { return }
    if ($script:editMode) { return }

    $value = [Math]::Max(20.0, [Math]::Min(100.0, [double]$s.Value))
    $opacity = $value / 100.0

    $script:window.Opacity = $opacity
    $script:config.widget.opacity = [Math]::Round($opacity, 2)
    $script:opacityLabel.Text = ([int][Math]::Round($value)).ToString() + '%'
})

$opacitySlider.Add_PreviewMouseLeftButtonUp({
    if ($script:editMode) { return }
    Save-Config
})

$script:resizeBaseWidth = 0.0
$script:resizeBaseHeight = 0.0
$script:resizeAccumulated = 0.0

$resizeButton.Add_DragStarted({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $script:resizeBaseWidth = [double]$script:window.Width
    $script:resizeBaseHeight = [double]$script:window.Height
    $script:resizeAccumulated = 0.0
})

$resizeButton.Add_DragDelta({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $horizontal = [double]$e.HorizontalChange
    $vertical = [double]$e.VerticalChange
    $script:resizeAccumulated += (($horizontal - $vertical) * 0.5)

    $minWidth = if ($null -ne $script:config.resize.minWidth) {
        [double]$script:config.resize.minWidth
    }
    else {
        320.0
    }

    $maxWidth = if ($null -ne $script:config.resize.maxWidth) {
        [double]$script:config.resize.maxWidth
    }
    else {
        1100.0
    }

    $newWidth = [Math]::Max(
        $minWidth,
        [Math]::Min(
            $maxWidth,
            ([double]$script:resizeBaseWidth + [double]$script:resizeAccumulated)
        )
    )

    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight
    $aspect = $designHeight * (1.0 / $designWidth)
    $newHeight = $newWidth * $aspect

    $bottom = [double]$script:window.Top + [double]$script:window.Height

    $script:config.widget.width = [Math]::Round($newWidth, 1)
    $script:config.widget.height = [Math]::Round($newHeight, 1)

    $script:window.Width = $newWidth
    $script:window.Height = $newHeight
    $script:window.Top = $bottom - $newHeight

    $script:config.widget.top = [Math]::Round([double]$script:window.Top, 1)
})

$resizeButton.Add_DragCompleted({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $script:config.widget.width = [Math]::Round([double]$script:window.Width, 1)
    $script:config.widget.height = [Math]::Round([double]$script:window.Height, 1)
    Ensure-WidgetOnVisibleDisplay $false | Out-Null
    Save-WidgetPlacement
})


function Add-BackgroundOptionRow($entry) {
    $row = New-Object System.Windows.Controls.Grid
    $row.Height = 42
    $row.Margin = '0,0,0,6'

    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = New-Object System.Windows.GridLength(38)
    $row.ColumnDefinitions.Add($col1)
    $row.ColumnDefinitions.Add($col2)

    $select = New-Object System.Windows.Controls.Button
    $select.Content = [string]$entry.name
    $select.ToolTip = [string]$entry.name
    $select.Tag = [string]$entry.file
    $select.HorizontalContentAlignment = 'Left'
    $select.Padding = '10,0,10,0'
    $select.Height = 36

    if ([string]$entry.file -eq [string]$script:editBackgroundFile) {
        $select.FontWeight = 'Bold'
    }

    $select.Add_Click({
        param($s, $e)

        if (-not $script:editMode) { return }

        Push-EditUndo
        $script:editBackgroundFile = [string]$s.Tag
        Render-Background
        Render-BackgroundChoices
        $script:backgroundPanel.Visibility = 'Collapsed'
    })

    [System.Windows.Controls.Grid]::SetColumn($select, 0)
    $row.Children.Add($select) | Out-Null

    if (-not [bool]$entry.protected) {
        $delete = New-Object System.Windows.Controls.Button
        $delete.Content = 'X'
        $delete.ToolTip = 'Delete Background'
        $delete.Tag = [string]$entry.id
        $delete.Width = 32
        $delete.Height = 32
        $delete.Margin = '4,2,0,2'

        $delete.Add_Click({
            param($s, $e)

            if (-not $script:editMode) { return }

            $id = [string]$s.Tag

            if ($id -eq 'default') { return }

            Push-EditUndo
            [void]$script:pendingDeletedBackgroundIds.Add($id)

            $registry = Read-BackgroundRegistry
            $entryToDelete = @($registry.backgrounds | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1

            if ($null -ne $entryToDelete -and [string]$entryToDelete.file -eq [string]$script:editBackgroundFile) {
                $default = Get-DefaultBackground
                $script:editBackgroundFile = [string]$default.file
                Render-Background
            }

            Render-BackgroundChoices
        })

        [System.Windows.Controls.Grid]::SetColumn($delete, 1)
        $row.Children.Add($delete) | Out-Null
    }

    $script:backgroundList.Children.Add($row) | Out-Null
}

function Render-BackgroundChoices {
    if ($null -eq $script:backgroundList) { return }

    $script:backgroundList.Children.Clear()

    $browse = New-Object System.Windows.Controls.Button
    $browse.Content = 'Browse in PC...'
    $browse.ToolTip = 'Browse Backgrounds'
    $browse.Height = 38
    $browse.Margin = '0,0,0,10'
    $browse.FontWeight = 'SemiBold'

    $browse.Add_Click({
        if (-not $script:editMode) { return }

        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Choose PNG background'
        $dialog.Filter = 'PNG image (*.png)|*.png'
        $dialog.Multiselect = $false

        if ($dialog.ShowDialog() -ne $true) { return }

        Add-Type -AssemblyName Microsoft.VisualBasic
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            'Name for this background:',
            'Background name',
            [System.IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($name)) { return }

        $registry = Read-BackgroundRegistry

        if (@($registry.backgrounds | Where-Object { [string]$_.name -ieq $name }).Count -gt 0) {
            [System.Windows.MessageBox]::Show('A background with this name already exists.', 'Desktop Widget') | Out-Null
            return
        }

        $id = 'bg-' + [Guid]::NewGuid().ToString('N')
        $relative = 'backgrounds/' + $id + '.png'
        $destination = Join-Path $base $relative

        Copy-Item -LiteralPath $dialog.FileName -Destination $destination -Force

        $newEntry = [pscustomobject][ordered]@{
            id = $id
            name = $name
            file = $relative
            protected = $false
        }

        $registry.backgrounds = @($registry.backgrounds) + @($newEntry)
        Save-BackgroundRegistry $registry

        Push-EditUndo
        $script:editBackgroundFile = $relative
        Render-Background
        Render-BackgroundChoices
        $script:backgroundPanel.Visibility = 'Collapsed'
    })

    $script:backgroundList.Children.Add($browse) | Out-Null

    $registry = Read-BackgroundRegistry

    foreach ($entry in @($registry.backgrounds)) {
        if ($script:pendingDeletedBackgroundIds.Contains([string]$entry.id)) {
            continue
        }

        Add-BackgroundOptionRow $entry
    }
}

function Commit-BackgroundEdits {
    $registry = Read-BackgroundRegistry
    $kept = @()

    foreach ($entry in @($registry.backgrounds)) {
        $id = [string]$entry.id

        if ($script:pendingDeletedBackgroundIds.Contains($id) -and -not [bool]$entry.protected) {
            $path = Join-Path $base ([string]$entry.file)

            if (Test-Path $path) {
                Remove-Item -LiteralPath $path -Force
            }

            continue
        }

        $kept += $entry
    }

    $registry.backgrounds = @($kept)
    Save-BackgroundRegistry $registry
    $script:pendingDeletedBackgroundIds.Clear()
}


$backgroundClose.Add_Click({
    $script:backgroundPanel.Visibility = 'Collapsed'
})

$backgroundScaleSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundScale = [double]$s.Value / 100.0
    Render-Background
})

$backgroundXSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundOffsetX = [double]$s.Value
    Render-Background
})

$backgroundYSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundOffsetY = [double]$s.Value
    Render-Background
})

function Show-Widget {
    if ($script:exiting) { return }
    if ($null -eq $script:window) { return }

    $script:userHidden = $false

    if (-not $script:window.IsVisible) {
        $script:window.Show()
    }

    $script:window.WindowState = 'Normal'
    $script:window.Topmost = [bool]$script:config.widget.topmost
    Ensure-WidgetOnVisibleDisplay $true | Out-Null
    $script:window.Activate() | Out-Null
}


function Exit-Widget {
    if ($script:exiting) { return }

    if ($script:editMode) {
        Cancel-EditSession
    }

    $script:exiting = $true
    $script:userHidden = $true

    if ($null -ne $script:reloadTimer) { $script:reloadTimer.Stop() }
    if ($null -ne $script:desktopTimer) { $script:desktopTimer.Stop() }

    if ($null -ne $script:tray) {
        $script:tray.Visible = $false
        $script:tray.Dispose()
    }

    if ($null -ne $script:trayIcon) {
        $script:trayIcon.Dispose()
        $script:trayIcon = $null
    }

    if ($null -ne $script:window) {
        $script:config.widget.width = [Math]::Round([double]$script:window.Width, 1)
        $script:config.widget.height = [Math]::Round([double]$script:window.Height, 1)
        Save-WidgetPlacement
        $script:window.Close()
    }

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown(
        [System.Windows.Threading.DispatcherPriority]::Background
    )
}

function Hide-Widget {
    $script:userHidden = $true
    $script:window.Hide()
}

$closeButton.Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $false
})

$closeButton.Add_Click({ Exit-Widget })
$minimizeButton.Add_Click({ if ($script:editMode) { Cancel-EditSession }; Hide-Widget })
$detailChangeIcon.Add_Click({
    Populate-IconGrid $script:detailIconGrid $script:detailSelectedIcon ([int]$script:config.icons.columns) 'detail'
    $script:detailChooser.Visibility = 'Visible'
})
$detailChooserClose.Add_Click({ $script:detailChooser.Visibility = 'Collapsed' })
$detailIconGrid.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender,$e)
    $btn = $e.OriginalSource
    while ($null -ne $btn -and -not ($btn -is [System.Windows.Controls.Button])) { $btn = [System.Windows.Media.VisualTreeHelper]::GetParent($btn) }
    if ($null -eq $btn -or [string]::IsNullOrWhiteSpace([string]$btn.Tag)) { return }
    $script:detailSelectedIcon = [string]$btn.Tag
    $entry = Get-IconEntry $script:detailSelectedIcon
    if ($null -ne $entry) { $script:detailCurrentIcon.Child = New-ImageControl ([string]$entry.file) 62 }
    $script:detailChooser.Visibility = 'Collapsed'
    $e.Handled = $true
})

$detailDelete.Add_Click({
    if ([string]::IsNullOrWhiteSpace([string]$script:selectedTaskId)) { return }

    $taskId = [string]$script:selectedTaskId
    $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $taskId })
    Save-Tasks
    $script:selectedTaskId = $null
    
    Render-Tasks
})

$detailSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace([string]$script:selectedTaskId)) { return }

    $title = $script:detailTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $task = Get-TaskById ([string]$script:selectedTaskId)
    if ($null -eq $task) { return }

    $task.title = $title
    $task.description = $script:detailDescriptionBox.Text.Trim()
    $task.icon = [string]$script:detailSelectedIcon
    Save-Tasks
    
    Render-Tasks
})

$detailClose.Add_Click({
    $script:selectedTaskId = $null
    
})

$addClose.Add_Click({ Close-AddTaskPanel })

$editButton.Add_Click({
    if (-not $script:editMode) {
        $script:editSnapshot = Copy-JsonObject $script:area
        $script:editWorkingArea = Copy-JsonObject $script:area
        $script:editSnapshotBackgroundFile = [string]$script:config.background.file
        $script:editBackgroundFile = [string]$script:config.background.file
        $script:editSnapshotBackgroundScale = [double]$script:config.background.scale
        $script:editSnapshotBackgroundOffsetX = [double]$script:config.background.offsetX
        $script:editSnapshotBackgroundOffsetY = [double]$script:config.background.offsetY
        $script:editBackgroundScale = [double]$script:config.background.scale
        $script:editBackgroundOffsetX = [double]$script:config.background.offsetX
        $script:editBackgroundOffsetY = [double]$script:config.background.offsetY
        $script:editSnapshotAddX = $script:config.buttons.addX
        $script:editSnapshotAddY = $script:config.buttons.addY
        $script:editSnapshotAddSize = $script:config.buttons.addSize
        $script:editAddX = $script:config.buttons.addX
        $script:editAddY = $script:config.buttons.addY
        $script:editSnapshotGridColumns = [int]$script:config.icons.columns
        $script:editGridColumns = [int]$script:config.icons.columns
        $script:pendingDeletedBackgroundIds.Clear()
        $script:editUndoStack.Clear()
        $script:editMode = $true

        Set-EditButtonVisual $true
        $script:clearButton.Visibility = 'Visible'
        $script:borderToggle.Visibility = 'Visible'
        $script:cancelEditButton.Visibility = 'Visible'
        $script:backgroundButton.Visibility = 'Visible'
        $script:gridButton.Visibility = 'Visible'
        
        $script:backgroundPanel.Visibility = 'Collapsed'
        $script:gridPanel.Visibility = 'Collapsed'
        $script:taskLayer.IsHitTestVisible = $false
        $script:editorLayer.IsHitTestVisible = $true
        $script:resizeButton.Visibility = 'Collapsed'
        $script:opacitySlider.Visibility = 'Collapsed'
        $script:opacityLabel.Visibility = 'Collapsed'

        Hide-Panel
        Update-EditButtons
        Apply-Config
        Render-Area
        Render-EditorNodes
        return
    }

    if ($null -ne $script:draggingEditorNode) {
        $script:draggingEditorNode.ReleaseMouseCapture()
        $script:draggingEditorNode = $null
        $script:draggingEditorIndex = -1
    }

    $script:area = Copy-JsonObject $script:editWorkingArea
    Save-Area $script:area
    $script:config.background.file = [string]$script:editBackgroundFile
    $script:config.background.scale = [Math]::Round([double]$script:editBackgroundScale, 3)
    $script:config.background.offsetX = [Math]::Round([double]$script:editBackgroundOffsetX, 1)
    $script:config.background.offsetY = [Math]::Round([double]$script:editBackgroundOffsetY, 1)
    $script:config.buttons.addX = $script:editAddX
    $script:config.buttons.addY = $script:editAddY
    $script:config.icons.columns = [int]$script:editGridColumns
    Commit-BackgroundEdits
    Save-Config

    $script:editMode = $false
    $script:editSnapshot = $null
    $script:editWorkingArea = $null
    $script:editUndoStack.Clear()

    Set-EditButtonVisual $false
    $script:undoButton.Visibility = 'Collapsed'
    $script:clearButton.Visibility = 'Collapsed'
    $script:borderToggle.Visibility = 'Collapsed'
    $script:cancelEditButton.Visibility = 'Collapsed'
    $script:backgroundButton.Visibility = 'Collapsed'
    $script:gridButton.Visibility = 'Collapsed'
    $script:backgroundPanel.Visibility = 'Collapsed'
    $script:gridPanel.Visibility = 'Collapsed'
    $script:taskLayer.IsHitTestVisible = $true
    $script:editorLayer.IsHitTestVisible = $false

    Apply-Config

    try {
        Normalize-Tasks-ToArea
    }
    catch {
        Render-Tasks
    }

    Render-Background
    Render-Area
    Render-EditorNodes
    Render-Tasks
})

$undoButton.Add_Click({
    if (-not $script:editMode -or $script:editUndoStack.Count -eq 0) { return }

    $checkpoint = $script:editUndoStack.Pop()
    $script:editWorkingArea = Copy-JsonObject $checkpoint.area
    $script:editBackgroundFile = [string]$checkpoint.backgroundFile
    $script:editBackgroundScale = [double]$checkpoint.backgroundScale
    $script:editBackgroundOffsetX = [double]$checkpoint.backgroundOffsetX
    $script:editBackgroundOffsetY = [double]$checkpoint.backgroundOffsetY
    $script:editAddX = $checkpoint.addX
    $script:editAddY = $checkpoint.addY
    $script:editGridColumns = [int]$checkpoint.gridColumns

    Update-EditButtons
    Apply-Config
    Render-Area
    Render-EditorNodes
    Render-Background

    if ($script:gridPanel.Visibility -eq 'Visible') {
        $script:columnsBox.Text = [string]$script:editGridColumns
        Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview'
    }
})

$clearButton.Add_Click({
    if (-not $script:editMode) { return }

    Push-EditUndo

    $defaultBackground = Get-DefaultBackground
    $defaultBackgroundFile = [string]$defaultBackground.file
    $useDefaultArea = -not [string]::IsNullOrWhiteSpace($defaultBackgroundFile)

    if ($useDefaultArea) {
        $script:editWorkingArea = Read-DefaultArea
    }
    else {
        $script:editWorkingArea = New-FactoryArea
    }

    $script:editBackgroundFile = $defaultBackgroundFile
    $script:editBackgroundScale = 1.0
    $script:editBackgroundOffsetX = 0.0
    $script:editBackgroundOffsetY = 0.0
    $script:editAddX = $null
    $script:editAddY = $null
    $script:editGridColumns = 3

    Update-EditButtons
    Render-Area
    Render-EditorNodes
    Render-Background
    Render-BackgroundChoices
    Apply-Config

    if ($script:gridPanel.Visibility -eq 'Visible') {
        $script:columnsBox.Text = '3'
        Populate-IconGrid $script:gridPreview '' 3 'preview'
    }
})

$backgroundButton.Add_Click({
    if (-not $script:editMode) { return }

    if ($script:backgroundPanel.Visibility -eq 'Visible') {
        $script:backgroundPanel.Visibility = 'Collapsed'
        return
    }

    $script:backgroundScaleSlider.Value = [double]$script:editBackgroundScale * 100.0
    $script:backgroundXSlider.Value = [double]$script:editBackgroundOffsetX
    $script:backgroundYSlider.Value = [double]$script:editBackgroundOffsetY

    Render-BackgroundChoices
    $script:backgroundPanel.Visibility = 'Visible'
})

$gridButton.Add_Click({
    if (-not $script:editMode) { return }

    if ($script:gridPanel.Visibility -eq 'Visible') {
        $script:gridPanel.Visibility = 'Collapsed'
        return
    }

    $script:backgroundPanel.Visibility = 'Collapsed'
    $script:columnsBox.Text = [string]$script:editGridColumns
    Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview'
    $script:gridPanel.Visibility = 'Visible'
})

$gridClose.Add_Click({
    $script:gridPanel.Visibility = 'Collapsed'
})

$columnsBox.Add_TextChanged({
    if (-not $script:editMode) { return }

    $value = 0

    if ([int]::TryParse($script:columnsBox.Text, [ref]$value)) {
        $value = [Math]::Max(1, [Math]::Min(8, $value))

        if ($value -ne [int]$script:editGridColumns) {
            Push-EditUndo
            $script:editGridColumns = $value
        }

        Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview'
    }
})

$borderToggle.Add_Click({
    if (-not $script:editMode) { return }

    Push-EditUndo
    $script:editWorkingArea.borderVisible = -not [bool]$script:editWorkingArea.borderVisible
    Update-EditButtons
    Render-Area
    Render-EditorNodes
})

$cancelEditButton.Add_Click({
    Cancel-EditSession
})

$script:addDragActive = $false

$addButton.Add_PreviewMouseLeftButtonDown({
    param($s, $e)

    if (-not $script:editMode) {
        return
    }

    Push-EditUndo
    $script:addDragActive = $true
    [void]$s.CaptureMouse()
    $e.Handled = $true
})

$addButton.Add_PreviewMouseMove({
    param($s, $e)

    if (-not $script:editMode -or -not $script:addDragActive) { return }
    if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

    $p = $e.GetPosition($script:root)

    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight
    $size = [double]$script:addButton.Width
    $toolbarBottom = if ($null -ne $script:config.buttons.toolbarBottom) { [double]$script:config.buttons.toolbarBottom } else { 12.0 }
    $toolbarY = $designHeight - 42.0 - $toolbarBottom
    $maxY = $toolbarY - $size - 10.0

    $x = [Math]::Max(0.0, [Math]::Min($designWidth - $size, [double]$p.X - ($size * 0.5)))
    $y = [Math]::Max(0.0, [Math]::Min($maxY, [double]$p.Y - ($size * 0.5)))

    $centerX = $x + ($size * 0.5)
    $centerY = $y + ($size * 0.5)

    if (Point-InPolygon $centerX $centerY) {
        $e.Handled = $true
        return
    }

    $script:editAddX = [Math]::Round($x, 1)
    $script:editAddY = [Math]::Round($y, 1)

    [System.Windows.Controls.Canvas]::SetLeft($s, $script:editAddX)
    [System.Windows.Controls.Canvas]::SetTop($s, $script:editAddY)

    $sliderX = [Math]::Min(
        $designWidth - [double]$script:addSizeSlider.Width - 4.0,
        [double]$script:editAddX + $size + 8.0
    )
    $sliderY = [double]$script:editAddY + (($size - [double]$script:addSizeSlider.Height) * 0.5)

    [System.Windows.Controls.Canvas]::SetLeft($script:addSizeSlider, $sliderX)
    [System.Windows.Controls.Canvas]::SetTop($script:addSizeSlider, $sliderY)

    $e.Handled = $true
})

$addButton.Add_PreviewMouseLeftButtonUp({
    param($s, $e)

    if (-not $script:addDragActive) { return }

    $script:addDragActive = $false

    if ($s.IsMouseCaptured) {
        $s.ReleaseMouseCapture()
    }

    $e.Handled = $true
})

$script:addSizeSliderUpdating = $false

$addSizeSlider.Add_ValueChanged({
    param($s, $e)
    if ($script:addSizeSliderUpdating -or -not $script:editMode) { return }

    Push-EditUndo
    $script:config.buttons.addSize = [Math]::Round([double]$s.Value, 1)
    Apply-Config
})

$addSizeSlider.Add_PreviewMouseLeftButtonUp({
    if ($script:editMode) {
        Save-Config
    }
})

$addButton.Add_Click({
    Open-AddTaskPanel
})

$createButton.Add_Click({
    Create-NewTask
})

function Get-ButtonAncestor($element) {
    $current = $element

    while ($null -ne $current) {
        if ($current -is [System.Windows.Controls.Button]) {
            return $current
        }

        try {
            $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
        }
        catch {
            return $null
        }
    }

    return $null
}

$root.Add_MouseLeftButtonDown({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    if ($null -ne (Get-ButtonAncestor $e.OriginalSource)) {
        return
    }

    if ($null -ne $script:addPanel -and $script:addPanel.Visibility -eq 'Visible') {
        return
    }

    $cursor = [System.Windows.Forms.Cursor]::Position

    $script:widgetDragActive = $true
    $script:widgetDragStartMouseX = [double]$cursor.X
    $script:widgetDragStartMouseY = [double]$cursor.Y
    $script:widgetDragStartLeft = [double]$script:window.Left
    $script:widgetDragStartTop = [double]$script:window.Top
    $script:widgetNormalOpacity = [double]$script:window.Opacity

    $dragOpacity = if ($null -ne $script:config.drag.opacity) {
        [double]$script:config.drag.opacity
    }
    else {
        0.55
    }

    $script:window.Opacity = [Math]::Max(0.2, [Math]::Min(1.0, $dragOpacity))
    [void]$script:root.CaptureMouse()

    $e.Handled = $true
})

$root.Add_MouseMove({
    param($s, $e)

    if (-not $script:widgetDragActive) {
        return
    }

    if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
        return
    }

    $cursor = [System.Windows.Forms.Cursor]::Position

    $deltaX = [double]$cursor.X - [double]$script:widgetDragStartMouseX
    $deltaY = [double]$cursor.Y - [double]$script:widgetDragStartMouseY

    $script:window.Left = [double]$script:widgetDragStartLeft + $deltaX
    $script:window.Top = [double]$script:widgetDragStartTop + $deltaY

    $e.Handled = $true
})

$root.Add_MouseLeftButtonUp({
    param($s, $e)

    if (-not $script:widgetDragActive) {
        return
    }

    $script:widgetDragActive = $false

    if ($script:root.IsMouseCaptured) {
        $script:root.ReleaseMouseCapture()
    }

    $script:window.Opacity = [double]$script:widgetNormalOpacity
    Save-WidgetPlacement
    $e.Handled = $true
})

$root.Add_LostMouseCapture({
    if (-not $script:widgetDragActive) {
        return
    }

    $script:widgetDragActive = $false
    $script:window.Opacity = [double]$script:widgetNormalOpacity
    Save-WidgetPlacement
})

$window.Add_LocationChanged({
    if (-not $script:positionInitialized -or $script:widgetDragActive -or $script:suppressPositionSave) { return }
    Save-WidgetPlacement
})

$window.Add_StateChanged({
    if (-not $script:userHidden -and $script:window.WindowState -eq 'Minimized') {
        $script:window.WindowState = 'Normal'
        $script:window.Show()
    }
})

$window.Add_Closing({
    param($s, $e)

    if (-not $script:exiting) {
        $e.Cancel = $true
        Hide-Widget
    }
})

$window.Add_Closed({
    $script:exiting = $true
    if ($null -ne $script:reloadTimer) { $script:reloadTimer.Stop() }
    if ($null -ne $script:desktopTimer) { $script:desktopTimer.Stop() }
})

$tray = New-Object System.Windows.Forms.NotifyIcon
$trayIconPath = Join-Path $PSScriptRoot 'widget.ico'

if (Test-Path $trayIconPath) {
    $script:trayIcon = New-Object System.Drawing.Icon($trayIconPath)
    $tray.Icon = $script:trayIcon
}
else {
    $tray.Icon = [System.Drawing.SystemIcons]::Application
}

$tray.Text = 'Desktop Widget'
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add('Show')
$hideItem = $menu.Items.Add('Hide')
$exitItem = $menu.Items.Add('Exit')

$showItem.Add_Click({ Show-Widget })
$hideItem.Add_Click({ Hide-Widget })
$exitItem.Add_Click({ Exit-Widget })

$tray.ContextMenuStrip = $menu

$showFromTray = {
    $script:window.Dispatcher.BeginInvoke(
        [System.Action]{
            Show-Widget
        },
        [System.Windows.Threading.DispatcherPriority]::Send
    ) | Out-Null
}

$tray.Add_MouseDown({
    param($s, $e)

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $showFromTray
    }
})

$tray.Add_Click({
    if ([System.Windows.Forms.Control]::MouseButtons -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $showFromTray
    }
})

$tray.Add_DoubleClick({
    & $showFromTray
})

$script:tray = $tray

Set-EditButtonVisual $false
Apply-Config
Render-Tasks
Render-EditorNodes

$reloadTimer = New-Object System.Windows.Threading.DispatcherTimer
$reloadTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(5, [double]$script:config.refreshSeconds))
$reloadTimer.Add_Tick({ Reload-Files })
$script:reloadTimer = $reloadTimer
$reloadTimer.Start()

$desktopTimer = New-Object System.Windows.Threading.DispatcherTimer
$desktopTimer.Interval = [TimeSpan]::FromMilliseconds(700)
$desktopTimer.Add_Tick({
    if ($script:exiting) { return }

    try {
        $currentDisplaySignature = Get-DisplaySignature
        $displayChanged = $currentDisplaySignature -ne $script:displaySignature

        if ($displayChanged) {
            $script:displaySignature = $currentDisplaySignature
            Ensure-WidgetOnVisibleDisplay $true | Out-Null
        }

        if ($script:userHidden) { return }

        if (-not $script:window.IsVisible) {
            $script:window.Show()
            Ensure-WidgetOnVisibleDisplay $displayChanged | Out-Null
        }

        if ($script:window.WindowState -eq 'Minimized') {
            $script:window.WindowState = 'Normal'
        }

        $script:window.Topmost = [bool]$script:config.widget.topmost
    }
    catch {
        $script:desktopTimer.Stop()
    }
})
$script:desktopTimer = $desktopTimer
$desktopTimer.Start()

$window.Show()
Ensure-WidgetOnVisibleDisplay $false | Out-Null
$window.Activate() | Out-Null
[System.Windows.Threading.Dispatcher]::Run()
