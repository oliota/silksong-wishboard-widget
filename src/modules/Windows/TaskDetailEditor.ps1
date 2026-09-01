function Set-DetailEditVisual($button, [bool]$saveMode) {
    $view = New-Object System.Windows.Controls.Viewbox
    $view.Width = 17
    $view.Height = 17

    $path = New-Object System.Windows.Shapes.Path
    $path.Stroke = [System.Windows.Media.Brushes]::White
    $path.StrokeThickness = 1.8
    $path.StrokeStartLineCap = 'Round'
    $path.StrokeEndLineCap = 'Round'
    $path.StrokeLineJoin = 'Round'
    $path.Fill = [System.Windows.Media.Brushes]::Transparent

    if ($saveMode) {
        $path.Data = [System.Windows.Media.Geometry]::Parse(
            'M3,3 L14,3 L17,6 L17,17 L3,17 Z M6,3 L6,8 L13,8 L13,3 M6,12 L14,12 L14,17 L6,17 Z'
        )
        $button.ToolTip = 'Save'
    }
    else {
        $path.Data = [System.Windows.Media.Geometry]::Parse(
            'M3,14 L4,10 L12,2 L16,6 L8,14 Z M11,3 L15,7'
        )
        $button.ToolTip = 'Edit'
    }

    $view.Child = $path
    $button.Content = $view
}

function Show-TaskIconChooser(
    [System.Windows.Window]$Owner,
    [string]$SelectedIcon
) {
    $chooser = New-Object System.Windows.Window
    $chooser.WindowStyle = 'None'
    $chooser.ResizeMode = 'NoResize'
    $chooser.AllowsTransparency = $true
    $chooser.Background = [System.Windows.Media.Brushes]::Transparent
    $chooser.ShowInTaskbar = $false
    $chooser.Topmost = $true
    $chooser.Width = 390
    $chooser.Height = 430
    $chooser.WindowStartupLocation = 'CenterOwner'

    if ($null -ne $Owner) {
        $chooser.Owner = $Owner
    }

    $chooser.Tag = $null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F51A1A1E')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#99FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 10
    $card.Padding = 14
    $chooser.Content = $card

    $layout = New-Object System.Windows.Controls.Grid
    $card.Child = $layout

    $topRow = New-Object System.Windows.Controls.RowDefinition
    $topRow.Height = New-Object System.Windows.GridLength(40)
    $contentRow = New-Object System.Windows.Controls.RowDefinition
    $contentRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($topRow)
    $layout.RowDefinitions.Add($contentRow)

    $header = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($header, 0)
    $layout.Children.Add($header) | Out-Null

    $hc1 = New-Object System.Windows.Controls.ColumnDefinition
    $hc1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $hc2 = New-Object System.Windows.Controls.ColumnDefinition
    $hc2.Width = New-Object System.Windows.GridLength(36)
    $header.ColumnDefinitions.Add($hc1)
    $header.ColumnDefinitions.Add($hc2)

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = 'Choose Icon'
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 17
    $title.FontWeight = 'SemiBold'
    $title.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($title, 0)
    $header.Children.Add($title) | Out-Null

    $close = New-RoundButton 'X' 30
    $close.ToolTip = 'Close'
    [System.Windows.Controls.Grid]::SetColumn($close, 1)
    $header.Children.Add($close) | Out-Null

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    [System.Windows.Controls.Grid]::SetRow($scroll, 1)
    $layout.Children.Add($scroll) | Out-Null

    $grid = New-Object System.Windows.Controls.WrapPanel
    $grid.Orientation = 'Horizontal'
    $scroll.Content = $grid

    $columns = [Math]::Max(1, [Math]::Min(8, [int]$script:config.icons.columns))
    $availableWidth = 340.0
    $cell = [Math]::Max(42.0, [Math]::Floor($availableWidth / [double]$columns) - 6.0)
    $imageSize = [Math]::Max(30.0, $cell - 10.0)

    $catalog = Read-IconCatalog

    foreach ($entry in @($catalog.icons)) {
        $button = New-Object System.Windows.Controls.Button
        $button.Tag = [string]$entry.id
        $button.Width = $cell
        $button.Height = $cell
        $button.Margin = '3'
        $button.Padding = '3'
        $button.ToolTip = [string]$entry.name
        $button.Content = New-ImageControl ([string]$entry.file) $imageSize

        if ([string]$entry.id -eq $SelectedIcon) {
            $button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF2ECC71')
            $button.BorderThickness = 3
        }

        $button.Add_Click({
            param($s, $e)
            $chooser.Tag = [string]$s.Tag
            $chooser.DialogResult = $true
            $chooser.Close()
        }.GetNewClosure())

        $grid.Children.Add($button) | Out-Null
    }

    $close.Add_Click({
        $chooser.Tag = $null
        $chooser.DialogResult = $false
        $chooser.Close()
    }.GetNewClosure())

    $result = $chooser.ShowDialog()

    $selected = [string]$chooser.Tag

    if ($result -eq $true -and -not [string]::IsNullOrWhiteSpace($selected)) {
        return $selected
    }

    return $null
}

function Set-DetailIconById([string]$iconId) {
    if ($null -eq $script:detailIconHost) { return }

    $entry = Get-IconEntry $iconId

    if ($null -eq $entry) {
        $script:detailIconHost.Child = $null
        return
    }

    $script:detailIconHost.Child = New-ImageControl ([string]$entry.file) 68
}

function Update-DescriptionOverflowIndicator {
    if ($null -eq $script:detailOverflowIndicator -or $null -eq $script:detailDescriptionScroll) { return }

    $hasMore = -not $script:detailEditing -and
        [double]$script:detailDescriptionScroll.ScrollableHeight -gt 1.0 -and
        [double]$script:detailDescriptionScroll.VerticalOffset -lt ([double]$script:detailDescriptionScroll.ScrollableHeight - 1.0)
    $script:detailOverflowIndicator.Visibility = if ($hasMore) { 'Visible' } else { 'Collapsed' }
}

function Set-DetailReadMode {
    if ($null -eq $script:detailEditButton) { return }

    $script:detailEditing = $false
    $script:detailDeleteTopButton.Visibility = 'Visible'
    Set-DetailEditVisual $script:detailEditButton $false
    $script:detailTitleText.Visibility = 'Visible'
    $script:detailDescriptionScroll.Visibility = 'Visible'
    $script:detailTitleBox.Visibility = 'Collapsed'
    $script:detailDescriptionBox.Visibility = 'Collapsed'
    $script:detailChangeIconButton.Visibility = 'Collapsed'
    $script:detailEditActions.Visibility = 'Collapsed'
    $script:detailActionsRow.Height = New-Object System.Windows.GridLength(0)
    $script:detailDescriptionScroll.Dispatcher.BeginInvoke(
        [System.Action]{ Update-DescriptionOverflowIndicator },
        [System.Windows.Threading.DispatcherPriority]::Loaded
    ) | Out-Null
}

function Set-DetailEditMode {
    $task = Get-TaskById ([string]$script:detailCurrentTaskId)
    if ($null -eq $task) { return }

    $script:detailEditing = $true
    $script:detailDeleteTopButton.Visibility = 'Collapsed'
    Set-DetailEditVisual $script:detailEditButton $true

    $script:detailTitleBox.Text = [string]$task.title
    $script:detailDescriptionBox.Text = [string]$task.description
    $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) { 'icon-01' } else { [string]$task.icon }

    Set-DetailIconById $script:detailPendingIconId

    $script:detailTitleText.Visibility = 'Collapsed'
    $script:detailDescriptionScroll.Visibility = 'Collapsed'
    $script:detailTitleBox.Visibility = 'Visible'
    $script:detailDescriptionBox.Visibility = 'Visible'
    $script:detailChangeIconButton.Visibility = 'Visible'
    $script:detailEditActions.Visibility = 'Visible'
    $script:detailActionsRow.Height = New-Object System.Windows.GridLength(86)
    Update-DescriptionOverflowIndicator
}

function Save-DetailItem {
    $task = Get-TaskById ([string]$script:detailCurrentTaskId)
    if ($null -eq $task) { return }

    $title = $script:detailTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = 'Untitled'
    }

    $task.title = $title
    $task.description = $script:detailDescriptionBox.Text.Trim()
    $task.icon = [string]$script:detailPendingIconId
    $task | Add-Member -NotePropertyName badgeColor -NotePropertyValue (Get-DominantIconColor ([string]$task.icon)) -Force

    Save-Tasks

    $script:detailTitleText.Text = [string]$task.title
    $script:detailDescriptionText.Text = [string]$task.description
    Set-DetailIconById ([string]$task.icon)
    Set-DetailReadMode
    Render-Tasks
}

function Close-DetailWindow {
    $detailRef = $script:activeDetailWindow

    $script:activeDetailWindow = $null
    $script:detailCurrentTaskId = $null
    $script:detailEditing = $false

    if ($null -ne $detailRef) {
        try {
            $detailRef.Close()
        }
        catch {
        }
    }
}

function Delete-DetailItem {
    if ($script:detailEditing) { return }

    $targetId = [string]$script:detailCurrentTaskId
    if ([string]::IsNullOrWhiteSpace($targetId)) { return }

    $targetTask = Get-TaskById $targetId
    if ($null -eq $targetTask) { return }
    Start-TaskDeletionAnimation $targetTask {
        param($task)
        $deletedId = [string]$task.id
        $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $deletedId })
        Save-Tasks
        Add-PositionToCache ([double]$task.x) ([double]$task.y) ([double]$script:area.taskSize)
        Render-Tasks
        Close-DetailWindow
    }
}

