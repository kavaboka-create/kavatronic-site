param(
  [Parameter(Mandatory = $false)][string]$Source = "assets/logo.jpg",
  [Parameter(Mandatory = $false)][string]$Out48 = "favicon-48x48.png",
  [Parameter(Mandatory = $false)][string]$Out96 = "favicon-96x96.png",
  [Parameter(Mandatory = $false)][string]$Out192 = "favicon-192x192.png",
  [Parameter(Mandatory = $false)][string]$OutIco = "favicon.ico"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Get-NonWhiteBBox {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory = $true)][int]$YMaxInclusive,
    [Parameter(Mandatory = $false)][int]$WhiteThreshold = 250
  )

  $minX = $Bitmap.Width
  $minY = $Bitmap.Height
  $maxX = -1
  $maxY = -1

  for ($y = 0; $y -le $YMaxInclusive; $y++) {
    for ($x = 0; $x -lt $Bitmap.Width; $x++) {
      $c = $Bitmap.GetPixel($x, $y)
      if ($c.R -lt $WhiteThreshold -or $c.G -lt $WhiteThreshold -or $c.B -lt $WhiteThreshold) {
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }

  if ($maxX -lt 0) {
    throw "Non-white bbox not found in top region."
  }

  return [pscustomobject]@{ MinX = $minX; MinY = $minY; MaxX = $maxX; MaxY = $maxY }
}

function Clamp {
  param([int]$V, [int]$Min, [int]$Max)
  if ($V -lt $Min) { return $Min }
  if ($V -gt $Max) { return $Max }
  return $V
}

function Crop-To-Square {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap
  )

  # Heuristic: logo file includes icon + wordmark; favicon should use icon-only.
  # We scan non-white pixels only in the top 70% to avoid capturing the wordmark.
  $yMax = [int][Math]::Floor(($Bitmap.Height - 1) * 0.70)
  $bbox = Get-NonWhiteBBox -Bitmap $Bitmap -YMaxInclusive $yMax

  $w = ($bbox.MaxX - $bbox.MinX + 1)
  $h = ($bbox.MaxY - $bbox.MinY + 1)

  # Add padding around icon bbox.
  $pad = [int][Math]::Ceiling([Math]::Max($w, $h) * 0.08)

  $minX = Clamp ($bbox.MinX - $pad) 0 ($Bitmap.Width - 1)
  $minY = Clamp ($bbox.MinY - $pad) 0 ($Bitmap.Height - 1)
  $maxX = Clamp ($bbox.MaxX + $pad) 0 ($Bitmap.Width - 1)
  $maxY = Clamp ($bbox.MaxY + $pad) 0 ($Bitmap.Height - 1)

  $w2 = ($maxX - $minX + 1)
  $h2 = ($maxY - $minY + 1)

  $side = [int][Math]::Ceiling([Math]::Max($w2, $h2))
  $cx = [int][Math]::Round(($minX + $maxX) / 2.0)
  $cy = [int][Math]::Round(($minY + $maxY) / 2.0)

  $left = Clamp ([int]($cx - [Math]::Floor($side / 2.0))) 0 ($Bitmap.Width - $side)
  $top = Clamp ([int]($cy - [Math]::Floor($side / 2.0))) 0 ($Bitmap.Height - $side)

  $rect = New-Object System.Drawing.Rectangle($left, $top, $side, $side)
  $square = New-Object System.Drawing.Bitmap($side, $side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

  $g = [System.Drawing.Graphics]::FromImage($square)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Bitmap, (New-Object System.Drawing.Rectangle(0, 0, $side, $side)), $rect, [System.Drawing.GraphicsUnit]::Pixel)
  } finally {
    $g.Dispose()
  }

  return $square
}

function Resize-And-SavePng {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory = $true)][int]$Size,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $dst = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Bitmap, 0, 0, $Size, $Size)
    $dst.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $g.Dispose()
    $dst.Dispose()
  }
}

function Bitmap-ToPngBytes {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory = $true)][int]$Size
  )

  $dst = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  try {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Bitmap, 0, 0, $Size, $Size)

    $ms = New-Object System.IO.MemoryStream
    try {
      $dst.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
      return ,$ms.ToArray()
    } finally {
      $ms.Dispose()
    }
  } finally {
    $g.Dispose()
    $dst.Dispose()
  }
}

function Write-IcoWithPngImages {
  param(
    [Parameter(Mandatory = $true)][byte[][]]$PngImages,
    [Parameter(Mandatory = $true)][int[]]$Sizes,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ($PngImages.Length -ne $Sizes.Length) {
    throw "PngImages and Sizes must have same length."
  }

  $count = $Sizes.Length
  $iconDirSize = 6
  $entrySize = 16
  $offset = $iconDirSize + ($entrySize * $count)

  $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
  $bw = New-Object System.IO.BinaryWriter($fs)
  try {
    # ICONDIR
    $bw.Write([UInt16]0)     # reserved
    $bw.Write([UInt16]1)     # type 1 = icon
    $bw.Write([UInt16]$count)

    # ICONDIRENTRY list
    for ($i = 0; $i -lt $count; $i++) {
      $size = $Sizes[$i]
      $png = $PngImages[$i]

      $w = if ($size -ge 256) { 0 } else { [byte]$size }
      $h = if ($size -ge 256) { 0 } else { [byte]$size }

      $bw.Write($w)                 # width
      $bw.Write($h)                 # height
      $bw.Write([byte]0)            # colorCount
      $bw.Write([byte]0)            # reserved
      $bw.Write([UInt16]1)          # planes
      $bw.Write([UInt16]32)         # bitCount
      $bw.Write([UInt32]$png.Length) # bytesInRes
      $bw.Write([UInt32]$offset)     # imageOffset

      $offset += $png.Length
    }

    # Image data
    for ($i = 0; $i -lt $count; $i++) {
      $bw.Write($PngImages[$i])
    }
  } finally {
    $bw.Dispose()
    $fs.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source file not found: $Source"
}

$srcImg = [System.Drawing.Image]::FromFile($Source)
try {
  $bmp = New-Object System.Drawing.Bitmap($srcImg)
  try {
    $square = Crop-To-Square -Bitmap $bmp
    try {
      Resize-And-SavePng -Bitmap $square -Size 48 -Path $Out48
      Resize-And-SavePng -Bitmap $square -Size 96 -Path $Out96
      Resize-And-SavePng -Bitmap $square -Size 192 -Path $Out192

      $ico16 = Bitmap-ToPngBytes -Bitmap $square -Size 16
      $ico32 = Bitmap-ToPngBytes -Bitmap $square -Size 32
      $ico48 = Bitmap-ToPngBytes -Bitmap $square -Size 48
      Write-IcoWithPngImages -PngImages @($ico16, $ico32, $ico48) -Sizes @(16, 32, 48) -Path $OutIco
    } finally {
      $square.Dispose()
    }
  } finally {
    $bmp.Dispose()
  }
} finally {
  $srcImg.Dispose()
}

Write-Host "Generated: $Out48, $Out96, $Out192, $OutIco"
