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

