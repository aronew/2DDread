"""Draw the layout's cell grid, cell coordinates and props over a painting, to read where
painted features sit in map cells (e.g. to move prop letters or sinkholes to match).

python3 tools/rooms/grid_overlay.py PAINTING GUIDE_JSON LAYOUT_GD OUT [scale]
Each floor cell gets a thin diamond and "i,j"; layout walls/props are marked in yellow
with their letter; layout void cells inside the frame get a blue cross.
"""
import json, re, sys
from PIL import Image, ImageDraw

paint, guide, layout, out = sys.argv[1:5]
scale = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0
g = json.load(open(guide))
a, b, c, d, tx, ty = g["world_to_image"]
rows = re.findall(r'^\t"(.*)",$', re.search(r"const MAP := \[(.*?)\n\]", open(layout).read(), re.S).group(1), re.M)
im = Image.open(paint).convert("RGB")
dr = ImageDraw.Draw(im)


def img(i, j):
    x, y = (i - j) * 128.0, (i + j) * 64.0
    return (a * x + c * y + tx, b * x + d * y + ty)


W, H = im.size
for j, row in enumerate(rows):
    for i, ch in enumerate(row):
        cx, cy = img(i + 0.5, j + 0.5)
        if not (-20 < cx < W + 20 and -20 < cy < H + 20):
            continue
        if ch == " ":
            continue
        pts = [img(i, j), img(i + 1, j), img(i + 1, j + 1), img(i, j + 1)]
        dr.polygon(pts, outline=(90, 200, 255))
        if ch not in ":.":
            dr.text((cx - 4, cy - 14), ch, fill=(255, 230, 0))
        dr.text((cx - 12, cy - 4), "%d,%d" % (i, j), fill=(255, 255, 255))
if scale != 1.0:
    im = im.resize((int(W * scale), int(H * scale)))
im.save(out)
print("wrote", out)
