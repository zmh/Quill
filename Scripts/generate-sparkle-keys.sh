#!/bin/bash

# generate-sparkle-keys.sh
# Generates Sparkle EdDSA signing keys for secure app updates
#
# This script downloads Sparkle's key generation tool and creates
# a public/private key pair for signing update releases.

set -e

echo "🔐 Generating Sparkle EdDSA Keys"
echo "================================="
echo ""

# Check if keys already exist
if [ -f "sparkle_eddsa_private.key" ] || [ -f "sparkle_eddsa_public.key" ]; then
    echo "⚠️  Warning: Key files already exist!"
    echo ""
    read -p "Do you want to overwrite existing keys? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy](es)?$ ]]; then
        echo "Aborted."
        exit 1
    fi
    echo ""
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📥 Downloading Sparkle tools..."
cd "$TEMP_DIR"

# Download latest Sparkle release
SPARKLE_VERSION="2.6.4"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

curl -L -o sparkle.tar.xz "$SPARKLE_URL"
tar -xf sparkle.tar.xz

# Find generate_keys tool
GENERATE_KEYS="bin/generate_keys"

if [ ! -f "$GENERATE_KEYS" ]; then
    echo "❌ Error: generate_keys tool not found in Sparkle package"
    exit 1
fi

echo "✅ Downloaded Sparkle tools"
echo ""

# Generate keys
echo "🔑 Generating EdDSA key pair..."
"$GENERATE_KEYS"

# Move keys to project root
cd - > /dev/null
mv "$TEMP_DIR/sparkle_eddsa_private.key" .
mv "$TEMP_DIR/sparkle_eddsa_public.key" .

echo ""
echo "✅ Keys generated successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Add the following to Quill/Quill/Info.plist:"
echo ""
echo "   <key>SUPublicEDKey</key>"
echo "   <string>$(cat sparkle_eddsa_public.key)</string>"
echo ""
echo "2. Add these GitHub Secrets (Settings → Secrets and variables → Actions):"
echo ""
echo "   SPARKLE_EDDSA_PRIVATE_KEY = $(cat sparkle_eddsa_private.key)"
echo "   SPARKLE_EDDSA_PUBLIC_KEY = $(cat sparkle_eddsa_public.key)"
echo ""
echo "3. ⚠️  IMPORTANT: Keep sparkle_eddsa_private.key secure and never commit it!"
echo "   Add it to .gitignore:"
echo "   echo 'sparkle_eddsa_*.key' >> .gitignore"
echo ""
echo "4. You can delete the key files from your local machine after adding to GitHub Secrets"
echo ""
