# Enhanced build script
Write-Host "===== Starting CardMind Build =====" -ForegroundColor Green

# Windows
Write-Host "Building Windows app..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Windows build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Windows build successful!" -ForegroundColor Green
Write-Host "Output: $(Get-Location)\build\windows\runner\Release\" -ForegroundColor Yellow

# Android APK
Write-Host "Building Android APK..." -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Android APK build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Android APK build successful!" -ForegroundColor Green
Write-Host "Output: $(Get-Location)\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow

Write-Host "===== All builds completed! =====" -ForegroundColor Green
