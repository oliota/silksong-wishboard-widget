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
    $script:editButton.Visibility = 'Visible'
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

