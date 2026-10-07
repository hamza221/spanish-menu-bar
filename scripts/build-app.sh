#!/usr/bin/env bash
# Builds a universal, sandboxed "build/Spanish Menu Bar.app".
#
# Environment (all optional):
#   SIGN_IDENTITY   codesign identity; default "-" (ad-hoc, local use only)
#   ENTITLEMENTS    entitlements plist; default Packaging/SpanishMenuBar.entitlements
#   PROFILE         provisioning profile to embed (Mac App Store builds)
#   BUNDLE_ID       default com.hamzamahjoubi.SpanishMenuBar
#   VERSION         marketing version; default 1.0.0
#   BUILD_NUMBER    must increase for every App Store upload; default: git commit count
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-Packaging/SpanishMenuBar.entitlements}"
BUNDLE_ID="${BUNDLE_ID:-com.hamzamahjoubi.SpanishMenuBar}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

APP="build/Spanish Menu Bar.app"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SpanishMenuBar" "$APP/Contents/MacOS/SpanishMenuBar"
cp Sources/SpanishMenuBarCore/Resources/es-en.xml "$APP/Contents/Resources/"
cp ThirdParty/en-es-en-Dic-LICENSE.txt "$APP/Contents/Resources/"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/"
sed -e "s/\$(BUNDLE_ID)/$BUNDLE_ID/" -e "s/\$(VERSION)/$VERSION/" -e "s/\$(BUILD_NUMBER)/$BUILD_NUMBER/" \
    Packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

if [[ -n "${PROFILE:-}" ]]; then
    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
fi
# Installed apps are owned by root; every file must stay world-readable (App Store error 90255).
chmod -R u+rwX,go+rX,go-w "$APP"
# Downloaded inputs (e.g. the provisioning profile) carry com.apple.quarantine, which the App Store rejects (ITMS-91109).
xattr -cr "$APP"

# Real identities need a secure timestamp (notarization); ad-hoc signatures can't have one.
TIMESTAMP="--timestamp"
[[ "$SIGN_IDENTITY" == "-" ]] && TIMESTAMP="--timestamp=none"
codesign --force --options runtime "$TIMESTAMP" --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, build $BUILD_NUMBER, signed: $SIGN_IDENTITY)"
