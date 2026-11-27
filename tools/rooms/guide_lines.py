"""Line-art copy of a paint guide (black lines on white), for SOL to follow.

    python3 tools/rooms/guide_lines.py docs/paint_guides/NAME_guide.png

writes NAME_lines.png next to it.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps

src = sys.argv[1]
a = np.asarray(Image.open(src).convert("L").filter(ImageFilter.GaussianBlur(0.8))).astype(float)
gx = np.zeros_like(a)
gy = np.zeros_like(a)
gx[:, 1:-1] = a[:, 2:] - a[:, :-2]
gy[1:-1, :] = a[2:, :] - a[:-2, :]
lines = Image.fromarray(((np.hypot(gx, gy) > 18) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
dst = src.replace("_guide.png", "_lines.png")
ImageOps.invert(lines).save(dst)
print("wrote", dst)
