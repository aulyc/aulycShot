#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVENANCE="$(cd "$(dirname "${1:?usage: install-release.sh <provenance>}")" && pwd)/$(basename "$1")"
TARGET="/Applications/aulycShot.app"
BACKUP="/Applications/.aulycShot.backup.$$"
cd "$ROOT"
bash scripts/verify-formal-artifact.sh "$PROVENANCE"
DMG_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["artifacts"][0]["file"])' "$PROVENANCE")"
DMG="$(dirname "$PROVENANCE")/$DMG_NAME"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aulycShot-install.XXXXXX")"
MOUNT_POINT="$TEMP_ROOT/mount"
MOUNTED=0
BACKED_UP=0
REPLACEMENT_WRITTEN=0
INSTALLED=0
cleanup() {
    if [[ "$MOUNTED" == "1" ]]; then hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; fi
    if [[ "$INSTALLED" != "1" && "$REPLACEMENT_WRITTEN" == "1" ]]; then
        pkill -x aulycShot >/dev/null 2>&1 || true
        rm -rf "$TARGET"
        if [[ "$BACKED_UP" == "1" ]]; then mv "$BACKUP" "$TARGET"; fi
    fi
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=1

pkill -x aulycShot >/dev/null 2>&1 || true
[[ ! -e "$BACKUP" ]] || { echo "error: backup path already exists: $BACKUP" >&2; exit 1; }
if [[ -d "$TARGET" ]]; then
    mv "$TARGET" "$BACKUP"
    BACKED_UP=1
fi
ditto "$MOUNT_POINT/aulycShot.app" "$TARGET"
REPLACEMENT_WRITTEN=1
bash scripts/verify-installed.sh "$PROVENANCE"

hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNTED=0
open "$TARGET"
for _ in $(seq 1 50); do
    PID="$(pgrep -x aulycShot | head -1 || true)"
    if [[ -n "$PID" ]]; then
        COMMAND="$(ps -p "$PID" -o command=)"
        [[ "$COMMAND" == "$TARGET/Contents/MacOS/aulycShot" ]] || { echo "error: running process is not the installed formal app" >&2; exit 1; }
        INSTALLED=1
        if [[ "$BACKED_UP" == "1" ]]; then rm -rf "$BACKUP"; fi
        echo "Installed and launched formal app at $TARGET (PID $PID)"
        exit 0
    fi
    sleep 0.1
done
echo "error: installed formal app did not launch" >&2
exit 1
