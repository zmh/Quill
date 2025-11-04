# Distribution Setup Instructions

Quick setup guide for enabling GitHub distribution and automatic updates for Quill.

## Step 1: Add Sparkle Framework

1. Open `Quill/Quill.xcodeproj` in Xcode
2. Select the Quill project → Quill target
3. Go to "Package Dependencies" tab
4. Click "+" → Add Package Dependency
5. Enter: `https://github.com/sparkle-project/Sparkle`
6. Version: Select 2.x (latest)
7. Click "Add Package" → Select "Sparkle" → Click "Add Package"

## Step 2: Configure Appcast URL

1. In Xcode, select Quill target
2. Go to "Info" tab
3. Hover over any key and click "+" to add a new key
4. Add:
   - **Key**: `SUFeedURL`
   - **Type**: String
   - **Value**: `https://raw.githubusercontent.com/zmh/quill/main/appcast.xml`

   Replace `zmh` with your actual GitHub username.

## Step 3: Update Appcast Template

Edit `appcast.xml` and replace:
- `zmh` with your GitHub username
- Update the version and release notes

## Step 4: Test Locally

```bash
# Build release version
./Scripts/build-release.sh 1.0.0

# Create DMG
./Scripts/create-dmg.sh 1.0.0

# Test the DMG
open build/Quill-1.0.0.dmg
```

## Step 5: Create First Release

```bash
# Commit all changes
git add .
git commit -m "Add distribution setup"

# Create and push tag
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

GitHub Actions will automatically:
- Build the app
- Create DMG
- Create GitHub Release
- Generate appcast.xml

## Step 6: Setup Appcast Hosting

**Option A: Main Branch (Easiest)**

The appcast.xml in your main branch will work automatically with the URL format:
```
https://raw.githubusercontent.com/zmh/quill/main/appcast.xml
```

**Option B: GitHub Pages (Recommended for Production)**

1. Create gh-pages branch:
   ```bash
   git checkout --orphan gh-pages
   git reset --hard
   cp appcast.xml .
   git add appcast.xml
   git commit -m "Initial appcast"
   git push origin gh-pages
   ```

2. Enable GitHub Pages:
   - Settings → Pages → Source: gh-pages

3. Update Info.plist `SUFeedURL` to:
   ```
   https://zmh.github.io/quill/appcast.xml
   ```

## Step 7: Verify Updates Work

1. Build and run the app
2. Go to "Quill" menu → "Check for Updates..."
3. Verify it checks for updates (will show "You're up to date" if on latest)

## Optional: Code Signing Setup

For distribution outside your development machine:

### Create App-Specific Password

1. Visit https://appleid.apple.com
2. Sign In → Security → App-Specific Passwords
3. Generate password labeled "Quill Notarization"
4. Save this password securely

### Add GitHub Secrets

In your GitHub repository:
1. Settings → Secrets and variables → Actions
2. Add these secrets:
   - `APPLE_ID`: Your Apple ID email
   - `APPLE_ID_PASSWORD`: The app-specific password
   - `APPLE_TEAM_ID`: Your team ID (find in developer.apple.com)

### Enable Notarization in Workflow

Uncomment the notarization step in `.github/workflows/release.yml`

## That's It!

You're now set up for:
- ✅ Automated builds on version tags
- ✅ GitHub Releases with DMG files
- ✅ Automatic update checking in the app
- ✅ Professional distribution workflow

## Next Steps

- Read [RELEASE.md](RELEASE.md) for detailed release process
- Customize DMG appearance in `Scripts/create-dmg.sh`
- Add release notes templates
- Setup signing keys for Sparkle (for production)

## Quick Commands Reference

```bash
# Build release
./Scripts/build-release.sh 1.0.0

# Create DMG
./Scripts/create-dmg.sh 1.0.0

# Create release tag
git tag v1.0.0 && git push origin v1.0.0

# Test DMG
open build/Quill-1.0.0.dmg

# Verify checksum
shasum -a 256 -c build/Quill-1.0.0.dmg.sha256
```

## Troubleshooting

If builds fail, ensure:
- All scripts have execute permissions: `chmod +x Scripts/*.sh`
- Xcode command line tools installed: `xcode-select --install`
- Correct development team ID in project settings

For more help, see [RELEASE.md](RELEASE.md#troubleshooting).
