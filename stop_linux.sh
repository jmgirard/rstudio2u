#!/bin/bash
cd "$(dirname "$0")" || {
    echo "❌ Could not open the folder this launcher lives in: $(dirname "$0")"
    [ -n "${RS_LAUNCHER_NONINTERACTIVE:-}" ] || read -n 1 -s -r -p "Press any key to close..."
    exit 1
}

echo "Stopping rstudio2u..."
docker compose stop

echo ""
echo "✅ Server stopped. The files in your home folder are kept. Run"
echo "   ./start_linux.sh to start it again."
