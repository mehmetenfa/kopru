#!/bin/bash
# build/Köprü.app'ten sürüm dosyalarını üretir: dist/Kopru-<sürüm>.dmg ve .zip
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
[ -d "build/Köprü.app" ] || scripts/build-app.sh
rm -rf dist build/dmg && mkdir -p dist build/dmg
cp -R "build/Köprü.app" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "Köprü" -srcfolder build/dmg -ov -format UDZO "dist/Kopru-$VERSION.dmg" >/dev/null
ditto -c -k --keepParent "build/Köprü.app" "dist/Kopru-$VERSION.zip"
( cd dist && shasum -a 256 Kopru-$VERSION.* > SHA256SUMS.txt )
ls -la dist
