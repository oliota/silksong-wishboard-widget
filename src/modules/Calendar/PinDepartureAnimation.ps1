function Complete-CalendarSummonsPinDeparture($pinControl, [string]$timerName, [bool]$departCraw) {
    Stop-WidgetTimer $timerName
    if ($null -ne $script:root) { $script:root.Children.Remove($pinControl) | Out-Null }
    if ($script:calendarSummonsPin -eq $pinControl) { $script:calendarSummonsPin = $null }
    if ($script:calendarSummonsPreviousPin -eq $pinControl) { $script:calendarSummonsPreviousPin = $null }
    if ($departCraw) { Start-CalendarSummonsCrawDeparture }
}

function Start-CalendarSummonsPinFall($pinControl, [string]$timerName, [bool]$departCraw) {
    if ($null -eq $pinControl) { if ($departCraw) { Start-CalendarSummonsCrawDeparture }; return }
    $pinTop = [double][System.Windows.Controls.Canvas]::GetTop($pinControl)
    if ([double]::IsNaN($pinTop)) { $pinTop = 0.0 }
    $designHeight = [double]$script:config.widget.designHeight
    $rotation = [System.Windows.Media.RotateTransform]::new(0)
    $translation = [System.Windows.Media.TranslateTransform]::new(0, 0)
    $transformGroup = New-Object System.Windows.Media.TransformGroup
    $transformGroup.Children.Add($rotation) | Out-Null
    $transformGroup.Children.Add($translation) | Out-Null
    $pinControl.RenderTransformOrigin = '0.5,0.88'
    $pinControl.RenderTransform = $transformGroup
    $fallDistance = [Math]::Max(150.0, $designHeight - $pinTop + $pinControl.Height + 30.0)
    $state = [pscustomobject]@{ StartedAt = [DateTime]::UtcNow; Completed = $false }
    Start-WidgetTimer $timerName 16 ({
        $elapsed = ([DateTime]::UtcNow - $state.StartedAt).TotalSeconds
        $progress = [Math]::Min(1.0, $elapsed / 0.58)
        $eased = $progress * $progress
        $rotation.Angle = 105.0 * [Math]::Min(1.0, $progress * 1.8)
        $translation.Y = $fallDistance * $eased
        if ($progress -ge 1.0 -and -not $state.Completed) {
            $state.Completed = $true
            Complete-CalendarSummonsPinDeparture $pinControl $timerName $departCraw
        }
    }.GetNewClosure()) | Out-Null
}

function Start-CalendarSummonsDeparture {
    Start-CalendarSummonsPinFall $script:calendarSummonsPin 'Summons.Pin' $true
}

function Drop-SupersededCalendarSummonsPin {
    if ($null -eq $script:calendarSummonsPreviousPin) { return }
    Start-CalendarSummonsPinFall $script:calendarSummonsPreviousPin 'Summons.PreviousPin' $false
}
