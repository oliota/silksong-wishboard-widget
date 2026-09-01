function Initialize-WidgetLog {
    $script:widgetLogPath = Join-Path $base 'widget.log'
    [System.IO.File]::WriteAllText($script:widgetLogPath, '', [System.Text.UTF8Encoding]::new($false))
    Write-WidgetLog 'START' 'Widget process starting.'
}

function Write-WidgetLog([string]$event, [string]$message) {
    if ([string]::IsNullOrWhiteSpace([string]$script:widgetLogPath)) { return }
    $line = '{0:yyyy-MM-dd HH:mm:ss.fff} [{1}] {2}' -f (Get-Date), $event, $message
    try {
        Add-Content -LiteralPath $script:widgetLogPath -Value $line -ErrorAction SilentlyContinue
    }
    catch {
    }
}

function Enter-ApplicationInstance {
    $name = 'Local\SilksongWishBoardWidget'
    $script:instanceMutex = [System.Threading.Mutex]::new($false, $name)

    try {
        $script:ownsInstanceMutex = $script:instanceMutex.WaitOne(0, $false)
    }
    catch [System.Threading.AbandonedMutexException] {
        $script:ownsInstanceMutex = $true
    }

    if ($script:ownsInstanceMutex) {
        Write-WidgetLog 'INSTANCE' 'Application instance acquired.'
        return $true
    }

    Write-WidgetLog 'INSTANCE' 'Another application instance is already running.'
    $script:instanceMutex.Dispose()
    $script:instanceMutex = $null
    return $false
}

function Exit-ApplicationInstance {
    if ($null -eq $script:instanceMutex) {
        return
    }

    if ($script:ownsInstanceMutex) {
        try {
            $script:instanceMutex.ReleaseMutex()
        }
        catch [System.ApplicationException] {
        }
    }

    $script:ownsInstanceMutex = $false
    $script:instanceMutex.Dispose()
    $script:instanceMutex = $null
}

function Dispose-ApplicationResources {
    if (Get-Command Stop-AllWidgetTimers -ErrorAction SilentlyContinue) {
        Stop-AllWidgetTimers
    }

    if (Get-Command Stop-TaskPlacementAnimation -ErrorAction SilentlyContinue) {
        Stop-TaskPlacementAnimation
    }

    if ($null -ne $script:reloadTimer) {
        $script:reloadTimer.Stop()
    }

    if ($null -ne $script:desktopTimer) {
        $script:desktopTimer.Stop()
    }

    if ($null -ne $script:calendarTimer) {
        $script:calendarTimer.Stop()
    }

    if ($null -ne $script:calendarConnectionTimer) {
        $script:calendarConnectionTimer.Stop()
        $script:calendarConnectionTimer = $null
    }

    if ($null -ne $script:tray) {
        $script:tray.Visible = $false
        $script:tray.Dispose()
        $script:tray = $null
    }

    if ($null -ne $script:trayIcon) {
        $script:trayIcon.Dispose()
        $script:trayIcon = $null
    }

    if ($null -ne $script:activeDetailWindow) {
        $script:activeDetailWindow.Close()
        $script:activeDetailWindow = $null
    }

    if ($null -ne $script:addWindow) {
        $script:addWindow.Close()
        $script:addWindow = $null
    }

    if ($null -ne $script:editSettingsWindow) {
        $script:editSettingsWindow.Close()
        $script:editSettingsWindow = $null
    }
}
