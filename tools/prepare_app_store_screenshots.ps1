param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\release_outputs\app_store_screenshots_6_5")
)

Add-Type -AssemblyName System.Drawing

$targetWidth = 1242
$targetHeight = 2688
$androidStatusBarHeight = 75
$androidNavigationBarHeight = 98

$screenshots = [ordered]@{
    "01_ana_sayfa.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.14 (2).jpeg"
    "02_akilli_bitki_araclari.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.14.jpeg"
    "03_uc_fotografla_teshis.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.14 (1).jpeg"
    "04_bakim_ozeti.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.13.jpeg"
    "05_guvenlik_profili.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.14 (3).jpeg"
    "06_acilis_markasi.png" = "C:\Users\omerc\Downloads\WhatsApp Image 2026-07-03 at 12.57.14 (4).jpeg"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

foreach ($entry in $screenshots.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value)) {
        throw "Kaynak ekran goruntusu bulunamadi: $($entry.Value)"
    }

    $source = [System.Drawing.Image]::FromFile($entry.Value)
    try {
        $canvas = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight)
        try {
            $canvas.SetResolution(72, 72)
            $graphics = [System.Drawing.Graphics]::FromImage($canvas)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

                $contentHeight = $source.Height - $androidStatusBarHeight - $androidNavigationBarHeight
                $requiredSourceWidth = [int][Math]::Round($contentHeight * $targetWidth / $targetHeight)
                $sourceX = [int][Math]::Floor(($source.Width - $requiredSourceWidth) / 2)
                $destinationRect = New-Object System.Drawing.Rectangle(0, 0, $targetWidth, $targetHeight)
                $sourceRect = New-Object System.Drawing.Rectangle(
                    $sourceX,
                    $androidStatusBarHeight,
                    $requiredSourceWidth,
                    $contentHeight
                )

                $graphics.DrawImage(
                    $source,
                    $destinationRect,
                    $sourceRect,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            }
            finally {
                $graphics.Dispose()
            }

            $destination = Join-Path $OutputDirectory $entry.Key
            $canvas.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $canvas.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

Get-ChildItem -LiteralPath $OutputDirectory -Filter *.png | Sort-Object Name | ForEach-Object {
    $image = [System.Drawing.Image]::FromFile($_.FullName)
    try {
        [PSCustomObject]@{
            File = $_.Name
            Dimensions = "$($image.Width)x$($image.Height)"
            SizeMB = [Math]::Round($_.Length / 1MB, 2)
        }
    }
    finally {
        $image.Dispose()
    }
}
