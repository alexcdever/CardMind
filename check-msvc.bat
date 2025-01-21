@echo off
echo Setting up MSVC environment...
call "C:\ProgramData\scoop\apps\vs2022-build-tools\current\Common7\Tools\VsDevCmd.bat" -arch=x64

echo.
echo Checking for required tools...

echo Checking for link.exe...
where link.exe
if %ERRORLEVEL% EQU 0 (
    echo [OK] link.exe found
) else (
    echo [ERROR] link.exe not found
)

echo.
echo Checking for cl.exe...
where cl.exe
if %ERRORLEVEL% EQU 0 (
    echo [OK] cl.exe found
) else (
    echo [ERROR] cl.exe not found
)

echo.
echo Checking for Windows SDK...
if exist "C:\Program Files (x86)\Windows Kits\10\Include" (
    echo [OK] Windows SDK found
) else (
    echo [ERROR] Windows SDK not found
)

echo.
echo Checking environment variables...
echo INCLUDE: %INCLUDE%
echo LIB: %LIB%
echo LIBPATH: %LIBPATH%

echo.
echo Visual Studio installation path:
vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
