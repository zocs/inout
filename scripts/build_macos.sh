#!/bin/bash
# build_macos.sh - Build inout for macOS
set -e

ARCH=${1:-aarch64}
VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | tr -d '+')
APP_NAME="inout"

# Architecture mapping
DARWIN_ARCH=$([ "$ARCH" = "aarch64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
DISPLAY_ARCH=$([ "$ARCH" = "aarch64" ] && echo "arm64" || echo "x64")
ARCHIVE_NAME="${APP_NAME}-${VERSION}-macos-${DISPLAY_ARCH}"

echo "Building inout ${VERSION} for macOS ${DISPLAY_ARCH}..."

# Download dufs binary
DUFS_URL="https://github.com/sigoden/dufs/releases/download/v0.45.0/dufs-v0.45.0-${DARWIN_ARCH}.tar.gz"
echo "Downloading dufs for ${DARWIN_ARCH}..."
curl -sL "$DUFS_URL" | tar xz -C /tmp/
mkdir -p assets/dufs
cp /tmp/dufs "assets/dufs/dufs-macos-${DISPLAY_ARCH}"
chmod +x "assets/dufs/dufs-macos-${DISPLAY_ARCH}"

# Build Flutter macOS
flutter build macos --release

BUILD_DIR="build/macos/Build/Products/Release"
OUTPUT_DIR="build/macos/output"
mkdir -p "$OUTPUT_DIR"

# Copy .app bundle
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
if [ ! -d "$APP_BUNDLE" ]; then
  echo "ERROR: ${APP_BUNDLE} not found"
  ls "$BUILD_DIR/" 2>/dev/null
  exit 1
fi
cp -r "$APP_BUNDLE" "${OUTPUT_DIR}/${APP_NAME}.app"

# Include dufs binary in the app bundle
APP_CONTENTS="${OUTPUT_DIR}/${APP_NAME}.app/Contents/MacOS"
cp "assets/dufs/dufs-macos-${DISPLAY_ARCH}" "${APP_CONTENTS}/dufs"
chmod +x "${APP_CONTENTS}/dufs"

# Create DMG-like zip (simpler for distribution)
echo "Creating zip archive..."
cd "${OUTPUT_DIR}"
zip -r -y "${ARCHIVE_NAME}.zip" "${APP_NAME}.app"
cd -

echo "Created: ${OUTPUT_DIR}/${ARCHIVE_NAME}.zip"
ls -la "${OUTPUT_DIR}/${ARCHIVE_NAME}.zip"
