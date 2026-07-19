#!/bin/bash
set -e

# Build configuration
# - CONFIG=debug|release  (default: debug)
# - UNIVERSAL=1           build a fat arm64+x86_64 binary (default: host arch only)
CONFIG="${CONFIG:-debug}"
UNIVERSAL="${UNIVERSAL:-0}"

for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        --release)   CONFIG="release" ;;
        --debug)     CONFIG="debug" ;;
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

# Build binary
if [ "$UNIVERSAL" = "1" ]; then
    echo "Building aulycShot ($CONFIG, universal: arm64 + x86_64)..."
    swift build -c "$CONFIG" --arch arm64 --arch x86_64
    # SwiftPM emits the merged universal binary under .build/apple/Products/<Config>/
    CONFIG_CAP="$(tr '[:lower:]' '[:upper:]' <<< "${CONFIG:0:1}")${CONFIG:1}"
    BUILD_BIN=".build/apple/Products/$CONFIG_CAP/aulycShot"
    EXTENSION_BUILD_BIN=".build/apple/Products/$CONFIG_CAP/$EXTENSION_PRODUCT_NAME"
    if [ ! -f "$BUILD_BIN" ] || [ ! -f "$EXTENSION_BUILD_BIN" ]; then
        # Fallback: merge per-arch binaries with lipo
        ARM_BIN=".build/arm64-apple-macosx/$CONFIG/aulycShot"
        X86_BIN=".build/x86_64-apple-macosx/$CONFIG/aulycShot"
        EXTENSION_ARM_BIN=".build/arm64-apple-macosx/$CONFIG/$EXTENSION_PRODUCT_NAME"
        EXTENSION_X86_BIN=".build/x86_64-apple-macosx/$CONFIG/$EXTENSION_PRODUCT_NAME"
        if [ -f "$ARM_BIN" ] && [ -f "$X86_BIN" ]; then
            BUILD_BIN=".build/$CONFIG/aulycShot-universal"
            lipo -create -output "$BUILD_BIN" "$ARM_BIN" "$X86_BIN"
        else
            echo "error: universal binary not found at $BUILD_BIN and per-arch fallbacks missing" >&2
            exit 1
        fi
        if [ -f "$EXTENSION_ARM_BIN" ] && [ -f "$EXTENSION_X86_BIN" ]; then
            EXTENSION_BUILD_BIN=".build/$CONFIG/$EXTENSION_PRODUCT_NAME-universal"
            lipo -create -output "$EXTENSION_BUILD_BIN" "$EXTENSION_ARM_BIN" "$EXTENSION_X86_BIN"
        else
            echo "error: universal extension binary not found at $EXTENSION_BUILD_BIN and per-arch fallbacks missing" >&2
            exit 1
        fi
    fi
else
    echo "Building aulycShot ($CONFIG, host arch only)..."
    swift build -c "$CONFIG"
    BUILD_BIN=".build/$CONFIG/aulycShot"
    EXTENSION_BUILD_BIN=".build/$CONFIG/$EXTENSION_PRODUCT_NAME"
fi

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
cp "ThirdParty/PermissionFlow/LICENSE" "$RESOURCES/PermissionFlow-LICENSE.txt"

# Copy menu bar icon source. The SVG lives in design/ so tweaking it updates the
# app bundle on the next rebuild without touching Swift code.
cp "design/menuBarIcon.svg" "$RESOURCES/MenuBarIcon.svg"

# Copy localization bundles (.lproj). The app loads these directly for its
# in-app language picker — see Localizer.swift.
for lproj in Resources/*.lproj; do
    [ -d "$lproj" ] || continue
    cp -R "$lproj" "$RESOURCES/"
done

# Copy SwiftPM resource bundles. PermissionFlow uses Bundle.module for its
# floating authorization panel strings; if this bundle is absent, Intel builds
# crash with a Swift assertion the first time the panel is shown.
BUILD_DIR="$(dirname "$BUILD_BIN")"
PERMISSION_FLOW_BUNDLE="$BUILD_DIR/aulycShot_PermissionFlow.bundle"
if [ ! -d "$PERMISSION_FLOW_BUNDLE" ]; then
    echo "error: missing SwiftPM resource bundle: $PERMISSION_FLOW_BUNDLE" >&2
    exit 1
fi
cp -R "$PERMISSION_FLOW_BUNDLE" "$RESOURCES/"

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
sign_bundles() {
    local identity="$1"
    local timestamp_option="--timestamp"
    if [ "$identity" = "-" ]; then
        timestamp_option="--timestamp=none"
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
echo "To install and run from /Applications:"
echo "  bash scripts/rebuild-and-open.sh"
