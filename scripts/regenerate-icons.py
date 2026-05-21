#!/usr/bin/env python3
"""
Regenerate all icon variants for the AppIcon.appiconset from a single source PNG.
Generates:
  - icon_{16,32,128,256,512}x{...}.png + @2x variants
  - AppStoreIcon-1024.png (marketing icon, RGB, no alpha)

Usage:
    python3 scripts/regenerate-icons.py <source.png>
"""
import sys
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
ICONSET = REPO / "StatFocus/Resources/Assets.xcassets/AppIcon.appiconset"
MARKETING = REPO / "docs/screenshots/AppStoreIcon-1024.png"

# (base_size, scale) -> filename
SIZES = [
    (16,  1, "icon_16x16.png"),
    (16,  2, "icon_16x16@2x.png"),
    (32,  1, "icon_32x32.png"),
    (32,  2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]


def main(src: str) -> int:
    src_path = Path(src).expanduser().resolve()
    if not src_path.exists():
        print(f"Source not found: {src_path}", file=sys.stderr)
        return 1

    img = Image.open(src_path).convert("RGBA")
    print(f"Source: {src_path}  {img.size}")

    if img.size[0] != img.size[1]:
        print("Warning: source is not square — output may look stretched.", file=sys.stderr)

    ICONSET.mkdir(parents=True, exist_ok=True)
    for base, scale, name in SIZES:
        target = base * scale
        out = ICONSET / name
        resized = img.resize((target, target), Image.LANCZOS)
        resized.save(out, "PNG", optimize=True)
        print(f"  {name}  {target}x{target}")

    # Marketing icon (App Store) — flatten to RGB on opaque background
    print()
    marketing = img.resize((1024, 1024), Image.LANCZOS)
    # If source has alpha, use top-left pixel as background fallback
    if marketing.mode == "RGBA":
        bg_color = tuple(marketing.getpixel((0, 0))[:3])
        flat = Image.new("RGB", marketing.size, bg_color)
        flat.paste(marketing, mask=marketing.split()[3])
        marketing = flat
    else:
        marketing = marketing.convert("RGB")
    MARKETING.parent.mkdir(parents=True, exist_ok=True)
    marketing.save(MARKETING, "PNG", optimize=True)
    print(f"  AppStoreIcon-1024.png  1024x1024 RGB (no alpha) → {MARKETING}")

    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: regenerate-icons.py <source.png>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
