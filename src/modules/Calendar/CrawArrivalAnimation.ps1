function Show-CalendarSummons($events) {
    $pending = @($events | Where-Object { $null -eq (Get-TaskById ('calendar-' + [string]$_.id)) })
    if ($pending.Count -eq 0) { return }
    $pendingIds = @($pending | ForEach-Object { [string]$_.id } | Sort-Object)
    $activeIds = @($script:calendarSummonsEventIds | Sort-Object)
    if ($script:calendarSummonsActive) {
        if (($pendingIds -join '|') -eq ($activeIds -join '|')) { return }
        Restart-CalendarSummons $pending
        return
    }
    $script:calendarSummonsActive = $true
    $script:calendarSummonsEvents = $pending
    $script:calendarSummonsEventIds = @($pending | ForEach-Object { [string]$_.id })
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight
    $addLeft = [double][System.Windows.Controls.Canvas]::GetLeft($script:addButton)
    $addCenter = $addLeft + ([double]$script:addButton.Width * 0.5)
    $pinHeight = 120.0
    $pinWidth = 62.0
    $groundY = $designHeight - $pinHeight - 54.0
    $flightWidth = 75.0
    $flightHeight = 50.0
    $minFlightX = 8.0
    $maxFlightX = [Math]::Max($minFlightX, $designWidth - $flightWidth - 8.0)
    $dropCrawX = [Math]::Max($minFlightX, [Math]::Min($maxFlightX, $addCenter - ($flightWidth * 0.5)))
    $restX = if (($addCenter + ($pinWidth * 0.5) + 82.0) -le $designWidth) { $addCenter + ($pinWidth * 0.5) + 6.0 } else { $addCenter - ($pinWidth * 0.5) - 78.0 }
    $restX = [Math]::Max(8.0, [Math]::Min($designWidth - 78.0, $restX))
    $restY = $groundY + $pinHeight - 66.0

    $craw = New-Object System.Windows.Controls.Image
    $craw.Width = $flightWidth
    $craw.Height = $flightHeight
    $craw.Stretch = 'Uniform'
    $craw.RenderTransformOrigin = '0.5,0.5'
    $craw.IsHitTestVisible = $false
    Set-CalendarSummonsImage $craw 'craw-hover-0000.png'
    $script:root.Children.Add($craw) | Out-Null
    [System.Windows.Controls.Panel]::SetZIndex($craw, 4000)
    $script:calendarSummonsCraw = $craw

    $pinImage = New-Object System.Windows.Controls.Image
    $pinImage.Stretch = 'Uniform'
    Set-CalendarSummonsImage $pinImage 'craw_court_summons_pin0000.png'
    $pin = New-Object System.Windows.Controls.Button
    $pin.Width = $pinWidth
    $pin.Height = $pinHeight
    $pin.Padding = 0
    $pin.BorderThickness = 0
    $pin.Background = [System.Windows.Media.Brushes]::Transparent
    $pin.Cursor = [System.Windows.Input.Cursors]::Hand
    $pin.Focusable = $false
    $pin.IsTabStop = $false
    $pin.Template = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>
</ControlTemplate>
'@)
    $pin.Content = $pinImage
    $pin.Visibility = 'Collapsed'
    $pin.Add_Click({ Start-CalendarSummonsCreation })
    $script:root.Children.Add($pin) | Out-Null
    [System.Windows.Controls.Panel]::SetZIndex($pin, 4001)
    $script:calendarSummonsPin = $pin
    $script:calendarSummonsPinImage = $pinImage

    $glow = New-Object System.Windows.Shapes.Ellipse
    $glow.Width = 46.0
    $glow.Height = 46.0
    $glow.IsHitTestVisible = $false
    $glow.Visibility = 'Collapsed'
    $glow.RenderTransformOrigin = '0.5,0.5'
    $glow.RenderTransform = [System.Windows.Media.ScaleTransform]::new(1, 1)
    $gradient = New-Object System.Windows.Media.RadialGradientBrush
    $gradient.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.ColorConverter]::ConvertFromString('#FFFFFFFF'), 0.0)) | Out-Null
    $gradient.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.ColorConverter]::ConvertFromString('#E8FFFFFF'), 0.42)) | Out-Null
    $gradient.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.ColorConverter]::ConvertFromString('#00FFFFFF'), 1.0)) | Out-Null
    $glow.Fill = $gradient
    [System.Windows.Controls.Canvas]::SetLeft($glow, $addCenter - ($glow.Width * 0.5))
    [System.Windows.Controls.Canvas]::SetTop($glow, $groundY + ($pinHeight * 0.46) - ($glow.Height * 0.5))
    $script:root.Children.Add($glow) | Out-Null
    [System.Windows.Controls.Panel]::SetZIndex($glow, 4002)
    $script:calendarSummonsGlow = $glow

    $hoverFrames = @('craw-hover-0004.png', 'craw-hover-0005.png', 'craw-hover-0001.png', 'craw-hover-0000.png')
    $flapDurations = @(0.52, 0.68, 0.57, 0.74, 0.61)
    $state = [pscustomobject]@{ StartedAt = [DateTime]::UtcNow; FlapStartedAt = 0.0; FlapIndex = 0; Frame = -1; Impact = $false }
    Start-WidgetTimer 'Summons.Arrival' 16 ({
        $elapsed = ([DateTime]::UtcNow - $state.StartedAt).TotalSeconds
        $flapDuration = $flapDurations[$state.FlapIndex]
        if (($elapsed - $state.FlapStartedAt) -ge $flapDuration -and $elapsed -lt 3.0) {
            $state.FlapStartedAt = $elapsed
            $state.FlapIndex = ($state.FlapIndex + 1) % $flapDurations.Count
            $flapDuration = $flapDurations[$state.FlapIndex]
        }
        $flapPhase = [Math]::Min(1.0, ($elapsed - $state.FlapStartedAt) / $flapDuration)
        if ($elapsed -lt 3.0) {
            $frame = if ($flapPhase -lt 0.2) { 0 } elseif ($flapPhase -lt 0.4) { 1 } elseif ($flapPhase -lt 0.68) { 2 } else { 3 }
            if ($frame -ne $state.Frame) { Set-CalendarSummonsImage $craw $hoverFrames[$frame]; $state.Frame = $frame }
            $craw.Width = 68.0
            $craw.Height = 72.0
        }
        if ($elapsed -lt 1.5) {
            $craw.RenderTransform = [System.Windows.Media.ScaleTransform]::new(-1, 1)
            $progress = $elapsed / 1.5
            $eased = $progress * $progress * (3.0 - (2.0 * $progress))
            $x = $minFlightX + (($maxFlightX - $minFlightX) * $eased)
            $lift = if ($flapPhase -lt 0.4) { -13.0 * ($flapPhase / 0.4) } else { -13.0 + (18.0 * (($flapPhase - 0.4) / 0.6)) }
            $y = [Math]::Max(8.0, $groundY - 108.0 + $lift)
        } elseif ($elapsed -lt 3.0) {
            $progress = [Math]::Min(1.0, ($elapsed - 1.5) / 1.5)
            $eased = $progress * $progress * (3.0 - (2.0 * $progress))
            $x = if ($progress -lt 0.58) { $maxFlightX + (($dropCrawX - $maxFlightX) * ($progress / 0.58)) } else { $dropCrawX + (($restX - $dropCrawX) * (($progress - 0.58) / 0.42)) }
            $lift = if ($flapPhase -lt 0.4) { -13.0 * ($flapPhase / 0.4) } else { -13.0 + (18.0 * (($flapPhase - 0.4) / 0.6)) }
            $y = [Math]::Max(8.0, $groundY - 108.0 + $lift)
            $craw.RenderTransform = if ($restX -lt $maxFlightX) { [System.Windows.Media.ScaleTransform]::new(1, 1) } else { [System.Windows.Media.ScaleTransform]::new(-1, 1) }
            if ($elapsed -ge 2.25) {
                $pin.Visibility = 'Visible'
                $drop = [Math]::Min(1.0, ($elapsed - 2.25) / 0.62)
                $drop = $drop * $drop
                [System.Windows.Controls.Canvas]::SetLeft($pin, $addCenter - ($pinWidth * 0.5))
                [System.Windows.Controls.Canvas]::SetTop($pin, ($groundY - 130.0) + (130.0 * $drop))
                if ($drop -ge 1.0 -and -not $state.Impact) {
                    $state.Impact = $true
                    Drop-SupersededCalendarSummonsPin
                    $glow.Visibility = 'Visible'
                    $pulse = New-Object System.Windows.Media.Animation.DoubleAnimation(0.32, 0.92, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(620)))
                    $pulse.AutoReverse = $true
                    $pulse.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                    $glow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $pulse)
                    $scale = New-Object System.Windows.Media.Animation.DoubleAnimation(0.82, 1.22, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(620)))
                    $scale.AutoReverse = $true
                    $scale.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                    $glow.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $scale)
                    $glow.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $scale)
                }
            }
        } else {
            $landing = [Math]::Min(1.0, ($elapsed - 3.0) / 1.0)
            $craw.RenderTransform = if ($restX -lt $addCenter) { [System.Windows.Media.ScaleTransform]::new(-1, 1) } else { [System.Windows.Media.ScaleTransform]::new(1, 1) }
            $x = $restX
            $landingEased = $landing * $landing * (3.0 - (2.0 * $landing))
            $y = ($restY - 42.0) + (42.0 * $landingEased)
            $craw.Width = 72.0
            $craw.Height = 64.0
            $landingFrame = if ($landing -lt 0.38) { 'craw-takeoff-0002.png' } elseif ($landing -lt 0.68) { 'craw-landing-0000.png' } elseif ($landing -lt 0.9) { 'craw-landing-0001.png' } else { 'craw-rest-0000.png' }
            if ($null -ne $landingFrame) { Set-CalendarSummonsImage $craw $landingFrame }
        }
        [System.Windows.Controls.Canvas]::SetLeft($craw, $x)
        [System.Windows.Controls.Canvas]::SetTop($craw, $y)
        if ($elapsed -ge 4.0) {
            Stop-WidgetTimer 'Summons.Arrival'
            Set-CalendarSummonsImage $pinImage 'craw_court_summons_pin0007.png'
            Set-CalendarSummonsImage $craw 'craw-rest-0000.png'
            [System.Windows.Controls.Canvas]::SetTop($pin, $groundY)
            [System.Windows.Controls.Canvas]::SetLeft($craw, $restX)
            [System.Windows.Controls.Canvas]::SetTop($craw, $restY)
        }
    }.GetNewClosure()) | Out-Null
}
