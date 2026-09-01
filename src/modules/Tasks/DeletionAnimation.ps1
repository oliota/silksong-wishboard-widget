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

