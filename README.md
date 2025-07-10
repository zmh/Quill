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

### 🔐 Secure Authentication
- Support for WordPress Application Passwords
- Credentials stored securely in macOS Keychain
- No passwords or tokens stored in code or preferences

### 📝 Post Management
- Create, edit, and publish posts
- Draft, published, and scheduled post support
- Post metadata editing (slug, excerpt, publish date)
- Search and filter posts by status
- Bulk operations support

## 📋 Requirements

- macOS 15.5 (Sequoia) or later
- Xcode 16.0 or later (for building from source)
- WordPress site with REST API enabled
- WordPress Application Password (for self-hosted sites)

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

## 🔧 Configuration

### Setting Up Your WordPress Site

1. Launch Quill and open Settings (⌘,)
2. Go to the "Accounts" tab
3. Enter your WordPress site URL
4. For self-hosted WordPress:
   - Create an Application Password in WordPress admin → Users → Profile
   - Enter your username and the generated password
5. Click "Connect"

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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI and SwiftData
- Gutenberg editor inspiration from WordPress
- Icons from SF Symbols

## 📬 Contact

For questions, suggestions, or issues, please open a GitHub issue.

---

**Note**: This is an independent project and is not affiliated with or endorsed by WordPress or Automattic.