function Render-Background {
    $script:background.Source = $null
    $activeFile = Get-ActiveBackgroundFile
    $path = Join-Path $base $activeFile

    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $script:background.Source = $bitmap
    }

    $scale = [Math]::Max(0.2, [Math]::Min(4.0, [double](Get-ActiveBackgroundScale)))
    $designWidth = [double]$script:config.widget.designWidth
    $designHeight = [double]$script:config.widget.designHeight

    $script:background.Width = $designWidth * $scale
    $script:background.Height = $designHeight * $scale

    [System.Windows.Controls.Canvas]::SetLeft(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetX) - (($script:background.Width - $designWidth) * 0.5))
    )

    [System.Windows.Controls.Canvas]::SetTop(
        $script:background,
        ([double](Get-ActiveBackgroundOffsetY) - (($script:background.Height - $designHeight) * 0.5))
    )

    $script:background.Opacity = [double]$script:config.background.opacity
    $script:background.Stretch = [System.Enum]::Parse(
        [System.Windows.Media.Stretch],
        [string]$script:config.background.stretch,
        $true
    )
    Render-ProfileAccessory
}

function Render-ProfileAccessory {
    if ($null -eq $script:profileAccessory) { return }
    $profile = Get-ActiveProfile
    $script:profileAccessory.Source = $null
    if ($null -eq $profile) { return }
    $path = Join-Path $base ([string]$profile.accessory)
    if (-not (Test-Path $path)) { return }
    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = 'OnLoad'
    $bitmap.UriSource = New-Object System.Uri($path)
    $bitmap.EndInit()
    $script:profileAccessory.Source = $bitmap
}

