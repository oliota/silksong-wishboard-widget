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

