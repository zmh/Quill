# Product Specification: Native WordPress Editor
*A focused, beautiful writing app for WordPress bloggers*

## Product Vision

Create a native Mac/iOS app that provides a distraction-free writing experience for WordPress bloggers, with seamless offline support and true post lifecycle management (draft → publish → edit → update).

## Core Design Principles

1. **Writing First** - The interface disappears, leaving just you and your words
2. **Native Feel** - Uses platform conventions, transparency, and system integrations
3. **Offline First** - Draft anywhere, sync when connected
4. **Complete Lifecycle** - Manage posts from creation through updates, not just publishing

## MVP Feature Set

### 1. Quick Compose
- **"What would you like to say?"** text field at the top of the main screen
- Single-click/tap to start writing
- ⌘N (Mac) or + button (iOS) for new post
- Auto-saves as draft immediately upon typing

### 2. Editor
- **Gutenberg Block Support** (Core blocks only for MVP):
  - Paragraph
  - Heading (H1-H6)
  - List (ordered/unordered)
  - Quote
  - Image
  - Code
  - Separator
- **Rich Text Fallback** for posts created with unsupported blocks
- Focus mode (hides all UI except editor)
- Word/character count in subtle toolbar
- Markdown shortcuts (e.g., ## for heading)

### 3. Post Management
- **Three-pane layout** (Mac/iPad): Sites → Posts → Editor
- **Two-pane layout** (iPhone): Posts → Editor
- Post list shows:
  - Title (or first line if untitled)
  - Status badge (Draft/Published/Scheduled)
  - Last modified date
  - Word count
- Search and filter by status
- Pull to refresh

### 4. Post Metadata
- Minimal metadata popover/sheet:
  - Title
  - Slug  
  - Status (Draft/Published/Private)
  - Publish date (for scheduling)
- Advanced options hidden by default

### 5. Offline Support
- All drafts saved locally with automatic sync
- Queue system for offline actions
- Visual indicator for sync status
- Conflict resolution (prefer local changes)

### 6. Image Handling
- Drag & drop or paste images directly into editor
- Automatic upload when online
- Local preview while offline
- Compression options in settings

### 7. Site Connection
- Add site via URL + Application Password (self-hosted)
- WordPress.com OAuth flow
- Test connection before saving
- Store credentials in Keychain

## User Interface Design

### Design Language
- **Inspiration**: Ulysses, iA Writer, Things 3
- Translucent sidebar with vibrancy
- Minimal chrome, maximum content
- Typography-focused with generous whitespace
- Subtle animations for state changes

### Platform Adaptations

**Mac**
- Native menu bar with keyboard shortcuts
- Translucent sidebar
- Full keyboard navigation
- Hover states for interactive elements
- Window management (tabs, full screen)

**iPad**  
- Three-column layout in landscape
- Slide-over sidebar in portrait
- Keyboard shortcuts matching Mac
- Apple Pencil support for markup

**iPhone**
- Edge swipe for navigation
- Floating compose button
- Adaptive type sizing
- Gesture-based actions (swipe to delete/archive)

### Visual Hierarchy
```
┌─────────────────────────────────────┐
│  What would you like to say?        │ ← Quick compose
├─────────┬───────────────────────────┤
│ Sites   │ Posts        │ Editor     │
│         │              │            │
│ My Blog │ Draft Post 1 │ # Title    │
│         │ Published... │            │
│         │ Draft Post 2 │ Content... │
└─────────┴──────────────┴────────────┘
```

## Technical Architecture

### Data Model
```swift
struct Post {
    let id: Int?
    let localID: UUID
    let title: String
    let content: String // Gutenberg HTML
    let status: PostStatus
    let slug: String
    let modified: Date
    let syncStatus: SyncStatus
}

enum SyncStatus {
    case synced
    case pendingUpload
    case pendingUpdate
    case conflict(local: Date, remote: Date)
}
```

### Sync Strategy
1. Local SQLite database for offline storage
2. Operation queue for API calls
3. Automatic retry with exponential backoff
4. Background sync on iOS/macOS
5. Conflict resolution UI when needed

### Authentication
- Application Passwords for self-hosted (stored in Keychain)
- OAuth 2.0 for WordPress.com
- Biometric authentication for app access

## MVP Development Phases

### Phase 1: Foundation (Weeks 1-3)
- Basic app structure (SwiftUI)
- Local post storage
- Simple text editor
- WordPress REST API integration

### Phase 2: Editor (Weeks 4-6)
- Gutenberg block parser
- Block renderers for core types
- Rich text editing
- Image upload support

### Phase 3: Sync & Polish (Weeks 7-8)
- Offline queue implementation
- Sync conflict resolution
- UI polish and animations
- Platform-specific optimizations

### Phase 4: Testing & Launch Prep (Weeks 9-10)
- Beta testing
- Performance optimization
- App Store assets
- Documentation

## Success Metrics

1. **Writing Speed**: Time from thought to published post
2. **Reliability**: Successful sync rate > 99%
3. **Engagement**: Daily active usage
4. **Simplicity**: Minimal support requests

## Future Enhancements (Post-MVP)

- Multiple site support
- Plugin integrations (SEO, custom fields)
- Share extension
- Shortcuts/automation support
- Media library browsing
- Comment moderation
- Analytics dashboard
- Team collaboration features

## Monetization Strategy

**Freemium Model** (Post-MVP):
- Free: 1 site, core features
- Pro ($4.99/month): Unlimited sites, advanced features
- Universal purchase (buy once, use on all platforms)

---

This spec prioritizes the essential writing and editing experience while maintaining flexibility for future growth. The focus on offline-first architecture and native platform integration will differentiate it from existing solutions.