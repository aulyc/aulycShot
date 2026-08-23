#!/bin/bash
set -e

# Build configuration
# - CONFIG=debug|release  (default: debug)
# - --sandboxed uses the project-local SwiftPM wrapper for Codex workspace-write
#   and similarly restricted executors
#
# aulycShot is Apple Silicon only. Every assembled App and share extension is
# built explicitly for arm64 so host architecture or stale build products
# cannot change the distributed architecture.
CONFIG="${CONFIG:-debug}"
SANDBOXED=0

for arg in "$@"; do
    case "$arg" in
        --release)   CONFIG="release" ;;
        --debug)     CONFIG="debug" ;;
        --sandboxed) SANDBOXED=1 ;;
        *)
            echo "error: unsupported bundle argument: $arg" >&2
            exit 64
            ;;
    esac
done

# Paths
APP_NAME="aulycShot.app"
APP_OUTPUT_DIR="${AULYCSHOT_APP_OUTPUT_DIR:-.cache/build}"
APP_DIR="$APP_OUTPUT_DIR/$APP_NAME"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
PLUGINS="$CONTENTS/PlugIns"
EXTENSION_PRODUCT_NAME="AulycShotShareExtension"
EXTENSION_NAME="$EXTENSION_PRODUCT_NAME.appex"
EXTENSION_DIR="$PLUGINS/$EXTENSION_NAME"
EXTENSION_CONTENTS="$EXTENSION_DIR/Contents"
EXTENSION_MACOS="$EXTENSION_CONTENTS/MacOS"
EXTENSION_RESOURCES="$EXTENSION_CONTENTS/Resources"

# Generated menu bar and application icons must match the canonical geometry
# and manifest before a build starts. Verification is read-only so exact-tag
# release worktrees remain clean.
bash scripts/generate-icon.sh --check

# Build binaries
echo "Building aulycShot ($CONFIG, arm64)..."
if [ "$SANDBOXED" -eq 1 ]; then
    swift_build=(scripts/swiftpm-sandbox.sh build)
else
    swift_build=(swift build)
fi
"${swift_build[@]}" -c "$CONFIG" --arch arm64
BUILD_BIN_DIR="$("${swift_build[@]}" -c "$CONFIG" --arch arm64 --show-bin-path)"
BUILD_BIN="$BUILD_BIN_DIR/aulycShot"
EXTENSION_BUILD_BIN="$BUILD_BIN_DIR/$EXTENSION_PRODUCT_NAME"

if [ ! -f "$BUILD_BIN" ]; then
    echo "error: app binary not found at $BUILD_BIN" >&2
    exit 1
fi

if [ ! -f "$EXTENSION_BUILD_BIN" ]; then
    echo "error: share extension binary not found at $EXTENSION_BUILD_BIN" >&2
    exit 1
fi

# Clean previous bundle
rm -rf "$APP_DIR"

# Create .app bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$EXTENSION_MACOS"
mkdir -p "$EXTENSION_RESOURCES"

# Copy binary
cp "$BUILD_BIN" "$MACOS/aulycShot"

# Copy share extension bundle
cp "$EXTENSION_BUILD_BIN" "$EXTENSION_MACOS/$EXTENSION_PRODUCT_NAME"
cp "aulycShot-share-extension/Info.plist" "$EXTENSION_CONTENTS/Info.plist"
cp "Resources/AppIcon.icns" "$EXTENSION_RESOURCES/AppIcon.icns"

# Copy Info.plist
cp "aulycShot/App/Info.plist" "$CONTENTS/Info.plist"
bash scripts/inject-build-metadata.sh "$CONTENTS/Info.plist"
APP_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CONTENTS/Info.plist")"
APP_BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$CONTENTS/Info.plist")"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_SHORT_VERSION" "$EXTENSION_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUNDLE_VERSION" "$EXTENSION_CONTENTS/Info.plist"

# Copy app icon
cp "Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

# Ship all license notices with the distributed application. The project is
# MIT-licensed and the original copyright notice must remain with copies.
cp "LICENSE" "$RESOURCES/LICENSE.txt"
cp "THIRD_PARTY_NOTICES.md" "$RESOURCES/THIRD_PARTY_NOTICES.md"

# Copy the generated menu bar icon. Its geometry shares design/iconMark.svg
# with AppIcon.icns; scripts/generate-icon.sh is the only update path.
cp "design/menuBarIcon.svg" "$RESOURCES/MenuBarIcon.svg"

# Copy the two supported localization bundles. The app loads these directly
# for its in-app language picker — see Localizer.swift.
for language in en zh-Hans; do
    lproj="Resources/$language.lproj"
    if [ ! -d "$lproj" ]; then
        echo "error: missing supported localization bundle: $lproj" >&2
        exit 1
    fi
    cp -R "$lproj" "$RESOURCES/"
done

python3 scripts/release_tool.py verify-runtime-resources --app "$APP_DIR"

# Code signing
# -----------------------------------------------------------------------------
# Use the project's stable Developer ID identity by default so local rebuilds
# keep the same macOS TCC identity as installed builds. Override with
# SIGN_IDENTITY when needed. REQUIRE_SIGNING=1 makes a missing identity fatal;
# ordinary development builds may still fall back to ad-hoc signing.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_SIGN_IDENTITY="Developer ID Application: nan ma (M9M7M2ARFD)"
SIGN_IDENTITY="${SIGN_IDENTITY:-$DEFAULT_SIGN_IDENTITY}"
REQUIRE_SIGNING="${REQUIRE_SIGNING:-0}"
APPLE_TIMESTAMP_URL="${APPLE_TIMESTAMP_URL:-}"
sign_bundles() {
    local identity="$1"
    local timestamp_option="--timestamp"
    if [ "$identity" = "-" ]; then
        timestamp_option="--timestamp=none"
    elif [ -n "$APPLE_TIMESTAMP_URL" ]; then
        timestamp_option="--timestamp=$APPLE_TIMESTAMP_URL"
    fi
    codesign --force --options runtime "$timestamp_option" \
        --entitlements "$SCRIPT_DIR/aulycShot-share-extension.entitlements" \
        --sign "$identity" "$EXTENSION_DIR"
    codesign --force --options runtime "$timestamp_option" \
        --entitlements "$SCRIPT_DIR/aulycShot.entitlements" \
        --sign "$identity" "$APP_DIR"
}

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Signing ad-hoc with Hardened Runtime"
    sign_bundles -
elif security find-identity -p codesigning 2>/dev/null | grep -qF "$SIGN_IDENTITY"; then
    echo "Signing with: $SIGN_IDENTITY"
    sign_bundles "$SIGN_IDENTITY"
else
    if [ "$REQUIRE_SIGNING" = "1" ]; then
        echo "error: required signing identity not found: $SIGN_IDENTITY" >&2
        exit 1
    fi
    echo "warning: '$SIGN_IDENTITY' not found in keychain — falling back to ad-hoc signing." >&2
    echo "warning: TCC permissions may not survive rebuilds without a stable signing identity." >&2
    sign_bundles -
fi

echo "✅ Built and signed $APP_DIR"
ARCHS=$(lipo -archs "$MACOS/aulycShot" 2>/dev/null || echo "unknown")
echo "   Architectures: $ARCHS"
echo ""
echo "To rebuild and run the local development app:"
echo "  bash scripts/rebuild-and-open.sh"
