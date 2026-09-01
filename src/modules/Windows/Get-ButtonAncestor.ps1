function Get-ButtonAncestor($element) {
    $current = $element

    while ($null -ne $current) {
        if ($current -is [System.Windows.Controls.Button]) {
            return $current
        }

        try {
            $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
        }
        catch {
            return $null
        }
    }

    return $null
}
