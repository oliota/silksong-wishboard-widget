function Show-Widget {
    if ($script:exiting) { return }
    if ($null -eq $script:window) { return }

    $script:userHidden = $false

    if (-not $script:window.IsVisible) {
        $script:window.Show()
    }

    $script:window.WindowState = 'Normal'
    $script:window.Topmost = [bool]$script:config.widget.topmost
    Ensure-WidgetOnVisibleDisplay $true | Out-Null
    $script:window.Activate() | Out-Null
}
