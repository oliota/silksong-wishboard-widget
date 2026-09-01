function Add-BackgroundOptionRow($entry) {
    $row = New-Object System.Windows.Controls.Grid
    $row.Height = 42
    $row.Margin = '0,0,0,6'

    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = New-Object System.Windows.GridLength(38)
    $row.ColumnDefinitions.Add($col1)
    $row.ColumnDefinitions.Add($col2)

    $select = New-Object System.Windows.Controls.Button
    $select.Content = [string]$entry.name
    $select.ToolTip = [string]$entry.name
    $select.Tag = [string]$entry.id
    $select.HorizontalContentAlignment = 'Left'
    $select.Padding = '10,0,10,0'
    $select.Height = 36

    if ([string]$entry.id -eq [string]$script:editProfileId) {
        $select.FontWeight = 'Bold'
    }

    $select.Add_Click({
        param($s, $e)

        if (-not $script:editMode) { return }

        Push-EditUndo
        Set-Profile ([string]$s.Tag) $true
        Render-BackgroundChoices
        $script:backgroundPanel.Visibility = 'Collapsed'
    })

    [System.Windows.Controls.Grid]::SetColumn($select, 0)
    $row.Children.Add($select) | Out-Null

    if ($false) {
        $delete = New-Object System.Windows.Controls.Button
        $delete.Content = 'X'
        $delete.ToolTip = 'Delete Background'
        $delete.Tag = [string]$entry.id
        $delete.Width = 32
        $delete.Height = 32
        $delete.Margin = '4,2,0,2'

        $delete.Add_Click({
            param($s, $e)

            if (-not $script:editMode) { return }

            $id = [string]$s.Tag

            if ($id -eq 'default') { return }

            Push-EditUndo
            [void]$script:pendingDeletedBackgroundIds.Add($id)

            $registry = Read-BackgroundRegistry
            $entryToDelete = @($registry.backgrounds | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1

            if ($null -ne $entryToDelete -and [string]$entryToDelete.file -eq [string]$script:editBackgroundFile) {
                $default = Get-DefaultBackground
                $script:editBackgroundFile = [string]$default.file
                Render-Background
            }

            Render-BackgroundChoices
        })

        [System.Windows.Controls.Grid]::SetColumn($delete, 1)
        $row.Children.Add($delete) | Out-Null
    }

    $script:backgroundList.Children.Add($row) | Out-Null
}
