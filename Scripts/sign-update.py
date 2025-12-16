#!/usr/bin/env python3
"""
sign-update.py
Signs a DMG file with Sparkle EdDSA for secure updates.

Usage:
    python3 Scripts/sign-update.py <dmg_path>

Environment:
    SPARKLE_PRIVATE_KEY: Base64-encoded Ed25519 private key
"""

import sys
import os
import base64

try:
    import nacl.signing
except ImportError:
    print("Error: PyNaCl not installed. Run: pip3 install pynacl", file=sys.stderr)
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 sign-update.py <dmg_path>", file=sys.stderr)
        sys.exit(1)

    dmg_path = sys.argv[1]
    private_key_b64 = os.environ.get('SPARKLE_PRIVATE_KEY', '')

    if not private_key_b64:
        print("Error: SPARKLE_PRIVATE_KEY environment variable not set", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(dmg_path):
        print(f"Error: File not found: {dmg_path}", file=sys.stderr)
        sys.exit(1)

    # Decode the private key
    key_bytes = base64.b64decode(private_key_b64)

    # Read the DMG file
    with open(dmg_path, 'rb') as f:
        data = f.read()

    # Sign using Ed25519 (first 32 bytes are the seed)
    signing_key = nacl.signing.SigningKey(key_bytes[:32])
    signed = signing_key.sign(data)

    # Output base64-encoded signature
    signature = base64.b64encode(signed.signature).decode('utf-8')
    print(signature)

if __name__ == '__main__':
    main()
