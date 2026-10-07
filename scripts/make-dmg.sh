#!/usr/bin/env bash
# Builds a signed + notarized DMG for free download: build/SpanishMenuBar-<version>.dmg
#
# Environment:
#   DEVELOPER_ID     "Developer ID Application: Your Name (TEAMID)". Unset → ad-hoc local test DMG (not distributable).
#   NOTARY_PROFILE   keychain profile created with `xcrun notarytool store-credentials`. Required with DEVELOPER_ID.
#   VERSION, BUILD_NUMBER, BUNDLE_ID   forwarded to build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
export VERSION
DMG="build/SpanishMenuBar-$VERSION.dmg"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    : "${NOTARY_PROFILE:?set NOTARY_PROFILE (xcrun notarytool store-credentials) to notarize}"
    SIGN_IDENTITY="$DEVELOPER_ID" scripts/build-app.sh
else
    echo "warning: DEVELOPER_ID not set — building an ad-hoc DMG that Gatekeeper will block on other Macs." >&2
    scripts/build-app.sh
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "build/Spanish Menu Bar.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Spanish Menu Bar" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
fi
echo "Created $DMG"
