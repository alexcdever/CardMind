@echo off
echo ===== 开始构建 CardMind 应用程序 =====
echo.

echo ===== 构建 Windows 安装包 =====
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo Windows 构建失败！
    exit /b %ERRORLEVEL%
)
echo Windows 安装包构建成功！
echo 输出目录: %CD%\build\windows\runner\Release\
echo.

echo ===== 构建 Android APK =====
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo Android APK 构建失败！
    exit /b %ERRORLEVEL%
)
echo Android APK 构建成功！
echo 输出文件: %CD%\build\app\outputs\flutter-apk\app-release.apk
echo.

echo ===== 构建 Android App Bundle =====
call flutter build appbundle --release
if %ERRORLEVEL% NEQ 0 (
    echo Android App Bundle 构建失败！
    exit /b %ERRORLEVEL%
)
echo Android App Bundle 构建成功！
echo 输出文件: %CD%\build\app\outputs\bundle\release\app-release.aab
echo.

echo ===== 所有构建任务完成 =====
echo.
echo Windows 安装包: %CD%\build\windows\runner\Release\
echo Android APK: %CD%\build\app\outputs\flutter-apk\app-release.apk
echo Android App Bundle: %CD%\build\app\outputs\bundle\release\app-release.aab
