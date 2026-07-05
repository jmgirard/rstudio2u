#!/bin/bash
cd "$(dirname "$0")"

echo "Starting rstudio2u..."

# Make sure Docker is running before doing anything else
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "❌ Docker does not appear to be running (or your user cannot reach it)."
    echo "   Start the Docker service, then run this again."
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
    xdg-open http://localhost:8787 >/dev/null 2>&1 || \
        echo "Open http://localhost:8787 in your browser."
else
    echo ""
    echo "❌ The server did not become ready in time. Please try again."
    echo ""
    exit 1
fi
