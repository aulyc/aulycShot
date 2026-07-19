#!/bin/bash
set -euo pipefail

INFO_PLIST="${1:?Usage: inject-build-metadata.sh <Info.plist>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_COMMIT="${AULYCSHOT_BUILD_COMMIT:-}"
RELEASE_CHANNEL="${AULYCSHOT_RELEASE_CHANNEL:-local}"
RELEASE_TAG="${AULYCSHOT_RELEASE_TAG:-N/A}"
BUILD_DIRTY="${AULYCSHOT_BUILD_DIRTY:-}"

if [ ! -f "$INFO_PLIST" ]; then
    echo "error: Info.plist not found at $INFO_PLIST" >&2
    exit 1
fi

if [ -z "$BUILD_COMMIT" ]; then
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
        git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
        BUILD_COMMIT="$(git -C "$ROOT" rev-parse --short=7 HEAD)"
    else
        BUILD_COMMIT="unversioned"
    fi
fi

if [ -z "$BUILD_DIRTY" ]; then
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
        [ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]; then
        BUILD_DIRTY="false"
    else
        BUILD_DIRTY="true"
    fi
fi

if [[ ! "$BUILD_COMMIT" =~ ^([0-9a-fA-F]{7,}|unversioned)$ ]]; then
    echo "error: invalid Git build commit: $BUILD_COMMIT" >&2
    exit 1
fi

if [[ ! "$RELEASE_CHANNEL" =~ ^(local|formal-candidate|formal)$ ]]; then
    echo "error: invalid release channel: $RELEASE_CHANNEL" >&2
    exit 1
fi

if [[ ! "$BUILD_DIRTY" =~ ^(true|false)$ ]]; then
    echo "error: invalid build dirty value: $BUILD_DIRTY" >&2
    exit 1
fi

if ! /usr/libexec/PlistBuddy -c "Set :AulycShotGitCommit $BUILD_COMMIT" "$INFO_PLIST" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :AulycShotGitCommit string $BUILD_COMMIT" "$INFO_PLIST"
fi

if ! /usr/libexec/PlistBuddy -c "Set :AulycShotReleaseChannel $RELEASE_CHANNEL" "$INFO_PLIST" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :AulycShotReleaseChannel string $RELEASE_CHANNEL" "$INFO_PLIST"
fi

if ! /usr/libexec/PlistBuddy -c "Set :AulycShotReleaseTag $RELEASE_TAG" "$INFO_PLIST" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :AulycShotReleaseTag string $RELEASE_TAG" "$INFO_PLIST"
fi

if /usr/libexec/PlistBuddy -c "Print :AulycShotBuildDirty" "$INFO_PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Delete :AulycShotBuildDirty" "$INFO_PLIST"
fi
/usr/libexec/PlistBuddy -c "Add :AulycShotBuildDirty bool $BUILD_DIRTY" "$INFO_PLIST"

echo "Injected build identity: commit=$BUILD_COMMIT channel=$RELEASE_CHANNEL tag=$RELEASE_TAG dirty=$BUILD_DIRTY"
