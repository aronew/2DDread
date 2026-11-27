"""Build the soul-fire pit textures from the owner's pit pack (kit_2026-11-27_pits).
Any python with pillow + numpy:

    python3 tools/blender/prep_pit_textures.py

pit_edge_i is a painted 2 m pit wall seen at roughly the game angle: capstones on top,
plain masonry below and green flames painted along its foot. This script unprojects
that wall face to a flat rectangle, then splits it in two:

  assets/sprites/env/pit_wall.png    masonry only: one clean course of the painting,
                                     repeated as two staggered courses, tiling both ways
  assets/sprites/env/pit_flames.png  the painted flames on transparency, tiling along x

PitFire draws both on the far walls of every pit at runtime, so the art keeps the
exact game camera at any pit size. The face isn't a perfect parallelogram (it was
generated, not rendered), so its top and bottom lines are measured separately.
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "textures", "kit_2026-11-27_pits")
OUT = os.path.join(HERE, "..", "..", "assets", "sprites", "env")

# pit_edge_i.webp: the masonry face below the capstones, measured on the image.
# top(x) / bottom(x) are the face's upper and lower lines; x spans the face.
FACE_X = (262.0, 1158.0)
FACE_TOP = (370.0, 0.517)      # y at x=500, slope
FACE_BOT = (722.0, 0.45)
RECT = (1024, 400)             # unprojected face size (px)
COURSE_ROWS = (4, 172)         # the one flame-free course (with its bottom joint)
JOINTS_X = (210, 900)          # vertical joints in that course: crop there so it tiles


def _bilinear(img, x, y):
    h, w = img.shape[:2]
    x0 = np.clip(np.floor(x).astype(int), 0, w - 2)
    y0 = np.clip(np.floor(y).astype(int), 0, h - 2)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    a, b = img[y0, x0], img[y0, x0 + 1]
    c, d = img[y0 + 1, x0], img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def unproject(src):
    ow, oh = RECT
    u = np.linspace(0.0, 1.0, ow)
    v = np.linspace(0.0, 1.0, oh)
    x = FACE_X[0] + u * (FACE_X[1] - FACE_X[0])
    top = FACE_TOP[0] + FACE_TOP[1] * (x - 500.0)
    bot = FACE_BOT[0] + FACE_BOT[1] * (x - 500.0)
    xx = np.repeat(x[None, :], oh, 0)
    yy = top[None, :] + v[:, None] * (bot - top)[None, :]
    return _bilinear(src, xx, yy)


def flame_mask(rect):
    r, g, b = rect[..., 0], rect[..., 1], rect[..., 2]
    lum = rect[..., :3].mean(-1)
    return np.clip((g - np.maximum(r, b) - 0.08) / 0.12, 0, 1) * np.clip((lum - 0.18) / 0.12, 0, 1)


# The two tall flame tongues reach into the clean course (their dim tips escape any
# colour mask): (x0, x1) columns in unprojected px, each patched over the course's full
# height from `shift` px along, where the stone has no joint and no flame.
PATCHES = ((300, 420, 200), (680, 795, -250))


def masonry(rect):
    """One course of the wall, flame tips patched from further along the same course,
    cropped at two vertical joints so it repeats, then stacked twice with the joints
    staggered by half a unit."""
    r0, r1 = COURSE_ROWS
    course = rect[r0:r1, :, :3].copy()
    for x0, x1, shift in PATCHES:
        w = np.clip(np.minimum(np.arange(x0, x1) - x0, x1 - 1 - np.arange(x0, x1)) / 18.0, 0, 1)[None, :, None]
        donor = course[:, x0 + shift:x1 + shift].copy()
        course[:, x0:x1] = course[:, x0:x1] * (1 - w) + donor * w
    j0, j1 = JOINTS_X
    unit = course[:, j0:j1]
    half = unit.shape[1] // 2
    tile = np.concatenate([unit, np.roll(unit, half, axis=1)], axis=0)
    return tile


def flames(rect, mask, fade=96):
    """The painted flames alone, faded into each other at the ends so they tile."""
    rgb = rect[..., :3]
    a = mask.copy()
    a[-24:] = np.maximum(a[-24:], np.linspace(0.6, 1.0, 24)[:, None])  # solid base, it meets the glow bed
    out = np.dstack([rgb, a])
    w = out.shape[1]
    t = np.linspace(0.0, 1.0, fade)[None, :, None]
    head, tail = out[:, :fade], out[:, w - fade:]
    blended = tail * (1 - t) + head * t
    out = out[:, fade:w].copy()
    out[:, -fade:] = blended
    # colour under faint alpha comes from the wall; take it from the flame body instead
    body = out[..., 3:4] > 0.35
    mean_flame = (out[..., :3] * body).sum((0, 1)) / max(1, body.sum())
    weak = out[..., 3:4] < 0.35
    out[..., :3] = np.where(weak, np.maximum(out[..., :3], mean_flame * 0.85), out[..., :3])
    return out


def save(arr, name, size=None):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    if size:
        im = im.resize(size, Image.LANCZOS)
    path = os.path.join(OUT, name)
    im.save(path)
    print("wrote", os.path.relpath(path, os.path.join(HERE, "..", "..")), im.size)


if __name__ == "__main__":
    src = np.asarray(Image.open(os.path.join(KIT, "pit_edge_i.webp")).convert("RGBA")).astype(np.float32) / 255.0
    rect = unproject(src)
    mask = flame_mask(rect)
    wall = masonry(rect)
    save(wall, "pit_wall.png", (512, int(round(512 * wall.shape[0] / wall.shape[1]))))
    save(flames(rect, mask), "pit_flames.png", (1024, 400))
