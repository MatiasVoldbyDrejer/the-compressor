#!/bin/bash
set -euo pipefail

# Fix PATH for standard macOS locations
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

APP_NAME="The Compressor"
SCHEME="TheCompressor"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$PROJECT_DIR/The Compressor/The Compressor.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"

# Get version from project
VERSION=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" \
    -showBuildSettings 2>/dev/null | grep MARKETING_VERSION | tr -d ' ' | cut -d'=' -f2)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "Building $APP_NAME v$VERSION..."

# Clean
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Resolve packages
xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -resolvePackageDependencies

# Build
xcodebuild -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination "generic/platform=macOS" \
    build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

# Create DMG
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 185 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 185 \
    "$DIST_DIR/$DMG_NAME" \
    "$APP_PATH"

echo "Done: $DIST_DIR/$DMG_NAME"
