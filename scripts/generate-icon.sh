#!/usr/bin/env bash
# Regenerate every icon asset from design/iconMark.svg.
# Usage: scripts/generate-icon.sh [--check]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" == "--check" ]]; then
    [[ $# -eq 1 ]] || { echo "error: --check takes no additional arguments" >&2; exit 64; }
    exec python3 scripts/icon_assets.py check
elif [[ $# -ne 0 ]]; then
    echo "error: unsupported icon generation argument: $1" >&2
    exit 64
fi

python3 scripts/icon_assets.py generate-svgs
SRC="$ROOT/design/appIcon.svg"

ICNS_OUT="$ROOT/Resources/AppIcon.icns"
APPICONSET="$ROOT/Resources/Assets.xcassets/AppIcon.appiconset"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "==> rendering $SRC → 1024x1024 master PNG"
MASTER="$WORK/master.png"
MODULE_CACHE="$WORK/module-cache"
mkdir -p "$MODULE_CACHE"
# Some macOS releases cannot decode modern SVG features through sips. Render
# through AppKit instead so the transparent squircle padding remains intact.
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" \
  swift -module-cache-path "$MODULE_CACHE" \
  "$ROOT/scripts/render-svg.swift" "$SRC" "$MASTER" 1024
[[ -f "$MASTER" ]] || { echo "error: SVG renderer failed to produce $MASTER" >&2; exit 1; }

# iconutil expects these specific filenames inside the .iconset folder.
declare -a SPECS=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for spec in "${SPECS[@]}"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    dst="$ICONSET/$name"
    cp "$MASTER" "$dst"
    sips -z "$size" "$size" "$dst" >/dev/null
done

echo "==> iconutil → $ICNS_OUT"
mkdir -p "$(dirname "$ICNS_OUT")"
iconutil -c icns "$ICONSET" -o "$ICNS_OUT"

# Mirror the PNGs into the asset catalog so an Xcode build (if ever used) picks them up.
echo "==> populating $APPICONSET"
mkdir -p "$APPICONSET"
declare -a CATALOG=(
    "16:icon_16.png"
    "32:icon_16@2x.png"
    "32:icon_32.png"
    "64:icon_32@2x.png"
    "128:icon_128.png"
    "256:icon_128@2x.png"
    "256:icon_256.png"
    "512:icon_256@2x.png"
    "512:icon_512.png"
    "1024:icon_512@2x.png"
)
for spec in "${CATALOG[@]}"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    dst="$APPICONSET/$name"
    cp "$MASTER" "$dst"
    sips -z "$size" "$size" "$dst" >/dev/null
done

# Refresh Contents.json so each entry references its filename.
cat > "$APPICONSET/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "16x16",   "filename": "icon_16.png" },
    { "idiom": "mac", "scale": "2x", "size": "16x16",   "filename": "icon_16@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "32x32",   "filename": "icon_32.png" },
    { "idiom": "mac", "scale": "2x", "size": "32x32",   "filename": "icon_32@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128.png" },
    { "idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256.png" },
    { "idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512.png" },
    { "idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512@2x.png" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
JSON

python3 scripts/icon_assets.py write-manifest
echo "==> done."
echo "    icns:    $ICNS_OUT"
echo "    catalog: $APPICONSET"
