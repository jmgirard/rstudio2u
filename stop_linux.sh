#!/bin/bash
cd "$(dirname "$0")"

echo "Stopping rstudio2u..."
docker compose stop

echo ""
echo "✅ Server stopped. Your work is preserved -- run ./start_linux.sh"
echo "   to resume where you left off."
