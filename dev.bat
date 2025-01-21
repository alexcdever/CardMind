@echo off
chcp 65001 > nul
echo Starting CardMind development servers...

:: Setup MSVC environment
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64

:: Install dependencies
echo Installing dependencies...
call pnpm install
if errorlevel 1 (
    echo Failed to install dependencies
    pause
    exit /b 1
)

:: Start backend server
cd server
start "CardMind Backend" cmd /k "cargo run"
cd ..

:: Wait for backend to start
ping 127.0.0.1 -n 6 > nul

:: Start frontend server
start "CardMind Frontend" cmd /k "pnpm dev"

echo Development servers are starting...
echo Backend will be available at http://localhost:3000
echo Frontend will be available at http://localhost:9999
pause
