#!/usr/bin/env bash
# Render reproducible de la infografía (HTML -> PNG) sin dependencias externas:
# usa el Chromium de Playwright ya presente en el host + las librerías de /home/dsh/tools/libs.
set -euo pipefail
HS="$HOME/.cache/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell"
FF="$HOME/.cache/ms-playwright/firefox-1538/firefox"
export LD_LIBRARY_PATH="/home/dsh/tools/libs/usr/lib/x86_64-linux-gnu:${FF}:${LD_LIBRARY_PATH:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${1:-1400}"; H="${2:-1900}"
"$HS" --no-sandbox --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
      --screenshot="${DIR}/infografia_proyecto.png" --window-size="${W},${H}" \
      "file://${DIR}/infografia_proyecto.html" 2>/dev/null
echo "OK: ${DIR}/infografia_proyecto.png (${W}x${H})"
