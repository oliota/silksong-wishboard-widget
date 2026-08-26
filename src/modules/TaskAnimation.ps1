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

function Start-TaskPlacementAnimation($task, [double[]]$position, [double]$taskSize, [scriptblock]$completed) {
    try {
        Stop-TaskPlacementAnimation
        $durationSeconds = 3.0
        if ($null -ne $script:config.animation -and $null -ne $script:config.animation.placementDurationSeconds) {
            $durationSeconds = [Math]::Max(0.2, [Math]::Min(30.0, [double]$script:config.animation.placementDurationSeconds))
        }
        $sourcePoint = Get-ScreenPointInDips $script:addSavingVisualHost ([System.Windows.Point]::new(
            [double]$script:addSavingVisualHost.ActualWidth * 0.5,
            [double]$script:addSavingVisualHost.ActualHeight * 0.5
        ))
        $destinationTopLeft = Get-ScreenPointInDips $script:taskLayer ([System.Windows.Point]::new($position[0], $position[1]))
        $destinationBottomRight = Get-ScreenPointInDips $script:taskLayer ([System.Windows.Point]::new($position[0] + $taskSize, $position[1] + $taskSize))
        $destinationWidth = [Math]::Max(12.0, [Math]::Abs($destinationBottomRight.X - $destinationTopLeft.X))
        $destinationHeight = [Math]::Max(12.0, [Math]::Abs($destinationBottomRight.Y - $destinationTopLeft.Y))
        $destinationPoint = [System.Windows.Point]::new($destinationTopLeft.X + ($destinationWidth * 0.5), $destinationTopLeft.Y + ($destinationHeight * 0.5))

        $virtualLeft = [double][System.Windows.SystemParameters]::VirtualScreenLeft
        $virtualTop = [double][System.Windows.SystemParameters]::VirtualScreenTop
        $overlay = New-Object System.Windows.Window
        $overlay.WindowStyle = 'None'
        $overlay.ResizeMode = 'NoResize'
        $overlay.AllowsTransparency = $true
        $overlay.Background = [System.Windows.Media.Brushes]::Transparent
        $overlay.ShowInTaskbar = $false
        $overlay.ShowActivated = $false
        $overlay.Topmost = $true
        $overlay.IsHitTestVisible = $false
        $overlay.Left = $virtualLeft
        $overlay.Top = $virtualTop
        $overlay.Width = [double][System.Windows.SystemParameters]::VirtualScreenWidth
        $overlay.Height = [double][System.Windows.SystemParameters]::VirtualScreenHeight

        $canvas = New-Object System.Windows.Controls.Canvas
        $overlay.Content = $canvas
        $sourceSize = 92.0
        $movingBadgeContent = New-TaskBadgeVisual $task $sourceSize
        $movingBadgeContent.Width = $sourceSize
        $movingBadgeContent.Height = $sourceSize
        $movingBadge = New-Object System.Windows.Controls.Viewbox
        $movingBadge.Stretch = [System.Windows.Media.Stretch]::Uniform
        $movingBadge.StretchDirection = [System.Windows.Controls.StretchDirection]::Both
        $movingBadge.Child = $movingBadgeContent
        $movingBadge.Width = $sourceSize
        $movingBadge.Height = $sourceSize
        $canvas.Children.Add($movingBadge) | Out-Null

        $sourceX = $sourcePoint.X - $virtualLeft
        $sourceY = $sourcePoint.Y - $virtualTop
        $destinationX = $destinationPoint.X - $virtualLeft
        $destinationY = $destinationPoint.Y - $virtualTop
        [System.Windows.Controls.Canvas]::SetLeft($movingBadge, $sourceX - ($sourceSize * 0.5))
        [System.Windows.Controls.Canvas]::SetTop($movingBadge, $sourceY - ($sourceSize * 0.5))

        $script:taskAnimationWindow = $overlay
        $overlay.Show()
        $overlay.UpdateLayout()
        $script:addWindow.Hide()

        $particles = [System.Collections.ArrayList]::new()
        $random = [System.Random]::new()
        $state = [pscustomobject]@{
            StartedAt = [DateTime]::UtcNow
            PreviousFrameAt = [DateTime]::UtcNow
            LastTrailAt = [DateTime]::UtcNow
            ArrivalAt = $null
            Completed = $false
        }
        $frameTimer = New-Object System.Windows.Threading.DispatcherTimer
        $frameTimer.Interval = [TimeSpan]::FromMilliseconds(16)
        $script:taskAnimationFrameTimer = $frameTimer
        $frameTimer.Add_Tick({
            $now = [DateTime]::UtcNow
            $delta = [Math]::Min(0.05, ($now - $state.PreviousFrameAt).TotalSeconds)
            $state.PreviousFrameAt = $now
            $progress = [Math]::Min(1.0, ($now - $state.StartedAt).TotalSeconds / $durationSeconds)
            $eased = $progress * $progress * (3.0 - (2.0 * $progress))
            $x = $sourceX + (($destinationX - $sourceX) * $eased)
            $y = $sourceY + (($destinationY - $sourceY) * $eased)
            $width = $sourceSize + (($destinationWidth - $sourceSize) * $eased)
            $height = $sourceSize + (($destinationHeight - $sourceSize) * $eased)

            if (-not $state.Completed) {
                $movingBadge.Width = $width
                $movingBadge.Height = $height
                [System.Windows.Controls.Canvas]::SetLeft($movingBadge, $x - ($width * 0.5))
                [System.Windows.Controls.Canvas]::SetTop($movingBadge, $y - ($height * 0.5))
                if (($now - $state.LastTrailAt).TotalMilliseconds -ge 95) {
                    $state.LastTrailAt = $now
                    $reverseAngle = [Math]::Atan2($sourceY - $destinationY, $sourceX - $destinationX)
                    Add-TaskSparkle $canvas $particles $x $y ($reverseAngle + (($random.NextDouble() - 0.5) * 1.5)) (24 + $random.NextDouble() * 38) (0.55 + $random.NextDouble() * 0.65) (7 + $random.NextDouble() * 9)
                }
                if ($progress -ge 1.0) {
                    $state.Completed = $true
                    $state.ArrivalAt = $now
                    $canvas.Children.Remove($movingBadge)
                    & $completed $task
                    for ($burstIndex = 0; $burstIndex -lt 20; $burstIndex++) {
                        $angle = (($burstIndex / 20.0) * [Math]::PI * 2.0) + (($random.NextDouble() - 0.5) * 0.2)
                        Add-TaskSparkle $canvas $particles $x $y $angle (48 + $random.NextDouble() * 82) (0.75 + $random.NextDouble() * 1.15) (8 + $random.NextDouble() * 12)
                    }
                }
            }

            for ($particleIndex = $particles.Count - 1; $particleIndex -ge 0; $particleIndex--) {
                $particle = $particles[$particleIndex]
                $particle.Age += $delta
                if ($particle.Age -ge $particle.Duration) {
                    $canvas.Children.Remove($particle.Element)
                    $particles.RemoveAt($particleIndex)
                    continue
                }
                $particle.X += $particle.VelocityX * $delta
                $particle.Y += $particle.VelocityY * $delta
                $ratio = $particle.Age / $particle.Duration
                $particleSize = $particle.Size * (1.0 - ($ratio * 0.7))
                $particle.Element.Width = $particleSize
                $particle.Element.Height = $particleSize
                $particle.Element.Opacity = 0.95 * (1.0 - $ratio)
                [System.Windows.Controls.Canvas]::SetLeft($particle.Element, $particle.X - ($particleSize * 0.5))
                [System.Windows.Controls.Canvas]::SetTop($particle.Element, $particle.Y - ($particleSize * 0.5))
            }

            if ($state.Completed -and $null -ne $state.ArrivalAt -and ($now - $state.ArrivalAt).TotalSeconds -ge 2.0) {
                Stop-TaskPlacementAnimation
            }
        }.GetNewClosure())
        $frameTimer.Start()
    }
    catch {
        Stop-TaskPlacementAnimation
        & $completed $task
    }
}

function Start-TaskDeletionAnimation($task, [scriptblock]$completed) {
    try {
        Stop-TaskPlacementAnimation
        $taskSize = [double]$script:area.taskSize
        $center = Get-ScreenPointInDips $script:taskLayer ([System.Windows.Point]::new([double]$task.x + ($taskSize * 0.5), [double]$task.y + ($taskSize * 0.5)))
        $virtualLeft = [double][System.Windows.SystemParameters]::VirtualScreenLeft
        $virtualTop = [double][System.Windows.SystemParameters]::VirtualScreenTop
        $overlay = New-Object System.Windows.Window
        $overlay.WindowStyle = 'None'
        $overlay.ResizeMode = 'NoResize'
        $overlay.AllowsTransparency = $true
        $overlay.Background = [System.Windows.Media.Brushes]::Transparent
        $overlay.ShowInTaskbar = $false
        $overlay.ShowActivated = $false
        $overlay.Topmost = $true
        $overlay.IsHitTestVisible = $false
        $overlay.Left = $virtualLeft
        $overlay.Top = $virtualTop
        $overlay.Width = [double][System.Windows.SystemParameters]::VirtualScreenWidth
        $overlay.Height = [double][System.Windows.SystemParameters]::VirtualScreenHeight
        $canvas = New-Object System.Windows.Controls.Canvas
        $overlay.Content = $canvas
        $script:taskAnimationWindow = $overlay
        $overlay.Show()
        $overlay.UpdateLayout()

        $x = $center.X - $virtualLeft
        $y = $center.Y - $virtualTop
        $particles = [System.Collections.ArrayList]::new()
        $random = [System.Random]::new()
        for ($burstIndex = 0; $burstIndex -lt 20; $burstIndex++) {
            $angle = (($burstIndex / 20.0) * [Math]::PI * 2.0) + (($random.NextDouble() - 0.5) * 0.2)
            Add-TaskSparkle $canvas $particles $x $y $angle (48 + $random.NextDouble() * 82) (0.75 + $random.NextDouble() * 1.15) (8 + $random.NextDouble() * 12)
        }
        & $completed $task

        $state = [pscustomobject]@{ PreviousFrameAt = [DateTime]::UtcNow; StartedAt = [DateTime]::UtcNow }
        $frameTimer = New-Object System.Windows.Threading.DispatcherTimer
        $frameTimer.Interval = [TimeSpan]::FromMilliseconds(16)
        $script:taskAnimationFrameTimer = $frameTimer
        $frameTimer.Add_Tick({
            $now = [DateTime]::UtcNow
            $delta = [Math]::Min(0.05, ($now - $state.PreviousFrameAt).TotalSeconds)
            $state.PreviousFrameAt = $now
            for ($particleIndex = $particles.Count - 1; $particleIndex -ge 0; $particleIndex--) {
                $particle = $particles[$particleIndex]
                $particle.Age += $delta
                if ($particle.Age -ge $particle.Duration) {
                    $canvas.Children.Remove($particle.Element)
                    $particles.RemoveAt($particleIndex)
                    continue
                }
                $particle.X += $particle.VelocityX * $delta
                $particle.Y += $particle.VelocityY * $delta
                $ratio = $particle.Age / $particle.Duration
                $particleSize = $particle.Size * (1.0 - ($ratio * 0.7))
                $particle.Element.Width = $particleSize
                $particle.Element.Height = $particleSize
                $particle.Element.Opacity = 0.95 * (1.0 - $ratio)
                [System.Windows.Controls.Canvas]::SetLeft($particle.Element, $particle.X - ($particleSize * 0.5))
                [System.Windows.Controls.Canvas]::SetTop($particle.Element, $particle.Y - ($particleSize * 0.5))
            }
            if ($particles.Count -eq 0 -or ($now - $state.StartedAt).TotalSeconds -ge 2.0) {
                Stop-TaskPlacementAnimation
            }
        }.GetNewClosure())
        $frameTimer.Start()
    }
    catch {
        Stop-TaskPlacementAnimation
        & $completed $task
    }
}
