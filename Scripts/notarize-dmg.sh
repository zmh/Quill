#!/bin/bash
#
# notarize-dmg.sh
# Notarizes a DMG file with Apple
#
# Usage: ./Scripts/notarize-dmg.sh <path-to-dmg>
#
# Prerequisites:
# 1. Developer ID certificate installed
# 2. Credentials stored: xcrun notarytool store-credentials "quill-notary"
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DMG_PATH="$1"

if [ -z "$DMG_PATH" ]; then
    echo -e "${RED}✗${NC} Error: No DMG path provided"
    echo "Usage: $0 <path-to-dmg>"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}✗${NC} Error: DMG not found: $DMG_PATH"
    exit 1
fi

DMG_NAME=$(basename "$DMG_PATH")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Notarizing $DMG_NAME${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if credentials are stored
echo -e "\n${BLUE}→${NC} Checking notarization credentials..."
if ! xcrun notarytool history --keychain-profile "quill-notary" > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Notarization credentials not found"
    echo ""
    echo "Please run:"
    echo "  xcrun notarytool store-credentials \"quill-notary\" \\"
    echo "    --apple-id \"your@email.com\" \\"
    echo "    --team-id \"YOUR_TEAM_ID\" \\"
    echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    echo "See NOTARIZATION.md for details"
    exit 1
fi

echo -e "${GREEN}✓${NC} Credentials found"

# Submit for notarization
echo -e "\n${BLUE}→${NC} Submitting DMG to Apple for notarization..."
echo -e "${YELLOW}Note:${NC} This may take 2-5 minutes..."

SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "quill-notary" \
    --wait 2>&1)

echo "$SUBMIT_OUTPUT"

if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "\n${GREEN}✓${NC} Notarization successful!"

    # Staple the notarization ticket
    echo -e "\n${BLUE}→${NC} Stapling notarization ticket to DMG..."
    xcrun stapler staple "$DMG_PATH"

    echo -e "${GREEN}✓${NC} Ticket stapled successfully"

    # Verify
    echo -e "\n${BLUE}→${NC} Verifying notarization..."
    spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

    echo -e "\n${GREEN}✓✓✓ DMG is now notarized and ready for distribution!${NC}"
    echo -e "\nUsers will be able to open the app without warnings."

elif echo "$SUBMIT_OUTPUT" | grep -q "status: Invalid"; then
    echo -e "\n${RED}✗${NC} Notarization failed - Invalid submission"

    # Extract submission ID
    SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')

    if [ -n "$SUBMISSION_ID" ]; then
        echo -e "\n${YELLOW}→${NC} Fetching detailed error log..."
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "quill-notary"
    fi

    echo -e "\n${YELLOW}Common issues:${NC}"
    echo "  - App not properly signed"
    echo "  - Missing Developer ID certificate"
    echo "  - Invalid bundle identifier"
    echo ""
    echo "See NOTARIZATION.md for troubleshooting"
    exit 1

else
    echo -e "\n${RED}✗${NC} Notarization failed - Unknown error"
    echo "$SUBMIT_OUTPUT"
    exit 1
fi

echo -e "\n${GREEN}Done!${NC}"
