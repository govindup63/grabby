#!/bin/bash
# Builds GrabbyApp in release, wraps it in build/Grabby.app and signs it with the
# Apple Development identity so the Accessibility grant survives rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

# GRABBY_SIGN_IDENTITY: a codesigning identity name, or "-" for ad-hoc signing (CI, or no Apple ID).
# A stable identity matters on a dev machine: the Accessibility grant is keyed to the signature.
IDENTITY="${GRABBY_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep -oE '"(Developer ID Application|Apple Development)[^"]*"' | head -1 | tr -d '"')"
    IDENTITY="${IDENTITY:--}"
fi
if [ "$IDENTITY" != "-" ] && ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "bundle.sh: signing identity not found in keychain: $IDENTITY" >&2
    echo "bundle.sh: set GRABBY_SIGN_IDENTITY to one listed by: security find-identity -v -p codesigning, or to - for ad-hoc" >&2
    exit 1
fi
echo "bundle.sh: signing with ${IDENTITY/-/ad-hoc identity}"

swift build -c release --product GrabbyApp
BIN="$(swift build -c release --product GrabbyApp --show-bin-path)/GrabbyApp"

APP=build/Grabby.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Grabby"
cp Sources/GrabbyApp/Resources/Info.plist "$APP/Contents/Info.plist"
cp Sources/GrabbyApp/Resources/AppIcon.icns Sources/GrabbyApp/Resources/MenuBarTemplate.png Sources/GrabbyApp/Resources/MenuBarTemplate@2x.png "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --sign "$IDENTITY" "$APP"
fi
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Authority|Signature' | head -3
echo "bundle.sh: built $APP"
