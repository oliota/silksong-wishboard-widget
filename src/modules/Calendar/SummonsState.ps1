function Set-CalendarSummonsImage($image, [string]$fileName) {
    if ($image -isnot [System.Windows.Controls.Image]) { return }
    $path = Join-Path $base "assets/calendar-summons/$fileName"
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = 'OnLoad'
    $bitmap.UriSource = [Uri]::new($path)
    $bitmap.EndInit()
    $image.Source = $bitmap
}

function New-GoogleCalendarTask($event) {
    $startText = if ($null -ne $event.start.dateTime) { ([DateTimeOffset]::Parse([string]$event.start.dateTime)).ToLocalTime().ToString('HH:mm') } else { 'All day' }
    $endText = if ($null -ne $event.end.dateTime) { ([DateTimeOffset]::Parse([string]$event.end.dateTime)).ToLocalTime().ToString('HH:mm') } else { '' }
    $description = @($startText + $(if ($endText) { " - $endText" } else { '' }), [string]$event.location, [string]$event.description) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $task = [pscustomobject][ordered]@{
        id = 'calendar-' + [string]$event.id
        externalId = [string]$event.id
        source = 'googleCalendar'
        title = if ([string]::IsNullOrWhiteSpace([string]$event.summary)) { 'Google Calendar event' } else { [string]$event.summary }
        description = $description -join [Environment]::NewLine
        icon = Get-RandomTaskIconId
        isNew = $true
        createdAt = [DateTime]::Now.ToString('o')
    }
    Add-TaskBadgeMetadata $task $true
    $task
}

function Remove-CalendarSummons {
    Stop-WidgetTimer 'Summons.Arrival'
    Stop-WidgetTimer 'Summons.Queue'
    Stop-WidgetTimer 'Summons.Pin'
    Stop-WidgetTimer 'Summons.Departure'
    Stop-WidgetTimer 'Summons.PreviousPin'
    if ($null -ne $script:calendarSummonsCraw) { $script:root.Children.Remove($script:calendarSummonsCraw); $script:calendarSummonsCraw = $null }
    if ($null -ne $script:calendarSummonsPin) { $script:root.Children.Remove($script:calendarSummonsPin); $script:calendarSummonsPin = $null }
    if ($null -ne $script:calendarSummonsGlow) { $script:root.Children.Remove($script:calendarSummonsGlow); $script:calendarSummonsGlow = $null }
    if ($null -ne $script:calendarSummonsPreviousPin) { $script:root.Children.Remove($script:calendarSummonsPreviousPin); $script:calendarSummonsPreviousPin = $null }
    $script:calendarSummonsActive = $false
    $script:calendarSummonsEventIds = @()
    $script:calendarSummonsPendingEvents = @()
    $script:calendarSummonsRestarting = $false
}

function Restart-CalendarSummons($events) {
    $script:calendarSummonsPendingEvents = @($events)
    if ($script:calendarSummonsRestarting) { return }
    $script:calendarSummonsRestarting = $true
    Stop-WidgetTimer 'Summons.Arrival'
    Stop-WidgetTimer 'Summons.Queue'
    if ($null -ne $script:calendarSummonsGlow) { $script:root.Children.Remove($script:calendarSummonsGlow) | Out-Null; $script:calendarSummonsGlow = $null }
    $script:calendarSummonsPreviousPin = $script:calendarSummonsPin
    $script:calendarSummonsPin = $null
    Start-CalendarSummonsCrawDeparture $true
}
