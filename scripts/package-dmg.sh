#!/usr/bin/env bash
# Build the .app, then package it into a draggable DMG and pop the install
# window for quick testing.
#
# Usage: scripts/package-dmg.sh
# Env:   OPEN_DMG_ON_SUCCESS=0   skip the auto-open at the end
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="aulycShot"
VOLNAME="aulycShot"
APP_OUTPUT_DIR="${AULYCSHOT_APP_OUTPUT_DIR:-$ROOT/.cache/build}"
APP="$APP_OUTPUT_DIR/${APP_NAME}.app"
DIST="$ROOT/dist"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/aulycShot/App/Info.plist")
DMG="$DIST/${APP_NAME}-${VERSION}-arm64.dmg"

echo "==> building .app (release, arm64)"
CONFIG=release bash "$ROOT/scripts/bundle.sh"
[[ -d "$APP" ]] || { echo "error: $APP missing after build" >&2; exit 1; }

# Sanity-check: DMGs are shipped to users, so the binary must be arm64-only.
ARCHS="$(lipo -archs "$APP/Contents/MacOS/aulycShot" 2>/dev/null || true)"
if [[ "$ARCHS" != "arm64" ]]; then
    echo "error: bundled binary is not arm64-only (archs: $ARCHS)" >&2
    exit 1
fi
echo "==> binary archs: $ARCHS"

echo "==> creating $DMG"
bash "$ROOT/scripts/create-dmg.sh" "$APP" "$DMG" "$VOLNAME"

SHA256=$(shasum -a 256 "$DMG" | awk '{print $1}')
printf '%s  %s\n' "$SHA256" "$(basename "$DMG")" > "${DMG}.sha256"

SIZE=$(du -h "$DMG" | awk '{print $1}')
echo ""
echo "SUCCESS: $DMG ($SIZE)"
echo "    sha256: ${DMG}.sha256"
echo "    drag ${APP_NAME}.app into Applications when the window opens."

if [[ "${OPEN_DMG_ON_SUCCESS:-1}" == "1" ]]; then
    echo "==> opening DMG"
    open "$DMG" || true
fi
