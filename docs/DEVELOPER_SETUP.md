# Developer Setup Guide

This guide helps you set up Quill for local development without exposing your developer credentials in the repository.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/quill.git
cd quill
```

### 2. Configure Your Developer Credentials

Create a local configuration file with your Apple Developer credentials:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Edit `Config/Local.xcconfig` and add your information:

```xcconfig
// Your Apple Developer Team ID
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE

// Your Developer ID Application certificate (for signed releases)
CODE_SIGN_IDENTITY_RELEASE = Developer ID Application: Your Name (YOUR_TEAM_ID)

// Your signing identity for debug builds
CODE_SIGN_IDENTITY_DEBUG = Apple Development
```

### 3. Find Your Apple Developer Team ID

1. Go to https://developer.apple.com/account/#!/membership
2. Sign in with your Apple Developer account
3. Your Team ID is displayed under "Membership Information"

### 4. Open in Xcode

```bash
open Quill/Quill.xcodeproj
```

Xcode will now use your credentials from `Config/Local.xcconfig` for code signing.

## Building the App

### Debug Builds (Development)

Build and run in Xcode normally. Your debug signing identity from `Local.xcconfig` will be used automatically.

### Release Builds (Distribution)

For unsigned releases (like GitHub Actions does):

```bash
export SKIP_CODESIGN=true
./Scripts/build-release.sh 1.0.0
```

For signed releases with your Developer ID:

```bash
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./Scripts/build-release.sh 1.0.0
```

## Security Notes

### What's Kept Private

The following files are **automatically excluded** from git (in `.gitignore`):

- `Config/Local.xcconfig` - Your local developer credentials
- `*.p12`, `*.cer` - Code signing certificates
- `*.mobileprovision` - Provisioning profiles
- `.env*` - Environment files with secrets
- `*_priv.pem` - Sparkle signing keys

### What's Safe to Commit

- `Config/Local.xcconfig.example` - Template file (no real credentials)
- `Config/README.md` - Configuration documentation
- All other project files - No credentials hardcoded

### Developer Credentials Are Never Committed

Your Apple Developer Team ID and signing certificates are:
1. **Removed** from the Xcode project file
2. **Loaded** from your local `Config/Local.xcconfig` file
3. **Ignored** by git (will never be committed)

## GitHub Actions / CI

The GitHub Actions workflows automatically build **unsigned** releases using:

```yaml
env:
  SKIP_CODESIGN: "true"
```

This allows the project to build publicly without requiring access to signing certificates.

## Troubleshooting

### "No signing certificate found" error

Make sure you've:
1. Created `Config/Local.xcconfig` from the example
2. Added your actual Team ID (not `YOUR_TEAM_ID_HERE`)
3. Installed your Apple Developer certificates in Keychain

### "DEVELOPMENT_TEAM not set" error

When using build scripts, either:
- Set environment variable: `export DEVELOPMENT_TEAM="YOUR_TEAM_ID"`
- Or use `SKIP_CODESIGN=true` for unsigned builds

### Xcode asks for signing every time

Check that:
1. `Config/Local.xcconfig` exists and has valid values
2. The file is in the correct location: `Config/Local.xcconfig`
3. Clean build folder in Xcode (Cmd+Shift+K)

## Contributing

When contributing to this repository:

1. **Never commit** signing certificates or Team IDs
2. **Never modify** `.gitignore` to expose credentials
3. **Always use** `Config/Local.xcconfig` for your credentials
4. **Test** that unsigned builds work: `SKIP_CODESIGN=true ./Scripts/build-release.sh`

## Additional Resources

- [Apple Developer Account](https://developer.apple.com/account/)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Xcode Build Configuration](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project)
