#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DIR="Apps/Mac/Sources/Assets.xcassets/AppIcon.appiconset"
SOURCE="$DIR/icon_1024x1024.png"

swift Scripts/generate-icon.swift

generate() {
    local pixels="$1"
    local name="$2"
    sips -z "$pixels" "$pixels" "$SOURCE" --out "$DIR/$name" >/dev/null
    echo "  $DIR/$name"
}

generate 16 icon_16x16.png
generate 32 icon_16x16@2x.png
generate 32 icon_32x32.png
generate 64 icon_32x32@2x.png
generate 128 icon_128x128.png
generate 256 icon_128x128@2x.png
generate 256 icon_256x256.png
generate 512 icon_256x256@2x.png
generate 512 icon_512x512.png
generate 1024 icon_512x512@2x.png

# The 1024 source is an intermediate; the appiconset references only the ten
# entries above. Keeping an unreferenced child makes actool warn.
rm -f "$SOURCE"

echo "图标已生成：$DIR"
