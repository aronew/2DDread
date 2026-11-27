"""Prepare painted source textures for the Blender kit (run with the bpy venv's python,
or any python with pillow + numpy). Writes processed copies next to the other textures
in tools/blender/textures/; the sources stay untouched.

    python tools/blender/prep_textures.py

cool() makes greyer copies of the worn and damaged slabs (slab_*_cool.png) for the
temple floor, which the soul-fire mockup paints as grey stone rather than olive.

Large-slab floors: each 2 m square holds the same 3x3 slabs, so the light/dark slabs
repeat as a checkerboard across a room. calm_slabs() keeps the painting, grout and
cracks but pulls every slab's average colour and brightness toward the floor's mean,
then blends the edges so the image repeats without a visible line.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "textures")
SLABS = os.path.join(TEX, "kit_2026-11-27", "textures_large_slabs")


def make_seamless(a, margin=28):
    """Nudge the outer `margin` pixels so opposite edges meet: each edge is pulled to the
    average of itself and the opposite edge, fading out inward. Generated textures are
    almost seamless, and on calm slabs even a small mismatch shows as a line per tile."""
    a = a.copy()
    w = (1.0 - np.arange(margin) / margin)[:, None] ** 2

    def smooth(v):  # soften the per-pixel correction along the edge so it can't streak
        k = np.exp(-0.5 * (np.arange(-6, 7) / 3.0) ** 2)
        k /= k.sum()
        return np.stack([np.convolve(np.pad(v[:, c], 6, mode="wrap"), k, mode="valid") for c in range(v.shape[1])], 1)

    for _ in range(2):  # columns, then rows (transpose and back)
        first, last = a[:, 0], a[:, -1]
        mid = (first + last) * 0.5
        d0, d1 = smooth(mid - first), smooth(mid - last)
        a[:, :margin] += d0[:, None, :] * w[None, :, :].transpose(0, 1, 2)
        a[:, -margin:] += (d1[:, None, :] * w[None, :, :])[:, ::-1]
        a = a.transpose(1, 0, 2)
    return a


def calm_slabs(src, dst, keep=0.15, blur=60):
    im = Image.open(src).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    # slab-scale colour: blur wide enough to average a slab, but not across the image
    low = np.asarray(im.filter(ImageFilter.GaussianBlur(blur))).astype(np.float32)
    mean = a.reshape(-1, 3).mean(0)
    out = a - (low - mean) * (1.0 - keep)   # keep only `keep` of each slab's offset from the mean
    out = make_seamless(out)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)
    print("wrote", os.path.relpath(dst, HERE))


def cool(src, dst, sat=0.5, tint=(0.97, 1.0, 1.06), joints=True):
    """The mockup's floor is grey stone with a hint of green, where the kit's slabs are
    yellow-olive: keep the paint, halve its saturation and cool it slightly.
    joints: the mockup's slabs have bold dark joints, while the kit's are hairlines that
    vanish once a 2 m tile shrinks to ~230 px on screen. Pixels clearly darker than their
    surroundings (the joints and cracks) are widened and darkened."""
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    lum = (a * np.array([0.3, 0.59, 0.11])).sum(-1, keepdims=True)
    out = (lum + (a - lum) * sat) * np.array(tint)
    if joints:
        l = out.mean(-1)
        local = np.asarray(Image.fromarray(np.clip(l, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)))
        dark = ((l - local.astype(np.float32)) < -5).astype(np.uint8) * 255
        m = Image.fromarray(dark).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
        out = out * (1.0 - np.asarray(m).astype(np.float32)[..., None] / 255.0 * 0.6)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(dst)
    print("wrote", os.path.relpath(dst, HERE))


# The kit's painted hooded-relief wall module (the mockup's mural): its front face, from
# just above the upper Greek-key band to below the lower one, between the side arches.
# Corner lines measured on the 1448x1086 image: x range, then (y at x0, y at x1) for the
# top and bottom lines. Generated art, so not a perfect parallelogram; close enough.
HOODED = {"x": (495.0, 1065.0), "top": (435.0, 170.0), "bot": (1010.0, 740.0)}


def unproject_relief(src, dst, out_w=640, out_h=752):
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    u = np.linspace(0.0, 1.0, out_w)
    v = np.linspace(0.0, 1.0, out_h)
    x0, x1 = HOODED["x"]
    x = x0 + u * (x1 - x0)
    top = HOODED["top"][0] + u * (HOODED["top"][1] - HOODED["top"][0])
    bot = HOODED["bot"][0] + u * (HOODED["bot"][1] - HOODED["bot"][0])
    xx = np.repeat(x[None, :], out_h, 0)
    yy = top[None, :] + v[:, None] * (bot - top)[None, :]
    xi = np.clip(np.floor(xx).astype(int), 0, w - 2)
    yi = np.clip(np.floor(yy).astype(int), 0, h - 2)
    fx = (xx - xi)[..., None]
    fy = (yy - yi)[..., None]
    out = (a[yi, xi] * (1 - fx) + a[yi, xi + 1] * fx) * (1 - fy) + (a[yi + 1, xi] * (1 - fx) + a[yi + 1, xi + 1] * fx) * fy
    Image.fromarray(np.clip(out[..., :3], 0, 255).astype(np.uint8)).save(dst)
    print("wrote", os.path.relpath(dst, HERE))


if __name__ == "__main__":
    for name in ("floor_worn", "floor_damaged", "floor_moss_bones"):
        src = os.path.join(SLABS, name + ".png")
        if os.path.exists(src):
            calm_slabs(src, os.path.join(TEX, "slab_" + name.replace("floor_", "") + ".png"))
    for name in ("worn", "damaged"):
        src = os.path.join(TEX, "slab_%s.png" % name)
        if os.path.exists(src):
            cool(src, os.path.join(TEX, "slab_%s_cool.png" % name))
    src = os.path.join(TEX, "slab_worn.png")
    if os.path.exists(src):   # for the pit capstones: same paint, no joints drawn across them
        cool(src, os.path.join(TEX, "slab_worn_cool_plain.png"), joints=False)
    # moss stays green, but loses the yellow cast that made it read as a warm patch
    src = os.path.join(TEX, "slab_moss_bones.png")
    if os.path.exists(src):
        cool(src, os.path.join(TEX, "slab_moss_bones_cool.png"), sat=0.75, tint=(0.9, 1.0, 0.96))
    src = os.path.join(TEX, "kit_2026-11-27", "modules", "wall_hooded_relief.png")
    if os.path.exists(src):
        unproject_relief(src, os.path.join(TEX, "wall_hooded_panel.png"))
