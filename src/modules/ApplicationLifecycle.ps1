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
        return $true
    }

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
    if (Get-Command Stop-TaskPlacementAnimation -ErrorAction SilentlyContinue) {
        Stop-TaskPlacementAnimation
    }

    if ($null -ne $script:reloadTimer) {
        $script:reloadTimer.Stop()
    }

    if ($null -ne $script:desktopTimer) {
        $script:desktopTimer.Stop()
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
