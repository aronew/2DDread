"""Import a generated painting of a room (made from a paint guide, see
docs/paint_guides/README.md) so the game can lay it back over that room.

    python3 tools/rooms/import_room_paint.py PAINTING GUIDE_JSON NAME [walls]

PAINTING    the image the generator returned (any size; resized to the guide's)
GUIDE_JSON  the guide's camera file (world_to_image), written by --paint-guide
NAME        output name: assets/rooms/NAME.png and assets/rooms/NAME.json
walls       the painting includes the walls the game adds around rooms (ENCLOSE): those
            walls then draw it; without it they keep their own art (older paintings
            show abyss where they stand)

What it does:
- The black abyss around the floor is made transparent, so the game's animated
  soul-fire void shows through: near-black regions connected to the image border are
  flood-filled and keyed out. Dark pixels inside the room (grout, pit shadows, ink) stay.
- A coarse copy of that abyss mask goes into the JSON (`mask`, one hex digit per 16 px),
  so the game knows where the painting has floor and only drops tiles there.
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


def main(painting, guide_json, name, walls=False):
    guide = json.load(open(guide_json))
    w, h = guide["size"]
    im = Image.open(painting).convert("RGB")
    if im.size != (w, h):
        im = im.resize((w, h), Image.LANCZOS)
    rgb = np.asarray(im).astype(np.float32)
    alpha = key_abyss(rgb)
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
                   "walls": bool(walls), "source": os.path.relpath(painting, ROOT)}, f, indent=1)
    print("wrote assets/rooms/%s.png (%dx%d) and .json" % (name, w, h))


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5) or (len(sys.argv) == 5 and sys.argv[4] != "walls"):
        print(__doc__)
        sys.exit(1)
    main(*sys.argv[1:4], walls=len(sys.argv) == 5)
