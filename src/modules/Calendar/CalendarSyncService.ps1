function Get-GoogleCalendarConfig {
    $clientPath = Join-Path $base 'google-calendar-client.json'
    $sessionPath = Join-Path $base 'google-calendar-session.json'
    if (-not (Test-Path -LiteralPath $clientPath) -or -not (Test-Path -LiteralPath $sessionPath)) { return $null }
    $client = Get-Content -LiteralPath $clientPath -Raw | ConvertFrom-Json
    $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    if (-not [bool]$session.configured) { return $null }
    [pscustomobject][ordered]@{ clientId = [string]$client.clientId; clientSecret = [string]$client.clientSecret; projectId = [string]$client.projectId; authUri = [string]$client.authUri; tokenUri = [string]$client.tokenUri; redirectUri = [string]$session.redirectUri; accessToken = [string]$session.accessToken; refreshToken = [string]$session.refreshToken; sourceCredentialFile = [string]$session.sourceCredentialFile; configured = $true }
}

function Initialize-GoogleCalendar {
    Remove-LegacyGoogleCalendarConfig
    $resultPath = Join-Path $base 'google-calendar-auth-result.json'
    $newAuthorization = Test-Path -LiteralPath $resultPath
    if ($newAuthorization) { Save-GoogleCalendarAuthorizationResult $resultPath }
    if ($null -eq (Get-GoogleCalendarConfig)) { return }
    Sync-GoogleCalendar $false $newAuthorization
    if ($newAuthorization) {
        [System.Windows.MessageBox]::Show(
            'Google Calendar connected and synchronized successfully.',
            'Google Calendar',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
    }
}

function Update-GoogleCalendarAccessToken($calendar) {
    if ([string]::IsNullOrWhiteSpace([string]$calendar.refreshToken)) { return [string]$calendar.accessToken }
    $body = @{
        client_id = [string]$calendar.clientId
        refresh_token = [string]$calendar.refreshToken
        grant_type = 'refresh_token'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$calendar.clientSecret)) { $body.client_secret = [string]$calendar.clientSecret }
    $tokens = Invoke-RestMethod -Method Post -Uri ([string]$calendar.tokenUri) -Body $body -ContentType 'application/x-www-form-urlencoded'
    if ([string]::IsNullOrWhiteSpace([string]$tokens.access_token)) { throw 'Google did not renew the access token.' }
    $calendar.accessToken = [string]$tokens.access_token
    $sessionPath = Join-Path $base 'google-calendar-session.json'
    $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    $session.accessToken = [string]$tokens.access_token
    [System.IO.File]::WriteAllText($sessionPath, ($session | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    [string]$tokens.access_token
}

function Sync-GoogleCalendar([bool]$allowDuringEdit = $false, [bool]$useCurrentAccessToken = $false) {
    if ($script:calendarSyncActive -or ($script:editMode -and -not $allowDuringEdit)) { return }
    $calendar = Get-GoogleCalendarConfig
    if ($null -eq $calendar) { return }
    $script:calendarSyncActive = $true
    try {
        $token = if ($useCurrentAccessToken) { [string]$calendar.accessToken } else { Update-GoogleCalendarAccessToken $calendar }
        $now = [DateTimeOffset]::Now
        $end = [DateTimeOffset]::new($now.Year, $now.Month, $now.Day, 23, 59, 59, $now.Offset)
        $query = 'https://www.googleapis.com/calendar/v3/calendars/primary/events?singleEvents=true&orderBy=startTime&timeMin=' + [Uri]::EscapeDataString($now.ToString('o')) + '&timeMax=' + [Uri]::EscapeDataString($end.ToString('o'))
        $response = Invoke-RestMethod -Method Get -Uri $query -Headers @{ Authorization = "Bearer $token" }
        $events = @($response.items | Where-Object { [string]$_.status -ne 'cancelled' })
        $script:lastGoogleCalendarEvents = $events
        $activeIds = @($events | ForEach-Object { [string]$_.id })
        $script:tasks = @($script:tasks | Where-Object { [string]$_.source -ne 'googleCalendar' -or $activeIds -contains [string]$_.externalId })
        foreach ($event in $events) {
            $existing = @($script:tasks | Where-Object { [string]$_.source -eq 'googleCalendar' -and [string]$_.externalId -eq [string]$event.id } | Select-Object -First 1)
            $startText = if ($null -ne $event.start.dateTime) { ([DateTimeOffset]::Parse([string]$event.start.dateTime)).ToLocalTime().ToString('HH:mm') } else { 'All day' }
            $endText = if ($null -ne $event.end.dateTime) { ([DateTimeOffset]::Parse([string]$event.end.dateTime)).ToLocalTime().ToString('HH:mm') } else { '' }
            $description = @($startText + $(if ($endText) { " - $endText" } else { '' }), [string]$event.location, [string]$event.description) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if ($existing.Count -gt 0) {
                $existing[0].title = if ([string]::IsNullOrWhiteSpace([string]$event.summary)) { 'Google Calendar event' } else { [string]$event.summary }
                $existing[0].description = $description -join [Environment]::NewLine
                continue
            }
        }
        Save-Tasks
        Render-Tasks
        if ($events.Count -gt 0) { Show-CalendarSummons $events }
    } finally {
        $script:calendarSyncActive = $false
    }
}

