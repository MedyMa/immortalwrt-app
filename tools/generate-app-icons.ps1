param([string]$Chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $projectRoot 'design/app-icons'
$temporaryDirectory = Join-Path $projectRoot '.dart_tool/icon-render'
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
Add-Type -AssemblyName System.Drawing
function Save-Icon([string]$source, [string]$target, [int]$size) {
    $inputImage = [System.Drawing.Image]::FromFile($source)
    $outputImage = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $canvas = [System.Drawing.Graphics]::FromImage($outputImage)
    try {
        $canvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $canvas.DrawImage($inputImage, [System.Drawing.Rectangle]::new(0,0,$size,$size),
            [System.Drawing.Rectangle]::new(0,0,1024,1024), [System.Drawing.GraphicsUnit]::Pixel)
        $outputImage.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $canvas.Dispose(); $outputImage.Dispose(); $inputImage.Dispose() }
}
$catalogDirectory = Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$catalogFile = Join-Path $catalogDirectory 'Contents.json'
$catalog = Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json
foreach ($mode in @('day','night','tinted')) {
    $svgFile = Join-Path $sourceDirectory "router-$mode.svg"
    $documentFile = Join-Path $temporaryDirectory "$mode.html"
    $screenshotFile = Join-Path $temporaryDirectory "$mode.png"
    if (Test-Path -LiteralPath $screenshotFile) { Remove-Item -LiteralPath $screenshotFile }
    $svgText = Get-Content -LiteralPath $svgFile -Raw
    Set-Content -LiteralPath $documentFile -Encoding utf8 -Value "<!doctype html><style>body{margin:0}svg{display:block}</style>$svgText"
    $documentUrl = ([System.Uri]::new($documentFile)).AbsoluteUri
    $chromeArgs = @('--headless','--disable-gpu','--hide-scrollbars','--no-first-run',
        "--user-data-dir=$temporaryDirectory/chrome-profile", "--screenshot=$screenshotFile",
        '--window-size=1024,1100','--force-device-scale-factor=1',$documentUrl)
    Start-Process -FilePath $Chrome -ArgumentList $chromeArgs -WindowStyle Hidden -Wait
    for ($attempt = 0; $attempt -lt 100 -and !(Test-Path -LiteralPath $screenshotFile); $attempt++) {
        Start-Sleep -Milliseconds 100
    }
    if (!(Test-Path -LiteralPath $screenshotFile)) { throw "Icon render failed: $mode" }
    Save-Icon $screenshotFile (Join-Path $catalogDirectory "Router-$mode-1024.png") 1024
    if ($mode -eq 'day') {
        foreach ($entry in $catalog.images) {
            if ($entry.filename -and $entry.scale -and !$entry.appearances) {
                $points = [double]($entry.size.Split('x')[0])
                $scale = [double]($entry.scale.Replace('x',''))
                Save-Icon $screenshotFile (Join-Path $catalogDirectory $entry.filename) ([int]($points * $scale))
            }
        }
        foreach ($density in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))) {
            Save-Icon $screenshotFile (Join-Path $projectRoot "android/app/src/main/res/mipmap-$($density[0])/ic_launcher.png") $density[1]
        }
    }
}
$catalog.images = @($catalog.images | Where-Object { $_.idiom -ne 'universal' }) + @(
    @{idiom='universal'; platform='ios'; size='1024x1024'; filename='Router-day-1024.png'},
    @{idiom='universal'; platform='ios'; size='1024x1024'; filename='Router-night-1024.png'; appearances=@(@{appearance='luminosity'; value='dark'})},
    @{idiom='universal'; platform='ios'; size='1024x1024'; filename='Router-tinted-1024.png'; appearances=@(@{appearance='luminosity'; value='tinted'})}
)
Set-Content -LiteralPath $catalogFile -Encoding utf8 -Value ($catalog | ConvertTo-Json -Depth 8)
