#!/usr/bin/env python3
"""
Fix iOS App Icons - Remove Transparency

iOS App Store requires app icons WITHOUT transparency (no alpha channel).
This script converts all app icons to have a solid background.

Usage:
    cd /Users/bikrammaharjan/Desktop/Hugging/ios
    python3 fix_app_icons.py

Requirements:
    pip3 install Pillow
"""

import os
from PIL import Image

# Path to app icons
ICON_DIR = "Runner/Assets.xcassets/AppIcon.appiconset"

# Background color (solid color to replace transparency)
# Using a nice blue color for the app - change as desired
BACKGROUND_COLOR = (59, 130, 246)  # Blue (#3B82F6)

def remove_transparency(image_path, output_path=None):
    """Remove transparency from an image by adding a solid background."""
    if output_path is None:
        output_path = image_path
    
    try:
        img = Image.open(image_path)
        
        # Check if image has alpha channel
        if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
            # Create a new image with solid background
            background = Image.new('RGB', img.size, BACKGROUND_COLOR)
            
            # Convert to RGBA if needed
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Paste the image on the background using alpha as mask
            background.paste(img, mask=img.split()[3])  # 3 is the alpha channel
            
            # Save without alpha
            background.save(output_path, 'PNG')
            print(f"✅ Fixed: {os.path.basename(image_path)}")
        else:
            # Already no transparency, but ensure it's RGB
            if img.mode != 'RGB':
                img = img.convert('RGB')
            img.save(output_path, 'PNG')
            print(f"✓ Already OK: {os.path.basename(image_path)}")
            
    except Exception as e:
        print(f"❌ Error processing {image_path}: {e}")

def main():
    print("=" * 50)
    print("iOS App Icon Transparency Fixer")
    print("=" * 50)
    print(f"\nBackground color: RGB{BACKGROUND_COLOR}")
    print(f"Icon directory: {ICON_DIR}\n")
    
    if not os.path.exists(ICON_DIR):
        print(f"❌ Icon directory not found: {ICON_DIR}")
        print("Make sure you're running this from the ios/ folder")
        return
    
    # Process all PNG files
    png_files = [f for f in os.listdir(ICON_DIR) if f.endswith('.png')]
    
    if not png_files:
        print("No PNG files found in icon directory")
        return
    
    print(f"Found {len(png_files)} icon files\n")
    
    for filename in sorted(png_files):
        filepath = os.path.join(ICON_DIR, filename)
        remove_transparency(filepath)
    
    print("\n" + "=" * 50)
    print("Done! Now rebuild and resubmit your app.")
    print("=" * 50)

if __name__ == "__main__":
    main()

