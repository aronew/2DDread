"""Make the HUD portrait (the gold diamond, bottom-left) from a piece of character art.

    python3 tools/ui/portrait_from_art.py ART CX CY SIZE [OUT]

ART      the character image (transparent or plain background)
CX CY    the pixel in ART the diamond centres on (the face)
SIZE     width of the square cut out of ART around it, in ART pixels; the HUD shows the
         diamond inscribed in that square, so the corners are cut off
OUT      default assets/sprites/ui/portrait.png (256 x 256)

A white or near-white background connected to the image border is keyed out, so the
HUD's dark panel shows behind the character. Writes OUT plus OUT_preview.png (next to
it in /tmp) showing the diamond as the HUD draws it.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZE_OUT = 256


def key_white(im):
    rgb = np.asarray(im.convert("RGB")).astype(np.int32)
    a = np.asarray(im.convert("RGBA"))[..., 3].copy()
    white = ((rgb.min(-1) > 235) & (a > 0)).astype(np.uint8) * 255
    mask = Image.fromarray(white).copy()
    w, h = mask.size
    for x, y in [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + \
                [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]:
        if mask.getpixel((x, y)) == 255:
            ImageDraw.floodfill(mask, (x, y), 128, thresh=0)
    a[np.asarray(mask) == 128] = 0
    out = np.dstack([np.asarray(im.convert("RGB")), a])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def main(art, cx, cy, size, out=None):
    out = out or os.path.join(ROOT, "assets", "sprites", "ui", "portrait.png")
    im = key_white(Image.open(art))
    half = size // 2
    box = (cx - half, cy - half, cx - half + size, cy - half + size)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(im.crop(box))   # crop() pads outside the image with transparency
    canvas = canvas.resize((SIZE_OUT, SIZE_OUT), Image.LANCZOS)
    canvas.save(out)
    # preview: the diamond the HUD draws, on its dark panel
    pv = Image.new("RGBA", (SIZE_OUT, SIZE_OUT), (16, 22, 24, 255))
    pv.alpha_composite(canvas)
    m = Image.new("L", (SIZE_OUT, SIZE_OUT), 0)
    s = SIZE_OUT
    ImageDraw.Draw(m).polygon([(s / 2, 0), (s, s / 2), (s / 2, s), (0, s / 2)], fill=255)
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 255))
    bg.paste(pv, (0, 0), m)
    ImageDraw.Draw(bg).polygon([(s / 2, 1), (s - 1, s / 2), (s / 2, s - 1), (1, s / 2)], outline=(220, 170, 70, 255))
    pv_path = os.path.join("/tmp", os.path.splitext(os.path.basename(out))[0] + "_preview.png")
    bg.save(pv_path)
    print("wrote %s and %s" % (out, pv_path))


if __name__ == "__main__":
    if len(sys.argv) not in (5, 6):
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), *(sys.argv[5:]))
