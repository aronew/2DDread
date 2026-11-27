"""Import the owner's painted prop sprites (tools/blender/textures/kit_2026-11-27/sprites)
into the game's prop sheets (assets/sprites/props/<name>). Needs pillow + numpy; run with
the bpy venv's python, then `godot --headless --path . --import`.

    python tools/blender/import_painted_props.py

Each painted master is a large canvas with transparent background. It is cropped to its
silhouette, scaled so its real-world size matches the game projection (1 m of height =
59.87 px, a w x d m footprint spans (w + d) * 64 px across), and given a base-centre
origin. Flames and glowing cracks come from the kit's glow-mask drafts, which share the
sprite's canvas; they are clipped to the sprite's silhouette. The painted props are
already shaded, so they ship without a normal map (lights still brighten them, flat).

To use the Blender-modelled props again, run build_env.py -- props.
"""
import json
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "textures", "kit_2026-11-27")
OUT = os.path.join(HERE, "..", "..", "assets", "sprites", "props")

K = 0.5               # sin of camera pitch (matches Iso.K)
PX_M = 78.38          # screen px per metre of height
FOOT = 64.0           # screen px across per metre of footprint (w + d)
PAD = 4

# game sheet: ([painted frames], glow-mask draft or None, height m incl. flames, footprint w, d)
PROPS = {
    "crate": (["amphorae_pair"], None, 1.0, 1.0, 1.0),           # amphorae: break into supplies
    "canisters": (["candle_cluster"], "candles", 0.9, 0.6, 0.5),
    "barrel": (["fire_urn"], "fire_urn", 1.15, 0.7, 0.7),          # explosive urn
    "chest": (["chest_closed", "chest_open"], None, 0.75, 1.2, 0.7),
    "crystals": (["soul_brazier"], "brazier", 1.1, 0.8, 0.8),      # soul brazier
    "pylon": (["candelabra"], "candelabra", 1.3, 0.6, 0.6),
    "cryotube": (["broken_statue"], None, 1.5, 0.9, 0.9),          # broken statue
    "eggs": (["bone_nest_empty", "bone_nest_active"], ["bone_nest", 1], 0.45, 1.3, 1.1),  # nest; frame 1 = active
}


def load(name, folder="sprites"):
    return np.asarray(Image.open(os.path.join(KIT, folder, name + ".png")).convert("RGBA")).astype(np.float32)


def bbox(alpha):
    ys, xs = np.where(alpha > 16)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def resize(rgba, scale):
    """Premultiplied resample, so transparent pixels never bleed colour into edges."""
    h, w = rgba.shape[:2]
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    a = rgba[..., 3:4] / 255.0
    pm = Image.fromarray(np.clip(rgba[..., :3] * a, 0, 255).astype(np.uint8)).resize(size, Image.LANCZOS)
    al = Image.fromarray(rgba[..., 3].astype(np.uint8)).resize(size, Image.LANCZOS)
    pm = np.asarray(pm).astype(np.float32)
    al = np.asarray(al).astype(np.float32)
    rgb = np.where(al[..., None] > 0, pm / np.maximum(al[..., None] / 255.0, 1e-3), 0)
    return np.dstack([np.clip(rgb, 0, 255), al])


def bleed(arr, rings=3):
    rgb = arr[..., :3].copy()
    filled = arr[..., 3] >= 200
    for _ in range(rings):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(filled.shape, np.float32)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.roll(filled, d, (0, 1))
            acc += np.roll(rgb, d, (0, 1)) * m[..., None]
            cnt += m
        grow = (~filled) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        filled |= grow
    out = arr.copy()
    keep = (arr[..., 3] < 200) & filled
    out[..., :3] = np.where(keep[..., None], rgb, arr[..., :3])
    return out


def build(sheet, frames, glow, h_m, w_m, d_m):
    masters = [load(f) for f in frames]
    x0, y0, x1, y1 = bbox(masters[0][..., 3])
    # match the silhouette's height to the projected height (object + footprint depth)
    want_h = h_m * PX_M + (w_m + d_m) * FOOT * K
    scale = want_h / (y1 - y0)
    glow_name, glow_frame = (glow, 0) if isinstance(glow, str) else (glow or [None, None])
    crops = []
    for k, m in enumerate(masters):
        bx = bbox(m[..., 3])
        c = m[bx[1]:bx[3], bx[0]:bx[2]]
        e = None
        if glow_name and k == glow_frame:
            g = load(glow_name + "_emission", "emission_drafts")[..., :3]
            e = g[bx[1]:bx[3], bx[0]:bx[2]] * (c[..., 3:4] / 255.0)   # clip to the silhouette
        # the base centre: middle of the bottom fifth of the silhouette (so an open lid or a
        # leaning amphora doesn't shift it), half the footprint's depth above its bottom
        low = c[int((bx[3] - bx[1]) * 0.8):, :, 3] > 128
        ox = float(np.where(low)[1].mean())
        oy = (bx[3] - bx[1]) - (w_m + d_m) * FOOT * K * 0.5 / scale
        crops.append((c, e, ox, oy))
    # common frame: every frame is placed so its origin lands on the same pixel
    lefts = [ox * scale for c, e, ox, oy in crops]
    rights = [(c.shape[1] - ox) * scale for c, e, ox, oy in crops]
    tops = [oy * scale for c, e, ox, oy in crops]
    bottoms = [(c.shape[0] - oy) * scale for c, e, ox, oy in crops]
    org = (int(np.ceil(max(lefts))) + PAD, int(np.ceil(max(tops))) + PAD)
    fw = org[0] + int(np.ceil(max(rights))) + PAD
    fh = org[1] + int(np.ceil(max(bottoms))) + PAD
    col = np.zeros((fh, fw * len(crops), 4), np.float32)
    emi = np.zeros((fh, fw * len(crops), 3), np.float32)
    has_emit = False
    for k, (c, e, ox, oy) in enumerate(crops):
        rc = resize(c, scale)
        px = k * fw + org[0] - int(round(ox * scale))
        py = org[1] - int(round(oy * scale))
        hh, ww = rc.shape[:2]
        col[py:py + hh, px:px + ww] = rc
        if e is not None:
            re = np.asarray(Image.fromarray(np.clip(e, 0, 255).astype(np.uint8)).resize((ww, hh), Image.LANCZOS)).astype(np.float32)
            emi[py:py + hh, px:px + ww] = re
            has_emit = True
    col = bleed(col)
    files = {"color": sheet + "_c.png"}
    Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, files["color"]), optimize=True)
    if has_emit:
        files["emit"] = sheet + "_e.png"
        Image.fromarray(np.clip(emi, 0, 255).astype(np.uint8), "RGB").save(os.path.join(OUT, files["emit"]), optimize=True)
    for stale in ("_n.png", "_n.png.import") + (() if has_emit else ("_e.png", "_e.png.import")):
        p = os.path.join(OUT, sheet + stale)
        if os.path.exists(p):
            os.remove(p)
    meta = {"name": sheet, "frame_w": fw, "frame_h": fh, "origin": list(org), "rows": 1, "cols": len(crops),
            "files": files, "source": "painted: textures/kit_2026-11-27/sprites/" + ", ".join(frames)}
    with open(os.path.join(OUT, sheet + ".json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("%-10s %3dx%-3d origin %s  frames %d  glow %s  (scale %.3f)" % (sheet, fw, fh, org, len(crops), has_emit, scale))


if __name__ == "__main__":
    for name, spec in PROPS.items():
        build(name, *spec)
