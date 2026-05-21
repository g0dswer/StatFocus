#!/usr/bin/env bash
# build-appstore.sh
# End-to-end Mac App Store build:
#   - Compiles with APP_STORE flag (gates sandbox-incompatible code)
#   - Bundles, embeds provisioning profile, signs with Apple Distribution + sandbox entitlements
#   - Packages as signed .pkg (3rd Party Mac Developer Installer)
#   - Validates via altool/notarytool (sanity check; ASC Connect rejects invalid pkgs anyway)
#
# Requires:
#   - "Apple Distribution: <Name> (<TeamID>)" cert in Keychain
#   - "3rd Party Mac Developer Installer: <Name> (<TeamID>)" cert in Keychain (System or login)
#   - Provisioning profile at $PROFILE_PATH (default: ~/Documents/StatFocus.provisionprofile)
#   - Notarization profile in Keychain (for upload step)
#
# Usage:
#   scripts/build-appstore.sh                    # build only
#   UPLOAD=1 scripts/build-appstore.sh           # build + upload to App Store Connect
#   VERSION=1.0 BUILD=1 scripts/build-appstore.sh
#
# Output:
#   build/appstore/StatFocus.app   (sandboxed, signed)
#   build/appstore/StatFocus.pkg   (installer, signed, ready for ASC upload)

set -euo pipefail

# -------- Config (override via env) --------
TEAM_ID="${TEAM_ID:-9A7SMX4LKH}"
BUNDLE_ID="${BUNDLE_ID:-com.thiagogruber.statfocus}"
PRODUCT_NAME="${PRODUCT_NAME:-StatFocus}"
VERSION="${VERSION:-1.0}"
BUILD="${BUILD:-1}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-statfocus-notarization}"
PROFILE_PATH="${PROFILE_PATH:-$HOME/Documents/StatFocus.provisionprofile}"
APP_SIGN_PREFIX="${APP_SIGN_PREFIX:-Apple Distribution}"
PKG_SIGN_PREFIX="${PKG_SIGN_PREFIX:-3rd Party Mac Developer Installer}"

# -------- Paths --------
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build/appstore"
APP="$BUILD_DIR/$PRODUCT_NAME.app"
ICONSET_TMP="$BUILD_DIR/AppIcon.iconset"
ICNS="$BUILD_DIR/AppIcon.icns"
ENTITLEMENTS="$ROOT/StatFocus/StatFocus-AppStore.entitlements"
PKG="$BUILD_DIR/$PRODUCT_NAME.pkg"

# -------- Helpers --------
log()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

find_identity() {
  local prefix="$1"
  security find-identity -p basic -v 2>&1 \
    | grep "$prefix" \
    | head -1 \
    | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+([A-F0-9]+).*/\1/' \
    || true
}

# -------- 0. Sanity --------
log "Sanity checks"
[ -f "$ROOT/Package.swift" ] || fail "Run from repo root. Package.swift not found at $ROOT"
[ -f "$ENTITLEMENTS" ] || fail "Entitlements missing: $ENTITLEMENTS"
[ -f "$PROFILE_PATH" ] || fail "Provisioning profile missing: $PROFILE_PATH"

APP_IDENTITY=$(find_identity "$APP_SIGN_PREFIX")
PKG_IDENTITY=$(find_identity "$PKG_SIGN_PREFIX")
[ -n "$APP_IDENTITY" ] || fail "Missing '$APP_SIGN_PREFIX' identity in Keychain"
[ -n "$PKG_IDENTITY" ] || fail "Missing '$PKG_SIGN_PREFIX' identity in Keychain"
ok "App sign identity: $APP_IDENTITY"
ok "Pkg sign identity: $PKG_IDENTITY"

# Verify profile matches bundle ID + team
PROFILE_TMP=$(mktemp)
security cms -D -i "$PROFILE_PATH" > "$PROFILE_TMP"
PROFILE_TEAM=$(plutil -extract TeamIdentifier.0 raw -o - "$PROFILE_TMP" 2>/dev/null)
PROFILE_APPID=$(plutil -extract Entitlements.com\\.apple\\.application-identifier raw -o - "$PROFILE_TMP" 2>/dev/null)
EXPECTED_APPID="$TEAM_ID.$BUNDLE_ID"
[ "$PROFILE_TEAM" = "$TEAM_ID" ] || fail "Profile team $PROFILE_TEAM ≠ $TEAM_ID"
[ "$PROFILE_APPID" = "$EXPECTED_APPID" ] || fail "Profile app-id $PROFILE_APPID ≠ $EXPECTED_APPID"
rm -f "$PROFILE_TMP"
ok "Provisioning profile validated"

# -------- 1. Clean --------
log "Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# -------- 2. Compile with APP_STORE flag --------
log "Compiling (APP_STORE flag)"
cd "$ROOT"
STATFOCUS_APP_STORE=1 swift build -c release 2>&1 | tail -3
BINARY="$ROOT/.build/release/$PRODUCT_NAME"
[ -x "$BINARY" ] || fail "Release binary not produced"
ok "Built: $(file "$BINARY" | cut -d: -f2-)"

# -------- 3. Icon --------
log "Compiling AppIcon.icns"
SRC_ICONS="$ROOT/StatFocus/Resources/Assets.xcassets/AppIcon.appiconset"
rm -rf "$ICONSET_TMP" && mkdir -p "$ICONSET_TMP"
for s in 16x16 16x16@2x 32x32 32x32@2x 128x128 128x128@2x 256x256 256x256@2x 512x512 512x512@2x; do
  cp "$SRC_ICONS/icon_$s.png" "$ICONSET_TMP/icon_$s.png"
done
iconutil -c icns -o "$ICNS" "$ICONSET_TMP"
ok "$(ls -lh "$ICNS" | awk '{print $5}') AppIcon.icns"

# -------- 4. Bundle --------
log "Assembling .app bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP/Contents/MacOS/$PRODUCT_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

# Embed provisioning profile (Mac App Store requires this)
cp "$PROFILE_PATH" "$APP/Contents/embedded.provisionprofile"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>pt-BR</string>
	<key>CFBundleExecutable</key>
	<string>$PRODUCT_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$PRODUCT_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST
ok "Bundle assembled: $APP"

# -------- 5. Sign --------
log "Signing app (sandbox + entitlements + hardened runtime implicit)"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APP_IDENTITY" \
  "$APP/Contents/MacOS/$PRODUCT_NAME"

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APP_IDENTITY" \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -3
codesign -d --entitlements - --xml "$APP" 2>/dev/null | head -2 || true
ok "App signed and verified"

# Sanity check: did it actually pick up the sandbox entitlement?
if codesign -d --entitlements - "$APP" 2>&1 | grep -q "com.apple.security.app-sandbox"; then
  ok "Sandbox entitlement present"
else
  fail "Sandbox entitlement NOT present — check entitlements file"
fi

# -------- 6. Productbuild → .pkg --------
log "Packaging as installer .pkg"
xcrun productbuild \
  --component "$APP" /Applications \
  --sign "$PKG_IDENTITY" \
  --product "$APP/Contents/Info.plist" \
  "$PKG"
ok "$(ls -lh "$PKG" | awk '{print $5}') $PKG"

# -------- 7. Optional upload --------
if [ "${UPLOAD:-}" = "1" ]; then
  log "Uploading to App Store Connect (this can take a few minutes)"
  xcrun notarytool submit "$PKG" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait || fail "Upload validation failed (notarytool can pre-check pkg)"
  # For actual ASC upload (not just notarytool), use Transporter or altool:
  # xcrun altool --upload-app -f "$PKG" -t macos --apple-id "<id>" --password "@keychain:..."
  # We use Transporter manually for the first upload to avoid altool's quirks.
  ok "Pkg validated"
fi

log "Done"
printf "  App: %s\n" "$APP"
printf "  Pkg: %s\n" "$PKG"
printf "\n  Next: upload $PKG to App Store Connect via Transporter.app (free in App Store).\n"
