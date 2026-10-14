# Encode the existing artwork as Windows ICO frames. Small shell icons use
# 32-bit DIB + an explicit transparency mask; the 256px frame stays PNG.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetDir = Join-Path $PSScriptRoot 'MeshDrop/Assets'
$source = [Drawing.Bitmap]::FromFile((Join-Path $assetDir 'AppIcon.png'))
$frames = [Collections.Generic.List[object]]::new()
try {
    foreach ($size in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $bitmap = [Drawing.Bitmap]::new($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $data = [IO.MemoryStream]::new()
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($source, 0, 0, $size, $size)
            if ($size -eq 256) {
                $bitmap.Save($data, [Drawing.Imaging.ImageFormat]::Png)
            } else {
                $writer = [IO.BinaryWriter]::new($data, [Text.Encoding]::UTF8, $true)
                $maskStride = [int]([Math]::Ceiling($size / 32.0) * 4)
                $writer.Write([uint32]40)
                $writer.Write([int32]$size)
                $writer.Write([int32]($size * 2))
                $writer.Write([uint16]1)
                $writer.Write([uint16]32)
                $writer.Write([uint32]0)
                $writer.Write([uint32]($size * $size * 4 + $maskStride * $size))
                1..4 | ForEach-Object { $writer.Write([uint32]0) }
                for ($y = $size - 1; $y -ge 0; $y--) {
                    for ($x = 0; $x -lt $size; $x++) {
                        $pixel = $bitmap.GetPixel($x, $y)
                        if ($pixel.A -eq 0) { $writer.Write([uint32]0) }
                        else { $writer.Write([byte]$pixel.B); $writer.Write([byte]$pixel.G); $writer.Write([byte]$pixel.R); $writer.Write([byte]$pixel.A) }
                    }
                }
                for ($y = $size - 1; $y -ge 0; $y--) {
                    $mask = [byte[]]::new($maskStride)
                    for ($x = 0; $x -lt $size; $x++) {
                        if ($bitmap.GetPixel($x, $y).A -eq 0) {
                            $index = [int][Math]::Floor($x / 8)
                            $mask[$index] = $mask[$index] -bor (0x80 -shr ($x % 8))
                        }
                    }
                    $writer.Write($mask)
                }
                $writer.Dispose()
            }
            $frames.Add(@{ Size = $size; Data = $data.ToArray() })
        } finally { $data.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
    }
    $output = [IO.File]::Create((Join-Path $assetDir 'AppIcon.ico'))
    $ico = [IO.BinaryWriter]::new($output)
    try {
        $ico.Write([uint16]0); $ico.Write([uint16]1); $ico.Write([uint16]$frames.Count)
        $offset = 6 + $frames.Count * 16
        foreach ($frame in $frames) {
            $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
            $ico.Write([byte]$dimension); $ico.Write([byte]$dimension)
            $ico.Write([uint16]0); $ico.Write([uint16]1); $ico.Write([uint16]32)
            $ico.Write([uint32]$frame.Data.Length); $ico.Write([uint32]$offset)
            $offset += $frame.Data.Length
        }
        foreach ($frame in $frames) { $ico.Write([byte[]]$frame.Data) }
    } finally { $ico.Dispose(); $output.Dispose() }
} finally { $source.Dispose() }
