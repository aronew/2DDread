"""Textures for terrace drops and stairs (src/dungeon/terrace.gd), cut from the painted kit
textures in tools/blender/textures. Plain python (pillow + numpy):

    python3 tools/rooms/prep_terrace_textures.py

assets/sprites/env/terrace_face_1.png, terrace_face_2.png
    The face of a one- or two-level drop (1.633 m / 3.267 m tall, 2 m wide, tiling along
    x): wall_ashlar.png's gold Greek-key band just under the lip, green ashlar courses
    below it and its dark plinth at the foot. The courses are resampled to fit the height
    exactly, so the plinth always meets the lower floor.
assets/sprites/env/stair_tread.png
    The cool grey slab floor (slab_worn_cool.png, 2 m per repeat) for stair treads and
    risers; Terrace shades risers darker.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
TEX = os.path.join(ROOT, "tools", "blender", "textures")
OUT = os.path.join(ROOT, "assets", "sprites", "env")

PX_M = 128                 # output resolution: px per metre (the game shows ~78 at zoom 1)
LEVEL_M = 128.0 / 78.3837  # one level of drop: 128 screen px, one cell of depth
SRC_M = 512                # wall_ashlar.png: 1024 x 1536 px for 2 m x 3 m

# rows of wall_ashlar.png (measured): the band with the course under it, the repeating
# ashlar courses, and the plinth at the foot
TOP = (248, 692)
COURSES = (692, 1216)
PLINTH = (1392, 1536)


def rows(a, r0, r1, h):
    """Rows r0..r1 of a resampled to h px tall and the output width."""
    im = Image.fromarray(a[r0:r1])
    return np.asarray(im.resize((2 * PX_M, max(1, int(round(h)))), Image.LANCZOS))


def face(levels):
    src = np.asarray(Image.open(os.path.join(TEX, "wall_ashlar.png")).convert("RGB"))
    total = levels * LEVEL_M * PX_M
    top_h = (TOP[1] - TOP[0]) / SRC_M * PX_M
    plinth_h = (PLINTH[1] - PLINTH[0]) / SRC_M * PX_M * 0.8
    if levels <= 1:
        top_h *= 0.8                       # a short drop keeps the band and one course
    mid = total - top_h - plinth_h
    course_h = (COURSES[1] - COURSES[0]) / SRC_M * PX_M
    n = max(1, int(round(mid / course_h)))
    parts = [rows(src, TOP[0], TOP[1], top_h)]
    for k in range(n):
        parts.append(rows(src, COURSES[0], COURSES[1], mid / n))
    parts.append(rows(src, PLINTH[0], PLINTH[1], plinth_h))
    out = np.concatenate(parts, 0)
    out = np.asarray(Image.fromarray(out).resize((2 * PX_M, int(round(total))), Image.LANCZOS))
    Image.fromarray(out).save(os.path.join(OUT, "terrace_face_%d.png" % levels), optimize=True)
    print("terrace_face_%d.png" % levels, out.shape[1], "x", out.shape[0])


def tread():
    src = Image.open(os.path.join(TEX, "slab_worn_cool.png")).convert("RGB")
    out = src.resize((2 * PX_M, 2 * PX_M), Image.LANCZOS)
    out.save(os.path.join(OUT, "stair_tread.png"), optimize=True)
    print("stair_tread.png", out.size)


if __name__ == "__main__":
    face(1)
    face(2)
    tread()
