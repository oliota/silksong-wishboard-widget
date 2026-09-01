function Continue-CalendarSummonsQueue {
    Start-WidgetTimer 'Summons.Queue' 180 ({
        Stop-WidgetTimer 'Summons.Queue'
        Start-NextCalendarSummonsTask
    }.GetNewClosure()) | Out-Null
}

function Start-NextCalendarSummonsTask {
    if ($null -eq $script:calendarSummonsQueue -or $script:calendarSummonsQueue.Count -eq 0) { Start-CalendarSummonsDeparture; return }
    $entry = $script:calendarSummonsQueue.Dequeue()
    $script:tasks = @($script:tasks) + @($entry.Task)
    Save-Tasks
    Start-TaskPlacementAnimation $entry.Task $entry.Position $entry.Size {
        param($createdTask)
        Render-Tasks
        Continue-CalendarSummonsQueue
    } $script:calendarSummonsPin 0.45
}

function Start-CalendarSummonsCreation {
    if (-not $script:calendarSummonsActive -or $null -eq $script:calendarSummonsPin) { return }
    Stop-WidgetTimer 'Summons.Arrival'
    $script:calendarSummonsPin.IsEnabled = $false
    if ($null -ne $script:calendarSummonsGlow) { $script:root.Children.Remove($script:calendarSummonsGlow); $script:calendarSummonsGlow = $null }
    $script:calendarSummonsPin.Effect = $null
    Set-CalendarSummonsImage $script:calendarSummonsPinImage 'craw_court_summons_pin0007.png'
    $script:calendarSummonsQueue = [System.Collections.Queue]::new()
    $originalTasks = @($script:tasks)
    foreach ($event in @($script:calendarSummonsEvents)) {
        if ($null -ne (Get-TaskById ('calendar-' + [string]$event.id))) { continue }
        $task = New-GoogleCalendarTask $event
        $size = [double]$script:area.taskSize
        $position = @(Find-FreePosition $size)
        if ($position.Count -lt 2) { continue }
        $task | Add-Member -NotePropertyName x -NotePropertyValue ([Math]::Round([double]$position[0], 1)) -Force
        $task | Add-Member -NotePropertyName y -NotePropertyValue ([Math]::Round([double]$position[1], 1)) -Force
        $script:calendarSummonsQueue.Enqueue([pscustomobject]@{ Task = $task; Position = [double[]]$position; Size = $size })
        $script:tasks = @($script:tasks) + @($task)
    }
    $script:tasks = $originalTasks
    Start-NextCalendarSummonsTask
}
