function Render-BackgroundChoices {
    if ($null -eq $script:backgroundList) { return }

    $script:backgroundList.Children.Clear()

    $browse = New-Object System.Windows.Controls.Button
    $browse.Content = 'Browse in PC...'
    $browse.ToolTip = 'Browse Backgrounds'
    $browse.Height = 38
    $browse.Margin = '0,0,0,10'
    $browse.FontWeight = 'SemiBold'

    $browse.Add_Click({
        if (-not $script:editMode) { return }

        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Choose PNG background'
        $dialog.Filter = 'PNG image (*.png)|*.png'
        $dialog.Multiselect = $false

        if ($dialog.ShowDialog() -ne $true) { return }

        Add-Type -AssemblyName Microsoft.VisualBasic
        $name = [Microsoft.VisualBasic.Interaction]::InputBox(
            'Name for this background:',
            'Background name',
            [System.IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
        ).Trim()

        if ([string]::IsNullOrWhiteSpace($name)) { return }

        $registry = Read-BackgroundRegistry

        if (@($registry.backgrounds | Where-Object { [string]$_.name -ieq $name }).Count -gt 0) {
            [System.Windows.MessageBox]::Show('A background with this name already exists.', 'Desktop Widget') | Out-Null
            return
        }

        $id = 'bg-' + [Guid]::NewGuid().ToString('N')
        $relative = 'backgrounds/' + $id + '.png'
        $destination = Join-Path $base $relative

        Copy-Item -LiteralPath $dialog.FileName -Destination $destination -Force

        $newEntry = [pscustomobject][ordered]@{
            id = $id
            name = $name
            file = $relative
            protected = $false
        }

        $registry.backgrounds = @($registry.backgrounds) + @($newEntry)
        Save-BackgroundRegistry $registry

        Push-EditUndo
        $script:editBackgroundFile = $relative
        Render-Background
        Render-BackgroundChoices
        $script:backgroundPanel.Visibility = 'Collapsed'
    })

    $browse.Visibility = 'Collapsed'

    $registry = Read-ProfileRegistry

    foreach ($entry in @($registry.profiles)) {
        if ($script:pendingDeletedBackgroundIds.Contains([string]$entry.id)) {
            continue
        }

        Add-BackgroundOptionRow $entry
    }
}
