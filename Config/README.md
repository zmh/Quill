# Configuration Setup

This directory contains configuration files for local development and CI/CD.

## Local Development Setup

1. Copy the example config file:
   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

2. Edit `Config/Local.xcconfig` and add your Apple Developer Team ID:
   - Find your Team ID at: https://developer.apple.com/account/#!/membership
   - Replace `YOUR_TEAM_ID_HERE` with your actual Team ID

3. **Important**: `Local.xcconfig` is gitignored and will never be committed to the repository.

## Environment Variables for Build Scripts

The build scripts also support environment variables:

- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID
- `CODE_SIGN_IDENTITY`: Your signing certificate name
- `SKIP_CODESIGN`: Set to "true" to skip code signing (for CI/CD)

## GitHub Actions / CI Setup

For GitHub Actions, no local config is needed. The workflows use `SKIP_CODESIGN=true` to build unsigned binaries for distribution.

If you want to sign releases in CI, you'll need to:
1. Set up GitHub Secrets with your certificates
2. Update the release workflow to use the secrets
3. See DISTRIBUTION_SETUP.md for more details
