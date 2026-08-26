function Render-Background {
    $script:background.Source = $null
    $activeFile = Get-ActiveBackgroundFile
    $path = Join-Path $base $activeFile

    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $script:background.Source = $bitmap
    }

    $scale = [Math]::Max(0.2, [Math]::Min(4.0, [double](Get-ActiveBackgroundScale)))
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight

    $script:background.Width = $designWidth * $scale
    $script:background.Height = $designHeight * $scale

    [System.Windows.Controls.Canvas]::SetLeft(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetX) - (($script:background.Width - $designWidth) * 0.5))
    )

    [System.Windows.Controls.Canvas]::SetTop(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetY) - (($script:background.Height - $designHeight) * 0.5))
    )

    $script:background.Opacity = [double]$script:config.background.opacity
    $script:background.Stretch = [System.Enum]::Parse(
        [System.Windows.Media.Stretch],
        [string]$script:config.background.stretch,
        $true
    )
    Render-ProfileAccessory
}

function Render-ProfileAccessory {
    if ($null -eq $script:profileAccessory) { return }
    $profile = Get-ActiveProfile
    $script:profileAccessory.Source = $null
    if ($null -eq $profile) { return }
    $path = Join-Path $base ([string]$profile.accessory)
    if (-not (Test-Path $path)) { return }
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = 'OnLoad'
    $bitmap.UriSource = New-Object System.Uri($path)
    $bitmap.EndInit()
    $script:profileAccessory.Source = $bitmap
}

function Render-Area {
    $activeArea = Get-ActiveArea
    $points = New-Object System.Windows.Media.PointCollection

    foreach ($p in @($activeArea.points)) {
        $points.Add([System.Windows.Point]::new([double]$p.x, [double]$p.y))
    }

    $script:taskArea.Points = $points
    $showBorder = $script:editMode -or [bool]$activeArea.borderVisible
    $script:taskArea.Visibility = if ($showBorder) { 'Visible' } else { 'Collapsed' }
    $script:taskArea.StrokeThickness = [double]$activeArea.borderThickness

    if ($script:editMode) {
        $color = if ([bool]$activeArea.borderVisible) { '#FF2ECC71' } else { '#FFE74C3C' }
        $script:taskArea.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString($color)
        $script:taskArea.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$activeArea.fillColor)
    }
    else {
        $script:taskArea.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$activeArea.borderColor)
        $script:taskArea.Fill = [System.Windows.Media.Brushes]::Transparent
    }

    $script:taskArea.IsHitTestVisible = $false
}

function Render-Tasks {
    Render-Background
    $script:hoverPreviewHost.Visibility = 'Collapsed'
    $script:hoverPreviewHost.Content = $null
    foreach ($child in @($script:taskLayer.Children)) {
        $script:taskLayer.Children.Remove($child)
    }

    $size = [double]$script:area.taskSize

    foreach ($taskItem in @($script:tasks)) {
        $button = New-Object System.Windows.Controls.Button
        $button.Width = $size
        $button.Height = $size
        $button.Tag = [string]$taskItem.id
        $button.Cursor = [System.Windows.Input.Cursors]::Hand
        $button.Background = [System.Windows.Media.Brushes]::Transparent
        $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $button.BorderThickness = 0
        $button.Padding = 2
        $button.Add_MouseEnter({
            param($s, $e)
            $hoverTask = Get-TaskById ([string]$s.Tag)
            if ($null -eq $hoverTask) { return }
            $script:hoverPreviewHost.Content = New-TaskPreviewControl $hoverTask
            $script:hoverPreviewHost.Visibility = 'Visible'
        })
        $button.Add_MouseLeave({
            $script:hoverPreviewHost.Visibility = 'Collapsed'
            $script:hoverPreviewHost.Content = $null
        })

        $taskVisual = New-TaskBadgeVisual $taskItem ($size - 2)
        $taskVisual.RenderTransformOrigin = '0.5,0.5'
        $taskVisual.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1.2, 1.2)
        $button.Content = $taskVisual

        if ([bool]$taskItem.isNew) {
            $aura = New-Object System.Windows.Media.Effects.DropShadowEffect
            $aura.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$taskItem.badgeColor)
            $aura.BlurRadius = 14
            $aura.ShadowDepth = 0
            $aura.Opacity = 0.9
            $button.Effect = $aura
            $pulse = New-Object System.Windows.Media.Animation.DoubleAnimation
            $pulse.From = 0.28
            $pulse.To = 0.98
            $pulse.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds((Get-Random -Minimum 750 -Maximum 1801)))
            $pulse.BeginTime = [TimeSpan]::FromMilliseconds((Get-Random -Minimum 0 -Maximum 901))
            $pulse.AutoReverse = $true
            $pulse.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $aura.BeginAnimation([System.Windows.Media.Effects.DropShadowEffect]::OpacityProperty, $pulse)
        }

        $contextMenu = New-Object System.Windows.Controls.ContextMenu
        $deleteItem = New-Object System.Windows.Controls.MenuItem
        $deleteItem.Header = 'Delete'
        $deleteItem.Tag = [string]$taskItem.id
        $deleteItem.Add_Click({
            param($s, $e)
            $taskIdToDelete = [string]$s.Tag
            if ([string]::IsNullOrWhiteSpace($taskIdToDelete)) { return }
            $taskToDelete = Get-TaskById $taskIdToDelete
            if ($null -eq $taskToDelete) { return }
            Start-TaskDeletionAnimation $taskToDelete {
                param($task)
                $deletedId = [string]$task.id
                $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $deletedId })
                Save-Tasks
                Render-Tasks
            }
            $e.Handled = $true
        })
        $contextMenu.Items.Add($deleteItem) | Out-Null
        $button.ContextMenu = $contextMenu

        [System.Windows.Controls.Canvas]::SetLeft($button, [double]$taskItem.x)
        [System.Windows.Controls.Canvas]::SetTop($button, [double]$taskItem.y)

        $state = [pscustomobject]@{
            dragging = $false
            moved = $false
            startScreenX = 0.0
            startScreenY = 0.0
            originX = [double]$taskItem.x
            originY = [double]$taskItem.y
            lastX = [double]$taskItem.x
            lastY = [double]$taskItem.y
        }

        $button.Add_PreviewMouseLeftButtonDown({
            param($s, $e)

            if ($script:editMode) {
                $e.Handled = $true
                return
            }

            $cursor = [System.Windows.Forms.Cursor]::Position
            $state.dragging = $true
            $state.moved = $false
            $state.startScreenX = [double]$cursor.X
            $state.startScreenY = [double]$cursor.Y
            $state.originX = [double][System.Windows.Controls.Canvas]::GetLeft($s)
            $state.originY = [double][System.Windows.Controls.Canvas]::GetTop($s)
            $state.lastX = [double]$state.originX
            $state.lastY = [double]$state.originY
            [void]$s.CaptureMouse()
            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_PreviewMouseMove({
            param($s, $e)

            if ($script:editMode -or -not $state.dragging) { return }
            if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

            $cursor = [System.Windows.Forms.Cursor]::Position
            $cursorX = [double]$cursor.X
            $cursorY = [double]$cursor.Y
            $startScreenX = [double]$state.startScreenX
            $startScreenY = [double]$state.startScreenY
            $designWidth = [double]$script:config.widget.designWidth
            $designHeight = [double]$script:config.widget.designHeight
            $viewportWidth = [double]$script:viewport.ActualWidth
            $viewportHeight = [double]$script:viewport.ActualHeight

            $scaleX = if ($designWidth -gt 0.0) { $viewportWidth / $designWidth } else { 1.0 }
            $scaleY = if ($designHeight -gt 0.0) { $viewportHeight / $designHeight } else { 1.0 }
            $scale = [Math]::Min([double]$scaleX, [double]$scaleY)
            if ($scale -le 0.0001) { $scale = 1.0 }

            $deltaX = ($cursorX - $startScreenX) / $scale
            $deltaY = ($cursorY - $startScreenY) / $scale
            $candidateX = [double]$state.originX + $deltaX
            $candidateY = [double]$state.originY + $deltaY

            if (([Math]::Abs($deltaX) + [Math]::Abs($deltaY)) -gt 2.0) {
                $state.moved = $true
            }

            if ($state.moved) {
                $position = Constrain-TaskDrag `
                    ([string]$s.Tag) `
                    ([double]$state.lastX) `
                    ([double]$state.lastY) `
                    ([double]$candidateX) `
                    ([double]$candidateY) `
                    $size

                $state.lastX = [double]$position.X
                $state.lastY = [double]$position.Y

                [System.Windows.Controls.Canvas]::SetLeft($s, [double]$position.X)
                [System.Windows.Controls.Canvas]::SetTop($s, [double]$position.Y)
            }

            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_PreviewMouseLeftButtonUp({
            param($s, $e)

            if (-not $state.dragging) { return }

            $state.dragging = $false
            $s.ReleaseMouseCapture()

            $taskId = [string]$s.Tag
            $selectedTask = Get-TaskById $taskId

            if ($null -ne $selectedTask) {
                if ($state.moved) {
                    $selectedTask.x = [Math]::Round([double][System.Windows.Controls.Canvas]::GetLeft($s), 1)
                    $selectedTask.y = [Math]::Round([double][System.Windows.Controls.Canvas]::GetTop($s), 1)
                    Save-Tasks
                    Render-Tasks
                }
                else {
                    if ([bool]$selectedTask.isNew) {
                        $selectedTask | Add-Member -NotePropertyName isNew -NotePropertyValue $false -Force
                        $s.Effect = $null
                        Save-Tasks
                    }
                    Show-DetailsById $taskId
                }
            }

            $e.Handled = $true
        }.GetNewClosure())

        $button.Add_LostMouseCapture({
            $state.dragging = $false
        }.GetNewClosure())

        $script:taskLayer.Children.Add($button) | Out-Null
    }
}

