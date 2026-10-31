#!/usr/bin/env bash
# Runs the settings window's backend against a throwaway config and prints its URL, so the page can
# be opened in any browser, on any machine, without SwiftBar or a real config. Ctrl-C stops it.
#
#   scripts/settings-dev.sh [CONFIG_JSON]
#
# Set PYTHON to pick an interpreter. Browse and Add repo need the plugin and macOS, so they do nothing here. Everything else works.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK=$(mktemp -d)
CONFIG=${1:-$WORK/config.json}
PY=${PYTHON:-$(command -v python3 || command -v python || true)}

[ -n "$PY" ] || {
  echo "python3 is needed to run the settings backend." >&2
  exit 1
}

cleanup() {
  [ -n "${HELPER:-}" ] && kill "$HELPER" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

if [ ! -f "$CONFIG" ]; then
  cat > "$CONFIG" <<'JSON'
{
  "version": 1,
  "roots": [
    "~/Projects"
  ],
  "idleStopHours": "4",
  "editor": "",
  "repos": {
    "acme/storefront": {
      "name": "storefront",
      "path": "~/Projects/storefront",
      "ports": "4200-4209",
      "defaultPort": "4200",
      "copyIfMissing": ".env.local",
      "modes": [
        {
          "name": "Local",
          "start": "PORT={port} npm run dev",
          "url": "http://localhost:{port}",
          "defaultPortUrl": "http://storefront.test"
        },
        {
          "name": "Staging API",
          "start": "PORT={port} npm run dev:staging",
          "url": "http://localhost:{port}",
          "detect": "dev:staging"
        }
      ]
    }
  }
}
JSON
fi

cd "$ROOT/src/settings"
"$PY" -I server.py "$CONFIG" "$ROOT/src/dev-servers.sh" index.html "$WORK/info" dev &
HELPER=$!

for _ in $(seq 1 200); do
  [ -s "$WORK/info" ] && break
  sleep 0.05
done
[ -s "$WORK/info" ] || {
  echo "The settings backend didn't start." >&2
  exit 1
}

IFS=$'\t' read -r _ port token _ < "$WORK/info"
echo "Settings page:  http://127.0.0.1:$port/?t=$token"
echo "Config file:    $CONFIG"
echo "Ctrl-C to stop."
wait "$HELPER"
