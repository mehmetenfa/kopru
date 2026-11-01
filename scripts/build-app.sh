#!/bin/bash
# Köprü.app paketi üretir (release). Kullanım: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Köprü.app"; rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/KopruApp "$APP/Contents/MacOS/Kopru"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" 2>/dev/null || true
echo "✓ $APP"
