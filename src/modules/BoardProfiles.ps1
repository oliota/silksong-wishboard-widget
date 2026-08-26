function Set-EditButtonVisual([bool]$saveMode) {
    $viewbox = New-Object System.Windows.Controls.Viewbox
    $viewbox.Width = 17
    $viewbox.Height = 17

    $path = New-Object System.Windows.Shapes.Path
    $path.Stroke = [System.Windows.Media.Brushes]::White
    $path.StrokeThickness = 1.8
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.StrokeLineJoin = 'Round'
    $path.Fill = [System.Windows.Media.Brushes]::Transparent

    if ($saveMode) {
        $path.Data = [System.Windows.Media.Geometry]::Parse('M3,3 L14,3 L17,6 L17,17 L3,17 Z M6,3 L6,8 L13,8 L13,3 M6,12 L14,12 L14,17 L6,17 Z')
        $script:editButton.ToolTip = 'Save'
    }
    else {
        $path.Data = [System.Windows.Media.Geometry]::Parse('M3,15 L5,10 L13,2 L16,5 L8,13 Z M12,3 L15,6')
        $script:editButton.ToolTip = 'Edit'
    }

    $viewbox.Child = $path
    $script:editButton.Content = $viewbox
}

function Read-BackgroundRegistry {
    if (-not (Test-Path $backgroundsPath)) {
        return [pscustomobject]@{ backgrounds = @() }
    }

    $data = Read-JsonFile $backgroundsPath

    if ($null -eq $data.backgrounds) {
        $data | Add-Member -NotePropertyName backgrounds -NotePropertyValue @()
    }

    $data
}

function Read-ProfileRegistry {
    $manifest = Read-JsonFile $profilesPath
    $profiles = @()
    foreach ($entry in @($manifest.profiles)) {
        $profile = Read-JsonFile (Join-Path $base ([string]$entry.file))
        $profile | Add-Member -NotePropertyName sourceFile -NotePropertyValue ([string]$entry.file) -Force
        $profiles += $profile
    }
    [pscustomobject]@{ profiles = $profiles }
}

function Get-Profile([string]$id) {
    $registry = Read-ProfileRegistry
    @($registry.profiles | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
}

function Get-ActiveProfile {
    $id = if ($script:editMode -and -not [string]::IsNullOrWhiteSpace([string]$script:editProfileId)) { [string]$script:editProfileId } else { [string]$script:config.profile }
    Get-Profile $id
}

function Save-ProfileRegistry($registry) {
    foreach ($profile in @($registry.profiles)) {
        $path = Join-Path $base ([string]$profile.sourceFile)
        $profile.PSObject.Properties.Remove('sourceFile')
        $tempPath = "$path.tmp"
        [System.IO.File]::WriteAllText($tempPath, ($profile | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $path -Force
    }
}

function Set-Profile([string]$id, [bool]$editing) {
    $profile = Get-Profile $id
    if ($null -eq $profile) { return }
    $state = if ($null -ne $profile.state) { Copy-JsonObject $profile.state } else { Copy-JsonObject $profile.defaults }
    if ($editing) {
        $script:editProfileId = $id
        $script:editWorkingArea = Copy-JsonObject $state.area
        $script:editAddX = [double]$state.addX
        $script:editAddY = [double]$state.addY
        $script:config.buttons.addSize = [double]$state.addSize
    }
    else {
        $script:config.profile = $id
        $script:area = Copy-JsonObject $state.area
        $script:config.buttons.addX = [double]$state.addX
        $script:config.buttons.addY = [double]$state.addY
        $script:config.buttons.addSize = [double]$state.addSize
        Save-Area $script:area
        Save-Config
    }
    Render-Background
    Apply-Config
    Render-Area
    Render-EditorNodes
    Render-Tasks
}

function Save-ActiveProfileState {
    $registry = Read-ProfileRegistry
    $profile = @($registry.profiles | Where-Object { [string]$_.id -eq [string]$script:config.profile }) | Select-Object -First 1
    if ($null -eq $profile) { return }
    if ($null -eq $profile.state) { $profile.state = Copy-JsonObject $profile.defaults }
    $profile.state.area = Copy-JsonObject $script:area
    $profile.state.addX = [Math]::Round([double]$script:config.buttons.addX, 1)
    $profile.state.addY = [Math]::Round([double]$script:config.buttons.addY, 1)
    $profile.state.addSize = [Math]::Round([double]$script:config.buttons.addSize, 1)
    Save-ProfileRegistry $registry
}

function Save-BackgroundRegistry($registry) {
    $tempPath = "$backgroundsPath.tmp"
    $json = $registry | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $backgroundsPath -Force
}

function Get-DefaultBackground {
    $registry = Read-BackgroundRegistry
    @($registry.backgrounds | Where-Object { [string]$_.id -eq 'default' }) | Select-Object -First 1
}


function Get-ActiveBackgroundScale {
    if ($script:editMode) { return [double]$script:editBackgroundScale }
    return [double]$script:config.background.scale
}

function Get-ActiveBackgroundOffsetX {
    if ($script:editMode) { return [double]$script:editBackgroundOffsetX }
    return [double]$script:config.background.offsetX
}

function Get-ActiveBackgroundOffsetY {
    if ($script:editMode) { return [double]$script:editBackgroundOffsetY }
    return [double]$script:config.background.offsetY
}

function Get-ActiveAddX {
    if ($script:editMode -and $null -ne $script:editAddX) { return [double]$script:editAddX }
    if ($null -ne $script:config.buttons.addX) { return [double]$script:config.buttons.addX }
    return $null
}

function Get-ActiveAddY {
    if ($script:editMode -and $null -ne $script:editAddY) { return [double]$script:editAddY }
    if ($null -ne $script:config.buttons.addY) { return [double]$script:config.buttons.addY }
    return $null
}

function Get-ActiveBackgroundFile {
    $profile = Get-ActiveProfile
    if ($null -eq $profile) { return [string]$script:config.background.file }
    if (@($script:tasks).Count -eq 0) { return [string]$profile.emptyBackground }
    [string]$profile.background
}

function New-EditCheckpoint {
    [pscustomobject][ordered]@{
        area = Copy-JsonObject $script:editWorkingArea
        profileId = [string]$script:editProfileId
        backgroundFile = [string]$script:editBackgroundFile
        backgroundScale = [double]$script:editBackgroundScale
        backgroundOffsetX = [double]$script:editBackgroundOffsetX
        backgroundOffsetY = [double]$script:editBackgroundOffsetY
        addX = $script:editAddX
        addY = $script:editAddY
        gridColumns = [int]$script:editGridColumns
    }
}

function Save-Tasks {
    $payload = [ordered]@{ tasks = @($script:tasks) }
    $tempPath = "$tasksPath.tmp"
    $json = $payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $tasksPath -Force
    $script:tasks = @(Read-Tasks)
    $script:tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc
}

function Get-TaskById([string]$id) {
    @($script:tasks | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
}

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


