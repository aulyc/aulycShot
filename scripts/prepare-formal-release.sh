#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STANDARDS_ROOT="${STANDARDS_ROOT:-/Users/crp/Projects/Codex 开发规范}"
TARGET_VERSION="${1:?usage: prepare-formal-release.sh <version> <build>}"
TARGET_BUILD="${2:?usage: prepare-formal-release.sh <version> <build>}"
cd "$ROOT"

[[ "$(git symbolic-ref --quiet --short HEAD)" == "main" ]] || { echo "error: formal releases must be prepared on main" >&2; exit 1; }
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: worktree must be clean before release metadata changes" >&2; exit 1; }

python3 "$STANDARDS_ROOT/scripts/formal_release_git.py" preflight --path "$ROOT"
python3 scripts/release_tool.py prepare --version "$TARGET_VERSION" --build "$TARGET_BUILD"

CHANGED="$(git diff --name-only | LC_ALL=C sort)"
[[ "$CHANGED" == $'CHANGELOG.md\nCHANGELOG.zh-CN.md\naulycShot/App/Info.plist' ]] || {
    echo "error: release preparation changed unexpected files" >&2
    printf '%s\n' "$CHANGED" >&2
    exit 1
}

git add CHANGELOG.md CHANGELOG.zh-CN.md aulycShot/App/Info.plist
git diff --cached --check
git commit -m "chore: release $TARGET_VERSION"
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: release metadata commit did not leave a clean worktree" >&2; exit 1; }
echo "Prepared formal release $TARGET_VERSION build $TARGET_BUILD"
