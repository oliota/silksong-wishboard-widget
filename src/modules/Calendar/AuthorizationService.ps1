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

