#!/bin/bash
cd "$(dirname "$0")"

# shellcheck source=launcher_common.sh
. ./launcher_common.sh

echo "Starting rstudio2u..."

# Distinguish "not installed" from "not running (or unreachable)" so the
# message points at the actual fix.
if ! command -v docker >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker does not appear to be installed."
    echo "   Install Docker, then run this again."
    echo ""
    launcher_pause
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker is installed but not running (or your user cannot reach it)."
    echo "   Start the Docker service, then run this again."
    echo ""
    launcher_pause
    exit 1
fi

# Catch a bad RS_PORT before Compose does, so the user gets a plain message
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
        xdg-open "$url" >/dev/null 2>&1 || \
            echo "Open $url in your browser."
    fi
else
    echo ""
    echo "❌ The server did not become ready in time. Please try again."
    echo "   If the port is already in use, pick another one by putting"
    echo "   RS_PORT=8888 in a file named .env next to this launcher."
    echo ""
    launcher_pause
    exit 1
fi
