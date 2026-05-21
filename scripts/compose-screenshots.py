#!/usr/bin/env python3
"""
Compose raw window screenshots into App Store-ready 2880x1800 canvases.

Each input PNG is scaled (preserving aspect ratio) to fit inside ~80% of the canvas,
centered, with a soft drop shadow over a brand-colored background.

Usage:
    python3 scripts/compose-screenshots.py docs/screenshots/*.png

Output:
    docs/screenshots/composed/01-<original>.png  (2880x1800)
"""
import sys
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw

# App Store Connect accepts: 1280x800, 1440x900, 2560x1600, 2880x1800
TARGET_W, TARGET_H = 2880, 1800

# Background — light tint of #2D6A4F (app accent)
BG_COLOR = (232, 240, 236)

# Maximum fraction of the canvas the screenshot can occupy
MAX_FILL = 0.80

# Drop shadow params
SHADOW_OFFSET = (0, 24)
SHADOW_BLUR = 32
SHADOW_OPACITY = 80  # 0-255


def compose(src_path: Path, dst_path: Path) -> None:
    img = Image.open(src_path).convert("RGBA")

    # Scale screenshot to fit in MAX_FILL × canvas, preserving aspect ratio
    max_w = int(TARGET_W * MAX_FILL)
    max_h = int(TARGET_H * MAX_FILL)
    scale = min(max_w / img.width, max_h / img.height)
    new_w = int(img.width * scale)
    new_h = int(img.height * scale)
    img = img.resize((new_w, new_h), Image.LANCZOS)

    # Canvas with brand background
    canvas = Image.new("RGBA", (TARGET_W, TARGET_H), BG_COLOR + (255,))

    # Position centered
    pos_x = (TARGET_W - new_w) // 2
    pos_y = (TARGET_H - new_h) // 2

    # Shadow layer (slightly larger than image, blurred)
    shadow = Image.new("RGBA", (TARGET_W, TARGET_H), (0, 0, 0, 0))
    sx, sy = SHADOW_OFFSET
    shadow_box = (pos_x + sx, pos_y + sy, pos_x + sx + new_w, pos_y + sy + new_h)
    ImageDraw.Draw(shadow).rectangle(
        shadow_box, fill=(0, 0, 0, SHADOW_OPACITY)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))

    canvas.alpha_composite(shadow)
    canvas.alpha_composite(img, (pos_x, pos_y))

    canvas.convert("RGB").save(dst_path, "PNG", optimize=True)
    print(f"  {dst_path.name}  ({new_w}×{new_h} centered)")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: compose-screenshots.py <input.png> [more.png ...]", file=sys.stderr)
        return 1

    out_dir = Path("docs/screenshots/composed")
    out_dir.mkdir(parents=True, exist_ok=True)

    inputs = sorted(Path(p) for p in argv[1:] if Path(p).exists())
    if not inputs:
        print("No valid input files.", file=sys.stderr)
        return 1

    print(f"Composing {len(inputs)} screenshot(s) → {out_dir}/  (canvas {TARGET_W}×{TARGET_H})")
    for idx, src in enumerate(inputs, start=1):
        dst = out_dir / f"{idx:02d}-{src.stem}.png"
        compose(src, dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
