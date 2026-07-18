#!/bin/bash
cd "$(dirname "$0")"

echo "Starting rstudio2u..."

# Distinguish "not installed" from "not running (or unreachable)" so the
# message points at the actual fix.
if ! command -v docker >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker does not appear to be installed."
    echo "   Install Docker, then run this again."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker is installed but not running (or your user cannot reach it)."
    echo "   Start the Docker service, then run this again."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

# A pull failure is a different problem from a slow or unhealthy start.
if ! docker compose pull; then
    echo ""
    echo "❌ Could not download the latest image."
    echo "   Check your internet connection and that you can reach Docker Hub,"
    echo "   then try again."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

# Start the server and wait until it is healthy
if docker compose up -d --wait --wait-timeout 180; then
    echo ""
    echo "============================================================"
    echo "✅ RStudio Server is running at http://localhost:8787"
    echo "🚀 Opening your web browser..."
    echo "============================================================"
    echo ""
    xdg-open http://localhost:8787 >/dev/null 2>&1 || \
        echo "Open http://localhost:8787 in your browser."
else
    echo ""
    echo "❌ The server did not become ready in time. Please try again."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi
