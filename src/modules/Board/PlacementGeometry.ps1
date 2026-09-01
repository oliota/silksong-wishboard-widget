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

function Find-FreePositionCore([double]$size, [double]$ringStep = 4.0) {
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

