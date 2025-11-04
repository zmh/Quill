#!/usr/bin/env python3
"""
Configure Sparkle in the Xcode project
Adds Sparkle Swift Package and configures dependencies
"""

import re
import sys
from pathlib import Path

def generate_uuid():
    """Generate a UUID in Xcode format (24 hex chars)"""
    import secrets
    return secrets.token_hex(12).upper()

def add_sparkle_to_project(project_path):
    """Add Sparkle package to project.pbxproj"""

    with open(project_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for new objects
    package_ref_uuid = generate_uuid()
    package_product_uuid = generate_uuid()

    print(f"Package Reference UUID: {package_ref_uuid}")
    print(f"Package Product UUID: {package_product_uuid}")

    # Check if Sparkle is already added
    if 'sparkle-project' in content.lower():
        print("Sparkle already configured in project")
        return False

    # Find the target UUID for Quill
    target_match = re.search(r'(/\* Quill \*/ = \{[^}]+isa = PBXNativeTarget[^}]+)productReference = ([A-F0-9]+)', content, re.DOTALL)
    if not target_match:
        print("ERROR: Could not find Quill target")
        return False

    # Find the project UUID
    project_match = re.search(r'(/\* Project object \*/);\s*objects = \{', content)
    if not project_match:
        print("ERROR: Could not find project object")
        return False

    # 1. Add XCRemoteSwiftPackageReference section
    package_ref_section = f'''
/* Begin XCRemoteSwiftPackageReference section */
\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "Sparkle" */ = {{
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "https://github.com/sparkle-project/Sparkle";
\t\t\trequirement = {{
\t\t\t\tkind = upToNextMajorVersion;
\t\t\t\tminimumVersion = 2.0.0;
\t\t\t}};
\t\t}};
/* End XCRemoteSwiftPackageReference section */
'''

    # 2. Add XCSwiftPackageProductDependency section
    product_dep_section = f'''
/* Begin XCSwiftPackageProductDependency section */
\t\t{package_product_uuid} /* Sparkle */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {package_ref_uuid} /* XCRemoteSwiftPackageReference "Sparkle" */;
\t\t\tproductName = Sparkle;
\t\t}};
/* End XCSwiftPackageProductDependency section */
'''

    # Insert sections before PBXProject section
    pbx_project_pos = content.find('/* Begin PBXProject section */')
    if pbx_project_pos == -1:
        print("ERROR: Could not find PBXProject section")
        return False

    content = content[:pbx_project_pos] + package_ref_section + '\n' + product_dep_section + '\n' + content[pbx_project_pos:]

    # 3. Add package reference to project
    # Find: productRefGroup = ... ; projectDirPath = "";
    project_section = re.search(r'(projectDirPath = "";[^}]+projectRoot = "";[^}]+targets = \([^)]+\);)', content, re.DOTALL)
    if project_section:
        # Add package references array after targets
        new_project_content = project_section.group(1) + f'\n\t\t\tpackageReferences = (\n\t\t\t\t{package_ref_uuid} /* XCRemoteSwiftPackageReference "Sparkle" */,\n\t\t\t);'
        content = content.replace(project_section.group(1), new_project_content)

    # 4. Add product dependency to Quill target
    # Find the Quill target's packageProductDependencies
    target_section = re.search(r'(8444F69F2DEB50FA002F0BEA /\* Quill \*/ = \{[^}]+packageProductDependencies = \()\s*(\);)', content, re.DOTALL)
    if target_section:
        new_target_content = target_section.group(1) + f'\n\t\t\t\t{package_product_uuid} /* Sparkle */,\n\t\t\t' + target_section.group(2)
        content = content.replace(target_section.group(0), new_target_content)

    # Write back
    with open(project_path, 'w') as f:
        f.write(content)

    print("✓ Added Sparkle package to project")
    return True

def create_info_plist(info_plist_path):
    """Create Info.plist with Sparkle configuration"""

    if info_plist_path.exists():
        print(f"Info.plist already exists at {info_plist_path}")
        return False

    info_plist_content = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>SUFeedURL</key>
\t<string>https://raw.githubusercontent.com/YOUR_USERNAME/quill/main/appcast.xml</string>
\t<key>SUEnableAutomaticChecks</key>
\t<true/>
\t<key>SUScheduledCheckInterval</key>
\t<integer>86400</integer>
\t<key>SUPublicEDKey</key>
\t<string>YOUR_PUBLIC_KEY_HERE</string>
</dict>
</plist>
'''

    with open(info_plist_path, 'w') as f:
        f.write(info_plist_content)

    print(f"✓ Created Info.plist at {info_plist_path}")
    return True

def update_project_for_info_plist(project_path):
    """Update project to use Info.plist file"""

    with open(project_path, 'r') as f:
        content = f.read()

    # Change GENERATE_INFOPLIST_FILE to NO for Quill target
    content = re.sub(
        r'(8444F6C[45]2DEB50FD002F0BEA /\* Debug|Release \*/ = \{[^}]+GENERATE_INFOPLIST_FILE = )YES;',
        r'\1NO;',
        content
    )

    # Add INFOPLIST_FILE setting
    content = re.sub(
        r'(8444F6C[45]2DEB50FD002F0BEA /\* Debug|Release \*/ = \{[^}]+GENERATE_INFOPLIST_FILE = NO;)',
        r'\1\n\t\t\t\tINFOPLIST_FILE = Quill/Info.plist;',
        content
    )

    with open(project_path, 'w') as f:
        f.write(content)

    print("✓ Updated project to use Info.plist")
    return True

def main():
    project_file = Path("Quill/Quill.xcodeproj/project.pbxproj")
    info_plist = Path("Quill/Quill/Info.plist")

    if not project_file.exists():
        print(f"ERROR: Project file not found: {project_file}")
        sys.exit(1)

    # Backup
    backup_file = project_file.with_suffix('.pbxproj.backup')
    import shutil
    shutil.copy(project_file, backup_file)
    print(f"✓ Created backup: {backup_file}")

    # Add Sparkle package
    print("\n1. Adding Sparkle package...")
    add_sparkle_to_project(project_file)

    # Create Info.plist
    print("\n2. Creating Info.plist...")
    if create_info_plist(info_plist):
        print("\n3. Updating project settings...")
        update_project_for_info_plist(project_file)

    print("\n✓ Sparkle configuration complete!")
    print("\nNext steps:")
    print("1. Edit Quill/Quill/Info.plist and replace YOUR_USERNAME with your GitHub username")
    print("2. Generate Sparkle EdDSA keys (optional, for production)")
    print("3. Build and test: ./Scripts/build-release.sh 1.0.0")

if __name__ == '__main__':
    main()
