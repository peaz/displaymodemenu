#!/usr/bin/env bash
set -euo pipefail

# Build DisplayModeMenu to build/Release/DisplayModeMenu.app

# Resolve repo root (script can be run from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_PATH="$REPO_ROOT/displaymodemenu.xcodeproj"
SCHEME="DisplayModeMenu"
CONFIGURATION="Release"
OUTPUT_DIR="$REPO_ROOT/build/$CONFIGURATION"

mkdir -p "$OUTPUT_DIR"

echo "Building $SCHEME ($CONFIGURATION) to $OUTPUT_DIR ..."

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  build \
  CONFIGURATION_BUILD_DIR="$OUTPUT_DIR"

APP_PATH="$OUTPUT_DIR/DisplayModeMenu.app"

if [[ -d "$APP_PATH" ]]; then
  echo "Build succeeded: $APP_PATH"
  
  # Extract version from Info.plist
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
  
  # Create zip with version number
  ZIP_NAME="DisplayModeMenu-v${VERSION}.zip"
  ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
  
  echo "Creating archive: $ZIP_PATH"
  cd "$OUTPUT_DIR"
  ditto -c -k --sequesterRsrc --keepParent "DisplayModeMenu.app" "$ZIP_NAME"
  
  echo "Archive created: $ZIP_PATH"
else
  echo "Build finished but app not found at $APP_PATH" >&2
  exit 1
fi
