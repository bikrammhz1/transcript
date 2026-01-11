#!/usr/bin/env python3
"""
App Icon Generator for Transcript Summarizer
Generates all required iOS and macOS app icon sizes

Design: Document with AI/summary sparkle motif
- Gradient background (deep purple to teal)
- Stylized document with text lines
- AI sparkle/summary symbol

Requirements: pip install pillow
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Installing Pillow...")
    os.system(f"{sys.executable} -m pip install pillow")
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_gradient(size, color1, color2, direction='diagonal'):
    """Create a gradient background."""
    img = Image.new('RGBA', (size, size), color1)
    draw = ImageDraw.Draw(img)

    for i in range(size):
        if direction == 'diagonal':
            # Diagonal gradient
            ratio = (i / size)
        else:
            ratio = i / size

        r = int(color1[0] + (color2[0] - color1[0]) * ratio)
        g = int(color1[1] + (color2[1] - color1[1]) * ratio)
        b = int(color1[2] + (color2[2] - color1[2]) * ratio)

        if direction == 'diagonal':
            draw.line([(0, i), (i, 0)], fill=(r, g, b, 255))
            draw.line([(size - 1, i), (i, size - 1)], fill=(r, g, b, 255))
        else:
            draw.line([(0, i), (size, i)], fill=(r, g, b, 255))

    return img


def create_app_icon(size):
    """Create a single app icon at the specified size."""
    # Create high-res version then scale down for better quality
    scale = 4 if size < 256 else 2
    work_size = size * scale

    # Colors
    bg_color1 = (88, 28, 135)    # Deep purple (#581c87)
    bg_color2 = (13, 148, 136)   # Teal (#0d9488)
    doc_color = (255, 255, 255, 240)  # White with slight transparency
    line_color = (148, 163, 184)  # Slate gray for text lines
    accent_color = (250, 204, 21)  # Yellow/gold for sparkle (#facc15)

    # Create base with gradient
    img = Image.new('RGBA', (work_size, work_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw rounded rectangle background with gradient effect
    padding = int(work_size * 0.08)
    corner_radius = int(work_size * 0.22)  # iOS style rounded corners

    # Create gradient background
    for y in range(work_size):
        for x in range(work_size):
            # Calculate diagonal gradient
            ratio = ((x + y) / (2 * work_size))
            r = int(bg_color1[0] + (bg_color2[0] - bg_color1[0]) * ratio)
            g = int(bg_color1[1] + (bg_color2[1] - bg_color1[1]) * ratio)
            b = int(bg_color1[2] + (bg_color2[2] - bg_color1[2]) * ratio)
            img.putpixel((x, y), (r, g, b, 255))

    # Create mask for rounded corners
    mask = Image.new('L', (work_size, work_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [0, 0, work_size - 1, work_size - 1],
        radius=corner_radius,
        fill=255
    )
    img.putalpha(mask)

    # Draw document shape (white paper with folded corner)
    doc_left = int(work_size * 0.22)
    doc_top = int(work_size * 0.18)
    doc_right = int(work_size * 0.78)
    doc_bottom = int(work_size * 0.85)
    doc_corner = int(work_size * 0.15)  # Folded corner size
    doc_radius = int(work_size * 0.04)

    # Document body (with folded corner)
    doc_points = [
        (doc_left, doc_top + doc_radius),  # Top-left corner start
        (doc_left + doc_radius, doc_top),  # Top-left curve
        (doc_right - doc_corner, doc_top),  # Top edge to fold
        (doc_right, doc_top + doc_corner),  # Fold diagonal
        (doc_right, doc_bottom - doc_radius),  # Right edge
        (doc_right - doc_radius, doc_bottom),  # Bottom-right curve
        (doc_left + doc_radius, doc_bottom),  # Bottom edge
        (doc_left, doc_bottom - doc_radius),  # Bottom-left curve
    ]

    # Draw document with shadow
    shadow_offset = int(work_size * 0.02)
    shadow_img = Image.new('RGBA', (work_size, work_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_draw.rounded_rectangle(
        [doc_left + shadow_offset, doc_top + shadow_offset,
         doc_right + shadow_offset, doc_bottom + shadow_offset],
        radius=doc_radius,
        fill=(0, 0, 0, 60)
    )
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=work_size * 0.02))
    img = Image.alpha_composite(img, shadow_img)

    # Draw main document
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(
        [doc_left, doc_top, doc_right, doc_bottom],
        radius=doc_radius,
        fill=doc_color
    )

    # Draw folded corner
    fold_points = [
        (doc_right - doc_corner, doc_top),
        (doc_right, doc_top + doc_corner),
        (doc_right - doc_corner, doc_top + doc_corner),
    ]
    draw.polygon(fold_points, fill=(230, 230, 235, 255))
    draw.line([fold_points[0], fold_points[1]], fill=(200, 200, 210, 255), width=max(1, work_size // 200))

    # Draw text lines on document
    line_y_start = doc_top + int(work_size * 0.12)
    line_spacing = int(work_size * 0.065)
    line_left = doc_left + int(work_size * 0.06)
    line_right_full = doc_right - int(work_size * 0.06)
    line_thickness = max(2, int(work_size * 0.018))

    # Draw 5 text lines with varying lengths
    line_lengths = [1.0, 0.85, 0.92, 0.7, 0.6]
    for i, length_ratio in enumerate(line_lengths):
        y = line_y_start + i * line_spacing
        line_right = line_left + int((line_right_full - line_left) * length_ratio)
        draw.rounded_rectangle(
            [line_left, y, line_right, y + line_thickness],
            radius=line_thickness // 2,
            fill=line_color
        )

    # Draw AI/Summary sparkle symbol (bottom right of document)
    sparkle_x = doc_right - int(work_size * 0.08)
    sparkle_y = doc_bottom - int(work_size * 0.12)
    sparkle_size = int(work_size * 0.12)

    # Main 4-pointed star
    def draw_star(cx, cy, size, color, points=4):
        star_points = []
        inner_ratio = 0.3
        for i in range(points * 2):
            angle = (i * 3.14159 / points) - 3.14159 / 2
            r = size if i % 2 == 0 else size * inner_ratio
            x = cx + r * (1 if i < points else -1) * (0 if i % points == 0 else 1)
            y = cy + r * (0 if i % points == 0 else 1 if i < points else -1)

        # Draw 4-pointed star manually
        import math
        star_pts = []
        for i in range(8):
            angle = i * math.pi / 4 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.35
            x = cx + r * math.cos(angle)
            y = cy + r * math.sin(angle)
            star_pts.append((x, y))
        draw.polygon(star_pts, fill=color)

    # Draw main sparkle
    import math

    def draw_sparkle(cx, cy, size, color):
        # 4-pointed star
        pts = []
        for i in range(8):
            angle = i * math.pi / 4 - math.pi / 2
            r = size if i % 2 == 0 else size * 0.3
            x = cx + r * math.cos(angle)
            y = cy + r * math.sin(angle)
            pts.append((x, y))
        draw.polygon(pts, fill=color)

    # Main sparkle (gold)
    draw_sparkle(sparkle_x, sparkle_y, sparkle_size, accent_color)

    # Smaller sparkles around
    small_sparkle_size = sparkle_size * 0.4
    draw_sparkle(sparkle_x - sparkle_size * 1.2, sparkle_y - sparkle_size * 0.5,
                 small_sparkle_size, (255, 255, 255, 200))
    draw_sparkle(sparkle_x + sparkle_size * 0.3, sparkle_y - sparkle_size * 1.1,
                 small_sparkle_size * 0.7, (255, 255, 255, 180))

    # Apply the rounded corner mask again
    img.putalpha(ImageChops_multiply_alpha(img.split()[3], mask))

    # Scale down to target size
    if scale > 1:
        img = img.resize((size, size), Image.LANCZOS)

    return img


def ImageChops_multiply_alpha(alpha1, alpha2):
    """Multiply two alpha channels."""
    result = Image.new('L', alpha1.size, 0)
    for y in range(alpha1.size[1]):
        for x in range(alpha1.size[0]):
            a1 = alpha1.getpixel((x, y))
            a2 = alpha2.getpixel((x, y))
            result.putpixel((x, y), min(a1, a2))
    return result


def create_simple_icon(size):
    """Create a simpler, cleaner app icon."""
    import math

    # Create at higher resolution for quality
    scale = 4 if size < 256 else 2
    work_size = size * scale

    # Colors - Modern gradient
    bg_color1 = (99, 102, 241)    # Indigo (#6366f1)
    bg_color2 = (139, 92, 246)    # Violet (#8b5cf6)
    doc_color = (255, 255, 255)
    accent_color = (251, 191, 36)  # Amber (#fbbf24)

    img = Image.new('RGBA', (work_size, work_size), (0, 0, 0, 0))

    # Create smooth gradient
    for y in range(work_size):
        for x in range(work_size):
            # Radial-ish gradient from top-left
            dist = math.sqrt(x*x + y*y) / (math.sqrt(2) * work_size)
            r = int(bg_color1[0] + (bg_color2[0] - bg_color1[0]) * dist)
            g = int(bg_color1[1] + (bg_color2[1] - bg_color1[1]) * dist)
            b = int(bg_color1[2] + (bg_color2[2] - bg_color1[2]) * dist)
            img.putpixel((x, y), (r, g, b, 255))

    draw = ImageDraw.Draw(img)

    # iOS rounded corners
    corner_radius = int(work_size * 0.22)
    mask = Image.new('L', (work_size, work_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, work_size-1, work_size-1], radius=corner_radius, fill=255)

    # Document dimensions
    doc_width = int(work_size * 0.5)
    doc_height = int(work_size * 0.6)
    doc_left = (work_size - doc_width) // 2
    doc_top = int(work_size * 0.18)
    doc_right = doc_left + doc_width
    doc_bottom = doc_top + doc_height
    fold_size = int(work_size * 0.1)

    # Shadow
    shadow = Image.new('RGBA', (work_size, work_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_offset = int(work_size * 0.015)
    shadow_draw.rounded_rectangle(
        [doc_left + shadow_offset, doc_top + shadow_offset,
         doc_right + shadow_offset, doc_bottom + shadow_offset],
        radius=int(work_size * 0.03),
        fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=work_size * 0.015))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Document body
    draw.rounded_rectangle(
        [doc_left, doc_top, doc_right, doc_bottom],
        radius=int(work_size * 0.03),
        fill=doc_color
    )

    # Folded corner
    fold_pts = [
        (doc_right - fold_size, doc_top),
        (doc_right, doc_top + fold_size),
        (doc_right - fold_size, doc_top + fold_size),
    ]
    draw.polygon(fold_pts, fill=(235, 235, 240))

    # Text lines
    line_color = (180, 180, 195)
    line_start_x = doc_left + int(work_size * 0.05)
    line_start_y = doc_top + int(work_size * 0.1)
    line_spacing = int(work_size * 0.055)
    line_height = max(2, int(work_size * 0.015))

    widths = [0.7, 0.85, 0.6, 0.75, 0.5]
    max_width = doc_width - int(work_size * 0.1)

    for i, w in enumerate(widths):
        y = line_start_y + i * line_spacing
        line_width = int(max_width * w)
        draw.rounded_rectangle(
            [line_start_x, y, line_start_x + line_width, y + line_height],
            radius=line_height // 2,
            fill=line_color
        )

    # AI Sparkle/Summary icon (bottom area)
    sparkle_cx = work_size // 2
    sparkle_cy = int(work_size * 0.78)
    sparkle_r = int(work_size * 0.1)

    def draw_4star(cx, cy, r, color):
        pts = []
        for i in range(8):
            angle = i * math.pi / 4 - math.pi / 2
            radius = r if i % 2 == 0 else r * 0.35
            x = cx + radius * math.cos(angle)
            y = cy + radius * math.sin(angle)
            pts.append((x, y))
        draw.polygon(pts, fill=color)

    # Main sparkle
    draw_4star(sparkle_cx, sparkle_cy, sparkle_r, accent_color)

    # Small accent sparkles
    draw_4star(sparkle_cx - sparkle_r * 1.5, sparkle_cy - sparkle_r * 0.3,
               sparkle_r * 0.35, (255, 255, 255))
    draw_4star(sparkle_cx + sparkle_r * 1.3, sparkle_cy - sparkle_r * 0.5,
               sparkle_r * 0.25, (255, 255, 255, 200))

    # Apply mask
    final_mask = Image.new('L', (work_size, work_size), 0)
    final_draw = ImageDraw.Draw(final_mask)
    final_draw.rounded_rectangle([0, 0, work_size-1, work_size-1], radius=corner_radius, fill=255)
    img.putalpha(final_mask)

    # Scale down
    if scale > 1:
        img = img.resize((size, size), Image.LANCZOS)

    return img


def create_launch_image(width, height):
    """Create a launch screen image with centered logo."""
    import math

    # Colors - Match app icon
    bg_color1 = (99, 102, 241)    # Indigo (#6366f1)
    bg_color2 = (139, 92, 246)    # Violet (#8b5cf6)
    doc_color = (255, 255, 255)
    accent_color = (251, 191, 36)  # Amber (#fbbf24)

    img = Image.new('RGBA', (width, height), (0, 0, 0, 255))

    # Create smooth gradient background
    max_dist = math.sqrt(width * width + height * height)
    for y in range(height):
        for x in range(width):
            dist = math.sqrt(x * x + y * y) / max_dist
            r = int(bg_color1[0] + (bg_color2[0] - bg_color1[0]) * dist)
            g = int(bg_color1[1] + (bg_color2[1] - bg_color1[1]) * dist)
            b = int(bg_color1[2] + (bg_color2[2] - bg_color1[2]) * dist)
            img.putpixel((x, y), (r, g, b, 255))

    draw = ImageDraw.Draw(img)

    # Calculate icon size (centered, about 20% of shortest dimension)
    icon_size = int(min(width, height) * 0.2)
    cx = width // 2
    cy = height // 2

    # Document dimensions
    doc_width = int(icon_size * 0.5)
    doc_height = int(icon_size * 0.6)
    doc_left = cx - doc_width // 2
    doc_top = cy - int(icon_size * 0.35)
    doc_right = doc_left + doc_width
    doc_bottom = doc_top + doc_height
    fold_size = int(icon_size * 0.1)

    # Shadow
    shadow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_offset = int(icon_size * 0.015)
    shadow_draw.rounded_rectangle(
        [doc_left + shadow_offset, doc_top + shadow_offset,
         doc_right + shadow_offset, doc_bottom + shadow_offset],
        radius=int(icon_size * 0.03),
        fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=icon_size * 0.015))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Document body
    draw.rounded_rectangle(
        [doc_left, doc_top, doc_right, doc_bottom],
        radius=int(icon_size * 0.03),
        fill=doc_color
    )

    # Folded corner
    fold_pts = [
        (doc_right - fold_size, doc_top),
        (doc_right, doc_top + fold_size),
        (doc_right - fold_size, doc_top + fold_size),
    ]
    draw.polygon(fold_pts, fill=(235, 235, 240))

    # Text lines
    line_color = (180, 180, 195)
    line_start_x = doc_left + int(icon_size * 0.05)
    line_start_y = doc_top + int(icon_size * 0.1)
    line_spacing = int(icon_size * 0.055)
    line_height = max(2, int(icon_size * 0.015))

    widths = [0.7, 0.85, 0.6, 0.75, 0.5]
    max_line_width = doc_width - int(icon_size * 0.1)

    for i, w in enumerate(widths):
        y = line_start_y + i * line_spacing
        line_width = int(max_line_width * w)
        draw.rounded_rectangle(
            [line_start_x, y, line_start_x + line_width, y + line_height],
            radius=line_height // 2,
            fill=line_color
        )

    # AI Sparkle/Summary icon (bottom area)
    sparkle_cx = cx
    sparkle_cy = doc_bottom + int(icon_size * 0.15)
    sparkle_r = int(icon_size * 0.1)

    def draw_4star(scx, scy, r, color):
        pts = []
        for i in range(8):
            angle = i * math.pi / 4 - math.pi / 2
            radius = r if i % 2 == 0 else r * 0.35
            px = scx + radius * math.cos(angle)
            py = scy + radius * math.sin(angle)
            pts.append((px, py))
        draw.polygon(pts, fill=color)

    # Main sparkle
    draw_4star(sparkle_cx, sparkle_cy, sparkle_r, accent_color)

    # Small accent sparkles
    draw_4star(sparkle_cx - sparkle_r * 1.5, sparkle_cy - sparkle_r * 0.3,
               sparkle_r * 0.35, (255, 255, 255))
    draw_4star(sparkle_cx + sparkle_r * 1.3, sparkle_cy - sparkle_r * 0.5,
               sparkle_r * 0.25, (255, 255, 255, 200))

    return img


def main():
    """Generate all required app icon sizes."""
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    ios_icon_dir = project_dir / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos_icon_dir = project_dir / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    launch_image_dir = project_dir / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

    # iOS icon sizes (point size x scale)
    ios_sizes = [
        (20, 1), (20, 2), (20, 3),
        (29, 1), (29, 2), (29, 3),
        (40, 1), (40, 2), (40, 3),
        (60, 2), (60, 3),
        (76, 1), (76, 2),
        (83.5, 2),
        (1024, 1),
    ]

    # macOS icon sizes
    macos_sizes = [16, 32, 64, 128, 256, 512, 1024]

    print("Generating Transcript Summarizer App Icons...")
    print("=" * 50)

    # Generate iOS icons
    print("\niOS Icons:")
    for point_size, scale in ios_sizes:
        pixel_size = int(point_size * scale)
        if point_size == 83.5:
            filename = f"Icon-App-83.5x83.5@{scale}x.png"
        else:
            filename = f"Icon-App-{int(point_size)}x{int(point_size)}@{scale}x.png"

        filepath = ios_icon_dir / filename
        icon = create_simple_icon(pixel_size)
        icon.save(filepath, "PNG")
        print(f"  Created: {filename} ({pixel_size}x{pixel_size})")

    # Generate macOS icons
    print("\nmacOS Icons:")
    for size in macos_sizes:
        filename = f"app_icon_{size}.png"
        filepath = macos_icon_dir / filename
        icon = create_simple_icon(size)
        icon.save(filepath, "PNG")
        print(f"  Created: {filename} ({size}x{size})")

    # Update iOS Contents.json with filenames
    ios_contents = {
        "images": [
            {"idiom": "iphone", "scale": "2x", "size": "20x20", "filename": "Icon-App-20x20@2x.png"},
            {"idiom": "iphone", "scale": "3x", "size": "20x20", "filename": "Icon-App-20x20@3x.png"},
            {"idiom": "iphone", "scale": "2x", "size": "29x29", "filename": "Icon-App-29x29@2x.png"},
            {"idiom": "iphone", "scale": "3x", "size": "29x29", "filename": "Icon-App-29x29@3x.png"},
            {"idiom": "iphone", "scale": "2x", "size": "40x40", "filename": "Icon-App-40x40@2x.png"},
            {"idiom": "iphone", "scale": "3x", "size": "40x40", "filename": "Icon-App-40x40@3x.png"},
            {"idiom": "iphone", "scale": "2x", "size": "60x60", "filename": "Icon-App-60x60@2x.png"},
            {"idiom": "iphone", "scale": "3x", "size": "60x60", "filename": "Icon-App-60x60@3x.png"},
            {"idiom": "ipad", "scale": "1x", "size": "20x20", "filename": "Icon-App-20x20@1x.png"},
            {"idiom": "ipad", "scale": "2x", "size": "20x20", "filename": "Icon-App-20x20@2x.png"},
            {"idiom": "ipad", "scale": "1x", "size": "29x29", "filename": "Icon-App-29x29@1x.png"},
            {"idiom": "ipad", "scale": "2x", "size": "29x29", "filename": "Icon-App-29x29@2x.png"},
            {"idiom": "ipad", "scale": "1x", "size": "40x40", "filename": "Icon-App-40x40@1x.png"},
            {"idiom": "ipad", "scale": "2x", "size": "40x40", "filename": "Icon-App-40x40@2x.png"},
            {"idiom": "ipad", "scale": "1x", "size": "76x76", "filename": "Icon-App-76x76@1x.png"},
            {"idiom": "ipad", "scale": "2x", "size": "76x76", "filename": "Icon-App-76x76@2x.png"},
            {"idiom": "ipad", "scale": "2x", "size": "83.5x83.5", "filename": "Icon-App-83.5x83.5@2x.png"},
            {"idiom": "ios-marketing", "scale": "1x", "size": "1024x1024", "filename": "Icon-App-1024x1024@1x.png"},
        ],
        "info": {"version": 1, "author": "xcode"}
    }

    import json
    with open(ios_icon_dir / "Contents.json", "w") as f:
        json.dump(ios_contents, f, indent=2)
    print("\n  Updated: iOS Contents.json")

    # Generate Launch Images
    print("\nLaunch Images:")

    # Launch image sizes (width x height for different screen sizes)
    # Using square format that works well centered on any screen
    launch_sizes = [
        ("LaunchImage.png", 1, 320, 480),      # 1x (iPhone 4)
        ("LaunchImage@2x.png", 2, 640, 960),   # 2x (iPhone 4 Retina)
        ("LaunchImage@3x.png", 3, 1242, 2208), # 3x (iPhone Plus)
        ("LaunchImage-568h@2x.png", 2, 640, 1136),  # iPhone 5
        ("LaunchImage-667h.png", 2, 750, 1334),     # iPhone 6/7/8
        ("LaunchImage-736h.png", 3, 1242, 2208),    # iPhone Plus
    ]

    for filename, scale, width, height in launch_sizes:
        filepath = launch_image_dir / filename
        launch_img = create_launch_image(width, height)
        launch_img.save(filepath, "PNG")
        print(f"  Created: {filename} ({width}x{height})")

    print("\n" + "=" * 50)
    print("App icons and launch images generated successfully!")
    print("\nDesign: Indigo/violet gradient with document + AI sparkle")


if __name__ == "__main__":
    main()
