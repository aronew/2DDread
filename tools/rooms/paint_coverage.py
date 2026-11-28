"""Which floor cells no room painting covers (they show bare kit tiles in the game).

    python3 tools/rooms/paint_coverage.py LAYOUT_GD [--trim]

Reads the layout's MAP and PAINTS (the imported assets/rooms/*.png, alpha = painted).
Prints every walkable cell less than half covered. With --trim (for open island levels
such as the Phlegethon), uncovered cells on an island's rim that hold no prop or marker
are turned into void, again and again until none is left, as long as every walkable cell
stays reachable from S; the MAP in the layout file is rewritten.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
layout = sys.argv[1]
trim = "--trim" in sys.argv
src = open(layout).read()
m = re.search(r"const MAP := \[\n(.*?)\n\]", src, re.S)
rows = [list(r) for r in re.findall(r'^\t"(.*)",$', m.group(1), re.M)]
W = max(len(r) for r in rows)
for r in rows:
    r.extend(" " * (W - len(r)))
paints = re.findall(r'"res://(assets/rooms/[^"]+)"', re.search(r"const PAINTS := \[(.*?)\]", src, re.S).group(1))
cover = {}
for p in paints:
    info = json.load(open(os.path.join(ROOT, p + ".json")))
    a, b, c, d, tx, ty = info["world_to_image"]
    al = np.asarray(Image.open(os.path.join(ROOT, p + ".png")))[:, :, 3]
    h, w = al.shape
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == " ":
                continue
            n = 0
            for ti, tj in ((i + .5, j + .5), (i + .25, j + .25), (i + .75, j + .75), (i + .25, j + .75), (i + .75, j + .25)):
                x, y = (ti - tj) * 128.0, (ti + tj) * 64.0
                X, Y = int(a * x + c * y + tx), int(b * x + d * y + ty)
                if 0 <= X < w and 0 <= Y < h and al[Y, X] > 128:
                    n += 1
            cover[(i, j)] = max(cover.get((i, j), 0), n)
walk = lambda ch: ch not in " PWMIRKOQU=x|"
get = lambda i, j: rows[j][i] if 0 <= j < len(rows) and 0 <= i < W else " "


def reachable():
    s = [(i, j) for j, r in enumerate(rows) for i, ch in enumerate(r) if ch == "S"][0]
    seen, st = {s}, [s]
    while st:
        i, j = st.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (i + di, j + dj)
            if n not in seen and walk(get(*n)):
                seen.add(n)
                st.append(n)
    return len(seen) == sum(1 for r in rows for ch in r if walk(ch))


bare = sorted(c for c, n in cover.items() if walk(get(*c)) and n < 3)
print("%d walkable cells not covered by a painting" % len(bare))
if trim:
    out = 0
    changed = True
    while changed:
        changed = False
        for (i, j) in bare:
            if get(i, j) not in ":.,w" or cover.get((i, j), 0) >= 3:
                continue
            if not any(get(i + di, j + dj) == " " for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            old = rows[j][i]
            rows[j][i] = " "
            if reachable():
                out += 1
                changed = True
            else:
                rows[j][i] = old
        bare = [c for c in bare if get(*c) != " "]
    new = "\n".join('\t"%s",' % "".join(r).rstrip() for r in rows)
    open(layout, "w").write(src[:m.start()] + "const MAP := [\n" + new + "\n]" + src[m.end():])
    print("trimmed %d rim cells; %d uncovered walkable cells left:" % (out, len(bare)), bare)
else:
    print(bare)
