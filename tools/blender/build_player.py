"""Player: armoured hunter rendered as two layers.

legs   : 16 movement directions x (8 run frames + 1 idle)  -- drawn first
torso  : 32 aim directions per weapon (rifle, shotgun, arc, rail) -- drawn on top

Both layers share the same origin (feet) so they composite exactly.
"""
import math
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

LEG_DIRS = 16
RUN_FRAMES = 8
TORSO_DIRS = 32

LEGS_FRAME = (160, 160, (80, 112))
TORSO_FRAME = (224, 200, (112, 176))


def materials():
    return {
        "red": C.mat("p_red", (0.42, 0.035, 0.045), metal=0.35, rough=0.32, coat=0.4, noise=0.25,
                     noise_scale=14, noise_color=(0.22, 0.02, 0.03)),
        "dark": C.mat("p_dark", (0.05, 0.05, 0.06), metal=0.65, rough=0.42),
        "suit": C.mat("p_suit", (0.10, 0.095, 0.105), metal=0.1, rough=0.85, bump=0.3, noise_scale=40),
        "steel": C.mat("p_steel", (0.55, 0.56, 0.6), metal=0.95, rough=0.28),
        "bone": C.mat("p_bone", (0.78, 0.74, 0.68), metal=0.1, rough=0.45),
        "glow": C.mat("p_glow", (0.1, 0.3, 0.9), emit=(0.25, 0.6, 1.0), emit_strength=7.0),
        "visor": C.mat("p_visor", (0.05, 0.2, 0.3), metal=0.2, rough=0.1, emit=(0.35, 0.95, 1.0), emit_strength=6.0),
        "orange": C.mat("p_orange", (0.6, 0.2, 0.02), emit=(1.0, 0.45, 0.08), emit_strength=5.0),
        "violet": C.mat("p_violet", (0.3, 0.1, 0.6), emit=(0.65, 0.35, 1.0), emit_strength=7.0),
        "gun_white": C.mat("p_gunw", (0.72, 0.72, 0.74), metal=0.3, rough=0.35, coat=0.3),
        "gun_dark": C.mat("p_gund", (0.08, 0.085, 0.095), metal=0.7, rough=0.35),
        "gun_red": C.mat("p_gunr", (0.5, 0.05, 0.05), metal=0.4, rough=0.3, coat=0.4),
    }


# ---------------------------------------------------------------- legs

def build_legs(M):
    root = C.empty("legs_root")
    pelvis = C.empty("pelvis", (0, 0, 0.96), root)
    C.box((0.26, 0.36, 0.2), (0, 0, 0.02), M["dark"], pelvis, bevel=0.04)
    C.box((0.2, 0.30, 0.1), (0.1, 0, -0.04), M["red"], pelvis, bevel=0.03, rot=(0, 0.3, 0))  # cod plate
    C.box((0.1, 0.42, 0.06), (0, 0, 0.1), M["suit"], pelvis, bevel=0.02)  # belt
    for s in (-1, 1):
        C.box((0.12, 0.08, 0.12), (-0.08, 0.21 * s, 0.05), M["dark"], pelvis, bevel=0.02)  # pouches
        C.box((0.16, 0.05, 0.22), (0.0, 0.22 * s, -0.1), M["red"], pelvis, bevel=0.02)  # tassets
    legs = {}
    for side, s in (("L", 1), ("R", -1)):
        hip = C.empty("hip" + side, (0, 0.12 * s, -0.02), pelvis)
        # thigh
        C.wedge((0.22, 0.2, 0.42), (0, 0, -0.22), M["suit"], hip, taper=(1.2, 1.15))
        C.box((0.14, 0.19, 0.32), (0.07, 0.0, -0.2), M["red"], hip, bevel=0.035, rot=(0, -0.05, 0))
        knee = C.empty("knee" + side, (0, 0, -0.44), hip)
        C.box((0.12, 0.13, 0.12), (0.07, 0, 0.0), M["red"], knee, bevel=0.035)  # knee pad
        C.sphere(0.035, (0.13, 0, 0.0), M["glow"], knee, segs=10)
        # shin
        C.wedge((0.18, 0.16, 0.4), (0, 0, -0.22), M["suit"], knee, taper=(1.3, 1.2))
        C.box((0.12, 0.18, 0.34), (0.06, 0, -0.2), M["red"], knee, bevel=0.035)  # greave
        C.box((0.02, 0.02, 0.22), (0.11, 0.0, -0.2), M["glow"], knee, bevel=0.0)  # glow strip
        C.box((0.06, 0.02, 0.16), (-0.02, 0.085 * s, -0.22), M["glow"], knee, bevel=0.0)
        ankle = C.empty("ankle" + side, (0, 0, -0.42), knee)
        C.box((0.34, 0.18, 0.12), (0.05, 0, -0.04), M["dark"], ankle, bevel=0.03)  # boot
        C.box((0.12, 0.15, 0.06), (0.16, 0, -0.06), M["steel"], ankle, bevel=0.02)  # toe cap
        legs[side] = (hip, knee, ankle)
    return root, pelvis, legs


def pose_legs(pelvis, legs, phase, idle=False):
    """phase 0..1 run cycle. Returns pelvis bob (metres)."""
    p = phase * 2 * math.pi
    if idle:
        for side, (hip, knee, ankle) in legs.items():
            s = 1 if side == "L" else -1
            hip.rotation_euler = (0.02 * s, -0.12 if side == "L" else 0.1, 0)
            knee.rotation_euler = (0, 0.22, 0)
            ankle.rotation_euler = (0, -0.1, 0)
        pelvis.location.z = 0.94
        pelvis.rotation_euler = (0, 0.04, 0)
        return -0.02
    bob = 0.035 * math.cos(2 * p)
    for side, (hip, knee, ankle) in legs.items():
        q = p if side == "L" else p + math.pi
        swing = 0.62 * math.sin(q)  # + = forward
        kb = 0.18 + 1.15 * max(0.0, math.cos(q)) ** 1.4
        hip.rotation_euler = (0, -swing, 0)
        knee.rotation_euler = (0, kb, 0)
        ankle.rotation_euler = (0, -(kb - swing) * 0.55 + 0.05, 0)
    pelvis.location.z = 0.94 + bob
    pelvis.rotation_euler = (0, 0.14, 0.06 * math.sin(p))  # lean into the run
    return bob


# ---------------------------------------------------------------- torso + weapons

def build_torso(M):
    root = C.empty("torso_root")
    t = C.empty("torso", (0, 0, 1.0), root)
    C.wedge((0.24, 0.32, 0.26), (0, 0, 0.12), M["suit"], t, taper=(1.1, 1.25))  # abdomen
    C.box((0.16, 0.30, 0.18), (0.08, 0, 0.12), M["dark"], t, bevel=0.04)  # ab plates
    C.wedge((0.34, 0.5, 0.36), (0.0, 0, 0.42), M["red"], t, taper=(0.82, 0.78), bevel=0.04)  # chest
    C.box((0.08, 0.24, 0.16), (0.16, 0, 0.45), M["dark"], t, bevel=0.02)  # chest vent
    C.box((0.015, 0.16, 0.03), (0.2, 0, 0.42), M["glow"], t, bevel=0.0)
    C.box((0.2, 0.18, 0.08), (0.0, 0, 0.64), M["dark"], t, bevel=0.03)  # collar
    # backpack
    C.box((0.22, 0.42, 0.42), (-0.24, 0, 0.42), M["dark"], t, bevel=0.05)
    for s in (-1, 1):
        C.cyl(0.055, 0.34, (-0.36, 0.12 * s, 0.42), M["glow"], t, verts=14, bevel=0.0)
        C.cyl(0.07, 0.04, (-0.36, 0.12 * s, 0.6), M["steel"], t, verts=14)
        C.cyl(0.07, 0.04, (-0.36, 0.12 * s, 0.24), M["steel"], t, verts=14)
    C.box((0.06, 0.06, 0.3), (-0.3, 0.2, 0.72), M["steel"], t, bevel=0.01, rot=(0.2, 0, 0))  # antenna
    # shoulders
    for s in (-1, 1):
        C.sphere(0.14, (0.0, 0.31 * s, 0.56), M["red"], t, scale=(1.15, 1.0, 0.8))
        C.box((0.22, 0.12, 0.06), (0.0, 0.33 * s, 0.66), M["dark"], t, bevel=0.02, rot=(0.35 * s, 0, 0))
    # helmet
    h = C.empty("head", (0.02, 0, 0.82), t)
    C.sphere(0.15, (0, 0, 0.0), M["dark"], h, scale=(1.08, 0.95, 1.05))
    C.box((0.16, 0.24, 0.14), (0.04, 0, -0.04), M["red"], h, bevel=0.05)  # jaw
    C.box((0.08, 0.2, 0.04), (0.12, 0, 0.03), M["visor"], h, bevel=0.015)  # visor slit
    C.box((0.26, 0.04, 0.05), (-0.02, 0, 0.14), M["red"], h, bevel=0.015)  # crest
    return root, t


def _arm(M, parent, shoulder, hand, side):
    shoulder, hand = Vector(shoulder), Vector(hand)
    d = hand - shoulder
    L = d.length
    a, b = 0.31, 0.31
    L = min(L, a + b - 0.01)
    # elbow pushed down and outward
    mid = shoulder + d * 0.5
    h = math.sqrt(max(0.0, a * a - (L * 0.5) ** 2))
    out = Vector((0, side, -0.9)).normalized()
    out = (out - d.normalized() * out.dot(d.normalized())).normalized()
    elbow = mid + out * h
    C.tube_between(shoulder, elbow, 0.065, M["suit"], parent, name="uarm")
    C.tube_between(elbow, hand, 0.06, M["suit"], parent, name="farm")
    # armour plates
    up = (elbow - shoulder)
    C.box((0.1, 0.1, up.length * 0.8), (shoulder + elbow) / 2, M["red"], parent, bevel=0.025,
          rot=up.to_track_quat("Z", "Y").to_euler())
    fa = (hand - elbow)
    C.box((0.11, 0.11, fa.length * 0.75), elbow + fa * 0.45, M["dark"], parent, bevel=0.025,
          rot=fa.to_track_quat("Z", "Y").to_euler())
    C.sphere(0.06, hand, M["dark"], parent, segs=12)


def build_weapon(kind, M, parent):
    """Weapons held along +X at the right side. Returns (muzzle, right_hand, left_hand) in torso space."""
    g = C.empty("gun_" + kind, (0, -0.12, 0.3), parent)
    if kind == "rifle":
        C.box((0.62, 0.08, 0.12), (0.32, 0, 0), M["gun_white"], g, bevel=0.02)
        C.box((0.34, 0.06, 0.06), (0.75, 0, 0.02), M["gun_dark"], g, bevel=0.01)  # barrel shroud
        C.cyl(0.022, 0.2, (0.98, 0, 0.02), M["steel"], g, rot=(0, math.pi / 2, 0), verts=10)
        C.box((0.42, 0.012, 0.03), (0.45, 0.042, 0.02), M["glow"], g, bevel=0.0)
        C.box((0.42, 0.012, 0.03), (0.45, -0.042, 0.02), M["glow"], g, bevel=0.0)
        C.box((0.12, 0.05, 0.16), (0.36, 0, -0.12), M["gun_dark"], g, bevel=0.01, rot=(0, 0.2, 0))  # mag
        C.box((0.1, 0.05, 0.06), (0.32, 0, 0.1), M["gun_dark"], g, bevel=0.01)  # sight
        C.box((0.2, 0.06, 0.1), (0.02, 0, -0.03), M["gun_dark"], g, bevel=0.02)  # stock
        muzzle, rh, lh = (1.08, 0, 0.02), (0.18, 0, -0.05), (0.56, 0, -0.04)
    elif kind == "shotgun":
        C.box((0.5, 0.13, 0.15), (0.28, 0, 0), M["gun_dark"], g, bevel=0.03)
        for s in (-1, 1):
            C.cyl(0.04, 0.46, (0.68, 0.035 * s, 0.03), M["steel"], g, rot=(0, math.pi / 2, 0), verts=12)
        C.box((0.24, 0.15, 0.09), (0.62, 0, -0.05), M["gun_red"], g, bevel=0.03)  # pump
        C.box((0.05, 0.155, 0.04), (0.45, 0, 0.07), M["orange"], g, bevel=0.0)
        C.box((0.22, 0.08, 0.12), (0.0, 0, -0.04), M["gun_red"], g, bevel=0.03)
        muzzle, rh, lh = (0.92, 0, 0.03), (0.16, 0, -0.05), (0.62, 0, -0.08)
    elif kind == "arc":
        C.box((0.46, 0.14, 0.16), (0.24, 0, 0), M["gun_dark"], g, bevel=0.03)
        C.cyl(0.07, 0.36, (0.5, 0, 0.02), M["steel"], g, rot=(0, math.pi / 2, 0), verts=16)
        for i in range(3):
            C.torus(0.085, 0.018, (0.4 + i * 0.1, 0, 0.02), M["violet"], g, rot=(0, math.pi / 2, 0), seg=20, mseg=6)
        for s in (-1, 1):
            C.box((0.22, 0.025, 0.03), (0.78, 0.05 * s, 0.02), M["steel"], g, bevel=0.005, rot=(0, 0, -0.15 * s))
        C.sphere(0.04, (0.86, 0, 0.02), M["violet"], g, segs=12)
        C.cyl(0.05, 0.2, (0.12, 0, 0.12), M["glow"], g, rot=(0, math.pi / 2, 0), verts=12)  # cell
        muzzle, rh, lh = (0.9, 0, 0.02), (0.14, 0, -0.06), (0.46, 0, -0.08)
    elif kind == "rail":
        C.box((0.7, 0.08, 0.1), (0.38, 0, 0), M["gun_white"], g, bevel=0.02)
        C.box((0.6, 0.03, 0.04), (0.8, 0.03, 0.0), M["gun_red"], g, bevel=0.008)
        C.box((0.6, 0.03, 0.04), (0.8, -0.03, 0.0), M["gun_red"], g, bevel=0.008)
        C.box((0.56, 0.012, 0.02), (0.82, 0, 0.0), M["visor"], g, bevel=0.0)
        C.cyl(0.05, 0.16, (0.32, 0, 0.1), M["gun_dark"], g, rot=(0, math.pi / 2, 0), verts=14)  # scope
        C.box((0.2, 0.06, 0.12), (0.0, 0, -0.03), M["gun_dark"], g, bevel=0.02)
        muzzle, rh, lh = (1.12, 0, 0.0), (0.18, 0, -0.05), (0.58, 0, -0.04)
    gl = Vector(g.location)
    return (gl + Vector(muzzle), gl + Vector(rh), gl + Vector(lh), g)


# ---------------------------------------------------------------- render

def render_legs():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    root, pelvis, legs = build_legs(M)
    fw, fh, org = LEGS_FRAME
    C.setup_camera(fw, fh, org)
    cols = RUN_FRAMES + 1
    sw = C.SheetWriter("player", "player_legs", fw, fh, org, LEG_DIRS, cols,
                       meta={"dirs": LEG_DIRS, "anims": {"run": [0, RUN_FRAMES], "idle": [RUN_FRAMES, 1]}})
    bobs = []
    for f in range(RUN_FRAMES):
        bobs.append(pose_legs(pelvis, legs, f / RUN_FRAMES))
    sw.meta["bob_m"] = bobs
    for d in range(LEG_DIRS):
        phi = d * 2 * math.pi / LEG_DIRS
        root.rotation_euler = (0, 0, C.yaw_for_ground_angle(phi))
        for f in range(cols):
            if f < RUN_FRAMES:
                pose_legs(pelvis, legs, f / RUN_FRAMES)
            else:
                pose_legs(pelvis, legs, 0, idle=True)
            sw.put(d, f, C.render_passes())
        print("legs dir", d)
    sw.save()


def render_torsos(kinds=("rifle", "shotgun", "arc", "rail")):
    for kind in kinds:
        C.reset_scene()
        C.setup_lights()
        M = materials()
        root, t = build_torso(M)
        muzzle, rh, lh, g = build_weapon(kind, M, t)
        _arm(M, t, (0.0, -0.3, 0.52), rh, -1)
        _arm(M, t, (0.0, 0.3, 0.52), lh, 1)
        fw, fh, org = TORSO_FRAME
        C.setup_camera(fw, fh, org)
        cols = 8
        rows = TORSO_DIRS // cols
        tz = t.location.z
        mz = (muzzle[0], muzzle[1], muzzle[2] + tz)
        sw = C.SheetWriter("player", "player_torso_" + kind, fw, fh, org, rows, cols,
                           meta={"dirs": TORSO_DIRS, "layout": "grid", "muzzle_m": list(mz)})
        for d in range(TORSO_DIRS):
            phi = d * 2 * math.pi / TORSO_DIRS
            root.rotation_euler = (0, 0, C.yaw_for_ground_angle(phi))
            sw.put(d // cols, d % cols, C.render_passes())
        sw.save()
        print("torso", kind, "done")


if __name__ == "__main__":
    import sys
    what = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["legs", "torso"]
    if "legs" in what:
        render_legs()
    if "torso" in what:
        render_torsos()
