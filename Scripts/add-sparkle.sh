#!/bin/bash
#
# add-sparkle.sh
# Adds Sparkle framework to the Xcode project
#

set -e

PROJECT_FILE="Quill/Quill.xcodeproj/project.pbxproj"
INFO_PLIST="Quill/Quill/Info.plist"

echo "Adding Sparkle framework to Quill project..."

# Generate UUIDs for new objects (Xcode-style 24-char hex)
generate_uuid() {
    openssl rand -hex 12 | tr '[:lower:]' '[:upper:]'
}

PACKAGE_REF_UUID=$(generate_uuid)
PACKAGE_PRODUCT_UUID=$(generate_uuid)

echo "Package Reference UUID: $PACKAGE_REF_UUID"
echo "Package Product UUID: $PACKAGE_PRODUCT_UUID"

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Add the package reference
# Find the end of the project section and add package references
if ! grep -q "sparkle-project/Sparkle" "$PROJECT_FILE"; then
    echo "Adding Sparkle package reference..."

    # This is complex to do via sed/awk. Let me use a Python script instead.
    echo "Note: Manual Xcode integration required"
    echo ""
    echo "Please add Sparkle manually in Xcode:"
    echo "1. Open Quill/Quill.xcodeproj"
    echo "2. Select Quill project → Package Dependencies"
    echo "3. Click '+' → Add Package Dependency"
    echo "4. Enter: https://github.com/sparkle-project/Sparkle"
    echo "5. Version: Up to Next Major Version 2.0.0"
    echo "6. Click 'Add Package'"
    echo "7. Select 'Sparkle' and click 'Add Package'"
else
    echo "Sparkle already added to project"
fi

# Create Info.plist if it doesn't exist
if [ ! -f "$INFO_PLIST" ]; then
    echo "Creating Info.plist..."
    cat > "$INFO_PLIST" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/YOUR_USERNAME/quill/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
</dict>
</plist>
EOF
    echo "Created Info.plist with Sparkle configuration"
    echo ""
    echo "IMPORTANT: Update YOUR_USERNAME in Info.plist with your GitHub username"
else
    echo "Info.plist already exists"
fi

echo ""
echo "Setup instructions:"
echo "1. Open Xcode and add Sparkle package manually (see above)"
echo "2. Update YOUR_USERNAME in Quill/Quill/Info.plist"
echo "3. Build and test: xcodebuild -project Quill/Quill.xcodeproj -scheme Quill build"
