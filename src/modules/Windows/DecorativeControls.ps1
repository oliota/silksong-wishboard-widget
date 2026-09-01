function Hide-Panel {
    if ($script:detailsPanel) {  }
    Close-AddTaskPanel
    if ($script:backgroundPanel) { $script:backgroundPanel.Visibility = 'Collapsed' }
    if ($script:gridPanel) { $script:gridPanel.Visibility = 'Collapsed' }
}

function New-DecorativeAsset([string]$relativePath, [double]$height) {
    $image = New-Object System.Windows.Controls.Image
    $image.Height = $height
    $image.Stretch = 'Uniform'
    $image.HorizontalAlignment = 'Stretch'
    $image.VerticalAlignment = 'Center'

    $path = Join-Path $base $relativePath
    if (Test-Path $path) {
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.UriSource = New-Object System.Uri($path)
        $bitmap.EndInit()
        $image.Source = $bitmap
    }

    $image
}

function New-DescriptionCorner(
    [string]$relativePath,
    [bool]$flipX,
    [string]$horizontalAlignment,
    [string]$verticalAlignment,
    [double]$width,
    [double]$height
) {
    $image = New-DecorativeAsset $relativePath 1
    $image.Width = $width
    $image.Height = $height
    $image.Stretch = 'Fill'
    $image.HorizontalAlignment = $horizontalAlignment
    $image.VerticalAlignment = $verticalAlignment
    $image.IsHitTestVisible = $false
    $image.Opacity = 0.82
    if ($flipX) {
        $image.RenderTransformOrigin = '0.5,0.5'
        $image.RenderTransform = New-Object System.Windows.Media.ScaleTransform(-1, 1)
    }
    $image
}

function Add-DescriptionCorners($container) {
    $lineBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#B8FFFFFF')
    foreach ($line in @(
        [pscustomobject]@{ width = [double]::NaN; height = 1.0; horizontal = 'Stretch'; vertical = 'Top'; margin = '50,8,50,0' }
        [pscustomobject]@{ width = [double]::NaN; height = 1.0; horizontal = 'Stretch'; vertical = 'Bottom'; margin = '50,0,50,8' }
        [pscustomobject]@{ width = 1.0; height = [double]::NaN; horizontal = 'Left'; vertical = 'Stretch'; margin = '8,46,0,38' }
        [pscustomobject]@{ width = 1.0; height = [double]::NaN; horizontal = 'Right'; vertical = 'Stretch'; margin = '0,46,8,38' }
    )) {
        $border = New-Object System.Windows.Controls.Border
        if (-not [double]::IsNaN($line.width)) { $border.Width = $line.width }
        if (-not [double]::IsNaN($line.height)) { $border.Height = $line.height }
        $border.HorizontalAlignment = $line.horizontal
        $border.VerticalAlignment = $line.vertical
        $border.Margin = $line.margin
        $border.Background = $lineBrush
        $border.IsHitTestVisible = $false
        $container.Children.Add($border) | Out-Null
    }

    $corners = @(
        New-DescriptionCorner 'backgrounds/dialogue_corner_top_left.png' $false 'Left' 'Top' 58 72
        New-DescriptionCorner 'backgrounds/dialogue_corner_top_left.png' $true 'Right' 'Top' 58 72
        New-DescriptionCorner 'backgrounds/dialogue_corner_bottom_right.png' $true 'Left' 'Bottom' 68 56
        New-DescriptionCorner 'backgrounds/dialogue_corner_bottom_right.png' $false 'Right' 'Bottom' 68 56
    )
    foreach ($corner in $corners) {
        $container.Children.Add($corner) | Out-Null
    }
}

function Add-TextBoxPlaceholder($container, $textBox, [string]$text, [string]$margin, [int]$row, [string]$verticalAlignment) {
    $placeholder = New-Object System.Windows.Controls.TextBlock
    $placeholder.Text = $text
    $placeholder.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF777777')
    $placeholder.Margin = $margin
    $placeholder.VerticalAlignment = $verticalAlignment
    $placeholder.IsHitTestVisible = $false
    [System.Windows.Controls.Grid]::SetRow($placeholder, $row)
    [System.Windows.Controls.Panel]::SetZIndex($placeholder, 4)
    $container.Children.Add($placeholder) | Out-Null
    $update = {
        $placeholder.Visibility = if ($textBox.IsVisible -and [string]::IsNullOrEmpty($textBox.Text)) { 'Visible' } else { 'Collapsed' }
    }.GetNewClosure()
    $textBox.Add_TextChanged($update)
    $textBox.Add_IsVisibleChanged($update)
    & $update
}

function Add-OrnamentShadow($container, [int]$row) {
    $shadow = New-Object System.Windows.Controls.Border
    $shadow.Margin = '0'
    $shadow.IsHitTestVisible = $false

    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = [System.Windows.Point]::new(0.0, 0.5)
    $brush.EndPoint = [System.Windows.Point]::new(1.0, 0.5)
    $stops = @(
        [pscustomobject]@{ alpha = 0; offset = 0.0 }
        [pscustomobject]@{ alpha = 45; offset = 0.08 }
        [pscustomobject]@{ alpha = 155; offset = 0.18 }
        [pscustomobject]@{ alpha = 225; offset = 0.3 }
        [pscustomobject]@{ alpha = 225; offset = 0.7 }
        [pscustomobject]@{ alpha = 155; offset = 0.82 }
        [pscustomobject]@{ alpha = 45; offset = 0.92 }
        [pscustomobject]@{ alpha = 0; offset = 1.0 }
    )
    foreach ($stop in $stops) {
        $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new(
            [System.Windows.Media.Color]::FromArgb([byte]$stop.alpha, 0, 0, 0),
            [double]$stop.offset
        ))
    }
    $shadow.Background = $brush

    [System.Windows.Controls.Grid]::SetRow($shadow, $row)
    [System.Windows.Controls.Panel]::SetZIndex($shadow, -1)
    $container.Children.Add($shadow) | Out-Null
}

function New-DetailOrnament([bool]$bottom = $false) {
    $image = if ($bottom) {
        New-DecorativeAsset 'backgrounds/bottom_fleur0008.png' 30
    }
    else {
        New-DecorativeAsset 'backgrounds/Dialogue_fleur_top_NPC0005.png' 46
    }

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.Color = [System.Windows.Media.Colors]::Black
    $shadow.BlurRadius = 12
    $shadow.ShadowDepth = 0
    $shadow.Opacity = 0.95
    $image.Effect = $shadow
    $image
}

function New-TaskPreviewControl($task) {
    $titleLength = ([string]$task.title).Length
    $previewWidth = [Math]::Max(190.0, [Math]::Min(420.0, 120.0 + ($titleLength * 7.2)))

    $outer = New-Object System.Windows.Controls.Grid
    $outer.Width = $previewWidth
    $outer.Height = 172
    foreach ($height in @(40, 102, 30)) {
        $row = New-Object System.Windows.Controls.RowDefinition
        $row.Height = New-Object System.Windows.GridLength($height)
        $outer.RowDefinitions.Add($row)
    }

    Add-OrnamentShadow $outer 1

    $top = New-DetailOrnament
    [System.Windows.Controls.Grid]::SetRow($top, 0)
    $outer.Children.Add($top) | Out-Null

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F4070708')
    $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#66FFFFFF')
    $card.BorderThickness = 1
    $card.CornerRadius = 4
    $card.Padding = '14,10'
    $card.Margin = '14,0'
    [System.Windows.Controls.Grid]::SetRow($card, 1)
    $outer.Children.Add($card) | Out-Null

    $content = New-Object System.Windows.Controls.Grid
    $iconRow = New-Object System.Windows.Controls.RowDefinition
    $iconRow.Height = New-Object System.Windows.GridLength(58)
    $titleRow = New-Object System.Windows.Controls.RowDefinition
    $titleRow.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $content.RowDefinitions.Add($iconRow)
    $content.RowDefinitions.Add($titleRow)
    $card.Child = $content

    $iconEntry = Get-IconEntry ([string]$task.icon)
    if ($null -ne $iconEntry) {
        $icon = New-ImageControl ([string]$iconEntry.file) 54
        [System.Windows.Controls.Grid]::SetRow($icon, 0)
        $content.Children.Add($icon) | Out-Null
    }

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = [string]$task.title
    $title.Foreground = [System.Windows.Media.Brushes]::White
    $title.FontSize = 16
    $title.FontWeight = 'SemiBold'
    $title.TextAlignment = 'Center'
    $title.TextTrimming = 'CharacterEllipsis'
    $title.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetRow($title, 1)
    $content.Children.Add($title) | Out-Null

    $bottom = New-DetailOrnament $true
    [System.Windows.Controls.Grid]::SetRow($bottom, 2)
    $outer.Children.Add($bottom) | Out-Null

    $outer
}

