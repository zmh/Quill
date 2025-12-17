# Release Guide for Quill

This guide explains how to build, package, and distribute Quill for macOS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Release Process](#manual-release-process)
- [Automated Release (GitHub Actions)](#automated-release-github-actions)
- [Setting Up Automatic Updates](#setting-up-automatic-updates)
- [Code Signing and Notarization](#code-signing-and-notarization)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Xcode 16.0+** - Download from Mac App Store
- **macOS 14.0+** - For building and testing
- **Apple Developer Account** - For code signing and notarization
- **Git** - For version control

### Optional Tools

- **xcpretty** - For prettier build output
  ```bash
  gem install xcpretty
  ```

### Apple Developer Setup

1. **Join Apple Developer Program** ($99/year)
   - Visit: https://developer.apple.com/programs/

2. **Download Certificates**
   - Open Xcode → Settings → Accounts
   - Sign in with your Apple ID
   - Select your team → Manage Certificates
   - Click "+" → "Apple Development" (for testing)
   - Click "+" → "Developer ID Application" (for distribution)

3. **Create App Identifier** (if needed)
   - Visit: https://developer.apple.com/account/resources/identifiers/
   - Create identifier: `zacharyhamed.Quill`

---

## Quick Start

### 1. Build for Testing

```bash
# Build and run in Xcode
open Quill/Quill.xcodeproj

# Or build via command line
xcodebuild -project Quill/Quill.xcodeproj \
  -scheme Quill \
  -configuration Debug \
  build
```

### 2. Build Release

```bash
# Build release version
./Scripts/build-release.sh 1.0.0
```

### 3. Create DMG

```bash
# Create distributable DMG
./Scripts/create-dmg.sh 1.0.0
```

The DMG will be created at: `build/Quill-1.0.0.dmg`

---

## Manual Release Process

### Step 1: Update Version

Edit the `VERSION` file:
```bash
echo "1.0.1" > VERSION
```

### Step 2: Update Changelog

Add release notes to your commit:
```bash
git commit -m "Release v1.0.1

- Fixed bug in post sync
- Improved editor performance
- Updated dependencies
"
```

### Step 3: Build Release

```bash
./Scripts/build-release.sh $(cat VERSION)
```

This will:
- Clean previous builds
- Create an Xcode archive
- Export the signed app to `build/Release/`

### Step 4: Create DMG

```bash
./Scripts/create-dmg.sh $(cat VERSION)
```

This will:
- Create a DMG staging directory
- Add Applications symlink
- Configure DMG appearance
- Create compressed DMG at `build/Quill-X.X.X.dmg`
- Generate SHA256 checksum

### Step 5: Test the DMG

```bash
# Mount and test
open build/Quill-*.dmg

# Verify the app opens
# Test basic functionality
```

### Step 6: Create GitHub Release

```bash
# Tag the release
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1

# Or create manually on GitHub
```

Then upload the DMG and checksum file to GitHub Releases.

---

## Automated Release (GitHub Actions)

The easiest way to create releases is using GitHub Actions.

### Setup

1. **Enable GitHub Actions** in your repository
2. **Push a version tag** to trigger the workflow

### Usage

```bash
# Commit your changes
git add .
git commit -m "Prepare for v1.0.1 release"

# Create and push a version tag
git tag v1.0.1
git push origin v1.0.1
```

The GitHub Actions workflow will automatically:
1. Build the macOS app
2. Create a DMG
3. Generate release notes from commits
4. Create a GitHub Release
5. Upload the DMG and checksums
6. Generate appcast.xml for Sparkle updates

### Workflow Details

See `.github/workflows/release.yml` for the full workflow.

The workflow triggers on tags matching `v*.*.*` (e.g., `v1.0.0`, `v2.1.3`).

---

## Setting Up Automatic Updates

Quill uses [Sparkle](https://sparkle-project.org/) for automatic updates.

### Step 1: Add Sparkle to Xcode Project

1. Open `Quill.xcodeproj` in Xcode
2. Select the Quill project in the navigator
3. Select the Quill target
4. Go to "Package Dependencies" tab
5. Click "+" to add a package
6. Enter URL: `https://github.com/sparkle-project/Sparkle`
7. Select version 2.x
8. Click "Add Package"
9. Select "Sparkle" framework and click "Add Package"

### Step 2: Configure Appcast URL

1. Open `Quill/Quill.xcodeproj` in Xcode
2. Select Quill target → Info tab
3. Add a new key:
   - Key: `SUFeedURL`
   - Type: String
   - Value: `https://raw.githubusercontent.com/zmh/quill/main/appcast.xml`

Replace `zmh` with your GitHub username.

### Step 3: Enable Automatic Update Checks

The `AppUpdater.swift` file is already configured for automatic updates.
The "Check for Updates..." menu item has been added to the app menu.

### Step 4: Host Appcast File

**Option A: GitHub Pages (Recommended)**

1. Create a `gh-pages` branch:
   ```bash
   git checkout --orphan gh-pages
   git reset --hard
   cp appcast.xml .
   git add appcast.xml
   git commit -m "Initial appcast"
   git push origin gh-pages
   ```

2. Enable GitHub Pages:
   - Go to repository Settings → Pages
   - Source: Deploy from branch
   - Branch: `gh-pages`

3. Update `SUFeedURL` in Info.plist:
   ```
   https://zmh.github.io/quill/appcast.xml
   ```

**Option B: Main Branch (Simpler)**

Just keep `appcast.xml` in the main branch and use:
```
https://raw.githubusercontent.com/zmh/quill/main/appcast.xml
```

### Step 5: Sign Updates (Production)

For production releases, you should sign your updates with EdDSA:

1. **Generate signing keys:**
   ```bash
   # Download generate_keys from Sparkle
   ./generate_keys
   ```

2. **Save public key** to Info.plist:
   - Key: `SUPublicEDKey`
   - Value: Your public key

3. **Keep private key secure**:
   - Add to GitHub Secrets as `SPARKLE_PRIVATE_KEY`
   - Never commit to repository

4. **Sign releases** in GitHub Actions:
   ```yaml
   - name: Sign DMG
     run: |
       echo "${{ secrets.SPARKLE_PRIVATE_KEY }}" > private_key
       ./sign_update build/Quill-${{ VERSION }}.dmg
   ```

---

## Code Signing and Notarization

### Development Signing (Automatic)

For development builds, Xcode automatically signs with "Apple Development" certificate.

### Distribution Signing (Manual)

For distribution outside the Mac App Store:

1. **Create Developer ID Certificate**:
   - Xcode → Settings → Accounts → Manage Certificates
   - Click "+" → "Developer ID Application"

2. **Update Build Script**:
   The `build-release.sh` script uses automatic signing.
   For manual signing, modify the script to use:
   ```bash
   CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
   ```

3. **Enable Hardened Runtime**:
   - Select Quill target in Xcode
   - Signing & Capabilities tab
   - Enable "Hardened Runtime"
   - Enable required capabilities (Network, etc.)

### Notarization (Required for macOS 10.15+)

After building, notarize the app with Apple:

1. **Create App-Specific Password**:
   - Visit: https://appleid.apple.com
   - Sign In → Security → App-Specific Passwords
   - Generate password for "Quill Notarization"

2. **Store Credentials**:
   ```bash
   xcrun notarytool store-credentials "quill-notary" \
     --apple-id "your@email.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "app-specific-password"
   ```

3. **Notarize the DMG**:
   ```bash
   # Submit for notarization
   xcrun notarytool submit build/Quill-1.0.0.dmg \
     --keychain-profile "quill-notary" \
     --wait

   # Staple the notarization
   xcrun stapler staple build/Quill-1.0.0.dmg
   ```

4. **Verify**:
   ```bash
   spctl -a -t open --context context:primary-signature -v build/Quill-1.0.0.dmg
   ```

### GitHub Actions Notarization

To automate notarization in GitHub Actions:

1. **Add Secrets**:
   - `APPLE_ID` - Your Apple ID email
   - `APPLE_ID_PASSWORD` - App-specific password
   - `APPLE_TEAM_ID` - Your team ID

2. **Update Workflow**:
   Add notarization step to `.github/workflows/release.yml`:
   ```yaml
   - name: Notarize DMG
     env:
       APPLE_ID: ${{ secrets.APPLE_ID }}
       APPLE_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
       APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
     run: |
       # Create temporary keychain
       security create-keychain -p actions temp.keychain
       security default-keychain -s temp.keychain
       security unlock-keychain -p actions temp.keychain

       # Submit for notarization
       xcrun notarytool submit "build/Quill-${VERSION}.dmg" \
         --apple-id "$APPLE_ID" \
         --password "$APPLE_PASSWORD" \
         --team-id "$APPLE_TEAM_ID" \
         --wait

       # Staple
       xcrun stapler staple "build/Quill-${VERSION}.dmg"
   ```

---

## Troubleshooting

### Build Fails with Code Sign Error

**Problem**: `errSecInternalComponent` or signing errors

**Solution**:
1. Open Keychain Access
2. Right-click on "Apple Development" certificate
3. Select "Get Info" → Trust → Always Trust
4. Restart Xcode

### DMG Creation Fails

**Problem**: `hdiutil: attach failed - Resource busy`

**Solution**:
```bash
# List mounted volumes
hdiutil info

# Detach any Quill volumes
hdiutil detach "/Volumes/Quill*" -force

# Retry DMG creation
./Scripts/create-dmg.sh 1.0.0
```

### Sparkle Updates Not Working

**Problem**: "Check for Updates" does nothing

**Solution**:
1. Verify `SUFeedURL` is set in Info.plist
2. Check appcast.xml is accessible:
   ```bash
   curl https://your-appcast-url.xml
   ```
3. Ensure app is running macOS version (not iOS simulator)
4. Check Console.app for Sparkle error messages

### Notarization Fails

**Problem**: "Invalid bundle" or "Notarization failed"

**Solution**:
1. Check notarization log:
   ```bash
   xcrun notarytool log <submission-id> --keychain-profile "quill-notary"
   ```
2. Common issues:
   - Missing Hardened Runtime
   - Invalid entitlements
   - Unsigned frameworks
   - Bundle identifier mismatch

### GitHub Actions Fails

**Problem**: Workflow fails at build step

**Solution**:
1. Check workflow logs in GitHub Actions tab
2. Verify Xcode version matches your local version
3. Ensure all scripts have execute permissions:
   ```bash
   chmod +x Scripts/*.sh
   git add Scripts/*.sh
   git commit -m "Fix script permissions"
   ```

---

## Additional Resources

- **Sparkle Documentation**: https://sparkle-project.org/documentation/
- **Apple Notarization Guide**: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Xcode Build Settings**: https://developer.apple.com/documentation/xcode/build-settings-reference
- **GitHub Actions macOS**: https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources

---

## Release Checklist

Use this checklist when creating a new release:

- [ ] Update `VERSION` file
- [ ] Update `appcast.xml` with release notes
- [ ] Test app functionality locally
- [ ] Run `./Scripts/build-release.sh <version>`
- [ ] Run `./Scripts/create-dmg.sh <version>`
- [ ] Test DMG installation
- [ ] Verify app launches and works correctly
- [ ] Create git tag: `git tag v<version>`
- [ ] Push tag: `git push origin v<version>`
- [ ] Wait for GitHub Actions to complete
- [ ] Download and test release from GitHub
- [ ] Update appcast.xml in gh-pages branch
- [ ] Announce release (Twitter, blog, etc.)
- [ ] Monitor for user issues

---

## Support

For issues with the release process:
1. Check [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs
3. Check Xcode build logs
4. Open an issue on GitHub

For user support:
- GitHub Issues: https://github.com/zmh/quill/issues
- Email: your@email.com
