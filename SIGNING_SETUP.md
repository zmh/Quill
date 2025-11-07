# Code Signing Setup for GitHub Actions

This guide shows you how to configure GitHub Actions to build **signed** releases while keeping your credentials private.

## Prerequisites

- A valid Apple Developer ID Application certificate installed in your Keychain
- Admin access to the GitHub repository settings
- Sparkle framework installed (already in the project)

## Step 1: Export Your Developer ID Certificate

1. **Open Keychain Access** on your Mac
2. Select **"login"** keychain in the left sidebar
3. Select **"My Certificates"** category
4. Find your **"Developer ID Application"** certificate
5. Right-click and select **"Export..."**
6. Save as: `Certificates.p12`
7. Enter a strong password when prompted (you'll need this for GitHub Secrets)
8. Save the file to a secure location

## Step 2: Convert Certificate to Base64

Open Terminal and run:

```bash
base64 -i ~/Downloads/Certificates.p12 | pbcopy
```

This copies the base64-encoded certificate to your clipboard.

## Step 3: Generate Sparkle Signing Keys

Sparkle uses EdDSA signatures to verify updates. Use the provided script to generate a key pair:

```bash
# Generate keys (creates sparkle_eddsa_private.key and sparkle_eddsa_public.key)
chmod +x Scripts/generate-sparkle-keys.sh
./Scripts/generate-sparkle-keys.sh
```

The script will:
- Download the Sparkle key generation tool
- Generate a secure EdDSA key pair
- Display the keys and next steps

**IMPORTANT**: Keep `sparkle_eddsa_private.key` secure! Never commit it to the repository.

## Step 4: Add Secrets to GitHub

Go to your GitHub repository settings: **Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `APPLE_TEAM_ID` | Your Apple Team ID (e.g., `2LPS95N95U`) | Find in Apple Developer account |
| `APPLE_CERTIFICATE_BASE64` | (paste from clipboard in Step 2) | Base64-encoded .p12 certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Your .p12 password | Password you set when exporting |
| `SPARKLE_EDDSA_PRIVATE_KEY` | Contents of `sparkle_eddsa_private.key` | Private key for signing updates |
| `SPARKLE_EDDSA_PUBLIC_KEY` | Contents of `sparkle_eddsa_public.key` | Public key for verifying updates (optional) |

**Note**: To find your Apple Team ID, go to https://developer.apple.com/account and look under "Membership Details".

## Step 5: Update Info.plist with Public Key

Edit `Quill/Quill/Info.plist` and replace the placeholder with your actual Sparkle public key:

```xml
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_YOUR_SPARKLE_PUBLIC_KEY</string>
```

Replace `REPLACE_WITH_YOUR_SPARKLE_PUBLIC_KEY` with the contents of `sparkle_eddsa_public.key` from Step 3.

## Step 6: Test the Setup

1. Push your changes to GitHub
2. Create a test tag: `git tag v1.0.8 && git push origin v1.0.8`
3. GitHub Actions will build and sign the release automatically
4. Download the DMG and verify it opens without Gatekeeper warnings

## Security Notes

- The certificate and keys are stored as encrypted GitHub Secrets
- They're only accessible to GitHub Actions workflows in your repository
- Never commit certificates, keys, or passwords to the repository
- Regularly rotate your credentials according to security best practices

## Troubleshooting

**Error: "No signing identity found"**
- Verify `APPLE_CERTIFICATE_BASE64` and `APPLE_CERTIFICATE_PASSWORD` are correct
- Check that the certificate hasn't expired

**Error: "Invalid signature"**
- Ensure `SPARKLE_EDDSA_PRIVATE_KEY` matches the public key in Info.plist
- Verify the appcast.xml file has the `sparkle:edSignature` attribute

**Gatekeeper still blocks the app**
- The certificate must be a "Developer ID Application" certificate (not "Development")
- The app must be notarized (requires additional setup with Apple)
