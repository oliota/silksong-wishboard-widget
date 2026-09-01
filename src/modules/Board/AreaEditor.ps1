function Save-Area {
    param($AreaToSave = $null)

    $target = if ($null -ne $AreaToSave) { $AreaToSave } else { $script:area }
    Write-WidgetLog 'SAVE_AREA' ("Writing area file: {0}" -f $areaPath)
    $tempPath = "$areaPath.tmp"
    $json = $target | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $areaPath -Force
    $script:areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
    Write-WidgetLog 'SAVE_AREA' 'Area file saved.'
}

function Distance-ToSegment([double]$px, [double]$py, [double]$ax, [double]$ay, [double]$bx, [double]$by) {
    $vx = $bx - $ax
    $vy = $by - $ay
    $len2 = ($vx * $vx) + ($vy * $vy)

    if ($len2 -le 0.000001) {
        $dx = $px - $ax
        $dy = $py - $ay
        return [pscustomobject]@{
            Distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
            X = $ax
            Y = $ay
        }
    }

    $t = (($px - $ax) * $vx + ($py - $ay) * $vy) / $len2
    $t = [Math]::Max(0, [Math]::Min(1, $t))
    $x = $ax + ($t * $vx)
    $y = $ay + ($t * $vy)
    $dx = $px - $x
    $dy = $py - $y

    [pscustomobject]@{
        Distance = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
        X = $x
        Y = $y
    }
}

function Insert-Node-OnNearestSegment([double]$x, [double]$y) {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return $false }

    $points = @($script:editWorkingArea.points)
    if ($points.Count -lt 2) { return $false }

    $best = $null

    for ($i = 0; $i -lt $points.Count; $i++) {
        $j = ($i + 1) % $points.Count
        $hit = Distance-ToSegment $x $y ([double]$points[$i].x) ([double]$points[$i].y) ([double]$points[$j].x) ([double]$points[$j].y)

        if ($null -eq $best -or $hit.Distance -lt $best.Distance) {
            $best = [pscustomobject]@{
                Distance = $hit.Distance
                X = $hit.X
                Y = $hit.Y
                InsertAt = $j
            }
        }
    }

    if ($null -eq $best -or [double]$best.Distance -gt 18.0) { return $false }

    Push-EditUndo

    $list = New-Object System.Collections.ArrayList
    foreach ($p in $points) {
        [void]$list.Add([pscustomobject][ordered]@{ x = [double]$p.x; y = [double]$p.y })
    }

    [void]$list.Insert(
        [int]$best.InsertAt,
        [pscustomobject][ordered]@{
            x = [Math]::Round([double]$best.X, 1)
            y = [Math]::Round([double]$best.Y, 1)
        }
    )

    $script:editWorkingArea.points = @($list)
    Render-Area
    Render-EditorNodes
    Update-EditButtons
    return $true
}

function Insert-EditorNodeOnSegment([int]$segmentStartIndex) {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return }

    $points = @($script:editWorkingArea.points)
    if ($points.Count -lt 2) { return }
    if ($segmentStartIndex -lt 0 -or $segmentStartIndex -ge $points.Count) { return }

    $segmentEndIndex = ($segmentStartIndex + 1) % $points.Count
    $a = $points[$segmentStartIndex]
    $b = $points[$segmentEndIndex]

    Push-EditUndo

    $newPoints = New-Object System.Collections.ArrayList
    foreach ($point in $points) {
        [void]$newPoints.Add(
            [pscustomobject][ordered]@{
                x = [double]$point.x
                y = [double]$point.y
            }
        )
    }

    $newPoint = [pscustomobject][ordered]@{
        x = [Math]::Round((([double]$a.x + [double]$b.x) * 0.5), 1)
        y = [Math]::Round((([double]$a.y + [double]$b.y) * 0.5), 1)
    }

    $insertAt = $segmentStartIndex + 1

    if ($insertAt -ge $newPoints.Count) {
        [void]$newPoints.Add($newPoint)
    }
    else {
        [void]$newPoints.Insert($insertAt, $newPoint)
    }

    $script:editWorkingArea.points = @($newPoints)
    Render-Area
    Render-EditorNodes
    Update-EditButtons
}

function New-NodeAddButton {
    $button = New-RoundButton '' 16
    $button.ToolTip = 'Insert Node'

    $view = New-Object System.Windows.Controls.Viewbox
    $view.Width = 10
    $view.Height = 10

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = 10
    $canvas.Height = 10

    $horizontal = New-Object System.Windows.Shapes.Line
    $horizontal.X1 = 1
    $horizontal.Y1 = 5
    $horizontal.X2 = 9
    $horizontal.Y2 = 5
    $horizontal.Stroke = [System.Windows.Media.Brushes]::White
    $horizontal.StrokeThickness = 2
    $horizontal.StrokeStartLineCap = 'Round'
    $horizontal.StrokeEndLineCap = 'Round'

    $vertical = New-Object System.Windows.Shapes.Line
    $vertical.X1 = 5
    $vertical.Y1 = 1
    $vertical.X2 = 5
    $vertical.Y2 = 9
    $vertical.Stroke = [System.Windows.Media.Brushes]::White
    $vertical.StrokeThickness = 2
    $vertical.StrokeStartLineCap = 'Round'
    $vertical.StrokeEndLineCap = 'Round'

    $canvas.Children.Add($horizontal) | Out-Null
    $canvas.Children.Add($vertical) | Out-Null
    $view.Child = $canvas
    $button.Content = $view
    $button
}

function Render-EditorNodes {
    if ($null -eq $script:editorLayer) { return }
    $script:editorLayer.Children.Clear()

    if (-not $script:editMode -or $null -eq $script:editWorkingArea) {
        $script:editorLayer.IsHitTestVisible = $false
        $script:editorLayer.Background = [System.Windows.Media.Brushes]::Transparent
        return
    }

    $script:editorLayer.IsHitTestVisible = $true
    $script:editorLayer.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#01000000')
    $points = @($script:editWorkingArea.points)

    if ($points.Count -ge 2) {
        for ($i = 0; $i -lt $points.Count; $i++) {
            $j = ($i + 1) % $points.Count
            $a = $points[$i]
            $b = $points[$j]

            $line = New-Object System.Windows.Shapes.Line
            $line.X1 = [double]$a.x
            $line.Y1 = [double]$a.y
            $line.X2 = [double]$b.x
            $line.Y2 = [double]$b.y
            $line.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
                $(if ([bool]$script:editWorkingArea.borderVisible) { '#FF2ECC71' } else { '#FFE74C3C' })
            )
            $line.StrokeThickness = 2
            $line.IsHitTestVisible = $false
            $script:editorLayer.Children.Add($line) | Out-Null
        }
    }

    for ($index = 0; $index -lt $points.Count; $index++) {
        $point = $points[$index]
        $prevIndex = ($index - 1 + $points.Count) % $points.Count
        $nextIndex = ($index + 1) % $points.Count
        $prev = $points[$prevIndex]
        $next = $points[$nextIndex]

        $node = New-RoundButton ([string]($index + 1)) 28
        $node.Tag = $index
        $node.ToolTip = 'Move Node ' + ([string]($index + 1))
        $node.Cursor = [System.Windows.Input.Cursors]::SizeAll
        $node.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(245, 20, 110, 190))
        [System.Windows.Controls.Panel]::SetZIndex($node, 510)
        [System.Windows.Controls.Canvas]::SetLeft($node, [double]$point.x - 14)
        [System.Windows.Controls.Canvas]::SetTop($node, [double]$point.y - 14)

        $midPrevX = ([double]$prev.x + [double]$point.x) * 0.5
        $midPrevY = ([double]$prev.y + [double]$point.y) * 0.5
        $midNextX = ([double]$point.x + [double]$next.x) * 0.5
        $midNextY = ([double]$point.y + [double]$next.y) * 0.5

        $leftButtonX = [double]$point.x - 38.0
        $leftButtonY = [double]$point.y
        $rightButtonX = [double]$point.x + 38.0
        $rightButtonY = [double]$point.y

        $leftPrevDistance = [Math]::Sqrt(
            (($leftButtonX - $midPrevX) * ($leftButtonX - $midPrevX)) +
            (($leftButtonY - $midPrevY) * ($leftButtonY - $midPrevY))
        )
        $leftNextDistance = [Math]::Sqrt(
            (($leftButtonX - $midNextX) * ($leftButtonX - $midNextX)) +
            (($leftButtonY - $midNextY) * ($leftButtonY - $midNextY))
        )

        $rightPrevDistance = [Math]::Sqrt(
            (($rightButtonX - $midPrevX) * ($rightButtonX - $midPrevX)) +
            (($rightButtonY - $midPrevY) * ($rightButtonY - $midPrevY))
        )
        $rightNextDistance = [Math]::Sqrt(
            (($rightButtonX - $midNextX) * ($rightButtonX - $midNextX)) +
            (($rightButtonY - $midNextY) * ($rightButtonY - $midNextY))
        )

        $assignmentA = $leftPrevDistance + $rightNextDistance
        $assignmentB = $leftNextDistance + $rightPrevDistance

        if ($assignmentA -le $assignmentB) {
            $leftSegmentStart = $prevIndex
            $rightSegmentStart = $index
        }
        else {
            $leftSegmentStart = $index
            $rightSegmentStart = $prevIndex
        }

        $leftPreviewX = if ($leftSegmentStart -eq $prevIndex) { $midPrevX } else { $midNextX }
        $leftPreviewY = if ($leftSegmentStart -eq $prevIndex) { $midPrevY } else { $midNextY }
        $rightPreviewX = if ($rightSegmentStart -eq $prevIndex) { $midPrevX } else { $midNextX }
        $rightPreviewY = if ($rightSegmentStart -eq $prevIndex) { $midPrevY } else { $midNextY }

        $leftPreview = New-Object System.Windows.Shapes.Ellipse
        $leftPreview.Width = 28
        $leftPreview.Height = 28
        $leftPreview.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E6E53935')
        $leftPreview.Stroke = [System.Windows.Media.Brushes]::White
        $leftPreview.StrokeThickness = 1
        $leftPreview.Visibility = 'Collapsed'
        $leftPreview.IsHitTestVisible = $false
        [System.Windows.Controls.Canvas]::SetLeft($leftPreview, $leftPreviewX - 14)
        [System.Windows.Controls.Canvas]::SetTop($leftPreview, $leftPreviewY - 14)
        [System.Windows.Controls.Panel]::SetZIndex($leftPreview, 505)
        $script:editorLayer.Children.Add($leftPreview) | Out-Null

        $rightPreview = New-Object System.Windows.Shapes.Ellipse
        $rightPreview.Width = 28
        $rightPreview.Height = 28
        $rightPreview.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E6E53935')
        $rightPreview.Stroke = [System.Windows.Media.Brushes]::White
        $rightPreview.StrokeThickness = 1
        $rightPreview.Visibility = 'Collapsed'
        $rightPreview.IsHitTestVisible = $false
        [System.Windows.Controls.Canvas]::SetLeft($rightPreview, $rightPreviewX - 14)
        [System.Windows.Controls.Canvas]::SetTop($rightPreview, $rightPreviewY - 14)
        [System.Windows.Controls.Panel]::SetZIndex($rightPreview, 505)
        $script:editorLayer.Children.Add($rightPreview) | Out-Null

        $leftAdd = New-NodeAddButton
        $leftAdd.Tag = [string]$leftSegmentStart
        [System.Windows.Controls.Canvas]::SetLeft($leftAdd, [double]$point.x - 37)
        [System.Windows.Controls.Canvas]::SetTop($leftAdd, [double]$point.y - 8)
        [System.Windows.Controls.Panel]::SetZIndex($leftAdd, 520)

        $rightAdd = New-NodeAddButton
        $rightAdd.Tag = [string]$rightSegmentStart
        [System.Windows.Controls.Canvas]::SetLeft($rightAdd, [double]$point.x + 21)
        [System.Windows.Controls.Canvas]::SetTop($rightAdd, [double]$point.y - 8)
        [System.Windows.Controls.Panel]::SetZIndex($rightAdd, 520)

        $leftAdd.Add_MouseEnter({
            $leftPreview.Visibility = 'Visible'
        }.GetNewClosure())

        $leftAdd.Add_MouseLeave({
            $leftPreview.Visibility = 'Collapsed'
        }.GetNewClosure())

        $rightAdd.Add_MouseEnter({
            $rightPreview.Visibility = 'Visible'
        }.GetNewClosure())

        $rightAdd.Add_MouseLeave({
            $rightPreview.Visibility = 'Collapsed'
        }.GetNewClosure())

        $leftAdd.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)
            Insert-EditorNodeOnSegment ([int]$sender.Tag)
            $eventArgs.Handled = $true
        })

        $rightAdd.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)
            Insert-EditorNodeOnSegment ([int]$sender.Tag)
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseLeftButtonDown({
            param($sender, $eventArgs)
            Push-EditUndo
            $script:draggingEditorNode = $sender
            $script:draggingEditorIndex = [int]$sender.Tag
            [void]$sender.CaptureMouse()
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseMove({
            param($sender, $eventArgs)

            if ($null -eq $script:draggingEditorNode) { return }
            if ($script:draggingEditorNode -ne $sender) { return }
            if ($eventArgs.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }

            $position = $eventArgs.GetPosition($script:root)
            $dragIndex = [int]$script:draggingEditorIndex
            if ($dragIndex -lt 0 -or $dragIndex -ge @($script:editWorkingArea.points).Count) { return }

            $script:editWorkingArea.points[$dragIndex].x = [Math]::Round([double]$position.X, 1)
            $script:editWorkingArea.points[$dragIndex].y = [Math]::Round([double]$position.Y, 1)

            [System.Windows.Controls.Canvas]::SetLeft($sender, [double]$position.X - 14)
            [System.Windows.Controls.Canvas]::SetTop($sender, [double]$position.Y - 14)

            Render-Area
            $eventArgs.Handled = $true
        })

        $node.Add_PreviewMouseLeftButtonUp({
            param($sender, $eventArgs)

            if ($script:draggingEditorNode -eq $sender) {
                $sender.ReleaseMouseCapture()
                $script:draggingEditorNode = $null
                $script:draggingEditorIndex = -1
                Render-Area
                Render-EditorNodes
                Update-EditButtons
            }

            $eventArgs.Handled = $true
        })

        $script:editorLayer.Children.Add($leftAdd) | Out-Null
        $script:editorLayer.Children.Add($rightAdd) | Out-Null
        $script:editorLayer.Children.Add($node) | Out-Null
    }
}

