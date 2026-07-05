@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo Stopping rstudio2u...
docker compose stop

echo.
echo [OK] Server stopped. Your work is preserved -- double-click
echo      start_windows.bat to resume where you left off.
echo.
pause
