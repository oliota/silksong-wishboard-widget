function Exit-Widget {
    if ($script:exiting) { return }

    if ($script:editMode) {
        Cancel-EditSession
    }

    $script:exiting = $true
    $script:userHidden = $true

    Dispose-ApplicationResources

    if ($null -ne $script:window) {
        $script:config.widget.width = [Math]::Round([double]$script:window.Width, 1)
        $script:config.widget.height = [Math]::Round([double]$script:window.Height, 1)
        Save-WidgetPlacement
        $script:window.Close()
    }

    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvokeShutdown(
        [System.Windows.Threading.DispatcherPriority]::Background
    )
}
