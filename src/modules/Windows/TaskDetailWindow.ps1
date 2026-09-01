function Show-DetailsById([string]$taskId) {
    $task = Get-TaskById $taskId
    if ($null -eq $task) { return }

    $script:detailCurrentTaskId = [string]$taskId
    $script:detailEditing = $false

    if ($null -ne $script:activeDetailWindow) {
        try {
            if ($script:activeDetailWindow.IsVisible) {
                $script:activeDetailWindow.Close()
            }
        }
        catch {
        }

        $script:activeDetailWindow = $null
    }

    $detailWindow = New-Object System.Windows.Window
    $detailWindow.WindowStyle = 'None'
    $detailWindow.ResizeMode = 'NoResize'
    $detailWindow.AllowsTransparency = $true
    $detailWindow.Background = [System.Windows.Media.Brushes]::Transparent
    $detailWindow.ShowInTaskbar = $false
    $detailWindow.Topmost = $true
    $detailMinimumHeight = [Math]::Max(540.0, [double]$script:config.detailWindow.minHeight)
    $configuredWidth = [Math]::Max([double]$script:config.detailWindow.minWidth, [double]$script:config.detailWindow.width)
    $configuredHeight = [Math]::Max($detailMinimumHeight, [double]$script:config.detailWindow.height)
    $detailAspectRatio = $configuredWidth / $configuredHeight
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $detailMaximumWidth = [Math]::Min(
        [double]$workArea.Width * 0.7,
        [double]$workArea.Height * 0.9 * $detailAspectRatio
    )
    $detailMaximumHeight = $detailMaximumWidth / $detailAspectRatio
    $effectiveMinimumHeight = [Math]::Min($detailMinimumHeight, $detailMaximumHeight)
    $detailMinimumWidth = [Math]::Min(
        $detailMaximumWidth,
        [Math]::Max([double]$script:config.detailWindow.minWidth, $effectiveMinimumHeight * $detailAspectRatio)
    )
    $detailWindow.Width = [Math]::Min($detailMaximumWidth, [Math]::Max($detailMinimumWidth, $configuredWidth))
    $detailWindow.Height = $detailWindow.Width / $detailAspectRatio
    $detailWindow.MinWidth = $detailMinimumWidth
    $detailWindow.MinHeight = $effectiveMinimumHeight
    $detailWindow.MaxWidth = $detailMaximumWidth
    $detailWindow.MaxHeight = $detailMaximumHeight
    $detailWindow.WindowStartupLocation = 'Manual'
    $script:activeDetailWindow = $detailWindow

    $outer = New-Object System.Windows.Controls.Grid
    $detailWindow.Content = $outer

    $ornamentTopRow = New-Object System.Windows.Controls.RowDefinition
    $ornamentTopRow.Height = New-Object System.Windows.GridLength(52)
    $cardRow = New-Object System.Windows.Controls.RowDefinition
    $cardRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $ornamentBottomRow = New-Object System.Windows.Controls.RowDefinition
    $ornamentBottomRow.Height = New-Object System.Windows.GridLength(38)
    $outer.RowDefinitions.Add($ornamentTopRow)
    $outer.RowDefinitions.Add($cardRow)
    $outer.RowDefinitions.Add($ornamentBottomRow)

    Add-OrnamentShadow $outer 1

    $topOrnament = New-DetailOrnament
    [System.Windows.Controls.Grid]::SetRow($topOrnament, 0)
    $outer.Children.Add($topOrnament) | Out-Null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F4070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#44FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    $card.Padding = 18
    $card.Margin = '24,0'
    [System.Windows.Controls.Grid]::SetRow($card, 1)
    $outer.Children.Add($card) | Out-Null

    $bottomOrnament = New-DetailOrnament $true
    [System.Windows.Controls.Grid]::SetRow($bottomOrnament, 2)
    $outer.Children.Add($bottomOrnament) | Out-Null

    $layout = New-Object System.Windows.Controls.Grid
    $card.Child = $layout

    $toolbarRow = New-Object System.Windows.Controls.RowDefinition
    $toolbarRow.Height = New-Object System.Windows.GridLength(38)
    $bodyRow = New-Object System.Windows.Controls.RowDefinition
    $bodyRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $layout.RowDefinitions.Add($toolbarRow)
    $layout.RowDefinitions.Add($bodyRow)

    $toolbar = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($toolbar, 0)
    $layout.Children.Add($toolbar) | Out-Null

    $toolbarSpacer = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarSpacer.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $toolbarEditCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarEditCol.Width = New-Object System.Windows.GridLength(36)
    $toolbarDeleteCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarDeleteCol.Width = New-Object System.Windows.GridLength(36)
    $toolbarCloseCol = New-Object System.Windows.Controls.ColumnDefinition
    $toolbarCloseCol.Width = New-Object System.Windows.GridLength(36)
    $toolbar.ColumnDefinitions.Add($toolbarSpacer)
    $toolbar.ColumnDefinitions.Add($toolbarEditCol)
    $toolbar.ColumnDefinitions.Add($toolbarDeleteCol)
    $toolbar.ColumnDefinitions.Add($toolbarCloseCol)

    $detailEditButton = New-RoundButton '' 30
    $script:detailEditButton = $detailEditButton
    Set-DetailEditVisual $detailEditButton $false
    [System.Windows.Controls.Grid]::SetColumn($detailEditButton, 1)
    $toolbar.Children.Add($detailEditButton) | Out-Null

    $detailDeleteTopButton = New-RoundButton '' 30
    $script:detailDeleteTopButton = $detailDeleteTopButton
    $detailDeleteTopButton.ToolTip = 'Delete'
    $trashView = New-Object System.Windows.Controls.Viewbox
    $trashView.Width = 16
    $trashView.Height = 16
    $trashPath = New-Object System.Windows.Shapes.Path
    $trashPath.Stroke = [System.Windows.Media.Brushes]::White
    $trashPath.StrokeThickness = 1.8
    $trashPath.StrokeStartLineCap = 'Round'
    $trashPath.StrokeEndLineCap = 'Round'
    $trashPath.StrokeLineJoin = 'Round'
    $trashPath.Fill = [System.Windows.Media.Brushes]::Transparent
    $trashPath.Data = [System.Windows.Media.Geometry]::Parse('M4,5 L14,5 M6,5 L7,16 L12,16 L13,5 M8,3 L11,3 M8,8 L8,13 M11,8 L11,13')
    $trashView.Child = $trashPath
    $detailDeleteTopButton.Content = $trashView
    [System.Windows.Controls.Grid]::SetColumn($detailDeleteTopButton, 2)
    $toolbar.Children.Add($detailDeleteTopButton) | Out-Null

    $detailCloseButton = New-RoundButton 'X' 30
    $script:detailCloseButton = $detailCloseButton
    $detailCloseButton.ToolTip = 'Close'
    [System.Windows.Controls.Grid]::SetColumn($detailCloseButton, 3)
    $toolbar.Children.Add($detailCloseButton) | Out-Null

    $body = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($body, 1)
    $layout.Children.Add($body) | Out-Null

    $iconRow = New-Object System.Windows.Controls.RowDefinition
    $iconRow.Height = New-Object System.Windows.GridLength(80)
    $titleRow = New-Object System.Windows.Controls.RowDefinition
    $titleRow.Height = New-Object System.Windows.GridLength(38)
    $titleOrnamentRow = New-Object System.Windows.Controls.RowDefinition
    $titleOrnamentRow.Height = New-Object System.Windows.GridLength(22)
    $descriptionRow = New-Object System.Windows.Controls.RowDefinition
    $descriptionRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $actionsRow = New-Object System.Windows.Controls.RowDefinition
    $actionsRow.Height = New-Object System.Windows.GridLength(0)
    $script:detailActionsRow = $actionsRow
    $body.RowDefinitions.Add($iconRow)
    $body.RowDefinitions.Add($titleRow)
    $body.RowDefinitions.Add($titleOrnamentRow)
    $body.RowDefinitions.Add($descriptionRow)
    $body.RowDefinitions.Add($actionsRow)

    $iconHostGrid = New-Object System.Windows.Controls.Grid
    [System.Windows.Controls.Grid]::SetRow($iconHostGrid, 0)
    $body.Children.Add($iconHostGrid) | Out-Null

    $detailIconHost = New-Object System.Windows.Controls.Border
    $script:detailIconHost = $detailIconHost
    $detailIconHost.Width = 72
    $detailIconHost.Height = 72
    $detailIconHost.HorizontalAlignment = 'Center'
    $detailIconHost.VerticalAlignment = 'Bottom'
    $detailIconHost.Margin = '0,0,0,2'
    $detailIconHost.RenderTransform = New-Object System.Windows.Media.TranslateTransform(0, 4)
    [System.Windows.Controls.Panel]::SetZIndex($detailIconHost, 2)
    $iconHostGrid.Children.Add($detailIconHost) | Out-Null

    $changeIconButton = New-RoundButton '' 30
    $script:detailChangeIconButton = $changeIconButton
    Set-DetailEditVisual $changeIconButton $false
    $changeIconButton.ToolTip = 'Edit Icon'
    $changeIconButton.HorizontalAlignment = 'Center'
    $changeIconButton.VerticalAlignment = 'Bottom'
    $changeIconButton.Margin = '82,0,0,8'
    $changeIconButton.Visibility = 'Collapsed'
    [System.Windows.Controls.Panel]::SetZIndex($changeIconButton, 3)
    $iconHostGrid.Children.Add($changeIconButton) | Out-Null

    $iconOrnament = New-DecorativeAsset 'backgrounds/dialogue_fleur_bottom0007.png' 22
    $iconOrnament.VerticalAlignment = 'Bottom'
    [System.Windows.Controls.Panel]::SetZIndex($iconOrnament, 1)
    $iconHostGrid.Children.Add($iconOrnament) | Out-Null

    $detailTitleText = New-Object System.Windows.Controls.TextBlock
    $script:detailTitleText = $detailTitleText
    $detailTitleText.Foreground = [System.Windows.Media.Brushes]::White
    $detailTitleText.FontSize = 18
    $detailTitleText.FontWeight = 'SemiBold'
    $detailTitleText.HorizontalAlignment = 'Center'
    $detailTitleText.VerticalAlignment = 'Center'
    $detailTitleText.TextAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetRow($detailTitleText, 1)
    $body.Children.Add($detailTitleText) | Out-Null

    $titleOrnament = New-DecorativeAsset 'backgrounds/Controller_Dialogue_0001_bot.png' 20
    [System.Windows.Controls.Grid]::SetRow($titleOrnament, 2)
    $body.Children.Add($titleOrnament) | Out-Null

    $detailDescriptionText = New-Object System.Windows.Controls.TextBlock
    $script:detailDescriptionText = $detailDescriptionText
    $detailDescriptionText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F0E9E9E9')
    $detailDescriptionText.FontSize = 14
    $detailDescriptionText.TextWrapping = 'Wrap'
    $detailDescriptionText.TextAlignment = 'Left'
    $detailDescriptionText.VerticalAlignment = 'Top'
    $detailDescriptionText.Margin = '4'

    $descriptionFrame = New-Object System.Windows.Controls.Grid
    $descriptionFrame.Margin = '6,2,6,2'
    [System.Windows.Controls.Grid]::SetRow($descriptionFrame, 3)
    $body.Children.Add($descriptionFrame) | Out-Null
    Add-DescriptionCorners $descriptionFrame

    $detailDescriptionScroll = New-Object System.Windows.Controls.ScrollViewer
    $script:detailDescriptionScroll = $detailDescriptionScroll
    $detailDescriptionScroll.VerticalScrollBarVisibility = 'Hidden'
    $detailDescriptionScroll.HorizontalScrollBarVisibility = 'Disabled'
    $detailDescriptionScroll.Margin = '24,16,24,16'
    $detailDescriptionScroll.Content = $detailDescriptionText
    [System.Windows.Controls.Panel]::SetZIndex($detailDescriptionScroll, 2)
    $descriptionFrame.Children.Add($detailDescriptionScroll) | Out-Null

    $overflowIndicator = New-Object System.Windows.Controls.TextBlock
    $script:detailOverflowIndicator = $overflowIndicator
    $overflowIndicator.Text = '...'
    $overflowIndicator.Foreground = [System.Windows.Media.Brushes]::White
    $overflowIndicator.FontSize = 18
    $overflowIndicator.FontWeight = 'Bold'
    $overflowIndicator.HorizontalAlignment = 'Right'
    $overflowIndicator.VerticalAlignment = 'Bottom'
    $overflowIndicator.Margin = '0,0,22,10'
    $overflowIndicator.IsHitTestVisible = $false
    $overflowIndicator.Visibility = 'Collapsed'
    [System.Windows.Controls.Panel]::SetZIndex($overflowIndicator, 3)
    $descriptionFrame.Children.Add($overflowIndicator) | Out-Null

    $overflowAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $overflowAnimation.From = 0.3
    $overflowAnimation.To = 1.0
    $overflowAnimation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(650))
    $overflowAnimation.AutoReverse = $true
    $overflowAnimation.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $overflowIndicator.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $overflowAnimation)

    $detailDescriptionScroll.Add_ScrollChanged({ Update-DescriptionOverflowIndicator })

    $titleBox = New-Object System.Windows.Controls.TextBox
    $script:detailTitleBox = $titleBox
    $titleBox.Height = 30
    $titleBox.Margin = '8,4,8,4'
    $titleBox.Visibility = 'Collapsed'
    [System.Windows.Controls.Grid]::SetRow($titleBox, 1)
    $body.Children.Add($titleBox) | Out-Null
    Add-TextBoxPlaceholder $body $titleBox 'Task title' '18,4,18,4' 1 'Center'

    $descriptionBox = New-Object System.Windows.Controls.TextBox
    $script:detailDescriptionBox = $descriptionBox
    $descriptionBox.AcceptsReturn = $true
    $descriptionBox.TextWrapping = 'Wrap'
    $descriptionBox.VerticalScrollBarVisibility = 'Auto'
    $descriptionBox.Margin = '24,16,24,16'
    $descriptionBox.Padding = '6'
    $descriptionBox.Background = [System.Windows.Media.Brushes]::White
    $descriptionBox.Foreground = [System.Windows.Media.Brushes]::Black
    $descriptionBox.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFB8B8B8')
    $descriptionBox.BorderThickness = 1
    $descriptionBox.Visibility = 'Collapsed'
    [System.Windows.Controls.Panel]::SetZIndex($descriptionBox, 2)
    $descriptionFrame.Children.Add($descriptionBox) | Out-Null
    Add-TextBoxPlaceholder $descriptionFrame $descriptionBox 'Describe your task...' '32,22,32,22' 0 'Top'

    $editActions = New-Object System.Windows.Controls.StackPanel
    $script:detailEditActions = $editActions
    $editActions.Orientation = 'Vertical'
    $editActions.Width = 154
    $editActions.HorizontalAlignment = 'Center'
    $editActions.VerticalAlignment = 'Center'
    $editActions.Visibility = 'Collapsed'
    [System.Windows.Controls.Grid]::SetRow($editActions, 4)
    $body.Children.Add($editActions) | Out-Null

    $cancelTopOrnament = New-DecorativeAsset 'backgrounds/dialogue_cancel_top.png' 20
    $cancelTopOrnament.Width = 148
    $cancelTopOrnament.HorizontalAlignment = 'Center'
    $cancelTopOrnament.Margin = '0,0,0,-4'
    $editActions.Children.Add($cancelTopOrnament) | Out-Null

    $cancelButton = New-Object System.Windows.Controls.Button
    $script:detailCancelButton = $cancelButton
    $cancelButton.Width = 112
    $cancelButton.Height = 34
    $cancelButton.HorizontalAlignment = 'Center'
    $cancelButton.Margin = '0,3,0,0'
    $cancelButton.Background = [System.Windows.Media.Brushes]::Black
    $cancelButton.Foreground = [System.Windows.Media.Brushes]::White
    $cancelButton.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF777777')
    $cancelButton.BorderThickness = 1
    $cancelButton.FontSize = 12
    $cancelButton.FontWeight = 'SemiBold'
    $cancelButton.Cursor = [System.Windows.Input.Cursors]::Hand

    $cancelButton.Content = 'Cancel'
    $editActions.Children.Add($cancelButton) | Out-Null

    $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) {
        'icon-01'
    }
    else {
        [string]$task.icon
    }

    Set-DetailIconById $script:detailPendingIconId

    $detailTitleText.Text = [string]$task.title
    $detailDescriptionText.Text = [string]$task.description

    $detailEditButton.Add_Click({
        if ($script:detailEditing) {
            Save-DetailItem
        }
        else {
            Set-DetailEditMode
        }
    })

    $cancelButton.Add_Click({
        $task = Get-TaskById ([string]$script:detailCurrentTaskId)

        if ($null -ne $task) {
            $script:detailPendingIconId = if ([string]::IsNullOrWhiteSpace([string]$task.icon)) { 'icon-01' } else { [string]$task.icon }
            Set-DetailIconById $script:detailPendingIconId
        }

        Set-DetailReadMode
    })

    $changeIconButton.Add_Click({
        $selectedIconId = Show-TaskIconChooser `
            -Owner $script:activeDetailWindow `
            -SelectedIcon $script:detailPendingIconId

        if ([string]::IsNullOrWhiteSpace([string]$selectedIconId)) { return }

        $entry = Get-IconEntry ([string]$selectedIconId)
        if ($null -eq $entry) { return }

        $script:detailPendingIconId = [string]$selectedIconId
        Set-DetailIconById $script:detailPendingIconId
    })

    $detailDeleteTopButton.Add_Click({
        Delete-DetailItem
    })

    $detailCloseButton.Add_Click({
        Close-DetailWindow
    })

    $detailWindow.Add_Closed({
        $script:activeDetailWindow = $null
        $script:detailCurrentTaskId = $null
        $script:detailEditing = $false
    })

    $detailWindow.Show()
    Center-WindowOnPrimaryScreen $detailWindow
    $detailWindow.Activate() | Out-Null
    $detailWindow.Dispatcher.BeginInvoke(
        [System.Action]{ Update-DescriptionOverflowIndicator },
        [System.Windows.Threading.DispatcherPriority]::Loaded
    ) | Out-Null
}

