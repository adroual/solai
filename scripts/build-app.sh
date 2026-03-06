#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Solai"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

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

# Sign (ad-hoc for local use)
codesign --force --sign - --entitlements "$PROJECT_DIR/Solai.entitlements" "$APP_BUNDLE" 2>&1 || true

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:   open $APP_BUNDLE"
