function Save-PositionCache {
    if ([string]::IsNullOrWhiteSpace([string]$positionCachePath)) { return }
    $payload = [ordered]@{ positions = @($script:positionCache) }
    $tempPath = "$positionCachePath.tmp"
    [System.IO.File]::WriteAllText($tempPath, ($payload | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $positionCachePath -Force
}

function Get-ValidCachedPositions([double]$size) {
    $valid = [System.Collections.ArrayList]::new()
    $reserved = [System.Collections.ArrayList]::new()
    $margin = if ($null -ne $script:config.tasks.collisionMargin) { [double]$script:config.tasks.collisionMargin } else { 2.0 }
    $minimumDistanceSquared = [Math]::Pow($size + $margin, 2)
    foreach ($entry in @($script:positionCache)) {
        if ([Math]::Abs([double]$entry.size - $size) -gt 0.01) { continue }
        $x = [double]$entry.x
        $y = [double]$entry.y
        if (-not (Test-TaskPlacementValid '' $x $y $size)) { continue }
        $overlap = $false
        foreach ($position in @($reserved)) {
            $dx = ($x + ($size * 0.5)) - ([double]$position.x + ($size * 0.5))
            $dy = ($y + ($size * 0.5)) - ([double]$position.y + ($size * 0.5))
            if ((($dx * $dx) + ($dy * $dy)) -lt $minimumDistanceSquared) { $overlap = $true; break }
        }
        if ($overlap) { continue }
        $cached = [pscustomobject][ordered]@{ x = $x; y = $y; size = $size }
        $valid.Add($cached) | Out-Null
        $reserved.Add($cached) | Out-Null
        if ($valid.Count -ge 5) { break }
    }
    @($valid)
}

function Update-PositionCache([double]$size) {
    $script:positionCache = @(Get-ValidCachedPositions $size)
    if ($script:positionCache.Count -ge 5) { return }
    $originalTasks = @($script:tasks)
    try {
        foreach ($entry in @($script:positionCache)) {
            $script:tasks = @($script:tasks) + @([pscustomobject]@{ id = [Guid]::NewGuid().ToString('N'); x = [double]$entry.x; y = [double]$entry.y })
        }
        $position = @(Find-FreePositionCore $size 14.0)
        if ($position.Count -ge 2) {
            $script:positionCache = @($script:positionCache) + @([pscustomobject][ordered]@{ x = [double]$position[0]; y = [double]$position[1]; size = $size })
        }
    }
    finally {
        $script:tasks = $originalTasks
    }
    Save-PositionCache
}

function Initialize-PositionCache {
    $script:positionCache = @()
    if (Test-Path -LiteralPath $positionCachePath) {
        try { $script:positionCache = @((Read-JsonFile $positionCachePath).positions) } catch { $script:positionCache = @() }
    }
    $script:positionCacheTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:positionCacheTimer.Interval = [TimeSpan]::FromMinutes(1)
    $script:positionCacheTimer.Add_Tick({
        if ($script:exiting -or $script:editMode -or $null -ne $script:taskAnimationFrameTimer) { return }
        try {
            Update-PositionCache ([double]$script:area.taskSize)
        } catch {}
    })
    $script:positionCacheTimer.Start()
}

function Find-FreePosition([double]$size) {
    if ($null -eq $script:positionCache) { $script:positionCache = @() }
    $script:positionCache = @(Get-ValidCachedPositions $size)
    if ($script:positionCache.Count -eq 0) { Update-PositionCache $size }
    if ($script:positionCache.Count -eq 0) { return $null }
    $entry = $script:positionCache[0]
    $script:positionCache = @($script:positionCache | Select-Object -Skip 1)
    Save-PositionCache
    @([double]$entry.x, [double]$entry.y)
}

function Request-PositionCacheRefill([int]$delayMilliseconds = 0) {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds([Math]::Max(1, $delayMilliseconds))
    $timer.Add_Tick({
        $timer.Stop()
        if ($script:exiting -or $script:editMode -or $null -ne $script:taskAnimationFrameTimer) { return }
        try { Update-PositionCache ([double]$script:area.taskSize) } catch {}
    }.GetNewClosure())
    $timer.Start()
}

function Add-PositionToCache([double]$x, [double]$y, [double]$size) {
    if ($null -eq $script:positionCache) { $script:positionCache = @() }
    $script:positionCache = @(Get-ValidCachedPositions $size)
    if ($script:positionCache.Count -ge 5 -or -not (Test-TaskPlacementValid '' $x $y $size)) { return }
    $script:positionCache = @([pscustomobject][ordered]@{ x = $x; y = $y; size = $size }) + @($script:positionCache)
    $script:positionCache = @(Get-ValidCachedPositions $size)
    Save-PositionCache
}

