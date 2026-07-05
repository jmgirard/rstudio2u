#!/bin/bash
cd "$(dirname "$0")"

# Allow future double-clicking without macOS Gatekeeper re-prompting
xattr -c "$0" 2>/dev/null
chmod u+x "$0" 2>/dev/null

echo "Starting rstudio2u..."

# Make sure Docker is running before doing anything else
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker does not appear to be running."
    echo "   Please open Docker Desktop, wait for it to finish starting,"
    echo "   then double-click this file again."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi

# Get the latest image, then start the server and wait until it is healthy
docker compose pull
if docker compose up -d --wait --wait-timeout 180; then
    echo ""
    echo "============================================================"
    echo "✅ RStudio Server is running at http://localhost:8787"
    echo "🚀 Opening your web browser..."
    echo "============================================================"
    echo ""
    open http://localhost:8787
else
    echo ""
    echo "❌ The server did not become ready in time. Please try again,"
    echo "   or check Docker Desktop for errors."
    echo ""
    read -n 1 -s -r -p "Press any key to close..."
    exit 1
fi
