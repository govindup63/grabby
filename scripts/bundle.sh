#!/bin/bash
# Builds GrabbyApp in release, wraps it in build/Grabby.app and signs it with the
# Apple Development identity so the Accessibility grant survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${GRABBY_SIGN_IDENTITY:-Apple Development: govindup63@gmail.com (Y9N4XD635T)}"
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "bundle.sh: signing identity not found in keychain: $IDENTITY" >&2
    echo "bundle.sh: set GRABBY_SIGN_IDENTITY to one listed by: security find-identity -v -p codesigning" >&2
    exit 1
fi

swift build -c release --product GrabbyApp
BIN="$(swift build -c release --product GrabbyApp --show-bin-path)/GrabbyApp"

APP=build/Grabby.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Grabby"
cp Sources/GrabbyApp/Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Authority' | head -3
echo "bundle.sh: built $APP"
