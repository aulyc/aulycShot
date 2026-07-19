#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARDS_ROOT="${STANDARDS_ROOT:-/Users/crp/Projects/Codex 开发规范}"
PROVENANCE="$(cd "$(dirname "${1:?usage: publish-release.sh <provenance>}")" && pwd)/$(basename "$1")"
cd "$ROOT"

bash scripts/verify-formal-artifact.sh "$PROVENANCE"
bash scripts/verify-installed.sh "$PROVENANCE"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$PROVENANCE")"
DMG_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["artifacts"][0]["file"])' "$PROVENANCE")"
DMG="$(dirname "$PROVENANCE")/$DMG_NAME"

python3 "$STANDARDS_ROOT/scripts/formal_release_git.py" push \
    --path "$ROOT" --tag "$VERSION" --provenance "$PROVENANCE"

PROVENANCE_SHA="$(shasum -a 256 "$PROVENANCE" | awk '{print $1}')"
printf '%s  %s\n' "$PROVENANCE_SHA" "$(basename "$PROVENANCE")" > "$PROVENANCE.sha256"
python3 "$STANDARDS_ROOT/scripts/formal_release_git.py" verify \
    --path "$ROOT" --tag "$VERSION" --provenance "$PROVENANCE"

NOTES="$(dirname "$PROVENANCE")/aulycShot-$VERSION-release-notes.md"
python3 scripts/release_tool.py release-notes --version "$VERSION" --output "$NOTES"
if gh release view "$VERSION" --repo aulyc/aulycShot >/dev/null 2>&1; then
    echo "error: GitHub Release $VERSION already exists" >&2
    exit 1
fi
gh release create "$VERSION" \
    --repo aulyc/aulycShot \
    --verify-tag \
    --title "aulycShot $VERSION" \
    --notes-file "$NOTES" \
    "$DMG" "$DMG.sha256" "$PROVENANCE" "$PROVENANCE.sha256"
gh release view "$VERSION" --repo aulyc/aulycShot --json tagName,isDraft,isPrerelease,url
echo "Published private GitHub Release $VERSION without Homebrew dispatch"
