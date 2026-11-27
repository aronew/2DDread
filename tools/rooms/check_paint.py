"""Check a SOL painting against a paint guide before importing it: draws the guide's
line art in red over the painting. Pits, bridges, columns and props should sit on the
red lines; if they don't, try the other guide or ask SOL to keep the layout.

    python3 tools/rooms/check_paint.py PAINTING docs/paint_guides/NAME_lines.png OUT.png
"""
import sys

import numpy as np
from PIL import Image

painting, lines, out = sys.argv[1:4]
L = Image.open(lines).convert("L")
p = Image.open(painting).convert("RGB").resize(L.size, Image.LANCZOS)
a = np.asarray(p).astype(float)
m = np.asarray(L) < 128
a[m] = a[m] * 0.3 + np.array([255, 40, 40]) * 0.7
Image.fromarray(a.astype(np.uint8)).save(out)
print("wrote", out)
