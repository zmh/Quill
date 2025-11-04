# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security Practices

Quill takes security seriously. This document outlines our security practices and how to report vulnerabilities.

### Data Protection

#### Credential Storage
- **Keychain Storage**: All WordPress passwords and authentication tokens are stored exclusively in the system Keychain
- **Never in Database**: Credentials are never stored in the local SQLite database or UserDefaults
- **Device-Only Access**: Passwords use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection, meaning:
  - Credentials are only accessible when the device is unlocked
  - Credentials cannot be accessed after the device locks
  - Credentials do not sync across devices via iCloud Keychain

#### Network Security
- **HTTPS Only**: All WordPress API connections require HTTPS
- **Certificate Validation**: SSL/TLS certificates are validated to prevent Man-in-the-Middle (MITM) attacks
- **No HTTP Fallback**: HTTP URLs are automatically converted to HTTPS with warnings logged
- **Private IP Blocking**: Connections to localhost, loopback addresses, and private IP ranges are blocked to prevent SSRF attacks

#### Content Privacy
- **No Logging**: User content is never logged to console or debug output in production builds
- **Local Storage**: All content is stored locally in encrypted SQLite database via SwiftData
- **Minimal API Calls**: Only necessary data is transmitted to WordPress servers

### Authentication

Quill supports WordPress authentication through:

1. **Application Passwords** (Recommended)
   - WordPress 5.6+ built-in feature
   - Create at: WordPress Admin → Users → Profile → Application Passwords
   - Revocable without changing main password
   - Limited scope and permissions

2. **Basic Authentication** (Self-hosted only)
   - Uses HTTP Basic Auth over HTTPS
   - Credentials base64-encoded (not encrypted)
   - Only secure over HTTPS connection
   - Certificate validation prevents interception

**Security Note**: Application Passwords are strongly recommended over traditional passwords as they can be revoked independently and have limited scope.

### Build Configurations

#### Debug Builds
- Debug console available for troubleshooting
- Extended logging enabled
- Development features accessible

#### Release Builds
- Debug console completely disabled via `#if DEBUG` compilation flags
- Minimal logging (errors only)
- No sensitive data in logs
- Production-ready security

### Third-Party Dependencies

Quill has minimal dependencies:
- **iA Writer Fonts**: Typography (MIT License) - No security implications
- **SwiftData**: Apple's native framework - Inherits Apple's security model
- **SwiftUI**: Apple's native framework - Inherits Apple's security model

No third-party networking libraries or analytics SDKs are used, reducing attack surface.

### Code Security

#### Input Validation
- All WordPress URLs validated before use
- Private IP ranges and localhost blocked
- Malformed URLs rejected
- HTTPS scheme enforced

#### Output Encoding
- HTML entities properly encoded/decoded
- JavaScript string escaping using JSON encoding
- XSS prevention in web views

#### Memory Safety
- Built with Swift (memory-safe language)
- No manual memory management
- No known buffer overflow vulnerabilities

## Reporting a Vulnerability

If you discover a security vulnerability in Quill, please report it responsibly:

### Where to Report

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please email security reports to: **[Your Email Here]**

### What to Include

Please include the following in your report:

1. **Description**: Clear description of the vulnerability
2. **Impact**: What an attacker could accomplish
3. **Steps to Reproduce**: Detailed steps to reproduce the issue
4. **Affected Versions**: Which versions are affected
5. **Suggested Fix**: If you have ideas for a fix (optional)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Varies by severity
  - Critical: 1-7 days
  - High: 7-30 days
  - Medium: 30-90 days
  - Low: Best effort basis

### Disclosure Policy

- **Coordinated Disclosure**: We request 90 days to fix vulnerabilities before public disclosure
- **Credit**: Security researchers will be credited (if desired) in release notes
- **CVE Assignment**: Critical vulnerabilities will receive CVE identifiers when appropriate

## Security Checklist for Contributors

If you're contributing to Quill, please ensure:

- [ ] No credentials hardcoded in code
- [ ] No secrets committed to version control
- [ ] All API calls use HTTPS
- [ ] User input is validated and sanitized
- [ ] No sensitive data logged to console
- [ ] Credentials only stored in Keychain
- [ ] All user content properly encoded/decoded
- [ ] No unnecessary network requests
- [ ] Error messages don't leak sensitive information
- [ ] Debug code wrapped in `#if DEBUG` flags

## Security Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Security Documentation](https://developer.apple.com/documentation/security)
- [WordPress REST API Security](https://developer.wordpress.org/rest-api/using-the-rest-api/authentication/)

## Updates and Notifications

Security updates will be:
- Released via GitHub releases
- Documented in `CHANGELOG.md`
- Announced on the repository README
- Tagged with `security` label

## License

This security policy is part of the Quill project and follows the same license.
