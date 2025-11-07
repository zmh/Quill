# Notarization Setup for GitHub Actions

This guide shows how to configure automatic notarization for macOS apps distributed via GitHub releases.

## Why Notarization is Required

Starting with macOS 10.15 (Catalina), all apps distributed outside the Mac App Store must be:
1. **Signed** with a Developer ID Application certificate ✅ (already configured)
2. **Notarized** by Apple (this guide)

Without notarization, users see: "Apple could not verify [app] is free of malware"

## Option A: App Store Connect API Key (Recommended)

This is the recommended approach because:
- Works with GitHub Actions (no 2FA prompts)
- More secure (scoped permissions)
- Easier to rotate/revoke

### Step 1: Create App Store Connect API Key

1. Go to https://appstoreconnect.apple.com/access/api
2. Click the **Keys** tab
3. Click **+** to generate a new key
4. Name: `GitHub Actions Notarization`
5. Access: Select **Developer**
6. Click **Generate**
7. **Download the .p8 file** (you can only download this once!)
8. Note the following values:
   - **Issuer ID** (UUID format, e.g., `d8e8fca2-...`)
   - **Key ID** (10 characters, e.g., `ABC123DEFG`)

### Step 2: Add Secrets to GitHub

Go to: https://github.com/zmh/Quill/settings/secrets/actions

Add these 3 new secrets:

| Secret Name | Value | Example |
|------------|-------|---------|
| `APPLE_API_KEY_ID` | Key ID from Step 1 | `ABC123DEFG` |
| `APPLE_API_ISSUER_ID` | Issuer ID from Step 1 | `d8e8fca2-7dc8-479b-a376-cd07f...` |
| `APPLE_API_KEY_CONTENT` | Full content of the .p8 file | `-----BEGIN PRIVATE KEY-----\nMIGT...` |

**For the .p8 file content:**
```bash
cat ~/Downloads/AuthKey_ABC123DEFG.p8 | pbcopy
```
Then paste into the secret field.

### Step 3: Configure Your Apple Developer Team ID

You should already have this from the code signing setup:
- `APPLE_TEAM_ID` = Your 10-character team ID (e.g., `C68GA48KN3`)

### Step 4: Test Notarization

Once the secrets are added, create a new release tag:
```bash
git tag v1.0.10
git push origin v1.0.10
```

The GitHub Actions workflow will now:
1. Build and sign the app
2. Create and sign the DMG
3. **Submit to Apple for notarization** (takes 1-5 minutes)
4. **Staple the notarization ticket** to the DMG
5. Upload to GitHub releases

## Option B: Apple ID + App-Specific Password (Alternative)

This method works but requires generating an app-specific password since your Apple ID likely has 2FA enabled.

### Step 1: Generate App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. In the **Security** section, click **App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Label: `GitHub Actions Notarization`
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### Step 2: Add Secrets to GitHub

| Secret Name | Value |
|------------|-------|
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | App-specific password from Step 1 |
| `APPLE_TEAM_ID` | Your 10-character team ID |

### Step 3: Update Workflow

The workflow will need to use `notarytool` with `--apple-id` instead of `--key`.

## Verification

After notarization completes:

1. Download the DMG from the GitHub release
2. Double-click to open (should work without warnings)
3. Verify notarization:
   ```bash
   spctl -a -vvv -t install "/path/to/Quill-1.0.10.dmg"
   ```
   Should show: `source=Notarized Developer ID`

## Troubleshooting

**Error: "Credentials are invalid"**
- Verify API Key ID and Issuer ID are correct
- Ensure .p8 file content is complete (including BEGIN/END lines)

**Error: "Could not find credentials"**
- Check that all 3 secrets are set (KEY_ID, ISSUER_ID, KEY_CONTENT)
- Secret names are case-sensitive

**Notarization takes a long time**
- Apple's notarization typically takes 1-5 minutes
- Large apps may take longer
- Check status with: `xcrun notarytool history --key /path/to/key.p8`

**DMG still shows warning**
- Ensure notarization ticket is stapled: `xcrun stapler staple file.dmg`
- Verify stapling: `xcrun stapler validate file.dmg`

## Security Notes

- Keep your .p8 API key file secure
- Never commit API keys to the repository
- Rotate keys annually
- Use GitHub Secrets to encrypt credentials
- App Store Connect API Keys can be revoked at any time

## References

- [Apple Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [notarytool Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
