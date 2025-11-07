#!/bin/bash
#
# create-dmg.sh
# Creates a distributable DMG for Quill
#
# Usage: ./Scripts/create-dmg.sh [version]
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Quill"
VERSION=${1:-"1.0.0"}
BUILD_DIR="build"
RELEASE_DIR="$BUILD_DIR/Release"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="Quill-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
VOLUME_NAME="Quill $VERSION"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Creating DMG for Quill v${VERSION}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if app exists
if [ ! -d "$RELEASE_DIR/$APP_NAME.app" ]; then
    echo -e "${RED}✗${NC} Error: $RELEASE_DIR/$APP_NAME.app not found"
    echo -e "${YELLOW}→${NC} Run ./Scripts/build-release.sh first"
    exit 1
fi

# Clean previous DMG artifacts
echo -e "\n${BLUE}→${NC} Cleaning previous DMG artifacts..."
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"
mkdir -p "$DMG_DIR"

# Copy app to DMG staging directory
echo -e "${BLUE}→${NC} Copying application to staging directory..."
cp -R "$RELEASE_DIR/$APP_NAME.app" "$DMG_DIR/"

# Create Applications symlink
echo -e "${BLUE}→${NC} Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

# Create a temporary DMG
echo -e "${BLUE}→${NC} Creating temporary DMG..."
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$VOLUME_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "$TEMP_DMG"

# Mount the temporary DMG
echo -e "${BLUE}→${NC} Mounting temporary DMG..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Set custom icon positions and view options
echo -e "${BLUE}→${NC} Configuring DMG appearance..."

# Use AppleScript to set window properties
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 120
        -- Subtle blue-grey background (RGB: 240, 245, 250)
        set background color of viewOptions to {61680, 62965, 64250}
        set text size of viewOptions to 14
        set label position of viewOptions to bottom

        -- Position icons for better visual balance
        -- App icon on the left
        set position of item "$APP_NAME.app" of container window to {180, 180}
        -- Applications folder on the right
        set position of item "Applications" of container window to {480, 180}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount
echo -e "${BLUE}→${NC} Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed, read-only DMG
echo -e "${BLUE}→${NC} Converting to final DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Sign the DMG (required for notarization)
if [ "$SKIP_CODESIGN" != "true" ]; then
    if [ -z "$CODE_SIGN_IDENTITY" ]; then
        echo -e "${YELLOW}Warning: CODE_SIGN_IDENTITY not set, skipping DMG signing${NC}"
        echo "Set CODE_SIGN_IDENTITY environment variable to sign the DMG"
    else
        echo -e "${BLUE}→${NC} Signing DMG with: $CODE_SIGN_IDENTITY"
        codesign --sign "$CODE_SIGN_IDENTITY" \
            --timestamp \
            --options runtime \
            "$DMG_PATH"
    fi
fi

# Clean up
echo -e "${BLUE}→${NC} Cleaning up..."
rm -rf "$DMG_DIR"
rm -f "$TEMP_DMG"

# Verify the DMG
if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    echo -e "\n${GREEN}✓${NC} DMG created successfully!"
    echo -e "\n${BLUE}DMG Info:${NC}"
    echo -e "  Name: $DMG_NAME"
    echo -e "  Size: $DMG_SIZE"
    echo -e "  Path: $DMG_PATH"

    # Calculate SHA256 checksum
    echo -e "\n${BLUE}→${NC} Calculating checksum..."
    CHECKSUM=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
    echo -e "  SHA256: $CHECKSUM"

    # Save checksum to file
    echo "$CHECKSUM  $DMG_NAME" > "$BUILD_DIR/$DMG_NAME.sha256"
    echo -e "${GREEN}✓${NC} Checksum saved to $BUILD_DIR/$DMG_NAME.sha256"
else
    echo -e "\n${RED}✗${NC} DMG creation failed"
    exit 1
fi

echo -e "\n${GREEN}Done!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Test the DMG: open $DMG_PATH"
echo -e "  2. Upload to GitHub Releases"
echo -e "  3. Update appcast.xml with new version"
