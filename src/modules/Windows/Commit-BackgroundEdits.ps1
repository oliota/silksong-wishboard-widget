function Commit-BackgroundEdits {
    $registry = Read-BackgroundRegistry
    $kept = @()

    foreach ($entry in @($registry.backgrounds)) {
        $id = [string]$entry.id

        if ($script:pendingDeletedBackgroundIds.Contains($id) -and -not [bool]$entry.protected) {
            $path = Join-Path $base ([string]$entry.file)

            if (Test-Path $path) {
                Remove-Item -LiteralPath $path -Force
            }

            continue
        }

        $kept += $entry
    }

    $registry.backgrounds = @($kept)
    Save-BackgroundRegistry $registry
    $script:pendingDeletedBackgroundIds.Clear()
}
