# Contributing to Quill

Thank you for your interest in contributing to Quill! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to:
- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- **Xcode 15.0+**: Download from the Mac App Store
- **macOS 14.0+**: Required for development
- **iOS 17.0+**: For iOS testing (optional)
- **WordPress Site**: For testing API integration

### Setting Up Development Environment

1. **Clone the repository**
   ```bash
   git clone https://github.com/[username]/Quill.git
   cd Quill
   ```

2. **Open in Xcode**
   ```bash
   open Quill/Quill.xcodeproj
   ```

3. **Build and run**
   - Select your target (Mac, iPhone, iPad)
   - Press `Cmd+R` to build and run

### Project Structure

```
Quill/
├── Quill/                 # Main app source
│   ├── Models/           # SwiftData models
│   ├── Views/            # SwiftUI views
│   ├── Services/         # API and business logic
│   └── Resources/        # Assets, fonts, etc.
├── QuillTests/           # Unit tests
├── QuillUITests/         # UI tests
└── CLAUDE.md             # Project guidance for AI assistants
```

## How to Contribute

### Reporting Bugs

Before creating a bug report:
1. **Check existing issues** to avoid duplicates
2. **Verify the bug** in the latest version
3. **Gather information**: OS version, Xcode version, steps to reproduce

Create a bug report with:
- Clear, descriptive title
- Detailed steps to reproduce
- Expected vs actual behavior
- Screenshots or screen recordings (if applicable)
- Error messages or logs
- Environment details

### Suggesting Features

Feature requests should include:
- **Use case**: Why is this feature needed?
- **Description**: What should it do?
- **Mockups**: Visual examples (if applicable)
- **Alternatives**: Other solutions you've considered

### Pull Requests

#### Before You Start

1. **Check existing PRs** to avoid duplicate work
2. **Open an issue** to discuss major changes first
3. **Fork the repository** and create a branch
4. **Follow coding standards** (see below)

#### Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make your changes**
   - Write clean, readable code
   - Follow Swift style guide
   - Add tests for new functionality
   - Update documentation

3. **Test thoroughly**
   - Run all unit tests: `Cmd+U`
   - Test on multiple platforms (Mac, iOS, iPad)
   - Test with real WordPress sites
   - Verify security checklist (see SECURITY.md)

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add brief description of changes"
   ```

   Commit message format:
   - Use present tense ("Add feature" not "Added feature")
   - Use imperative mood ("Move cursor to..." not "Moves cursor to...")
   - First line: Brief summary (50 chars or less)
   - Blank line, then detailed description (if needed)

5. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```

   In your PR description:
   - Explain the changes and why they're needed
   - Reference any related issues (`Fixes #123`)
   - Include screenshots for UI changes
   - List any breaking changes

#### Pull Request Checklist

- [ ] Code follows Swift style guide
- [ ] All tests pass (`Cmd+U`)
- [ ] New code has test coverage
- [ ] Documentation updated (if needed)
- [ ] SECURITY.md checklist verified
- [ ] No hardcoded credentials or secrets
- [ ] UI tested on Mac, iPhone, iPad (if applicable)
- [ ] No compiler warnings
- [ ] Changes are backwards compatible (or breaking changes documented)

## Coding Standards

### Swift Style Guide

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

**Key points:**
- Use 4 spaces for indentation (no tabs)
- Line length: 120 characters maximum
- Use meaningful variable names
- Add documentation comments for public APIs
- Group related code with `// MARK: -` comments

**Example:**
```swift
// MARK: - Public Methods

/// Fetches posts from WordPress
/// - Parameters:
///   - siteURL: The WordPress site URL
///   - page: Page number for pagination
/// - Returns: Array of WordPress posts
func fetchPosts(siteURL: String, page: Int) async throws -> [WordPressPost] {
    // Implementation
}
```

### SwiftUI Conventions

- Keep views small and focused
- Extract complex views into separate components
- Use `@State` for local state, `@Binding` for passed state
- Use `@Environment` for dependency injection
- Prefer composition over inheritance

### Architecture

- **Models**: SwiftData models in `Models/` directory
- **Views**: SwiftUI views organized by feature
- **Services**: API clients, managers in `Services/`
- **MVVM Pattern**: ViewModels for complex business logic

### Security Best Practices

**Always:**
- Store credentials in Keychain only
- Use HTTPS for all network requests
- Validate and sanitize user input
- Avoid logging sensitive data
- Use `#if DEBUG` for debug-only code

**Never:**
- Hardcode credentials or API keys
- Log passwords or authentication tokens
- Store credentials in UserDefaults or files
- Use HTTP for API connections
- Commit secrets to version control

## Testing

### Unit Tests

- Located in `QuillTests/`
- Test business logic and models
- Use `XCTest` framework
- Aim for 70%+ code coverage

```swift
func testPostCreation() {
    let post = Post(title: "Test", content: "Content", status: .draft)
    XCTAssertEqual(post.title, "Test")
    XCTAssertEqual(post.status, .draft)
}
```

### UI Tests

- Located in `QuillUITests/`
- Test critical user flows
- Use XCUITest framework

### Manual Testing

Test on:
- macOS (latest version)
- iOS (iPhone and iPad)
- Different WordPress configurations:
  - WordPress.com
  - Self-hosted WordPress
  - Various WordPress versions

## Documentation

### Code Documentation

Use Swift documentation comments:

```swift
/// Brief description of the method
///
/// Longer description with more details about what this does,
/// edge cases, and important notes.
///
/// - Parameters:
///   - param1: Description of first parameter
///   - param2: Description of second parameter
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
func myMethod(param1: String, param2: Int) throws -> Bool {
    // Implementation
}
```

### User Documentation

- Update README.md for user-facing features
- Add inline help text in the UI
- Include tooltips for complex features

## Development Workflow

### Branch Naming

- `feature/feature-name`: New features
- `fix/bug-description`: Bug fixes
- `docs/documentation-update`: Documentation only
- `refactor/code-improvement`: Code refactoring
- `test/test-description`: Test improvements

### Release Process

1. Version bump in Xcode project
2. Update `CHANGELOG.md`
3. Create release branch
4. Final testing on all platforms
5. Create GitHub release with notes
6. Tag release in git

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Security**: Email security reports (see SECURITY.md)
- **Chat**: [Add Discord/Slack link if applicable]

## Recognition

Contributors will be:
- Listed in release notes
- Credited in CONTRIBUTORS.md (if created)
- Recognized in the About screen (for significant contributions)

## License

By contributing to Quill, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Quill! 🎉
