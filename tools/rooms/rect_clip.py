"""Clip a painting to the map cells its room owns, given as cell rectangles, before
importing it (the Phlegethon's islands; band_clip.py is for the temple's column bands).

    python3 tools/rooms/rect_clip.py PAINTING GUIDE_JSON OUT "i0,j0,i1,j1 ..." [height_m]

Rectangles are inclusive cell ranges. A pixel is kept if its ground point, or the ground
point up to height_m (default 3.5) metres below it on screen, lies in an owned cell, so
columns, statues and the giant skulls keep their painted height above their ground.
Everything else is painted pure black (import_room_paint.py keys it out).
"""
import json
import sys

import numpy as np
from PIL import Image

HPX_PER_M = 78.3837

paint, guide, out, rects = sys.argv[1:5]
height = float(sys.argv[5]) if len(sys.argv) > 5 else 3.5
g = json.load(open(guide))
a, b, c, d, tx, ty = g["world_to_image"]
R = [tuple(int(v) for v in r.split(",")) for r in rects.split()]
im = Image.open(paint).convert("RGB")
W, H = g["size"]
if im.size != (W, H):
    im = im.resize((W, H), Image.LANCZOS)
arr = np.asarray(im).copy()
ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
wx = (xs - tx) / a
keep = np.zeros((H, W), bool)
step = 6.0
for t in np.arange(0.0, height * HPX_PER_M * d + step, step):
    wy = (ys + t - ty) / d
    fi = (wx / 128.0 + wy / 64.0) / 2.0
    fj = (wy / 64.0 - wx / 128.0) / 2.0
    ci = np.floor(fi)
    cj = np.floor(fj)
    for (i0, j0, i1, j1) in R:
        keep |= (ci >= i0) & (ci <= i1) & (cj >= j0) & (cj <= j1)
arr[~keep] = 0
Image.fromarray(arr).save(out)
print("wrote", out, "kept %.0f%%" % (100.0 * keep.mean()))
