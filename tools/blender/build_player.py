"""Player: the gunslinger, rendered as two ink/cel-shaded layers.

legs   : 16 movement directions x (8 run frames + 1 idle)  -- drawn first
torso  : 32 aim directions per weapon (rifle=twin revolvers, shotgun=blunderbuss,
         arc=stormcaller, rail=longshot)                      -- drawn on top

Both layers share the same origin (feet) so they composite exactly.
"""
import math
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

LEG_DIRS = 16
RUN_FRAMES = 8
TORSO_DIRS = 32

LEGS_FRAME = (160, 160, (80, 112))
TORSO_FRAME = (240, 216, (120, 186))


def materials():
    return {
        "coat": C.mat("p_coat", (0.17, 0.055, 0.075), rough=0.75),
        "lining": C.mat("p_lining", (0.72, 0.05, 0.06), rough=0.6),
        "scarf": C.mat("p_scarf", (0.82, 0.07, 0.07), rough=0.65),
        "leather": C.mat("p_leather", (0.34, 0.16, 0.07), rough=0.55),
        "cloth": C.mat("p_cloth", (0.09, 0.08, 0.11), rough=0.85),
        "gold": C.mat("p_gold", (0.95, 0.66, 0.22), metal=1.0, rough=0.25),
        "steel": C.mat("p_steel", (0.5, 0.52, 0.56), metal=0.9, rough=0.3),
        "dark": C.mat("p_dark", (0.09, 0.085, 0.1), metal=0.4, rough=0.45),
        "skin": C.mat("p_skin", (0.86, 0.63, 0.5), rough=0.6),
        "hat": C.mat("p_hat", (0.06, 0.045, 0.05), rough=0.7),
        "wood": C.mat("p_wood", (0.38, 0.18, 0.08), rough=0.6),
        "brass": C.mat("p_brass", (0.6, 0.38, 0.13), metal=1.0, rough=0.3),
        "copper": C.mat("p_copper", (0.75, 0.32, 0.14), metal=1.0, rough=0.3),
        "cyan": C.mat("p_cyan", (0.2, 0.8, 0.95), emit=(0.35, 0.95, 1.0), emit_strength=6.0),
        "rune": C.mat("p_rune", (0.9, 0.15, 0.1), emit=(1.0, 0.25, 0.12), emit_strength=6.0),
    }


# ---------------------------------------------------------------- legs

def build_legs(M):
    root = C.empty("legs_root")
    pelvis = C.empty("pelvis", (0, 0, 0.95), root)
    C.box((0.24, 0.36, 0.2), (0, 0, 0.02), M["cloth"], pelvis, bevel=0.05)
    C.box((0.27, 0.4, 0.08), (0, 0, 0.12), M["leather"], pelvis, bevel=0.025)  # belt
    C.box((0.04, 0.12, 0.09), (0.14, 0, 0.12), M["gold"], pelvis, bevel=0.015)  # buckle
    C.box((0.16, 0.08, 0.2), (0.04, -0.21, -0.06), M["leather"], pelvis, bevel=0.03)  # holster
    # long coat tails: back pair + side flaps, hinged at the belt so they swing
    tails = []
    for (x, y, rz, w) in ((-0.12, 0.1, 0.2, 0.22), (-0.12, -0.1, -0.2, 0.22)):
        h = C.empty("tail", (x, y, 0.1), pelvis)
        h["base"] = (0.0, 0.0, rz)
        C.wedge((0.04, w, 0.62), (0, 0, -0.31), M["coat"], h, taper=(1.0, 0.8), bevel=0.012)
        h.rotation_euler = (0, 0, rz)
        tails.append(h)
    legs = {}
    for side, s in (("L", 1), ("R", -1)):
        hip = C.empty("hip" + side, (0, 0.11 * s, -0.02), pelvis)
        C.wedge((0.19, 0.17, 0.44), (0, 0, -0.22), M["cloth"], hip, taper=(1.18, 1.12))
        knee = C.empty("knee" + side, (0, 0, -0.44), hip)
        C.sphere(0.085, (0.02, 0, 0), M["cloth"], knee, segs=12)
        C.wedge((0.16, 0.15, 0.4), (0, 0, -0.2), M["cloth"], knee, taper=(1.15, 1.1))
        C.cyl(0.095, 0.3, (0.0, 0, -0.27), M["leather"], knee, verts=14, bevel=0.01)  # tall boot
        C.cyl(0.1, 0.05, (0.0, 0, -0.12), M["leather"], knee, verts=14, bevel=0.01, r2=0.11)  # boot cuff
        C.box((0.03, 0.06, 0.04), (0.09, 0, -0.22), M["gold"], knee, bevel=0.008)  # buckle
        ankle = C.empty("ankle" + side, (0, 0, -0.42), knee)
        C.box((0.3, 0.14, 0.1), (0.05, 0, -0.04), M["leather"], ankle, bevel=0.035)
        C.box((0.12, 0.15, 0.05), (-0.06, 0, -0.08), M["dark"], ankle, bevel=0.015)  # heel
        legs[side] = (hip, knee, ankle)
    return root, pelvis, legs, tails


def pose_legs(pelvis, legs, phase, idle=False, tails=()):
    """phase 0..1 run cycle. Returns pelvis bob (metres)."""
    p = phase * 2 * math.pi
    if idle:
        for side, (hip, knee, ankle) in legs.items():
            s = 1 if side == "L" else -1
            hip.rotation_euler = (0.05 * s, -0.1 if side == "L" else 0.12, 0)
            knee.rotation_euler = (0, 0.2, 0)
            ankle.rotation_euler = (0, -0.1, 0)
        pelvis.location.z = 0.93
        pelvis.rotation_euler = (0, 0.03, 0)
        for t in tails:
            t.rotation_euler = t["base"]
        return -0.02
    bob = 0.035 * math.cos(2 * p)
    for side, (hip, knee, ankle) in legs.items():
        q = p if side == "L" else p + math.pi
        swing = 0.66 * math.sin(q)
        kb = 0.2 + 1.2 * max(0.0, math.cos(q)) ** 1.4
        hip.rotation_euler = (0, -swing, 0)
        knee.rotation_euler = (0, kb, 0)
        ankle.rotation_euler = (0, -(kb - swing) * 0.55 + 0.05, 0)
    pelvis.location.z = 0.93 + bob
    pelvis.rotation_euler = (0, 0.12, 0.06 * math.sin(p))
    # coat tails stream behind and flap with the stride
    for i, t in enumerate(tails):
        b = t["base"]
        flap = 0.12 * math.sin(p * 2 + i)
        t.rotation_euler = (b[0] + flap * (1 if i % 2 else -1) * 0.4, 0.35 + flap, b[2])
    return bob


# ---------------------------------------------------------------- torso + weapons

def build_torso(M):
    root = C.empty("torso_root")
    t = C.empty("torso", (0, 0, 1.0), root)
    C.wedge((0.24, 0.32, 0.26), (0, 0, 0.12), M["coat"], t, taper=(1.12, 1.2))
    C.wedge((0.32, 0.48, 0.4), (0.0, 0, 0.42), M["coat"], t, taper=(0.85, 0.82), bevel=0.05)
    # lapels (red lining) + waistcoat
    for s in (-1, 1):
        C.box((0.03, 0.12, 0.34), (0.155, 0.08 * s, 0.42), M["lining"], t, bevel=0.01, rot=(0.25 * s, 0.12, 0))
    C.box((0.02, 0.12, 0.3), (0.16, 0, 0.36), M["cloth"], t, bevel=0.01)
    for z in (0.28, 0.36, 0.44):
        C.sphere(0.018, (0.175, 0, z), M["gold"], t, segs=8)
    # left pauldron (leather + gold rim)
    C.sphere(0.14, (0.0, 0.27, 0.6), M["leather"], t, scale=(1.15, 1.0, 0.7))
    C.torus(0.12, 0.014, (0.0, 0.27, 0.6), M["gold"], t, rot=(0.3, 0, 0), seg=20, mseg=6)
    C.sphere(0.11, (0.0, -0.27, 0.58), M["coat"], t, scale=(1.1, 1.0, 0.8))
    # scarf wrap + tails flowing back
    C.torus(0.12, 0.05, (0.0, 0, 0.66), M["scarf"], t, seg=20, mseg=8)
    C.box((0.08, 0.16, 0.1), (0.1, 0, 0.62), M["scarf"], t, bevel=0.03)
    for i, y in enumerate((0.05, -0.05)):
        pts = [Vector((-0.08, y, 0.66)), Vector((-0.2, y * 1.6, 0.58)), Vector((-0.32, y * 2.4, 0.46 - i * 0.04)),
               Vector((-0.42, y * 3.2, 0.3 - i * 0.08))]
        _ribbon(pts, 0.1 - i * 0.015, M["scarf"], t)
    # head: masked by the scarf, eyes in the hat's shadow
    h = C.empty("head", (0.03, 0, 0.82), t)
    C.sphere(0.12, (0, 0, 0), M["skin"], h, scale=(1.05, 0.95, 1.1))
    C.box((0.16, 0.2, 0.1), (0.04, 0, -0.06), M["scarf"], h, bevel=0.04)  # face mask
    C.box((0.02, 0.15, 0.025), (0.12, 0, 0.03), M["dark"], h, bevel=0.0)  # eye shadow line
    # wide-brim hat
    hat = C.empty("hat", (0.0, 0, 0.1), h, rot=(0, 0.12, 0))
    C.cyl(0.32, 0.03, (0, 0, 0), M["hat"], hat, verts=28, bevel=0.012)
    C.cyl(0.14, 0.16, (0, 0, 0.09), M["hat"], hat, verts=20, r2=0.12, bevel=0.02)
    C.cyl(0.143, 0.04, (0, 0, 0.04), M["lining"], hat, verts=20, bevel=0.0)
    C.sphere(0.03, (0.13, 0.05, 0.05), M["gold"], hat, segs=8)
    return root, t


def _ribbon(pts, width, mat, parent):
    """Connected flat strip through pts (scarf tails)."""
    for a, b in zip(pts[:-1], pts[1:]):
        d = b - a
        C.box((width, 0.022, d.length + 0.03), (a + b) / 2, mat, parent, bevel=0.006,
              rot=d.to_track_quat("Z", "X").to_euler())
        C.sphere(width * 0.5, b, mat, parent, scale=(1.0, 0.25, 1.0), segs=10)


def _revolver(M, parent, at, name):
    g = C.empty(name, at, parent)
    C.box((0.2, 0.05, 0.07), (0.08, 0, 0.02), M["dark"], g, bevel=0.012)       # frame
    C.cyl(0.042, 0.07, (0.05, 0, 0.03), M["brass"], g, rot=(0, math.pi / 2, 0), verts=12)  # drum
    C.cyl(0.022, 0.26, (0.24, 0, 0.045), M["brass"], g, rot=(0, math.pi / 2, 0), verts=10)  # barrel
    C.box((0.02, 0.03, 0.03), (0.35, 0, 0.075), M["gold"], g, bevel=0.0)       # sight
    C.box((0.09, 0.045, 0.13), (-0.03, 0, -0.06), M["wood"], g, bevel=0.015, rot=(0, -0.35, 0))  # grip
    return g


def build_weapon(kind, M, parent):
    """Returns (muzzle, right_hand, left_hand, group[, muzzle2]) in torso space."""
    if kind == "rifle":  # twin revolvers, both arms extended
        r = _revolver(M, parent, (0.46, -0.17, 0.3), "gunR")
        l = _revolver(M, parent, (0.44, 0.17, 0.32), "gunL")
        muzzle = Vector((0.83, -0.17, 0.345))
        muzzle2 = Vector((0.81, 0.17, 0.365))
        return muzzle, Vector((0.43, -0.17, 0.27)), Vector((0.41, 0.17, 0.29)), r, muzzle2
    g = C.empty("gun_" + kind, (0, -0.12, 0.3), parent)
    if kind == "shotgun":  # blunderbuss
        C.box((0.42, 0.07, 0.09), (0.12, 0, -0.01), M["wood"], g, bevel=0.025)
        C.cyl(0.045, 0.5, (0.55, 0, 0.03), M["brass"], g, rot=(0, math.pi / 2, 0), verts=14, r2=0.075)
        C.torus(0.07, 0.015, (0.8, 0, 0.03), M["gold"], g, rot=(0, math.pi / 2, 0), seg=16, mseg=6)
        C.box((0.1, 0.08, 0.06), (0.3, 0, 0.05), M["dark"], g, bevel=0.015)
        C.box((0.22, 0.06, 0.11), (-0.12, 0, -0.06), M["wood"], g, bevel=0.03, rot=(0, -0.25, 0))
        muzzle, rh, lh = (0.84, 0, 0.03), (0.1, 0, -0.05), (0.5, 0, -0.02)
    elif kind == "arc":  # stormcaller
        C.box((0.44, 0.09, 0.11), (0.2, 0, 0), M["dark"], g, bevel=0.025)
        C.cyl(0.05, 0.34, (0.48, 0, 0.02), M["copper"], g, rot=(0, math.pi / 2, 0), verts=14)
        for i in range(3):
            C.torus(0.07, 0.016, (0.38 + i * 0.1, 0, 0.02), M["copper"], g, rot=(0, math.pi / 2, 0), seg=16, mseg=6)
        for s in (-1, 1):
            C.box((0.2, 0.02, 0.025), (0.74, 0.045 * s, 0.02), M["gold"], g, bevel=0.005, rot=(0, 0, -0.18 * s))
        C.sphere(0.05, (0.82, 0, 0.02), M["cyan"], g, segs=12, scale=(1.3, 0.9, 0.9))
        C.box((0.18, 0.06, 0.1), (-0.06, 0, -0.03), M["wood"], g, bevel=0.025)
        muzzle, rh, lh = (0.86, 0, 0.02), (0.12, 0, -0.06), (0.44, 0, -0.07)
    else:  # rail -> longshot
        C.box((0.72, 0.06, 0.08), (0.34, 0, 0), M["wood"], g, bevel=0.02)
        C.cyl(0.024, 0.6, (0.82, 0, 0.03), M["dark"], g, rot=(0, math.pi / 2, 0), verts=10)
        C.box((0.5, 0.012, 0.018), (0.5, 0.032, 0.025), M["rune"], g, bevel=0.0)
        C.cyl(0.035, 0.24, (0.32, 0, 0.1), M["brass"], g, rot=(0, math.pi / 2, 0), verts=12)
        for x in (0.2, 0.62, 1.0):
            C.cyl(0.03, 0.03, (x, 0, 0.03), M["gold"], g, rot=(0, math.pi / 2, 0), verts=10)
        C.box((0.24, 0.06, 0.12), (-0.08, 0, -0.04), M["wood"], g, bevel=0.03)
        muzzle, rh, lh = (1.12, 0, 0.03), (0.16, 0, -0.05), (0.56, 0, -0.04)
    gl = Vector(g.location)
    return (gl + Vector(muzzle), gl + Vector(rh), gl + Vector(lh), g)


def _arm(M, parent, shoulder, hand, side):
    shoulder, hand = Vector(shoulder), Vector(hand)
    d = hand - shoulder
    a = 0.3
    L = min(d.length, 2 * a - 0.01)
    mid = shoulder + d * 0.5
    hh = math.sqrt(max(0.0, a * a - (L * 0.5) ** 2))
    out = Vector((0, side, -0.9)).normalized()
    out = (out - d.normalized() * out.dot(d.normalized())).normalized()
    elbow = mid + out * hh
    C.tube_between(shoulder, elbow, 0.07, M["coat"], parent, name="uarm")
    C.tube_between(elbow, hand, 0.062, M["coat"], parent, name="farm", r2=0.07)
    fa = hand - elbow
    C.cyl(0.075, 0.1, elbow + fa * 0.8, M["lining"], parent, rot=fa.to_track_quat("Z", "Y").to_euler(), verts=12)  # cuff
    C.sphere(0.06, hand, M["leather"], parent, segs=12)  # glove


# ---------------------------------------------------------------- render

def render_legs():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    root, pelvis, legs, tails = build_legs(M)
    fw, fh, org = LEGS_FRAME
    C.setup_camera(fw, fh, org)
    cols = RUN_FRAMES + 1
    sw = C.SheetWriter("player", "player_legs", fw, fh, org, LEG_DIRS, cols,
                       meta={"dirs": LEG_DIRS, "anims": {"run": [0, RUN_FRAMES], "idle": [RUN_FRAMES, 1]}})
    sw.meta["bob_m"] = [pose_legs(pelvis, legs, f / RUN_FRAMES, tails=tails) for f in range(RUN_FRAMES)]
    for d in range(LEG_DIRS):
        root.rotation_euler = (0, 0, C.yaw_for_ground_angle(d * 2 * math.pi / LEG_DIRS))
        for f in range(cols):
            if f < RUN_FRAMES:
                pose_legs(pelvis, legs, f / RUN_FRAMES, tails=tails)
            else:
                pose_legs(pelvis, legs, 0, idle=True, tails=tails)
            sw.put(d, f, C.render_stylized())
        print("legs dir", d, flush=True)
    sw.save()


def render_torsos(kinds=("rifle", "shotgun", "arc", "rail")):
    for kind in kinds:
        C.reset_scene()
        C.setup_lights()
        M = materials()
        root, t = build_torso(M)
        res = build_weapon(kind, M, t)
        muzzle, rh, lh = res[0], res[1], res[2]
        _arm(M, t, (0.0, -0.27, 0.54), rh, -1)
        _arm(M, t, (0.0, 0.27, 0.54), lh, 1)
        fw, fh, org = TORSO_FRAME
        C.setup_camera(fw, fh, org)
        cols = 8
        tz = t.location.z
        meta = {"dirs": TORSO_DIRS, "layout": "grid", "muzzle_m": [muzzle[0], muzzle[1], muzzle[2] + tz]}
        if len(res) > 4:
            m2 = res[4]
            meta["muzzle2_m"] = [m2[0], m2[1], m2[2] + tz]
        sw = C.SheetWriter("player", "player_torso_" + kind, fw, fh, org, TORSO_DIRS // cols, cols, meta=meta)
        for d in range(TORSO_DIRS):
            root.rotation_euler = (0, 0, C.yaw_for_ground_angle(d * 2 * math.pi / TORSO_DIRS))
            sw.put(d // cols, d % cols, C.render_stylized())
        sw.save()
        print("torso", kind, "done", flush=True)


def render_portrait(size=192):
    """Head-and-shoulders portrait for the HUD diamond (front 3/4 view)."""
    import os
    C.reset_scene()
    C.setup_lights()
    M = materials()
    root, t = build_torso(M)
    _arm(M, t, (0.0, -0.27, 0.54), Vector((0.12, -0.32, 0.12)), -1)
    _arm(M, t, (0.0, 0.27, 0.54), Vector((0.12, 0.32, 0.12)), 1)
    sc = C.bpy.context.scene
    ss = C.SS
    sc.render.resolution_x = sc.render.resolution_y = size * ss
    cam_data = C.bpy.data.cameras.new("PortraitCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.0
    cam = C.bpy.data.objects.new("PortraitCam", cam_data)
    sc.collection.objects.link(cam)
    el = math.radians(14.0)
    cam.rotation_euler = (math.pi / 2 - el, 0, math.radians(118.0))
    back = cam.rotation_euler.to_matrix() @ Vector((0, 0, 1))
    cam.location = Vector((0.03, 0, 1.72)) + back * C.CAM_DIST
    sc.camera = cam
    img = C.render_stylized({"outline_px": 6, "inner_px": 2})["color"]
    out = os.path.join(C.ROOT, "assets", "sprites", "ui")
    os.makedirs(out, exist_ok=True)
    from PIL import Image
    Image.fromarray(img).save(os.path.join(out, "portrait.png"))
    print("[portrait] saved")


if __name__ == "__main__":
    import sys
    what = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["legs", "torso"]
    if "legs" in what:
        render_legs()
    if "torso" in what:
        render_torsos([k for k in ("rifle", "shotgun", "arc", "rail") if k in what] or ("rifle", "shotgun", "arc", "rail"))
    if "portrait" in what:
        render_portrait()
