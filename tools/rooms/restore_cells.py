"""Copy back, from the original painting, the pixels of some cells (as prisms h m tall) onto a
band-clipped copy, so a painting can own a few cells outside its band (room 6 owns the corridor
from room 5). Usage:

    python3 tools/rooms/restore_cells.py ORIGINAL CLIPPED GUIDE_JSON OUT "i,j,h i,j,h ..."
"""
import json, sys
import numpy as np
from PIL import Image, ImageDraw
orig, clipped, guide, out = sys.argv[1:5]
cells = [(int(a), int(b), float(h)) for a, b, h in (c.split(',') for c in sys.argv[5].split())]
m = json.load(open(guide))['world_to_image']
def P(i, j, h=0.0):
    x = (i - j) * 128.0; y = (i + j) * 64.0 - h * 78.3837
    return (m[0] * x + m[4], m[3] * y + m[5])
def hull(pts):
    pts = sorted(set(pts))
    cr = lambda o, a, b: (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]
a = np.asarray(Image.open(orig).convert('RGB'))
b = np.asarray(Image.open(clipped).convert('RGB')).copy()
mask = Image.new('L', (a.shape[1], a.shape[0]), 0)
d = ImageDraw.Draw(mask)
for i, j, h in cells:
    cs = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
    d.polygon(hull([P(*c) for c in cs] + [P(*c, h) for c in cs]), fill=255)
k = np.asarray(mask) > 0
b[k] = a[k]
Image.fromarray(b).save(out)
print('restored', int(k.sum()), 'px')
