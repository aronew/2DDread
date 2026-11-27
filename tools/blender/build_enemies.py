"""Underworld enemy roster, ink/cel-shaded, 16 directions, one sheet per animation.

Gameplay roles (ids in data/enemies stay stable):
  hound  -> mite     fast flanking swarmer, pounce bite
  witch  -> spitter  floating caster, crystal shard volleys
  legion -> brute    shield-wall heavy, overhead sword slam
  skull  -> bloater  flying flaming skull that detonates
"""
import math
import random
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

DIRS = 16


def materials():
    return {
        "fur": C.mat("e_fur", (0.11, 0.09, 0.1), rough=0.8),
        "fur2": C.mat("e_fur2", (0.2, 0.12, 0.12), rough=0.8),
        "ember": C.mat("e_ember", (0.9, 0.3, 0.08), emit=(1.0, 0.38, 0.1), emit_strength=6),
        "eye_r": C.mat("e_eye_r", (1.0, 0.15, 0.1), emit=(1.0, 0.2, 0.12), emit_strength=9),
        "bone": C.mat("e_bone", (0.86, 0.8, 0.66), rough=0.5),
        "bone_dk": C.mat("e_bone_dk", (0.52, 0.46, 0.36), rough=0.6),
        "teeth": C.mat("e_teeth", (0.95, 0.92, 0.82), rough=0.4),
        "robe": C.mat("e_robe", (0.5, 0.06, 0.2), rough=0.7),
        "robe_dk": C.mat("e_robe_dk", (0.22, 0.05, 0.16), rough=0.75),
        "mask": C.mat("e_mask", (0.9, 0.86, 0.8), rough=0.4),
        "gold": C.mat("e_gold", (0.95, 0.66, 0.22), metal=1.0, rough=0.25),
        "bronze": C.mat("e_bronze", (0.36, 0.25, 0.12), metal=0.6, rough=0.45),
        "steel": C.mat("e_steel", (0.62, 0.66, 0.7), metal=0.9, rough=0.25),
        "crest": C.mat("e_crest", (0.75, 0.08, 0.07), rough=0.7),
        "rag": C.mat("e_rag", (0.07, 0.22, 0.2), rough=0.85),
        "orb": C.mat("e_orb", (1.0, 0.2, 0.25), emit=(1.0, 0.22, 0.3), emit_strength=8),
        "ghost": C.mat("e_ghost", (0.35, 1.0, 0.6), emit=(0.4, 1.0, 0.6), emit_strength=7),
        "ghost2": C.mat("e_ghost2", (0.2, 0.85, 0.5), emit=(0.25, 0.95, 0.5), emit_strength=4),
        "dark": C.mat("e_dark", (0.04, 0.03, 0.04), rough=0.9),
    }


def _limb(parent, p0, p1, r0, r1, mat, name="limb"):
    C.tube_between(p0, p1, r0, mat, parent, r2=r1, name=name)
    C.sphere(r1 * 1.1, p1, mat, parent, segs=10)


# =================================================================== HELLHOUND

def hound(M):
    root = C.empty("hound")
    body = C.empty("body", (0, 0, 0.62), root)
    C.sphere(0.24, (0.16, 0, 0.02), M["fur"], body, scale=(1.35, 1.0, 1.1), subsurf=1)
    C.sphere(0.2, (-0.26, 0, 0.0), M["fur"], body, scale=(1.35, 0.9, 0.95), subsurf=1)
    for i in range(6):  # spiky mane along the spine
        x = 0.3 - i * 0.12
        C.cyl(0.06, 0.24 - i * 0.02, (x, 0, 0.24 - i * 0.015), M["fur2"], body, r2=0.0, verts=6,
              rot=(0, -0.9, 0), smooth=False)
    for s in (-1, 1):  # glowing ember cracks on the flanks
        C.box((0.34, 0.01, 0.03), (0.0, 0.19 * s, 0.04), M["ember"], body, bevel=0.0, rot=(0.0, 0.3, 0.1 * s))
        C.box((0.2, 0.01, 0.025), (-0.24, 0.17 * s, -0.02), M["ember"], body, bevel=0.0, rot=(0.0, -0.4, 0))
    head = C.empty("head", (0.46, 0, 0.12), body)
    C.wedge((0.3, 0.22, 0.2), (0.0, 0, 0.0), M["fur"], head, taper=(0.8, 0.8), bevel=0.05)
    C.wedge((0.24, 0.15, 0.12), (0.2, 0, -0.03), M["fur2"], head, taper=(0.7, 0.7), bevel=0.03)
    jaw = C.empty("jaw", (0.08, 0, -0.07), head)
    C.wedge((0.24, 0.13, 0.06), (0.11, 0, -0.02), M["fur2"], jaw, taper=(0.8, 0.8), bevel=0.02)
    for s in (-1, 1):
        C.sphere(0.035, (0.12, 0.08 * s, 0.05), M["eye_r"], head, segs=8)
        C.cyl(0.04, 0.2, (-0.06, 0.08 * s, 0.14), M["bone"], head, r2=0.0, verts=8, rot=(0.4 * s, -0.7, 0))
        C.cyl(0.014, 0.06, (0.27, 0.04 * s, -0.08), M["teeth"], head, r2=0.0, verts=6, rot=(math.pi, 0, 0))
        C.cyl(0.012, 0.05, (0.2, 0.04 * s, 0.0), M["teeth"], jaw, r2=0.0, verts=6)
    legs = []
    for (x, front) in ((0.24, True), (-0.3, False)):
        for s in (-1, 1):
            hip = C.empty("hip", (x, 0.13 * s, -0.08), body)
            knee_p = Vector((0.06 if front else -0.08, 0.02 * s, -0.26))
            _limb(hip, (0, 0, 0), knee_p, 0.07 if front else 0.08, 0.05, M["fur"])
            knee = C.empty("knee", knee_p, hip)
            paw_p = Vector((-0.04 if front else 0.08, 0, -0.27))
            _limb(knee, (0, 0, 0), paw_p, 0.045, 0.04, M["fur"])
            C.box((0.12, 0.08, 0.05), paw_p + Vector((0.04, 0, -0.02)), M["fur2"], knee, bevel=0.02)
            legs.append((hip, knee, front, s))
    tail = C.empty("tail", (-0.48, 0, 0.06), body)
    _limb(tail, (0, 0, 0), (-0.22, 0, 0.16), 0.05, 0.03, M["fur"])
    C.cyl(0.07, 0.22, (-0.3, 0, 0.26), M["ember"], tail, r2=0.0, verts=8, rot=(0, -0.6, 0))
    return root, {"body": body, "head": head, "jaw": jaw, "legs": legs, "tail": tail}


def hound_run(R, t):
    p = t * 2 * math.pi
    for hip, knee, front, s in R["legs"]:
        q = p + (0.0 if front else math.pi * 0.9) + (0.25 if s > 0 else 0.0)
        hip.rotation_euler = (0, -0.75 * math.sin(q), 0)
        knee.rotation_euler = (0, (0.5 if front else -0.6) * max(0.0, math.cos(q)), 0)
    R["body"].location.z = 0.62 + 0.05 * math.cos(2 * p)
    R["body"].rotation_euler = (0, 0.09 * math.sin(p), 0)
    R["head"].rotation_euler = (0, -0.08 * math.sin(p), 0)
    R["jaw"].rotation_euler = (0, 0.15 + 0.1 * math.sin(p * 2), 0)
    R["tail"].rotation_euler = (0.3 * math.sin(p), 0.2, 0)


def hound_bite(R, t):
    # crouch (telegraph) -> leap with jaws open -> land
    if t < 0.45:
        k = t / 0.45
        z, pitch, fwd, jaw, leg = 0.62 - 0.14 * k, 0.15 * k, -0.05 * k, 0.2 + 0.4 * k, 0.4 * k
    elif t < 0.75:
        k = (t - 0.45) / 0.3
        z, pitch, fwd, jaw, leg = 0.48 + 0.22 * math.sin(k * math.pi), 0.15 - 0.35 * k, -0.05 + 0.4 * k, 0.6 - 0.5 * k, -0.9
    else:
        k = (t - 0.75) / 0.25
        z, pitch, fwd, jaw, leg = 0.62, -0.2 * (1 - k), 0.35 * (1 - k), 0.1, 0.0
    R["body"].location = (fwd, 0, z)
    R["body"].rotation_euler = (0, pitch, 0)
    R["jaw"].rotation_euler = (0, jaw, 0)
    for hip, knee, front, s in R["legs"]:
        hip.rotation_euler = (0, leg if front else -leg * 0.6, 0)
        knee.rotation_euler = (0, 0.4 if front else -0.5, 0)


# =================================================================== HEX WITCH

def witch(M):
    root = C.empty("witch")
    body = C.empty("body", (0, 0, 0.55), root)
    C.cyl(0.42, 1.0, (0, 0, 0.35), M["robe"], body, r2=0.16, verts=24, bevel=0.02)
    C.torus(0.4, 0.035, (0, 0, -0.1), M["gold"], body, seg=28, mseg=6)
    rng = random.Random(5)
    for i in range(9):  # tattered hem
        a = i * 2 * math.pi / 9
        C.box((0.16, 0.04, 0.16), (0.41 * math.cos(a), 0.41 * math.sin(a), -0.17 - rng.random() * 0.04), M["robe_dk"],
              body, bevel=0.01, rot=(0.0, 0.5, a))
    C.wedge((0.26, 0.36, 0.38), (0, 0, 0.98), M["robe_dk"], body, taper=(0.75, 0.7), bevel=0.04)
    cape = C.empty("cape", (-0.1, 0, 1.12), body)
    C.wedge((0.05, 0.7, 1.25), (-0.08, 0, -0.55), M["robe"], cape, taper=(1.0, 0.55), bevel=0.02)
    for s in (-1, 1):
        C.sphere(0.12, (0, 0.2 * s, 1.14), M["gold"], body, scale=(1.1, 1.0, 0.6))
        C.cyl(0.04, 0.2, (0, 0.27 * s, 1.24), M["gold"], body, r2=0.0, verts=6, rot=(0.6 * s, 0, 0))
    head = C.empty("head", (0.02, 0, 1.36), body)
    C.sphere(0.15, (-0.03, 0, 0.02), M["robe_dk"], head, scale=(1.0, 1.0, 1.15))  # hood
    C.sphere(0.11, (0.05, 0, 0.0), M["mask"], head, scale=(0.8, 0.85, 1.05))  # mask
    for s in (-1, 1):
        C.box((0.02, 0.035, 0.012), (0.14, 0.04 * s, 0.03), M["orb"], head, bevel=0.0)
        C.cyl(0.03, 0.28, (0.0, 0.09 * s, 0.2), M["gold"], head, r2=0.0, verts=8, rot=(-0.45 * s, -0.15, 0))
    C.torus(0.2, 0.014, (-0.1, 0, 0.12), M["gold"], head, rot=(0, math.pi / 2 - 0.2, 0), seg=28, mseg=6)  # halo
    for i in range(7):
        a = -math.pi * 0.9 + i * (math.pi * 1.8 / 6)
        C.cyl(0.018, 0.1, (-0.1, 0.24 * math.cos(a), 0.12 + 0.24 * math.sin(a)), M["gold"], head, r2=0.0, verts=6,
              rot=(-a + math.pi / 2, 0, 0))
    arm = C.empty("arm", (0.05, -0.22, 1.12), body)
    _limb(arm, (0, 0, 0), (0.34, -0.06, -0.1), 0.06, 0.05, M["robe_dk"])
    orb = C.empty("orb", (0.42, -0.07, -0.1), arm)
    C.sphere(0.09, (0, 0, 0), M["orb"], orb, segs=14)
    C.torus(0.12, 0.012, (0, 0, 0), M["gold"], orb, rot=(0.5, 0.3, 0), seg=20, mseg=6)
    arm2 = C.empty("arm2", (0.0, 0.22, 1.12), body)
    _limb(arm2, (0, 0, 0), (0.12, 0.1, -0.32), 0.06, 0.05, M["robe_dk"])
    return root, {"body": body, "cape": cape, "arm": arm, "orb": orb, "head": head}


def witch_float(R, t):
    p = t * 2 * math.pi
    R["body"].location.z = 0.55 + 0.07 * math.sin(p)
    R["cape"].rotation_euler = (0.06 * math.sin(p + 1), 0.25 + 0.08 * math.sin(p), 0)
    R["arm"].rotation_euler = (0, 0.1 * math.sin(p), 0)
    s = 1.0 + 0.1 * math.sin(p * 2)
    R["orb"].scale = (s, s, s)


def witch_cast(R, t):
    if t < 0.55:
        k = t / 0.55
        arm, orb, lean = -1.4 * k, 1.0 + 0.6 * k, -0.15 * k
    elif t < 0.72:
        k = (t - 0.55) / 0.17
        arm, orb, lean = -1.4 + 1.7 * k, 1.6 - 0.4 * k, -0.15 + 0.3 * k
    else:
        k = (t - 0.72) / 0.28
        arm, orb, lean = 0.3 * (1 - k), 1.2 - 0.2 * k, 0.15 * (1 - k)
    R["arm"].rotation_euler = (0, arm, 0)
    R["orb"].scale = (orb, orb, orb)
    R["body"].rotation_euler = (0, lean, 0)
    R["body"].location.z = 0.55
    R["cape"].rotation_euler = (0, 0.3 + 0.2 * k, 0)


# =================================================================== SHADE LEGIONNAIRE

def legion(M):
    root = C.empty("legion")
    body = C.empty("body", (0, 0, 1.15), root)
    # ribcage glimpsed under the cuirass, ghost fire inside
    C.sphere(0.2, (-0.02, 0, 0.32), M["ghost2"], body, scale=(1.0, 1.2, 1.2))
    C.wedge((0.36, 0.56, 0.5), (0.02, 0, 0.38), M["bronze"], body, taper=(0.85, 0.8), bevel=0.05)
    for z in (0.22, 0.38, 0.54):
        C.box((0.38, 0.58, 0.025), (0.02, 0, z), M["gold"], body, bevel=0.008)
    C.box((0.22, 0.5, 0.3), (0, 0, 0.02), M["rag"], body, bevel=0.03)  # tunic
    for i in range(6):  # pteruges (leather strips)
        a = -1.2 + i * 0.48
        C.box((0.06, 0.1, 0.32), (0.22 * math.cos(a), 0.26 * math.sin(a), -0.16), M["bronze"], body, bevel=0.01,
              rot=(0, 0, a))
    for s in (-1, 1):
        C.sphere(0.17, (0, 0.34 * s, 0.6), M["bronze"], body, scale=(1.2, 1.0, 0.7))
        C.torus(0.15, 0.015, (0, 0.34 * s, 0.6), M["gold"], body, rot=(0.4 * s, 0, 0), seg=20, mseg=6)
    head = C.empty("head", (0.04, 0, 0.84), body)
    C.sphere(0.15, (0, 0, 0), M["bone"], head, scale=(1.1, 0.95, 1.1))
    for s in (-1, 1):
        C.sphere(0.04, (0.12, 0.05 * s, 0.02), M["ghost"], head, segs=8)
    C.box((0.08, 0.14, 0.05), (0.12, 0, -0.1), M["bone_dk"], head, bevel=0.015)  # jaw
    helm = C.empty("helm", (0, 0, 0.04), head)
    C.sphere(0.18, (-0.01, 0, 0.03), M["bronze"], helm, scale=(1.1, 1.0, 1.05))
    C.box((0.03, 0.08, 0.2), (0.16, 0.08, -0.05), M["bronze"], helm, bevel=0.01)
    C.box((0.03, 0.08, 0.2), (0.16, -0.08, -0.05), M["bronze"], helm, bevel=0.01)
    C.box((0.42, 0.06, 0.16), (-0.04, 0, 0.24), M["crest"], helm, bevel=0.03)
    C.box((0.44, 0.07, 0.03), (-0.04, 0, 0.16), M["gold"], helm, bevel=0.008)
    # shield arm (left) — the tower shield covers the front: this IS the frontal armour
    sh = C.empty("shield_arm", (0.1, 0.36, 0.5), body)
    _limb(sh, (0, 0, 0), (0.28, -0.05, -0.28), 0.06, 0.05, M["bone"])
    shield = C.empty("shield", (0.42, -0.12, -0.32), sh)
    C.box((0.08, 0.62, 1.1), (0, 0, 0), M["bronze"], shield, bevel=0.04)
    C.box((0.085, 0.66, 0.05), (0, 0, 0.53), M["gold"], shield, bevel=0.01)
    C.box((0.085, 0.66, 0.05), (0, 0, -0.53), M["gold"], shield, bevel=0.01)
    C.torus(0.16, 0.025, (0.05, 0, 0.08), M["gold"], shield, rot=(0, math.pi / 2, 0), seg=24, mseg=6)
    C.sphere(0.08, (0.06, 0, 0.08), M["ghost"], shield, segs=12, scale=(0.5, 1, 1))
    # sword arm (right)
    sw = C.empty("sword_arm", (0.0, -0.36, 0.52), body)
    _limb(sw, (0, 0, 0), (0.2, -0.08, -0.4), 0.06, 0.05, M["bone"])
    blade = C.empty("blade", (0.22, -0.08, -0.44), sw)
    C.box((0.08, 0.1, 0.04), (0, 0, 0), M["gold"], blade, bevel=0.01)
    C.box((0.86, 0.09, 0.02), (0.48, 0, 0), M["steel"], blade, bevel=0.008)
    C.box((0.84, 0.012, 0.025), (0.48, 0, 0), M["ghost2"], blade, bevel=0.0)
    legs = []
    for s in (-1, 1):
        hip = C.empty("hip", (-0.02, 0.15 * s, -0.12), body)
        _limb(hip, (0, 0, 0), (0.04, 0.02 * s, -0.48), 0.07, 0.055, M["bone"])
        knee = C.empty("knee", (0.04, 0.02 * s, -0.48), hip)
        _limb(knee, (0, 0, 0), (-0.02, 0, -0.46), 0.05, 0.045, M["bone"])
        C.wedge((0.12, 0.13, 0.36), (0.04, 0, -0.22), M["bronze"], knee, taper=(0.8, 0.85), bevel=0.02)
        C.box((0.24, 0.12, 0.07), (0.05, 0, -0.5), M["bronze"], knee, bevel=0.02)
        legs.append((hip, knee, s))
    return root, {"body": body, "head": head, "sh": sh, "sw": sw, "legs": legs}


def legion_walk(R, t):
    p = t * 2 * math.pi
    for hip, knee, s in R["legs"]:
        q = p + (0 if s > 0 else math.pi)
        hip.rotation_euler = (0, -0.42 * math.sin(q), 0)
        knee.rotation_euler = (0, 0.5 * max(0.0, math.cos(q)), 0)
    R["body"].location.z = 1.15 + 0.04 * math.cos(2 * p)
    R["body"].rotation_euler = (0.04 * math.sin(p), 0.06, 0)
    R["sw"].rotation_euler = (0, 0.25 * math.sin(p), 0)
    R["sh"].rotation_euler = (0, 0.05 * math.sin(p), 0)


def legion_slam(R, t):
    # sword raised overhead (telegraph) -> smash -> recover; shield stays up
    if t < 0.5:
        k = math.sin(t / 0.5 * math.pi / 2)
        arm, lean = -2.6 * k, -0.2 * k
    elif t < 0.65:
        k = (t - 0.5) / 0.15
        arm, lean = -2.6 + 3.1 * k, -0.2 + 0.5 * k
    else:
        k = (t - 0.65) / 0.35
        arm, lean = 0.5 - 0.5 * k, 0.3 * (1 - k)
    R["sw"].rotation_euler = (0, arm, 0)
    R["body"].rotation_euler = (0, lean, 0)
    R["body"].location.z = 1.15 - 0.1 * max(0.0, lean)
    R["sh"].rotation_euler = (0, -0.1, 0)
    for hip, knee, s in R["legs"]:
        hip.rotation_euler = (0, -0.25 * s, 0)
        knee.rotation_euler = (0, 0.25, 0)


# =================================================================== FLAMING SKULL

def skull(M):
    root = C.empty("skull")
    body = C.empty("body", (0, 0, 1.2), root)
    C.sphere(0.27, (0, 0, 0.04), M["bone"], body, scale=(1.15, 0.95, 1.0), subsurf=1)
    C.box((0.18, 0.3, 0.16), (0.16, 0, -0.1), M["bone"], body, bevel=0.05)
    for s in (-1, 1):
        C.sphere(0.075, (0.24, 0.1 * s, 0.03), M["dark"], body, segs=12)
        C.sphere(0.035, (0.27, 0.1 * s, 0.03), M["ghost"], body, segs=8)
    C.cyl(0.03, 0.06, (0.31, 0, -0.06), M["dark"], body, r2=0.0, verts=6, rot=(0, math.pi / 2, 0))
    for i in range(6):
        C.box((0.03, 0.035, 0.05), (0.27, -0.09 + i * 0.036, -0.17), M["teeth"], body, bevel=0.005)
    jaw = C.empty("jaw", (0.08, 0, -0.18), body)
    C.box((0.2, 0.28, 0.06), (0.1, 0, -0.03), M["bone_dk"], jaw, bevel=0.025)
    for i in range(5):
        C.box((0.03, 0.035, 0.045), (0.19, -0.07 + i * 0.035, 0.015), M["teeth"], jaw, bevel=0.005)
    flames = C.empty("flames", (0, 0, 0), body)
    return root, {"body": body, "jaw": jaw, "flames": flames, "M": M}


def _skull_flames(R, t, power):
    for ob in list(R["flames"].children):
        C.bpy.data.objects.remove(ob, do_unlink=True)
    rng = random.Random(int(t * 1000) + 7)
    M = R["M"]
    for i in range(11):
        a = i * 2 * math.pi / 11 + rng.uniform(-0.2, 0.2)
        r = 0.22 + rng.uniform(0, 0.05)
        h = (0.28 + rng.uniform(0, 0.22)) * power
        pos = (-0.06 + r * 0.6 * math.cos(a) - 0.05, r * math.sin(a), 0.16 + 0.08 * math.cos(a))
        C.cyl(0.08 * power, h, pos, M["ghost2"] if i % 3 else M["ghost"], R["flames"], r2=0.0, verts=8,
              rot=(rng.uniform(-0.3, 0.3), -0.9 + rng.uniform(-0.25, 0.25), 0))
    for i in range(3):  # trailing tail
        C.cyl(0.12 * power * (1 - i * 0.25), 0.36 * power, (-0.28 - i * 0.16, rng.uniform(-0.05, 0.05), 0.1 + i * 0.05),
              M["ghost2"], R["flames"], r2=0.0, verts=8, rot=(0, -1.25, 0))


def skull_fly(R, t):
    p = t * 2 * math.pi
    R["body"].location.z = 1.2 + 0.07 * math.sin(p)
    R["body"].rotation_euler = (0.08 * math.sin(p), 0.05, 0)
    R["jaw"].rotation_euler = (0, 0.12 + 0.12 * max(0.0, math.sin(p * 2)), 0)
    _skull_flames(R, t, 1.0)


def skull_prime(R, t):
    p = t * 2 * math.pi
    R["body"].location = (0.03 * math.sin(p * 3), 0.03 * math.cos(p * 5), 1.2)
    R["jaw"].rotation_euler = (0, 0.55, 0)
    _skull_flames(R, t + 0.37, 1.45)


ENEMIES = {
    # name: (builder, frame (w,h,origin), {anim: (frames, pose_fn)})
    "hound": (hound, (200, 184, (100, 126)), {"run": (8, hound_run), "attack": (6, hound_bite)}),
    "witch": (witch, (200, 264, (100, 224)), {"float": (6, witch_float), "attack": (6, witch_cast)}),
    "legion": (legion, (272, 360, (136, 274)), {"walk": (8, legion_walk), "attack": (7, legion_slam)}),
    "skull": (skull, (176, 216, (88, 184)), {"fly": (6, skull_fly), "attack": (4, skull_prime)}),
}


def render_enemy(name):
    build, (fw, fh, org), anims = ENEMIES[name]
    for anim, (nf, pose) in anims.items():
        C.reset_scene()
        C.setup_lights()
        M = materials()
        root, R = build(M)
        C.setup_camera(fw, fh, org)
        sw = C.SheetWriter("enemies", "%s_%s" % (name, anim), fw, fh, org, DIRS, nf,
                           meta={"dirs": DIRS, "frames": nf, "anim": anim})
        for d in range(DIRS):
            root.rotation_euler = (0, 0, C.yaw_for_ground_angle(d * 2 * math.pi / DIRS))
            for f in range(nf):
                pose(R, f / nf)
                sw.put(d, f, C.render_stylized())
            print(name, anim, "dir", d, flush=True)
        sw.save()


if __name__ == "__main__":
    import sys
    what = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ENEMIES.keys())
    for n in what:
        render_enemy(n)
