# iA Fonts Integration Setup

This document describes the changes made to integrate iA Writer fonts into the Quill app.

## Changes Made

### 1. Font Files Added
Downloaded and added three iA Writer font families to `Quill/Quill/Fonts/`:
- **iA Writer Mono** - Monospaced font for code/technical writing
- **iA Writer Duo** - Duospace font (variable-width for improved readability)
- **iA Writer Quattro** - Serif-style writing font

Each font family includes:
- Regular, Bold, Italic, and BoldItalic weights
- LICENSE.md file (SIL Open Font License 1.1)

### 2. Code Changes

#### SettingsView.swift
Updated the `typefaces` array to include three new options:
```swift
let typefaces = [
    ("system", "San Francisco"),
    ("sf-mono", "SF Mono"),
    ("ia-mono", "iA Writer Mono"),      // NEW
    ("ia-duo", "iA Writer Duo"),         // NEW
    ("ia-quattro", "iA Writer Quattro"), // NEW
    ("georgia", "Georgia"),
    ("verdana", "Verdana"),
    ("arial", "Arial")
]
```

#### GutenbergWebView.swift
Added CSS font-family mappings for the iA fonts in the editor:
```swift
case "ia-mono": return "'iA Writer Mono S', 'SF Mono', Monaco, monospace"
case "ia-duo": return "'iA Writer Duo S', -apple-system, sans-serif"
case "ia-quattro": return "'iA Writer Quattro S', Georgia, serif"
```

#### Info.plist
Created `Quill/Quill/Info.plist` with font registrations:
```xml
<key>UIAppFonts</key>
<array>
    <string>Fonts/iA Writer Mono/iAWriterMonoS-Regular.ttf</string>
    <!-- ... all 12 font files listed ... -->
</array>
```

## Manual Steps Required

**IMPORTANT:** The font files and Info.plist need to be added to the Xcode project:

1. **Open the project in Xcode:**
   ```bash
   open Quill/Quill.xcodeproj
   ```

2. **Add the Fonts folder to the project:**
   - In Xcode, right-click on the "Quill" group in the Project Navigator
   - Select "Add Files to 'Quill'..."
   - Navigate to `Quill/Quill/Fonts`
   - Select the entire `Fonts` folder
   - **Important:** Check "Create folder references" (not "Create groups")
   - Ensure "Quill" target is checked
   - Click "Add"

3. **Add Info.plist to the project:**
   - Right-click on the "Quill" group
   - Select "Add Files to 'Quill'..."
   - Navigate to `Quill/Quill/Info.plist`
   - Ensure "Quill" target is checked
   - Click "Add"

4. **Configure the Info.plist in Build Settings:**
   - Select the Quill project in Project Navigator
   - Select the "Quill" target
   - Go to "Build Settings" tab
   - Search for "Info.plist File"
   - Set the value to: `Quill/Info.plist`

5. **Verify font registration:**
   - Build the project (⌘B)
   - Check for any build errors related to fonts
   - Run the app and go to Settings → General → Typeface
   - Verify that "iA Writer Mono", "iA Writer Duo", and "iA Writer Quattro" appear in the list
   - Select one and create a new post to test the font rendering

## Font Information

### iA Writer Mono
- Designed for code and technical writing
- Monospaced for perfect alignment
- Excellent for markdown and plain text

### iA Writer Duo
- Duospace font (mix between monospace and proportional)
- Better readability than pure monospace
- Great for long-form writing

### iA Writer Quattro
- Serif-style font
- Optimized for reading
- Professional, classic look

## License

All iA Writer fonts are licensed under the **SIL Open Font License 1.1**, which allows:
- Free use in personal and commercial projects
- Bundling and embedding in applications
- Redistribution with proper attribution

License files are included in each font directory.

## Troubleshooting

If fonts don't appear in the app:
1. Verify fonts are added to the Xcode project target
2. Check that Info.plist paths match actual font locations
3. Clean build folder (Shift+⌘K) and rebuild
4. Check Console.app for font loading errors

If fonts appear but don't render correctly:
1. Verify the CSS font-family names match the actual font names
2. Check that font files aren't corrupted
3. Try rebuilding the app

## Attribution

As per the iA Writer font requirements:
- Fonts based on IBM Plex
- Modified by Information Architects Inc.
- Used under SIL Open Font License 1.1
