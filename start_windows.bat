@echo off
setlocal
:: Set console to UTF-8
chcp 65001 >nul
cd /d "%~dp0"

echo Starting rstudio2u...

:: Is Docker installed at all? Distinguish "not installed" from "not running"
:: so a student who never installed Docker Desktop is not told to "wait for it
:: to finish starting".
where docker >nul 2>&1
if errorlevel 1 (
    echo.
    echo [X] Docker Desktop does not appear to be installed.
    echo     Install it from https://www.docker.com/products/docker-desktop/
    echo     then double-click this file again.
    echo.
    call :wait
    exit /b 1
)

:: Installed, but is the engine actually running?
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo [X] Docker Desktop is installed but not running.
    echo     Open Docker Desktop, wait for it to finish starting,
    echo     then double-click this file again.
    echo.
    call :wait
    exit /b 1
)

:: Get the latest image. A pull failure is a different problem from a slow or
:: unhealthy start, so report it as its own thing instead of blaming a timeout.
docker compose pull
if errorlevel 1 (
    echo.
    echo [X] Could not download the latest image.
    echo     Check your internet connection and that you can reach Docker Hub,
    echo     then try again.
    echo.
    call :wait
    exit /b 1
)

:: Start the server and wait until it reports healthy.
docker compose up -d --wait --wait-timeout 180
if errorlevel 1 (
    echo.
    echo [X] The server did not become ready in time.
    echo     If port 8787 is already in use, pick another port before running
    echo     this file again, for example:
    echo         set RS_PORT=8888
    echo     Otherwise, open Docker Desktop and check the container for errors.
    echo.
    call :wait
    exit /b 1
)

echo.
echo ============================================================
echo [OK] RStudio Server is running at http://localhost:8787
echo      If your browser does not open, go to that address manually.
echo ============================================================
echo.

:: Under the non-interactive test seam, stop before opening a browser or
:: pausing so CI can drive every branch unattended.
if defined RS_LAUNCHER_NONINTERACTIVE goto :done

echo Opening your web browser...
start "" http://localhost:8787
timeout /t 3 >nul

:done
endlocal
exit /b 0

:: Interactive pause, suppressed under the test seam.
:wait
if defined RS_LAUNCHER_NONINTERACTIVE goto :eof
pause
goto :eof
