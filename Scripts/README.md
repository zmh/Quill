# Build Scripts

This directory contains scripts for building and packaging Quill for distribution.

## Scripts

### `build-release.sh`

Builds a release version of Quill for macOS.

**Usage:**
```bash
./Scripts/build-release.sh [version]
```

**Examples:**
```bash
./Scripts/build-release.sh 1.0.0
./Scripts/build-release.sh $(cat VERSION)
```

**What it does:**
1. Cleans previous builds
2. Archives the Xcode project
3. Exports signed .app to `build/Release/`
4. Shows version and size info

**Output:**
- `build/Quill.xcarchive` - Xcode archive
- `build/Release/Quill.app` - Signed application

---

### `create-dmg.sh`

Creates a distributable DMG file from the built app.

**Usage:**
```bash
./Scripts/create-dmg.sh [version]
```

**Examples:**
```bash
./Scripts/create-dmg.sh 1.0.0
./Scripts/create-dmg.sh $(cat VERSION)
```

**What it does:**
1. Verifies built app exists
2. Creates DMG staging directory
3. Adds Applications symlink
4. Configures window appearance
5. Creates compressed DMG
6. Generates SHA256 checksum

**Output:**
- `build/Quill-X.X.X.dmg` - Distributable disk image
- `build/Quill-X.X.X.dmg.sha256` - Checksum file

---

## Quick Workflow

### Complete Build & Package

```bash
# Set version
VERSION="1.0.0"

# Build and package
./Scripts/build-release.sh $VERSION
./Scripts/create-dmg.sh $VERSION

# Test
open build/Quill-$VERSION.dmg
```

### Using VERSION file

```bash
# Read version from file
./Scripts/build-release.sh $(cat VERSION)
./Scripts/create-dmg.sh $(cat VERSION)
```

### Clean Build

```bash
# Remove all build artifacts
rm -rf build/

# Rebuild
./Scripts/build-release.sh 1.0.0
```

---

## Configuration

### Team ID

The scripts use team ID `86G95Q55DC`. To change this:

1. Open `build-release.sh`
2. Find `DEVELOPMENT_TEAM="86G95Q55DC"`
3. Replace with your team ID

Find your team ID:
- Xcode → Settings → Accounts → [Your Account] → Team ID
- Or: https://developer.apple.com/account

### Bundle Identifier

Current: `zacharyhamed.Quill`

To change:
1. Open Xcode project
2. Select Quill target → General tab
3. Change Bundle Identifier
4. Update in all scripts if referenced

### Signing

Scripts use Automatic signing by default.

For manual signing:
1. Edit `build-release.sh`
2. Change `CODE_SIGN_STYLE=Automatic` to `CODE_SIGN_STYLE=Manual`
3. Set `CODE_SIGN_IDENTITY="Developer ID Application: Your Name"`

---

## Troubleshooting

### Permission Denied

Make scripts executable:
```bash
chmod +x Scripts/*.sh
```

### Build Fails

Check Xcode version:
```bash
xcodebuild -version
```

Should be Xcode 16.0 or later.

### DMG Creation Fails

Unmount any existing volumes:
```bash
hdiutil detach "/Volumes/Quill*" -force
```

### Signing Errors

1. Open Keychain Access
2. Find "Apple Development" certificate
3. Right-click → Get Info → Trust → Always Trust
4. Restart Xcode

---

## Advanced

### Custom Export Options

Edit the export options in `build-release.sh`:

```xml
<dict>
    <key>method</key>
    <string>mac-application</string>
    <!-- Add custom options here -->
</dict>
```

### Custom DMG Appearance

Edit `create-dmg.sh` to customize:
- Window size: `set the bounds of container window to {100, 100, 650, 450}`
- Icon size: `set icon size of viewOptions to 128`
- Icon positions: `set position of item`
- Background color/image

### Parallel Builds

Build for multiple configurations:
```bash
# Build debug and release
xcodebuild -project Quill/Quill.xcodeproj \
  -scheme Quill \
  -configuration Debug \
  -configuration Release \
  build
```

---

## CI/CD Integration

These scripts are used by GitHub Actions in `.github/workflows/release.yml`.

To run locally mimicking CI:
```bash
# Extract version from git tag
VERSION=${GITHUB_REF#refs/tags/v}

# Or use current commit
VERSION=$(git describe --tags --always)

./Scripts/build-release.sh $VERSION
./Scripts/create-dmg.sh $VERSION
```

---

## See Also

- [DISTRIBUTION_SETUP.md](../DISTRIBUTION_SETUP.md) - Initial setup guide
- [RELEASE.md](../RELEASE.md) - Complete release process
- [.github/workflows/release.yml](../.github/workflows/release.yml) - CI/CD workflow
