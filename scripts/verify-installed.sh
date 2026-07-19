#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVENANCE="$(cd "$(dirname "${1:?usage: verify-installed.sh <provenance>}")" && pwd)/$(basename "$1")"
APP="/Applications/aulycShot.app"
[[ -d "$APP" ]] || { echo "error: $APP is not installed" >&2; exit 1; }
python3 "$ROOT/scripts/release_tool.py" verify-app --provenance "$PROVENANCE" --app "$APP"
spctl -a -vvv -t exec "$APP"
echo "Installed formal app verified at $APP"
