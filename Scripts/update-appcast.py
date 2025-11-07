#!/usr/bin/env python3
"""
update-appcast.py
Automatically updates appcast.xml with a new release entry.

Usage:
    ./Scripts/update-appcast.py <version> <dmg_size> <release_notes_file> [ed_signature]

Example:
    ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md
    ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md "MEUCIQDxA..."
"""

import sys
import os
import re
from datetime import datetime
from xml.etree import ElementTree as ET

def parse_release_notes(release_notes_file):
    """Extract release notes from markdown file."""
    if not os.path.exists(release_notes_file):
        return ["See the full release notes for details."]

    with open(release_notes_file, 'r') as f:
        content = f.read()

    # Extract lines between "What's Changed" and "Installation"
    notes = []
    in_section = False
    for line in content.split('\n'):
        if "## What's Changed" in line or "## What's New" in line:
            in_section = True
            continue
        if line.startswith('## ') and in_section:
            break
        if in_section and line.strip().startswith('- '):
            # Remove commit hash if present: "- Fix something (abc123)" -> "Fix something"
            clean_line = re.sub(r'\s*\([a-f0-9]{7}\)\s*$', '', line.strip('- ').strip())
            if clean_line:
                notes.append(clean_line)

    return notes[:5] if notes else ["See the full release notes for details."]

def create_item_xml(version, dmg_size, release_notes, repo="zmh/quill", ed_signature=None):
    """Create a new <item> XML string for the appcast."""
    # Publication date (RFC 822 format)
    pub_date = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')

    # Format release notes as HTML list items
    notes_html = '\n'.join([f'                    <li>{note}</li>' for note in release_notes])

    # Add EdDSA signature if provided
    signature_attr = f'\n                sparkle:edSignature="{ed_signature}"' if ed_signature else ''

    # Build the XML string manually to match the existing format exactly
    item_xml = f"""        <item>
            <title>Version {version}</title>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{version}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New in {version}</h2>
                <ul>
{notes_html}
                </ul>
                <p>See the <a href="https://github.com/{repo}/releases/tag/v{version}">full release notes</a> for details.</p>
            ]]></description>
            <enclosure
                url="https://github.com/{repo}/releases/download/v{version}/Quill-{version}.dmg"
                length="{dmg_size}"
                type="application/octet-stream"{signature_attr}
            />
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>"""

    return item_xml

def update_appcast(appcast_file, version, dmg_size, release_notes_file, repo="zmh/quill", ed_signature=None):
    """Update the appcast.xml file with a new release."""
    # Read the file content
    with open(appcast_file, 'r') as f:
        content = f.read()

    # Parse release notes
    release_notes = parse_release_notes(release_notes_file)

    # Create new item XML (as a formatted string)
    new_item_xml = create_item_xml(version, dmg_size, release_notes, repo, ed_signature)

    # Find the insertion point (after the comment block, before first existing item)
    # Look for the end of the comment block (-->)
    insertion_pattern = r'(-->\s*\n\s*\n)'

    if re.search(insertion_pattern, content):
        # Insert the new item after the comment block
        updated_content = re.sub(
            insertion_pattern,
            r'\1' + new_item_xml + '\n\n',
            content,
            count=1
        )

        # Write back
        with open(appcast_file, 'w') as f:
            f.write(updated_content)

        print(f"✓ Updated {appcast_file} with version {version}")
        print(f"  - DMG size: {dmg_size} bytes")
        print(f"  - Release notes: {len(release_notes)} items")
        return True
    else:
        print(f"✗ Could not find insertion point in {appcast_file}")
        return False

def main():
    if len(sys.argv) < 4:
        print("Usage: ./Scripts/update-appcast.py <version> <dmg_size> <release_notes_file> [ed_signature]")
        print("Example: ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md")
        print("         ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md \"MEUCIQDxA...\"")
        sys.exit(1)

    version = sys.argv[1]
    dmg_size = sys.argv[2]
    release_notes_file = sys.argv[3]
    ed_signature = sys.argv[4] if len(sys.argv) > 4 else None

    # Default paths
    appcast_file = 'appcast.xml'

    # Get repository from environment or use default
    repo = os.environ.get('GITHUB_REPOSITORY', 'zmh/quill')

    if not os.path.exists(appcast_file):
        print(f"✗ Appcast file not found: {appcast_file}")
        sys.exit(1)

    success = update_appcast(appcast_file, version, dmg_size, release_notes_file, repo, ed_signature)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
