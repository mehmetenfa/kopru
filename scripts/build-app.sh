#!/bin/bash
# Köprü.app (evrensel: Apple Silicon + Intel) üretir. Kullanım: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
swift build -c release --arch arm64 --arch x86_64
BIN=".build/apple/Products/Release"
APP="build/Köprü.app"; rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/KopruApp" "$APP/Contents/MacOS/Kopru"
cp "$BIN/kopru" "$APP/Contents/Resources/kopru"        # komut satırı aracı
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "✓ $APP (v$VERSION)"; lipo -archs "$APP/Contents/MacOS/Kopru"
