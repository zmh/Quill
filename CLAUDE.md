# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quill is a native WordPress editor app for Mac/iOS that provides a distraction-free writing experience for WordPress bloggers. The app is built using SwiftUI and SwiftData, targeting seamless offline support and complete post lifecycle management (draft → publish → edit → update).

## Architecture

The app follows a SwiftUI + SwiftData architecture:

- **SwiftUI**: For the user interface across Mac/iOS/iPadOS
- **SwiftData**: For local data persistence and offline support
- **WordPress REST API**: For syncing with WordPress sites
- **Three-pane layout** (Mac/iPad): Sites → Posts → Editor
- **Two-pane layout** (iPhone): Posts → Editor

Key architectural decisions from the product spec:
- Offline-first with local SQLite database via SwiftData
- Operation queue for API calls with automatic retry
- Background sync support
- Gutenberg block support for core WordPress blocks

## Development Commands

### Building
```bash
# Build the project
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -configuration Debug build

# Build for iOS Simulator
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -sdk iphonesimulator -configuration Debug build

# Build for release
xcodebuild -project Quill/Quill.xcodeproj -scheme Quill -configuration Release build
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project Quill/Quill.xcodeproj -scheme Quill -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -project Quill/Quill.xcodeproj -scheme QuillUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Opening in Xcode
```bash
open Quill/Quill.xcodeproj
```

## Current State

The project is in its initial setup phase with:
- Basic SwiftUI app structure created
- SwiftData container configured with a placeholder `Item` model
- Standard Xcode project structure with test targets

The current implementation needs to be replaced with the actual WordPress editor functionality as specified in `product-spec.md`.

## Key Implementation Areas

When implementing features, focus on these core areas from the product spec:

1. **Data Models**: Replace the placeholder `Item` model with proper `Post`, `Site`, and sync-related models
2. **WordPress API Integration**: Implement REST API client for WordPress.com and self-hosted sites
3. **Gutenberg Block Support**: Parser and renderers for core WordPress blocks
4. **Offline Sync**: Queue system for offline actions with conflict resolution
5. **Editor Interface**: Three-pane navigation with focus mode and rich text editing

## Platform Considerations

The app targets multiple Apple platforms with platform-specific adaptations:
- **Mac**: Native menu bar, translucent sidebar, keyboard shortcuts
- **iPad**: Three-column layout, slide-over sidebar, Apple Pencil support
- **iPhone**: Edge swipe navigation, floating compose button, gesture-based actions