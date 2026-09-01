function Get-ScreenPointInDips($visual, [System.Windows.Point]$point) {
    $screenPoint = $visual.PointToScreen($point)
    $source = [System.Windows.PresentationSource]::FromVisual($visual)
    if ($null -ne $source -and $null -ne $source.CompositionTarget) {
        return $source.CompositionTarget.TransformFromDevice.Transform($screenPoint)
    }
    $screenPoint
}

function Add-TaskSparkle($canvas, $particles, [double]$x, [double]$y, [double]$angle, [double]$speed, [double]$duration, [double]$size) {
    $element = New-DecorativeAsset 'backgrounds/task_sparkle.png' $size
    $element.Width = $size
    $element.Height = $size
    $element.Opacity = 0.95
    $element.IsHitTestVisible = $false
    [System.Windows.Controls.Canvas]::SetLeft($element, $x - ($size * 0.5))
    [System.Windows.Controls.Canvas]::SetTop($element, $y - ($size * 0.5))
    $canvas.Children.Add($element) | Out-Null
    $particles.Add([pscustomobject]@{
        Element = $element
        X = $x
        Y = $y
        VelocityX = [Math]::Cos($angle) * $speed
        VelocityY = [Math]::Sin($angle) * $speed
        Age = 0.0
        Duration = $duration
        Size = $size
    }) | Out-Null
}

function Stop-TaskPlacementAnimation {
    if ($null -ne $script:taskAnimationFrameTimer) {
        $script:taskAnimationFrameTimer.Stop()
        $script:taskAnimationFrameTimer = $null
    }
    if ($null -ne $script:taskAnimationWindow) {
        $script:taskAnimationWindow.Close()
        $script:taskAnimationWindow = $null
    }
}

