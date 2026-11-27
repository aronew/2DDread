"""Clip a room painting to the part of the map its room owns, before importing it.

    python3 tools/rooms/band_clip.py PAINTING GUIDE_JSON OUT I0 I1

Rooms in the temple dungeon run left to right, so a room owns a band of map columns
I0 <= i < I1 (all rows), cut through the middle of the corridors between rooms. The
paint guides frame a room with bits of its neighbours, and SOL paints those too; left in,
they would draw over the neighbour's own painting. Everything outside the band is
painted pure black (import_room_paint.py keys it out), except what stands on the band:
walls (as 6 m prisms), columns and props rise up the screen past the band's ground edge
and keep their painted height. Walls include the ones the game adds around rooms
(ENCLOSE), worked out from the layout the way Dungeon._enclose_floor does.
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WALL_H = 6.0          # metres: the tall walls; shorter ones just keep a little extra
PROP_H = 2.6
HPX_PER_M = 78.3837
NEIGH8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]


def _consts():
    src = open(os.path.join(ROOT, "src", "dungeon", "dungeon.gd")).read()

    def keys(name):
        m = re.search(r"const %s := \{([^}]*)\}" % name, src)
        return set(re.findall(r'"(.)"\s*:', m.group(1))) if m else set()
    return keys("WALL_CHAR"), keys("LOW_CHAR"), keys("PROP_CHAR")


def _map():
    src = open(os.path.join(ROOT, "src", "dungeon", "layout_temple.gd")).read()
    block = src[src.index("const MAP"):]
    block = block[:block.index("\n]")]
    return re.findall(r'^\t"(.*)",', block, re.M)


def walls_and_props():
    wall_ch, low_ch, prop_ch = _consts()
    rows = _map()
    cells = {}
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch != " ":
                cells[(i, j)] = ch
    walk = {c for c, ch in cells.items() if ch not in wall_ch and ch not in low_ch and ch != "_"}
    walls = {c for c, ch in cells.items() if ch in wall_ch}
    props = {c for c, ch in cells.items() if ch in prop_ch}

    def closed(c, d):
        for k in range(1, 9):
            n = (c[0] + d[0] * k, c[1] + d[1] * k)
            if n in cells:
                return cells[n] not in wall_ch
        return False

    for c in walk:
        for d in NEIGH8:
            n = (c[0] + d[0], c[1] + d[1])
            if n in cells:
                continue
            if all(closed(n, dd) for dd in [(1, 0), (-1, 0), (0, 1), (0, -1)]):
                continue   # a soul-fire pit
            walls.add(n)
    return walls, props


def to_image(m, i, j, h=0.0):
    x = (i - j) * 128.0
    y = (i + j) * 64.0 - h * HPX_PER_M
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


def hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def main(painting, guide_json, out, i0, i1):
    m = json.load(open(guide_json))["world_to_image"]
    im = Image.open(painting).convert("RGB")
    mask = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(mask)
    d.polygon([to_image(m, i0, -60), to_image(m, i1, -60), to_image(m, i1, 120), to_image(m, i0, 120)], fill=255)
    walls, props = walls_and_props()
    for cells, h in ((walls, WALL_H), (props, PROP_H)):
        for (i, j) in cells:
            if not (i0 <= i < i1):
                continue
            corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            pts = [to_image(m, a, b) for a, b in corners] + [to_image(m, a, b, h) for a, b in corners]
            d.polygon(hull(pts), fill=255)
    black = Image.new("RGB", im.size, (0, 0, 0))
    Image.composite(im, black, mask).save(out)
    print("wrote", out)


if __name__ == "__main__":
    if len(sys.argv) != 6:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]), float(sys.argv[5]))
