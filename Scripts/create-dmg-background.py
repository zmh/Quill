#!/usr/bin/env python3
"""
create-dmg-background.py
Creates a custom background image for the Quill DMG installer
"""

from PIL import Image, ImageDraw, ImageFont
import sys

def create_dmg_background(output_path, width=660, height=400):
    """Create a beautiful gradient background with installation instructions"""

    # Create image with gradient background
    img = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(img)

    # Create subtle gradient (light blue to white)
    for y in range(height):
        # Gradient from #E8F4F8 to #FFFFFF
        r = int(232 + (255 - 232) * (y / height))
        g = int(244 + (255 - 244) * (y / height))
        b = int(248 + (255 - 248) * (y / height))
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    # Add instruction text
    try:
        # Try to use system font
        font_large = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 28)
        font_medium = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
    except:
        # Fallback to default font
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()

    # Draw title
    title = "Install Quill"
    title_bbox = draw.textbbox((0, 0), title, font=font_large)
    title_width = title_bbox[2] - title_bbox[0]
    draw.text(
        ((width - title_width) / 2, 30),
        title,
        fill=(50, 50, 50),
        font=font_large
    )

    # Draw instruction
    instruction = "Drag Quill to the Applications folder"
    inst_bbox = draw.textbbox((0, 0), instruction, font=font_medium)
    inst_width = inst_bbox[2] - inst_bbox[0]
    draw.text(
        ((width - inst_width) / 2, 340),
        instruction,
        fill=(100, 100, 100),
        font=font_medium
    )

    # Draw arrow indicator (simple arrow pointing right)
    arrow_y = 200
    arrow_start_x = 280
    arrow_end_x = 360
    arrow_color = (100, 100, 100)

    # Arrow line
    draw.line([(arrow_start_x, arrow_y), (arrow_end_x, arrow_y)],
              fill=arrow_color, width=3)
    # Arrow head
    draw.polygon([
        (arrow_end_x, arrow_y),
        (arrow_end_x - 15, arrow_y - 10),
        (arrow_end_x - 15, arrow_y + 10)
    ], fill=arrow_color)

    # Save the image
    img.save(output_path, 'PNG')
    print(f"✓ Created DMG background: {output_path}")

if __name__ == '__main__':
    output = sys.argv[1] if len(sys.argv) > 1 else 'Resources/DMG/background.png'
    create_dmg_background(output)
