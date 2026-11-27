"""Black out part of a room painting before importing it, so that part imports as abyss.

    python3 tools/rooms/clip_paint.py PAINTING GUIDE_JSON OUT POLYGON [POLYGON ...]

Each POLYGON is a list of layout cell points "i,j i,j ...", in the same coordinates as
the layout (corners of cells: "68,6" is the top corner of cell (68, 6)). Points may lie
far outside the frame. Everything inside a polygon is painted pure black; when it
touches the image border, import_room_paint.py keys it out.

Use it when
* two paintings overlap (room 4 has an upper and a lower painting): give each the part
  it owns, cut along an architectural edge such as a terrace's top edge, so the two
  never show different versions of the same spot;
* SOL paints stray bits of a neighbouring room into the frame.
"""
import json
import sys

from PIL import Image, ImageDraw


def to_image(m, i, j):
    x = (i - j) * 128.0
    y = (i + j) * 64.0
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


def main(painting, guide_json, out, polys):
    m = json.load(open(guide_json))["world_to_image"]
    im = Image.open(painting).convert("RGB")
    d = ImageDraw.Draw(im)
    for poly in polys:
        pts = [to_image(m, *map(float, p.split(","))) for p in poly.split()]
        d.polygon(pts, fill=(0, 0, 0))
    im.save(out)
    print("wrote", out)


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:])
