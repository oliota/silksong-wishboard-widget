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

