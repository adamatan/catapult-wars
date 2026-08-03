#!/usr/bin/env python3
"""Cut horizon plates out of the reference mockups.

The mockups are flat renders with everything baked in, so only a narrow band is
usable. It is squeezed from four sides:

  - y < 150   the mockup's own player chips and turn emblem
  - y > 355   the painted catapults and their stone platforms
  - x < 240   a painted legion standard (per-image faction, wrong colours for us)
  - x > 1480  ditto on the right

What is left is sky, horizon and the top of the mid-ground set piece. That gets
used as a horizon band; the sky above it and the haze below it are drawn
procedurally from colours sampled here, so the band never has to stretch far.

Run:  python3 scripts/make_backdrops.py
"""
from pathlib import Path
import json

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "reference" / "ready to fire"
OUT_DIR = ROOT / "assets" / "backdrops"

CROP = (240, 150, 1480, 355)  # left, top, right, bottom
OUT_WIDTH = 1920
JPEG_QUALITY = 88

# Order matters: these become field_01..04 and the names show up in the UI.
# Sky and haze colours are sampled from the plate; the terrain pair is hand
# picked to sit under each scene (rock body, then the crust along the surface).
SCENES = [
    ("ready-1.png", "field_01", "Alpine Pass",    "#3c444d", "#dfe6ec"),
    ("ready-2.png", "field_02", "Hilltop Siege",  "#5c4126", "#c1955c"),
    ("ready-3.png", "field_03", "Coastal City",   "#5b5342", "#9aa06a"),
    ("ready-4.png", "field_04", "Frontier Wall",  "#38402c", "#7d8a4e"),
]


def average_row(img, y, samples=240):
    """Mean colour of one pixel row, sampled across the width."""
    step = max(1, img.width // samples)
    px = img.load()
    n = 0
    r = g = b = 0
    for x in range(0, img.width, step):
        pr, pg, pb = px[x, y]
        r += pr
        g += pg
        b += pb
        n += 1
    return (round(r / n), round(g / n), round(b / n))


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = []

    for filename, slug, title, rock, crust in SCENES:
        src = Image.open(SRC_DIR / filename).convert("RGB")
        plate = src.crop(CROP)

        # Pre-upscale with Lanczos: better than letting the GPU do a 1.5x
        # bilinear stretch on a soft painted image.
        height = round(plate.height * OUT_WIDTH / plate.width)
        plate = plate.resize((OUT_WIDTH, height), Image.LANCZOS)

        out_path = OUT_DIR / f"{slug}.jpg"
        plate.save(out_path, "JPEG", quality=JPEG_QUALITY, optimize=True)

        manifest.append(
            {
                "slug": slug,
                "title": title,
                "texture": f"res://assets/backdrops/{slug}.jpg",
                # Sky fades to the plate's top row; haze fades from its bottom row.
                "sky_color": average_row(plate, 0),
                "haze_color": average_row(plate, plate.height - 1),
                "rock_color": rock,
                "crust_color": crust,
            }
        )
        print(f"{out_path.name}: {plate.width}x{plate.height} "
              f"{out_path.stat().st_size // 1024}KB "
              f"sky={manifest[-1]['sky_color']} haze={manifest[-1]['haze_color']}")

    (OUT_DIR / "backdrops.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {OUT_DIR / 'backdrops.json'}")


if __name__ == "__main__":
    main()
