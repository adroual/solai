#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Solai"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

SIGN_IDENTITY="Developer ID Application: Alexandre Droual (2FHSYNGW44)"

echo "Building $APP_NAME..."

# Build release binary
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/release/Solai" "$MACOS/Solai"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy hook script to Resources
cp "$PROJECT_DIR/Sources/Solai/Hooks/solai_hook.sh" "$RESOURCES/solai_hook.sh"
chmod 755 "$RESOURCES/solai_hook.sh"

# Sign with Developer ID
echo "Signing with: $SIGN_IDENTITY"
codesign --force --options runtime \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$PROJECT_DIR/Solai.entitlements" \
    --timestamp \
    "$APP_BUNDLE" 2>&1

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
