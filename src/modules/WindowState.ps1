function Get-DisplaySignature {
    (($screens = [System.Windows.Forms.Screen]::AllScreens) | ForEach-Object {
        $w = $_.WorkingArea
        '{0}:{1},{2},{3},{4}:{5}' -f $_.DeviceName, $w.Left, $w.Top, $w.Width, $w.Height, $_.Primary
    }) -join '|'
}

function Get-WindowScreen([double]$left, [double]$top, [double]$width, [double]$height) {
    $centerX = [int][Math]::Round($left + ($width * 0.5))
    $centerY = [int][Math]::Round($top + ($height * 0.5))
    [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new($centerX, $centerY))
}

function Center-WindowOnPrimaryScreen($targetWindow) {
    if ($null -eq $targetWindow) { return }

    $workArea = [System.Windows.SystemParameters]::WorkArea
    $width = if ([double]::IsNaN([double]$targetWindow.Width)) { [double]$targetWindow.ActualWidth } else { [double]$targetWindow.Width }
    $height = if ([double]::IsNaN([double]$targetWindow.Height)) { [double]$targetWindow.ActualHeight } else { [double]$targetWindow.Height }
    $targetWindow.Left = [Math]::Round([double]$workArea.Left + (([double]$workArea.Width - $width) * 0.5), 1)
    $targetWindow.Top = [Math]::Round([double]$workArea.Top + (([double]$workArea.Height - $height) * 0.5), 1)
}

function Update-DisplayAnchor {
    if ($null -eq $script:window -or $null -eq $script:config) { return }

    $width = [double]$script:window.Width
    $height = [double]$script:window.Height
    $left = [double]$script:window.Left
    $top = [double]$script:window.Top
    $screen = Get-WindowScreen $left $top $width $height
    $work = $screen.WorkingArea
    $rangeX = [Math]::Max(1.0, [double]$work.Width - $width)
    $rangeY = [Math]::Max(1.0, [double]$work.Height - $height)
    $relativeX = [Math]::Max(0.0, [Math]::Min(1.0, ($left - [double]$work.Left) / $rangeX))
    $relativeY = [Math]::Max(0.0, [Math]::Min(1.0, ($top - [double]$work.Top) / $rangeY))

    $anchor = [pscustomobject]@{
        deviceName = [string]$screen.DeviceName
        workLeft = [double]$work.Left
        workTop = [double]$work.Top
        workWidth = [double]$work.Width
        workHeight = [double]$work.Height
        relativeX = [Math]::Round($relativeX, 4)
        relativeY = [Math]::Round($relativeY, 4)
    }

    if ($null -eq $script:config.widget.PSObject.Properties['displayAnchor']) {
        $script:config.widget | Add-Member -NotePropertyName displayAnchor -NotePropertyValue $anchor
    }
    else {
        $script:config.widget.displayAnchor = $anchor
    }
}

function Save-WidgetPlacement {
    if ($null -eq $script:window -or $script:suppressPositionSave) { return }
    $script:config.widget.left = [Math]::Round([double]$script:window.Left, 1)
    $script:config.widget.top = [Math]::Round([double]$script:window.Top, 1)
    Update-DisplayAnchor
    Save-Config
}

function Get-VisibleWindowArea([double]$left, [double]$top, [double]$width, [double]$height) {
    $right = $left + $width
    $bottom = $top + $height
    $best = 0.0

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $work = $screen.WorkingArea
        $intersectionWidth = [Math]::Max(0.0, [Math]::Min($right, [double]$work.Right) - [Math]::Max($left, [double]$work.Left))
        $intersectionHeight = [Math]::Max(0.0, [Math]::Min($bottom, [double]$work.Bottom) - [Math]::Max($top, [double]$work.Top))
        $best = [Math]::Max($best, $intersectionWidth * $intersectionHeight)
    }

    $best
}

function Ensure-WidgetOnVisibleDisplay([bool]$displayChanged = $false) {
    if ($null -eq $script:window -or -not $script:positionInitialized) { return $false }

    $width = [double]$script:window.Width
    $height = [double]$script:window.Height
    $left = [double]$script:window.Left
    $top = [double]$script:window.Top
    $visibleArea = Get-VisibleWindowArea $left $top $width $height
    $minimumVisibleArea = [Math]::Min($width, 160.0) * [Math]::Min($height, 100.0)

    if ($visibleArea -ge $minimumVisibleArea) {
        if ($displayChanged) { Update-DisplayAnchor; Save-Config }
        return $false
    }

    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    if ($screens.Count -eq 0) { return $false }

    $target = @($screens | Where-Object { $_.Primary } | Select-Object -First 1)[0]
    if ($null -eq $target) { $target = $screens[0] }
    $work = $target.WorkingArea
    $rangeX = [Math]::Max(0.0, [double]$work.Width - $width)
    $rangeY = [Math]::Max(0.0, [double]$work.Height - $height)
    $relativeX = $null
    $relativeY = $null
    $anchor = $script:config.widget.displayAnchor

    if ($null -ne $anchor) {
        $relativeX = [Math]::Max(0.0, [Math]::Min(1.0, [double]$anchor.relativeX))
        $relativeY = [Math]::Max(0.0, [Math]::Min(1.0, [double]$anchor.relativeY))
    }

    if ($null -eq $relativeX -or $null -eq $relativeY) {
        $newLeft = [Math]::Max([double]$work.Left, [Math]::Min([double]$work.Right - $width, $left))
        $newTop = [Math]::Max([double]$work.Top, [Math]::Min([double]$work.Bottom - $height, $top))
    }
    else {
        $newLeft = [double]$work.Left + ($rangeX * $relativeX)
        $newTop = [double]$work.Top + ($rangeY * $relativeY)
    }

    if ($width -gt [double]$work.Width) { $newLeft = [double]$work.Left }
    if ($height -gt [double]$work.Height) { $newTop = [double]$work.Top }

    $script:suppressPositionSave = $true
    try {
        $script:window.Left = [Math]::Round($newLeft, 1)
        $script:window.Top = [Math]::Round($newTop, 1)
    }
    finally {
        $script:suppressPositionSave = $false
    }

    Save-WidgetPlacement
    $true
}

function Save-Config {
    $tempPath = "$configPath.tmp"
    $json = $script:config | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $configPath -Force
    $script:configStamp = (Get-Item $configPath).LastWriteTimeUtc
}


function Persist-WidgetScale {
    Save-Config
}

function Apply-Config {
    $windowWidth = [double]$script:config.widget.width
    $windowHeight = [double]$script:config.widget.height
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight

    $script:window.Width = $windowWidth
    $script:window.Height = $windowHeight
    $script:window.Topmost = [bool]$script:config.widget.topmost
    $script:window.Opacity = [Math]::Max(0.2, [Math]::Min(1.0, [double]$script:config.widget.opacity))

    if (-not $script:positionInitialized) {
        $script:window.Left = [double]$script:config.widget.left
        $script:window.Top = [double]$script:config.widget.top
        $script:positionInitialized = $true
    }

    $script:root.Width = $designWidth
    $script:root.Height = $designHeight
    $script:taskLayer.Width = $designWidth
    $script:taskLayer.Height = $designHeight
    $script:editorLayer.Width = $designWidth
    $script:editorLayer.Height = $designHeight

    Render-Background
    Render-Area

    $toolbarBottom = if ($null -ne $script:config.buttons.toolbarBottom) { [double]$script:config.buttons.toolbarBottom } else { 12.0 }
    $toolbarY = $designHeight - 42.0 - $toolbarBottom
    $toolbarWidth = 318.0
    $toolbarStartX = ($designWidth - $toolbarWidth) * 0.5

    [System.Windows.Controls.Canvas]::SetLeft($script:opacitySlider, $toolbarStartX)
    [System.Windows.Controls.Canvas]::SetTop($script:opacitySlider, $toolbarY + 2.0)
    [System.Windows.Controls.Canvas]::SetLeft($script:opacityLabel, $toolbarStartX + 114.0)
    [System.Windows.Controls.Canvas]::SetTop($script:opacityLabel, $toolbarY + 9.0)
    [System.Windows.Controls.Canvas]::SetLeft($script:editButton, $toolbarStartX + 154.0)
    [System.Windows.Controls.Canvas]::SetTop($script:editButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:resizeButton, $toolbarStartX + 194.0)
    [System.Windows.Controls.Canvas]::SetTop($script:resizeButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:minimizeButton, $toolbarStartX + 234.0)
    [System.Windows.Controls.Canvas]::SetTop($script:minimizeButton, $toolbarY)
    [System.Windows.Controls.Canvas]::SetLeft($script:closeButton, $toolbarStartX + 274.0)
    [System.Windows.Controls.Canvas]::SetTop($script:closeButton, $toolbarY)

    $script:opacitySliderUpdating = $true
    $script:opacitySlider.Value = [double]$script:config.widget.opacity * 100.0
    $script:opacityLabel.Text = ([int][Math]::Round([double]$script:opacitySlider.Value)).ToString() + '%'
    $script:opacitySliderUpdating = $false

    $addSize = if ($null -ne $script:config.buttons.addSize) { [double]$script:config.buttons.addSize } else { 44.0 }
    $script:addButton.Width = $addSize
    $script:addButton.Height = $addSize
    $script:profileAccessory.Width = $addSize
    $script:profileAccessory.Height = $addSize

    $customAddX = Get-ActiveAddX
    $customAddY = Get-ActiveAddY
    $maxAddY = $toolbarY - $addSize - 10.0

    if ($null -eq $customAddX -or $null -eq $customAddY) {
        $customAddX = ($designWidth - $addSize) * 0.5
        $customAddY = 120.0
    }

    $safeX = [Math]::Max(0.0, [Math]::Min($designWidth - $addSize, [double]$customAddX))
    $safeY = [Math]::Max(0.0, [Math]::Min($maxAddY, [double]$customAddY))

    $centerX = $safeX + ($addSize * 0.5)
    $centerY = $safeY + ($addSize * 0.5)

    if (Point-InPolygon $centerX $centerY) {
        $safeX = ($designWidth - $addSize) * 0.5
        $safeY = 90.0

        while ((Point-InPolygon ($safeX + ($addSize * 0.5)) ($safeY + ($addSize * 0.5))) -and $safeY -gt 8.0) {
            $safeY -= 10.0
        }

        if (Point-InPolygon ($safeX + ($addSize * 0.5)) ($safeY + ($addSize * 0.5))) {
            $safeX = 12.0
            $safeY = 90.0
        }

        if ($script:editMode) {
            $script:editAddX = [Math]::Round($safeX, 1)
            $script:editAddY = [Math]::Round($safeY, 1)
        }
        else {
            $script:config.buttons.addX = [Math]::Round($safeX, 1)
            $script:config.buttons.addY = [Math]::Round($safeY, 1)
        }
    }

    [System.Windows.Controls.Canvas]::SetLeft($script:addButton, $safeX)
    [System.Windows.Controls.Canvas]::SetTop($script:addButton, $safeY)
    [System.Windows.Controls.Canvas]::SetLeft($script:profileAccessory, $safeX)
    [System.Windows.Controls.Canvas]::SetTop($script:profileAccessory, $safeY)

    [System.Windows.Controls.Canvas]::SetLeft($script:addSizeSlider, [Math]::Min($designWidth - 108.0, $safeX + $addSize + 8.0))
    [System.Windows.Controls.Canvas]::SetTop($script:addSizeSlider, $safeY + (($addSize - 30.0) * 0.5))

    $script:addSizeSliderUpdating = $true
    $script:addSizeSlider.Value = $addSize
    $script:addSizeSliderUpdating = $false
    $script:addSizeSlider.Visibility = if ($script:editMode) { 'Visible' } else { 'Collapsed' }

    $editY = 50.0
    [System.Windows.Controls.Canvas]::SetLeft($script:undoButton, 92.0)
    [System.Windows.Controls.Canvas]::SetTop($script:undoButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:clearButton, 142.0)
    [System.Windows.Controls.Canvas]::SetTop($script:clearButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:borderToggle, 192.0)
    [System.Windows.Controls.Canvas]::SetTop($script:borderToggle, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:cancelEditButton, 242.0)
    [System.Windows.Controls.Canvas]::SetTop($script:cancelEditButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:backgroundButton, 292.0)
    [System.Windows.Controls.Canvas]::SetTop($script:backgroundButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:gridButton, 342.0)
    [System.Windows.Controls.Canvas]::SetTop($script:gridButton, $editY)
    [System.Windows.Controls.Canvas]::SetLeft($script:startupToggle, 392.0)
    [System.Windows.Controls.Canvas]::SetTop($script:startupToggle, $editY - 10.0)

    $script:opacitySlider.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
    $script:opacityLabel.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
    $script:resizeButton.Visibility = if ($script:editMode) { 'Collapsed' } else { 'Visible' }
}

function Reload-Files {
    $configStamp = (Get-Item $configPath).LastWriteTimeUtc
    $areaStamp = (Get-Item $areaPath).LastWriteTimeUtc
    $tasksStamp = (Get-Item $tasksPath).LastWriteTimeUtc

    if ($configStamp -ne $script:configStamp) {
        $script:config = Read-JsonFile $configPath
        $script:configStamp = $configStamp
        Apply-Config
        Render-Background

        if ($null -ne $script:reloadTimer) {
            $script:reloadTimer.Interval = [TimeSpan]::FromSeconds([Math]::Max(5, [double]$script:config.refreshSeconds))
        }
    }

    if ($areaStamp -ne $script:areaStamp) {
        $script:area = Read-JsonFile $areaPath
        $script:areaStamp = $areaStamp
        Apply-Config
        Render-Tasks
        Render-EditorNodes
    }

    if ($tasksStamp -ne $script:tasksStamp) {
        $script:tasks = @(Read-Tasks)
        $script:tasksStamp = $tasksStamp
        Render-Tasks
    }
}
