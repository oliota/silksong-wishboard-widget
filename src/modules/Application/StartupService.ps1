function Get-StartupShortcutPath {
    Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)) 'Silksong Wish Board.lnk'
}

function Test-StartupEnabled {
    Test-Path -LiteralPath (Get-StartupShortcutPath)
}

function Enable-Startup {
    $projectRoot = Split-Path -Parent $base
    $launcher = Join-Path $projectRoot 'Desktop Wish Board.vbs'
    if (-not (Test-Path -LiteralPath $launcher)) { throw 'Launcher not found.' }
    $startupDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
    if (-not (Test-Path -LiteralPath $startupDirectory)) {
        New-Item -ItemType Directory -Path $startupDirectory -Force | Out-Null
    }
    $shell = New-Object -ComObject WScript.Shell
    try {
        $shortcut = $shell.CreateShortcut((Get-StartupShortcutPath))
        $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
        $shortcut.Arguments = '"' + $launcher + '"'
        $shortcut.WorkingDirectory = $projectRoot
        $shortcut.IconLocation = (Join-Path $base 'widget.ico') + ',0'
        $shortcut.Description = 'Silksong Wish Board Widget'
        $shortcut.Save()
    }
    finally {
        if ($null -ne $shortcut) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut) }
        if ($null -ne $shell) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
    }
}

function Disable-Startup {
    $shortcutPath = Get-StartupShortcutPath
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }
}

function Update-StartupButton {
    if ($null -eq $script:startupToggle) { return }
    $enabled = Test-StartupEnabled
    $script:startupToggle.Content = if ($enabled) { 'STARTUP ON' } else { 'STARTUP OFF' }
    $script:startupToggle.ToolTip = if ($enabled) { 'Disable Start with Windows' } else { 'Enable Start with Windows' }
    $script:startupToggle.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
        $(if ($enabled) { '#CC198754' } else { '#CCD93025' })
    )
}

function New-RoundButton([string]$text, [double]$size) {
    $button = New-Object System.Windows.Controls.Button
    $button.Width = $size
    $button.Height = $size
    $button.Content = $text
    $button.Foreground = [System.Windows.Media.Brushes]::White
    $button.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(180, 22, 22, 26))
    $button.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 225, 225, 225))
    $button.BorderThickness = '1'
    $button.FontSize = 12
    $button.FontWeight = 'SemiBold'
    $button.Cursor = 'Hand'
    $button.Template = [System.Windows.Markup.XamlReader]::Parse(@"
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
  <Border CornerRadius="999" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="4"/>
  </Border>
</ControlTemplate>
"@)
    $button
}

