function Read-JsonFile([string]$path) {
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-Tasks {
    $data = Read-JsonFile $tasksPath
    if ($null -eq $data.tasks) { return @() }
    @($data.tasks)
}

function Read-IconCatalog {
    if (-not (Test-Path $iconsPath)) {
        return [pscustomobject]@{ icons = @() }
    }

    $data = Read-JsonFile $iconsPath

    if ($null -eq $data.icons) {
        $data | Add-Member -NotePropertyName icons -NotePropertyValue @()
    }

    $data
}

function Get-IconEntry([string]$id) {
    $catalog = Read-IconCatalog
    @($catalog.icons | Where-Object { [string]$_.id -eq $id }) | Select-Object -First 1
}

function Get-RandomTaskIconId {
    $icons = @(
        (Read-IconCatalog).icons | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.id) -and
            -not [string]::IsNullOrWhiteSpace([string]$_.file) -and
            (Test-Path (Join-Path $base ([string]$_.file)))
        }
    )
    if ($icons.Count -eq 0) { return Get-DefaultTaskIconId }
    [string]($icons | Get-Random).id
}

function Get-RelativeAssetPath([string]$path) {
    ([System.IO.Path]::GetFullPath($path).Substring([System.IO.Path]::GetFullPath($base).Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/')
}

function Get-BadgeAssets([bool]$labels = $false) {
    if (-not (Test-Path $backgroundsDir)) { return @() }
    @(
        Get-ChildItem -LiteralPath $backgroundsDir -Recurse -File -Filter '*.png' |
            Where-Object {
                $relative = Get-RelativeAssetPath $_.FullName
                $isLabel = $relative -match '(?i)/badges/label/'
                if ($labels) { $isLabel } else { $relative -match '(?i)/badges/' -and -not $isLabel }
            } |
            Sort-Object FullName |
            ForEach-Object { Get-RelativeAssetPath $_.FullName }
    )
}

function Get-DominantIconColor([string]$iconId) {
    $entry = Get-IconEntry $iconId
    if ($null -eq $entry) { return '#FF8B4A58' }
    if (Test-Path $iconColorsPath) {
        $colorCatalog = Read-JsonFile $iconColorsPath
        $iconFileName = [System.IO.Path]::GetFileName([string]$entry.file)
        $configured = @($colorCatalog.icons | Where-Object { [string]$_.id -eq $iconId -or [string]$_.file -eq $iconFileName }) | Select-Object -First 1
        if ($null -ne $configured -and [string]$configured.color -match '^#[0-9A-Fa-f]{6}$') {
            return '#FF' + ([string]$configured.color).Substring(1).ToUpperInvariant()
        }
    }
    $path = Join-Path $base ([string]$entry.file)
    if (-not (Test-Path $path)) { return '#FF8B4A58' }
    $bitmap = [System.Drawing.Bitmap]::new($path)
    try {
        $bins = @{}
        $step = [Math]::Max(1, [Math]::Floor([Math]::Min($bitmap.Width, $bitmap.Height) / 32))
        for ($y = 0; $y -lt $bitmap.Height; $y += $step) {
            for ($x = 0; $x -lt $bitmap.Width; $x += $step) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -lt 80) { continue }
                $max = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
                $min = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
                if ($max -lt 35 -or $min -gt 235) { continue }
                $saturation = if ($max -eq 0) { 0.0 } else { ($max - $min) / [double]$max }
                $key = '{0},{1},{2}' -f ([Math]::Floor($pixel.R / 32)), ([Math]::Floor($pixel.G / 32)), ([Math]::Floor($pixel.B / 32))
                if (-not $bins.ContainsKey($key)) { $bins[$key] = [pscustomobject]@{ score = 0.0; r = 0.0; g = 0.0; b = 0.0; weight = 0.0 } }
                $weight = 0.25 + ($saturation * 1.75)
                $bin = $bins[$key]
                $bin.score += $weight
                $bin.r += $pixel.R * $weight
                $bin.g += $pixel.G * $weight
                $bin.b += $pixel.B * $weight
                $bin.weight += $weight
            }
        }
        $winner = @($bins.Values | Sort-Object score -Descending | Select-Object -First 1)
        if ($winner.Count -eq 0) { return '#FF8B4A58' }
        $color = $winner[0]
        '#FF{0:X2}{1:X2}{2:X2}' -f [int]($color.r / $color.weight), [int]($color.g / $color.weight), [int]($color.b / $color.weight)
    }
    finally {
        $bitmap.Dispose()
    }
}

