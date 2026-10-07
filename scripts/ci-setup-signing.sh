#!/usr/bin/env bash
# CI only: creates a temporary default keychain holding the signing identities and the notarytool profile
# "spanish-menu-bar", installs the App Store Connect API key for altool, and decodes the provisioning profile.
#
# Environment (GitHub secrets):
#   SIGNING_P12_BASE64      .p12 with the private key, the Developer ID Application, Apple Distribution and
#                           3rd Party Mac Developer Installer certificates, and their intermediate CAs
#   SIGNING_P12_PASSWORD    password of that .p12
#   ASC_KEY_ID              App Store Connect API key ID (App Manager role)
#   ASC_ISSUER_ID           App Store Connect issuer ID
#   ASC_KEY_P8_BASE64       the key's .p8, base64-encoded
#   MAS_PROFILE_BASE64      Mac App Store provisioning profile, base64-encoded (optional; App Store job only)
# Writes PROFILE=<path> to $GITHUB_ENV when MAS_PROFILE_BASE64 is set.
set -euo pipefail
: "${SIGNING_P12_BASE64:?}" "${SIGNING_P12_PASSWORD:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8_BASE64:?}"

KEYCHAIN="$RUNNER_TEMP/signing.keychain-db"
KEYCHAIN_PASSWORD="$(uuidgen)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

P12="$RUNNER_TEMP/signing.p12"
printf '%s' "$SIGNING_P12_BASE64" | base64 --decode > "$P12"
security import "$P12" -k "$KEYCHAIN" -P "$SIGNING_P12_PASSWORD" -f pkcs12 \
    -T /usr/bin/codesign -T /usr/bin/productbuild -T /usr/bin/security
rm -f "$P12"
# Let codesign/productbuild use the key without a UI prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
security default-keychain -d user -s "$KEYCHAIN"

KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR"
KEY_FILE="$KEY_DIR/AuthKey_$ASC_KEY_ID.p8"
printf '%s' "$ASC_KEY_P8_BASE64" | base64 --decode > "$KEY_FILE"
chmod 600 "$KEY_FILE"
xcrun notarytool store-credentials spanish-menu-bar \
    --key "$KEY_FILE" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --keychain "$KEYCHAIN"

if [[ -n "${MAS_PROFILE_BASE64:-}" ]]; then
    PROFILE_PATH="$RUNNER_TEMP/SpanishMenuBar.provisionprofile"
    printf '%s' "$MAS_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"
    echo "PROFILE=$PROFILE_PATH" >> "$GITHUB_ENV"
fi

security find-identity -v "$KEYCHAIN"
