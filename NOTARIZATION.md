# Notarization Guide for Quill

This guide explains how to properly sign and notarize Quill for distribution, which removes the "Apple could not verify" warning.

## Why Notarize?

**Without notarization:**
- Users see: "Apple could not verify Quill is free of malware"
- Users must right-click → Open to bypass warning
- Not ideal for public distribution

**With notarization:**
- ✅ App opens normally with double-click
- ✅ No security warnings
- ✅ Professional distribution
- ✅ Users trust the app

---

## Prerequisites

### 1. Apple Developer Account
**Required:** $99/year Apple Developer Program membership
- Sign up: https://developer.apple.com/programs/

### 2. Developer ID Certificate
You need a "Developer ID Application" certificate:

1. Open **Xcode** → **Settings** → **Accounts**
2. Sign in with your Apple ID
3. Select your team → **Manage Certificates**
4. Click **"+"** → **"Developer ID Application"**
5. Certificate will be created and installed

### 3. App-Specific Password
For notarization automation:

1. Go to https://appleid.apple.com
2. Sign in → **Security** → **App-Specific Passwords**
3. Click **"+"** to generate new password
4. Name it: "Quill Notarization"
5. **Save this password** - you'll need it later

---

## Setup Notarization

### Step 1: Store Credentials

Store your notarization credentials securely:

```bash
xcrun notarytool store-credentials "quill-notary" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Replace:
- `your@email.com` - Your Apple ID
- `YOUR_TEAM_ID` - Your team ID (find in developer.apple.com)
- `xxxx-xxxx-xxxx-xxxx` - The app-specific password you created

This stores credentials in your keychain as "quill-notary".

### Step 2: Update Build Script

Edit your team ID in `Scripts/build-release.sh`:

```bash
DEVELOPMENT_TEAM="YOUR_TEAM_ID"  # Replace with your actual team ID
```

### Step 3: Build Signed Version

Build with signing (don't set SKIP_CODESIGN):

```bash
./Scripts/build-release.sh 1.0.0
```

The app will be signed with your Developer ID certificate.

### Step 4: Notarize the DMG

After creating the DMG:

```bash
# Create DMG
./Scripts/create-dmg.sh 1.0.0

# Notarize it
./Scripts/notarize-dmg.sh build/Quill-1.0.0.dmg
```

The notarization process:
1. Submits DMG to Apple (~30 seconds)
2. Apple scans for malware (~2-5 minutes)
3. Returns notarization ticket
4. Staples ticket to DMG

### Step 5: Verify

```bash
# Check if DMG is notarized
spctl -a -t open --context context:primary-signature -v build/Quill-1.0.0.dmg

# Should show: "accepted"
```

---

## For GitHub Actions

To notarize in CI/CD:

### 1. Add GitHub Secrets

In your repository: **Settings** → **Secrets and variables** → **Actions**

Add these secrets:
- `APPLE_ID` - Your Apple ID email
- `APPLE_ID_PASSWORD` - The app-specific password
- `APPLE_TEAM_ID` - Your team ID
- `SIGNING_CERTIFICATE_P12` - Your certificate (base64 encoded)
- `SIGNING_CERTIFICATE_PASSWORD` - Certificate password

### 2. Export Certificate

Export your Developer ID certificate:

```bash
# Export from keychain
security find-identity -v -p codesigning

# Export certificate (will prompt for password)
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities -f pkcs12 \
  -o DeveloperID.p12

# Base64 encode for GitHub
base64 -i DeveloperID.p12 -o DeveloperID.p12.base64

# Copy contents of DeveloperID.p12.base64 to GitHub secret
cat DeveloperID.p12.base64 | pbcopy
```

### 3. Update Workflow

The workflow in `.github/workflows/release.yml` has comments showing where to add notarization steps.

Uncomment and configure the notarization section.

---

## Quick Reference

### Local Development

```bash
# Build signed
./Scripts/build-release.sh 1.0.0

# Create DMG
./Scripts/create-dmg.sh 1.0.0

# Notarize
./Scripts/notarize-dmg.sh build/Quill-1.0.0.dmg

# Verify
spctl -a -t open --context context:primary-signature -v build/Quill-1.0.0.dmg
```

### Status Check

```bash
# Check notarization status
xcrun notarytool history --keychain-profile "quill-notary"

# Get detailed log
xcrun notarytool log <submission-id> --keychain-profile "quill-notary"
```

---

## Troubleshooting

### "No Developer ID certificate found"

**Solution:**
1. Open Xcode → Settings → Accounts
2. Select your team → Manage Certificates
3. Click "+" → "Developer ID Application"
4. Restart Xcode

### "Invalid credentials"

**Solution:**
1. Verify Apple ID and password are correct
2. Ensure you're using an **app-specific password**, not your regular password
3. Check team ID matches your developer account

### "Notarization failed"

**Solution:**
```bash
# Get the failure log
xcrun notarytool log <submission-id> --keychain-profile "quill-notary"
```

Common issues:
- App not properly signed
- Missing hardened runtime
- Invalid entitlements
- Wrong bundle identifier

### "stapler: The staple and validate action failed"

**Solution:**
- This can happen if Apple's notarization service is temporarily unavailable
- Wait a few minutes and try again
- Verify the notarization actually succeeded first

---

## Cost & Timeline

**Setup:**
- One-time: 30 minutes (certificates, passwords, testing)
- Ongoing: Automated

**Per Release:**
- Build: ~5 minutes
- Notarization: ~2-5 minutes
- Total: ~10 minutes

**Cost:**
- Apple Developer Program: $99/year
- Notarization service: Free

---

## Current Setup

Right now, Quill builds are **unsigned** for simplicity. This means:
- ✅ Free to distribute
- ✅ No Apple Developer account needed
- ❌ Users see security warning
- ❌ Must right-click → Open

**For v1.0.0:** Users can right-click → Open (one time)

**For future releases:** Follow this guide to enable notarization

---

## Resources

- Apple Notarization Guide: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- notarytool Documentation: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
- Code Signing Guide: https://developer.apple.com/support/code-signing/

---

## Decision Matrix

| Scenario | Recommendation |
|----------|---------------|
| Personal use only | Skip notarization, use right-click → Open |
| Small private beta | Skip notarization, instruct users to right-click |
| Public release (< 100 users) | Consider notarization |
| Public release (> 100 users) | **Definitely notarize** |
| App Store distribution | Required (different process) |

---

For **v1.0.0**, the app works perfectly - users just need to right-click → Open once.

For **v1.1.0+**, consider setting up notarization for a smoother user experience.
