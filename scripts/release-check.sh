#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARDS_ROOT="${STANDARDS_ROOT:-/Users/crp/Projects/Codex 开发规范}"
cd "$ROOT"

python3 scripts/release_tool.py version-check --release
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' aulycShot/App/Info.plist)"
HEAD_COMMIT="$(git rev-parse HEAD)"

[[ "$(git symbolic-ref --quiet --short HEAD)" == "main" ]] || { echo "error: release check requires main" >&2; exit 1; }
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: release check requires a clean worktree" >&2; exit 1; }
[[ "$(git log -1 --pretty=%s)" == "chore: release $VERSION" ]] || { echo "error: HEAD is not the dedicated release metadata commit" >&2; exit 1; }

CHANGED="$(git diff-tree --no-commit-id --name-only -r HEAD | sort)"
[[ "$CHANGED" == $'CHANGELOG.md\naulycShot/App/Info.plist' ]] || {
    echo "error: release metadata commit contains unexpected files" >&2
    printf '%s\n' "$CHANGED" >&2
    exit 1
}

python3 "$STANDARDS_ROOT/scripts/standards_check.py" project --path "$ROOT" --strict
bash scripts/compile-check.sh
PYTHONPYCACHEPREFIX=/tmp/aulycShot-pycache python3 -m unittest discover -s Tests -p 'test_*.py'
swift build -c debug
swift test

APP_OUTPUT="$ROOT/.cache/formal-candidate"
AULYCSHOT_APP_OUTPUT_DIR="$APP_OUTPUT" \
AULYCSHOT_BUILD_COMMIT="$HEAD_COMMIT" \
AULYCSHOT_RELEASE_CHANNEL="formal-candidate" \
AULYCSHOT_RELEASE_TAG="N/A" \
AULYCSHOT_BUILD_DIRTY="false" \
CONFIG=release REQUIRE_SIGNING=1 \
bash scripts/bundle.sh

APP="$APP_OUTPUT/aulycShot.app"
codesign --verify --deep --strict --verbose=2 "$APP"
APP_ARCHS="$(lipo -archs "$APP/Contents/MacOS/aulycShot")"
EXT_ARCHS="$(lipo -archs "$APP/Contents/PlugIns/AulycShotShareExtension.appex/Contents/MacOS/AulycShotShareExtension")"
[[ "$APP_ARCHS" == "arm64" ]] || { echo "error: candidate app is not arm64-only: $APP_ARCHS" >&2; exit 1; }
[[ "$EXT_ARCHS" == "arm64" ]] || { echo "error: candidate extension is not arm64-only: $EXT_ARCHS" >&2; exit 1; }
SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP" 2>&1)"
[[ "$SIGNATURE_INFO" == *"Developer ID Application:"* ]] || { echo "error: candidate is not Developer ID signed" >&2; exit 1; }
[[ "$SIGNATURE_INFO" == *"(runtime)"* ]] || { echo "error: candidate is missing Hardened Runtime" >&2; exit 1; }
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: candidate build modified the source worktree" >&2; exit 1; }

echo "Release check passed for $VERSION at $HEAD_COMMIT"
