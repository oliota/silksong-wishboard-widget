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

function New-SettingsTabStyle {
        $style = New-Object System.Windows.Style([System.Windows.Controls.TabItem])
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::White)))
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BackgroundProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF15151B'))))
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderBrushProperty, [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF55555F'))))
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::BorderThicknessProperty, [System.Windows.Thickness]::new(1))))
        $template = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="TabItem">
    <Border x:Name="TabBorder" Margin="0,0,3,0" Padding="16,8" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="5,5,0,0">
        <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center" TextElement.Foreground="{TemplateBinding Foreground}" TextElement.FontWeight="SemiBold"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsSelected" Value="True">
            <Setter TargetName="TabBorder" Property="Background" Value="#FF25252E"/>
            <Setter TargetName="TabBorder" Property="BorderBrush" Value="#FFFFFFFF"/>
            <Setter TargetName="TabBorder" Property="BorderThickness" Value="1,1,1,0"/>
        </Trigger>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="TabBorder" Property="Background" Value="#FF30303A"/>
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::TemplateProperty, $template)))
        $style
}

function New-SettingsContentFrame($content) {
    $frame = New-Object System.Windows.Controls.Border
    $frame.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
    $frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF55555F')
    $frame.BorderThickness = 1
    $frame.Padding = 10
    $surface = New-Object System.Windows.Controls.Grid
    $surface.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
    $surface.Children.Add($content) | Out-Null
    Add-DescriptionCorners $surface
    $frame.Child = $surface
    $frame
}

function Update-SettingsProfileSelection {
    if ($null -eq $script:settingsProfileCards) { return }
    foreach ($entry in $script:settingsProfileCards.GetEnumerator()) {
        $selected = [string]$entry.Key -eq [string]$script:editProfileId
        $entry.Value.Outer.Background = if ($selected) { New-SettingsHighlightBrush 76 } else { [System.Windows.Media.Brushes]::Transparent }
        $entry.Value.Frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($(if ($selected) { '#FFFFFFFF' } else { '#55FFFFFF' }))
        $entry.Value.Frame.BorderThickness = if ($selected) { 2 } else { 1 }
        $entry.Value.Frame.Effect = if ($selected) {
            $glow = New-Object System.Windows.Media.Effects.DropShadowEffect
            $glow.Color = [System.Windows.Media.Colors]::White
            $glow.BlurRadius = 18
            $glow.ShadowDepth = 0
            $glow.Opacity = 0.75
            $glow
        } else { $null }
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
    $background = New-SettingsImage $cardBackground 'Uniform'
    $background.HorizontalAlignment = 'Center'
    $background.VerticalAlignment = 'Center'
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
    $button.Add_MouseEnter({ param($s, $e); if ([string]$s.Tag -ne [string]$script:editProfileId) { $outer.Background = New-SettingsHighlightBrush 54; $frame.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#AAFFFFFF') } }.GetNewClosure())
    $button.Add_MouseLeave({ Update-SettingsProfileSelection })
    $button.Add_Click({ param($s, $e); if (-not $script:editMode) { return }; $profileId = [string]$s.Tag; if ($profileId -eq [string]$script:editProfileId) { return }; Push-EditUndo; Set-Profile $profileId $true; Update-SettingsProfileSelection })
    $outer
}

function Close-EditSettingsWindow {
    $windowRef = $script:editSettingsWindow
    $script:editSettingsWindow = $null
    $script:settingsProfileCards = $null
    foreach ($control in @($script:borderToggle, $script:startupToggle, $script:gridPanel)) {
        if ($null -ne $control -and $null -ne $control.Parent) {
            ([System.Windows.Controls.Panel]$control.Parent).Children.Remove($control)
        }
    }
    if ($null -ne $windowRef) { $windowRef.Close() }
}

function Save-IconCatalogData($catalog, $colors) {
    $iconTemp = "$iconsPath.tmp"
    $colorTemp = "$iconColorsPath.tmp"
    [System.IO.File]::WriteAllText($iconTemp, ($catalog | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($colorTemp, ($colors | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $iconTemp -Destination $iconsPath -Force
    Move-Item -LiteralPath $colorTemp -Destination $iconColorsPath -Force
}

function Get-ConfiguredIconColor([string]$id, [string]$file) {
    $colors = Read-JsonFile $iconColorsPath
    $fileName = [System.IO.Path]::GetFileName($file)
    $entry = @($colors.icons | Where-Object { [string]$_.id -eq $id -or [string]$_.file -eq $fileName }) | Select-Object -First 1
    if ($null -ne $entry -and [string]$entry.color -match '^#[0-9A-Fa-f]{6}$') { return [string]$entry.color }
    '#FFFFFF'
}

function Update-ConfiguredIconColor([string]$id, [string]$file, [string]$color) {
    if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { return }
    $catalog = Read-IconCatalog
    $colors = Read-JsonFile $iconColorsPath
    $fileName = [System.IO.Path]::GetFileName($file)
    $entry = @($colors.icons | Where-Object { [string]$_.id -eq $id -or [string]$_.file -eq $fileName }) | Select-Object -First 1
    if ($null -eq $entry) { $colors.icons = @($colors.icons) + @([pscustomobject][ordered]@{ id = $id; file = $fileName; color = $color }) } else { $entry.color = $color.ToUpperInvariant() }
    Save-IconCatalogData $catalog $colors
    foreach ($task in @($script:tasks | Where-Object { [string]$_.icon -eq $id })) { $task.badgeColor = '#FF' + $color.Substring(1).ToUpperInvariant() }
    Save-Tasks
    Render-Tasks
}

function Restore-OriginalIconCatalog {
    $current = Read-IconCatalog
    $original = Read-JsonFile (Join-Path $base 'icons.default.json')
    foreach ($entry in @($current.icons)) {
        if (@($original.icons | Where-Object { [string]$_.id -eq [string]$entry.id }).Count -eq 0) {
            $path = Join-Path $base ([string]$entry.file)
            if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
        }
    }
    Save-IconCatalogData $original (Read-JsonFile (Join-Path $base 'icons/colors.default.json'))
    foreach ($task in @($script:tasks)) { $task.badgeColor = Get-DominantIconColor ([string]$task.icon) }
    Save-Tasks
    Populate-AddIconGrid
    Render-Tasks
}

function Attach-GridPanelToIconSettings($panel) {
    if ($null -ne $script:gridPanel.Parent) { ([System.Windows.Controls.Panel]$script:gridPanel.Parent).Children.Remove($script:gridPanel) }
    $script:gridPanel.Visibility = 'Visible'
    $script:gridPanel.Margin = '10,18,10,0'
    $script:gridPanel.BorderThickness = 0
    $script:gridPanel.Background = [System.Windows.Media.Brushes]::Transparent
    $panel.Children.Add($script:gridPanel) | Out-Null
}

function Render-IconCatalogEditor($panel) {
    if ($null -ne $script:gridPanel.Parent) { ([System.Windows.Controls.Panel]$script:gridPanel.Parent).Children.Remove($script:gridPanel) }
    $panel.Children.Clear()
    $actions = New-Object System.Windows.Controls.StackPanel
    $actions.Orientation = 'Horizontal'
    $actions.Margin = '0,0,0,10'
    $add = New-RoundButton 'ADD ICON' 100
    $add.Width = 112
    $add.Height = 34
    $restore = New-RoundButton 'RESTORE' 100
    $restore.Width = 112
    $restore.Height = 34
    $restore.Margin = '8,0,0,0'
    $actions.Children.Add($add) | Out-Null
    $actions.Children.Add($restore) | Out-Null
    $panel.Children.Add($actions) | Out-Null
    $add.Add_Click({
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Choose icon PNG'
        $dialog.Filter = 'PNG image (*.png)|*.png'
        if ($dialog.ShowDialog() -ne $true) { return }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $name = [Microsoft.VisualBasic.Interaction]::InputBox('Name for this icon:', 'New icon', [System.IO.Path]::GetFileNameWithoutExtension($dialog.FileName)).Trim()
        $color = [Microsoft.VisualBasic.Interaction]::InputBox('Color in hexadecimal format:', 'New icon color', '#FFFFFF').Trim()
        if ([string]::IsNullOrWhiteSpace($name) -or $color -notmatch '^#[0-9A-Fa-f]{6}$') { return }
        $id = 'icon-' + [Guid]::NewGuid().ToString('N')
        $relative = 'icons/' + $id + '.png'
        Copy-Item -LiteralPath $dialog.FileName -Destination (Join-Path $base $relative) -Force
        $catalog = Read-IconCatalog
        $colors = Read-JsonFile $iconColorsPath
        $catalog.icons = @($catalog.icons) + @([pscustomobject][ordered]@{ id = $id; name = $name; file = $relative })
        $colors.icons = @($colors.icons) + @([pscustomobject][ordered]@{ id = $id; file = $id + '.png'; color = $color.ToUpperInvariant() })
        Save-IconCatalogData $catalog $colors
        Populate-AddIconGrid
        Render-IconCatalogEditor $panel
    }.GetNewClosure())
    $restore.Add_Click({ Restore-OriginalIconCatalog; Render-IconCatalogEditor $panel }.GetNewClosure())
    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.Height = 330
    $list = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $list
    $panel.Children.Add($scroll) | Out-Null
    foreach ($entry in @((Read-IconCatalog).icons)) {
        $row = New-Object System.Windows.Controls.Grid
        $row.Height = 58
        $row.Margin = '0,0,0,1'
        $row.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B')
        foreach ($width in @(52, '*', 100, 70, 70)) { $column = New-Object System.Windows.Controls.ColumnDefinition; $column.Width = if ($width -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { New-Object System.Windows.GridLength([double]$width) }; $row.ColumnDefinitions.Add($column) | Out-Null }
        $preview = New-SettingsImage ([string]$entry.file) 'Uniform'; $preview.Width = 42; $preview.Height = 42; $preview.HorizontalAlignment = 'Center'; $preview.VerticalAlignment = 'Center'; [System.Windows.Controls.Grid]::SetColumn($preview, 0); $row.Children.Add($preview) | Out-Null
        $name = New-Object System.Windows.Controls.TextBlock; $name.Text = [string]$entry.name; $name.Foreground = [System.Windows.Media.Brushes]::White; $name.VerticalAlignment = 'Center'; $name.Margin = '8,0,4,0'; [System.Windows.Controls.Grid]::SetColumn($name, 1); $row.Children.Add($name) | Out-Null
        $color = New-Object System.Windows.Controls.Button; $color.Width = 84; $color.Height = 30; $color.Tag = $entry; $color.Content = Get-ConfiguredIconColor ([string]$entry.id) ([string]$entry.file); $color.Foreground = [System.Windows.Media.Brushes]::White; $color.BorderBrush = [System.Windows.Media.Brushes]::White; $color.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF' + ([string]$color.Content).Substring(1)); $color.ToolTip = 'Choose icon color'; $color.Add_Click({ param($s, $e); $dialog = New-Object System.Windows.Forms.ColorDialog; if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }; $value = '#{0:X2}{1:X2}{2:X2}' -f $dialog.Color.R, $dialog.Color.G, $dialog.Color.B; $s.Content = $value; $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF' + $value.Substring(1)); $item = $s.Tag; Update-ConfiguredIconColor ([string]$item.id) ([string]$item.file) $value; $sample = $s.Parent.Children[3]; $sample.Child = New-TaskBadgeVisual ([pscustomobject]@{ badge = @(Get-BadgeAssets)[0]; label = $null; title = [string]$item.name; badgeColor = '#FF' + $value.Substring(1) }) 48 }.GetNewClosure()); [System.Windows.Controls.Grid]::SetColumn($color, 2); $row.Children.Add($color) | Out-Null
        $sample = New-Object System.Windows.Controls.Border; $sample.Width = 58; $sample.Height = 58; $sample.HorizontalAlignment = 'Center'; $sample.VerticalAlignment = 'Center'; $sample.Child = New-TaskBadgeVisual ([pscustomobject]@{ badge = @(Get-BadgeAssets)[0]; label = $null; title = [string]$entry.name; badgeColor = '#FF' + (Get-ConfiguredIconColor ([string]$entry.id) ([string]$entry.file)).Substring(1) }) 48; [System.Windows.Controls.Grid]::SetColumn($sample, 3); $row.Children.Add($sample) | Out-Null
        $delete = New-RoundButton 'X' 30; $delete.ToolTip = 'Delete icon'; $delete.Tag = $entry; $delete.HorizontalAlignment = 'Center'; $delete.Add_Click({ param($s, $e); $item = $s.Tag; $catalog = Read-IconCatalog; $colors = Read-JsonFile $iconColorsPath; $catalog.icons = @($catalog.icons | Where-Object { [string]$_.id -ne [string]$item.id }); $colors.icons = @($colors.icons | Where-Object { [string]$_.id -ne [string]$item.id -and [string]$_.file -ne [System.IO.Path]::GetFileName([string]$item.file) }); Save-IconCatalogData $catalog $colors; if ([string]$item.file -notmatch '^icons/icon-\d+\.png$') { $path = Join-Path $base ([string]$item.file); if (Test-Path $path) { Remove-Item -LiteralPath $path -Force } }; Populate-AddIconGrid; Render-IconCatalogEditor $panel }.GetNewClosure()); [System.Windows.Controls.Grid]::SetColumn($delete, 4); $row.Children.Add($delete) | Out-Null
        $list.Children.Add($row) | Out-Null
    }
    Attach-GridPanelToIconSettings $panel
}

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
    $close = New-RoundButton 'CANCEL' 30; $close.Width = 86; $close.HorizontalAlignment = 'Right'; $close.VerticalAlignment = 'Top'; $close.ToolTip = 'Cancel edit mode'; $header.Children.Add($close) | Out-Null
    $save = New-RoundButton 'SAVE' 30; $save.Width = 74; $save.Margin = '0,0,92,0'; $save.HorizontalAlignment = 'Right'; $save.VerticalAlignment = 'Top'; $save.ToolTip = 'Save edit mode'; $header.Children.Add($save) | Out-Null
    $save.Add_Click({ $script:editButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }.GetNewClosure())
    $tabs = New-Object System.Windows.Controls.TabControl; $tabs.Margin = '20,0,20,20'; $tabs.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF101014'); $tabs.Foreground = [System.Windows.Media.Brushes]::White; $tabs.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF55555F'); $tabs.ItemContainerStyle = New-SettingsTabStyle; [System.Windows.Controls.Grid]::SetRow($tabs, 1); $layout.Children.Add($tabs) | Out-Null
    $profilesTab = New-Object System.Windows.Controls.TabItem; $profilesTab.Header = 'WISH BOARD'; $profilesTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $profilesTab.Foreground = [System.Windows.Media.Brushes]::White; $profileGrid = New-Object System.Windows.Controls.Grid; $profileGrid.Margin = '10'; for ($column = 0; $column -lt 3; $column++) { $definition = New-Object System.Windows.Controls.ColumnDefinition; $definition.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $profileGrid.ColumnDefinitions.Add($definition) | Out-Null }; $registry = Read-ProfileRegistry; $definitions = @([pscustomobject]@{ Id = 'bonebotton'; Title = 'Bone Botton'; Background = 'backgrounds/settings/bonebotton-card.png' }, [pscustomobject]@{ Id = 'bellhart'; Title = 'Bellhart'; Background = 'backgrounds/settings/bellhart-card.png' }, [pscustomobject]@{ Id = 'songclave'; Title = 'Songclave'; Background = 'backgrounds/settings/songclave-card.png' }); for ($index = 0; $index -lt $definitions.Count; $index++) { $definition = $definitions[$index]; $profile = @($registry.profiles | Where-Object { [string]$_.id -eq $definition.Id } | Select-Object -First 1)[0]; if ($null -eq $profile) { continue }; $profileCard = New-WishBoardProfileCard $profile $definition.Title $definition.Background; [System.Windows.Controls.Grid]::SetColumn($profileCard, $index); $profileGrid.Children.Add($profileCard) | Out-Null }; $tabs.Items.Add($profilesTab) | Out-Null
    $iconsTab = New-Object System.Windows.Controls.TabItem; $iconsTab.Header = 'WISH ICONS'; $iconsTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $iconsTab.Foreground = [System.Windows.Media.Brushes]::White; $iconsContent = New-Object System.Windows.Controls.StackPanel; $iconsContent.Margin = '10'; Render-IconCatalogEditor $iconsContent; $tabs.Items.Add($iconsTab) | Out-Null
    $otherTab = New-Object System.Windows.Controls.TabItem; $otherTab.Header = 'OTHER SETTINGS'; $otherTab.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF202026'); $otherTab.Foreground = [System.Windows.Media.Brushes]::White; $otherPanel = New-Object System.Windows.Controls.StackPanel; $otherPanel.Margin = '18'; foreach ($setting in @([pscustomobject]@{ Control = $script:borderToggle; Description = 'Show or hide the permitted wish area boundary.'; Width = 100 }, [pscustomobject]@{ Control = $script:startupToggle; Description = 'Start the Wish Board automatically when Windows signs in.'; Width = 120 })) { $settingRow = New-Object System.Windows.Controls.Grid; $settingRow.Height = 64; $settingRow.Margin = '0,0,0,1'; $settingRow.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF08080B'); $col = New-Object System.Windows.Controls.ColumnDefinition; $col.Width = New-Object System.Windows.GridLength(130); $textCol = New-Object System.Windows.Controls.ColumnDefinition; $textCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $settingRow.ColumnDefinitions.Add($col) | Out-Null; $settingRow.ColumnDefinitions.Add($textCol) | Out-Null; $setting.Control.Width = $setting.Width; $setting.Control.Height = 34; $setting.Control.Visibility = 'Visible'; [System.Windows.Controls.Grid]::SetColumn($setting.Control, 0); $settingRow.Children.Add($setting.Control) | Out-Null; $description = New-Object System.Windows.Controls.TextBlock; $description.Text = [string]$setting.Description; $description.Foreground = [System.Windows.Media.Brushes]::White; $description.TextWrapping = 'Wrap'; $description.VerticalAlignment = 'Center'; $description.Margin = '12,0,4,0'; [System.Windows.Controls.Grid]::SetColumn($description, 1); $settingRow.Children.Add($description) | Out-Null; $otherPanel.Children.Add($settingRow) | Out-Null }; $tabs.Items.Add($otherTab) | Out-Null
    $profilesTab.Content = New-SettingsContentFrame $profileGrid
    $iconsTab.Content = New-SettingsContentFrame $iconsContent
    $otherScroll = New-Object System.Windows.Controls.ScrollViewer
    $otherScroll.Height = 330
    $otherScroll.VerticalScrollBarVisibility = 'Auto'
    $otherScroll.Content = $otherPanel
    $otherTab.Content = New-SettingsContentFrame $otherScroll
    $tabs.Add_SelectionChanged({ if ($tabs.SelectedItem -eq $iconsTab) { $columnsBox.Text = [string]$script:editGridColumns; Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview' } }.GetNewClosure())
    $close.Add_Click({ Cancel-EditSession })
    $settingsWindow.Add_Closed({ $script:editSettingsWindow = $null; $script:settingsProfileCards = $null })
    $settingsWindow.Content = $outer
    Update-SettingsProfileSelection
    $settingsWindow.Show()
    $settingsWindow.Activate() | Out-Null
}
