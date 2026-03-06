#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/Solai.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/Solai.dmg"

SIGN_IDENTITY="Developer ID Application: Alexandre Droual (2FHSYNGW44)"
TEAM_ID="2FHSYNGW44"
BUNDLE_ID="com.musicmi.solai"

# Build app first
"$PROJECT_DIR/scripts/build-app.sh"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

echo ""
echo "Creating DMG..."

# Prepare DMG staging
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create symlink to /Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "Solai" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" 2>&1

rm -rf "$DMG_DIR"

# Sign DMG
echo "Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH" 2>&1

# Notarize
echo ""
echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --team-id "$TEAM_ID" \
    --keychain-profile "notarytool" \
    --wait 2>&1

# Staple the ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH" 2>&1

echo ""
echo "Done! Notarized DMG: $DMG_PATH"
