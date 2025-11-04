# Quill - Native WordPress Editor for macOS

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2015.5%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Quill is a native macOS application that provides a distraction-free writing experience for WordPress bloggers. Built with SwiftUI and featuring a custom Gutenberg block editor implementation, Quill offers seamless offline support and a beautiful native interface for managing your WordPress content.

## ✨ Features

### 🎨 Native Gutenberg Block Editor
- Full support for core WordPress blocks (paragraphs, headings, lists, quotes, code, images)
- Slash commands (`/`) for quick block insertion
- Native macOS context menus for block manipulation
- Inline link editing with native popovers
- Image upload with automatic WordPress media library integration
- Real-time block manipulation without page refreshes

### 🖊️ Distraction-Free Writing
- Clean, minimal interface focused on content
- Three-pane layout: Sites → Posts → Editor
- Customizable typography (font family and size)
- Word count tracking
- Focus mode for immersive writing

### 🌐 Offline-First Design
- Full offline support with local SwiftData storage
- Automatic synchronization when connected
- Conflict resolution for concurrent edits
- Draft posts work completely offline

### 🎨 Native macOS Experience
- Beautiful native SwiftUI interface
- Light and dark mode support with dynamic colors
- macOS-style sidebars with translucent materials
- Native keyboard shortcuts
- Proper macOS button styles and interactions

### 🔐 Security & Privacy
- **HTTPS Required**: All WordPress connections use HTTPS only
- **Certificate Validation**: SSL/TLS certificates validated to prevent MITM attacks
- **Keychain Storage**: Credentials stored exclusively in macOS Keychain with device-only access
- **No Data Collection**: Zero analytics, tracking, or telemetry
- **Application Passwords**: Support for WordPress Application Passwords (recommended)
- **Input Validation**: URL validation prevents SSRF attacks on private networks
- **No Logging**: User content never logged in production builds

### 📝 Post Management
- Create, edit, and publish posts
- Draft, published, and scheduled post support
- Post metadata editing (slug, excerpt, publish date)
- Search and filter posts by status
- Bulk operations support

## 📋 Requirements

- macOS 15.5 (Sequoia) or later
- Xcode 16.0 or later (for building from source)
- **WordPress site with HTTPS enabled** (HTTP not supported for security)
- WordPress REST API enabled (WordPress 4.7+)
- WordPress Application Password (for self-hosted sites, recommended)

## 🚀 Getting Started

### Option 1: Download Pre-built App
*Coming soon - pre-built releases will be available in the Releases section*

### Option 2: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/quill-app.git
cd quill-app
```

2. Open in Xcode:
```bash
open Quill/Quill.xcodeproj
```

3. Build and run (⌘R)

### Option 3: Build and Run from Command Line

1. Build the app:
```bash
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -configuration Debug build
```

2. Run the app:
```bash
open /Users/$USER/Library/Developer/Xcode/DerivedData/Quill-*/Build/Products/Debug/Quill.app
```

Or build and run in one command:
```bash
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -configuration Debug build && \
open ~/Library/Developer/Xcode/DerivedData/Quill-*/Build/Products/Debug/Quill.app
```

## 🔧 Configuration

### Setting Up Your WordPress Site

**Security Note**: Quill requires HTTPS for all WordPress connections. HTTP URLs will be automatically upgraded to HTTPS.

1. **Ensure your WordPress site uses HTTPS**
   - Your site URL must start with `https://`
   - HTTP connections are blocked for security

2. **Launch Quill and open Settings (⌘,)**

3. **Go to the "Accounts" tab**

4. **Enter your WordPress site URL**
   - Example: `https://yourblog.com`
   - The `https://` prefix is required

5. **For self-hosted WordPress sites:**
   - Create an Application Password in WordPress admin → Users → Your Profile → Application Passwords
   - Enter your WordPress username
   - Enter the generated Application Password (not your regular password)
   - Click "Connect"

**Important**: Never use your main WordPress password. Always create an Application Password for better security. Application Passwords can be revoked independently without changing your main password.

### Customizing the Editor

In Settings → General:
- Choose your preferred font family
- Adjust font size (12-24pt)
- Toggle word count display
- Configure auto-save behavior

## 🏗️ Architecture

Quill is built with modern Apple technologies:

- **SwiftUI**: Entire UI built with declarative SwiftUI
- **SwiftData**: Local persistence and offline support
- **WebKit**: Gutenberg editor rendering with native bridge
- **Combine**: Reactive data flow and synchronization
- **async/await**: Modern concurrency for API calls

### Key Components

- `ContentView.swift` - Main app interface and navigation
- `GutenbergWebView.swift` - Custom WebView implementation for Gutenberg
- `WordPressAPI.swift` - REST API client for WordPress
- `Post.swift` - SwiftData model for local storage
- `SyncManager.swift` - Handles offline sync and conflict resolution

## 🛠️ Development

### Building for Development

```bash
# Debug build
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -configuration Debug build

# Run tests
xcodebuild test -project Quill/Quill.xcodeproj -scheme Quill -destination 'platform=macOS'
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI's declarative style
- Leverage Swift concurrency (async/await)
- Keep views small and focused
- Use SwiftData for all persistence

## 🔒 Security

Security is a top priority for Quill. We implement multiple layers of protection:

### Network Security
- **HTTPS Only**: All API connections require HTTPS
- **Certificate Validation**: SSL/TLS certificates validated on every request
- **No HTTP Fallback**: HTTP URLs automatically upgraded to HTTPS
- **Private IP Blocking**: Localhost and private IP ranges blocked to prevent SSRF

### Credential Protection
- **Keychain Storage**: All passwords stored in macOS Keychain
- **Device-Only Access**: Credentials use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Never in Files**: Credentials never stored in database, UserDefaults, or files
- **No iCloud Sync**: Credentials don't sync across devices for security

### Privacy
- **No Logging**: User content never logged in production builds
- **No Analytics**: Zero data collection or telemetry
- **Local Storage**: All content stored locally on your Mac
- **Minimal API Calls**: Only necessary data transmitted to WordPress

### Reporting Security Issues

**Do not** open public GitHub issues for security vulnerabilities.

Please report security issues responsibly by emailing: **[Your Email Here]**

For more details, see [SECURITY.md](SECURITY.md)

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development process.

Quick start:
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure:
- All tests pass
- Code follows Swift style guide
- Security checklist verified (see SECURITY.md)
- No hardcoded credentials or secrets

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI and SwiftData
- Gutenberg editor inspiration from WordPress
- Icons from SF Symbols
- [iA Writer Fonts](https://github.com/iaolo/iA-Fonts) - Typography (MIT License)

## 📬 Contact

For questions, suggestions, or issues, please open a GitHub issue.

---

**Note**: This is an independent project and is not affiliated with or endorsed by WordPress or Automattic.