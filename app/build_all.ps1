Write-Host "===== 开始构建 CardMind 应用程序 =====" -ForegroundColor Green
Write-Host ""

Write-Host "===== 构建 Windows 安装包 =====" -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Windows 构建失败！" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Windows 安装包构建成功！" -ForegroundColor Green
Write-Host "输出目录: $(Get-Location)\build\windows\runner\Release\" -ForegroundColor Yellow
Write-Host ""

Write-Host "===== 构建 Android APK =====" -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Android APK 构建失败！" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Android APK 构建成功！" -ForegroundColor Green
Write-Host "输出文件: $(Get-Location)\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
Write-Host ""

Write-Host "===== 构建 Android App Bundle =====" -ForegroundColor Cyan
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Android App Bundle 构建失败！" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "Android App Bundle 构建成功！" -ForegroundColor Green
Write-Host "输出文件: $(Get-Location)\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
Write-Host ""

Write-Host "===== 所有构建任务完成 =====" -ForegroundColor Green
Write-Host ""
Write-Host "Windows 安装包: $(Get-Location)\build\windows\runner\Release\" -ForegroundColor Yellow
Write-Host "Android APK: $(Get-Location)\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
Write-Host "Android App Bundle: $(Get-Location)\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
