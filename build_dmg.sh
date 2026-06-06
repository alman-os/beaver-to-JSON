#!/bin/bash
# ============================================
# BeaverJSON — sign, DMG, notarize, staple
# ============================================
# What this does (in order):
#   1. Build the .app if dist/ is empty (calls build_macos_app.sh)
#   2. Sign every nested binary/dylib/framework with hardened runtime
#   3. Sign the outer .app bundle with entitlements
#   4. Verify the signature passes Gatekeeper assessment
#   5. Build a styled DMG with create-dmg
#   6. Sign the DMG itself
#   7. Submit to Apple's notary service, wait for ticket
#   8. Staple the ticket onto the DMG
#   9. Verify the stapled DMG would pass on someone else's Mac
#
# Override any of these with env vars:
#   DEV_ID_NAME, TEAM_ID, NOTARY_PROFILE, BUNDLE_ID, APP_NAME

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# -------- Config --------
APP_NAME="${APP_NAME:-BeaverToJSON}"
BUNDLE_ID="${BUNDLE_ID:-com.beavertojson.app}"
DEV_ID_NAME="${DEV_ID_NAME:-Developer ID Application: ALMAN GONZALEZ (CNFQ3Q4EK2)}"
TEAM_ID="${TEAM_ID:-CNFQ3Q4EK2}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AudioGrabberNotary}"

DIST_DIR="dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

ENTITLEMENTS="entitlements.plist"
ICON_FILE="icon.icns"
DMG_BACKGROUND="wrap_folder/beaver-to-JSON_window.png"
VOLUME_NAME="${APP_NAME}"

# DMG icon positions (override if your background art expects different spots)
# Background is 1200x800; app on left third, Applications shortcut on right third.
APP_ICON_X="${APP_ICON_X:-300}"
APP_ICON_Y="${APP_ICON_Y:-400}"
APPS_LINK_X="${APPS_LINK_X:-900}"
APPS_LINK_Y="${APPS_LINK_Y:-400}"
WIN_W="${WIN_W:-1200}"
WIN_H="${WIN_H:-800}"

section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }
ok()      { echo -e "${GREEN}✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}! $1${NC}"; }
die()     { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# -------- Pre-flight checks --------
section "Pre-flight"

[[ "$OSTYPE" == darwin* ]] || die "macOS only."
command -v codesign >/dev/null || die "codesign not found (install Xcode CLT)."
command -v xcrun >/dev/null || die "xcrun not found (install Xcode CLT)."
command -v create-dmg >/dev/null || die "create-dmg not found. Install: brew install create-dmg"

[[ -f "$ENTITLEMENTS" ]] || die "Missing $ENTITLEMENTS"
[[ -f "$ICON_FILE" ]] || warn "No $ICON_FILE — DMG will have no custom volume icon"
[[ -f "$DMG_BACKGROUND" ]] || warn "No $DMG_BACKGROUND — DMG will have no background art"

# Confirm signing identity is present in this keychain
if ! security find-identity -v -p codesigning | grep -q "$DEV_ID_NAME"; then
    die "Signing identity not found in keychain:\n    $DEV_ID_NAME\nRun: security find-identity -v -p codesigning"
fi
ok "Found signing identity"

# Confirm notarytool profile exists (notarytool has no list cmd, so probe via history)
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    die "Notarytool profile '$NOTARY_PROFILE' not reachable.\nList existing: security find-generic-password -s 'com.apple.gke.notary.tool' -g 2>&1 | head\nOr create: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <you@example.com> --team-id $TEAM_ID --password <app-specific-password>"
fi
ok "Notary profile reachable"

# -------- Build .app if missing --------
if [[ ! -d "$APP_PATH" ]]; then
    section "Building .app (calling build_macos_app.sh)"
    [[ -x "./build_macos_app.sh" ]] || die "build_macos_app.sh not executable. chmod +x it."
    ./build_macos_app.sh
fi
[[ -d "$APP_PATH" ]] || die "Build did not produce $APP_PATH"
ok "Have $APP_PATH"

# -------- Sign --------
section "Signing $APP_NAME.app"

# Strip any stale signature first so re-runs are reproducible
codesign --remove-signature "$APP_PATH" 2>/dev/null || true

# 1. Sign every nested Mach-O file (.so, .dylib) with hardened runtime.
#    Inner-first is required: codesign needs leaves signed before parents.
echo "  Signing nested .dylib / .so files..."
find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" \) -print0 |
    while IFS= read -r -d '' f; do
        codesign --force --timestamp --options runtime \
            --sign "$DEV_ID_NAME" "$f" >/dev/null
    done

# 2. Sign every nested .framework (and Python.framework versions within)
echo "  Signing nested .framework bundles..."
find "$APP_PATH" -type d -name "*.framework" -print0 |
    while IFS= read -r -d '' fw; do
        codesign --force --timestamp --options runtime \
            --sign "$DEV_ID_NAME" "$fw" >/dev/null
    done

# 3. Sign nested executables in Contents/MacOS (PyInstaller bootloader + helpers)
echo "  Signing nested executables..."
find "$APP_PATH/Contents/MacOS" -type f -perm +111 -print0 |
    while IFS= read -r -d '' exe; do
        codesign --force --timestamp --options runtime \
            --sign "$DEV_ID_NAME" "$exe" >/dev/null
    done

# 4. Sign the outer .app bundle WITH entitlements
echo "  Signing outer bundle with entitlements..."
codesign --force --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEV_ID_NAME" \
    "$APP_PATH"

ok "Signed"

# -------- Verify --------
section "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ok "codesign --verify passed"

# spctl will refuse unnotarized signed apps; expect this to FAIL here.
# We just want to know the signature is well-formed.
spctl --assess --type execute --verbose=4 "$APP_PATH" 2>&1 | head -3 || \
    warn "spctl rejected pre-notarization (expected — will pass after stapling)"

# -------- Build DMG --------
section "Building DMG"
rm -f "$DMG_PATH" "${DIST_DIR}/.${APP_NAME}.dmg.staging" 2>/dev/null || true

CREATE_DMG_ARGS=(
    --volname "$VOLUME_NAME"
    --window-pos 200 120
    --window-size "$WIN_W" "$WIN_H"
    --icon-size 100
    --icon "${APP_NAME}.app" "$APP_ICON_X" "$APP_ICON_Y"
    --hide-extension "${APP_NAME}.app"
    --app-drop-link "$APPS_LINK_X" "$APPS_LINK_Y"
    --no-internet-enable
)
[[ -f "$ICON_FILE" ]]      && CREATE_DMG_ARGS+=(--volicon "$ICON_FILE")
[[ -f "$DMG_BACKGROUND" ]] && CREATE_DMG_ARGS+=(--background "$DMG_BACKGROUND")

create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$APP_PATH"
ok "Built $DMG_PATH"

# -------- Sign the DMG itself --------
section "Signing DMG"
codesign --force --timestamp --sign "$DEV_ID_NAME" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"
ok "DMG signed"

# -------- Notarize --------
section "Notarizing (this can take 1–5 minutes)"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout 30m

ok "Apple accepted the submission"

# -------- Staple --------
section "Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
ok "Stapled"

# -------- Final verification --------
section "Final Gatekeeper check (simulates a fresh recipient Mac)"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH" || \
    warn "spctl assessment returned non-zero — inspect output above"

DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Done${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Signed + notarized DMG: ${BLUE}${DMG_PATH}${NC} (${DMG_SIZE})"
echo -e "  Ready to upload anywhere — recipients can double-click and run."
