#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/app"
BACKEND_DIR="$PROJECT_DIR/backend"
RESOURCE_DIR="$APP_DIR/Resources"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== VoiceType DMG Builder ==="

# 1. Copy backend files into app Resources
echo "Step 1: Copying backend resources..."
mkdir -p "$RESOURCE_DIR/backend"
cp "$BACKEND_DIR/server.py" "$RESOURCE_DIR/backend/"
cp "$BACKEND_DIR/requirements.txt" "$RESOURCE_DIR/backend/"

# 2. Download uv binary
echo "Step 2: Downloading uv..."
if [ ! -f "$RESOURCE_DIR/uv" ]; then
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-aarch64-apple-darwin.tar.gz"
    else
        UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-apple-darwin.tar.gz"
    fi
    echo "  Downloading from $UV_URL"
    curl -fsSL "$UV_URL" -o /tmp/uv.tar.gz
    tar -xzf /tmp/uv.tar.gz -C /tmp/
    UV_BIN=$(find /tmp/uv-*-apple-darwin* -name "uv" -type f 2>/dev/null | head -1)
    if [ -z "$UV_BIN" ]; then
        UV_BIN="/tmp/uv"
    fi
    cp "$UV_BIN" "$RESOURCE_DIR/uv"
    chmod +x "$RESOURCE_DIR/uv"
    rm -f /tmp/uv.tar.gz
    rm -rf /tmp/uv-*-apple-darwin*
    echo "  uv downloaded."
else
    echo "  uv already exists, skipping download."
fi

# 3. Generate Xcode project
echo "Step 3: Generating Xcode project..."
cd "$APP_DIR"
xcodegen generate

# 4. Build archive
echo "Step 4: Building archive..."
ARCHIVE_PATH="$BUILD_DIR/VoiceType.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project "$APP_DIR/VoiceType.xcodeproj" \
    -scheme VoiceType \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tail -20

# 5. Export app from archive
echo "Step 5: Exporting app..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/VoiceType.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: VoiceType.app not found in archive."
    echo "Looking for app in archive..."
    find "$ARCHIVE_PATH" -name "*.app" -type d
    exit 1
fi

# 6. Create DMG
echo "Step 6: Creating DMG..."
DMG_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/VoiceType.dmg"

rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"
mkdir -p "$DMG_DIR"

cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "VoiceType" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "=== Build complete ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
