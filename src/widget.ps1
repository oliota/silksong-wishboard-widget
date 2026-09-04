$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $base

. (Join-Path $base 'modules/ApplicationLifecycle.ps1')
. (Join-Path $base 'modules/Core/TimerRegistry.ps1')

Initialize-WidgetLog
Initialize-TimerRegistry

if (-not (Enter-ApplicationInstance)) {
    exit 0
}

try {
Write-WidgetLog 'START' 'Loading WPF assemblies and application modules.'
Get-ChildItem -LiteralPath $projectRoot -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = Join-Path $base 'config.json'
$areaPath = Join-Path $base 'area.json'
$defaultAreaPath = Join-Path $base 'default-area.json'
$tasksPath = Join-Path $base 'tasks.json'
$positionCachePath = Join-Path $base 'position-cache.json'
$backgroundsPath = Join-Path $base 'backgrounds.json'
$backgroundsDir = Join-Path $base 'backgrounds'
$profilesPath = Join-Path $base 'profiles.json'
$iconsPath = Join-Path $base 'icons.json'
$iconColorsPath = Join-Path $base 'icons/colors.json'

. (Join-Path $base 'modules/Tasks/TaskRepository.ps1')
. (Join-Path $base 'modules/Tasks/TaskBadgeFactory.ps1')
. (Join-Path $base 'modules/Tasks/IconSelection.ps1')
. (Join-Path $base 'modules/Tasks/TaskCreation.ps1')
. (Join-Path $base 'modules/Board/ProfileService.ps1')
. (Join-Path $base 'modules/Board/CustomProfileService.ps1')
. (Join-Path $base 'modules/Application/StartupService.ps1')
. (Join-Path $base 'modules/Board/AreaState.ps1')
. (Join-Path $base 'modules/Board/PlacementGeometry.ps1')
. (Join-Path $base 'modules/Board/PositionCache.ps1')
. (Join-Path $base 'modules/Board/AreaEditor.ps1')
. (Join-Path $base 'modules/Windows/DecorativeControls.ps1')
. (Join-Path $base 'modules/Windows/TaskDetailEditor.ps1')
. (Join-Path $base 'modules/Windows/TaskDetailWindow.ps1')
. (Join-Path $base 'modules/Windows/SettingsControls.ps1')
. (Join-Path $base 'modules/Windows/SettingsWindow.ps1')
. (Join-Path $base 'modules/Tasks/AnimationCommon.ps1')
. (Join-Path $base 'modules/Tasks/PlacementAnimation.ps1')
. (Join-Path $base 'modules/Tasks/DeletionAnimation.ps1')
. (Join-Path $base 'modules/Board/BackgroundRendering.ps1')
. (Join-Path $base 'modules/Board/AreaRendering.ps1')
. (Join-Path $base 'modules/Board/TaskRendering.ps1')
. (Join-Path $base 'modules/Windows/DisplayService.ps1')
. (Join-Path $base 'modules/Application/ConfigurationService.ps1')
. (Join-Path $base 'modules/Calendar/AuthorizationService.ps1')
. (Join-Path $base 'modules/Calendar/CalendarSettings.ps1')
. (Join-Path $base 'modules/Calendar/CalendarSyncService.ps1')
. (Join-Path $base 'modules/Calendar/SummonsState.ps1')
. (Join-Path $base 'modules/Calendar/SummonsQueue.ps1')
. (Join-Path $base 'modules/Calendar/PinDepartureAnimation.ps1')
. (Join-Path $base 'modules/Calendar/CrawDepartureAnimation.ps1')
. (Join-Path $base 'modules/Calendar/CrawArrivalAnimation.ps1')
. (Join-Path $base 'modules/Windows/Add-BackgroundOptionRow.ps1')
. (Join-Path $base 'modules/Windows/Render-BackgroundChoices.ps1')
. (Join-Path $base 'modules/Windows/Commit-BackgroundEdits.ps1')
. (Join-Path $base 'modules/Windows/Show-Widget.ps1')
. (Join-Path $base 'modules/Windows/Exit-Widget.ps1')
. (Join-Path $base 'modules/Windows/Hide-Widget.ps1')
. (Join-Path $base 'modules/Windows/Get-ButtonAncestor.ps1')
. (Join-Path $base 'modules/Board/Invoke-EditModeSave.ps1')

$script:editMode = $false
$script:draggingEditorNode = $null
$script:draggingEditorIndex = -1
$script:editSnapshot = $null
$script:editWorkingArea = $null
$script:editUndoStack = New-Object System.Collections.Stack
$script:editBackgroundFile = $null
$script:editSnapshotBackgroundFile = $null
$script:editBackgroundScale = 1.0
$script:editBackgroundOffsetX = 0.0
$script:editBackgroundOffsetY = 0.0
$script:editSnapshotBackgroundScale = 1.0
$script:editSnapshotBackgroundOffsetX = 0.0
$script:editSnapshotBackgroundOffsetY = 0.0
$script:editSnapshotAddX = $null
$script:editSnapshotAddY = $null
$script:editSnapshotAddSize = $null
$script:editAddX = $null
$script:editAddY = $null
$script:editGridColumns = 3
$script:editSnapshotGridColumns = 3
$script:addSelectedIcon = 'icon-01'
$script:detailSelectedIcon = 'icon-01'
$script:selectedTaskId = $null
$script:activeProfile = $null


$script:pendingDeletedBackgroundIds = New-Object System.Collections.Generic.HashSet[string]


$script:config = Read-JsonFile $configPath
$script:area = Read-JsonFile $areaPath
$script:tasks = @(Read-Tasks)
$script:configStamp = (Get-Item $configPath).LastWriteTimeUtc
$script:areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
$script:tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc
Write-WidgetLog 'LOAD' ("Loaded configuration, area and {0} tasks." -f $script:tasks.Count)
Initialize-LegacyTaskBadges
$script:positionInitialized = $false
$script:userHidden = $false
$script:exiting = $false
$script:widgetDragActive = $false
$script:widgetDragStartMouseX = 0.0
$script:widgetDragStartMouseY = 0.0
$script:widgetDragStartLeft = 0.0
$script:widgetDragStartTop = 0.0
$script:widgetNormalOpacity = 1.0
$script:suppressPositionSave = $false
$script:displaySignature = Get-DisplaySignature


$window = New-Object System.Windows.Window
$window.WindowStyle = 'None'
$window.ResizeMode = 'NoResize'
$window.AllowsTransparency = $true
$window.Background = [System.Windows.Media.Brushes]::Transparent
$window.ShowInTaskbar = $false
$window.Topmost = $true
$window.SizeToContent = 'Manual'
$script:window = $window

$viewport = New-Object System.Windows.Controls.Viewbox
$viewport.Stretch = [System.Windows.Media.Stretch]::Uniform
$viewport.StretchDirection = [System.Windows.Controls.StretchDirection]::Both
$script:viewport = $viewport

$root = New-Object System.Windows.Controls.Canvas
$root.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(1, 0, 0, 0))
$script:root = $root
$viewport.Child = $root
$window.Content = $viewport

$background = New-Object System.Windows.Controls.Image
$background.IsHitTestVisible = $false
$script:background = $background
$root.Children.Add($background) | Out-Null

$profileAccessory = New-Object System.Windows.Controls.Image
$profileAccessory.Stretch = [System.Windows.Media.Stretch]::Uniform
$profileAccessory.IsHitTestVisible = $false
$script:profileAccessory = $profileAccessory
$root.Children.Add($profileAccessory) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($profileAccessory, 899)

$taskArea = New-Object System.Windows.Shapes.Polygon
$taskArea.Fill = [System.Windows.Media.Brushes]::Transparent
$taskArea.Stroke = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(130, 255, 255, 255))
$taskArea.IsHitTestVisible = $false
$script:taskArea = $taskArea
$root.Children.Add($taskArea) | Out-Null

$taskLayer = New-Object System.Windows.Controls.Canvas
$taskLayer.Width = 1000
$taskLayer.Height = 1000
$script:taskLayer = $taskLayer
$root.Children.Add($taskLayer) | Out-Null

$hoverPreviewHost = New-Object System.Windows.Controls.ContentControl
$hoverPreviewHost.Width = [double]$script:config.widget.designWidth
$hoverPreviewHost.Height = 150
$hoverPreviewHost.HorizontalContentAlignment = 'Center'
$hoverPreviewHost.VerticalContentAlignment = 'Top'
$hoverPreviewHost.IsHitTestVisible = $false
$hoverPreviewHost.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($hoverPreviewHost, 0)
[System.Windows.Controls.Canvas]::SetTop($hoverPreviewHost, 8)
[System.Windows.Controls.Panel]::SetZIndex($hoverPreviewHost, 1900)
$script:hoverPreviewHost = $hoverPreviewHost
$root.Children.Add($hoverPreviewHost) | Out-Null

$editorLayer = New-Object System.Windows.Controls.Canvas
$editorLayer.Width = 1000
$editorLayer.Height = 1000
$editorLayer.Background = [System.Windows.Media.Brushes]::Transparent
$editorLayer.IsHitTestVisible = $false
[System.Windows.Controls.Panel]::SetZIndex($editorLayer, 100)
$script:editorLayer = $editorLayer
$root.Children.Add($editorLayer) | Out-Null



$closeButton = New-RoundButton 'X' 30
$closeButton.FontSize = 13
$closeButton.ToolTip = 'Close'
$script:closeButton = $closeButton
$root.Children.Add($closeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($closeButton, 2000)

$minimizeButton = New-RoundButton '_' 30
$minimizeButton.FontSize = 16
$minimizeButton.ToolTip = 'Minimize'
$script:minimizeButton = $minimizeButton
$root.Children.Add($minimizeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($minimizeButton, 2000)

$resizeButton = New-Object System.Windows.Controls.Primitives.Thumb
$resizeButton.Width = 30
$resizeButton.Height = 30
$resizeButton.Cursor = [System.Windows.Input.Cursors]::SizeNESW
$resizeButton.ToolTip = 'Resize'
$resizeButton.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0202024')
$resizeButton.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B0FFFFFF')
$resizeButton.BorderThickness = 1
$resizeButton.Template = [System.Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Thumb">
    <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="15">
        <Grid Width="18" Height="18" HorizontalAlignment="Center" VerticalAlignment="Center">
            <Path Stroke="White" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Data="M 4,14 L 14,4 M 9,4 L 14,4 L 14,9 M 4,9 L 4,14 L 9,14"/>
        </Grid>
    </Border>
</ControlTemplate>
'@)
$script:resizeButton = $resizeButton
$root.Children.Add($resizeButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($resizeButton, 2000)

$opacitySlider = New-Object System.Windows.Controls.Slider
$opacitySlider.Minimum = 20
$opacitySlider.Maximum = 100
$opacitySlider.Width = 110
$opacitySlider.Height = 30
$opacitySlider.TickFrequency = 10
$opacitySlider.IsSnapToTickEnabled = $false
$opacitySlider.ToolTip = 'Opacity'
$script:opacitySlider = $opacitySlider
$root.Children.Add($opacitySlider) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($opacitySlider, 2000)

$opacityLabel = New-Object System.Windows.Controls.TextBlock
$opacityLabel.Foreground = [System.Windows.Media.Brushes]::White
$opacityLabel.FontSize = 10
$opacityLabel.TextAlignment = 'Center'
$opacityLabel.Width = 34
$opacityLabel.Height = 18
$script:opacityLabel = $opacityLabel
$root.Children.Add($opacityLabel) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($opacityLabel, 2000)

$addButton = New-RoundButton '+' 44
$addButton.FontSize = 22
$addButton.ToolTip = 'Add Task'
$addButton.Background = [System.Windows.Media.Brushes]::Transparent
$addButton.BorderBrush = [System.Windows.Media.Brushes]::Transparent
$script:addButton = $addButton
$root.Children.Add($addButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($addButton, 2000)

$addSizeSlider = New-Object System.Windows.Controls.Slider
$addSizeSlider.Minimum = 28
$addSizeSlider.Maximum = 84
$addSizeSlider.Width = 100
$addSizeSlider.Height = 30
$addSizeSlider.Visibility = 'Collapsed'
$addSizeSlider.ToolTip = 'Add Button Size'
$script:addSizeSlider = $addSizeSlider
$root.Children.Add($addSizeSlider) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($addSizeSlider, 2000)

$editButton = New-RoundButton '' 30
$editButton.ToolTip = 'Edit'
$script:editButton = $editButton
$root.Children.Add($editButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($editButton, 2000)
Set-EditButtonVisual $false

$undoButton = New-RoundButton 'UNDO' 44
$undoButton.FontSize = 8
$undoButton.Visibility = 'Collapsed'
$undoButton.ToolTip = 'Undo'
$script:undoButton = $undoButton
$root.Children.Add($undoButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($undoButton, 2000)

$clearButton = New-RoundButton 'CLEAR' 44
$clearButton.FontSize = 8
$clearButton.Visibility = 'Collapsed'
$clearButton.ToolTip = 'Reset'
$script:clearButton = $clearButton
$root.Children.Add($clearButton) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($clearButton, 2000)

$borderToggle = New-RoundButton 'LINE' 44
$borderToggle.FontSize = 8
$borderToggle.Visibility = 'Collapsed'
$borderToggle.ToolTip = 'Toggle Border'
$script:borderToggle = $borderToggle

$startupToggle = New-RoundButton 'STARTUP OFF' 64
$startupToggle.FontSize = 7
$startupToggle.Visibility = 'Collapsed'
$startupToggle.ToolTip = 'Enable Start with Windows'
$script:startupToggle = $startupToggle

$backgroundPanel = New-Object System.Windows.Controls.Border
$backgroundPanel.Width = 300
$backgroundPanel.MaxHeight = 390
$backgroundPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$backgroundPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$backgroundPanel.BorderThickness = 1
$backgroundPanel.CornerRadius = 10
$backgroundPanel.Padding = 12
$backgroundPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($backgroundPanel, 108)
[System.Windows.Controls.Canvas]::SetTop($backgroundPanel, 92)
[System.Windows.Controls.Panel]::SetZIndex($backgroundPanel, 3500)
$script:backgroundPanel = $backgroundPanel

$backgroundPanelStack = New-Object System.Windows.Controls.StackPanel
$backgroundHeader = New-Object System.Windows.Controls.TextBlock
$backgroundHeader.Text = 'Choose Background'
$backgroundHeader.Foreground = [System.Windows.Media.Brushes]::White
$backgroundHeader.FontSize = 17
$backgroundHeader.FontWeight = 'Bold'
$backgroundHeader.Margin = '0,0,0,10'
$headerGrid = New-Object System.Windows.Controls.Grid
$headerGrid.Height = 34
$headerCol1 = New-Object System.Windows.Controls.ColumnDefinition
$headerCol1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$headerCol2 = New-Object System.Windows.Controls.ColumnDefinition
$headerCol2.Width = New-Object System.Windows.GridLength(34)
$headerGrid.ColumnDefinitions.Add($headerCol1)
$headerGrid.ColumnDefinitions.Add($headerCol2)

[System.Windows.Controls.Grid]::SetColumn($backgroundHeader, 0)
$headerGrid.Children.Add($backgroundHeader) | Out-Null

$backgroundClose = New-Object System.Windows.Controls.Button
$backgroundClose.Content = 'X'
$backgroundClose.Width = 30
$backgroundClose.Height = 28
$backgroundClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($backgroundClose, 1)
$headerGrid.Children.Add($backgroundClose) | Out-Null
$backgroundPanelStack.Children.Add($headerGrid) | Out-Null

$backgroundTransformPanel = New-Object System.Windows.Controls.StackPanel
$backgroundTransformPanel.Margin = '0,0,0,10'

$scaleLabel = New-Object System.Windows.Controls.TextBlock
$scaleLabel.Text = 'Scale'
$scaleLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($scaleLabel) | Out-Null

$backgroundScaleSlider = New-Object System.Windows.Controls.Slider
$backgroundScaleSlider.Minimum = 20
$backgroundScaleSlider.Maximum = 300
$backgroundScaleSlider.Width = 250
$backgroundScaleSlider.Margin = '0,2,0,6'
$script:backgroundScaleSlider = $backgroundScaleSlider
$backgroundTransformPanel.Children.Add($backgroundScaleSlider) | Out-Null

$xLabel = New-Object System.Windows.Controls.TextBlock
$xLabel.Text = 'Horizontal position'
$xLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($xLabel) | Out-Null

$backgroundXSlider = New-Object System.Windows.Controls.Slider
$backgroundXSlider.Minimum = -260
$backgroundXSlider.Maximum = 260
$backgroundXSlider.Width = 250
$backgroundXSlider.Margin = '0,2,0,6'
$script:backgroundXSlider = $backgroundXSlider
$backgroundTransformPanel.Children.Add($backgroundXSlider) | Out-Null

$yLabel = New-Object System.Windows.Controls.TextBlock
$yLabel.Text = 'Vertical position'
$yLabel.Foreground = [System.Windows.Media.Brushes]::White
$backgroundTransformPanel.Children.Add($yLabel) | Out-Null

$backgroundYSlider = New-Object System.Windows.Controls.Slider
$backgroundYSlider.Minimum = -280
$backgroundYSlider.Maximum = 280
$backgroundYSlider.Width = 250
$backgroundYSlider.Margin = '0,2,0,8'
$script:backgroundYSlider = $backgroundYSlider
$backgroundTransformPanel.Children.Add($backgroundYSlider) | Out-Null

$backgroundScroll = New-Object System.Windows.Controls.ScrollViewer
$backgroundScroll.VerticalScrollBarVisibility = 'Auto'
$backgroundScroll.MaxHeight = 310
$backgroundList = New-Object System.Windows.Controls.StackPanel
$script:backgroundList = $backgroundList
$backgroundScroll.Content = $backgroundList
$backgroundPanelStack.Children.Add($backgroundScroll) | Out-Null
$backgroundPanel.Child = $backgroundPanelStack
$root.Children.Add($backgroundPanel) | Out-Null


$gridPanel = New-Object System.Windows.Controls.Border
$gridPanel.Width = 360
$gridPanel.MaxHeight = 450
$gridPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$gridPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$gridPanel.BorderThickness = 1
$gridPanel.CornerRadius = 10
$gridPanel.Padding = 12
$gridPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($gridPanel, 80)
[System.Windows.Controls.Canvas]::SetTop($gridPanel, 96)
[System.Windows.Controls.Panel]::SetZIndex($gridPanel, 3600)
$script:gridPanel = $gridPanel

$gridStack = New-Object System.Windows.Controls.StackPanel

$gridHeaderRow = New-Object System.Windows.Controls.Grid
$gridHeaderCol1 = New-Object System.Windows.Controls.ColumnDefinition
$gridHeaderCol1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$gridHeaderCol2 = New-Object System.Windows.Controls.ColumnDefinition
$gridHeaderCol2.Width = New-Object System.Windows.GridLength(34)
$gridHeaderRow.ColumnDefinitions.Add($gridHeaderCol1)
$gridHeaderRow.ColumnDefinitions.Add($gridHeaderCol2)

$gridHeader = New-Object System.Windows.Controls.TextBlock
$gridHeader.Text = 'Icon Grid'
$gridHeader.Foreground = [System.Windows.Media.Brushes]::White
$gridHeader.FontSize = 17
$gridHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($gridHeader, 0)
$gridHeaderRow.Children.Add($gridHeader) | Out-Null

$gridClose = New-Object System.Windows.Controls.Button
$gridClose.Content = 'X'
$gridClose.Width = 30
$gridClose.Height = 28
$gridClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($gridClose, 1)
$gridHeaderRow.Children.Add($gridClose) | Out-Null
$gridStack.Children.Add($gridHeaderRow) | Out-Null

$columnsRow = New-Object System.Windows.Controls.StackPanel
$columnsRow.Orientation = 'Horizontal'
$columnsRow.Margin = '0,10,0,10'

$columnsLabel = New-Object System.Windows.Controls.TextBlock
$columnsLabel.Text = 'Items per row'
$columnsLabel.Foreground = [System.Windows.Media.Brushes]::White
$columnsLabel.VerticalAlignment = 'Center'
$columnsLabel.Margin = '0,0,10,0'
$columnsRow.Children.Add($columnsLabel) | Out-Null

$columnsBox = New-Object System.Windows.Controls.TextBox
$columnsBox.Width = 52
$columnsBox.Height = 28
$columnsBox.VerticalContentAlignment = 'Center'
$script:columnsBox = $columnsBox
$columnsRow.Children.Add($columnsBox) | Out-Null
$gridStack.Children.Add($columnsRow) | Out-Null

$gridPreviewScroll = New-Object System.Windows.Controls.ScrollViewer
$gridPreviewScroll.VerticalScrollBarVisibility = 'Auto'
$gridPreviewScroll.HorizontalScrollBarVisibility = 'Disabled'
$gridPreviewScroll.MaxHeight = 320

$gridPreview = New-Object System.Windows.Controls.WrapPanel
$script:gridPreview = $gridPreview
$gridPreviewScroll.Content = $gridPreview
$gridStack.Children.Add($gridPreviewScroll) | Out-Null

$gridPanel.Child = $gridStack
$detailsPanel = New-Object System.Windows.Controls.Border
$detailsPanel.Width = [double]$script:config.detail.width
$detailsPanel.Height = [double]$script:config.detail.height
$detailsPanel.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 24, 24, 29))
$detailsPanel.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(190, 230, 230, 230))
$detailsPanel.BorderThickness = 1
$detailsPanel.CornerRadius = 10
$detailsPanel.Padding = 14
$detailsPanel.Visibility = 'Collapsed'
[System.Windows.Controls.Canvas]::SetLeft($detailsPanel, ([double]$script:config.widget.designWidth - [double]$script:config.detail.width) / 2)
[System.Windows.Controls.Canvas]::SetTop($detailsPanel, ([double]$script:config.widget.designHeight - [double]$script:config.detail.height) / 2)
$script:detailsPanel = $detailsPanel

$detailScroll = New-Object System.Windows.Controls.ScrollViewer
$detailScroll.VerticalScrollBarVisibility = 'Auto'
$detailStack = New-Object System.Windows.Controls.StackPanel

$detailHeaderGrid = New-Object System.Windows.Controls.Grid
$detailHeaderGrid.Margin = '0,0,0,10'
$detailHeaderCol = New-Object System.Windows.Controls.ColumnDefinition
$detailHeaderCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$detailHeaderCloseCol = New-Object System.Windows.Controls.ColumnDefinition
$detailHeaderCloseCol.Width = New-Object System.Windows.GridLength(34)
$detailHeaderGrid.ColumnDefinitions.Add($detailHeaderCol)
$detailHeaderGrid.ColumnDefinitions.Add($detailHeaderCloseCol)

$detailHeader = New-Object System.Windows.Controls.TextBlock
$detailHeader.Text = 'Edit Task'
$detailHeader.Foreground = [System.Windows.Media.Brushes]::White
$detailHeader.FontSize = 18
$detailHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($detailHeader, 0)
$detailHeaderGrid.Children.Add($detailHeader) | Out-Null

$detailClose = New-Object System.Windows.Controls.Button
$detailClose.Content = 'X'
$detailClose.Width = 30
$detailClose.Height = 28
$detailClose.ToolTip = 'Close'
[System.Windows.Controls.Grid]::SetColumn($detailClose, 1)
$detailHeaderGrid.Children.Add($detailClose) | Out-Null
$detailStack.Children.Add($detailHeaderGrid) | Out-Null

$detailIconLabel = New-Object System.Windows.Controls.TextBlock
$detailIconLabel.Text = 'Icon'
$detailIconLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailIconLabel.Margin = '0,0,0,4'
$detailStack.Children.Add($detailIconLabel) | Out-Null

$detailIconRow = New-Object System.Windows.Controls.StackPanel
$detailIconRow.Orientation = 'Horizontal'
$detailIconRow.Margin = '0,0,0,8'
$detailCurrentIcon = New-Object System.Windows.Controls.Border
$detailCurrentIcon.Width = 72
$detailCurrentIcon.Height = 72
$detailCurrentIcon.BorderBrush = [System.Windows.Media.Brushes]::Gray
$detailCurrentIcon.BorderThickness = 1
$detailCurrentIcon.Padding = 5
$script:detailCurrentIcon = $detailCurrentIcon
$detailIconRow.Children.Add($detailCurrentIcon) | Out-Null
$detailChangeIcon = New-Object System.Windows.Controls.Button
$detailChangeIcon.Content = 'Change'
$detailChangeIcon.Width = 90
$detailChangeIcon.Height = 32
$detailChangeIcon.Margin = '12,20,0,0'
$detailChangeIcon.ToolTip = 'Change Icon'
$detailIconRow.Children.Add($detailChangeIcon) | Out-Null
$detailStack.Children.Add($detailIconRow) | Out-Null

$detailChooser = New-Object System.Windows.Controls.Border
$detailChooser.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(252, 18, 18, 22))
$detailChooser.BorderBrush = [System.Windows.Media.Brushes]::Gray
$detailChooser.BorderThickness = 1
$detailChooser.Padding = 10
$detailChooser.Visibility = 'Collapsed'
$detailChooserStack = New-Object System.Windows.Controls.StackPanel
$detailChooserHeader = New-Object System.Windows.Controls.DockPanel
$detailChooserTitle = New-Object System.Windows.Controls.TextBlock
$detailChooserTitle.Text = 'Choose Icon'
$detailChooserTitle.Foreground = [System.Windows.Media.Brushes]::White
$detailChooserTitle.FontWeight = 'Bold'
$detailChooserClose = New-Object System.Windows.Controls.Button
$detailChooserClose.Content = 'X'
$detailChooserClose.Width = 28
$detailChooserClose.Height = 26
$detailChooserClose.ToolTip = 'Close'
[System.Windows.Controls.DockPanel]::SetDock($detailChooserClose,'Right')
$detailChooserHeader.Children.Add($detailChooserClose) | Out-Null
$detailChooserHeader.Children.Add($detailChooserTitle) | Out-Null
$detailChooserStack.Children.Add($detailChooserHeader) | Out-Null
$detailIconScroll = New-Object System.Windows.Controls.ScrollViewer
$detailIconScroll.MaxHeight = 190
$detailIconScroll.VerticalScrollBarVisibility = 'Auto'
$detailIconGrid = New-Object System.Windows.Controls.WrapPanel
$script:detailIconGrid = $detailIconGrid
$detailIconScroll.Content = $detailIconGrid
$detailChooserStack.Children.Add($detailIconScroll) | Out-Null
$detailChooser.Child = $detailChooserStack
$detailStack.Children.Add($detailChooser) | Out-Null
$script:detailChooser = $detailChooser

$detailTitleLabel = New-Object System.Windows.Controls.TextBlock
$detailTitleLabel.Text = 'Title'
$detailTitleLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailTitleLabel.Margin = '0,10,0,4'
$detailStack.Children.Add($detailTitleLabel) | Out-Null

$detailTitleBox = New-Object System.Windows.Controls.TextBox
$detailTitleBox.Height = 30
$script:detailTitleBox = $detailTitleBox
$detailStack.Children.Add($detailTitleBox) | Out-Null

$detailDescriptionLabel = New-Object System.Windows.Controls.TextBlock
$detailDescriptionLabel.Text = 'Description'
$detailDescriptionLabel.Foreground = [System.Windows.Media.Brushes]::White
$detailDescriptionLabel.Margin = '0,10,0,4'
$detailStack.Children.Add($detailDescriptionLabel) | Out-Null

$detailDescriptionBox = New-Object System.Windows.Controls.TextBox
$detailDescriptionBox.Height = 82
$detailDescriptionBox.AcceptsReturn = $true
$detailDescriptionBox.TextWrapping = 'Wrap'
$script:detailDescriptionBox = $detailDescriptionBox
$detailStack.Children.Add($detailDescriptionBox) | Out-Null

$detailActions = New-Object System.Windows.Controls.StackPanel
$detailActions.Orientation = 'Horizontal'
$detailActions.HorizontalAlignment = 'Right'
$detailActions.Margin = '0,14,0,0'

$detailDelete = New-Object System.Windows.Controls.Button
$detailDelete.Content = 'Delete'
$detailDelete.Width = 78
$detailDelete.Height = 30
$detailDelete.Margin = '0,0,8,0'
$detailDelete.ToolTip = 'Delete Task'

$detailSave = New-Object System.Windows.Controls.Button
$detailSave.Content = 'Save'
$detailSave.Width = 78
$detailSave.Height = 30
$detailSave.ToolTip = 'Save Task'

$detailActions.Children.Add($detailDelete) | Out-Null
$detailActions.Children.Add($detailSave) | Out-Null
$detailStack.Children.Add($detailActions) | Out-Null

$detailScroll.Content = $detailStack
$detailsPanel.Child = $detailScroll
$root.Children.Add($detailsPanel) | Out-Null
[System.Windows.Controls.Panel]::SetZIndex($detailsPanel, 4000)

$addPanel = New-Object System.Windows.Controls.Grid
$addPanel.Width = 500
$addPanel.Height = 400
$addPanel.Visibility = 'Collapsed'
$addPanel.HorizontalAlignment = 'Center'
$addPanel.VerticalAlignment = 'Center'
$script:addPanel = $addPanel

$addTopRow = New-Object System.Windows.Controls.RowDefinition
$addTopRow.Height = New-Object System.Windows.GridLength(52)
$addCardRow = New-Object System.Windows.Controls.RowDefinition
$addCardRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$addBottomRow = New-Object System.Windows.Controls.RowDefinition
$addBottomRow.Height = New-Object System.Windows.GridLength(38)
$addPanel.RowDefinitions.Add($addTopRow)
$addPanel.RowDefinitions.Add($addCardRow)
$addPanel.RowDefinitions.Add($addBottomRow)

Add-OrnamentShadow $addPanel 1

$addTopOrnament = New-DetailOrnament
[System.Windows.Controls.Grid]::SetRow($addTopOrnament, 0)
$addPanel.Children.Add($addTopOrnament) | Out-Null

$addCard = New-Object System.Windows.Controls.Border
$addCard.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F4070708')
$addCard.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#66FFFFFF')
$addCard.BorderThickness = 1
$addCard.CornerRadius = 4
$addCard.Padding = 14
$addCard.Margin = '20,0'
[System.Windows.Controls.Grid]::SetRow($addCard, 1)
$addPanel.Children.Add($addCard) | Out-Null

$addLayout = New-Object System.Windows.Controls.Grid
$addHeaderRow = New-Object System.Windows.Controls.RowDefinition
$addHeaderRow.Height = New-Object System.Windows.GridLength(38)
$addBodyRow = New-Object System.Windows.Controls.RowDefinition
$addBodyRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$addLayout.RowDefinitions.Add($addHeaderRow)
$addLayout.RowDefinitions.Add($addBodyRow)
$addCard.Child = $addLayout

$addHeaderGrid = New-Object System.Windows.Controls.Grid
$addHeaderCol = New-Object System.Windows.Controls.ColumnDefinition
$addHeaderCol.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$addHeaderSaveCol = New-Object System.Windows.Controls.ColumnDefinition
$addHeaderSaveCol.Width = New-Object System.Windows.GridLength(36)
$addHeaderCloseCol = New-Object System.Windows.Controls.ColumnDefinition
$addHeaderCloseCol.Width = New-Object System.Windows.GridLength(34)
$addHeaderGrid.ColumnDefinitions.Add($addHeaderCol)
$addHeaderGrid.ColumnDefinitions.Add($addHeaderSaveCol)
$addHeaderGrid.ColumnDefinitions.Add($addHeaderCloseCol)
[System.Windows.Controls.Grid]::SetRow($addHeaderGrid, 0)
$addLayout.Children.Add($addHeaderGrid) | Out-Null

$addHeader = New-Object System.Windows.Controls.TextBlock
$addHeader.Text = 'New Task'
$addHeader.Foreground = [System.Windows.Media.Brushes]::White
$addHeader.FontSize = 18
$addHeader.FontWeight = 'Bold'
[System.Windows.Controls.Grid]::SetColumn($addHeader, 0)
$addHeaderGrid.Children.Add($addHeader) | Out-Null

$createButton = New-RoundButton '' 30
$script:addCreateButton = $createButton
Set-DetailEditVisual $createButton $true
$createButton.ToolTip = 'Create Task'
[System.Windows.Controls.Grid]::SetColumn($createButton, 1)
$addHeaderGrid.Children.Add($createButton) | Out-Null

$addClose = New-RoundButton 'X' 30
$script:addCloseButton = $addClose
$addClose.ToolTip = 'Cancel'
[System.Windows.Controls.Grid]::SetColumn($addClose, 2)
$addHeaderGrid.Children.Add($addClose) | Out-Null

$addBody = New-Object System.Windows.Controls.Grid
$script:addBody = $addBody
$addBody.Margin = '8,2,8,0'
[System.Windows.Controls.Grid]::SetRow($addBody, 1)
$addLayout.Children.Add($addBody) | Out-Null

$addIconRow = New-Object System.Windows.Controls.RowDefinition
$addIconRow.Height = New-Object System.Windows.GridLength(82)
$addTitleRow = New-Object System.Windows.Controls.RowDefinition
$addTitleRow.Height = New-Object System.Windows.GridLength(34)
$addTitleOrnamentRow = New-Object System.Windows.Controls.RowDefinition
$addTitleOrnamentRow.Height = New-Object System.Windows.GridLength(22)
$addDescriptionRow = New-Object System.Windows.Controls.RowDefinition
$addDescriptionRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$addBody.RowDefinitions.Add($addIconRow)
$addBody.RowDefinitions.Add($addTitleRow)
$addBody.RowDefinitions.Add($addTitleOrnamentRow)
$addBody.RowDefinitions.Add($addDescriptionRow)

$addIconHostGrid = New-Object System.Windows.Controls.Grid
[System.Windows.Controls.Grid]::SetRow($addIconHostGrid, 0)
$addBody.Children.Add($addIconHostGrid) | Out-Null

$addSelectedIconHost = New-Object System.Windows.Controls.Border
$script:addSelectedIconHost = $addSelectedIconHost
$addSelectedIconHost.Width = 68
$addSelectedIconHost.Height = 68
$addSelectedIconHost.HorizontalAlignment = 'Center'
$addSelectedIconHost.VerticalAlignment = 'Bottom'
$addSelectedIconHost.RenderTransform = New-Object System.Windows.Media.TranslateTransform(0, 3)
[System.Windows.Controls.Panel]::SetZIndex($addSelectedIconHost, 2)
$addIconHostGrid.Children.Add($addSelectedIconHost) | Out-Null

$addIconOrnament = New-DecorativeAsset 'backgrounds/dialogue_fleur_bottom0007.png' 22
$addIconOrnament.VerticalAlignment = 'Bottom'
[System.Windows.Controls.Panel]::SetZIndex($addIconOrnament, 1)
$addIconHostGrid.Children.Add($addIconOrnament) | Out-Null

$addChangeIconButton = New-RoundButton '' 30
$script:addChangeIconButton = $addChangeIconButton
Set-DetailEditVisual $addChangeIconButton $false
$addChangeIconButton.ToolTip = 'Edit Icon'
$addChangeIconButton.HorizontalAlignment = 'Center'
$addChangeIconButton.VerticalAlignment = 'Top'
$addChangeIconButton.Margin = '0,-8,0,0'
[System.Windows.Controls.Panel]::SetZIndex($addChangeIconButton, 3)
$addIconHostGrid.Children.Add($addChangeIconButton) | Out-Null

$titleBox = New-Object System.Windows.Controls.TextBox
$script:addTitleBox = $titleBox
$titleBox.Height = 30
$titleBox.Margin = '24,2'
[System.Windows.Controls.Grid]::SetRow($titleBox, 1)
$addBody.Children.Add($titleBox) | Out-Null
Add-TextBoxPlaceholder $addBody $titleBox 'Task title' '32,2,32,2' 1 'Center'

$addTitleOrnament = New-DecorativeAsset 'backgrounds/Controller_Dialogue_0001_bot.png' 20
[System.Windows.Controls.Grid]::SetRow($addTitleOrnament, 2)
$addBody.Children.Add($addTitleOrnament) | Out-Null

$addDescriptionFrame = New-Object System.Windows.Controls.Grid
$addDescriptionFrame.Margin = '6,2,6,2'
[System.Windows.Controls.Grid]::SetRow($addDescriptionFrame, 3)
$addBody.Children.Add($addDescriptionFrame) | Out-Null
Add-DescriptionCorners $addDescriptionFrame

$descBox = New-Object System.Windows.Controls.TextBox
$script:addDescriptionBox = $descBox
$descBox.AcceptsReturn = $true
$descBox.TextWrapping = 'Wrap'
$descBox.VerticalScrollBarVisibility = 'Auto'
$descBox.Margin = '24,16,24,16'
$descBox.Padding = '6'
$descBox.Background = [System.Windows.Media.Brushes]::White
$descBox.Foreground = [System.Windows.Media.Brushes]::Black
$descBox.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFB8B8B8')
$descBox.BorderThickness = 1
[System.Windows.Controls.Panel]::SetZIndex($descBox, 2)
$addDescriptionFrame.Children.Add($descBox) | Out-Null
Add-TextBoxPlaceholder $addDescriptionFrame $descBox 'Describe your task...' '32,22,32,22' 0 'Top'

$addSavingPanel = New-Object System.Windows.Controls.Grid
$script:addSavingPanel = $addSavingPanel
$addSavingPanel.Visibility = 'Collapsed'
$savingPreviewRow = New-Object System.Windows.Controls.RowDefinition
$savingPreviewRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
$savingStatusRow = New-Object System.Windows.Controls.RowDefinition
$savingStatusRow.Height = New-Object System.Windows.GridLength(54)
$addSavingPanel.RowDefinitions.Add($savingPreviewRow)
$addSavingPanel.RowDefinitions.Add($savingStatusRow)
[System.Windows.Controls.Grid]::SetRow($addSavingPanel, 1)
$addLayout.Children.Add($addSavingPanel) | Out-Null

$savingPreview = New-Object System.Windows.Controls.StackPanel
$savingPreview.HorizontalAlignment = 'Center'
$savingPreview.VerticalAlignment = 'Center'
[System.Windows.Controls.Grid]::SetRow($savingPreview, 0)
$addSavingPanel.Children.Add($savingPreview) | Out-Null

$addSavingVisualHost = New-Object System.Windows.Controls.Border
$script:addSavingVisualHost = $addSavingVisualHost
$addSavingVisualHost.Width = 110
$addSavingVisualHost.Height = 110
$addSavingVisualHost.HorizontalAlignment = 'Center'
$savingPreview.Children.Add($addSavingVisualHost) | Out-Null

$addSavingTitleText = New-Object System.Windows.Controls.TextBlock
$script:addSavingTitleText = $addSavingTitleText
$addSavingTitleText.Foreground = [System.Windows.Media.Brushes]::White
$addSavingTitleText.FontSize = 17
$addSavingTitleText.FontWeight = 'SemiBold'
$addSavingTitleText.TextAlignment = 'Center'
$addSavingTitleText.TextTrimming = 'CharacterEllipsis'
$addSavingTitleText.Width = 420
$addSavingTitleText.Margin = '0,4,0,0'
$savingPreview.Children.Add($addSavingTitleText) | Out-Null

$addSavingStatusText = New-Object System.Windows.Controls.TextBlock
$script:addSavingStatusText = $addSavingStatusText
$addSavingStatusText.Foreground = [System.Windows.Media.Brushes]::White
$addSavingStatusText.FontSize = 14
$addSavingStatusText.FontWeight = 'Bold'
$addSavingStatusText.TextAlignment = 'Center'
$addSavingStatusText.TextWrapping = 'Wrap'
$addSavingStatusText.VerticalAlignment = 'Bottom'
[System.Windows.Controls.Grid]::SetRow($addSavingStatusText, 1)
$addSavingPanel.Children.Add($addSavingStatusText) | Out-Null

$addBottomOrnament = New-DetailOrnament $true
[System.Windows.Controls.Grid]::SetRow($addBottomOrnament, 2)
$addPanel.Children.Add($addBottomOrnament) | Out-Null

$addWindow = New-Object System.Windows.Window
$addWindow.WindowStyle = 'None'
$addWindow.ResizeMode = 'NoResize'
$addWindow.AllowsTransparency = $true
$addWindow.Background = [System.Windows.Media.Brushes]::Transparent
$addWindow.ShowInTaskbar = $false
$addWindow.Topmost = $true
$addWindow.Width = 560
$addWindow.Height = 450
$addWindow.WindowStartupLocation = 'Manual'
$addWindow.Content = $addPanel
$script:addWindow = $addWindow

$addWindow.Add_Closing({
    param($s, $e)

    if (-not $script:exiting) {
        $e.Cancel = $true
        Close-AddTaskPanel
    }
})

$script:opacitySliderUpdating = $false

$opacitySlider.Add_ValueChanged({
    param($s, $e)

    if ($script:opacitySliderUpdating) { return }
    if ($script:editMode) { return }

    $value = [Math]::Max(20.0, [Math]::Min(100.0, [double]$s.Value))
    $opacity = $value / 100.0

    $script:window.Opacity = $opacity
    $script:config.widget.opacity = [Math]::Round($opacity, 2)
    $script:opacityLabel.Text = ([int][Math]::Round($value)).ToString() + '%'
})

$opacitySlider.Add_PreviewMouseLeftButtonUp({
    if ($script:editMode) { return }
    Save-Config
})

$script:resizeBaseWidth = 0.0
$script:resizeBaseHeight = 0.0
$script:resizeAccumulated = 0.0

$resizeButton.Add_DragStarted({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $script:resizeBaseWidth = [double]$script:window.Width
    $script:resizeBaseHeight = [double]$script:window.Height
    $script:resizeAccumulated = 0.0
})

$resizeButton.Add_DragDelta({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $horizontal = [double]$e.HorizontalChange
    $vertical = [double]$e.VerticalChange
    $script:resizeAccumulated += (($horizontal - $vertical) * 0.5)

    $minWidth = if ($null -ne $script:config.resize.minWidth) {
        [double]$script:config.resize.minWidth
    }
    else {
        320.0
    }

    $maxWidth = if ($null -ne $script:config.resize.maxWidth) {
        [double]$script:config.resize.maxWidth
    }
    else {
        1100.0
    }

    $newWidth = [Math]::Max(
        $minWidth,
        [Math]::Min(
            $maxWidth,
            ([double]$script:resizeBaseWidth + [double]$script:resizeAccumulated)
        )
    )

    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight
    $aspect = $designHeight * (1.0 / $designWidth)
    $newHeight = $newWidth * $aspect

    $bottom = [double]$script:window.Top + [double]$script:window.Height

    $script:config.widget.width = [Math]::Round($newWidth, 1)
    $script:config.widget.height = [Math]::Round($newHeight, 1)

    $script:window.Width = $newWidth
    $script:window.Height = $newHeight
    $script:window.Top = $bottom - $newHeight

    $script:config.widget.top = [Math]::Round([double]$script:window.Top, 1)
})

$resizeButton.Add_DragCompleted({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    $script:config.widget.width = [Math]::Round([double]$script:window.Width, 1)
    $script:config.widget.height = [Math]::Round([double]$script:window.Height, 1)
    Ensure-WidgetOnVisibleDisplay $false | Out-Null
    Save-WidgetPlacement
})






$backgroundClose.Add_Click({
    $script:backgroundPanel.Visibility = 'Collapsed'
})

$backgroundScaleSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundScale = [double]$s.Value / 100.0
    Render-Background
})

$backgroundXSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundOffsetX = [double]$s.Value
    Render-Background
})

$backgroundYSlider.Add_ValueChanged({
    param($s, $e)
    if (-not $script:editMode) { return }
    if ($script:backgroundPanel.Visibility -ne 'Visible') { return }

    $script:editBackgroundOffsetY = [double]$s.Value
    Render-Background
})





$closeButton.Add_PreviewMouseLeftButtonDown({
    param($s, $e)
    $e.Handled = $false
})

$closeButton.Add_Click({ Exit-Widget })
$minimizeButton.Add_Click({ if ($script:editMode) { Cancel-EditSession }; Hide-Widget })
$detailChangeIcon.Add_Click({
    Populate-IconGrid $script:detailIconGrid $script:detailSelectedIcon ([int]$script:config.icons.columns) 'detail'
    $script:detailChooser.Visibility = 'Visible'
})
$detailChooserClose.Add_Click({ $script:detailChooser.Visibility = 'Collapsed' })
$detailIconGrid.AddHandler([System.Windows.Controls.Button]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender,$e)
    $btn = $e.OriginalSource
    while ($null -ne $btn -and -not ($btn -is [System.Windows.Controls.Button])) { $btn = [System.Windows.Media.VisualTreeHelper]::GetParent($btn) }
    if ($null -eq $btn -or [string]::IsNullOrWhiteSpace([string]$btn.Tag)) { return }
    $script:detailSelectedIcon = [string]$btn.Tag
    $entry = Get-IconEntry $script:detailSelectedIcon
    if ($null -ne $entry) { $script:detailCurrentIcon.Child = New-ImageControl ([string]$entry.file) 62 }
    $script:detailChooser.Visibility = 'Collapsed'
    $e.Handled = $true
})

$detailDelete.Add_Click({
    if ([string]::IsNullOrWhiteSpace([string]$script:selectedTaskId)) { return }

    $taskId = [string]$script:selectedTaskId
    $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $taskId })
    Save-Tasks
    $script:selectedTaskId = $null
    
    Render-Tasks
})

$detailSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace([string]$script:selectedTaskId)) { return }

    $title = $script:detailTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $task = Get-TaskById ([string]$script:selectedTaskId)
    if ($null -eq $task) { return }

    $task.title = $title
    $task.description = $script:detailDescriptionBox.Text.Trim()
    $task.icon = [string]$script:detailSelectedIcon
    $task | Add-Member -NotePropertyName badgeColor -NotePropertyValue (Get-DominantIconColor ([string]$task.icon)) -Force
    Save-Tasks
    
    Render-Tasks
})

$detailClose.Add_Click({
    $script:selectedTaskId = $null
    
})

$addClose.Add_Click({ Close-AddTaskPanel })


$editButton.Add_Click({
    if (-not $script:editMode) {
    Write-WidgetLog 'EDIT' 'Opening edit mode.'
        $script:editSnapshot = Copy-JsonObject $script:area
        $script:editWorkingArea = Copy-JsonObject $script:area
        $script:editProfileId = [string]$script:config.profile
        $script:editSnapshotBackgroundFile = [string]$script:config.background.file
        $script:editBackgroundFile = [string]$script:config.background.file
        $script:editSnapshotBackgroundScale = [double]$script:config.background.scale
        $script:editSnapshotBackgroundOffsetX = [double]$script:config.background.offsetX
        $script:editSnapshotBackgroundOffsetY = [double]$script:config.background.offsetY
        $script:editBackgroundScale = [double]$script:config.background.scale
        $script:editBackgroundOffsetX = [double]$script:config.background.offsetX
        $script:editBackgroundOffsetY = [double]$script:config.background.offsetY
        $script:editSnapshotAddX = $script:config.buttons.addX
        $script:editSnapshotAddY = $script:config.buttons.addY
        $script:editSnapshotAddSize = $script:config.buttons.addSize
        $script:editAddX = $script:config.buttons.addX
        $script:editAddY = $script:config.buttons.addY
        $script:editSnapshotGridColumns = [int]$script:config.icons.columns
        $script:editGridColumns = [int]$script:config.icons.columns
        $script:pendingDeletedBackgroundIds.Clear()
        $script:editUndoStack.Clear()
        $script:editMode = $true

        Set-EditButtonVisual $true
        $script:clearButton.Visibility = 'Visible'
        $script:borderToggle.Visibility = 'Visible'
        $script:startupToggle.Visibility = 'Visible'
        $script:backgroundPanel.Visibility = 'Collapsed'
        $script:gridPanel.Visibility = 'Collapsed'
        $script:taskLayer.IsHitTestVisible = $false
        $script:editorLayer.IsHitTestVisible = $true
        $script:resizeButton.Visibility = 'Collapsed'
        $script:editButton.Visibility = 'Collapsed'
        $script:opacitySlider.Visibility = 'Collapsed'
        $script:opacityLabel.Visibility = 'Collapsed'

        Hide-Panel
        Update-EditButtons
        Apply-Config
        Render-Area
        Render-EditorNodes
        Show-EditSettingsWindow
        Write-WidgetLog 'EDIT' 'Edit mode opened.'
        return
    }

    if ($null -ne $script:draggingEditorNode) {
        $script:draggingEditorNode.ReleaseMouseCapture()
        $script:draggingEditorNode = $null
        $script:draggingEditorIndex = -1
    }

    try {
        Write-WidgetLog 'EDIT_SAVE' 'Starting edit mode save.'
        if ($null -eq $script:editWorkingArea) { throw 'Edit area is not available.' }

        $script:area = Copy-JsonObject $script:editWorkingArea
        Save-Area $script:area
        $script:config.background.file = [string]$script:editBackgroundFile
        $script:config.background.scale = [Math]::Round([double]$script:editBackgroundScale, 3)
        $script:config.background.offsetX = [Math]::Round([double]$script:editBackgroundOffsetX, 1)
        $script:config.background.offsetY = [Math]::Round([double]$script:editBackgroundOffsetY, 1)
        $script:config.buttons.addX = $script:editAddX
        $script:config.buttons.addY = $script:editAddY
        $script:config.profile = [string]$script:editProfileId
        $script:config.icons.columns = [int]$script:editGridColumns
        Save-Config
        Write-WidgetLog 'EDIT_SAVE' 'Configuration and area saved.'
        Save-ActiveProfileState
        Write-WidgetLog 'EDIT_SAVE' 'Profile state saved.'
        Close-EditSettingsWindow
        Write-WidgetLog 'EDIT_SAVE' 'Edit settings window closed.'
    }
    catch {
        Write-WidgetLog 'ERROR' ("Edit save failed: {0}" -f $_.Exception.ToString())
        [System.Windows.MessageBox]::Show(
            "Could not save edit mode: $($_.Exception.Message)",
            'Wish Board',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return
    }

    try {
        Write-WidgetLog 'EDIT_SAVE' 'Applying saved edit state and rendering.'
        $script:editMode = $false
        $script:editSnapshot = $null
        $script:editWorkingArea = $null
        if ($null -ne $script:editUndoStack) { $script:editUndoStack.Clear() }

        Set-EditButtonVisual $false
        $script:undoButton.Visibility = 'Collapsed'
        $script:clearButton.Visibility = 'Collapsed'
        $script:borderToggle.Visibility = 'Collapsed'
        $script:startupToggle.Visibility = 'Collapsed'
        $script:backgroundPanel.Visibility = 'Collapsed'
        $script:gridPanel.Visibility = 'Collapsed'
        $script:taskLayer.IsHitTestVisible = $true
        $script:editorLayer.IsHitTestVisible = $false
        $script:editButton.Visibility = 'Visible'

        Apply-Config
        Normalize-Tasks-ToArea
        Render-Background
        Render-Area
        Render-EditorNodes
        Render-Tasks
        Write-WidgetLog 'EDIT_SAVE' 'Edit mode save completed.'
    }
    catch {
        $errorPath = Join-Path $base 'widget-error.log'
        Add-Content -LiteralPath $errorPath -Value ("{0} Save edit: {1}" -f (Get-Date), $_.Exception.ToString())
        Write-WidgetLog 'ERROR' ("Edit finalization failed: {0}" -f $_.Exception.ToString())
        return
    }
})

$undoButton.Add_Click({
    if (-not $script:editMode -or $script:editUndoStack.Count -eq 0) { return }

    $checkpoint = $script:editUndoStack.Pop()
    $script:editWorkingArea = Copy-JsonObject $checkpoint.area
    $script:editProfileId = [string]$checkpoint.profileId
    $script:editBackgroundFile = [string]$checkpoint.backgroundFile
    $script:editBackgroundScale = [double]$checkpoint.backgroundScale
    $script:editBackgroundOffsetX = [double]$checkpoint.backgroundOffsetX
    $script:editBackgroundOffsetY = [double]$checkpoint.backgroundOffsetY
    $script:editAddX = $checkpoint.addX
    $script:editAddY = $checkpoint.addY
    $script:editGridColumns = [int]$checkpoint.gridColumns

    Update-EditButtons
    Apply-Config
    Render-Area
    Render-EditorNodes
    Render-Background
    Update-SettingsProfileSelection

    if ($script:gridPanel.Visibility -eq 'Visible') {
        $script:columnsBox.Text = [string]$script:editGridColumns
        Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview'
    }
})

$clearButton.Add_Click({
    if (-not $script:editMode) { return }

    Push-EditUndo

    $profile = Get-Profile ([string]$script:editProfileId)
    $script:editWorkingArea = Copy-JsonObject $profile.defaults.area
    $script:editAddX = [double]$profile.defaults.addX
    $script:editAddY = [double]$profile.defaults.addY
    $script:config.buttons.addSize = [double]$profile.defaults.addSize

    Update-EditButtons
    Render-Area
    Render-EditorNodes
    Render-Background
    Render-BackgroundChoices
    Apply-Config

    if ($script:gridPanel.Visibility -eq 'Visible') {
        $script:columnsBox.Text = '3'
        Populate-IconGrid $script:gridPreview '' 3 'preview'
    }
})

$gridClose.Add_Click({
    $script:gridPanel.Visibility = 'Collapsed'
})

$columnsBox.Add_TextChanged({
    if (-not $script:editMode) { return }

    $value = 0

    if ([int]::TryParse($script:columnsBox.Text, [ref]$value)) {
        $value = [Math]::Max(1, [Math]::Min(8, $value))

        if ($value -ne [int]$script:editGridColumns) {
            Push-EditUndo
            $script:editGridColumns = $value
        }

        Populate-IconGrid $script:gridPreview '' $script:editGridColumns 'preview'
    }
})

$borderToggle.Add_Click({
    if (-not $script:editMode) { return }

    Push-EditUndo
    $script:editWorkingArea.borderVisible = -not [bool]$script:editWorkingArea.borderVisible
    Update-EditButtons
    Render-Area
    Render-EditorNodes
})

$startupToggle.Add_Click({
    if (-not $script:editMode) { return }
    try {
        if (Test-StartupEnabled) {
            Disable-Startup
        }
        else {
            Enable-Startup
        }
        Update-StartupButton
    }
    catch {
        [System.Windows.MessageBox]::Show(
            'The Windows startup setting could not be changed.',
            'Startup Setting',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        Update-StartupButton
    }
})

$script:addDragActive = $false

$addButton.Add_PreviewMouseLeftButtonDown({
    param($s, $e)

    if (-not $script:editMode) {
        return
    }

    Push-EditUndo
    $script:addDragActive = $true
    [void]$s.CaptureMouse()
    $e.Handled = $true
})

$addButton.Add_PreviewMouseMove({
    param($s, $e)

    if (-not $script:editMode -or -not $script:addDragActive) { return }
    if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

    $p = $e.GetPosition($script:root)

    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight
    $size = [double]$script:addButton.Width
    $toolbarBottom = if ($null -ne $script:config.buttons.toolbarBottom) { [double]$script:config.buttons.toolbarBottom } else { 12.0 }
    $toolbarY = $designHeight - 42.0 - $toolbarBottom
    $maxY = $toolbarY - $size - 10.0

    $x = [Math]::Max(0.0, [Math]::Min($designWidth - $size, [double]$p.X - ($size * 0.5)))
    $y = [Math]::Max(0.0, [Math]::Min($maxY, [double]$p.Y - ($size * 0.5)))

    $centerX = $x + ($size * 0.5)
    $centerY = $y + ($size * 0.5)

    if (Point-InPolygon $centerX $centerY) {
        $e.Handled = $true
        return
    }

    $script:editAddX = [Math]::Round($x, 1)
    $script:editAddY = [Math]::Round($y, 1)

    [System.Windows.Controls.Canvas]::SetLeft($s, $script:editAddX)
    [System.Windows.Controls.Canvas]::SetTop($s, $script:editAddY)

    $sliderX = [Math]::Min(
        $designWidth - [double]$script:addSizeSlider.Width - 4.0,
        [double]$script:editAddX + $size + 8.0
    )
    $sliderY = [double]$script:editAddY + (($size - [double]$script:addSizeSlider.Height) * 0.5)

    [System.Windows.Controls.Canvas]::SetLeft($script:addSizeSlider, $sliderX)
    [System.Windows.Controls.Canvas]::SetTop($script:addSizeSlider, $sliderY)

    $e.Handled = $true
})

$addButton.Add_PreviewMouseLeftButtonUp({
    param($s, $e)

    if (-not $script:addDragActive) { return }

    $script:addDragActive = $false

    if ($s.IsMouseCaptured) {
        $s.ReleaseMouseCapture()
    }

    $e.Handled = $true
})

$script:addSizeSliderUpdating = $false

$addSizeSlider.Add_ValueChanged({
    param($s, $e)
    if ($script:addSizeSliderUpdating -or -not $script:editMode) { return }

    Push-EditUndo
    $script:config.buttons.addSize = [Math]::Round([double]$s.Value, 1)
    Apply-Config
})

$addSizeSlider.Add_PreviewMouseLeftButtonUp({
    if ($script:editMode) {
        Save-Config
    }
})

$addButton.Add_Click({
    Open-AddTaskPanel
})

$addChangeIconButton.Add_Click({
    $selectedIconId = Show-TaskIconChooser `
        -Owner $script:addWindow `
        -SelectedIcon $script:addSelectedIcon

    if ([string]::IsNullOrWhiteSpace([string]$selectedIconId)) { return }
    $script:addSelectedIcon = [string]$selectedIconId
    Refresh-AddIconSelection
})

$createButton.Add_PreviewMouseLeftButtonUp({
    param($s, $e)
    $e.Handled = $true
    Create-NewTask
})


$root.Add_MouseLeftButtonDown({
    param($s, $e)

    if ($script:editMode) {
        return
    }

    if ($null -ne (Get-ButtonAncestor $e.OriginalSource)) {
        return
    }

    if ($null -ne $script:addPanel -and $script:addPanel.Visibility -eq 'Visible') {
        return
    }

    $cursor = [System.Windows.Forms.Cursor]::Position

    $script:widgetDragActive = $true
    $script:widgetDragStartMouseX = [double]$cursor.X
    $script:widgetDragStartMouseY = [double]$cursor.Y
    $script:widgetDragStartLeft = [double]$script:window.Left
    $script:widgetDragStartTop = [double]$script:window.Top
    $script:widgetNormalOpacity = [double]$script:window.Opacity

    $dragOpacity = if ($null -ne $script:config.drag.opacity) {
        [double]$script:config.drag.opacity
    }
    else {
        0.55
    }

    $script:window.Opacity = [Math]::Max(0.2, [Math]::Min(1.0, $dragOpacity))
    [void]$script:root.CaptureMouse()

    $e.Handled = $true
})

$root.Add_MouseMove({
    param($s, $e)

    if (-not $script:widgetDragActive) {
        return
    }

    if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) {
        return
    }

    $cursor = [System.Windows.Forms.Cursor]::Position

    $deltaX = [double]$cursor.X - [double]$script:widgetDragStartMouseX
    $deltaY = [double]$cursor.Y - [double]$script:widgetDragStartMouseY

    $script:window.Left = [double]$script:widgetDragStartLeft + $deltaX
    $script:window.Top = [double]$script:widgetDragStartTop + $deltaY

    $e.Handled = $true
})

$root.Add_MouseLeftButtonUp({
    param($s, $e)

    if (-not $script:widgetDragActive) {
        return
    }

    $script:widgetDragActive = $false

    if ($script:root.IsMouseCaptured) {
        $script:root.ReleaseMouseCapture()
    }

    $script:window.Opacity = [double]$script:widgetNormalOpacity
    Save-WidgetPlacement
    $e.Handled = $true
})

$root.Add_LostMouseCapture({
    if (-not $script:widgetDragActive) {
        return
    }

    $script:widgetDragActive = $false
    $script:window.Opacity = [double]$script:widgetNormalOpacity
    Save-WidgetPlacement
})

$window.Add_LocationChanged({
    if (-not $script:positionInitialized -or $script:widgetDragActive -or $script:suppressPositionSave) { return }
    Save-WidgetPlacement
})

$window.Add_StateChanged({
    if (-not $script:userHidden -and $script:window.WindowState -eq 'Minimized') {
        $script:window.WindowState = 'Normal'
        $script:window.Show()
    }
})

$window.Add_Closing({
    param($s, $e)

    if (-not $script:exiting) {
        $e.Cancel = $true
        Hide-Widget
    }
})

$window.Add_Closed({
    $script:exiting = $true
    if ($null -ne $script:reloadTimer) { $script:reloadTimer.Stop() }
    if ($null -ne $script:desktopTimer) { $script:desktopTimer.Stop() }
})

$tray = New-Object System.Windows.Forms.NotifyIcon
$trayIconPath = Join-Path $PSScriptRoot 'widget.ico'

if (Test-Path $trayIconPath) {
    $script:trayIcon = New-Object System.Drawing.Icon($trayIconPath)
    $tray.Icon = $script:trayIcon
}
else {
    $tray.Icon = [System.Drawing.SystemIcons]::Application
}

$tray.Text = 'Desktop Widget'
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add('Show')
$hideItem = $menu.Items.Add('Hide')
$exitItem = $menu.Items.Add('Exit')

$showItem.Add_Click({ Show-Widget })
$hideItem.Add_Click({ Hide-Widget })
$exitItem.Add_Click({ Exit-Widget })

$tray.ContextMenuStrip = $menu

$showFromTray = {
    $script:window.Dispatcher.BeginInvoke(
        [System.Action]{
            Show-Widget
        },
        [System.Windows.Threading.DispatcherPriority]::Send
    ) | Out-Null
}

$tray.Add_MouseDown({
    param($s, $e)

    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $showFromTray
    }
})

$tray.Add_Click({
    if ([System.Windows.Forms.Control]::MouseButtons -eq [System.Windows.Forms.MouseButtons]::Left) {
        & $showFromTray
    }
})

$tray.Add_DoubleClick({
    & $showFromTray
})

$script:tray = $tray

Set-EditButtonVisual $false
Apply-Config
Render-Tasks
Render-EditorNodes
Initialize-PositionCache

$reloadTimer = New-Object System.Windows.Threading.DispatcherTimer
$reloadTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(5, [double]$script:config.refreshSeconds))
$reloadTimer.Add_Tick({ Reload-Files })
$script:reloadTimer = $reloadTimer
$reloadTimer.Start()

$desktopTimer = New-Object System.Windows.Threading.DispatcherTimer
$desktopTimer.Interval = [TimeSpan]::FromMilliseconds(700)
$desktopTimer.Add_Tick({
    if ($script:exiting) { return }

    try {
        $currentDisplaySignature = Get-DisplaySignature
        $displayChanged = $currentDisplaySignature -ne $script:displaySignature

        if ($displayChanged) {
            $script:displaySignature = $currentDisplaySignature
            Ensure-WidgetOnVisibleDisplay $true | Out-Null
        }

        if ($script:userHidden) { return }

        if (-not $script:window.IsVisible) {
            $script:window.Show()
            Ensure-WidgetOnVisibleDisplay $displayChanged | Out-Null
        }

        if ($script:window.WindowState -eq 'Minimized') {
            $script:window.WindowState = 'Normal'
        }

        $script:window.Topmost = [bool]$script:config.widget.topmost
    }
    catch {
        $script:desktopTimer.Stop()
    }
})
$script:desktopTimer = $desktopTimer
$desktopTimer.Start()

$calendarTimer = New-Object System.Windows.Threading.DispatcherTimer
$calendarTimer.Interval = [TimeSpan]::FromMinutes(1)
$calendarTimer.Add_Tick({ try { Sync-GoogleCalendar } catch {} })
$script:calendarTimer = $calendarTimer
$calendarTimer.Start()

$window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)

    $eventArgs.Handled = $true
    $errorPath = Join-Path $base 'widget-error.log'
    Add-Content -LiteralPath $errorPath -Value ("{0} Dispatcher: {1}" -f (Get-Date), $eventArgs.Exception.ToString())
    Write-WidgetLog 'ERROR' ("Dispatcher exception: {0}" -f $eventArgs.Exception.ToString())
})

$window.Show()
Ensure-WidgetOnVisibleDisplay $false | Out-Null
$window.Activate() | Out-Null
try {
    Initialize-GoogleCalendar
} catch {
    [System.Windows.MessageBox]::Show(
        "Google Calendar connection failed:`n`n$($_.Exception.Message)",
        'Google Calendar',
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
}
Write-WidgetLog 'READY' 'Widget window shown; entering dispatcher loop.'
[System.Windows.Threading.Dispatcher]::Run()
}
finally {
    Write-WidgetLog 'STOP' 'Widget process stopping.'
    $script:exiting = $true
    Dispose-ApplicationResources
    Exit-ApplicationInstance
}
