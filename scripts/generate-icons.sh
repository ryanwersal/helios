#!/usr/bin/env bash
# Rebuild shipping assets from the generated brand masters (macOS tools only).
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" docs/branding/AppIcon.png --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" docs/branding/AppIcon.png --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o Sources/Helios/Resources/Branding/AppIcon.icns
sips -z 18 18 docs/branding/MenuBarTemplate.png --out Sources/Helios/Resources/Branding/MenuBarTemplate.png >/dev/null
sips -z 36 36 docs/branding/MenuBarTemplate.png --out Sources/Helios/Resources/Branding/MenuBarTemplate@2x.png >/dev/null
