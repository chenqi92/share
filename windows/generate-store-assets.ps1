# Generate MSIX scale and unplated taskbar assets from the existing artwork.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $PSScriptRoot 'MeshDrop\Assets'
$destination = Join-Path $assetRoot 'Store'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$source = [System.Drawing.Image]::FromFile((Join-Path $assetRoot 'AppIcon.png'))
try {
    $specs = @(
        @{Name = 'StoreLogo.png'; Size = 50},
        @{Name = 'AppList.png'; Size = 44},
        @{Name = 'Square150x150Logo.png'; Size = 150},
        @{Name = 'Square150x150Logo.scale-200.png'; Size = 300}
    )
    foreach ($scale in @(125, 150, 200, 400)) {
        $specs += @{Name = "AppList.scale-$scale.png"; Size = [int](44 * $scale / 100)}
    }
    # Packaged taskbar icons come from the manifest's app-list resource. Without
    # unplated variants Windows adds a colored square behind transparent corners.
    foreach ($size in @(16, 20, 24, 30, 32, 36, 40, 48, 60, 64, 72, 80, 96, 256)) {
        foreach ($form in @('', '_altform-unplated', '_altform-lightunplated')) {
            $specs += @{Name = "AppList.targetsize-$size$form.png"; Size = $size}
        }
    }
    foreach ($spec in $specs) {
        $bitmap = [System.Drawing.Bitmap]::new($spec.Size, $spec.Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($source, 0, 0, $spec.Size, $spec.Size)
            $bitmap.Save((Join-Path $destination $spec.Name), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
}
finally { $source.Dispose() }
