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

