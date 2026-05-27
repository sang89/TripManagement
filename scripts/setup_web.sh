#!/usr/bin/env bash
# Injects the Google Maps API key into web/index.html before running/building for web.
# The committed web/index.html contains %%MAPS_API_KEY%% as a placeholder.
#
# Usage:
#   scripts/setup_web.sh YOUR_KEY
#   scripts/setup_web.sh          # reads MAPS_API_KEY from environment
#
# The output is written to web/index.html.local (git-ignored).
# Then run:   flutter run -d chrome --web-launch-url http://localhost:PORT
# Or build:   flutter build web   (after running this script)
#
# In CI: set MAPS_API_KEY env var and pipe output to web/index.html before building.

set -euo pipefail

KEY="${1:-${MAPS_API_KEY:-}}"

if [[ -z "$KEY" ]]; then
  echo "Error: pass the API key as the first argument or set MAPS_API_KEY env var." >&2
  exit 1
fi

sed "s/%%MAPS_API_KEY%%/${KEY}/g" web/index.html > web/index.html.local
echo "✓ web/index.html.local created with key injected (git-ignored)."
echo "  Run flutter with: --web-renderer html (or use the .local file manually)."
