#!/usr/bin/env bash
# Builds a signed installer package for Mac App Store upload: build/SpanishMenuBar-AppStore-<version>.pkg
# Upload it with Apple's Transporter app (free on the Mac App Store).
#
# Environment (required):
#   APP_IDENTITY        "Apple Distribution: Your Name (TEAMID)"
#   INSTALLER_IDENTITY  "3rd Party Mac Developer Installer: Your Name (TEAMID)"
#   TEAM_ID             10-character team ID
#   PROFILE             Mac App Store provisioning profile (.provisionprofile) for BUNDLE_ID
#   BUILD_NUMBER        must be higher than any previous upload
# Optional: VERSION, BUNDLE_ID
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APP_IDENTITY:?}" "${INSTALLER_IDENTITY:?}" "${TEAM_ID:?}" "${PROFILE:?}" "${BUILD_NUMBER:?}"
VERSION="${VERSION:-$(cat VERSION)}"
BUNDLE_ID="${BUNDLE_ID:-com.hamzamahjoubi.SpanishMenuBar}"
export VERSION BUNDLE_ID BUILD_NUMBER PROFILE

# App Store builds need the application/team identifiers matching the provisioning profile.
ENTITLEMENTS="$(mktemp -t mas-entitlements)"
trap 'rm -f "$ENTITLEMENTS"' EXIT
cp Packaging/SpanishMenuBar.entitlements "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"

SIGN_IDENTITY="$APP_IDENTITY" ENTITLEMENTS="$ENTITLEMENTS" scripts/build-app.sh

PKG="build/SpanishMenuBar-AppStore-$VERSION.pkg"
productbuild --component "build/Spanish Menu Bar.app" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"
echo "Created $PKG — upload with Transporter."
