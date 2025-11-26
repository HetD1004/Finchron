# PowerShell script to resize Finchron logo for all app icons
# Note: This script requires ImageMagick to be installed
# Download from: https://imagemagick.org/script/download.php#windows

$logoPath = "C:\Users\ASUS\Desktop\Finchron\finchron_app\assets\images\finchron_logo.png"
$appPath = "C:\Users\ASUS\Desktop\Finchron\finchron_app"

# Check if ImageMagick is available
if (!(Get-Command "magick" -ErrorAction SilentlyContinue)) {
    Write-Host "ImageMagick not found. Please install ImageMagick first." -ForegroundColor Red
    Write-Host "Download from: https://imagemagick.org/script/download.php#windows" -ForegroundColor Yellow
    exit 1
}

Write-Host "Resizing Finchron logo for all platforms..." -ForegroundColor Green

# Android Icons (Different densities)
Write-Host "Creating Android icons..." -ForegroundColor Blue
& magick $logoPath -resize 48x48 "$appPath\android\app\src\main\res\mipmap-mdpi\ic_launcher.png"
& magick $logoPath -resize 72x72 "$appPath\android\app\src\main\res\mipmap-hdpi\ic_launcher.png"
& magick $logoPath -resize 96x96 "$appPath\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"
& magick $logoPath -resize 144x144 "$appPath\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"
& magick $logoPath -resize 192x192 "$appPath\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"

# iOS Icons
Write-Host "Creating iOS icons..." -ForegroundColor Blue
& magick $logoPath -resize 20x20 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png"
& magick $logoPath -resize 40x40 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png"
& magick $logoPath -resize 60x60 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png"
& magick $logoPath -resize 29x29 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png"
& magick $logoPath -resize 58x58 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png"
& magick $logoPath -resize 87x87 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png"
& magick $logoPath -resize 40x40 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png"
& magick $logoPath -resize 80x80 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png"
& magick $logoPath -resize 120x120 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png"
& magick $logoPath -resize 120x120 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png"
& magick $logoPath -resize 180x180 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png"
& magick $logoPath -resize 76x76 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png"
& magick $logoPath -resize 152x152 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png"
& magick $logoPath -resize 167x167 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png"
& magick $logoPath -resize 1024x1024 "$appPath\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png"

# macOS Icons
Write-Host "Creating macOS icons..." -ForegroundColor Blue
& magick $logoPath -resize 16x16 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png"
& magick $logoPath -resize 32x32 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png"
& magick $logoPath -resize 64x64 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png"
& magick $logoPath -resize 128x128 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png"
& magick $logoPath -resize 256x256 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png"
& magick $logoPath -resize 512x512 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png"
& magick $logoPath -resize 1024x1024 "$appPath\macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png"

# Web Icons
Write-Host "Creating Web icons..." -ForegroundColor Blue
& magick $logoPath -resize 192x192 "$appPath\web\icons\Icon-192.png"
& magick $logoPath -resize 512x512 "$appPath\web\icons\Icon-512.png"
& magick $logoPath -resize 192x192 "$appPath\web\icons\Icon-maskable-192.png"
& magick $logoPath -resize 512x512 "$appPath\web\icons\Icon-maskable-512.png"
& magick $logoPath -resize 32x32 "$appPath\web\favicon.png"

Write-Host "All icons have been resized successfully!" -ForegroundColor Green
Write-Host "Your Finchron logo is now used across all platforms." -ForegroundColor Cyan