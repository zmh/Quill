#!/usr/bin/env python3
"""
update-appcast.py
Automatically updates appcast.xml with a new release entry.

Usage:
    ./Scripts/update-appcast.py <version> <dmg_size> <release_notes_file>

Example:
    ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md
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

def create_item_element(version, dmg_size, release_notes, repo="zmh/quill"):
    """Create a new <item> element for the appcast."""
    # Create item with proper namespace
    item = ET.Element('item')

    # Title
    title = ET.SubElement(item, 'title')
    title.text = f'Version {version}'

    # Publication date (RFC 822 format)
    pub_date = ET.SubElement(item, 'pubDate')
    pub_date.text = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')

    # Sparkle version tags
    sparkle_ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'

    version_elem = ET.SubElement(item, f'{sparkle_ns}version')
    version_elem.text = version

    short_version = ET.SubElement(item, f'{sparkle_ns}shortVersionString')
    short_version.text = version

    # Description with CDATA
    description = ET.SubElement(item, 'description')
    notes_html = '\n'.join([f'                    <li>{note}</li>' for note in release_notes])
    cdata_content = f"""
                <h2>What's New in {version}</h2>
                <ul>
{notes_html}
                </ul>
                <p>See the <a href="https://github.com/{repo}/releases/tag/v{version}">full release notes</a> for details.</p>
            """
    description.text = cdata_content

    # Enclosure (DMG download)
    enclosure = ET.SubElement(item, 'enclosure')
    enclosure.set('url', f'https://github.com/{repo}/releases/download/v{version}/Quill-{version}.dmg')
    enclosure.set('length', str(dmg_size))
    enclosure.set('type', 'application/octet-stream')

    # Minimum system version
    min_version = ET.SubElement(item, f'{sparkle_ns}minimumSystemVersion')
    min_version.text = '14.0'

    return item

def update_appcast(appcast_file, version, dmg_size, release_notes_file, repo="zmh/quill"):
    """Update the appcast.xml file with a new release."""
    # Read the file content
    with open(appcast_file, 'r') as f:
        content = f.read()

    # Parse release notes
    release_notes = parse_release_notes(release_notes_file)

    # Create new item XML
    new_item = create_item_element(version, dmg_size, release_notes, repo)

    # Convert to string with proper formatting
    item_str = ET.tostring(new_item, encoding='unicode', method='xml')

    # Format the item XML nicely
    item_lines = []
    item_lines.append('        <item>')

    # Parse and format each sub-element
    for line in item_str.split('\n'):
        line = line.strip()
        if line and line != '<item>' and line != '</item>':
            item_lines.append('            ' + line)

    item_lines.append('        </item>')
    new_item_xml = '\n'.join(item_lines)

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
        print("Usage: ./Scripts/update-appcast.py <version> <dmg_size> <release_notes_file>")
        print("Example: ./Scripts/update-appcast.py 1.0.5 3517446 release_notes.md")
        sys.exit(1)

    version = sys.argv[1]
    dmg_size = sys.argv[2]
    release_notes_file = sys.argv[3]

    # Default paths
    appcast_file = 'appcast.xml'

    # Get repository from environment or use default
    repo = os.environ.get('GITHUB_REPOSITORY', 'zmh/quill')

    if not os.path.exists(appcast_file):
        print(f"✗ Appcast file not found: {appcast_file}")
        sys.exit(1)

    success = update_appcast(appcast_file, version, dmg_size, release_notes_file, repo)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
