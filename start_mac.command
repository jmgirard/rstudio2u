#!/bin/bash
cd "$(dirname "$0")"

# Allow future double-clicking without macOS Gatekeeper re-prompting
xattr -c "$0" 2>/dev/null
chmod u+x "$0" 2>/dev/null

# Sourcing a sibling file means a student who copied only this launcher out of
# the folder would otherwise get a bare "No such file or directory".
if [ ! -f ./launcher_common.sh ]; then
    echo ""
    echo "❌ This launcher needs the file launcher_common.sh, which is missing"
    echo "   from this folder. Copy or download the whole project folder, then"
    echo "   double-click this file again."
    echo ""
    # The seam helper lives in the very file that is missing, so honor the
    # test seam inline here rather than calling launcher_pause.
    [ -n "${RS_LAUNCHER_NONINTERACTIVE:-}" ] || read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi
# shellcheck source=launcher_common.sh
. ./launcher_common.sh

echo "Starting rstudio2u..."

# Distinguish "not installed" from "not running" so a student who never
# installed Docker Desktop is not told to wait for it to finish starting.
if ! command -v docker >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker Desktop does not appear to be installed."
    echo "   Install it from https://www.docker.com/products/docker-desktop/"
    echo "   then double-click this file again."
    echo ""
    launcher_pause
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker Desktop is installed but not running."
    echo "   Please open Docker Desktop, wait for it to finish starting,"
    echo "   then double-click this file again."
    echo ""
    launcher_pause
    exit 1
fi

# Catch a bad RS_PORT before Compose does, so the student gets a plain message
# instead of a port-binding error.
launcher_check_port "$(launcher_requested_port)" || exit 1

# A pull failure is a different problem from a slow or unhealthy start.
if ! docker compose pull; then
    echo ""
    echo "❌ Could not download the latest image."
    echo "   Check your internet connection and that you can reach Docker Hub,"
    echo "   then try again."
    echo ""
    launcher_pause
    exit 1
fi

# Start the server and wait until it is healthy
if docker compose up -d --wait --wait-timeout 180; then
    url=$(launcher_url)
    echo ""
    echo "============================================================"
    echo "✅ RStudio Server is running at $url"
    echo "   If your browser does not open, go to that address manually."
    echo "🚀 Opening your web browser..."
    echo "============================================================"
    echo ""
    if launcher_interactive; then
        open "$url"
    fi
else
    echo ""
    echo "❌ The server did not become ready in time. Please try again,"
    echo "   or check Docker Desktop for errors."
    echo "   If the port is already in use, pick another one by putting"
    echo "   RS_PORT=8888 in a file named .env next to this launcher."
    echo ""
    launcher_pause
    exit 1
fi
