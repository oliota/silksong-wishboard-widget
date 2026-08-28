function Hide-Panel {
    if ($script:detailsPanel) {  }
    Close-AddTaskPanel
    if ($script:backgroundPanel) { $script:backgroundPanel.Visibility = 'Collapsed' }
    if ($script:gridPanel) { $script:gridPanel.Visibility = 'Collapsed' }
}

function New-DecorativeAsset([string]$relativePath, [double]$height) {
    $image = New-Object System.Windows.Controls.Image
    $image.Height = $height
    $image.Stretch = 'Uniform'
    $image.HorizontalAlignment = 'Stretch'
    $image.VerticalAlignment = 'Center'

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

function New-DescriptionCorner(
    [string]$relativePath,
    [bool]$flipX,
    [string]$horizontalAlignment,
    [string]$verticalAlignment,
    [double]$width,
    [double]$height
) {
    $image = New-DecorativeAsset $relativePath 1
    $image.Width = $width
    $image.Height = $height
    $image.Stretch = 'Fill'
    $image.HorizontalAlignment = $horizontalAlignment
    $image.VerticalAlignment = $verticalAlignment
    $image.IsHitTestVisible = $false
    $image.Opacity = 0.82
    if ($flipX) {
        $image.RenderTransformOrigin = '0.5,0.5'
        $image.RenderTransform = New-Object System.Windows.Media.ScaleTransform(-1, 1)
    }
    $image
}

function Add-DescriptionCorners($container) {
    $lineBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B8FFFFFF')
    foreach ($line in @(
        [pscustomobject]@{ width = [double]::NaN; height = 1.0; horizontal = 'Stretch'; vertical = 'Top'; margin = '50,8,50,0' }
        [pscustomobject]@{ width = [double]::NaN; height = 1.0; horizontal = 'Stretch'; vertical = 'Bottom'; margin = '50,0,50,8' }
        [pscustomobject]@{ width = 1.0; height = [double]::NaN; horizontal = 'Left'; vertical = 'Stretch'; margin = '8,46,0,38' }
        [pscustomobject]@{ width = 1.0; height = [double]::NaN; horizontal = 'Right'; vertical = 'Stretch'; margin = '0,46,8,38' }
    )) {
        $border = New-Object System.Windows.Controls.Border
        if (-not [double]::IsNaN($line.width)) { $border.Width = $line.width }
        if (-not [double]::IsNaN($line.height)) { $border.Height = $line.height }
        $border.HorizontalAlignment = $line.horizontal
        $border.VerticalAlignment = $line.vertical
        $border.Margin = $line.margin
        $border.Background = $lineBrush
        $border.IsHitTestVisible = $false
        $container.Children.Add($border) | Out-Null
    }

    $corners = @(
        New-DescriptionCorner 'backgrounds/dialogue_corner_top_left.png' $false 'Left' 'Top' 58 72
        New-DescriptionCorner 'backgrounds/dialogue_corner_top_left.png' $true 'Right' 'Top' 58 72
        New-DescriptionCorner 'backgrounds/dialogue_corner_bottom_right.png' $true 'Left' 'Bottom' 68 56
        New-DescriptionCorner 'backgrounds/dialogue_corner_bottom_right.png' $false 'Right' 'Bottom' 68 56
    )
    foreach ($corner in $corners) {
        $container.Children.Add($corner) | Out-Null
    }
}

function Add-TextBoxPlaceholder($container, $textBox, [string]$text, [string]$margin, [int]$row, [string]$verticalAlignment) {
    $placeholder = New-Object System.Windows.Controls.TextBlock
    $placeholder.Text = $text
    $placeholder.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF777777')
    $placeholder.Margin = $margin
    $placeholder.VerticalAlignment = $verticalAlignment
    $placeholder.IsHitTestVisible = $false
    [System.Windows.Controls.Grid]::SetRow($placeholder, $row)
    [System.Windows.Controls.Panel]::SetZIndex($placeholder, 4)
    $container.Children.Add($placeholder) | Out-Null
    $update = {
        $placeholder.Visibility = if ($textBox.IsVisible -and [string]::IsNullOrEmpty($textBox.Text)) { 'Visible' } else { 'Collapsed' }
    }.GetNewClosure()
    $textBox.Add_TextChanged($update)
    $textBox.Add_IsVisibleChanged($update)
    & $update
}

function Add-OrnamentShadow($container, [int]$row) {
    $shadow = New-Object System.Windows.Controls.Border
    $shadow.Margin = '0'
    $shadow.IsHitTestVisible = $false

    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = [System.Windows.Point]::new(0.0, 0.5)
    $brush.EndPoint = [System.Windows.Point]::new(1.0, 0.5)
    $stops = @(
        [pscustomobject]@{ alpha = 0; offset = 0.0 }
        [pscustomobject]@{ alpha = 45; offset = 0.08 }
        [pscustomobject]@{ alpha = 155; offset = 0.18 }
        [pscustomobject]@{ alpha = 225; offset = 0.3 }
        [pscustomobject]@{ alpha = 225; offset = 0.7 }
        [pscustomobject]@{ alpha = 155; offset = 0.82 }
        [pscustomobject]@{ alpha = 45; offset = 0.92 }
        [pscustomobject]@{ alpha = 0; offset = 1.0 }
    )
    foreach ($stop in $stops) {
        $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new(
            [System.Windows.Media.Color]::FromArgb([byte]$stop.alpha, 0, 0, 0),
            [double]$stop.offset
        ))
    }
    $shadow.Background = $brush

    [System.Windows.Controls.Grid]::SetRow($shadow, $row)
    [System.Windows.Controls.Panel]::SetZIndex($shadow, -1)
    $container.Children.Add($shadow) | Out-Null
}


function New-DetailOrnament([bool]$bottom = $false) {
    $image = if ($bottom) {
        New-DecorativeAsset 'backgrounds/bottom_fleur0008.png' 30
    }
    else {
        New-DecorativeAsset 'backgrounds/Dialogue_fleur_top_NPC0005.png' 46
    }

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.BlurRadius = 12
    $shadow.ShadowDepth = 0
    $shadow.Opacity = 0.95
    $image.Effect = $shadow
    $image
}

function New-TaskPreviewControl($task) {
    $titleLength = ([string]$task.title).Length
    $previewWidth = [Math]::Max(190.0, [Math]::Min(420.0, 120.0 + ($titleLength * 7.2)))

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Width = $previewWidth
    $outer.Height = 172
    foreach ($height in @(40, 102, 30)) {
        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = New-Object System.Windows.GridLength($height)
        $outer.RowDefinitions.Add($row)
    }

    Add-OrnamentShadow $outer 1

    $top = New-DetailOrnament
    [System.Windows.Controls.Grid]::SetRow($top, 0)
    $outer.Children.Add($top) | Out-Null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F4070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#66FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    $card.Padding = '14,10'
    $card.Margin = '14,0'
    [System.Windows.Controls.Grid]::SetRow($card, 1)
    $outer.Children.Add($card) | Out-Null

    $content = New-Object System.Windows.Controls.Grid
    $iconRow = New-Object System.Windows.Controls.RowDefinition
    $iconRow.Height = New-Object System.Windows.GridLength(58)
    $titleRow = New-Object System.Windows.Controls.RowDefinition
    $titleRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $content.RowDefinitions.Add($iconRow)
    $content.RowDefinitions.Add($titleRow)
    $card.Child = $content

    $iconEntry = Get-IconEntry ([string]$task.icon)
    if ($null -ne $iconEntry) {
        $icon = New-ImageControl ([string]$iconEntry.file) 54
        [System.Windows.Controls.Grid]::SetRow($icon, 0)
        $content.Children.Add($icon) | Out-Null
    }

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = [string]$task.title
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 16
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    $title.TextTrimming = 'CharacterEllipsis'
    $title.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetRow($title, 1)
    $content.Children.Add($title) | Out-Null

    $bottom = New-DetailOrnament $true
    [System.Windows.Controls.Grid]::SetRow($bottom, 2)
    $outer.Children.Add($bottom) | Out-Null

    $outer
}

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
