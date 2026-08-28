function Save-GoogleCalendarAuthorizationResult([string]$resultPath) {
    if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Google authorization response not found.' }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if (-not [bool]$result.success) {
        $errorMessage = [string]$result.error
        Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
        throw $errorMessage
    }
    if ([string]::IsNullOrWhiteSpace([string]$result.accessToken)) { throw 'Google authorization response has no access token.' }
    $session = [pscustomobject][ordered]@{
        redirectUri = [string]$result.redirectUri
        accessToken = [string]$result.accessToken
        refreshToken = [string]$result.refreshToken
        sourceCredentialFile = if ([string]::IsNullOrWhiteSpace([string]$result.sourceCredentialFile)) { [string]$script:calendarCredentialSourceFile } else { [string]$result.sourceCredentialFile }
        configured = $true
    }
    [System.IO.File]::WriteAllText((Join-Path $base 'google-calendar-session.json'), ($session | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
}

function Remove-LegacyGoogleCalendarConfig {
    if ($null -eq $script:config.PSObject.Properties['googleCalendar']) { return }
    $legacy = $script:config.googleCalendar
    $clientPath = Join-Path $base 'google-calendar-client.json'
    $sessionPath = Join-Path $base 'google-calendar-session.json'
    if (-not (Test-Path -LiteralPath $clientPath)) {
        $client = [pscustomobject][ordered]@{ clientId = [string]$legacy.clientId; clientSecret = [string]$legacy.clientSecret; projectId = [string]$legacy.projectId; authUri = [string]$legacy.authUri; tokenUri = [string]$legacy.tokenUri }
        [System.IO.File]::WriteAllText($clientPath, ($client | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    }
    if (-not (Test-Path -LiteralPath $sessionPath)) {
        $session = [pscustomobject][ordered]@{ redirectUri = [string]$legacy.redirectUri; accessToken = [string]$legacy.accessToken; refreshToken = [string]$legacy.refreshToken; sourceCredentialFile = [string]$legacy.sourceCredentialFile; configured = $true }
        [System.IO.File]::WriteAllText($sessionPath, ($session | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    }
    $script:config.PSObject.Properties.Remove('googleCalendar')
    Save-Config
}

function Disconnect-GoogleCalendar {
    if ($null -ne $script:calendarConnectionTimer) {
        $script:calendarConnectionTimer.Stop()
        $script:calendarConnectionTimer = $null
    }
    $calendar = Get-GoogleCalendarConfig
    if ($null -ne $calendar -and -not [string]::IsNullOrWhiteSpace([string]$calendar.sourceCredentialFile)) {
        $sourcePath = Join-Path $projectRoot ([System.IO.Path]::GetFileName([string]$calendar.sourceCredentialFile))
        if (Test-Path -LiteralPath $sourcePath) { Remove-Item -LiteralPath $sourcePath -Force }
    }
    foreach ($path in @(
        (Join-Path $base 'google-calendar-client.json'),
        (Join-Path $base 'google-calendar-session.json'),
        (Join-Path $base 'google-calendar-credentials.json'),
        (Join-Path $base 'google-calendar-auth-result.json'),
        (Join-Path $base 'google-calendar-auth-result.json.url')
    )) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    if ($null -ne $script:config.PSObject.Properties['googleCalendar']) {
        $script:config.PSObject.Properties.Remove('googleCalendar')
        Save-Config
    }
    $script:tasks = @($script:tasks | Where-Object { [string]$_.source -ne 'googleCalendar' })
    Save-Tasks
    Render-Tasks
}

function Start-GoogleCalendarAuthorization($client, [string]$sourceName) {
    if ([string]::IsNullOrWhiteSpace([string]$client.clientId)) { throw 'The OAuth client ID is missing.' }
    $clientConfig = [pscustomobject][ordered]@{ clientId = [string]$client.clientId; clientSecret = [string]$client.clientSecret; projectId = [string]$client.projectId; authUri = [string]$client.authUri; tokenUri = [string]$client.tokenUri }
    [System.IO.File]::WriteAllText((Join-Path $base 'google-calendar-client.json'), ($clientConfig | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    $script:calendarCredentialSourceFile = $sourceName
    $resultPath = Join-Path $base 'google-calendar-auth-result.json'
    foreach ($path in @($resultPath, "$resultPath.url")) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $base 'google-calendar-auth.ps1'), '-ClientId', ([string]$client.clientId), '-ProjectId', ([string]$client.projectId), '-AuthUri', ([string]$client.authUri), '-TokenUri', ([string]$client.tokenUri), '-ResultPath', $resultPath, '-SourceCredentialFile', $sourceName)
    if (-not [string]::IsNullOrWhiteSpace([string]$client.clientSecret)) { $arguments += @('-ClientSecret', [string]$client.clientSecret) }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    Show-GoogleCalendarConnectionCountdown
}

function Show-GoogleCalendarConnectionCountdown {
    if ($null -ne $script:editSettingsWindow) { $script:editSettingsWindow.Hide() }
    $window = New-Object System.Windows.Window
    $window.WindowStyle = 'None'
    $window.ResizeMode = 'NoResize'
    $window.AllowsTransparency = $true
    $window.Background = [System.Windows.Media.Brushes]::Transparent
    $window.ShowInTaskbar = $false
    $window.Topmost = $true
    $window.Width = 520
    $window.Height = 340
    $window.Owner = $script:window
    $window.WindowStartupLocation = 'Manual'
    $screen = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.Primary } | Select-Object -First 1)[0]
    $work = $screen.WorkingArea
    $window.Left = [double]$work.Left + (([double]$work.Width - $window.Width) * 0.5)
    $window.Top = [double]$work.Bottom - $window.Height - 16
    $card = New-Object System.Windows.Controls.Border
    $card.Margin = '18'
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FA070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#77FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    $content = New-Object System.Windows.Controls.StackPanel
    $content.Margin = '30,24'
    $header = New-Object System.Windows.Controls.Grid
    $headerColumn = New-Object System.Windows.Controls.ColumnDefinition
    $headerColumn.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $handleColumn = New-Object System.Windows.Controls.ColumnDefinition
    $handleColumn.Width = New-Object System.Windows.GridLength(38)
    $header.ColumnDefinitions.Add($headerColumn) | Out-Null
    $header.ColumnDefinitions.Add($handleColumn) | Out-Null
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'CONNECTING GOOGLE CALENDAR'
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 19
    $title.FontWeight = 'SemiBold'
    $title.HorizontalAlignment = 'Center'
    $title.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($title, 0)
    $header.Children.Add($title) | Out-Null
    $dragHandle = New-RoundButton '' 30
    $dragHandle.Width = 30
    $dragHandle.Height = 30
    $dragHandle.ToolTip = 'Drag window'
    $dragHandle.Cursor = [System.Windows.Input.Cursors]::SizeAll
    $dragView = New-Object System.Windows.Controls.Viewbox
    $dragView.Width = 17
    $dragView.Height = 17
    $dragPath = New-Object System.Windows.Shapes.Path
    $dragPath.Stroke = [System.Windows.Media.Brushes]::White
    $dragPath.StrokeThickness = 1.6
    $dragPath.StrokeStartLineCap = 'Round'
    $dragPath.StrokeEndLineCap = 'Round'
    $dragPath.StrokeLineJoin = 'Round'
    $dragPath.Data = [System.Windows.Media.Geometry]::Parse('M2,8.5 L15,8.5 M2,8.5 L5,5.5 M2,8.5 L5,11.5 M15,8.5 L12,5.5 M15,8.5 L12,11.5 M8.5,2 L8.5,15 M8.5,2 L5.5,5 M8.5,2 L11.5,5 M8.5,15 L5.5,12 M8.5,15 L11.5,12')
    $dragView.Child = $dragPath
    $dragHandle.Content = $dragView
    $dragHandle.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        $eventArgs.Handled = $true
        $window.DragMove()
    }.GetNewClosure())
    [System.Windows.Controls.Grid]::SetColumn($dragHandle, 1)
    $header.Children.Add($dragHandle) | Out-Null
    $content.Children.Add($header) | Out-Null
    $message = New-Object System.Windows.Controls.TextBlock
    $message.Text = 'You have one minute to complete the authorization steps in your browser. Wait for this countdown to finish and the widget will restart automatically. If you cancel or close this window early, the connection may not be completed.'
    $message.Foreground = [System.Windows.Media.Brushes]::LightGray
    $message.TextWrapping = 'Wrap'
    $message.TextAlignment = 'Center'
    $message.Margin = '0,16,0,0'
    $content.Children.Add($message) | Out-Null
    $countdown = New-Object System.Windows.Controls.TextBlock
    $countdown.Text = '01:00'
    $countdown.Foreground = [System.Windows.Media.Brushes]::LightGreen
    $countdown.FontSize = 32
    $countdown.FontWeight = 'Bold'
    $countdown.HorizontalAlignment = 'Center'
    $countdown.Margin = '0,14,0,10'
    $content.Children.Add($countdown) | Out-Null
    $buttons = New-Object System.Windows.Controls.StackPanel
    $buttons.Orientation = 'Horizontal'
    $buttons.HorizontalAlignment = 'Center'
    $confirm = New-RoundButton 'I RECEIVED THE SUCCESS RESPONSE' 280
    $confirm.Width = 280
    $confirm.Height = 36
    $confirm.Margin = '0,0,10,0'
    $buttons.Children.Add($confirm) | Out-Null
    $cancel = New-RoundButton 'CANCEL' 100
    $cancel.Width = 100
    $cancel.Height = 36
    $buttons.Children.Add($cancel) | Out-Null
    $content.Children.Add($buttons) | Out-Null
    $card.Child = $content
    $window.Content = $card
    $state = [pscustomobject]@{ Remaining = 60; Completed = $false; Restored = $false }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $script:calendarConnectionTimer = $timer
    $restoreSettings = {
        if ($state.Restored -or $state.Completed) { return }
        $state.Restored = $true
        if ($null -ne $script:editSettingsWindow) {
            $script:editSettingsWindow.Show()
            $script:editSettingsWindow.WindowState = 'Normal'
            $script:editSettingsWindow.Activate() | Out-Null
        }
    }.GetNewClosure()
    $restartWidget = {
        if ($state.Completed) { return }
        $state.Completed = $true
        $timer.Stop()
        $script:calendarConnectionTimer = $null
        $window.Close()
        $launcher = Join-Path $projectRoot 'Desktop Wish Board.vbs'
        $escapedLauncher = $launcher.Replace("'", "''")
        $restartCommand = "Start-Sleep -Seconds 2; Start-Process -FilePath '$escapedLauncher'"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($restartCommand))
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-EncodedCommand', $encodedCommand) -WindowStyle Hidden | Out-Null
        Exit-Widget
    }.GetNewClosure()
    $timer.Add_Tick({
        $state.Remaining--
        $countdown.Text = '{0:00}:{1:00}' -f [Math]::Floor($state.Remaining / 60), ($state.Remaining % 60)
        if ($state.Remaining -le 0) { & $restartWidget }
    }.GetNewClosure())
    $confirm.Add_Click({ & $restartWidget }.GetNewClosure())
    $cancel.Add_Click({
        $timer.Stop()
        $script:calendarConnectionTimer = $null
        $window.Close()
        & $restoreSettings
    }.GetNewClosure())
    $window.Add_Closed({
        if ($null -ne $script:calendarConnectionTimer) {
            $script:calendarConnectionTimer.Stop()
            $script:calendarConnectionTimer = $null
        }
        & $restoreSettings
    }.GetNewClosure())
    $timer.Start()
    $window.Show()
    $window.Activate() | Out-Null
}

function New-GoogleCalendarSettingsContent {
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = '18'
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'GOOGLE CALENDAR'
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 20
    $title.FontWeight = 'SemiBold'
    $panel.Children.Add($title) | Out-Null
    $connectedPanel = New-Object System.Windows.Controls.StackPanel
    $connectedPanel.Margin = '0,18,0,0'
    $connectedText = New-Object System.Windows.Controls.TextBlock
    $connectedText.Text = 'Google Calendar is connected. Events are synchronized automatically every minute.'
    $connectedText.Foreground = [System.Windows.Media.Brushes]::LightGreen
    $connectedText.TextWrapping = 'Wrap'
    $connectedPanel.Children.Add($connectedText) | Out-Null
    $eventsTitle = New-Object System.Windows.Controls.TextBlock
    $eventsTitle.Text = "TODAY'S EVENTS"
    $eventsTitle.Foreground = [System.Windows.Media.Brushes]::White
    $eventsTitle.FontWeight = 'SemiBold'
    $eventsTitle.Margin = '0,18,0,6'
    $connectedPanel.Children.Add($eventsTitle) | Out-Null
    $eventsList = New-Object System.Windows.Controls.StackPanel
    $connectedPanel.Children.Add($eventsList) | Out-Null
    $disconnect = New-RoundButton 'DISCONNECT' 140
    $disconnect.Width = 140
    $disconnect.Height = 38
    $disconnect.Margin = '0,18,0,0'
    $connectedPanel.Children.Add($disconnect) | Out-Null
    $choicePanel = New-Object System.Windows.Controls.StackPanel
    $choicePanel.Margin = '0,18,0,0'
    $choiceTitle = New-Object System.Windows.Controls.TextBlock
    $choiceTitle.Text = 'CHOOSE HOW TO CONNECT'
    $choiceTitle.Foreground = [System.Windows.Media.Brushes]::White
    $choiceTitle.FontSize = 18
    $choiceTitle.FontWeight = 'SemiBold'
    $choicePanel.Children.Add($choiceTitle) | Out-Null
    $defaultDescription = New-Object System.Windows.Controls.TextBlock
    $defaultDescription.Text = 'Recommended: use the public widget credentials. You only need to select your Google account and authorize read-only Calendar access.'
    $defaultDescription.Foreground = [System.Windows.Media.Brushes]::LightGray
    $defaultDescription.TextWrapping = 'Wrap'
    $defaultDescription.Margin = '0,14,0,8'
    $choicePanel.Children.Add($defaultDescription) | Out-Null
    $useDefault = New-RoundButton 'USE WIDGET CREDENTIALS' 220
    $useDefault.Width = 220
    $useDefault.Height = 40
    $choicePanel.Children.Add($useDefault) | Out-Null
    $personalDescription = New-Object System.Windows.Controls.TextBlock
    $personalDescription.Text = 'Advanced: use your own Google Cloud project and OAuth credential file.'
    $personalDescription.Foreground = [System.Windows.Media.Brushes]::LightGray
    $personalDescription.TextWrapping = 'Wrap'
    $personalDescription.Margin = '0,22,0,8'
    $choicePanel.Children.Add($personalDescription) | Out-Null
    $usePersonal = New-RoundButton 'USE PERSONAL CREDENTIALS' 220
    $usePersonal.Width = 220
    $usePersonal.Height = 40
    $choicePanel.Children.Add($usePersonal) | Out-Null
    $tutorial = New-Object System.Windows.Controls.StackPanel
    $tutorial.Margin = '0,14,0,0'
    $steps = @(
        @('1. CREATE OR SELECT A PROJECT', 'Open Google Cloud Console at https://console.cloud.google.com/. Use the project selector at the top of the page to create a new project or select the project that will own this integration.'),
        @('2. ENABLE GOOGLE CALENDAR API', 'Open APIs & Services, select Library, search for Google Calendar API, open it and click Enable. Wait until the API status shows Enabled.'),
        @('3. CONFIGURE THE CONSENT SCREEN', 'Open APIs & Services > OAuth consent screen. Complete the required application information. If the app is in Testing mode, add the Google account you will authorize under Test users.'),
        @('4. CREATE DESKTOP CREDENTIALS', 'Open APIs & Services > Credentials. Click Create credentials > OAuth client ID, choose Desktop app, enter a name and create it. Do not choose Web application.'),
        @('5. DOWNLOAD AND SELECT THE JSON', 'Download the OAuth client JSON from the credentials list. Click Browse below, locate the downloaded client_secret JSON in Windows File Explorer, then click Validate file and connect.')
    )
    foreach ($step in $steps) {
        $heading = New-Object System.Windows.Controls.TextBlock
        $heading.Text = $step[0]
        $heading.Foreground = [System.Windows.Media.Brushes]::White
        $heading.FontWeight = 'SemiBold'
        $heading.Margin = '0,10,0,3'
        $tutorial.Children.Add($heading) | Out-Null
        $body = New-Object System.Windows.Controls.TextBlock
        $body.Text = $step[1]
        $body.Foreground = [System.Windows.Media.Brushes]::LightGray
        $body.TextWrapping = 'Wrap'
        $tutorial.Children.Add($body) | Out-Null
    }
    $selectedPath = New-Object System.Windows.Controls.TextBox
    $selectedPath.IsReadOnly = $true
    $selectedPath.Height = 30
    $selectedPath.Margin = '0,16,0,8'
    $selectedPath.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
    $selectedPath.Foreground = [System.Windows.Media.Brushes]::White
    $selectedPath.Text = 'No credential file selected.'
    $tutorial.Children.Add($selectedPath) | Out-Null
    $browse = New-RoundButton 'BROWSE...' 120
    $browse.Width = 120
    $browse.Height = 36
    $tutorial.Children.Add($browse) | Out-Null
    $validate = New-RoundButton 'VALIDATE FILE AND CONNECT' 220
    $validate.Width = 220
    $validate.Height = 38
    $validate.Margin = '0,10,0,0'
    $validate.IsEnabled = $false
    $tutorial.Children.Add($validate) | Out-Null
    $status = New-Object System.Windows.Controls.TextBlock
    $status.Margin = '0,12,0,0'
    $status.Foreground = [System.Windows.Media.Brushes]::White
    $status.TextWrapping = 'Wrap'
    $tutorial.Children.Add($status) | Out-Null
    $panel.Children.Add($connectedPanel) | Out-Null
    $panel.Children.Add($choicePanel) | Out-Null
    $panel.Children.Add($tutorial) | Out-Null
    $tutorial.Visibility = 'Collapsed'
    $refreshLayout = {
        $connected = $null -ne (Get-GoogleCalendarConfig)
        $connectedPanel.Visibility = if ($connected) { 'Visible' } else { 'Collapsed' }
        $choicePanel.Visibility = if ($connected) { 'Collapsed' } else { 'Visible' }
        if ($connected) { $tutorial.Visibility = 'Collapsed' }
        $eventsList.Children.Clear()
        $events = @($script:lastGoogleCalendarEvents)
        if ($events.Count -eq 0) {
            $empty = New-Object System.Windows.Controls.TextBlock
            $empty.Text = 'No remaining events for today.'
            $empty.Foreground = [System.Windows.Media.Brushes]::LightGray
            $eventsList.Children.Add($empty) | Out-Null
        } else {
            foreach ($event in $events) {
                $start = if ($null -ne $event.start.dateTime) { ([DateTimeOffset]::Parse([string]$event.start.dateTime)).ToLocalTime().ToString('HH:mm') } else { 'All day' }
                $item = New-Object System.Windows.Controls.TextBlock
                $item.Text = "$start  $([string]$event.summary)"
                $item.Foreground = [System.Windows.Media.Brushes]::White
                $item.Margin = '0,3,0,3'
                $eventsList.Children.Add($item) | Out-Null
            }
        }
    }
    $useDefault.Add_Click({
        try {
            $defaultPath = Join-Path $base 'google-calendar-default.json'
            if (-not (Test-Path -LiteralPath $defaultPath)) { throw 'The public widget OAuth configuration is missing.' }
            $client = Get-Content -LiteralPath $defaultPath -Raw | ConvertFrom-Json
            Start-GoogleCalendarAuthorization $client 'widget-default'
        } catch {
            $status.Text = $_.Exception.Message
            $status.Foreground = [System.Windows.Media.Brushes]::IndianRed
            $tutorial.Visibility = 'Visible'
            $choicePanel.Visibility = 'Collapsed'
        }
    }.GetNewClosure())
    $usePersonal.Add_Click({
        $choicePanel.Visibility = 'Collapsed'
        $tutorial.Visibility = 'Visible'
    }.GetNewClosure())
    $browse.Add_Click({
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Select Google OAuth client credentials'
        $dialog.Filter = 'Google credential JSON (*.json)|*.json'
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog() -eq $true) {
            $selectedPath.Text = $dialog.FileName
            $validate.IsEnabled = $true
            $status.Text = ''
        }
    }.GetNewClosure())
    $validate.Add_Click({
        try {
            $credential = Get-Content -LiteralPath $selectedPath.Text -Raw | ConvertFrom-Json
            if ($null -eq $credential.installed) { throw 'This is not a Desktop app OAuth credential file. Create an OAuth client ID with application type Desktop app.' }
            $installed = $credential.installed
            if ([string]::IsNullOrWhiteSpace([string]$installed.client_id) -or [string]::IsNullOrWhiteSpace([string]$installed.client_secret)) { throw 'The selected file does not contain a client ID and client secret.' }
            $sourceName = [System.IO.Path]::GetFileName($selectedPath.Text)
            $client = [pscustomobject][ordered]@{ clientId = [string]$installed.client_id; clientSecret = [string]$installed.client_secret; projectId = [string]$installed.project_id; authUri = [string]$installed.auth_uri; tokenUri = [string]$installed.token_uri }
            Start-GoogleCalendarAuthorization $client $sourceName
        } catch {
            & $refreshLayout
            $status.Text = $_.Exception.Message
            $status.Foreground = [System.Windows.Media.Brushes]::IndianRed
            $validate.IsEnabled = $true
        }
    }.GetNewClosure())
    $disconnect.Add_Click({
        Disconnect-GoogleCalendar
        $selectedPath.Text = 'No credential file selected.'
        $validate.IsEnabled = $false
        $status.Text = ''
        & $refreshLayout
    }.GetNewClosure())
    & $refreshLayout
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Content = $panel
    New-SettingsContentFrame $scroll
}

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
            $position = @(Find-FreePosition ([double]$script:area.taskSize))
            if ($position.Count -lt 2) { continue }
            $task = [pscustomobject][ordered]@{
                id = 'calendar-' + [string]$event.id
                externalId = [string]$event.id
                source = 'googleCalendar'
                title = if ([string]::IsNullOrWhiteSpace([string]$event.summary)) { 'Google Calendar event' } else { [string]$event.summary }
                description = $description -join [Environment]::NewLine
                icon = Get-DefaultTaskIconId
                isNew = $false
                createdAt = [DateTime]::Now.ToString('o')
                x = [Math]::Round([double]$position[0], 1)
                y = [Math]::Round([double]$position[1], 1)
            }
            Add-TaskBadgeMetadata $task $true
            $script:tasks = @($script:tasks) + @($task)
        }
        Save-Tasks
        Render-Tasks
    } finally {
        $script:calendarSyncActive = $false
    }
}
