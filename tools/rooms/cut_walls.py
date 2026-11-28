"""Cut a doorway through a painted wall: black out the walls painted on some cells (as
prisms H m tall, so their upright part goes too, not just their ground cell), minus the
prisms of walls standing in front of them, which stay. Used when a new room's corridor
opens through a room painting's enclosing wall (rooms 5 and 6).

    python3 tools/rooms/cut_walls.py PAINTING GUIDE_JSON OUT H "i,j i,j ..." ["i,j ..." keep]
"""
import json, sys
from PIL import Image, ImageDraw
import numpy as np
painting, guide, out, H = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
cut = [tuple(map(int, c.split(','))) for c in sys.argv[5].split()]
keep = [tuple(map(int, c.split(','))) for c in sys.argv[6].split()] if len(sys.argv) > 6 else []
m = json.load(open(guide))['world_to_image']
HPX = 78.3837
def P(i, j, h=0.0):
    x = (i - j) * 128.0; y = (i + j) * 64.0 - h * HPX
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])
def hull(pts):
    pts = sorted(set(pts))
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]
def prism(i, j, h):
    corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
    return hull([P(a, b) for a, b in corners] + [P(a, b, h) for a, b in corners])
im = Image.open(painting).convert('RGB')
mask = Image.new('L', im.size, 0)
d = ImageDraw.Draw(mask)
for c in cut:
    d.polygon(prism(c[0], c[1], H), fill=255)
for c in keep:
    d.polygon(prism(c[0], c[1], 6.0), fill=0)
a = np.asarray(im).copy()
a[np.asarray(mask) > 0] = 0
Image.fromarray(a).save(out)
print('cut', int((np.asarray(mask) > 0).sum()), 'px')
