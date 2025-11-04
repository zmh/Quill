# Installing Quill

Quill is a native WordPress editor for macOS that provides a distraction-free writing experience.

## System Requirements

- **macOS 14.0 (Sonoma) or later**
- Apple Silicon (M1/M2/M3) or Intel processor
- Internet connection for WordPress sync

## Installation

### Download

1. Go to the [Releases page](https://github.com/YOUR_USERNAME/quill/releases)
2. Download the latest `Quill-X.X.X.dmg` file

### Install

1. **Open the DMG file** you downloaded
2. **Drag Quill** to your Applications folder
3. **Eject the Quill disk image** from Finder
4. **Open Quill** from your Applications folder

### First Launch

When you first open Quill, macOS may show a warning because it's downloaded from the internet:

1. If you see "Quill cannot be opened because it is from an unidentified developer":
   - Open **System Settings** → **Privacy & Security**
   - Scroll down to the Security section
   - Click **"Open Anyway"** next to the Quill message
   - Click **"Open"** in the confirmation dialog

2. Or right-click on Quill and select **"Open"**, then click **"Open"** in the dialog

This is a standard macOS security feature for apps downloaded outside the Mac App Store.

## Automatic Updates

Quill includes automatic update checking:

- Updates are checked automatically on launch
- Manual check: **Quill menu** → **"Check for Updates..."**
- You'll be notified when new versions are available
- Updates download and install automatically with your permission

## Uninstallation

To remove Quill from your Mac:

1. Quit Quill if it's running
2. Open Applications folder
3. Drag Quill to the Trash
4. Empty Trash

### Remove User Data (Optional)

If you want to completely remove all Quill data:

```bash
# Remove application support files
rm -rf ~/Library/Application\ Support/zacharyhamed.Quill

# Remove preferences
rm -rf ~/Library/Preferences/zacharyhamed.Quill.plist

# Remove caches
rm -rf ~/Library/Caches/zacharyhamed.Quill
```

## Verification

To verify your download hasn't been tampered with:

1. Download both the DMG and `.sha256` files from the release
2. Open Terminal
3. Navigate to your Downloads folder:
   ```bash
   cd ~/Downloads
   ```
4. Verify the checksum:
   ```bash
   shasum -a 256 -c Quill-X.X.X.dmg.sha256
   ```
5. You should see: `Quill-X.X.X.dmg: OK`

## Building from Source

If you prefer to build Quill yourself:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/quill.git
cd quill

# Open in Xcode
open Quill/Quill.xcodeproj

# Build and run (⌘R)
```

See [RELEASE.md](RELEASE.md) for detailed build instructions.

## Troubleshooting

### "Quill" is damaged and can't be opened

This can happen if the download was corrupted:

1. Delete the DMG and app
2. Re-download from GitHub Releases
3. Verify the checksum (see Verification above)
4. Try again

### App won't open / crashes on launch

1. Check you're running macOS 14.0 or later:
   - Apple menu → About This Mac
2. Make sure you have the latest version of Quill
3. Try removing and reinstalling
4. Check Console.app for crash logs

### Updates not working

1. Check your internet connection
2. Quill menu → "Check for Updates..."
3. Make sure you're running a released version (not a development build)

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/quill/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/quill/discussions)
- **Email**: your@email.com

## Privacy

Quill respects your privacy:

- ✅ All posts stored locally on your Mac
- ✅ Only connects to WordPress sites you configure
- ✅ No analytics or tracking
- ✅ No data sent to third parties
- ✅ Open source - verify the code yourself

## License

Quill is open source software licensed under the MIT License.
See [LICENSE](LICENSE) for details.
