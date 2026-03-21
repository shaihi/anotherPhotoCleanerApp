#!/bin/bash
# Builds PhotoCullApp and launches it as a proper macOS .app bundle.
# Required because SwiftUI's App lifecycle needs a bundle structure
# (Contents/MacOS/binary + Contents/Info.plist) to connect to the window server.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/debug"
APP_BUNDLE="$SCRIPT_DIR/.build/PhotoCull.app"
BINARY_NAME="PhotoCullApp"

echo "Building..."
swift build --package-path "$SCRIPT_DIR" 2>&1

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$BINARY_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Launching..."
open "$APP_BUNDLE"
