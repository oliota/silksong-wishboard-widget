function Initialize-TimerRegistry {
    $script:timerRegistry = @{}
}

function Get-WidgetTimer([string]$name) {
    if ($null -eq $script:timerRegistry -or -not $script:timerRegistry.ContainsKey($name)) { return $null }
    $script:timerRegistry[$name]
}

function Stop-WidgetTimer([string]$name) {
    $timer = Get-WidgetTimer $name
    if ($null -ne $timer) { $timer.Stop() }
    if ($null -ne $script:timerRegistry) { $script:timerRegistry.Remove($name) }
}

function Start-WidgetTimer([string]$name, [int]$intervalMilliseconds, [scriptblock]$tick) {
    Stop-WidgetTimer $name
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds([Math]::Max(1, $intervalMilliseconds))
    $timer.Add_Tick($tick)
    $script:timerRegistry[$name] = $timer
    $timer.Start()
    $timer
}

function Stop-AllWidgetTimers {
    if ($null -eq $script:timerRegistry) { return }
    foreach ($timer in @($script:timerRegistry.Values)) { if ($null -ne $timer) { $timer.Stop() } }
    $script:timerRegistry.Clear()
}
