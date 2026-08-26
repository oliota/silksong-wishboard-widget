function Copy-JsonObject($value) {
    if ($null -eq $value) { return $null }
    $value | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Read-DefaultArea {
    if (Test-Path $defaultAreaPath) {
        return Copy-JsonObject (Read-JsonFile $defaultAreaPath)
    }

    return New-FactoryArea
}

function New-FactoryArea {
    $cx = 260.0
    $cy = 255.0
    $radius = 150.0
    $points = @()

    for ($i = 0; $i -lt 10; $i++) {
        $angle = (-90.0 + ($i * 36.0)) * [Math]::PI / 180.0
        $points += [pscustomobject][ordered]@{
            x = [Math]::Round($cx + ([Math]::Cos($angle) * $radius), 1)
            y = [Math]::Round($cy + ([Math]::Sin($angle) * $radius), 1)
        }
    }

    [pscustomobject][ordered]@{
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

function Get-ActiveArea {
    if ($script:editMode -and $null -ne $script:editWorkingArea) {
        return $script:editWorkingArea
    }
    $script:area
}

function Update-EditButtons {
    if ($null -eq $script:undoButton) { return }

    $script:undoButton.Visibility = if ($script:editMode -and $script:editUndoStack.Count -gt 0) { 'Visible' } else { 'Collapsed' }

    if ($script:editMode -and $null -ne $script:editWorkingArea) {
        $enabled = [bool]$script:editWorkingArea.borderVisible
        $script:borderToggle.Content = if ($enabled) { 'LINE ON' } else { 'LINE OFF' }
        $script:borderToggle.ToolTip = if ($enabled) { 'Hide Border After Save' } else { 'Show Border After Save' }
        $script:borderToggle.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString(
            $(if ($enabled) { '#CC198754' } else { '#CCD93025' })
        )
        Update-StartupButton
    }
}

function Push-EditUndo {
    if (-not $script:editMode -or $null -eq $script:editWorkingArea) { return }
    $script:editUndoStack.Push((New-EditCheckpoint))
    Update-EditButtons
}

function Cancel-EditSession {
    if (-not $script:editMode) { return }
    Close-EditSettingsWindow

    if ($null -ne $script:draggingEditorNode) {
        $script:draggingEditorNode.ReleaseMouseCapture()
        $script:draggingEditorNode = $null
        $script:draggingEditorIndex = -1
    }

    $script:editMode = $false
    $script:editWorkingArea = $null
    $script:editUndoStack.Clear()
    $script:editBackgroundFile = $null
    $script:editBackgroundScale = [double]$script:editSnapshotBackgroundScale
    $script:editBackgroundOffsetX = [double]$script:editSnapshotBackgroundOffsetX
    $script:editBackgroundOffsetY = [double]$script:editSnapshotBackgroundOffsetY
    $script:editAddX = $script:editSnapshotAddX
    $script:editAddY = $script:editSnapshotAddY
    if ($null -ne $script:editSnapshotAddSize) {
        $script:config.buttons.addSize = $script:editSnapshotAddSize
    }
    $script:editGridColumns = [int]$script:editSnapshotGridColumns
    $script:editSnapshotBackgroundFile = $null
    $script:pendingDeletedBackgroundIds.Clear()

    if ($null -ne $script:editSnapshot) {
        $script:area = Copy-JsonObject $script:editSnapshot
    }

    $script:editSnapshot = $null
    Set-EditButtonVisual $false
    $script:undoButton.Visibility = 'Collapsed'
    $script:clearButton.Visibility = 'Collapsed'
    $script:borderToggle.Visibility = 'Collapsed'
    $script:startupToggle.Visibility = 'Collapsed'
    
    $script:backgroundPanel.Visibility = 'Collapsed'
    $script:gridPanel.Visibility = 'Collapsed'
    $script:taskLayer.IsHitTestVisible = $true
    $script:editorLayer.IsHitTestVisible = $false

    Apply-Config
    Render-Background
    Render-Area
    Render-EditorNodes
    Render-Tasks
}

function Get-AreaPoints {
    $activeArea = Get-ActiveArea
    $points = New-Object System.Collections.Generic.List[System.Windows.Point]
    foreach ($p in @($activeArea.points)) {
        $points.Add([System.Windows.Point]::new([double]$p.x, [double]$p.y))
    }
    $points
}

function Point-InPolygon([double]$x, [double]$y) {
    $points = @(Get-AreaPoints)
    $count = [int]$points.Count
    if ($count -lt 3) { return $false }

    $inside = $false
    $j = $count - 1

    for ($i = 0; $i -lt $count; $i++) {
        $xi = [double]$points[$i].X
        $yi = [double]$points[$i].Y
        $xj = [double]$points[$j].X
        $yj = [double]$points[$j].Y

        if (($yi -gt $y) -ne ($yj -gt $y)) {
            $denominator = [double]($yj - $yi)

            if ([Math]::Abs($denominator) -gt 0.000001) {
                $ratio = [double](($y - $yi) * (1.0 / $denominator))
                $intersectionX = [double]($xi + (($xj - $xi) * $ratio))

                if ($x -lt $intersectionX) {
                    $inside = -not $inside
                }
            }
        }

        $j = $i
    }

    return [bool]$inside
}

function Test-TaskInsidePolygon([double]$x, [double]$y, [double]$size) {
    $half = [double]($size * 0.5)
    $cx = [double]($x + $half)
    $cy = [double]($y + $half)
    $radius = [double][Math]::Max(1.0, ($half - 2.0))
    $diagonal = [double]($radius * 0.70710678118)

    $samples = @(
        [pscustomobject]@{ X = $cx; Y = $cy },
        [pscustomobject]@{ X = [double]($cx - $radius); Y = $cy },
        [pscustomobject]@{ X = [double]($cx + $radius); Y = $cy },
        [pscustomobject]@{ X = $cx; Y = [double]($cy - $radius) },
        [pscustomobject]@{ X = $cx; Y = [double]($cy + $radius) },
        [pscustomobject]@{ X = [double]($cx - $diagonal); Y = [double]($cy - $diagonal) },
        [pscustomobject]@{ X = [double]($cx + $diagonal); Y = [double]($cy - $diagonal) },
        [pscustomobject]@{ X = [double]($cx - $diagonal); Y = [double]($cy + $diagonal) },
        [pscustomobject]@{ X = [double]($cx + $diagonal); Y = [double]($cy + $diagonal) }
    )

    foreach ($sample in $samples) {
        $sampleX = [double]$sample.X
        $sampleY = [double]$sample.Y

        if (-not (Point-InPolygon $sampleX $sampleY)) {
            return $false
        }
    }

    return $true
}

function Test-TaskCollision(
    [string]$movingTaskId,
    [double]$x,
    [double]$y,
    [double]$size
) {
    $margin = if ($null -ne $script:config.tasks.collisionMargin) {
        [double]$script:config.tasks.collisionMargin
    }
    else {
        2.0
    }

    $radius = ($size * 0.5) + ($margin * 0.5)
    $movingCenterX = $x + ($size * 0.5)
    $movingCenterY = $y + ($size * 0.5)
    $minimumDistance = $radius * 2.0
    $minimumDistanceSquared = $minimumDistance * $minimumDistance

    foreach ($task in @($script:tasks)) {
        if ([string]$task.id -eq $movingTaskId) { continue }

        $otherCenterX = [double]$task.x + ($size * 0.5)
        $otherCenterY = [double]$task.y + ($size * 0.5)
        $dx = $movingCenterX - $otherCenterX
        $dy = $movingCenterY - $otherCenterY
        $distanceSquared = ($dx * $dx) + ($dy * $dy)

        if ($distanceSquared -lt $minimumDistanceSquared) {
            return $true
        }
    }

    return $false
}

function Test-TaskPlacementValid(
    [string]$movingTaskId,
    [double]$x,
    [double]$y,
    [double]$size
) {
    if (-not (Test-TaskInsidePolygon $x $y $size)) {
        return $false
    }

    if (Test-TaskCollision $movingTaskId $x $y $size) {
        return $false
    }

    return $true
}

function Find-TaskSlidePosition(
    [string]$movingTaskId,
    [double]$fromX,
    [double]$fromY,
    [double]$targetX,
    [double]$targetY,
    [double]$size
) {
    if (Test-TaskPlacementValid $movingTaskId $targetX $targetY $size) {
        return [pscustomobject]@{ X = $targetX; Y = $targetY }
    }

    $dx = $targetX - $fromX
    $dy = $targetY - $fromY
    $length = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))

    if ($length -lt 0.0001) {
        return [pscustomobject]@{ X = $fromX; Y = $fromY }
    }

    $normalX = -$dy / $length
    $normalY = $dx / $length
    $best = $null
    $bestScore = [double]::PositiveInfinity

    foreach ($direction in @(-1.0, 1.0)) {
        foreach ($offset in @(4.0, 8.0, 12.0, 18.0, 24.0, 32.0, 42.0)) {
            $candidateX = $targetX + ($normalX * $offset * $direction)
            $candidateY = $targetY + ($normalY * $offset * $direction)

            if (-not (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size)) {
                continue
            }

            $scoreX = $candidateX - $targetX
            $scoreY = $candidateY - $targetY
            $score = ($scoreX * $scoreX) + ($scoreY * $scoreY)

            if ($score -lt $bestScore) {
                $bestScore = $score
                $best = [pscustomobject]@{
                    X = $candidateX
                    Y = $candidateY
                }
            }
        }
    }

    if ($null -ne $best) {
        return $best
    }

    $low = 0.0
    $high = 1.0
    $bestX = $fromX
    $bestY = $fromY

    for ($i = 0; $i -lt 18; $i++) {
        $mid = ($low + $high) * 0.5
        $candidateX = $fromX + (($targetX - $fromX) * $mid)
        $candidateY = $fromY + (($targetY - $fromY) * $mid)

        if (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size) {
            $bestX = $candidateX
            $bestY = $candidateY
            $low = $mid
        }
        else {
            $high = $mid
        }
    }

    return [pscustomobject]@{
        X = $bestX
        Y = $bestY
    }
}

function Constrain-TaskDrag(
    [string]$movingTaskId,
    [double]$fromX,
    [double]$fromY,
    [double]$targetX,
    [double]$targetY,
    [double]$size
) {
    if (Test-TaskPlacementValid $movingTaskId $targetX $targetY $size) {
        return [pscustomobject]@{ X = $targetX; Y = $targetY }
    }

    if (Test-TaskInsidePolygon $targetX $targetY $size) {
        return Find-TaskSlidePosition $movingTaskId $fromX $fromY $targetX $targetY $size
    }

    if (-not (Test-TaskInsidePolygon $fromX $fromY $size)) {
        $fallback = Clamp-ToPolygon $fromX $fromY $size
        $fromX = [double]$fallback.X
        $fromY = [double]$fallback.Y
    }

    $low = 0.0
    $high = 1.0
    $bestX = $fromX
    $bestY = $fromY

    for ($i = 0; $i -lt 18; $i++) {
        $mid = ($low + $high) * 0.5
        $candidateX = $fromX + (($targetX - $fromX) * $mid)
        $candidateY = $fromY + (($targetY - $fromY) * $mid)

        if (Test-TaskPlacementValid $movingTaskId $candidateX $candidateY $size) {
            $bestX = $candidateX
            $bestY = $candidateY
            $low = $mid
        }
        else {
            $high = $mid
        }
    }

    return [pscustomobject]@{ X = $bestX; Y = $bestY }
}

function Clamp-ToPolygon([double]$x, [double]$y, [double]$size) {
    $points = @(Get-AreaPoints)
    $count = [int]$points.Count

    if ($count -lt 3) {
        return [pscustomobject]@{ X = [double]$x; Y = [double]$y }
    }

    $half = [double]($size * 0.5)
    $cx = [double]($x + $half)
    $cy = [double]($y + $half)

    if (Point-InPolygon $cx $cy) {
        return [pscustomobject]@{ X = [double]$x; Y = [double]$y }
    }

    $sumX = 0.0
    $sumY = 0.0

    foreach ($point in $points) {
        $sumX += [double]$point.X
        $sumY += [double]$point.Y
    }

    $inverseCount = [double](1.0 / [double]$count)
    $targetX = [double]($sumX * $inverseCount)
    $targetY = [double]($sumY * $inverseCount)

    for ($step = 1; $step -le 100; $step++) {
        $t = [double]($step * 0.01)
        $candidateX = [double]($cx + (($targetX - $cx) * $t))
        $candidateY = [double]($cy + (($targetY - $cy) * $t))

        if (Point-InPolygon $candidateX $candidateY) {
            return [pscustomobject]@{
                X = [double]($candidateX - $half)
                Y = [double]($candidateY - $half)
            }
        }
    }

    return [pscustomobject]@{
        X = [double]($targetX - $half)
        Y = [double]($targetY - $half)
    }
}


function Normalize-Tasks-ToArea {
    $activeArea = Get-ActiveArea
    $size = [double]$activeArea.taskSize
    $half = [double]($size * 0.5)
    $changed = $false

    foreach ($task in @($script:tasks)) {
        $taskX = [double]$task.x
        $taskY = [double]$task.y
        $centerX = [double]($taskX + $half)
        $centerY = [double]($taskY + $half)

        if (-not (Point-InPolygon $centerX $centerY)) {
            $position = Clamp-ToPolygon $taskX $taskY $size
            $task.x = [Math]::Round([double]$position.X, 1)
            $task.y = [Math]::Round([double]$position.Y, 1)
            $changed = $true
        }
    }

    if ($changed) {
        Save-Tasks
        Load-All
    }

    Render-Tasks
}

function Find-FreePosition([double]$size) {
    $points = @(Get-AreaPoints)
    if ($points.Count -lt 3) { return $null }

    $minX = ($points | Measure-Object -Property X -Minimum).Minimum
    $maxX = ($points | Measure-Object -Property X -Maximum).Maximum
    $minY = ($points | Measure-Object -Property Y -Minimum).Minimum
    $maxY = ($points | Measure-Object -Property Y -Maximum).Maximum
    $centerX = ($points | Measure-Object -Property X -Average).Average
    $centerY = ($points | Measure-Object -Property Y -Average).Average
    $maxRadius = [Math]::Sqrt(
        [Math]::Pow([Math]::Max([Math]::Abs($centerX - $minX), [Math]::Abs($maxX - $centerX)), 2) +
        [Math]::Pow([Math]::Max([Math]::Abs($centerY - $minY), [Math]::Abs($maxY - $centerY)), 2)
    )
    $ringStep = 4.0

    for ($radius = 0.0; $radius -le $maxRadius; $radius += $ringStep) {
        $samples = if ($radius -lt 0.1) { 1 } else { [Math]::Max(12, [int][Math]::Ceiling((2.0 * [Math]::PI * $radius) / $ringStep)) }
        for ($index = 0; $index -lt $samples; $index++) {
            $angle = if ($samples -eq 1) { 0.0 } else { (2.0 * [Math]::PI * $index) / $samples }
            $x = $centerX + ([Math]::Cos($angle) * $radius) - ($size * 0.5)
            $y = $centerY + ([Math]::Sin($angle) * $radius) - ($size * 0.5)
            if (Test-TaskPlacementValid '' $x $y $size) {
                return @([Math]::Round($x, 1), [Math]::Round($y, 1))
            }
        }
    }

    $null
}

function Save-Area {
    param($AreaToSave = $null)

    $target = if ($null -ne $AreaToSave) { $AreaToSave } else { $script:area }
    $tempPath = "$areaPath.tmp"
    $json = $target | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $areaPath -Force
    $script:areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
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
