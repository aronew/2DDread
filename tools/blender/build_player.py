"""Player: the gunslinger, rendered as two ink/cel-shaded layers.

Modelled after the owner's character design (docs/concept/gunslinger_design_*.webp).

legs   : 16 movement directions x (8 run frames + 1 idle)  -- drawn first
torso  : 32 aim directions per weapon (rifle=twin revolvers, shotgun=blunderbuss,
         arc=stormcaller, rail=longshot)                      -- drawn on top
saber  : torso swapped in while the Hellfire Saber swings: light (5 frames), heavy (6),
         thrust (2), 16 directions each              (-- swings | light heavy thrust)
dash   : the whole body in a low lunge, 16 directions x 3 frames, shown instead of both
         layers while dashing                        (-- dash)
death  : the whole body falling onto its back, 16 directions x 5 frames (-- death)
hit    : the whole body flinching from a blow, 16 directions x 3 frames  (-- hit)
idle   : the whole body at rest, pistols lowered, breathing, 16 x 6 loop (-- idle)

Both layers share the same origin (feet) so they composite exactly.
"""
import math
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
import bmesh
from mathutils import Vector

LEG_DIRS = 16
RUN_FRAMES = 8
TORSO_DIRS = 32

LEGS_FRAME = (160, 164, (80, 116))
TORSO_FRAME = (240, 232, (120, 200))


def materials():
    # Palette from the owner's character design (docs/concept/gunslinger_design_*.webp):
    # black coat with a dark teal sheen and gold piping, red scarf and hatband, cream rolled
    # sleeves, brown gloves, belt, holsters and boots, gold flintlock pistols.
    return {
        "coat": C.mat("p_coat", (0.024, 0.035, 0.037), rough=0.8),
        "pants": C.mat("p_pants", (0.02, 0.026, 0.028), rough=0.85),
        "trim": C.mat("p_trim", (0.84, 0.47, 0.08), metal=1.0, rough=0.3),
        "scarf": C.mat("p_scarf", (0.72, 0.012, 0.018), rough=0.65),
        "skin": C.mat("p_skin", (0.64, 0.31, 0.16), rough=0.6),
        "hair": C.mat("p_hair", (0.022, 0.016, 0.014), rough=0.7),
        "cuff": C.mat("p_cuff", (0.84, 0.72, 0.52), rough=0.8),
        "glove": C.mat("p_glove", (0.13, 0.055, 0.035), rough=0.6),
        "boot": C.mat("p_boot", (0.17, 0.08, 0.052), rough=0.55),
        "belt": C.mat("p_belt", (0.15, 0.065, 0.032), rough=0.55),
        "hat": C.mat("p_hat", (0.02, 0.02, 0.024), rough=0.7),
        "grip": C.mat("p_grip", (0.035, 0.03, 0.032), rough=0.5),
        "blade": C.mat("p_blade", (0.075, 0.068, 0.072), metal=0.85, rough=0.3),
        "hellfire": C.mat("p_hellfire", (1.0, 0.42, 0.1), emit=(1.0, 0.36, 0.07), emit_strength=5.0),
        # the other guns
        "leather": C.mat("p_leather", (0.34, 0.16, 0.07), rough=0.55),
        "gold": C.mat("p_gold", (0.84, 0.47, 0.08), metal=1.0, rough=0.3),
        "steel": C.mat("p_steel", (0.5, 0.52, 0.56), metal=0.9, rough=0.3),
        "dark": C.mat("p_dark", (0.09, 0.085, 0.1), metal=0.4, rough=0.45),
        "wood": C.mat("p_wood", (0.38, 0.18, 0.08), rough=0.6),
        "brass": C.mat("p_brass", (0.6, 0.38, 0.13), metal=1.0, rough=0.3),
        "copper": C.mat("p_copper", (0.75, 0.32, 0.14), metal=1.0, rough=0.3),
        "cyan": C.mat("p_cyan", (0.2, 0.8, 0.95), emit=(0.35, 0.95, 1.0), emit_strength=6.0),
        "rune": C.mat("p_rune", (0.9, 0.15, 0.1), emit=(1.0, 0.25, 0.12), emit_strength=6.0),
    }


def _strip(pts, sides, widths, mat, parent, thick=0.02, name="strip"):
    """Flat cloth strip through pts (scarf tails, coat panels): at each point it spans
    widths[i] along sides[i]; solidified, so it inks like the rest of the model."""
    bm = bmesh.new()
    a, b = [], []
    for p, sd, w in zip(pts, sides, widths):
        p, sd = Vector(p), Vector(sd).normalized()
        a.append(bm.verts.new(p + sd * w * 0.5))
        b.append(bm.verts.new(p - sd * w * 0.5))
    for i in range(len(pts) - 1):
        bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    ob = C._mesh_obj(name, bm, mat, parent, (0, 0, 0), (0, 0, 0), smooth=True)
    md = ob.modifiers.new("Solid", "SOLIDIFY")
    md.thickness = thick
    md.offset = 0.0
    return ob


# ---------------------------------------------------------------- legs

# The long coat's skirt: panels hinged at the belt (x, y, yaw, width, length, kind). Open
# at the front over the legs, split at the back, longer behind, like the design's coat.
SKIRT = (
    (0.1, 0.085, 0.75, 0.16, 0.5, "front"),
    (0.1, -0.085, -0.75, 0.16, 0.5, "front"),
    (-0.005, 0.17, 1.62, 0.19, 0.55, "side"),
    (-0.005, -0.17, -1.62, 0.19, 0.55, "side"),
    (-0.1, 0.08, 2.55, 0.18, 0.6, "back"),
    (-0.1, -0.08, -2.55, 0.18, 0.6, "back"),
)


def build_legs(M):
    root = C.empty("legs_root")
    pelvis = C.empty("pelvis", (0, 0, 0.95), root)
    C.box((0.24, 0.34, 0.2), (0, 0, 0.02), M["pants"], pelvis, bevel=0.05)
    C.box((0.27, 0.4, 0.075), (0, 0, 0.1), M["belt"], pelvis, bevel=0.022)  # belt over the coat
    C.box((0.02, 0.1, 0.075), (0.14, 0, 0.1), M["trim"], pelvis, bevel=0.008)  # square gold buckle
    C.box((0.022, 0.052, 0.034), (0.143, 0, 0.1), M["belt"], pelvis, bevel=0.004)
    for y in (0.075, 0.105):
        C.sphere(0.011, (0.132, y, 0.1), M["trim"], pelvis, segs=8)  # studs
    for s in (1, -1):  # holsters on both hips, gold scrollwork on the outside
        hb = C.empty("holster", (0.04, 0.235 * s, 0.04), pelvis, rot=(-0.1 * s, 0.18, 0))
        C.box((0.12, 0.05, 0.21), (0, 0, -0.08), M["belt"], hb, bevel=0.018)
        C.box((0.05, 0.01, 0.07), (0.0, 0.027 * s, -0.09), M["trim"], hb, bevel=0.003)
        C.box((0.13, 0.056, 0.02), (0, 0, 0.02), M["trim"], hb, bevel=0.004)  # gold rim
    tails = []
    for (x, y, yaw, w, L, kind) in SKIRT:
        h = C.empty("skirt_" + kind, (x, y, 0.08), pelvis)
        o = C.empty("skirt_o", (0, 0, 0), h, rot=(0, 0, yaw))
        flare = -0.16 if kind == "front" else -0.12
        p = C.empty("skirt_p", (0, 0, 0), o, rot=(0, flare, 0))
        C.wedge((0.03, w, L), (0, 0, -L / 2), M["coat"], p, taper=(1.0, 0.72), bevel=0.01)
        C.box((0.036, w * 1.02, 0.024), (0, 0, -L + 0.012), M["trim"], p, bevel=0.004)  # gold hem
        if kind == "front":  # gold piping down the front opening
            ey = -w * 0.5 * (1 if y > 0 else -1)
            C.box((0.036, 0.022, L), (0, ey * 0.86, -L / 2), M["trim"], p, bevel=0.004)
        h["kind"] = kind
        h["side"] = 1 if y > 0 else -1
        tails.append(h)
    legs = {}
    for side, s in (("L", 1), ("R", -1)):
        hip = C.empty("hip" + side, (0, 0.1 * s, -0.02), pelvis)
        C.wedge((0.18, 0.16, 0.44), (0, 0, -0.22), M["pants"], hip, taper=(1.18, 1.12))
        knee = C.empty("knee" + side, (0, 0, -0.44), hip)
        C.sphere(0.08, (0.02, 0, 0), M["pants"], knee, segs=12)
        C.wedge((0.12, 0.11, 0.4), (0, 0, -0.2), M["pants"], knee, taper=(1.15, 1.1))
        C.cyl(0.088, 0.3, (0.0, 0, -0.28), M["boot"], knee, verts=14, bevel=0.01)  # knee-high boot
        C.cyl(0.104, 0.085, (0.01, 0, -0.1), M["boot"], knee, verts=14, bevel=0.012, r2=0.112)  # folded cuff
        C.torus(0.111, 0.011, (0.01, 0, -0.058), M["trim"], knee, seg=20, mseg=6)  # gold cuff edge
        ankle = C.empty("ankle" + side, (0, 0, -0.42), knee)
        C.box((0.29, 0.13, 0.1), (0.05, 0, -0.04), M["boot"], ankle, bevel=0.035)
        C.box((0.1, 0.135, 0.05), (-0.06, 0, -0.08), M["grip"], ankle, bevel=0.015)  # heel
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
            t.rotation_euler = (0.06 * t["side"] if t["kind"] == "front" else 0.0, 0.03, 0)
        return -0.02
    bob = 0.035 * math.cos(2 * p)
    swing_of = {}
    for side, (hip, knee, ankle) in legs.items():
        q = p if side == "L" else p + math.pi
        swing = 0.66 * math.sin(q)
        kb = 0.2 + 1.2 * max(0.0, math.cos(q)) ** 1.4
        hip.rotation_euler = (0, -swing, 0)
        knee.rotation_euler = (0, kb, 0)
        ankle.rotation_euler = (0, -(kb - swing) * 0.55 + 0.05, 0)
        swing_of[1 if side == "L" else -1] = swing
    pelvis.location.z = 0.93 + bob
    pelvis.rotation_euler = (0, 0.12, 0.06 * math.sin(p))
    # the skirt: front panels are kicked forward by their thigh, the rest streams behind
    for i, t in enumerate(tails):
        s = t["side"]
        sw = swing_of[s]
        flap = 0.1 * math.sin(p * 2 + i * 1.3)
        if t["kind"] == "front":
            t.rotation_euler = (0.12 * s, -0.95 * max(0.0, sw) + 0.22, 0)
        elif t["kind"] == "side":
            t.rotation_euler = (0.08 * s + flap * 0.4, 0.2 - 0.3 * max(0.0, sw) + flap * 0.7, 0)
        else:
            t.rotation_euler = (0.06 * s + flap * 0.5, 0.32 + flap * 0.7, 0)
    return bob


# ---------------------------------------------------------------- torso + weapons

def build_torso(M):
    root = C.empty("torso_root")
    t = C.empty("torso", (0, 0, 1.0), root)
    C.wedge((0.24, 0.32, 0.26), (0, 0, 0.12), M["coat"], t, taper=(1.12, 1.2))
    C.wedge((0.3, 0.46, 0.4), (0.0, 0, 0.42), M["coat"], t, taper=(0.85, 0.85), bevel=0.05)
    for s in (-1, 1):  # sloped shoulders
        C.sphere(0.088, (0.0, 0.21 * s, 0.57), M["coat"], t, scale=(1.15, 0.95, 0.62))
    # double-breasted front: the overlap edge piped in gold from the collar to the belt,
    # the other lapel's piping, two gold buttons
    pts = [Vector((0.135, 0.11, 0.62)), Vector((0.158, 0.055, 0.4)), Vector((0.142, 0.012, 0.16)),
           Vector((0.13, 0.0, 0.0))]
    for a, b in zip(pts[:-1], pts[1:]):
        C.tube_between(a, b, 0.011, M["trim"], t, verts=8)
    C.tube_between((0.135, -0.11, 0.62), (0.152, -0.045, 0.47), 0.011, M["trim"], t, verts=8)
    C.tube_between((0.152, -0.045, 0.47), (0.158, -0.02, 0.44), 0.011, M["trim"], t, verts=8)
    for z in (0.38, 0.28):
        C.sphere(0.017, (0.16, -0.06, z), M["trim"], t, segs=8)
    # scarf: a thick bunched wrap up to the chin, a fold on the chest, long tails streaming behind
    C.torus(0.112, 0.058, (0.0, 0, 0.67), M["scarf"], t, seg=20, mseg=8)
    C.sphere(0.075, (0.07, 0.06, 0.65), M["scarf"], t, scale=(1.0, 1.15, 0.8), segs=12)
    C.sphere(0.07, (0.075, -0.06, 0.68), M["scarf"], t, scale=(1.0, 1.15, 0.75), segs=12)
    C.sphere(0.07, (-0.05, 0.0, 0.7), M["scarf"], t, scale=(1.0, 1.4, 0.7), segs=12)
    _strip([(0.12, 0.09, 0.62), (0.15, 0.1, 0.52), (0.155, 0.13, 0.43)],
           [(0, 1, 0.3), (0, 1, 0.1), (0, 1, 0)], [0.1, 0.11, 0.06], M["scarf"], t, thick=0.025)
    # two tails falling down the back and fluttering out to one side, wide cloth with a
    # twist, cut to a point
    st1 = _strip([(-0.09, -0.03, 0.66), (-0.17, -0.09, 0.57), (-0.25, -0.15, 0.46), (-0.31, -0.19, 0.35),
                  (-0.37, -0.24, 0.24)],
                 [(0.15, 1, 0.35), (0.3, 1, 0.8), (0.2, 0.6, 1), (0.3, 1, 0.7), (0.2, 0.7, 1)],
                 [0.12, 0.16, 0.16, 0.13, 0.02], M["scarf"], t, thick=0.024)
    st2 = _strip([(-0.08, 0.05, 0.64), (-0.16, 0.06, 0.55), (-0.22, 0.04, 0.45), (-0.27, 0.0, 0.36)],
                 [(0.2, 1, 0.5), (0.3, 1, 1), (0.2, 1, 0.5), (0.3, 1, 1)],
                 [0.1, 0.13, 0.11, 0.02], M["scarf"], t, thick=0.024)
    st1["scarf_tail"] = st2["scarf_tail"] = 1   # the death pose lays them on the ground instead
    # head: tanned face under the hat's shadow, dark spiky hair at the sides
    h = C.empty("head", (0.045, 0, 0.82), t, rot=(0, -0.08, 0))
    C.cyl(0.045, 0.1, (0, 0, -0.08), M["skin"], h, verts=10)
    C.sphere(0.105, (0, 0, 0), M["skin"], h, scale=(1.02, 0.9, 1.12))
    C.sphere(0.07, (0.035, 0, -0.055), M["skin"], h, scale=(1.0, 1.05, 0.8), segs=12)  # jaw
    C.box((0.02, 0.15, 0.03), (0.1, 0, 0.025), M["hair"], h, bevel=0.0)  # eyes in shadow
    for ang, z, ln in ((0.9, 0.03, 0.07), (1.4, 0.0, 0.08), (1.9, 0.02, 0.08), (2.5, 0.0, 0.08), (3.14, 0.02, 0.08),
                       (-0.9, 0.03, 0.07), (-1.4, 0.0, 0.08), (-1.9, 0.02, 0.08), (-2.5, 0.0, 0.08),
                       (0.45, 0.06, 0.05), (-0.45, 0.06, 0.05)):
        d = Vector((math.cos(ang), math.sin(ang), -0.35)).normalized()
        base = Vector((math.cos(ang) * 0.075, math.sin(ang) * 0.07, z + 0.03))
        C.tube_between(base, base + d * ln, 0.03, M["hair"], h, verts=6, r2=0.003)
    # flat-brimmed hat: gold-edged brim, square crown turned 45 degrees with a red band and
    # a gold rim around its top
    # tipped back so the face shows under the brim from the game's high camera
    hat = C.empty("hat", (-0.01, 0, 0.095), h, rot=(0, -0.14, 0))
    C.cyl(0.27, 0.024, (0, 0, 0), M["hat"], hat, verts=32, bevel=0.01)
    C.torus(0.268, 0.012, (0, 0, 0.0), M["trim"], hat, seg=40, mseg=6)
    q = (0, 0, math.pi / 4)
    C.wedge((0.2, 0.2, 0.12), (0, 0, 0.072), M["hat"], hat, rot=q, taper=(0.93, 0.93), bevel=0.03)
    C.box((0.208, 0.208, 0.046), (0, 0, 0.036), M["scarf"], hat, rot=q, bevel=0.006)
    C.box((0.196, 0.196, 0.012), (0, 0, 0.132), M["trim"], hat, rot=q, bevel=0.004)
    C.box((0.17, 0.17, 0.016), (0, 0, 0.138), M["hat"], hat, rot=q, bevel=0.004)
    return root, t


def _pistol(M, parent, at, name):
    """Gold flintlock: gold lock and barrel with a black inlay, dark grip, gold butt cap."""
    g = C.empty(name, at, parent)
    C.box((0.15, 0.044, 0.066), (0.06, 0, 0.025), M["trim"], g, bevel=0.012)        # lock body
    C.box((0.1, 0.05, 0.022), (0.065, 0, 0.022), M["grip"], g, bevel=0.004)          # black inlay
    C.cyl(0.021, 0.27, (0.25, 0, 0.045), M["trim"], g, rot=(0, math.pi / 2, 0), verts=12)  # barrel
    for x, r in ((0.16, 0.027), (0.3, 0.025), (0.375, 0.03)):
        C.cyl(r, 0.026, (x, 0, 0.045), M["trim"], g, rot=(0, math.pi / 2, 0), verts=12)    # bands, muzzle
    C.torus(0.022, 0.006, (0.0, 0, 0.078), M["grip"], g, rot=(math.pi / 2, 0, 0), seg=12, mseg=4)  # hammer
    C.torus(0.026, 0.006, (0.05, 0, -0.026), M["trim"], g, rot=(math.pi / 2, 0, 0), seg=12, mseg=4)  # guard
    C.box((0.08, 0.042, 0.15), (-0.035, 0, -0.06), M["grip"], g, bevel=0.016, rot=(0, -0.45, 0))  # grip
    C.sphere(0.03, (-0.075, 0, -0.125), M["trim"], g, segs=10)                       # butt cap
    return g


def build_weapon(kind, M, parent):
    """Returns (muzzle, right_hand, left_hand, group[, muzzle2]) in torso space."""
    if kind == "rifle":  # twin flintlock pistols, both arms extended
        r = _pistol(M, parent, (0.46, -0.17, 0.3), "gunR")
        _pistol(M, parent, (0.44, 0.17, 0.32), "gunL")
        muzzle = Vector((0.85, -0.17, 0.345))
        muzzle2 = Vector((0.83, 0.17, 0.365))
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
    """Coat sleeve rolled to the elbow (cream cuff), bare forearm, brown gauntlet glove."""
    shoulder, hand = Vector(shoulder), Vector(hand)
    d = hand - shoulder
    a = 0.3
    L = min(d.length, 2 * a - 0.01)
    mid = shoulder + d * 0.5
    hh = math.sqrt(max(0.0, a * a - (L * 0.5) ** 2))
    out = Vector((0, side, -0.9)).normalized()
    out = (out - d.normalized() * out.dot(d.normalized())).normalized()
    elbow = mid + out * hh
    C.tube_between(shoulder, elbow, 0.068, M["coat"], parent, name="uarm")
    fa = hand - elbow
    fd = fa.normalized()
    rot = fa.to_track_quat("Z", "Y").to_euler()
    C.tube_between(elbow, hand, 0.047, M["skin"], parent, name="farm", r2=0.04)
    C.cyl(0.074, 0.09, elbow + fd * 0.035, M["cuff"], parent, rot=rot, verts=14, bevel=0.014)  # rolled sleeve
    C.cyl(0.07, 0.085, hand - fd * 0.075, M["glove"], parent, rot=rot, verts=12, r2=0.05, bevel=0.008)  # gauntlet
    C.sphere(0.058, hand, M["glove"], parent, segs=12)


# ---------------------------------------------------------------- sword swings + dash

SWING_FRAME = (320, 300, (160, 236))
SWING_DIRS = 16
# Saber swings keyed in the facing frame at the waist (+X ahead, +Y his left):
# (blade angle in degrees, 0 = ahead, + = his left; torso twist in degrees; blade tilt in
# radians, + = up; hand distance from the body axis in m; hand height above the waist in m).
# Both sweep from his left to his right like the slash effect of the combo's first and
# third swings (Blade: _side = +1); the second swing plays "light" backwards.
SWING_KEYS = {
    "light": ((80, 40, 0.3, 0.4, 0.44), (15, 15, 0.05, 0.55, 0.38), (-65, -25, -0.05, 0.56, 0.35),
              (-100, -40, -0.2, 0.5, 0.3), (-60, -15, -0.55, 0.42, 0.22)),
    "heavy": ((125, 60, 0.55, 0.38, 0.52), (60, 35, 0.15, 0.55, 0.42), (-5, 5, 0.0, 0.6, 0.36),
              (-85, -35, -0.05, 0.58, 0.34), (-130, -60, -0.2, 0.5, 0.3), (-80, -25, -0.55, 0.42, 0.22)),
}
# the dash-slash: (hand position in the facing frame, torso twist in degrees, blade tilt)
THRUST_KEYS = (((0.02, -0.3, 0.32), -25, 0.08), ((0.64, -0.1, 0.4), 25, 0.0))

DASH_FRAME = (280, 300, (140, 240))
# full-body dash poses: pelvis height, torso lean (rad, forward), (hip, knee) of the
# leading left leg, (hip, knee) of the trailing right leg
DASH_POSES = (
    (0.82, 0.32, (-0.55, 0.85), (0.45, 0.2)),     # push off
    (0.79, 0.5, (-0.95, 1.05), (0.8, 0.6)),       # flight
    (0.76, 0.28, (-0.7, 1.15), (0.35, 0.75)),     # landing
)


def build_saber(M, parent):
    """The Hellfire Saber: a broad curved blade of dark steel with a molten edge, gold
    guard and pommel. Built along +X; its origin is the grip, where the hand goes."""
    s = C.empty("saber", (0, 0, 0), parent)
    C.cyl(0.019, 0.12, (0, 0, 0), M["grip"], s, rot=(0, math.pi / 2, 0), verts=8, bevel=0.004)
    C.sphere(0.026, (-0.07, 0, 0), M["trim"], s, segs=10)
    C.box((0.022, 0.13, 0.026), (0.065, 0, 0), M["trim"], s, bevel=0.006)
    n, L, bend = 6, 0.84, 0.1
    pts, sides, widths = [], [], []
    for i in range(n + 1):
        u = i / n
        pts.append(Vector((0.075 + L * u, bend * u * u, 0.0)))
        sides.append(Vector((-2 * bend * u, L, 0.0)))
        widths.append(0.075 * (1.0 - 0.3 * u) if i < n else 0.006)
    _strip(pts, sides, widths, M["blade"], s, thick=0.008, name="blade")
    edge = [p - sd.normalized() * w * 0.27 for p, sd, w in zip(pts, sides, widths)]
    _strip(edge, sides, [w * 0.5 for w in widths], M["hellfire"], s, thick=0.012, name="edge")
    return s


def _pistol_in_hand(M, parent, hand, rot):
    """A flintlock with its grip in `hand`, turned by `rot` (Euler)."""
    from mathutils import Euler
    grip = Euler(rot).to_matrix() @ Vector((-0.035, 0, -0.06))
    g = _pistol(M, parent, Vector(hand) - grip, "gunL")
    g.rotation_euler = rot
    return g


def _created_by(fn):
    before = set(C.bpy.data.objects)
    fn()
    return [o for o in C.bpy.data.objects if o not in before]


def _remove(objs):
    for o in objs:
        C.bpy.data.objects.remove(o, do_unlink=True)


def _to_torso(v, twist):
    c, s = math.cos(-twist), math.sin(-twist)
    return Vector((v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2]))


def _sword_pose(M, t, hand_f, blade_deg, tilt, twist):
    """Twist the torso, put the saber in the right hand at hand_f (facing frame) pointing
    along blade_deg; the left hand keeps a pistol low. Returns the objects it made."""
    def make():
        t.rotation_euler = (0, 0, twist)
        hand = _to_torso(hand_f, twist)
        sab = build_saber(M, t)
        sab.location = hand
        sab.rotation_euler = (0, -tilt, math.radians(blade_deg) - twist)
        _arm(M, t, (0.0, -0.27, 0.54), hand, -1)
        lh = Vector((0.14, 0.3, 0.1))
        _pistol_in_hand(M, t, lh, (0, 0.7, 0.1))
        _arm(M, t, (0.0, 0.27, 0.54), lh, 1)
    return _created_by(make)


def swing_frame(M, t, kind, key):
    if kind == "thrust":
        hand_f, twist_deg, tilt = key
        return _sword_pose(M, t, Vector(hand_f), 0.0, tilt, math.radians(twist_deg))
    blade, twist_deg, tilt, r, z = key
    a = math.radians(blade)
    return _sword_pose(M, t, Vector((r * math.cos(a), r * math.sin(a), z)), blade, tilt, math.radians(twist_deg))


def pose_dash(pelvis, legs, tails, t, head, pose):
    """A low lunge: lead leg reaching, trail leg pushing off, body leaning into the dash,
    coat flung back."""
    pz, lean, front, back = pose
    pelvis.location.z = pz
    pelvis.rotation_euler = (0, lean * 0.45, 0)
    for side, (hip, knee, ankle) in legs.items():
        h, k = front if side == "L" else back
        hip.rotation_euler = (0, h - lean * 0.45, 0)
        knee.rotation_euler = (0, k, 0)
        ankle.rotation_euler = (0, -(h + k) * (1.0 if side == "L" else 0.4), 0)
    swing = {1: -front[0], -1: -back[0]}
    for i, tl in enumerate(tails):
        sd = tl["side"]
        sw = swing[sd]
        if tl["kind"] == "front":
            tl.rotation_euler = (0.14 * sd, -0.95 * max(0.0, sw) + 0.35, 0)
        elif tl["kind"] == "side":
            tl.rotation_euler = (0.12 * sd, 0.25 + lean * 0.3, 0)
        else:
            tl.rotation_euler = (0.08 * sd, 0.3 + lean * 0.4, 0)
    t.location = (0.0, 0, pz + 0.05)
    t.rotation_euler = (0, lean, 0)
    head.rotation_euler = (0, -0.08 - lean * 0.6, 0)


def _dash_arms(M, t):
    """Arms swept back, a pistol in each hand pointing behind."""
    for side, hand in ((-1, (-0.2, -0.37, 0.14)), (1, (-0.16, 0.37, 0.18))):
        _pistol_in_hand(M, t, hand, (0.12 * side, 2.0, 0.0))
        _arm(M, t, (0.0, 0.27 * side, 0.54), Vector(hand), side)


DEATH_FRAME = (360, 300, (180, 214))
# The death, full body, falling backward (away from the killing blow) onto his back. Per
# frame: fwd = the body's shift along his facing (the feet slide forward as he goes down),
# pz / pitch = pelvis height and backward tilt, lean = torso tilt (- = back), head = head
# tilt (- = back), L / R = (hip, knee, foot angle: 0 flat, -1.57 toes up) relative to the
# pelvis, hands in the torso's frame, guns = still in his hands, hat = None (on his head)
# or (x, y, z, rx, ry, rz) on the ground plane, relative to the feet.
DEATH_POSES = (
    dict(fwd=-0.06, pz=0.93, pitch=0.12, lean=-0.32, head=-0.4, L=(-0.18, 0.3, 0.0), R=(0.22, 0.12, 0.0),
         hands=((-0.04, -0.6, 0.4), (-0.06, 0.6, 0.44)), guns=True, hat=None),           # hit, arched back
    dict(fwd=0.0, pz=0.64, pitch=0.25, lean=-0.55, head=-0.3, L=(-0.9, 1.6, 0.0), R=(-0.62, 1.4, 0.0),
         hands=((-0.08, -0.6, 0.36), (-0.05, 0.6, 0.4)), guns=True,
         hat=(-0.45, 0.06, 1.62, 0.3, -0.5, 0.0)),                                         # knees buckle, hat flies
    dict(fwd=0.14, pz=0.36, pitch=0.62, lean=-1.0, head=-0.15, L=(-0.95, 1.5, 0.0), R=(-0.75, 1.15, -0.4),
         hands=((-0.06, -0.63, 0.4), (-0.06, 0.63, 0.44)), guns=True,
         hat=(-0.95, 0.12, 0.95, 0.7, -1.2, 0.4)),                                         # falling
    dict(fwd=0.28, pz=0.15, pitch=1.15, lean=-1.45, head=-0.05, L=(-0.6, 1.05, 0.0), R=(-0.3, 0.25, -1.2),
         hands=((-0.06, -0.64, 0.4), (-0.06, 0.64, 0.44)), guns=False,
         hat=(-1.3, 0.22, 0.14, 0.9, -0.3, 0.6)),                                          # hits the ground
    dict(fwd=0.3, pz=0.12, pitch=1.3, lean=-1.55, head=0.0, L=(-0.55, 1.0, 0.0), R=(-0.22, 0.05, -1.5),
         hands=((-0.08, -0.66, 0.36), (-0.08, 0.62, 0.42)), guns=False,
         hat=(-1.38, 0.32, 0.012, 0.0, 0.0, 0.6)),                                         # lying still
)


def pose_body(M, pelvis, legs, tails, troot, t, head, hat, scarf_tails, pose):
    """Pose the whole body for one full-body frame (death, hit reaction); returns the
    objects it made (arms, pistols, the scarf spread on the ground)."""
    fwd, pz, pitch, lean = pose["fwd"], pose["pz"], pose["pitch"], pose["lean"]
    pelvis.location = (fwd, 0, pz)
    pelvis.rotation_euler = (0, -pitch, 0)
    for side, (hip, knee, ankle) in legs.items():
        h, k, foot = pose["L"] if side == "L" else pose["R"]
        hip.rotation_euler = (0, h, 0)
        knee.rotation_euler = (0, k, 0)
        ankle.rotation_euler = (0, foot - (-pitch + h + k), 0)
    lying = pitch > 0.9
    for tl in tails:
        sd = tl["side"]
        if tl["kind"] == "front":
            hp = (pose["L"] if sd > 0 else pose["R"])[0]
            tl.rotation_euler = (0.12 * sd, min(0.2, hp * 0.8 + 0.2), 0)
        else:   # lifted toward the ground plane once he's down, so they spread under him
            tl.rotation_euler = (0.25 * sd, -0.45 if lying else 0.2, 0)
    # the torso pivots at the top of the tilted pelvis
    t.location = (fwd - 0.06 * math.sin(pitch), 0, pz + 0.06 * math.cos(pitch))
    t.rotation_euler = (0, lean, 0)
    head.rotation_euler = (0.35 if lying else 0.0, -0.08 + pose["head"], 0)
    for st in scarf_tails:
        st.hide_render = pitch > 0.5
    if pose["hat"] is None:
        hat.parent = head
        hat.location = (-0.01, 0, 0.095)
        hat.rotation_euler = (0, -0.14, 0)
    else:
        x, y, z, rx, ry, rz = pose["hat"]
        hat.parent = troot
        hat.location = (fwd + x, y, z)
        hat.rotation_euler = (rx, ry, rz)

    def make():
        for side, hand in ((-1, pose["hands"][0]), (1, pose["hands"][1])):
            _arm(M, t, (0.0, 0.27 * side, 0.54), Vector(hand), side)
            if pose["guns"]:
                gr = pose.get("gun_rot", (0.3, 0.7, 1.3))   # default: flung out, pointing down
                _pistol_in_hand(M, t, hand, (gr[0] * side, gr[1], gr[2] * side))
            else:   # dropped beside him, lying on their sides
                g = _pistol(M, troot, Vector((fwd - 0.45, 0.82 * side, 0.03)), "gun_dropped")
                g.rotation_euler = (math.pi / 2, 0, 0.9 * side + 0.3)
        if pitch > 0.5:   # the scarf's tails spill out on the ground by his neck
            nx = fwd - 0.62 if lying else fwd - 0.45
            nz = 0.03 if lying else 0.3
            _strip([(nx, -0.05, nz + 0.06), (nx - 0.12, -0.3, nz), (nx - 0.05, -0.55, nz), (nx - 0.16, -0.75, nz)],
                   [(1, 0, 0.1)] * 4, [0.16, 0.19, 0.17, 0.09], M["scarf"], troot, thick=0.024)
            _strip([(nx, 0.05, nz + 0.06), (nx - 0.2, 0.18, nz), (nx - 0.3, 0.36, nz)],
                   [(1, 0.3, 0.1)] * 3, [0.14, 0.16, 0.08], M["scarf"], troot, thick=0.024)
    return _created_by(make)


# The hit reaction (full body, facing the attacker): the blow snaps him back, he
# staggers, and recovers toward his aiming stance. Same keys as DEATH_POSES; gun_rot
# turns the pistols (default: flung out, pointing down).
HIT_POSES = (
    dict(fwd=-0.08, pz=0.9, pitch=0.1, lean=-0.3, head=-0.35, L=(-0.1, 0.25, 0.0), R=(0.35, 0.3, 0.0),
         hands=((0.12, -0.5, 0.38), (0.1, 0.5, 0.42)), guns=True, hat=None),                # the blow lands
    dict(fwd=-0.12, pz=0.86, pitch=0.0, lean=0.12, head=0.2, L=(-0.3, 0.55, 0.0), R=(0.3, 0.5, 0.0),
         hands=((0.2, -0.36, 0.22), (0.2, 0.36, 0.26)), guns=True, hat=None,
         gun_rot=(0.2, 0.9, 0.6)),                                                           # stagger, hunched
    dict(fwd=-0.1, pz=0.91, pitch=0.03, lean=0.02, head=0.0, L=(-0.15, 0.25, 0.0), R=(0.15, 0.2, 0.0),
         hands=((0.35, -0.22, 0.28), (0.33, 0.22, 0.3)), guns=True, hat=None,
         gun_rot=(0.0, 0.3, 0.1)),                                                           # recovering
)
BODY_FRAME = (260, 290, (130, 240))   # idle and hit: standing, so a smaller frame
IDLE_FRAMES = 6


def _rot_about(ob, pivot, euler):
    """Turn an object whose mesh sits in its parent's space about `pivot` (parent space)."""
    from mathutils import Euler
    R = Euler(euler).to_matrix()
    P = Vector(pivot)
    ob.rotation_euler = euler
    ob.location = P - R @ P


def pose_idle(M, pelvis, legs, tails, troot, t, head, hat, scarf_tails, f):
    """One frame of the idle loop: the pistols lowered at his sides like the design, a slow
    breath (chest rising, head nodding), the coat and scarf stirring in a draught."""
    p = 2 * math.pi * f / IDLE_FRAMES
    pose_legs(pelvis, legs, 0, idle=True, tails=tails)
    pelvis.location = (0, 0, 0.93 + 0.006 * math.sin(p))
    for i, tl in enumerate(tails):
        b = tl.rotation_euler
        tl.rotation_euler = (b[0] + 0.035 * math.sin(p + i * 1.1), b[1] + 0.03 * math.sin(p + i * 0.7 + 1.0), 0)
    t.location = (0, 0, 0.98 + 0.015 * math.sin(p))
    t.rotation_euler = (0, 0.015 * math.sin(p), 0)
    head.rotation_euler = (0, -0.08 + 0.025 * math.sin(p + 0.6), 0)
    hat.parent = head
    hat.location = (-0.01, 0, 0.095)
    hat.rotation_euler = (0, -0.14, 0)
    for k, st in enumerate(scarf_tails):
        st.hide_render = False
        _rot_about(st, (-0.06, 0.0, 0.66), (0.12 * math.sin(p + k), 0.08 * math.sin(p + 1.0 + k),
                                             0.17 * math.sin(p + 0.5 + k * 0.8)))

    def make():
        for side, hand in ((-1, (0.05, -0.32, -0.03 + 0.008 * math.sin(p))), (1, (0.05, 0.32, -0.02 + 0.008 * math.sin(p)))):
            _arm(M, t, (0.0, 0.27 * side, 0.54), Vector(hand), side)
            _pistol_in_hand(M, t, hand, (0.0, 1.4, 0.12 * side))   # barrel down, like the design
    return _created_by(make)


def _render_body(name, frame, n, poser):
    """Render a full-body sheet (16 dirs x n frames): poser(f, parts) poses frame f and
    returns the objects to remove after it."""
    C.reset_scene()
    C.setup_lights()
    M = materials()
    lroot, pelvis, legs, tails = build_legs(M)
    troot, t = build_torso(M)
    head = [o for o in t.children if o.name.startswith("head")][0]
    hat = [o for o in head.children if o.name.startswith("hat")][0]
    scarf_tails = [o for o in t.children if o.get("scarf_tail")]
    parts = (M, pelvis, legs, tails, troot, t, head, hat, scarf_tails)
    fw, fh, org = frame
    C.setup_camera(fw, fh, org)
    sw = C.SheetWriter("player", name, fw, fh, org, LEG_DIRS, n, meta={"dirs": LEG_DIRS, "frames": n})
    for f in range(n):
        objs = poser(f, parts)
        for d in range(LEG_DIRS):
            a = C.yaw_for_ground_angle(d * 2 * math.pi / LEG_DIRS)
            lroot.rotation_euler = (0, 0, a)
            troot.rotation_euler = (0, 0, a)
            sw.put(d, f, C.render_stylized())
        _remove(objs)
        print(name, "frame", f, flush=True)
    sw.save()


def render_death():
    _render_body("player_death", DEATH_FRAME, len(DEATH_POSES), lambda f, P: pose_body(*P, DEATH_POSES[f]))


def render_hit():
    _render_body("player_hit", BODY_FRAME, len(HIT_POSES), lambda f, P: pose_body(*P, HIT_POSES[f]))


def render_idle():
    _render_body("player_idle", BODY_FRAME, IDLE_FRAMES, lambda f, P: pose_idle(*P, f))


def render_swings(kinds=("light", "heavy", "thrust")):
    for kind in kinds:
        C.reset_scene()
        C.setup_lights()
        M = materials()
        root, t = build_torso(M)
        fw, fh, org = SWING_FRAME
        C.setup_camera(fw, fh, org)
        keys = THRUST_KEYS if kind == "thrust" else SWING_KEYS[kind]
        sw = C.SheetWriter("player", "player_saber_" + kind, fw, fh, org, SWING_DIRS, len(keys),
                           meta={"dirs": SWING_DIRS, "frames": len(keys)})
        for f, key in enumerate(keys):
            objs = swing_frame(M, t, kind, key)
            for d in range(SWING_DIRS):
                root.rotation_euler = (0, 0, C.yaw_for_ground_angle(d * 2 * math.pi / SWING_DIRS))
                sw.put(d, f, C.render_stylized())
            _remove(objs)
            print("saber", kind, "frame", f, flush=True)
        sw.save()


def render_dash():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    lroot, pelvis, legs, tails = build_legs(M)
    troot, t = build_torso(M)
    head = [o for o in t.children if o.name.startswith("head")][0]
    _dash_arms(M, t)
    fw, fh, org = DASH_FRAME
    C.setup_camera(fw, fh, org)
    sw = C.SheetWriter("player", "player_dash", fw, fh, org, LEG_DIRS, len(DASH_POSES),
                       meta={"dirs": LEG_DIRS, "frames": len(DASH_POSES)})
    for f, pose in enumerate(DASH_POSES):
        pose_dash(pelvis, legs, tails, t, head, pose)
        for d in range(LEG_DIRS):
            a = C.yaw_for_ground_angle(d * 2 * math.pi / LEG_DIRS)
            lroot.rotation_euler = (0, 0, a)
            troot.rotation_euler = (0, 0, a)
            sw.put(d, f, C.render_stylized())
        print("dash frame", f, flush=True)
    sw.save()


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
    swings = [k for k in ("light", "heavy", "thrust") if k in what]
    if "swings" in what or swings:
        render_swings(swings or ("light", "heavy", "thrust"))
    if "dash" in what:
        render_dash()
    if "death" in what:
        render_death()
    if "hit" in what:
        render_hit()
    if "idle" in what:
        render_idle()
