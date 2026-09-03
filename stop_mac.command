#!/bin/bash
cd "$(dirname "$0")" || {
    echo "❌ Could not open the folder this launcher lives in: $(dirname "$0")"
    [ -n "${RS_LAUNCHER_NONINTERACTIVE:-}" ] || read -n 1 -s -r -p "Press any key to close..."
    exit 1
}

# Allow future double-clicking without macOS Gatekeeper re-prompting
xattr -c "$0" 2>/dev/null
chmod u+x "$0" 2>/dev/null

echo "Stopping rstudio2u..."
docker compose stop

echo ""
echo "✅ Server stopped. Your work is preserved -- double-click"
echo "   start_mac.command to resume where you left off."
echo ""
read -n 1 -s -r -p "Press any key to close..."
