function Test-BuiltInProfile([string]$id) {
    @('bonebotton', 'bellhart', 'songclave') -contains $id
}

function New-CircularProfileArea {
    $points = @()
    $centerX = 260.0
    $centerY = 270.0
    $radius = 125.0
    for ($index = 0; $index -lt 10; $index++) {
        $angle = ((-90.0 + ($index * 36.0)) * [Math]::PI) / 180.0
        $points += [ordered]@{
            x = [Math]::Round($centerX + ($radius * [Math]::Cos($angle)), 1)
            y = [Math]::Round($centerY + ($radius * [Math]::Sin($angle)), 1)
        }
    }
    [ordered]@{
        type = 'polygon'
        borderVisible = $true
        borderThickness = 2
        borderColor = '#D8FFFFFF'
        fillColor = '#1600A8FF'
        taskSize = 48
        padding = 8
        points = $points
    }
}

function Copy-CustomProfileImage([string]$source, [string]$directory, [string]$name) {
    $extension = [System.IO.Path]::GetExtension($source).ToLowerInvariant()
    $destination = Join-Path $directory ($name + $extension)
    Copy-Item -LiteralPath $source -Destination $destination -Force
    'backgrounds/Custom/' + (Split-Path $directory -Leaf) + '/' + [System.IO.Path]::GetFileName($destination)
}

function Add-CustomProfile([string]$title, [string]$boardImage, [string]$cardImage, [string]$accessoryImage, [string]$emptyImage) {
    $id = 'custom-' + [Guid]::NewGuid().ToString('N')
    $directory = Join-Path $backgroundsDir ('Custom/' + $id)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $background = Copy-CustomProfileImage $boardImage $directory 'board'
    $selectionCard = Copy-CustomProfileImage $cardImage $directory 'selection-card'
    $accessory = Copy-CustomProfileImage $accessoryImage $directory 'accessory'
    $emptyBackground = if ([string]::IsNullOrWhiteSpace($emptyImage)) { $background } else { Copy-CustomProfileImage $emptyImage $directory 'empty-board' }
    $area = New-CircularProfileArea
    $defaults = [ordered]@{ addX = 218; addY = 408; addSize = 84; area = $area }
    $profile = [ordered]@{
        id = $id
        name = $title.Trim()
        protected = $false
        background = $background
        emptyBackground = $emptyBackground
        accessory = $accessory
        selectionCard = $selectionCard
        defaults = $defaults
        state = Copy-JsonObject $defaults
    }
    $relativeProfile = 'backgrounds/Custom/' + $id + '/profile.json'
    [System.IO.File]::WriteAllText((Join-Path $base $relativeProfile), ($profile | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
    $manifest = Read-JsonFile $profilesPath
    $manifest.profiles = @($manifest.profiles) + [pscustomobject]@{ id = $id; file = $relativeProfile }
    [System.IO.File]::WriteAllText($profilesPath, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
    Set-Profile $id $true
    $id
}

function Remove-CustomProfile([string]$id) {
    if (Test-BuiltInProfile $id) { return }
    $manifest = Read-JsonFile $profilesPath
    $entry = @($manifest.profiles | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1)[0]
    if ($null -eq $entry) { return }
    if ([string]$script:editProfileId -eq $id) { Set-Profile 'bonebotton' $true }
    if ([string]$script:config.profile -eq $id) {
        $script:config.profile = 'bonebotton'
        Save-Config
    }
    $manifest.profiles = @($manifest.profiles | Where-Object { [string]$_.id -ne $id })
    [System.IO.File]::WriteAllText($profilesPath, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
    $profilePath = Join-Path $base ([string]$entry.file)
    $directory = Split-Path $profilePath -Parent
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
    Render-Background
    Render-Area
    Render-EditorNodes
    Render-Tasks
}

function Select-CustomProfileImage([System.Windows.Controls.TextBox]$target) {
    $settingsTopmost = if ($script:editSettingsWindow -is [System.Windows.Window]) { [bool]$script:editSettingsWindow.Topmost } else { $false }
    $dialogTopmost = if ($script:customProfileDialog -is [System.Windows.Window]) { [bool]$script:customProfileDialog.Topmost } else { $false }
    if ($script:editSettingsWindow -is [System.Windows.Window]) { $script:editSettingsWindow.Topmost = $false }
    if ($script:customProfileDialog -is [System.Windows.Window]) { $script:customProfileDialog.Topmost = $false }
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.bmp'
    try {
        if ($dialog.ShowDialog() -eq $true) { $target.Text = $dialog.FileName }
    }
    finally {
        if ($script:editSettingsWindow -is [System.Windows.Window]) { $script:editSettingsWindow.Topmost = $settingsTopmost }
        if ($script:customProfileDialog -is [System.Windows.Window]) { $script:customProfileDialog.Topmost = $dialogTopmost }
    }
}

function Show-CreateCustomProfileWindow {
    $dialog = New-Object System.Windows.Window
    $dialog.Title = 'Create Wish Board'
    $dialog.Width = 620
    $dialog.Height = 480
    $dialog.WindowStartupLocation = 'CenterOwner'
    $dialog.ResizeMode = 'NoResize'
    $dialog.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF101014')
    $dialog.Foreground = [System.Windows.Media.Brushes]::White
    $dialog.Topmost = $true
    $script:customProfileDialog = $dialog
    if ($script:editSettingsWindow -is [System.Windows.Window]) { $dialog.Owner = $script:editSettingsWindow }
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = '24'
    $dialog.Content = $panel
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'CREATE WISH BOARD'
    $title.FontSize = 22
    $title.FontWeight = 'SemiBold'
    $title.HorizontalAlignment = 'Center'
    $title.Margin = '0,0,0,18'
    $panel.Children.Add($title) | Out-Null
    $inputs = @{}
    foreach ($field in @(
        [pscustomobject]@{ Key = 'title'; Label = 'Board title *'; Image = $false },
        [pscustomobject]@{ Key = 'board'; Label = 'Board image *'; Image = $true },
        [pscustomobject]@{ Key = 'card'; Label = 'Selection card background *'; Image = $true },
        [pscustomobject]@{ Key = 'accessory'; Label = 'Accessory image *'; Image = $true },
        [pscustomobject]@{ Key = 'empty'; Label = 'Empty board image'; Image = $true }
    )) {
        $row = New-Object System.Windows.Controls.Grid
        $row.Height = 52
        $labelColumn = New-Object System.Windows.Controls.ColumnDefinition
        $labelColumn.Width = New-Object System.Windows.GridLength(190)
        $inputColumn = New-Object System.Windows.Controls.ColumnDefinition
        $inputColumn.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $buttonColumn = New-Object System.Windows.Controls.ColumnDefinition
        $buttonColumn.Width = New-Object System.Windows.GridLength($(if ($field.Image) { 92 } else { 0 }))
        $row.ColumnDefinitions.Add($labelColumn) | Out-Null
        $row.ColumnDefinitions.Add($inputColumn) | Out-Null
        $row.ColumnDefinitions.Add($buttonColumn) | Out-Null
        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = $field.Label
        $label.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($label, 0)
        $row.Children.Add($label) | Out-Null
        $fieldInput = New-Object System.Windows.Controls.TextBox
        $fieldInput.Height = 30
        $fieldInput.Margin = '0,8'
        [System.Windows.Controls.Grid]::SetColumn($fieldInput, 1)
        $row.Children.Add($fieldInput) | Out-Null
        $inputs[$field.Key] = $fieldInput
        if ($field.Image) {
            $browse = New-RoundButton 'BROWSE' 30
            $browse.Width = 82
            $browse.Margin = '10,8,0,8'
            [System.Windows.Controls.Grid]::SetColumn($browse, 2)
            $row.Children.Add($browse) | Out-Null
            $browse.Add_Click({ Select-CustomProfileImage $fieldInput }.GetNewClosure())
        }
        $panel.Children.Add($row) | Out-Null
    }
    $message = New-Object System.Windows.Controls.TextBlock
    $message.Foreground = [System.Windows.Media.Brushes]::OrangeRed
    $message.Height = 28
    $message.TextAlignment = 'Center'
    $panel.Children.Add($message) | Out-Null
    $actions = New-Object System.Windows.Controls.StackPanel
    $actions.Orientation = 'Horizontal'
    $actions.HorizontalAlignment = 'Center'
    $panel.Children.Add($actions) | Out-Null
    $cancel = New-RoundButton 'CANCEL' 34
    $cancel.Width = 100
    $cancel.Margin = '6'
    $cancel.Add_Click({ $dialog.Close() }.GetNewClosure())
    $actions.Children.Add($cancel) | Out-Null
    $create = New-RoundButton 'CREATE' 34
    $create.Width = 100
    $create.Margin = '6'
    $create.Add_Click({
        $required = @($inputs.title.Text, $inputs.board.Text, $inputs.card.Text, $inputs.accessory.Text)
        if (@($required | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { $message.Text = 'Complete all required fields.'; return }
        $invalidImages = @()
        foreach ($path in @($inputs.board.Text, $inputs.card.Text, $inputs.accessory.Text, $inputs.empty.Text)) {
            if (-not [string]::IsNullOrWhiteSpace($path) -and -not (Test-Path -LiteralPath $path)) { $invalidImages += $path }
        }
        if ($invalidImages.Count -gt 0) { $message.Text = 'One or more image files were not found.'; return }
        Add-CustomProfile $inputs.title.Text $inputs.board.Text $inputs.card.Text $inputs.accessory.Text $inputs.empty.Text | Out-Null
        $dialog.DialogResult = $true
        $dialog.Close()
    }.GetNewClosure())
    $actions.Children.Add($create) | Out-Null
    try { $dialog.ShowDialog() }
    finally { $script:customProfileDialog = $null }
}
