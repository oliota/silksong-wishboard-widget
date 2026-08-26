function New-SettingsImage([string]$relativePath, [string]$stretch) {
    $image = New-Object System.Windows.Controls.Image
    $image.Stretch = $stretch
    $image.IsHitTestVisible = $false
    $path = Join-Path $base $relativePath
    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $image.Source = $bitmap
    }
    $image
}

function New-SettingsHighlightBrush([byte]$alpha) {
    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = [System.Windows.Point]::new(0, 0.5)
    $brush.EndPoint = [System.Windows.Point]::new(1, 0.5)
    $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromArgb(0, 255, 255, 255), 0))
    $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromArgb($alpha, 255, 255, 255), 0.5))
    $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new([System.Windows.Media.Color]::FromArgb(0, 255, 255, 255), 1))
    $brush
}

function Update-SettingsProfileSelection {
    if ($null -eq $script:settingsProfileCards) { return }
    foreach ($entry in $script:settingsProfileCards.GetEnumerator()) {
        $selected = [string]$entry.Key -eq [string]$script:editProfileId
        $entry.Value.Outer.Background = if ($selected) { New-SettingsHighlightBrush 76 } else { [System.Windows.Media.Brushes]::Transparent }
        $entry.Value.Frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($selected) { '#FFFFFFFF' } else { '#55FFFFFF' }))
        $entry.Value.Frame.BorderThickness = if ($selected) { 2 } else { 1 }
        if ($selected) {
            $glow = New-Object System.Windows.Media.Effects.DropShadowEffect
            $glow.Color = [System.Windows.Media.Colors]::White
            $glow.BlurRadius = 18
            $glow.ShadowDepth = 0
            $glow.Opacity = 0.75
            $entry.Value.Frame.Effect = $glow
        }
        else {
            $entry.Value.Frame.Effect = $null
        }
    }
}

function New-WishBoardProfileCard($profile, [string]$title, [string]$cardBackground) {
    $outer = New-Object System.Windows.Controls.Border
    $outer.Margin = '10'
    $outer.Padding = '12'
    $outer.CornerRadius = 4

    $button = New-Object System.Windows.Controls.Button
    $button.Tag = [string]$profile.id
    $button.Background = [System.Windows.Media.Brushes]::Transparent
    $button.BorderThickness = 0
    $button.Padding = 0
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $button.HorizontalContentAlignment = 'Stretch'
    $button.VerticalContentAlignment = 'Stretch'
    $outer.Child = $button

    $frame = New-Object System.Windows.Controls.Border
    $frame.Background = [System.Windows.Media.Brushes]::Black
    $frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#55FFFFFF')
    $frame.BorderThickness = 1
    $frame.CornerRadius = 3
    $button.Content = $frame

    $content = New-Object System.Windows.Controls.Grid
    $frame.Child = $content
    $background = New-SettingsImage $cardBackground 'UniformToFill'
    $content.Children.Add($background) | Out-Null

    $shade = New-Object System.Windows.Controls.Border
    $shade.IsHitTestVisible = $false
    $shade.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#24000000')
    $content.Children.Add($shade) | Out-Null

    $titlePanel = New-Object System.Windows.Controls.Border
    $titlePanel.Height = 48
    $titlePanel.VerticalAlignment = 'Top'
    $titlePanel.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B8000000')
    $titlePanel.IsHitTestVisible = $false
    $content.Children.Add($titlePanel) | Out-Null
    $titleText = New-Object System.Windows.Controls.TextBlock
    $titleText.Text = $title.ToUpperInvariant()
    $titleText.Foreground = [System.Windows.Media.Brushes]::White
    $titleText.FontSize = 18
    $titleText.FontWeight = 'SemiBold'
    $titleText.HorizontalAlignment = 'Center'
    $titleText.VerticalAlignment = 'Center'
    $titlePanel.Child = $titleText

    $previewFrame = New-Object System.Windows.Controls.Border
    $previewFrame.Width = 150
    $previewFrame.Height = 150
    $previewFrame.HorizontalAlignment = 'Right'
    $previewFrame.VerticalAlignment = 'Bottom'
    $previewFrame.Margin = '0,0,18,18'
    $previewFrame.Padding = 5
    $previewFrame.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D8000000')
    $previewFrame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#CCFFFFFF')
    $previewFrame.BorderThickness = 1
    $previewFrame.CornerRadius = 3
    $previewFrame.IsHitTestVisible = $false
    [System.Windows.Controls.Panel]::SetZIndex($previewFrame, 2)
    $previewFrame.Child = New-SettingsImage ([string]$profile.background) 'Uniform'
    $content.Children.Add($previewFrame) | Out-Null

    Add-DescriptionCorners $content

    $script:settingsProfileCards[[string]$profile.id] = [pscustomobject]@{ Outer = $outer; Frame = $frame }
    $button.Add_MouseEnter({
        param($s, $e)
        if ([string]$s.Tag -ne [string]$script:editProfileId) {
            $outer.Background = New-SettingsHighlightBrush 54
            $frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#AAFFFFFF')
        }
    }.GetNewClosure())
    $button.Add_MouseLeave({ Update-SettingsProfileSelection })
    $button.Add_Click({
        param($s, $e)
        if (-not $script:editMode) { return }
        $profileId = [string]$s.Tag
        if ($profileId -eq [string]$script:editProfileId) { return }
        Push-EditUndo
        Set-Profile $profileId $true
        Update-SettingsProfileSelection
    })
    $outer
}

function Close-EditSettingsWindow {
    $windowRef = $script:editSettingsWindow
    $script:editSettingsWindow = $null
    $script:settingsProfileCards = $null
    if ($null -ne $windowRef) { $windowRef.Close() }
}

function Show-EditSettingsWindow {
    if (-not $script:editMode) { return }
    if ($null -ne $script:editSettingsWindow) {
        Update-SettingsProfileSelection
        $script:editSettingsWindow.Show()
        $script:editSettingsWindow.Activate() | Out-Null
        return
    }

    $screen = @([System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.Primary } | Select-Object -First 1)[0]
    if ($null -eq $screen) { return }
    $work = $screen.WorkingArea
    $width = [double]$work.Width * 0.7
    $height = [Math]::Max(500.0, [Math]::Min([double]$work.Height * 0.76, $width * 0.56))

    $settingsWindow = New-Object System.Windows.Window
    $settingsWindow.WindowStyle = 'None'
    $settingsWindow.ResizeMode = 'NoResize'
    $settingsWindow.AllowsTransparency = $true
    $settingsWindow.Background = [System.Windows.Media.Brushes]::Transparent
    $settingsWindow.ShowInTaskbar = $false
    $settingsWindow.Topmost = $true
    $settingsWindow.Width = $width
    $settingsWindow.Height = $height
    $settingsWindow.Left = [double]$work.Left + (([double]$work.Width - $width) * 0.5)
    $settingsWindow.Top = [double]$work.Top + (([double]$work.Height - $height) * 0.5)
    $script:editSettingsWindow = $settingsWindow
    $script:settingsProfileCards = @{}

    $outer = New-Object System.Windows.Controls.Grid
    foreach ($rowHeight in @(60, '*', 44)) {
        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = if ($rowHeight -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { New-Object System.Windows.GridLength([double]$rowHeight) }
        $outer.RowDefinitions.Add($row)
    }
    Add-OrnamentShadow $outer 1

    $topOrnament = New-DetailOrnament
    [System.Windows.Controls.Grid]::SetRow($topOrnament, 0)
    $outer.Children.Add($topOrnament) | Out-Null
    $bottomOrnament = New-DetailOrnament $true
    [System.Windows.Controls.Grid]::SetRow($bottomOrnament, 2)
    $outer.Children.Add($bottomOrnament) | Out-Null

    $card = New-Object System.Windows.Controls.Border
    $card.Margin = '26,0'
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FA070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#77FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    [System.Windows.Controls.Grid]::SetRow($card, 1)
    $outer.Children.Add($card) | Out-Null

    $layout = New-Object System.Windows.Controls.Grid
    $headerRow = New-Object System.Windows.Controls.RowDefinition
    $headerRow.Height = New-Object System.Windows.GridLength(62)
    $contentRow = New-Object System.Windows.Controls.RowDefinition
    $contentRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($headerRow)
    $layout.RowDefinitions.Add($contentRow)
    $card.Child = $layout

    $header = New-Object System.Windows.Controls.Grid
    $header.Margin = '24,10,18,0'
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $layout.Children.Add($header) | Out-Null
    $tab = New-Object System.Windows.Controls.StackPanel
    $tab.Width = 240
    $tab.HorizontalAlignment = 'Left'
    $tabTitle = New-Object System.Windows.Controls.TextBlock
    $tabTitle.Text = 'WISH BOARD'
    $tabTitle.Foreground = [System.Windows.Media.Brushes]::White
    $tabTitle.FontSize = 22
    $tabTitle.FontWeight = 'SemiBold'
    $tabTitle.HorizontalAlignment = 'Center'
    $tab.Children.Add($tabTitle) | Out-Null
    $tabOrnament = New-DecorativeAsset 'backgrounds/Controller_Dialogue_0001_bot.png' 18
    $tab.Children.Add($tabOrnament) | Out-Null
    $header.Children.Add($tab) | Out-Null
    $close = New-RoundButton 'X' 30
    $close.HorizontalAlignment = 'Right'
    $close.VerticalAlignment = 'Top'
    $close.ToolTip = 'Close'
    $header.Children.Add($close) | Out-Null

    $cards = New-Object System.Windows.Controls.Grid
    $cards.Margin = '20,0,20,20'
    [System.Windows.Controls.Grid]::SetRow($cards, 1)
    $layout.Children.Add($cards) | Out-Null
    for ($column = 0; $column -lt 3; $column++) {
        $definition = New-Object System.Windows.Controls.ColumnDefinition
        $definition.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $cards.ColumnDefinitions.Add($definition)
    }
    $registry = Read-ProfileRegistry
    $definitions = @(
        [pscustomobject]@{ Id = 'bonebotton'; Title = 'Bone Botton'; Background = 'backgrounds/settings/bonebotton-card.png' }
        [pscustomobject]@{ Id = 'bellhart'; Title = 'Bellhart'; Background = 'backgrounds/settings/bellhart-card.png' }
        [pscustomobject]@{ Id = 'songclave'; Title = 'Songclave'; Background = 'backgrounds/settings/songclave-card.png' }
    )
    for ($index = 0; $index -lt $definitions.Count; $index++) {
        $definition = $definitions[$index]
        $profile = @($registry.profiles | Where-Object { [string]$_.id -eq $definition.Id } | Select-Object -First 1)[0]
        if ($null -eq $profile) { continue }
        $profileCard = New-WishBoardProfileCard $profile $definition.Title $definition.Background
        [System.Windows.Controls.Grid]::SetColumn($profileCard, $index)
        $cards.Children.Add($profileCard) | Out-Null
    }

    $close.Add_Click({ Close-EditSettingsWindow })
    $settingsWindow.Add_Closed({
        $script:editSettingsWindow = $null
        $script:settingsProfileCards = $null
    })
    $settingsWindow.Content = $outer
    Update-SettingsProfileSelection
    $settingsWindow.Show()
    $settingsWindow.Activate() | Out-Null
}
