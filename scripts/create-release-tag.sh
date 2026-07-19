#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/release-check.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' aulycShot/App/Info.plist)"
HEAD_COMMIT="$(git rev-parse HEAD)"

if git rev-parse --verify "refs/tags/$VERSION" >/dev/null 2>&1; then
    git rev-parse --verify "refs/tags/$VERSION^{tag}" >/dev/null
    [[ "$(git rev-list -n 1 "refs/tags/$VERSION")" == "$HEAD_COMMIT" ]] || { echo "error: existing tag points elsewhere" >&2; exit 1; }
    echo "Verified existing annotated tag $VERSION"
else
    git tag -a "$VERSION" -m "aulycShot $VERSION"
    echo "Created annotated tag $VERSION"
fi
