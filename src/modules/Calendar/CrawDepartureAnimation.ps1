function Complete-CalendarSummonsCrawDeparture($flyingCraw, [bool]$restart) {
    Stop-WidgetTimer 'Summons.Departure'
    if ($null -ne $script:root) { $script:root.Children.Remove($flyingCraw) | Out-Null }
    if ($script:calendarSummonsCraw -eq $flyingCraw) { $script:calendarSummonsCraw = $null }
    if ($restart) {
        $events = @($script:calendarSummonsPendingEvents)
        $script:calendarSummonsPendingEvents = @()
        $script:calendarSummonsRestarting = $false
        $script:calendarSummonsActive = $false
        Show-CalendarSummons $events
        return
    }
    Remove-CalendarSummons
}

function Start-CalendarSummonsCrawDeparture([bool]$restart = $false) {
    $restingCraw = $script:calendarSummonsCraw
    if ($restingCraw -isnot [System.Windows.Controls.Image]) {
        if ($restart) {
            $events = @($script:calendarSummonsPendingEvents)
            $script:calendarSummonsPendingEvents = @()
            $script:calendarSummonsRestarting = $false
            $script:calendarSummonsActive = $false
            Show-CalendarSummons $events
        } else {
            Remove-CalendarSummons
        }
        return
    }
    $startX = [double][System.Windows.Controls.Canvas]::GetLeft($restingCraw)
    $startY = [double][System.Windows.Controls.Canvas]::GetTop($restingCraw)
    $width = [Math]::Max(1.0, [double]$restingCraw.Width)
    $height = [Math]::Max(1.0, [double]$restingCraw.Height)
    $designWidth = [double]$script:config.widget.designWidth
    $goRight = $startX -ge ($designWidth * 0.5)
    $targetX = if ($goRight) { $designWidth + $width + 40.0 } else { -$width - 40.0 }
    $script:root.Children.Remove($restingCraw)
    $script:calendarSummonsCraw = $null

    $flyingCraw = New-Object System.Windows.Controls.Image
    $flyingCraw.Width = $width
    $flyingCraw.Height = $height
    $flyingCraw.Stretch = 'Uniform'
    $flyingCraw.IsHitTestVisible = $false
    $flyingCraw.Opacity = 1.0
    $flyingCraw.RenderTransformOrigin = '0.5,0.5'
    $flyingCraw.RenderTransform = if ($goRight) { [System.Windows.Media.ScaleTransform]::new(-1, 1) } else { [System.Windows.Media.ScaleTransform]::new(1, 1) }
    Set-CalendarSummonsImage $flyingCraw 'craw-takeoff-0000.png'
    [System.Windows.Controls.Canvas]::SetLeft($flyingCraw, $startX)
    [System.Windows.Controls.Canvas]::SetTop($flyingCraw, $startY)
    $script:root.Children.Add($flyingCraw) | Out-Null
    [System.Windows.Controls.Panel]::SetZIndex($flyingCraw, 9000)
    $script:calendarSummonsCraw = $flyingCraw

    $frames = @('craw-takeoff-0000.png', 'craw-takeoff-0001.png', 'craw-takeoff-0002.png', 'craw-flight-0000.png', 'craw-flight-0001.png', 'craw-flight-0002.png', 'craw-flight-0003.png', 'craw-flight-0004.png', 'craw-flight-0005.png')
    $state = [pscustomobject]@{ StartedAt = [DateTime]::UtcNow; Frame = -1 }
    Start-WidgetTimer 'Summons.Departure' 16 ({
        $elapsed = ([DateTime]::UtcNow - $state.StartedAt).TotalSeconds
        $progress = [Math]::Min(1.0, $elapsed / 1.35)
        $eased = $progress * $progress * (3.0 - (2.0 * $progress))
        $frame = [Math]::Min($frames.Count - 1, [int][Math]::Floor($progress * $frames.Count))
        if ($frame -ne $state.Frame) {
            Set-CalendarSummonsImage $flyingCraw $frames[$frame]
            $state.Frame = $frame
        }
        [System.Windows.Controls.Canvas]::SetLeft($flyingCraw, $startX + (($targetX - $startX) * $eased))
        [System.Windows.Controls.Canvas]::SetTop($flyingCraw, $startY - (150.0 * $eased) - ([Math]::Sin($progress * [Math]::PI * 5.0) * 5.0))
        if ($progress -ge 1.0) {
            Complete-CalendarSummonsCrawDeparture $flyingCraw $restart
        }
    }.GetNewClosure()) | Out-Null
}
