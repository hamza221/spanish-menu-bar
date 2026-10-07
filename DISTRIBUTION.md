# Distribution

Spanish Menu Bar ships two ways from the same sandboxed build:

| Channel | Certificate(s) | Script | Output |
| --- | --- | --- | --- |
| Free DMG (GitHub Releases) | Developer ID Application | `scripts/make-dmg.sh` | `build/SpanishMenuBar-<version>.dmg`, notarized and stapled |
| Mac App Store | Apple Distribution + Mac Installer Distribution | `scripts/make-appstore-pkg.sh` | `build/SpanishMenuBar-AppStore-<version>.pkg` |

Both need a paid Apple Developer Program membership. Your **Team ID** is shown at
<https://developer.apple.com/account> → Membership details.

## One-time setup

1. **Xcode.** Sign in at Xcode → Settings → Accounts with your Apple ID. `notarytool` and `stapler` ship with the
   Command Line Tools. Point `xcode-select` at Xcode only if you want `altool`:
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
2. **Bundle ID.** The default is `com.hamzamahjoubi.SpanishMenuBar`. To use another one, set `BUNDLE_ID=…` for
   every script call. Register it at developer.apple.com → Certificates, IDs & Profiles → Identifiers → **+** →
   App IDs → App, platform macOS, explicit Bundle ID. No extra capabilities are needed.
3. **Certificates.** In Xcode → Settings → Accounts → *your team* → Manage Certificates → **+**, create:
   - **Developer ID Application** (DMG). Only the Account Holder can create it.
   - **Apple Distribution** (App Store app signature).
   - **Mac Installer Distribution** (App Store `.pkg`). In the keychain it is named
     *3rd Party Mac Developer Installer: …*.

   Check the exact names with:
   ```sh
   security find-identity -v -p codesigning     # app identities
   security find-identity -v | grep Installer   # installer identity
   ```

## Free DMG

1. **Store notarization credentials** once, using an App Store Connect API key (Users and Access →
   Integrations → Team Keys, role *Developer*; the `.p8` downloads only once). No app-specific password or 2FA
   is needed:
   ```sh
   xcrun notarytool store-credentials spanish-menu-bar \
     --key AuthKey_KEYID.p8 --key-id KEYID --issuer ISSUER-UUID
   ```
2. **Build, sign, notarize and staple:**
   ```sh
   DEVELOPER_ID="Developer ID Application: hamza mahjoubi (TEAMID)" \
   NOTARY_PROFILE=spanish-menu-bar VERSION=1.0.0 scripts/make-dmg.sh
   ```
   The script ends with `spctl --assess`, which must report `accepted  source=Notarized Developer ID`.
3. **Publish on GitHub.** The website's download buttons point to `releases/latest`:
   ```sh
   gh release create v1.0.0 build/SpanishMenuBar-1.0.0.dmg --title "Spanish Menu Bar 1.0.0" --notes "First release"
   ```
4. **Website.** Repository → Settings → Pages → *Deploy from a branch* → `main` / `/docs`. It is served at
   <https://hamza221.github.io/spanish-menu-bar/>.

Without `DEVELOPER_ID`, `make-dmg.sh` builds an ad-hoc signed DMG for local testing only. Gatekeeper blocks it on
other Macs.

## Mac App Store

1. **Provisioning profile.** Certificates, IDs & Profiles → Profiles → **+** → Distribution → *Mac App Store
   Connect*. Pick the App ID and your Apple Distribution certificate, then download the `.provisionprofile`.
2. **App record.** In <https://appstoreconnect.apple.com> → Apps → **+** → New App: platform macOS, a name (it must
   be unique on the store; have a fallback ready), your bundle ID, and any SKU (e.g. `spanish-menu-bar`).
3. **Build the package.** `BUILD_NUMBER` must go up with every upload, even for the same `VERSION`.
   ```sh
   APP_IDENTITY="Apple Distribution: hamza mahjoubi (TEAMID)" \
   INSTALLER_IDENTITY="3rd Party Mac Developer Installer: hamza mahjoubi (TEAMID)" \
   TEAM_ID=TEAMID PROFILE=path/to/Spanish_Menu_Bar_Mac_App_Store.provisionprofile \
   VERSION=1.0.0 BUILD_NUMBER=1 scripts/make-appstore-pkg.sh
   ```
4. **Upload** with the same API key. `altool` ships with Xcode and finds the key in
   `~/.appstoreconnect/private_keys/AuthKey_KEYID.p8`:
   ```sh
   export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
   xcrun altool --validate-app -f build/SpanishMenuBar-AppStore-1.0.0.pkg -t macos --apiKey KEYID --apiIssuer ISSUER-UUID
   xcrun altool --upload-app   -f build/SpanishMenuBar-AppStore-1.0.0.pkg -t macos --apiKey KEYID --apiIssuer ISSUER-UUID
   ```
   Transporter works too. After processing (usually minutes), the build appears under the app's TestFlight tab.
5. **Store listing** (App Store Connect → your app → macOS App). The App Store version name must match
   `VERSION` (e.g. `1.0.0`).
   - **Screenshots:** `Packaging/AppStore/*.png` (1440×900, made from real captures of the app).
   - **Privacy Policy URL:** `https://hamza221.github.io/spanish-menu-bar/privacy.html`.
   - **App Privacy:** *Data Not Collected*.
   - **Category:** Education (already set via `LSApplicationCategoryType`).
   - **Price:** USD 9.00 base price, other storefronts set by Apple. Paid apps need the *Paid Applications
     Agreement* active (Business → Agreements, plus bank account and tax forms). The GitHub DMG stays free.
   - **Age rating:** the dictionary includes vulgar words, so answer *Profanity or Crude Humor: Infrequent/Mild*.
   - **Support URL:** `https://github.com/hamza221/spanish-menu-bar/issues`.
   - **Encryption:** `ITSAppUsesNonExemptEncryption = NO` is in Info.plist, so there's no export compliance prompt.
   - **Review notes:** "Menu bar–only app (no Dock icon, no windows). After launch, a Spanish word appears in the
     menu bar. Click it to see the definition, press the speaker button to hear it, and press Next for another
     word."
6. **Submit for review.** Very simple apps are sometimes rejected under guideline 4.2 (Minimum Functionality).
   Point out in the notes that the app has offline storage, presence-aware rotation and pronunciation.

## Updating

Bump `VERSION` (and, for the App Store, `BUILD_NUMBER`), then run the same scripts. The two channels are separate
installs: App Store copies update through the App Store, DMG users download the new release.
