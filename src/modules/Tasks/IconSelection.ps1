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

