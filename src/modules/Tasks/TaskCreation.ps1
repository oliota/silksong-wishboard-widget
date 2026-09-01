function Open-AddTaskPanel {
    if ($script:editMode) { return }
    if ($null -eq $script:addPanel) { return }
    if ($null -eq $script:addTitleBox) { return }
    if ($null -eq $script:addDescriptionBox) { return }

    $script:addTitleBox.Text = ''
    $script:addDescriptionBox.Text = ''
    $script:addSelectedIcon = Get-RandomTaskIconId
    $script:pendingNewTask = $null
    $script:addBody.Visibility = 'Visible'
    $script:addSavingPanel.Visibility = 'Collapsed'
    $script:addCreateButton.IsEnabled = $true
    $script:addCloseButton.IsEnabled = $true

    Populate-AddIconGrid
    Refresh-AddIconSelection

    $script:addPanel.Visibility = 'Visible'
    if ($null -ne $script:addWindow) {
        $script:addWindow.Show()
        Center-WindowOnPrimaryScreen $script:addWindow
        $script:addWindow.Activate() | Out-Null
    }
    $script:addTitleBox.Focus() | Out-Null
}

function Close-AddTaskPanel {
    if ($null -ne $script:addFailureTimer) {
        $script:addFailureTimer.Stop()
        $script:addFailureTimer = $null
    }
    $script:pendingNewTask = $null
    if ($null -ne $script:addPanel) {
        $script:addPanel.Visibility = 'Collapsed'
    }
    if ($null -ne $script:addWindow -and $script:addWindow.IsVisible) {
        $script:addWindow.Hide()
    }
}

function Show-AddFailure([string]$message) {
    $script:addSavingTitleText.Text = 'COULD NOT ADD ITEM'
    $script:addSavingStatusText.Text = $message
    $script:addFailureTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:addFailureTimer.Interval = [TimeSpan]::FromMilliseconds(2600)
    $script:addFailureTimer.Add_Tick({
        $script:addFailureTimer.Stop()
        $script:addFailureTimer = $null
        Close-AddTaskPanel
    })
    $script:addFailureTimer.Start()
}

function Commit-NewTask($newTask) {
    try {
        $script:tasks = @($script:tasks) + @($newTask)
        Save-Tasks
        Render-Tasks
        Close-AddTaskPanel
        Request-PositionCacheRefill 2100
    }
    catch {
        $failedTaskId = [string]$newTask.id
        $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $failedTaskId })
        Show-AddFailure 'The item could not be added. Please try again.'
    }
}

function Complete-NewTask {
    $newTask = $script:pendingNewTask
    if ($null -eq $newTask) { return }

    try {
        $size = [double]$script:area.taskSize
        $position = @(Find-FreePosition $size)

        if ($position.Count -lt 2) {
            $smile = [char]::ConvertFromUtf32(0x1F60A)
            Show-AddFailure "No space is available on the board. Taking on too many tasks at once is not responsible.`nFinish your tasks before creating more. $smile"
            return
        }

        $newTask | Add-Member -NotePropertyName x -NotePropertyValue ([Math]::Round([double]$position[0], 1)) -Force
        $newTask | Add-Member -NotePropertyName y -NotePropertyValue ([Math]::Round([double]$position[1], 1)) -Force
        Start-TaskPlacementAnimation $newTask $position $size {
            param($task)
            Commit-NewTask $task
        }
    }
    catch {
        $failedTaskId = [string]$newTask.id
        $script:tasks = @($script:tasks | Where-Object { [string]$_.id -ne $failedTaskId })
        Show-AddFailure 'The item could not be added. Please try again.'
    }
}

function Create-NewTask {
    if ($null -eq $script:addTitleBox -or $null -eq $script:addDescriptionBox) { return }
    if (-not $script:addCreateButton.IsEnabled) { return }

    $title = $script:addTitleBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { return }

    $iconId = [string]$script:addSelectedIcon

    if ([string]::IsNullOrWhiteSpace($iconId) -or $null -eq (Get-IconEntry $iconId)) {
        $iconId = Get-DefaultTaskIconId
    }

    if ([string]::IsNullOrWhiteSpace([string]$iconId)) { return }

    $newTask = [pscustomobject][ordered]@{
        id = 'task-' + [Guid]::NewGuid().ToString('N')
        title = $title
        description = $script:addDescriptionBox.Text.Trim()
        icon = [string]$iconId
        isNew = $true
        createdAt = [DateTime]::Now.ToString('o')
    }

    Add-TaskBadgeMetadata $newTask $true
    $script:pendingNewTask = $newTask
    $script:addBody.Visibility = 'Collapsed'
    $script:addSavingPanel.Visibility = 'Visible'
    $script:addSavingVisualHost.Child = New-TaskBadgeVisual $newTask 92
    $script:addSavingTitleText.Text = [string]$newTask.title
    $script:addSavingStatusText.Text = 'SAVING...'
    $script:addCreateButton.IsEnabled = $false
    $script:addCloseButton.IsEnabled = $false
    $script:window.Dispatcher.BeginInvoke(
        [System.Action]{ Complete-NewTask },
        [System.Windows.Threading.DispatcherPriority]::ContextIdle
    ) | Out-Null
}

