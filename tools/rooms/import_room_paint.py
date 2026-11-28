"""Import a generated painting of a room (made from a paint guide, see
docs/paint_guides/README.md) so the game can lay it back over that room.

    python3 tools/rooms/import_room_paint.py PAINTING GUIDE_JSON NAME [walls]

PAINTING    the image the generator returned (any size; resized to the guide's)
GUIDE_JSON  the guide's camera file (world_to_image), written by --paint-guide
NAME        output name: assets/rooms/NAME.png and assets/rooms/NAME.json
holes=LAYOUT  (the Phlegethon) lone void cells inside an island in that layout file are
            sinkholes: dark painted pixels in them are keyed out so the lava shows
pits=LAYOUT   (the hub) every soul-fire pit cell in that layout file: dark painted pixels
            in it are keyed out so the game's green fire burns there
walls       the painting includes the walls the game adds around rooms (ENCLOSE): those
            walls then draw it; without it they keep their own art (older paintings
            show abyss where they stand)

What it does:
- The black abyss around the floor is made transparent, so the game's animated
  soul-fire void shows through: near-black regions connected to the image border are
  flood-filled and keyed out. Dark pixels inside the room (grout, pit shadows, ink) stay.
- A coarse copy of that abyss mask goes into the JSON (`mask`, one hex digit per 16 px),
  so the game knows where the painting has floor and only drops tiles there.
- Its average colour (`mean`) is stored too: the game tints walls it doesn't cover
  (kit art) toward it, so they don't stand out in grey.
- The guide's camera transform is copied next to it. The game fades the painting's outer
  edge itself (room_paint.gdshader), so it blends into the tiles beyond it.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ABYSS_LUM = 0.035     # darker than this and touching the border = abyss
MASK_STEP = 16        # px per cell of the coarse mask in the JSON


def key_abyss(rgb):
    lum = rgb.mean(-1) / 255.0
    mask = Image.fromarray(((lum < ABYSS_LUM) * 255).astype(np.uint8)).copy()   # fromarray images are read-only
    h, w = lum.shape
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + \
             [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for x, y in border:
        if mask.getpixel((x, y)) == 255:
            ImageDraw.floodfill(mask, (x, y), 128, thresh=0)
    abyss = (np.asarray(mask) == 128).astype(np.uint8) * 255
    # soften the cut by a pixel or two so the ink edge stays and nothing halos
    soft = Image.fromarray(abyss).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    return 1.0 - np.asarray(soft).astype(np.float32) / 255.0


HOLE_LUM = 0.1       # sinkholes: darker than this inside an interior void cell = see-through


def key_holes(rgb, guide, layout, pits=False):
    """The Phlegethon's sinkholes: lone void cells inside an island show the game's lava
    through the painting. Dark painted pixels inside such a cell's diamond are keyed out."""
    import re
    src = open(layout).read()
    rows = re.findall(r'^\t"(.*)",$', re.search(r"const MAP := \[(.*?)\n\]", src, re.S).group(1), re.M)
    get = lambda i, j: rows[j][i] if 0 <= j < len(rows) and 0 <= i < len(rows[j]) else " "
    a, b, c, d, tx, ty = guide["world_to_image"]
    lum = rgb.mean(-1) / 255.0
    h, w = lum.shape
    cut = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(cut)
    to_img = lambda i, j: (a * (i - j) * 128.0 + c * (i + j) * 64.0 + tx, b * (i - j) * 128.0 + d * (i + j) * 64.0 + ty)
    n = 0
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != " ":
                continue
            if pits:
                # a soul-fire pit (PitFire.find_pits): non-wall floor within 8 cells all four ways
                def closed(di, dj):
                    for k in range(1, 9):
                        ch2 = get(i + di * k, j + dj * k)
                        if ch2 != " ":
                            return ch2 not in "PWMIRKOQU"
                    return False
                inside = all(closed(di, dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            else:
                inside = all(get(i + di, j + dj) != " " for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if inside:
                dr.polygon([to_img(i, j), to_img(i + 1, j), to_img(i + 1, j + 1), to_img(i, j + 1)], fill=255)
                n += 1
    holes = (np.asarray(cut) > 0) & (lum < HOLE_LUM)
    soft = Image.fromarray((holes * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    return 1.0 - np.asarray(soft).astype(np.float32) / 255.0


def main(painting, guide_json, name, walls=False, holes=None, pits=None):
    guide = json.load(open(guide_json))
    w, h = guide["size"]
    im = Image.open(painting).convert("RGB")
    if im.size != (w, h):
        im = im.resize((w, h), Image.LANCZOS)
    rgb = np.asarray(im).astype(np.float32)
    alpha = key_abyss(rgb)
    if holes:
        alpha = np.minimum(alpha, key_holes(rgb, guide, holes))
    if pits:
        alpha = np.minimum(alpha, key_holes(rgb, guide, pits, pits=True))
    out = np.dstack([rgb, alpha * 255.0])
    mh, mw = h // MASK_STEP, w // MASK_STEP
    coarse = alpha[:mh * MASK_STEP, :mw * MASK_STEP].reshape(mh, MASK_STEP, mw, MASK_STEP).mean((1, 3))
    mask = "".join("%x" % int(round(v * 15)) for v in coarse.ravel())
    d = os.path.join(ROOT, "assets", "rooms")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(os.path.join(d, name + ".png"))
    with open(os.path.join(d, name + ".json"), "w") as f:
        json.dump({"size": [w, h], "world_to_image": guide["world_to_image"],
                   "mask": {"step": MASK_STEP, "w": mw, "h": mh, "data": mask},
                   "walls": bool(walls), "mean": [round(float(v) / 255.0, 4) for v in rgb[alpha > 0.9].mean(0)],
                   "source": os.path.relpath(painting, ROOT) if os.path.abspath(painting).startswith(ROOT) else os.path.basename(painting)}, f, indent=1)
    print("wrote assets/rooms/%s.png (%dx%d) and .json" % (name, w, h))


if __name__ == "__main__":
    extra = sys.argv[4:]
    holes = [e[6:] for e in extra if e.startswith("holes=")]
    pits = [e[5:] for e in extra if e.startswith("pits=")]
    if len(sys.argv) < 4 or any(e != "walls" and not e.startswith(("holes=", "pits=")) for e in extra):
        print(__doc__)
        sys.exit(1)
    main(*sys.argv[1:4], walls="walls" in extra, holes=holes[0] if holes else None, pits=pits[0] if pits else None)
