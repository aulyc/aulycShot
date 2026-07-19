#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVENANCE="$(cd "$(dirname "${1:?usage: verify-formal-artifact.sh <provenance>}")" && pwd)/$(basename "$1")"
cd "$ROOT"
python3 scripts/release_tool.py verify-provenance --provenance "$PROVENANCE"
DMG_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["artifacts"][0]["file"])' "$PROVENANCE")"
DMG="$(dirname "$PROVENANCE")/$DMG_NAME"

xcrun stapler validate "$DMG"
spctl -a -vvv -t open --context context:primary-signature "$DMG"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aulycShot-verify.XXXXXX")"
MOUNT_POINT="$TEMP_ROOT/mount"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" == "1" ]]; then hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; fi
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=1
APP="$MOUNT_POINT/aulycShot.app"
python3 scripts/release_tool.py verify-app --provenance "$PROVENANCE" --app "$APP"
spctl -a -vvv -t exec "$APP"
hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNTED=0
echo "Formal DMG and mounted app verified"
