#!/bin/bash
#
# build-release.sh
# Builds a release version of Quill for macOS distribution
#
# Usage: ./Scripts/build-release.sh [version]
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Quill"
SCHEME="Quill"
CONFIGURATION="Release"
XCODE_PROJECT="Quill/Quill.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Quill.xcarchive"
EXPORT_PATH="$BUILD_DIR/Release"
APP_NAME="Quill.app"

# Get version from argument or use default
VERSION=${1:-"1.0.0"}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Building Quill v${VERSION} for Release${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Clean previous builds
echo -e "\n${BLUE}→${NC} Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive the app
echo -e "\n${BLUE}→${NC} Creating archive..."
xcodebuild archive \
    -project "$XCODE_PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="86G95Q55DC" \
    -allowProvisioningUpdates

# Create export options plist
echo -e "\n${BLUE}→${NC} Creating export options..."
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>86G95Q55DC</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

# Export the archive
echo -e "\n${BLUE}→${NC} Exporting application..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

# Verify the build
if [ -d "$EXPORT_PATH/$APP_NAME" ]; then
    echo -e "\n${GREEN}✓${NC} Build successful!"
    echo -e "${GREEN}✓${NC} Application exported to: $EXPORT_PATH/$APP_NAME"

    # Get app info
    APP_VERSION=$(defaults read "$(pwd)/$EXPORT_PATH/$APP_NAME/Contents/Info.plist" CFBundleShortVersionString)
    APP_BUILD=$(defaults read "$(pwd)/$EXPORT_PATH/$APP_NAME/Contents/Info.plist" CFBundleVersion)
    APP_SIZE=$(du -sh "$EXPORT_PATH/$APP_NAME" | cut -f1)

    echo -e "\n${BLUE}App Info:${NC}"
    echo -e "  Version: $APP_VERSION"
    echo -e "  Build: $APP_BUILD"
    echo -e "  Size: $APP_SIZE"
    echo -e "  Path: $EXPORT_PATH/$APP_NAME"
else
    echo -e "\n${RED}✗${NC} Build failed - application not found"
    exit 1
fi

echo -e "\n${GREEN}Done!${NC}"
