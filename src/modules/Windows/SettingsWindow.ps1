function Show-EditSettingsWindow {
    if (-not $script:editMode) { return }
    if ($null -ne $script:editSettingsWindow) { Update-SettingsProfileSelection; $script:editSettingsWindow.Show(); $script:editSettingsWindow.Activate() | Out-Null; return }
    $screen = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.Primary } | Select-Object -First 1)[0]
    if ($null -eq $screen) { return }
    $work = $screen.WorkingArea
    $width = [double]$work.Width * 0.6
    $height = [Math]::Max(500.0, [Math]::Min([double]$work.Height * 0.76, $width * 0.56))
    $settingsWindow = New-Object System.Windows.Window
    $settingsWindow.WindowStyle = 'None'; $settingsWindow.ResizeMode = 'NoResize'; $settingsWindow.AllowsTransparency = $true; $settingsWindow.Background = [System.Windows.Media.Brushes]::Transparent; $settingsWindow.ShowInTaskbar = $false; $settingsWindow.Topmost = $true; $settingsWindow.Width = $width; $settingsWindow.Height = $height
    $settingsWindow.Left = [double]$work.Left + (([double]$work.Width - $width) * 0.5); $settingsWindow.Top = [double]$work.Top + (([double]$work.Height - $height) * 0.5)
    $script:editSettingsWindow = $settingsWindow; $script:settingsProfileCards = @{}
    $outer = New-Object System.Windows.Controls.Grid
    foreach ($rowHeight in @(60, '*', 44)) { $row = New-Object System.Windows.Controls.RowDefinition; $row.Height = if ($rowHeight -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { New-Object System.Windows.GridLength([double]$rowHeight) }; $outer.RowDefinitions.Add($row) | Out-Null }
    Add-OrnamentShadow $outer 1
    $topOrnament = New-DetailOrnament; [System.Windows.Controls.Grid]::SetRow($topOrnament, 0); $outer.Children.Add($topOrnament) | Out-Null
    $bottomOrnament = New-DetailOrnament $true; [System.Windows.Controls.Grid]::SetRow($bottomOrnament, 2); $outer.Children.Add($bottomOrnament) | Out-Null
    $card = New-Object System.Windows.Controls.Border; $card.Margin = '26,0'; $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FA070708'); $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#77FFFFFF'); $card.BorderThickness = 1; $card.CornerRadius = 4; [System.Windows.Controls.Grid]::SetRow($card, 1); $outer.Children.Add($card) | Out-Null
    $layout = New-Object System.Windows.Controls.Grid
    $headerRow = New-Object System.Windows.Controls.RowDefinition; $headerRow.Height = New-Object System.Windows.GridLength(62)
    $contentRow = New-Object System.Windows.Controls.RowDefinition; $contentRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($headerRow) | Out-Null; $layout.RowDefinitions.Add($contentRow) | Out-Null; $card.Child = $layout
    $header = New-Object System.Windows.Controls.Grid; $header.Margin = '24,10,18,0'; [System.Windows.Controls.Grid]::SetRow($header, 0); $layout.Children.Add($header) | Out-Null
    $tab = New-Object System.Windows.Controls.StackPanel; $tab.Width = 320; $tab.HorizontalAlignment = 'Left'; $tabTitle = New-Object System.Windows.Controls.TextBlock; $tabTitle.Text = 'WISH BOARD CONFIGURATION'; $tabTitle.Foreground = [System.Windows.Media.Brushes]::White; $tabTitle.FontSize = 22; $tabTitle.FontWeight = 'SemiBold'; $tabTitle.HorizontalAlignment = 'Center'; $tab.Children.Add($tabTitle) | Out-Null; $tab.Children.Add((New-DecorativeAsset 'backgrounds/Controller_Dialogue_0001_bot.png' 18)) | Out-Null; $header.Children.Add($tab) | Out-Null
    $close = New-RoundButton 'CANCEL' 30; $close.Width = 86; $close.Margin = '0,0,44,0'; $close.HorizontalAlignment = 'Right'; $close.VerticalAlignment = 'Top'; $close.ToolTip = 'Cancel edit mode'; $header.Children.Add($close) | Out-Null
    $save = New-RoundButton 'SAVE' 30; $save.Width = 74; $save.Margin = '0,0,136,0'; $save.HorizontalAlignment = 'Right'; $save.VerticalAlignment = 'Top'; $save.ToolTip = 'Save edit mode'; $header.Children.Add($save) | Out-Null
    $save.Add_Click({ Invoke-EditModeSave }.GetNewClosure())
    $dragHandle = New-RoundButton '' 30
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
    $dragHandle.HorizontalAlignment = 'Right'
    $dragHandle.VerticalAlignment = 'Top'
    $dragHandle.Add_PreviewMouseLeftButtonDown({
        param($s, $e)
        $e.Handled = $true
        $settingsWindow.DragMove()
    }.GetNewClosure())
    $header.Children.Add($dragHandle) | Out-Null
    [System.Windows.Controls.Panel]::SetZIndex($dragHandle, 10)
    $tabs = New-Object System.Windows.Controls.TabControl; $tabs.Margin = '20,0,20,20'; $tabs.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF101014'); $tabs.Foreground = [System.Windows.Media.Brushes]::White; $tabs.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF55555F'); $tabs.ItemContainerStyle = New-SettingsTabStyle; [System.Windows.Controls.Grid]::SetRow($tabs, 1); $layout.Children.Add($tabs) | Out-Null
    $profilesTab = New-Object System.Windows.Controls.TabItem; $profilesTab.Header = 'WISH BOARD'; $profilesTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $profilesTab.Foreground = [System.Windows.Media.Brushes]::White; $profileGrid = New-WishBoardProfileGrid; $tabs.Items.Add($profilesTab) | Out-Null
    $iconsTab = New-Object System.Windows.Controls.TabItem; $iconsTab.Header = 'WISH ICONS'; $iconsTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $iconsTab.Foreground = [System.Windows.Media.Brushes]::White; $iconsContent = New-Object System.Windows.Controls.StackPanel; $iconsContent.Margin = '10'; Render-IconCatalogEditor $iconsContent; $tabs.Items.Add($iconsTab) | Out-Null
    $otherTab = New-Object System.Windows.Controls.TabItem; $otherTab.Header = 'OTHER SETTINGS'; $otherTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $otherTab.Foreground = [System.Windows.Media.Brushes]::White; $otherPanel = New-Object System.Windows.Controls.StackPanel; $otherPanel.Margin = '18'; foreach ($setting in @([pscustomobject]@{ Control = $script:borderToggle; Description = 'Show or hide the permitted wish area boundary.'; Width = 100 }, [pscustomobject]@{ Control = $script:startupToggle; Description = 'Start the Wish Board automatically when Windows signs in.'; Width = 120 })) { $settingRow = New-Object System.Windows.Controls.Grid; $settingRow.Height = 64; $settingRow.Margin = '0,0,0,1'; $settingRow.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B'); $col = New-Object System.Windows.Controls.ColumnDefinition; $col.Width = New-Object System.Windows.GridLength(130); $textCol = New-Object System.Windows.Controls.ColumnDefinition; $textCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $settingRow.ColumnDefinitions.Add($col) | Out-Null; $settingRow.ColumnDefinitions.Add($textCol) | Out-Null; $setting.Control.Width = $setting.Width; $setting.Control.Height = 34; $setting.Control.Visibility = 'Visible'; [System.Windows.Controls.Grid]::SetColumn($setting.Control, 0); $settingRow.Children.Add($setting.Control) | Out-Null; $description = New-Object System.Windows.Controls.TextBlock; $description.Text = [string]$setting.Description; $description.Foreground = [System.Windows.Media.Brushes]::White; $description.TextWrapping = 'Wrap'; $description.VerticalAlignment = 'Center'; $description.Margin = '12,0,4,0'; [System.Windows.Controls.Grid]::SetColumn($description, 1); $settingRow.Children.Add($description) | Out-Null; $otherPanel.Children.Add($settingRow) | Out-Null }; $tabs.Items.Add($otherTab) | Out-Null
    $profilesTab.Content = New-SettingsContentFrame $profileGrid
    $iconsTab.Content = New-SettingsContentFrame $iconsContent
    $otherScroll = New-Object System.Windows.Controls.ScrollViewer
    $otherScroll.Height = 330
    $otherScroll.VerticalScrollBarVisibility = 'Auto'
    $otherScroll.Content = $otherPanel
    $otherTab.Content = New-SettingsContentFrame $otherScroll
    $calendarTab = New-Object System.Windows.Controls.TabItem
    $calendarTab.Header = 'GOOGLE CALENDAR'
    $calendarTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026')
    $calendarTab.Foreground = [System.Windows.Media.Brushes]::White
    $calendarPanel = New-Object System.Windows.Controls.StackPanel
    $calendarPanel.Margin = '18'
    $calendarTitle = New-Object System.Windows.Controls.TextBlock
    $calendarTitle.Text = 'GOOGLE CALENDAR SETUP'
    $calendarTitle.Foreground = [System.Windows.Media.Brushes]::White
    $calendarTitle.FontSize = 20
    $calendarTitle.FontWeight = 'SemiBold'
    $calendarPanel.Children.Add($calendarTitle) | Out-Null
    $calendarGuide = New-Object System.Windows.Controls.TextBlock
    $calendarGuide.Text = 'Step 1 of 5: Open the Google Cloud Console, create a project, and select it.'
    $calendarGuide.Foreground = [System.Windows.Media.Brushes]::White
    $calendarGuide.TextWrapping = 'Wrap'
    $calendarGuide.Margin = '0,16,0,8'
    $calendarPanel.Children.Add($calendarGuide) | Out-Null
    $calendarTextArea = New-Object System.Windows.Controls.TextBox
    $calendarTextArea.AcceptsReturn = $true
    $calendarTextArea.TextWrapping = 'Wrap'
    $calendarTextArea.VerticalScrollBarVisibility = 'Auto'
    $calendarTextArea.Height = 130
    $calendarTextArea.Margin = '0,8,0,8'
    $calendarTextArea.Foreground = [System.Windows.Media.Brushes]::White
    $calendarTextArea.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
    $calendarTextArea.BorderBrush = [System.Windows.Media.Brushes]::White
    $savedCredentialPath = Join-Path $base 'google-calendar-credentials.json'
    if (Test-Path -LiteralPath $savedCredentialPath) {
        try {
            $savedCredential = Get-Content -LiteralPath $savedCredentialPath -Raw | ConvertFrom-Json
            if ($null -ne $savedCredential.installed) { $calendarTextArea.Text = [System.IO.File]::ReadAllText($savedCredentialPath) }
        } catch {}
    }
    $calendarPanel.Children.Add($calendarTextArea) | Out-Null
    $calendarLink = New-Object System.Windows.Controls.TextBlock
    $calendarLink.Text = 'https://console.cloud.google.com/'
    $calendarLink.Foreground = [System.Windows.Media.Brushes]::LightBlue
    $calendarLink.TextWrapping = 'Wrap'
    $calendarLink.Cursor = [System.Windows.Input.Cursors]::Hand
    $calendarLink.Add_MouseLeftButtonUp({ & "$env:WINDIR\System32\rundll32.exe" 'url.dll,FileProtocolHandler' $calendarLink.Text }.GetNewClosure())
    $calendarPanel.Children.Add($calendarLink) | Out-Null
    $calendarNext = New-RoundButton 'NEXT' 100
    $calendarNext.Width = 100
    $calendarNext.Height = 36
    $calendarNext.Margin = '0,16,0,8'
    $calendarPanel.Children.Add($calendarNext) | Out-Null
    $calendarImport = New-RoundButton 'AUTHORIZE GOOGLE' 100
    $calendarImport.Width = 170
    $calendarImport.Height = 36
    $calendarImport.Visibility = if ([string]::IsNullOrWhiteSpace($calendarTextArea.Text)) { 'Collapsed' } else { 'Visible' }
    $calendarPanel.Children.Add($calendarImport) | Out-Null
    $calendarFields = New-Object System.Windows.Controls.StackPanel
    $calendarFields.Margin = '0,12,0,4'
    $calendarFields.Visibility = 'Collapsed'
    $calendarPanel.Children.Add($calendarFields) | Out-Null
    $calendarInputs = @{}
    foreach ($field in @(
        [pscustomobject]@{ Key = 'clientId'; Name = 'Client ID'; Secret = $false }
        [pscustomobject]@{ Key = 'clientSecret'; Name = 'Client Secret'; Secret = $true }
        [pscustomobject]@{ Key = 'projectId'; Name = 'Project ID'; Secret = $false }
        [pscustomobject]@{ Key = 'redirectUri'; Name = 'Redirect URI'; Secret = $false }
    )) {
        $fieldLabel = New-Object System.Windows.Controls.TextBlock
        $fieldLabel.Text = $field.Name
        $fieldLabel.Foreground = [System.Windows.Media.Brushes]::White
        $fieldLabel.Margin = '0,5,0,2'
        $calendarFields.Children.Add($fieldLabel) | Out-Null
        if ($field.Secret) { $fieldInput = New-Object System.Windows.Controls.PasswordBox } else { $fieldInput = New-Object System.Windows.Controls.TextBox }
        $fieldInput.Height = 28
        $fieldInput.Foreground = [System.Windows.Media.Brushes]::White
        $fieldInput.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
        $fieldInput.BorderBrush = [System.Windows.Media.Brushes]::White
        $calendarInputs[$field.Key] = $fieldInput
        $calendarFields.Children.Add($fieldInput) | Out-Null
    }
    $calendarConfirm = New-RoundButton 'CONFIRM CONNECTION' 100
    $calendarConfirm.Width = 190
    $calendarConfirm.Height = 36
    $calendarConfirm.Margin = '0,8,0,8'
    $calendarConfirm.Visibility = 'Collapsed'
    $calendarPanel.Children.Add($calendarConfirm) | Out-Null
    $calendarFetchReturn = New-RoundButton 'GET CALENDAR RETURN' 100
    $calendarFetchReturn.Width = 190
    $calendarFetchReturn.Height = 36
    $calendarFetchReturn.Margin = '0,8,0,8'
    $calendarFetchReturn.Visibility = 'Collapsed'
    $calendarFetchReturn.IsEnabled = $false
    $calendarPanel.Children.Add($calendarFetchReturn) | Out-Null
    $calendarStatus = New-Object System.Windows.Controls.TextBlock
    $calendarStatus.Foreground = [System.Windows.Media.Brushes]::White
    $calendarStatus.TextWrapping = 'Wrap'
    $calendarPanel.Children.Add($calendarStatus) | Out-Null
    $calendarReturnViewer = New-Object System.Windows.Controls.TextBox
    $calendarReturnViewer.Height = 110
    $calendarReturnViewer.IsReadOnly = $true
    $calendarReturnViewer.TextWrapping = 'Wrap'
    $calendarReturnViewer.VerticalScrollBarVisibility = 'Auto'
    $calendarReturnViewer.HorizontalScrollBarVisibility = 'Auto'
    $calendarReturnViewer.Foreground = [System.Windows.Media.Brushes]::White
    $calendarReturnViewer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
    $calendarReturnViewer.BorderBrush = [System.Windows.Media.Brushes]::White
    $calendarReturnViewer.Visibility = 'Collapsed'
    $calendarPanel.Children.Add($calendarReturnViewer) | Out-Null
    $calendarResultPath = Join-Path $base 'google-calendar-auth-result.json'
    $script:calendarOAuthResultPath = $calendarResultPath
    $script:calendarOAuthInstalled = $null
    $script:calendarFetchReturn = $calendarFetchReturn
    $script:calendarStatus = $calendarStatus
    if (Test-Path -LiteralPath $calendarResultPath) {
        $calendarFetchReturn.Visibility = 'Visible'
        $calendarFetchReturn.IsEnabled = $true
        $calendarReturnViewer.Text = [System.IO.File]::ReadAllText($calendarResultPath)
        $calendarReturnViewer.Visibility = 'Visible'
        $calendarStatus.Text = 'Authorization response found. Click GET CALENDAR RETURN to save the connection.'
    }
    $calendarNext.Tag = 1
    $calendarNext.Add_Click({
        param($s, $e)
        if (-not [string]::IsNullOrWhiteSpace($calendarTextArea.Text)) {
            $calendarStep = 5
            $s.Visibility = 'Collapsed'
            $calendarGuide.Text = 'Final step: click TEST CONNECTION to validate and save the credentials.'
            $calendarLink.Visibility = 'Collapsed'
            $calendarImport.Visibility = 'Visible'
            return
        }
        $step = [int]$s.Tag + 1
        $s.Tag = $step
        if ($step -eq 2) { $calendarGuide.Text = 'Step 2 of 5: From the left menu, open APIs and Services, then Library. Search for Google Calendar API and enable it.' }
        elseif ($step -eq 3) { $calendarGuide.Text = 'Step 3 of 5: From APIs and Services, open Credentials and choose Create Credentials.' }
        elseif ($step -eq 4) { $calendarGuide.Text = 'Step 4 of 5: Choose OAuth client ID, select Desktop app, create it, and click Download JSON.' }
        elseif ($step -ge 5) { $s.Visibility = 'Collapsed'; $calendarGuide.Text = 'Step 5 of 5: paste the downloaded credentials JSON into the text area, then click TEST CONNECTION.'; $calendarLink.Visibility = 'Collapsed'; $calendarImport.Visibility = 'Visible' }
    }.GetNewClosure())
    $calendarImport.Add_Click({
        try {
            $jsonText = [string]$calendarTextArea.Text
            if ([string]::IsNullOrWhiteSpace($jsonText)) { throw 'Paste the credentials JSON into the text area.' }
            $credential = $jsonText | ConvertFrom-Json
            if ($null -eq $credential.installed) { throw 'The JSON must contain an installed credentials object.' }
            $installed = $credential.installed
            $clientId = [string]$installed.client_id
            $clientSecret = [string]$installed.client_secret
            if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) { throw 'The credentials file has no client_id or client_secret.' }

            $resultPath = Join-Path $base 'google-calendar-auth-result.json'
            $urlPath = "$resultPath.url"
            Remove-Item -LiteralPath $resultPath,$urlPath -Force -ErrorAction SilentlyContinue
            $script:calendarOAuthResultPath = $resultPath
            $script:calendarOAuthInstalled = $credential.installed
            $helperPath = Join-Path $base 'google-calendar-auth.ps1'
            $helperArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $helperPath, '-ClientId', $clientId, '-ClientSecret', $clientSecret, '-ProjectId', ([string]$installed.project_id), '-AuthUri', ([string]$installed.auth_uri), '-TokenUri', ([string]$installed.token_uri), '-ResultPath', $resultPath)
            Start-Process -FilePath 'powershell.exe' -ArgumentList $helperArgs -WindowStyle Hidden | Out-Null
            Write-WidgetLog 'OAUTH' 'External Google authentication process started.'
            $calendarStatus.Text = 'Authorize access in the browser...'
            $calendarImport.IsEnabled = $false
            $authState = [pscustomobject]@{ Opened = $false }
            $oauthPollTimer = New-Object System.Windows.Threading.DispatcherTimer
            $oauthPollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
            $oauthPollTimer.Add_Tick({
                try {
                    if (-not $authState.Opened -and (Test-Path -LiteralPath $urlPath)) {
                        $authUrl = [System.IO.File]::ReadAllText($urlPath)
                        Remove-Item -LiteralPath $urlPath -Force -ErrorAction SilentlyContinue
                        $authState.Opened = $true
                        & "$env:WINDIR\System32\rundll32.exe" 'url.dll,FileProtocolHandler' $authUrl
                        Write-WidgetLog 'OAUTH' 'Browser opened by external authentication process.'
                    }
                    if (-not (Test-Path -LiteralPath $resultPath)) { return }
                    $oauthPollTimer.Stop()
                    Save-GoogleCalendarAuthorizationResult $resultPath
                    $script:calendarFetchReturn.Visibility = 'Collapsed'
                    $script:calendarFetchReturn.IsEnabled = $false
                    $calendarReturnViewer.Visibility = 'Collapsed'
                    $script:calendarStatus.Text = 'Google Calendar connected and synchronized.'
                    $script:calendarStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $calendarImport.IsEnabled = $true
                }
                catch {
                    $oauthPollTimer.Stop()
                    $message = $_.Exception.Message
                    Write-WidgetLog 'ERROR' ("External OAuth failed: {0}" -f $_.Exception.ToString())
                    $script:calendarStatus.Dispatcher.BeginInvoke([Action]{ $script:calendarStatus.Text = 'Authorization failed: ' + $message; $script:calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed; $calendarImport.IsEnabled = $true }) | Out-Null
                    $calendarImport.IsEnabled = $true
                }
            }.GetNewClosure())
            $oauthPollTimer.Start()
            return

            $jsonText = [string]$calendarTextArea.Text
            if ([string]::IsNullOrWhiteSpace($jsonText)) { throw 'Paste the credentials JSON into the text area.' }
            [System.IO.File]::WriteAllText($savedCredentialPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
            $credential = @(Get-Content -LiteralPath $savedCredentialPath | ConvertFrom-Json)[0]
            if ($null -eq $credential -or $null -eq $credential.installed) { throw 'The JSON must contain an installed credentials object.' }
            $installed = $credential.installed
            $clientId = [string]$installed.client_id
            $clientSecret = [string]$installed.client_secret
            if ([string]::IsNullOrWhiteSpace([string]$clientId) -or [string]::IsNullOrWhiteSpace([string]$clientSecret)) { throw 'The credentials file has no client_id or client_secret.' }
            $port = Get-Random -Minimum 49152 -Maximum 65535
            $redirectUri = 'http://127.0.0.1:' + $port + '/'
            $authUri = [string]$installed.auth_uri
            $tokenUri = [string]$installed.token_uri
            $listener = New-Object System.Net.HttpListener
            $listener.Prefixes.Add($redirectUri)
            $listener.Start()
            $script:oauthListener = $listener
            Write-WidgetLog 'OAUTH' ("Listening for Google callback at {0}." -f $redirectUri)
            $state = [Guid]::NewGuid().ToString('N')
            $scope = 'https://www.googleapis.com/auth/calendar.readonly'
            $authUrl = $authUri + '?client_id=' + [Uri]::EscapeDataString($clientId) + '&redirect_uri=' + [Uri]::EscapeDataString($redirectUri) + '&response_type=code&scope=' + [Uri]::EscapeDataString($scope) + '&access_type=offline&prompt=consent&state=' + $state
            $calendarStatus.Text = 'Authorize access in the browser...'
            $calendarImport.IsEnabled = $false
            $oauthPreviousWindowTopmost = [bool]$script:window.Topmost
            $oauthPreviousSettingsTopmost = $false
            if ($script:editSettingsWindow -is [System.Windows.Window]) {
                $oauthPreviousSettingsTopmost = [bool]$script:editSettingsWindow.Topmost
                $script:editSettingsWindow.Topmost = $false
            }
            $script:window.Topmost = $false
            $oauthTimer = New-Object System.Windows.Threading.DispatcherTimer
            $oauthTimer.Interval = [TimeSpan]::FromMilliseconds(200)
            $script:oauthTimer = $oauthTimer
            $script:oauthContextTask = $script:oauthListener.GetContextAsync()
            $oauthStartedAt = [DateTime]::UtcNow
            $oauthTimer.Add_Tick({
                try {
                    if ($null -eq $script:oauthContextTask) { return }
                    if (-not $script:oauthContextTask.IsCompleted) {
                        if (([DateTime]::UtcNow - $oauthStartedAt).TotalSeconds -gt 120) {
                            throw 'Google callback timed out after 120 seconds.'
                        }
                        return
                    }
                    if ($script:oauthContextTask.IsFaulted) {
                        throw $script:oauthContextTask.Exception.InnerException
                    }
                    if ($null -eq $script:oauthTimer) { return }
                    $script:oauthTimer.Stop()
                    $context = $script:oauthContextTask.GetAwaiter().GetResult()
                    Write-WidgetLog 'OAUTH' 'Google callback received.'
                    if ($null -eq $context) {
                        throw 'Google callback returned no context.'
                    }
                    $responseText = '<html><body>Google Calendar authorization complete. You may close this window.</body></html>'
                    $bytes = [Text.Encoding]::UTF8.GetBytes($responseText)
                    $context.Response.ContentType = 'text/html; charset=utf-8'
                    $context.Response.ContentLength64 = $bytes.Length
                    $context.Response.KeepAlive = $false
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $context.Response.OutputStream.Close()
                    $context.Response.Close()
                    Write-WidgetLog 'OAUTH' 'Local callback response sent; processing authorization.'
                    $query = $context.Request.QueryString
                    if ([string]$query['state'] -ne $state) { throw 'OAuth state validation failed.' }
                    $code = [string]$query['code']
                    if ([string]::IsNullOrWhiteSpace($code)) { throw ([string]$query['error']) }
                    Write-WidgetLog 'OAUTH' 'Authorization code received; requesting token.'
                    $values = New-Object System.Collections.Specialized.NameValueCollection
                    $values.Add('code', $code)
                    $values.Add('client_id', $clientId)
                    $values.Add('client_secret', $clientSecret)
                    $values.Add('redirect_uri', $redirectUri)
                    $values.Add('grant_type', 'authorization_code')
                    $web = New-Object System.Net.WebClient
                    $tokenBytes = $web.UploadValues($tokenUri, 'POST', $values)
                    $tokens = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject([Text.Encoding]::UTF8.GetString($tokenBytes))
                    if (-not $tokens.ContainsKey('access_token')) { throw 'Google did not return an access token.' }
                    Write-WidgetLog 'OAUTH' 'Google token received.'
                    $calendarConfig = [pscustomobject]@{ clientId = $clientId; clientSecret = $clientSecret; projectId = [string]$installed.project_id; authUri = $authUri; tokenUri = $tokenUri; redirectUri = $redirectUri; accessToken = [string]$tokens['access_token']; refreshToken = [string]$tokens['refresh_token']; credentialFile = 'google-calendar-credentials.json'; configured = $true }
                    [System.IO.File]::WriteAllText($savedCredentialPath, ($calendarConfig | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
                    $script:config | Add-Member -NotePropertyName googleCalendar -NotePropertyValue $calendarConfig -Force
                    Save-Config
                    $calendarStatus.Text = 'Google Calendar connected and saved.'
                    $calendarStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
                    $calendarImport.IsEnabled = $true
                    $script:window.Topmost = $oauthPreviousWindowTopmost
                    if ($script:editSettingsWindow -is [System.Windows.Window]) { $script:editSettingsWindow.Topmost = $oauthPreviousSettingsTopmost }
                } catch {
                    $message = $_.Exception.Message
                    Write-WidgetLog 'ERROR' ("OAuth failed: {0}" -f $_.Exception.ToString())
                    $calendarStatus.Text = 'Authorization failed: ' + $message
                    $calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed
                    $calendarImport.IsEnabled = $true
                    $script:window.Topmost = $oauthPreviousWindowTopmost
                    if ($script:editSettingsWindow -is [System.Windows.Window]) { $script:editSettingsWindow.Topmost = $oauthPreviousSettingsTopmost }
                } finally {
                    if ($null -ne $script:oauthTimer) { $script:oauthTimer.Stop(); $script:oauthTimer = $null }
                    if ($null -ne $script:oauthListener) {
                        $script:oauthListener.Stop()
                        $script:oauthListener.Close()
                        $script:oauthListener = $null
                    }
                    $script:oauthContextTask = $null
                }
            }.GetNewClosure())
            $oauthTimer.Start()
            <#
            if (-not $asyncResult.AsyncWaitHandle.WaitOne(120000)) {
                        Write-WidgetLog 'ERROR' 'Google callback timed out after 120 seconds.'
                        $calendarStatus.Dispatcher.BeginInvoke([Action]{ $calendarStatus.Text = 'Authorization timed out. Try again.'; $calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed; $calendarImport.IsEnabled = $true }) | Out-Null
                        return
                    }
                    $context = $script:oauthListener.EndGetContext($asyncResult)
                    Write-WidgetLog 'OAUTH' 'Google callback received.'
                    $responseText = '<html><body>Google Calendar authorization complete. You may close this window.</body></html>'
                    $bytes = [Text.Encoding]::UTF8.GetBytes($responseText)
                    $context.Response.ContentType = 'text/html; charset=utf-8'
                    $context.Response.ContentLength64 = $bytes.Length
                    $context.Response.KeepAlive = $false
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $context.Response.OutputStream.Flush()
                    $context.Response.OutputStream.Close()
                    $context.Response.Close()
                    Write-WidgetLog 'OAUTH' 'Local callback response sent; processing authorization.'
                    $query = $context.Request.QueryString
                    if ([string]$query['state'] -ne $state) { throw 'OAuth state validation failed.' }
                    $code = [string]$query['code']
                    if ([string]::IsNullOrWhiteSpace($code)) { throw ([string]$query['error']) }
                    Write-WidgetLog 'OAUTH' 'Authorization code received; requesting token.'
                    $values = New-Object System.Collections.Specialized.NameValueCollection
                    $values.Add('code', $code)
                    $values.Add('client_id', $clientId)
                    $values.Add('client_secret', $clientSecret)
                    $values.Add('redirect_uri', $redirectUri)
                    $values.Add('grant_type', 'authorization_code')
                    $web = New-Object System.Net.WebClient
                    $tokenBytes = $web.UploadValues($tokenUri, 'POST', $values)
                    $tokens = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject([Text.Encoding]::UTF8.GetString($tokenBytes))
                    if (-not $tokens.ContainsKey('access_token')) { throw 'Google did not return an access token.' }
                    Write-WidgetLog 'OAUTH' 'Google token received.'
                    $calendarConfig = [pscustomobject]@{ clientId = $clientId; clientSecret = $clientSecret; projectId = [string]$installed.project_id; authUri = $authUri; tokenUri = $tokenUri; redirectUri = $redirectUri; accessToken = [string]$tokens['access_token']; refreshToken = [string]$tokens['refresh_token']; credentialFile = 'google-calendar-credentials.json'; configured = $true }
                    [System.IO.File]::WriteAllText($savedCredentialPath, ($calendarConfig | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
                    $script:config | Add-Member -NotePropertyName googleCalendar -NotePropertyValue $calendarConfig -Force
                    Save-Config
                    $calendarStatus.Dispatcher.BeginInvoke([Action]{ $calendarStatus.Text = 'Google Calendar connected and saved.'; $calendarStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen; $calendarImport.IsEnabled = $true }) | Out-Null
                } catch {
                    $message = $_.Exception.Message
                    Write-WidgetLog 'ERROR' ("OAuth failed: {0}" -f $_.Exception.ToString())
                    $calendarStatus.Dispatcher.BeginInvoke([Action]{ $calendarStatus.Text = 'Authorization failed: ' + $message; $calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed; $calendarImport.IsEnabled = $true }) | Out-Null
                } finally {
                    if ($null -ne $script:oauthListener) {
                        $script:oauthListener.Stop()
                        $script:oauthListener.Close()
                        $script:oauthListener = $null
                    }
                }
            }.GetNewClosure())
            $oauthThread.IsBackground = $true
            $script:oauthThread = $oauthThread
            $oauthThread.Start()
            #>
            & "$env:WINDIR\System32\rundll32.exe" 'url.dll,FileProtocolHandler' $authUrl
            Write-WidgetLog 'OAUTH' 'Browser opened for Google authorization.'
            $calendarInputs['clientId'].Text = $clientId
            $calendarInputs['clientSecret'].Password = $clientSecret
            $calendarInputs['projectId'].Text = [string]$installed.project_id
            $calendarInputs['redirectUri'].Text = $redirectUri
            $calendarFields.Visibility = 'Visible'
            $calendarConfirm.Visibility = 'Visible'
            $calendarStatus.Text = 'Browser opened. Complete Google authorization.'
            $calendarStatus.Foreground = [System.Windows.Media.Brushes]::White
        } catch { $calendarStatus.Text = 'Import failed: ' + $_.Exception.Message; $calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed }
    }.GetNewClosure())
    $calendarFetchReturn.Add_Click({
        try {
            Write-WidgetLog 'OAUTH' 'GET CALENDAR RETURN clicked; reading authorization result.'
            $calendarStatus.Text = 'Reading Google authorization response...'
            $resultPath = Join-Path $base 'google-calendar-auth-result.json'
            if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Google authorization response not found.' }
            Save-GoogleCalendarAuthorizationResult $resultPath
            $script:calendarFetchReturn.IsEnabled = $false
            $script:calendarFetchReturn.Visibility = 'Collapsed'
            $calendarStatus.Text = 'Google Calendar connected and saved.'
            $calendarStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
            Write-WidgetLog 'OAUTH' 'Google Calendar connection saved from returned authorization.'
        } catch {
            $message = $_.Exception.Message
            Write-WidgetLog 'ERROR' ("GET CALENDAR RETURN failed: {0}" -f $message)
            $calendarStatus.Text = 'Connection failed: ' + $message
            $calendarStatus.Foreground = [System.Windows.Media.Brushes]::IndianRed
        }
    }.GetNewClosure())
    $calendarScroll = New-Object System.Windows.Controls.ScrollViewer
    $calendarScroll.VerticalScrollBarVisibility = 'Auto'
    $calendarScroll.HorizontalScrollBarVisibility = 'Disabled'
    $calendarScroll.Content = $calendarPanel
    $calendarTab.Content = New-SettingsContentFrame $calendarScroll
    $calendarTab.Content = New-GoogleCalendarSettingsContent
    $tabs.Items.Add($calendarTab) | Out-Null
    $tabs.Add_SelectionChanged({ if ($tabs.SelectedItem -eq $iconsTab) { $columnsBox.Text = [string]$script:editGridColumns; Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview' } }.GetNewClosure())
    $close.Add_Click({ Cancel-EditSession })
    $settingsWindow.Add_Closed({ $script:editSettingsWindow = $null; $script:settingsProfileCards = $null })
    $settingsWindow.Content = $outer
    Update-SettingsProfileSelection
    $settingsWindow.Show()
    $settingsWindow.Activate() | Out-Null
}
