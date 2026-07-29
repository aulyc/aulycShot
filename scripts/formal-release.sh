#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="${DEVELOPER_ID_APPLICATION:?DEVELOPER_ID_APPLICATION is required}"
NOTARY_PROFILE="${NOTARY_PROFILE:?NOTARY_PROFILE is required}"
APPLE_TIMESTAMP_URL="${APPLE_TIMESTAMP_URL:-http://timestamp.apple.com/ts01}"
cd "$ROOT"

python3 scripts/release_tool.py version-check --release
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' aulycShot/App/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' aulycShot/App/Info.plist)"
COMMIT="$(git rev-parse HEAD)"
TAG="${RELEASE_TAG:-$VERSION}"
[[ "$TAG" == "$VERSION" ]] || { echo "error: formal tag must equal the version" >&2; exit 1; }
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: formal release requires a clean worktree" >&2; exit 1; }
git rev-parse --verify "refs/tags/$TAG^{tag}" >/dev/null
[[ "$(git rev-list -n 1 "refs/tags/$TAG")" == "$COMMIT" ]] || { echo "error: formal tag does not point to HEAD" >&2; exit 1; }

DIST="$ROOT/dist"
DMG="$DIST/aulycShot-$VERSION-build.$BUILD-arm64.dmg"
PROVENANCE="$DIST/aulycShot-$VERSION-build.$BUILD-arm64.release-provenance.json"
for output in "$DMG" "$DMG.sha256" "$PROVENANCE" "$PROVENANCE.sha256"; do
    [[ ! -e "$output" ]] || { echo "error: refusing to overwrite $output" >&2; exit 1; }
done

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aulycShot-formal.XXXXXX")"
SOURCE="$TEMP_ROOT/source"
APP_OUTPUT="$TEMP_ROOT/output"
MOUNT_POINT="$TEMP_ROOT/mount"
MOUNTED=0
WORKTREE_ADDED=0
cleanup() {
    if [[ "$MOUNTED" == "1" ]]; then hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; fi
    if [[ "$WORKTREE_ADDED" == "1" ]]; then git -C "$ROOT" worktree remove --force "$SOURCE" >/dev/null 2>&1 || true; fi
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$DIST" "$APP_OUTPUT" "$MOUNT_POINT"
git worktree add --detach "$SOURCE" "$TAG"
WORKTREE_ADDED=1
[[ -z "$(git -C "$SOURCE" status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: exact-tag source is dirty before build" >&2; exit 1; }

cd "$SOURCE"
AULYCSHOT_APP_OUTPUT_DIR="$APP_OUTPUT" \
AULYCSHOT_BUILD_COMMIT="$COMMIT" \
AULYCSHOT_RELEASE_CHANNEL="formal" \
AULYCSHOT_RELEASE_TAG="$TAG" \
AULYCSHOT_BUILD_DIRTY="false" \
CONFIG=release REQUIRE_SIGNING=1 SIGN_IDENTITY="$IDENTITY" \
bash scripts/bundle.sh
APP="$APP_OUTPUT/aulycShot.app"

codesign --verify --deep --strict --verbose=2 "$APP"
APP_ARCHS="$(lipo -archs "$APP/Contents/MacOS/aulycShot")"
EXT_ARCHS="$(lipo -archs "$APP/Contents/PlugIns/AulycShotShareExtension.appex/Contents/MacOS/AulycShotShareExtension")"
[[ "$APP_ARCHS" == "arm64" ]] || { echo "error: formal app is not arm64-only: $APP_ARCHS" >&2; exit 1; }
[[ "$EXT_ARCHS" == "arm64" ]] || { echo "error: formal extension is not arm64-only: $EXT_ARCHS" >&2; exit 1; }
SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP" 2>&1)"
[[ "$SIGNATURE_INFO" == *"Developer ID Application:"* && "$SIGNATURE_INFO" == *"(runtime)"* ]] || { echo "error: formal App signature is invalid" >&2; exit 1; }

bash scripts/create-dmg.sh "$APP" "$DMG" "aulycShot"
codesign --force --sign "$IDENTITY" "--timestamp=$APPLE_TIMESTAMP_URL" "$DMG"
codesign --verify --verbose=2 "$DMG"

NOTARY_RESULT="$TEMP_ROOT/notary-result.json"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$NOTARY_RESULT"
NOTARY_STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "$NOTARY_RESULT")"
NOTARY_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["id"])' "$NOTARY_RESULT")"
[[ "$NOTARY_STATUS" == "Accepted" ]] || { echo "error: Apple notarization status is $NOTARY_STATUS" >&2; exit 1; }

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vvv -t open --context context:primary-signature "$DMG"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
MOUNTED=1
MOUNTED_APP="$MOUNT_POINT/aulycShot.app"
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"
spctl -a -vvv -t exec "$MOUNTED_APP"

python3 scripts/release_tool.py write-provenance \
    --source-root "$SOURCE" \
    --app "$MOUNTED_APP" \
    --dmg "$DMG" \
    --output "$PROVENANCE" \
    --tag "$TAG" \
    --submission-id "$NOTARY_ID"

hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNTED=0
[[ -z "$(git -C "$SOURCE" status --porcelain=v1 --untracked-files=all)" ]] || { echo "error: exact-tag source is dirty after build" >&2; exit 1; }

DMG_SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
PROVENANCE_SHA="$(shasum -a 256 "$PROVENANCE" | awk '{print $1}')"
printf '%s  %s\n' "$DMG_SHA" "$(basename "$DMG")" > "$DMG.sha256"
printf '%s  %s\n' "$PROVENANCE_SHA" "$(basename "$PROVENANCE")" > "$PROVENANCE.sha256"

echo "Formal artifact verified"
echo "$DMG"
echo "$PROVENANCE"
