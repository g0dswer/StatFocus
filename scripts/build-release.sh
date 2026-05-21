#!/usr/bin/env bash
# build-release.sh
# End-to-end: compile (release) → bundle → sign (Developer ID + hardened runtime
# + entitlements) → notarize → staple → produce .dmg ready for distribution.
#
# Requires:
#   - "Developer ID Application" certificate installed in Keychain
#   - Notarization credentials stored in Keychain under profile name (default: "statfocus-notarization")
#     Set up with:  xcrun notarytool store-credentials <profile> --apple-id ... --team-id ... --password ...
#   - Xcode CLT (provides codesign, notarytool, stapler, hdiutil, iconutil)
#
# Usage:
#   scripts/build-release.sh                              # uses defaults below
#   VERSION=1.5 BUILD=6 scripts/build-release.sh          # override version
#   SKIP_NOTARIZATION=1 scripts/build-release.sh          # local dev only
#   SKIP_DMG=1 scripts/build-release.sh                   # just produce .app
#
# Output:
#   build/StatFocus.app          (signed + notarized + stapled)
#   build/StatFocus-<version>.dmg (signed + notarized + stapled)

set -euo pipefail

# -------- Config (override via env) --------
TEAM_ID="${TEAM_ID:-9A7SMX4LKH}"
BUNDLE_ID="${BUNDLE_ID:-com.thiagogruber.statfocus}"
PRODUCT_NAME="${PRODUCT_NAME:-StatFocus}"
VERSION="${VERSION:-1.5}"
BUILD="${BUILD:-6}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-statfocus-notarization}"
SIGN_IDENTITY_PREFIX="${SIGN_IDENTITY_PREFIX:-Developer ID Application}"

# -------- Paths --------
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$PRODUCT_NAME.app"
ICONSET_TMP="$BUILD_DIR/AppIcon.iconset"
ICNS="$BUILD_DIR/AppIcon.icns"
ENTITLEMENTS="$ROOT/StatFocus/StatFocus.entitlements"
DMG="$BUILD_DIR/$PRODUCT_NAME-$VERSION.dmg"
ZIP_FOR_NOTARIZATION="$BUILD_DIR/$PRODUCT_NAME-notarize.zip"

# -------- Helpers --------
log()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
fail() { printf "  \033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

# -------- 0. Sanity checks --------
log "Sanity checks"
[ -f "$ROOT/Package.swift" ] || fail "Run from repo root or scripts/. Package.swift not found at $ROOT"
[ -f "$ENTITLEMENTS" ] || fail "Entitlements file not found: $ENTITLEMENTS"

IDENTITY=$(security find-identity -p codesigning -v 2>&1 | grep "$SIGN_IDENTITY_PREFIX" | head -1 | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+([A-F0-9]+).*/\1/') || true
if [ -z "${IDENTITY:-}" ]; then
  fail "No '$SIGN_IDENTITY_PREFIX' identity found in Keychain. Create one in Xcode → Settings → Accounts → Manage Certificates."
fi
ok "Signing identity: $IDENTITY"

if [ "${SKIP_NOTARIZATION:-}" != "1" ]; then
  xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
    || fail "Keychain profile '$KEYCHAIN_PROFILE' missing or invalid. Run: xcrun notarytool store-credentials $KEYCHAIN_PROFILE --apple-id <id> --team-id $TEAM_ID --password <app-specific>"
  ok "Notarization profile valid"
fi

# -------- 1. Clean build dir --------
log "Cleaning build/"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
ok "Fresh $BUILD_DIR"

# -------- 2. Compile release binary --------
log "Compiling release binary"
cd "$ROOT"
swift build -c release
BINARY="$ROOT/.build/release/$PRODUCT_NAME"
[ -x "$BINARY" ] || fail "Release binary not produced at $BINARY"
ok "Built: $(file "$BINARY" | cut -d: -f2-)"

# -------- 3. Compile AppIcon.icns from PNGs --------
log "Compiling AppIcon.icns"
SRC_ICONS="$ROOT/StatFocus/Resources/Assets.xcassets/AppIcon.appiconset"
[ -d "$SRC_ICONS" ] || fail "AppIcon source PNGs not found at $SRC_ICONS"
rm -rf "$ICONSET_TMP" && mkdir -p "$ICONSET_TMP"
for s in 16x16 16x16@2x 32x32 32x32@2x 128x128 128x128@2x 256x256 256x256@2x 512x512 512x512@2x; do
  cp "$SRC_ICONS/icon_$s.png" "$ICONSET_TMP/icon_$s.png"
done
iconutil -c icns -o "$ICNS" "$ICONSET_TMP"
ok "$(ls -lh "$ICNS" | awk '{print $5}') AppIcon.icns"

# -------- 4. Assemble .app bundle --------
log "Assembling .app bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP/Contents/MacOS/$PRODUCT_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

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
	<key>NSAppleEventsUsageDescription</key>
	<string>O StatFocus precisa controlar seu navegador para detectar e redirecionar sites bloqueados durante sessões de foco.</string>
</dict>
</plist>
PLIST
ok "Bundle assembled: $APP"

# -------- 5. Sign with Developer ID + hardened runtime + entitlements --------
log "Signing"
# Sign the main executable first, then the bundle itself (deep sign).
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP/Contents/MacOS/$PRODUCT_NAME"

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$IDENTITY" \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -3
ok "Signed and verified"

# -------- 6. Notarize --------
if [ "${SKIP_NOTARIZATION:-}" = "1" ]; then
  log "Skipping notarization (SKIP_NOTARIZATION=1)"
else
  log "Notarizing (this can take 1–10 min)"
  # notarytool requires a zip, dmg, or pkg — zip is simplest.
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP_FOR_NOTARIZATION"

  xcrun notarytool submit "$ZIP_FOR_NOTARIZATION" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

  log "Stapling notarization ticket"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP" 2>&1 | tail -2
  rm -f "$ZIP_FOR_NOTARIZATION"
  ok "App is notarized and stapled"
fi

# -------- 7. Produce .dmg (optional) --------
if [ "${SKIP_DMG:-}" = "1" ]; then
  log "Skipping .dmg (SKIP_DMG=1)"
else
  log "Building distributable .dmg"
  DMG_STAGE="$BUILD_DIR/dmg-stage"
  rm -rf "$DMG_STAGE" && mkdir -p "$DMG_STAGE"
  cp -R "$APP" "$DMG_STAGE/"
  ln -s /Applications "$DMG_STAGE/Applications"

  rm -f "$DMG"
  hdiutil create -volname "$PRODUCT_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

  # Sign the dmg itself (so Gatekeeper trusts the container too)
  codesign --force --sign "$IDENTITY" --timestamp "$DMG"

  if [ "${SKIP_NOTARIZATION:-}" != "1" ]; then
    log "Notarizing .dmg"
    xcrun notarytool submit "$DMG" \
      --keychain-profile "$KEYCHAIN_PROFILE" \
      --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG" 2>&1 | tail -2
  fi

  rm -rf "$DMG_STAGE"
  ok ".dmg: $DMG ($(du -h "$DMG" | cut -f1))"
fi

log "Done"
printf "  App: %s\n" "$APP"
[ -f "$DMG" ] && printf "  DMG: %s\n" "$DMG"
printf "  Verify on a clean machine:  spctl --assess --type execute --verbose %s\n" "$APP"
