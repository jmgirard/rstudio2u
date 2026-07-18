@echo off
setlocal EnableDelayedExpansion
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

:: Resolve the port the user asked for, the way Compose resolves it: RS_PORT
:: from the environment wins, else a RS_PORT line in .env, else the 8787
:: default. This mirrors launcher_common.sh for the POSIX launchers, which
:: batch cannot source.
:: Note: comments inside a parenthesised block must use `rem`, not `::` -- a
:: `::` label inside ( ) is a cmd.exe parse error.
set "RS_PORT_REQUESTED=%RS_PORT%"
if not defined RS_PORT_REQUESTED (
    if exist ".env" (
        for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
            set "ENVKEY=%%A"
            rem trim leading whitespace from the key
            for /f "tokens=* delims= " %%K in ("!ENVKEY!") do set "ENVKEY=%%K"
            rem %%~B strips surrounding quotes; last assignment wins, as in Compose
            if /i "!ENVKEY!"=="RS_PORT" set "RS_PORT_REQUESTED=%%~B"
        )
    )
)
if defined RS_PORT_REQUESTED (
    for /f "tokens=* delims= " %%V in ("!RS_PORT_REQUESTED!") do set "RS_PORT_REQUESTED=%%V"
)

:: Catch a bad value before Compose does, so the student gets a plain message
:: instead of a port-binding error -- and so a value like 0.0.0.0:8888 can never
:: be interpolated into the 127.0.0.1 mapping and publish the port beyond
:: localhost while auth is disabled.
call :check_port
if errorlevel 1 (
    echo.
    echo [X] RS_PORT is set to '!RS_PORT_REQUESTED!', which is not a usable port number.
    echo     Use a whole number between 1 and 65535, for example 8888.
    echo     Check the RS_PORT line in your .env file, or unset RS_PORT to
    echo     use the default port 8787.
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
    echo     If the port is already in use, pick another one by putting
    echo         RS_PORT=8888
    echo     in a file named .env next to this launcher, then run it again.
    echo     Otherwise, open Docker Desktop and check the container for errors.
    echo.
    call :wait
    exit /b 1
)

:: Ask Compose what it actually bound. Trusting this over the value we parsed
:: means the URL we print can never disagree with reality, whatever set it.
set "RS_URL_PORT="
for /f "usebackq tokens=2 delims=:" %%P in (`docker compose port rstudio2u 8787 2^>nul`) do set "RS_URL_PORT=%%P"
if not defined RS_URL_PORT set "RS_URL_PORT=!RS_PORT_REQUESTED!"
if not defined RS_URL_PORT set "RS_URL_PORT=8787"
echo !RS_URL_PORT!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 set "RS_URL_PORT=8787"
set "RS_URL=http://localhost:!RS_URL_PORT!"

echo.
echo ============================================================
echo [OK] RStudio Server is running at !RS_URL!
echo      If your browser does not open, go to that address manually.
echo ============================================================
echo.

:: Under the non-interactive test seam, stop before opening a browser or
:: pausing so CI can drive every branch unattended.
if defined RS_LAUNCHER_NONINTERACTIVE goto :done

echo Opening your web browser...
start "" "!RS_URL!"
timeout /t 3 >nul

:done
endlocal
exit /b 0

:: Is RS_PORT_REQUESTED a usable port? Anything containing interpolation is left
:: to Compose, which supports syntax this reader does not -- refusing a config
:: that would have worked is worse than a late, clearer error.
:check_port
if not defined RS_PORT_REQUESTED exit /b 0
echo !RS_PORT_REQUESTED!| findstr /c:"$" /c:"{" >nul
if not errorlevel 1 exit /b 0
echo !RS_PORT_REQUESTED!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 exit /b 1
if !RS_PORT_REQUESTED! LSS 1 exit /b 1
if !RS_PORT_REQUESTED! GTR 65535 exit /b 1
exit /b 0

:: Interactive pause, suppressed under the test seam.
:wait
if defined RS_LAUNCHER_NONINTERACTIVE goto :eof
pause
goto :eof
