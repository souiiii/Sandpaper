#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build -c release --product Sandpaper
products="$(swift build -c release --show-bin-path)"
app="$project_root/.build/macos/Sandpaper.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$products/Sandpaper" "$app/Contents/MacOS/Sandpaper"
cp App/Info.plist "$app/Contents/Info.plist"
shopt -s nullglob
for resource in "$products"/*.bundle; do
    ditto "$resource" "$app/Contents/Resources/$(basename "$resource")"
done
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
