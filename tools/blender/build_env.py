"""Modular environment kit: floor slabs, wall blocks, low blocks, props.

Grid: 1 cell = 2 m x 2 m.  Godot isometric TileMap cell = 256 x 192 px diamond.
"""
import math
import random
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

CELL = 2.0
FLOOR_FRAME = (264, 240, (132, 100))
WALL_FRAME = (260, 388, (130, 286))
LOW_FRAME = (260, 276, (130, 174))


def materials():
    return {
        "deck": C.mat("v_deck", (0.075, 0.09, 0.095), metal=0.4, rough=0.55, noise=0.6, noise_scale=6,
                      noise_color=(0.035, 0.045, 0.05), bump=0.25),
        "deck2": C.mat("v_deck2", (0.09, 0.105, 0.11), metal=0.4, rough=0.5, noise=0.5, noise_scale=9,
                       noise_color=(0.045, 0.055, 0.06), bump=0.2),
        "deck_dark": C.mat("v_deckd", (0.02, 0.025, 0.028), metal=0.6, rough=0.6),
        "rust": C.mat("v_rust", (0.12, 0.07, 0.05), metal=0.5, rough=0.6, noise=0.8, noise_scale=5,
                      noise_color=(0.03, 0.035, 0.04), bump=0.6),
        "trim": C.mat("v_trim", (0.3, 0.32, 0.34), metal=0.9, rough=0.3),
        "yellow": C.mat("v_yellow", (0.75, 0.5, 0.03), metal=0.2, rough=0.45, noise=0.4, noise_scale=12,
                        noise_color=(0.2, 0.14, 0.02)),
        "black": C.mat("v_black", (0.015, 0.015, 0.017), metal=0.3, rough=0.5),
        "void": C.mat("v_void", (0.012, 0.014, 0.016), metal=0.0, rough=0.95, spec=0.05),
        "cyan": C.mat("v_cyan", (0.05, 0.4, 0.45), emit=(0.15, 0.85, 1.0), emit_strength=6),
        "side_light": C.mat("v_sidel", (0.1, 0.55, 0.6), metal=0.2, rough=0.3),
        "maroon_dim": C.mat("v_maroond", (0.3, 0.05, 0.05), metal=0.4, rough=0.3, coat=0.4),
        "teal": C.mat("v_teal", (0.03, 0.3, 0.25), emit=(0.1, 0.9, 0.65), emit_strength=4),
        "red_glow": C.mat("v_redg", (0.5, 0.03, 0.03), emit=(1.0, 0.12, 0.08), emit_strength=6),
        "purple": C.mat("v_purple", (0.3, 0.06, 0.45), emit=(0.7, 0.2, 1.0), emit_strength=6),
        "amber": C.mat("v_amber", (0.6, 0.3, 0.02), emit=(1.0, 0.55, 0.12), emit_strength=6),
        "ivory": C.mat("v_ivory", (0.62, 0.6, 0.56), metal=0.1, rough=0.35, coat=0.35, noise=0.25,
                       noise_scale=8, noise_color=(0.42, 0.4, 0.37)),
        "maroon": C.mat("v_maroon", (0.22, 0.03, 0.035), metal=0.3, rough=0.35, coat=0.3),
        "copper": C.mat("v_copper", (0.35, 0.14, 0.07), metal=0.95, rough=0.32, noise=0.5, noise_scale=10,
                        noise_color=(0.12, 0.07, 0.05)),
        "glass": C.mat("v_glass", (0.05, 0.25, 0.3), metal=0.0, rough=0.05, emit=(0.2, 0.75, 0.9),
                       emit_strength=2.2, noise=0.7, noise_scale=14, noise_color=(0.02, 0.12, 0.14)),
        "bio": C.mat("v_bio", (0.3, 0.04, 0.08), rough=0.25, subsurface=0.2, noise=0.7, noise_scale=6,
                     noise_color=(0.1, 0.01, 0.04), bump=0.8, coat=0.5),
        "bio_glow": C.mat("v_biog", (0.15, 0.45, 0.2), emit=(0.2, 0.6, 0.25), emit_strength=0.6),
        "rock": C.mat("v_rock", (0.06, 0.075, 0.075), metal=0.0, rough=0.85, noise=0.8, noise_scale=4,
                      noise_color=(0.02, 0.03, 0.03), bump=1.0),
        "crystal": C.mat("v_crystal", (0.1, 0.5, 0.6), rough=0.1, emit=(0.2, 0.9, 1.0), emit_strength=4),
        "rubber": C.mat("v_rubber", (0.03, 0.03, 0.035), rough=0.8),
        "redpaint": C.mat("v_redpaint", (0.45, 0.04, 0.03), metal=0.4, rough=0.4, noise=0.5, noise_scale=7,
                          noise_color=(0.15, 0.05, 0.03)),
        "olive": C.mat("v_olive", (0.14, 0.15, 0.09), metal=0.5, rough=0.5, noise=0.5, noise_scale=8,
                       noise_color=(0.06, 0.06, 0.04)),
        "egg": C.mat("v_egg", (0.25, 0.55, 0.3), rough=0.15, subsurface=0.3, emit=(0.4, 1.0, 0.55),
                     emit_strength=2.5, noise=0.7, noise_scale=5, noise_color=(0.05, 0.2, 0.1), bump=0.5),
    }


# ======================================================================= floors

def slab(M, top_mat, side_mat=None, size=CELL * 1.012):
    root = C.empty("slab")
    C.box((size, size, 0.5), (0, 0, -0.25), side_mat or M["deck_dark"], root, bevel=0.01)
    C.box((size, size, 0.04), (0, 0, -0.01), top_mat, root, bevel=0.006)
    # side detailing (only the two camera-facing sides are ever seen)
    for (dx, dy, rz) in ((size / 2, 0, 0), (0, -size / 2, math.pi / 2)):
        C.box((0.03, size * 0.9, 0.1), (dx, dy, -0.2), M["trim"], root, bevel=0.0, rot=(0, 0, rz))
        for k in (-0.6, 0.0, 0.6):
            off = Vector((0, k, 0)) if rz == 0 else Vector((k, 0, 0))
            C.box((0.03, 0.12, 0.04), Vector((dx, dy, -0.36)) + off, M["side_light"], root, bevel=0.0, rot=(0, 0, rz))
    return root


def panel_grooves(M, root, n=2):
    step = CELL / n
    for i in range(1, n):
        p = -CELL / 2 + i * step
        C.box((CELL, 0.03, 0.03), (0, p, 0.0), M["black"], root, bevel=0.0)
        C.box((0.03, CELL, 0.03), (p, 0, 0.0), M["black"], root, bevel=0.0)


def bolts(M, root, inset=0.12):
    for sx in (-1, 1):
        for sy in (-1, 1):
            C.cyl(0.03, 0.025, (sx * (CELL / 2 - inset), sy * (CELL / 2 - inset), 0.005), M["trim"], root,
                  verts=8, bevel=0.0)


def floor_variant(M, kind, rng):
    if kind == "plate":
        r = slab(M, M["deck"])
        C.box((1.6, 1.6, 0.03), (0, 0, 0.005), M["deck2"], r, bevel=0.03)
        C.box((1.3, 0.06, 0.02), (0, 0, 0.02), M["black"], r, bevel=0.0)
        bolts(M, r)
    elif kind == "plate2":
        r = slab(M, M["deck"])
        panel_grooves(M, r, 2)
        for (x, y) in ((-0.5, -0.5), (0.5, 0.5)):
            C.box((0.7, 0.7, 0.025), (x, y, 0.006), M["deck2"], r, bevel=0.02)
        for i in range(5):
            C.box((0.05, 0.4, 0.02), (0.3 + i * 0.1, -0.5, 0.01), M["black"], r, bevel=0.0)
        bolts(M, r, 0.08)
    elif kind == "grate":
        r = slab(M, M["deck_dark"])
        C.box((1.9, 1.9, 0.05), (0, 0, -0.1), M["deck_dark"], r, bevel=0.0)
        for y in (-0.45, 0.35):
            C.cyl(0.07, 1.9, (0, y, -0.06), M["teal"], r, rot=(0, math.pi / 2, 0), verts=10, bevel=0.0)
        C.cyl(0.05, 1.9, (0.4, 0, -0.07), M["copper"], r, rot=(math.pi / 2, 0, 0), verts=10, bevel=0.0)
        for i in range(-8, 9):
            C.box((1.86, 0.035, 0.05), (0, i * 0.11, 0.0), M["deck2"], r, bevel=0.0)
        for s in (-1, 1):
            C.box((CELL, 0.1, 0.06), (0, s * 0.96, 0.0), M["deck"], r, bevel=0.01)
            C.box((0.1, CELL, 0.06), (s * 0.96, 0, 0.0), M["deck"], r, bevel=0.01)
    elif kind == "hazard":
        r = slab(M, M["deck"])
        panel_grooves(M, r, 2)
        for i in range(10):
            C.box((0.12, 0.3, 0.02), (-0.9 + i * 0.2, 0.8, 0.01), M["yellow"] if i % 2 == 0 else M["black"], r,
                  bevel=0.0, rot=(0, 0, 0.6))
        C.box((CELL, 0.06, 0.03), (0, 0.6, 0.01), M["yellow"], r, bevel=0.0)
        bolts(M, r)
    elif kind == "light":
        r = slab(M, M["deck"])
        C.box((0.18, CELL, 0.03), (0, 0, 0.0), M["black"], r, bevel=0.0)
        C.box((0.08, CELL * 0.98, 0.04), (0, 0, 0.005), M["cyan"], r, bevel=0.0)
        for s in (-1, 1):
            C.box((0.7, 1.7, 0.025), (s * 0.55, 0, 0.006), M["deck2"], r, bevel=0.02)
    elif kind == "vent":
        r = slab(M, M["deck"])
        C.cyl(0.62, 0.04, (0, 0, 0.0), M["trim"], r, verts=40, bevel=0.01)
        C.cyl(0.56, 0.05, (0, 0, 0.0), M["black"], r, verts=40, bevel=0.0)
        for i in range(9):
            a = i * 2 * math.pi / 9
            C.box((0.48, 0.08, 0.015), (0.26 * math.cos(a), 0.26 * math.sin(a), 0.02), M["deck2"], r,
                  bevel=0.0, rot=(0.4, 0, a))
        C.cyl(0.1, 0.06, (0, 0, 0.03), M["red_glow"], r, verts=16, bevel=0.0)
        bolts(M, r)
    elif kind == "worn":
        r = slab(M, M["rust"])
        panel_grooves(M, r, 2)
        bolts(M, r)
        C.box((0.6, 0.5, 0.02), (0.45, -0.4, 0.01), M["deck2"], r, bevel=0.01, rot=(0, 0, 0.1))
    elif kind == "infested":
        r = slab(M, M["deck"])
        panel_grooves(M, r, 2)
        for i in range(6):
            x, y = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
            C.sphere(rng.uniform(0.25, 0.45), (x, y, -0.02), M["bio"], r, scale=(1.3, 1.0, 0.22), subsurf=1,
                     displace=0.04, rot=(0, 0, rng.uniform(0, 3)))
        for i in range(7):
            x, y = rng.uniform(-0.75, 0.75), rng.uniform(-0.75, 0.75)
            C.sphere(rng.uniform(0.04, 0.08), (x, y, 0.06), M["bio_glow"], r, segs=10)
    elif kind == "circle":
        r = slab(M, M["deck"])
        C.torus(0.72, 0.045, (0, 0, 0.0), M["maroon"], r, seg=48, mseg=6)
        C.torus(0.5, 0.025, (0, 0, 0.0), M["maroon_dim"], r, seg=48, mseg=6)
        C.torus(0.22, 0.04, (0, 0, 0.0), M["maroon"], r, seg=32, mseg=6)
    elif kind == "cables":
        r = slab(M, M["deck"])
        panel_grooves(M, r, 2)
        for i in range(4):
            y0 = -0.6 + i * 0.35
            pts = [Vector((-1.0, y0 + rng.uniform(-0.1, 0.1), 0.04)), Vector((0.0, y0 + rng.uniform(-0.25, 0.25), 0.04)),
                   Vector((1.0, y0 + rng.uniform(-0.1, 0.1), 0.04))]
            for a, b in zip(pts[:-1], pts[1:]):
                C.tube_between(a, b, 0.035 + i * 0.006, M["rubber"] if i != 2 else M["redpaint"], r)
        bolts(M, r)
    elif kind == "rockfloor":
        r = slab(M, M["rock"], M["rock"])
        for i in range(7):
            x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
            C.sphere(rng.uniform(0.12, 0.3), (x, y, -0.03), M["rock"], r, scale=(1.2, 1.0, 0.3), subsurf=1,
                     displace=0.05)
    return r


FLOOR_KINDS = ["plate", "plate2", "grate", "hazard", "light", "vent", "worn", "infested", "circle", "cables",
               "rockfloor"]


def render_floors():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    fw, fh, org = FLOOR_FRAME
    C.setup_camera(fw, fh, org)
    sw = C.SheetWriter("env", "floor_tiles", fw, fh, org, 1, len(FLOOR_KINDS), meta={"kinds": FLOOR_KINDS})
    rng = random.Random(7)
    for i, k in enumerate(FLOOR_KINDS):
        C.clear_scene_objects()
        floor_variant(M, k, rng)
        sw.put(0, i, C.render_passes())
    sw.save()


# ======================================================================= walls

H = 3.0


def _face_items(fn):
    """Call fn(origin, along, normal) for the two camera-facing faces (+X and -Y)."""
    fn(Vector((CELL / 2, 0, 0)), Vector((0, -1, 0)), Vector((1, 0, 0)))
    fn(Vector((0, -CELL / 2, 0)), Vector((1, 0, 0)), Vector((0, -1, 0)))


def _rot_for_normal(n):
    return (0, 0, math.atan2(n.y, n.x))


def wall_base(M, mat_body, cap=True):
    r = C.empty("wall")
    C.box((CELL, CELL, H), (0, 0, H / 2), mat_body, r, bevel=0.02)
    if cap:
        C.box((CELL + 0.02, CELL + 0.02, 0.14), (0, 0, H - 0.07), M["trim"], r, bevel=0.02)
        C.box((CELL * 0.94, CELL * 0.94, 0.04), (0, 0, H + 0.01), M["void"], r, bevel=0.01)
    C.box((CELL + 0.04, CELL + 0.04, 0.22), (0, 0, 0.11), M["deck_dark"], r, bevel=0.02)  # skirting
    return r


def wall_variant(M, kind, rng):
    if kind == "panel":
        r = wall_base(M, M["ivory"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.06, CELL * 0.98, 0.32), o + n * 0.02 + Vector((0, 0, 1.35)), M["maroon"], r, rot=rot, bevel=0.01)
            C.box((0.03, CELL * 0.9, 0.05), o + n * 0.05 + Vector((0, 0, 1.35)), M["red_glow"], r, rot=rot, bevel=0.0)
            for z in (0.75, 2.2):
                C.box((0.05, CELL * 0.8, 0.8), o + n * 0.01 + Vector((0, 0, z)), M["ivory"], r, rot=rot, bevel=0.06)
            C.box((0.04, 0.03, H * 0.9), o + n * 0.02 + a * (CELL * 0.48), M["black"], r, rot=rot, bevel=0.0)
        _face_items(face)
    elif kind == "pod":
        r = wall_base(M, M["deck2"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.sphere(1.0, o + n * 0.05 + Vector((0, 0, 1.45)), M["ivory"], r, scale=(0.22, 0.88, 1.35),
                     rot=rot, segs=32)
            ring_rot = (0, math.pi / 2, math.atan2(n.y, n.x))
            C.torus(0.48, 0.055, o + n * 0.25 + Vector((0, 0, 1.6)), M["maroon"], r, rot=ring_rot)
            C.torus(0.3, 0.03, o + n * 0.26 + Vector((0, 0, 1.6)), M["maroon"], r, rot=ring_rot)
            C.box((0.06, 0.5, 0.12), o + n * 0.22 + Vector((0, 0, 0.5)), M["cyan"], r, rot=rot, bevel=0.01)
        _face_items(face)
    elif kind == "machine":
        r = wall_base(M, M["deck"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            for k in (-0.5, 0.0, 0.5):
                p = o + a * k + n * 0.12
                C.cyl(0.2, H * 0.78, p + Vector((0, 0, 1.4)), M["copper"], r, verts=18, bevel=0.01)
                for z in (0.6, 1.1, 1.6, 2.1):
                    C.cyl(0.23, 0.08, p + Vector((0, 0, z)), M["deck_dark"], r, verts=18, bevel=0.0)
                C.box((0.05, 0.05, 1.8), p + n * 0.2 + Vector((0, 0, 1.4)), M["purple"], r, rot=rot, bevel=0.0)
        _face_items(face)
    elif kind == "window":
        r = wall_base(M, M["deck2"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.08, CELL * 0.82, 1.9), o + n * 0.02 + Vector((0, 0, 1.45)), M["deck_dark"], r, rot=rot, bevel=0.06)
            C.box((0.06, CELL * 0.68, 1.6), o + n * 0.05 + Vector((0, 0, 1.45)), M["glass"], r, rot=rot, bevel=0.03)
            for k in (-0.38, 0.38):
                C.box((0.05, 0.05, 1.7), o + n * 0.09 + a * k + Vector((0, 0, 1.45)), M["cyan"], r, rot=rot, bevel=0.0)
            C.box((0.1, CELL * 0.9, 0.12), o + n * 0.06 + Vector((0, 0, 0.4)), M["ivory"], r, rot=rot, bevel=0.03)
        _face_items(face)
    elif kind == "pipes":
        r = wall_base(M, M["deck"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            for k, rad, m in ((-0.6, 0.12, M["olive"]), (-0.25, 0.08, M["copper"]), (0.55, 0.15, M["olive"])):
                C.cyl(rad, H * 0.9, o + a * k + n * (rad + 0.02) + Vector((0, 0, 1.45)), m, r, verts=14, bevel=0.0)
            for z in (0.9, 2.3):
                C.cyl(0.07, CELL * 0.98, o + n * 0.32 + Vector((0, 0, z)), M["trim"], r,
                      rot=(math.pi / 2, 0, math.atan2(a.y, a.x) + math.pi / 2), verts=12, bevel=0.0)
            C.box((0.08, 0.3, 0.2), o + n * 0.06 + a * 0.15 + Vector((0, 0, 1.6)), M["amber"], r, rot=rot, bevel=0.02)
        _face_items(face)
    elif kind == "rock":
        r = C.empty("wall")
        C.box((CELL * 0.98, CELL * 0.98, H * 0.95), (0, 0, H * 0.47), M["rock"], r, bevel=0.2)
        for i in range(9):
            p = Vector((rng.uniform(-0.6, 1.0), rng.uniform(-1.0, 0.6), rng.uniform(0.3, 2.6)))
            C.sphere(rng.uniform(0.35, 0.6), p, M["rock"], r, scale=(1.0, 1.0, 1.3), subsurf=1, displace=0.15,
                     disp_scale=0.6)
        for i in range(3):
            p = Vector((rng.uniform(0.7, 1.05), rng.uniform(-1.05, -0.7), rng.uniform(0.2, 1.4)))
            C.cyl(0.08, 0.5, p, M["crystal"], r, r2=0.0, verts=6, rot=(rng.uniform(-0.6, 0.6), rng.uniform(0.3, 0.9), 0))
    elif kind == "breach":
        # damaged panel wall: cracked plates, exposed glowing seam -> reads as "breakable"
        r = wall_base(M, M["ivory"])

        def face(o, a, n):
            rot = _rot_for_normal(n)
            for k, z, tilt in ((-0.45, 0.8, 0.12), (0.4, 0.75, -0.2), (-0.35, 2.1, -0.15), (0.45, 2.2, 0.25)):
                C.box((0.07, 0.8, 0.95), o + n * 0.03 + a * k + Vector((0, 0, z)), M["ivory"], r,
                      rot=(tilt, 0, rot[2]), bevel=0.04)
            C.box((0.05, 0.08, 2.4), o + n * 0.01 + a * 0.02 + Vector((0, 0, 1.4)), M["amber"], r, rot=(0.1, 0, rot[2]),
                  bevel=0.0)
            C.box((0.05, 1.4, 0.07), o + n * 0.01 + Vector((0, 0, 1.45)), M["amber"], r, rot=(0, 0.2, rot[2]), bevel=0.0)
            for i in range(5):
                C.box((0.18, 0.18, 0.18), o + n * 0.15 + a * rng.uniform(-0.8, 0.8) + Vector((0, 0, 0.1)),
                      M["deck2"], r, rot=(rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 1)), bevel=0.02)
        _face_items(face)
    return r


WALL_KINDS = ["panel", "pod", "machine", "window", "pipes", "rock", "breach"]


def render_walls():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    fw, fh, org = WALL_FRAME
    C.setup_camera(fw, fh, org)
    sw = C.SheetWriter("env", "wall_blocks", fw, fh, org, 1, len(WALL_KINDS), meta={"kinds": WALL_KINDS})
    rng = random.Random(3)
    for i, k in enumerate(WALL_KINDS):
        C.clear_scene_objects()
        wall_variant(M, k, rng)
        sw.put(0, i, C.render_passes())
    sw.save()


# ======================================================================= low blocks (block movement, not bullets)

def low_variant(M, kind, rng):
    r = C.empty("low")
    if kind == "console":
        C.box((CELL * 0.9, CELL * 0.9, 0.8), (0, 0, 0.4), M["deck2"], r, bevel=0.05)
        C.box((CELL * 0.92, CELL * 0.92, 0.12), (0, 0, 0.86), M["deck_dark"], r, bevel=0.04)
        C.box((CELL * 0.5, CELL * 0.12, 0.02), (0, 0, 0.93), M["teal"], r, bevel=0.0)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.3, CELL * 0.7, 0.35), o * 0.9 + n * 0.02 + Vector((0, 0, 1.05)), M["deck_dark"], r,
                  rot=(0, 0, rot[2]), bevel=0.03)
            C.box((0.04, CELL * 0.62, 0.26), o * 0.9 + n * 0.18 + Vector((0, 0, 1.06)), M["cyan"], r, rot=rot, bevel=0.0)
            C.box((0.04, CELL * 0.6, 0.06), o * 0.9 + n * 0.02 + Vector((0, 0, 0.45)), M["amber"], r, rot=rot, bevel=0.0)
        _face_items(face)
    elif kind == "crates":
        for (x, y, z, s) in ((-0.42, 0.4, 0.4, 0.8), (0.42, 0.4, 0.4, 0.8), (-0.42, -0.42, 0.35, 0.7),
                             (0.4, -0.38, 0.4, 0.8), (0.0, 0.2, 1.1, 0.65)):
            C.box((s, s, s), (x, y, z), M["olive"], r, bevel=0.04, rot=(0, 0, rng.uniform(-0.15, 0.15)))
            C.box((s * 1.02, s * 0.2, s * 1.02), (x, y, z), M["trim"], r, bevel=0.02)
            C.box((s * 0.4, s * 1.03, s * 0.08), (x, y, z + s * 0.25), M["yellow"], r, bevel=0.0)
    elif kind == "railing":
        C.box((CELL * 0.95, CELL * 0.95, 0.25), (0, 0, 0.125), M["deck_dark"], r, bevel=0.04)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.06, CELL * 0.86, 0.75), o * 0.88 + Vector((0, 0, 0.62)), M["glass"], r, rot=rot, bevel=0.01)
            C.box((0.16, CELL * 0.92, 0.12), o * 0.88 + Vector((0, 0, 1.05)), M["ivory"], r, rot=rot, bevel=0.05)
            for k in (-0.85, 0.0, 0.85):
                C.box((0.2, 0.18, 1.05), o * 0.88 + a * k + Vector((0, 0, 0.55)), M["ivory"], r, rot=rot, bevel=0.06)
                C.box((0.06, 0.06, 0.35), o * 0.88 + a * k + n * 0.1 + Vector((0, 0, 0.6)), M["red_glow"], r,
                      rot=rot, bevel=0.0)
        _face_items(face)
        # back rails so the block reads as an enclosed planter / barrier
        for (o, a, n) in ((Vector((-CELL / 2, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0))),
                          (Vector((0, CELL / 2, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)))):
            C.box((0.16, CELL * 0.92, 0.12), o * 0.88 + Vector((0, 0, 1.05)), M["ivory"], r, rot=_rot_for_normal(n),
                  bevel=0.05)
        C.box((CELL * 0.8, CELL * 0.8, 0.1), (0, 0, 0.3), M["teal"], r, bevel=0.0)
    return r


LOW_KINDS = ["console", "crates", "railing"]


def render_lows():
    C.reset_scene()
    C.setup_lights()
    M = materials()
    fw, fh, org = LOW_FRAME
    C.setup_camera(fw, fh, org)
    sw = C.SheetWriter("env", "low_blocks", fw, fh, org, 1, len(LOW_KINDS), meta={"kinds": LOW_KINDS})
    rng = random.Random(5)
    for i, k in enumerate(LOW_KINDS):
        C.clear_scene_objects()
        low_variant(M, k, rng)
        sw.put(0, i, C.render_passes())
    sw.save()


# ======================================================================= props

def prop_barrel(M, frame):
    r = C.empty("barrel")
    C.cyl(0.32, 1.0, (0, 0, 0.5), M["redpaint"], r, verts=24, bevel=0.03)
    for z in (0.12, 0.88):
        C.cyl(0.335, 0.07, (0, 0, z), M["trim"], r, verts=24, bevel=0.01)
    C.cyl(0.333, 0.16, (0, 0, 0.55), M["yellow"], r, verts=24, bevel=0.0)
    C.box((0.08, 0.3, 0.5), (0.3, 0, 0.5), M["amber"], r, bevel=0.02, rot=(0, 0, -0.785))
    C.cyl(0.09, 0.08, (0.12, 0.05, 1.02), M["trim"], r, verts=12)
    return r


def prop_crate(M, frame):
    r = C.empty("crate")
    C.box((0.95, 0.95, 0.85), (0, 0, 0.425), M["olive"], r, bevel=0.05)
    C.box((0.97, 0.3, 0.87), (0, 0, 0.425), M["trim"], r, bevel=0.03)
    C.box((0.3, 0.97, 0.12), (0, 0, 0.6), M["yellow"], r, bevel=0.0)
    C.box((0.06, 0.25, 0.08), (0.5, 0, 0.3), M["cyan"], r, bevel=0.0)
    return r


def prop_chest(M, frame):
    r = C.empty("chest")
    C.box((0.9, 1.4, 0.55), (0, 0, 0.275), M["deck2"], r, bevel=0.06)
    C.box((0.92, 1.42, 0.08), (0, 0, 0.05), M["trim"], r, bevel=0.02)
    lid = C.empty("lid", (-0.45, 0, 0.55), r)
    C.box((0.9, 1.4, 0.25), (0.45, 0, 0.12), M["maroon"], lid, bevel=0.08)
    C.box((0.1, 1.0, 0.05), (0.88, 0, 0.12), M["amber"], lid, bevel=0.0)
    C.box((0.05, 0.6, 0.04), (0.46, 0, 0.32), M["amber"], r, bevel=0.0)
    if frame == 1:
        lid.rotation_euler = (0, -1.9, 0)
        C.box((0.7, 1.2, 0.05), (0, 0, 0.5), M["amber"], r, bevel=0.0)
    return r


def prop_eggs(M, frame):
    r = C.empty("eggs")
    C.sphere(0.6, (0, 0, 0.0), M["bio"], r, scale=(1.2, 1.1, 0.25), subsurf=1, displace=0.05)
    rng = random.Random(11)
    for (x, y, s) in ((0, 0, 0.32), (0.35, -0.25, 0.24), (-0.3, 0.3, 0.22), (0.3, 0.35, 0.2), (-0.35, -0.3, 0.18)):
        sc = s * (1.0 + (0.12 if frame == 1 else 0.0))
        C.sphere(sc, (x, y, sc * 1.1), M["egg"], r, scale=(0.85, 0.85, 1.25), subsurf=1, displace=0.02)
    for i in range(6):
        a = rng.uniform(0, 6.28)
        C.tube_between((0, 0, 0.05), (0.75 * math.cos(a), 0.75 * math.sin(a), 0.02), 0.04, M["bio"], r, r2=0.01)
    return r


def prop_crystals(M, frame):
    r = C.empty("crystals")
    rng = random.Random(4)
    C.sphere(0.45, (0, 0, 0.0), M["rock"], r, scale=(1.2, 1.0, 0.4), subsurf=1, displace=0.06)
    for i in range(7):
        a = rng.uniform(0, 6.28)
        h = rng.uniform(0.5, 1.2)
        C.cyl(rng.uniform(0.07, 0.13), h, (0.2 * math.cos(a), 0.2 * math.sin(a), h * 0.45), M["crystal"], r, r2=0.0,
              verts=6, rot=(rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0), smooth=False)
    return r


def prop_canisters(M, frame):
    r = C.empty("canisters")
    for (x, y, h) in ((0, 0, 0.55), (0.35, -0.15, 0.4), (-0.2, 0.32, 0.45)):
        C.cyl(0.16, h, (x, y, h / 2), M["ivory"], r, verts=18, bevel=0.03)
        C.cyl(0.165, 0.06, (x, y, h * 0.7), M["maroon"], r, verts=18, bevel=0.0)
        C.cyl(0.1, 0.05, (x, y, h + 0.02), M["trim"], r, verts=12, bevel=0.0)
    return r


def prop_pylon(M, frame):
    r = C.empty("pylon")
    C.cyl(0.3, 0.2, (0, 0, 0.1), M["deck_dark"], r, verts=6, bevel=0.03)
    C.box((0.14, 0.14, 2.0), (0, 0, 1.1), M["deck2"], r, bevel=0.03)
    C.box((0.06, 0.18, 1.4), (0.06, 0, 1.2), M["cyan"], r, bevel=0.0)
    C.box((0.3, 0.3, 0.12), (0, 0, 2.12), M["trim"], r, bevel=0.03)
    C.sphere(0.12, (0, 0, 2.25), M["cyan"], r, segs=14)
    return r


def prop_tube(M, frame):
    r = C.empty("cryotube")
    C.cyl(0.5, 0.3, (0, 0, 0.15), M["deck2"], r, verts=24, bevel=0.04)
    C.cyl(0.42, 1.7, (0, 0, 1.15), M["glass"], r, verts=24, bevel=0.0)
    C.cyl(0.5, 0.3, (0, 0, 2.1), M["deck2"], r, verts=24, bevel=0.04)
    C.sphere(0.22, (0, 0, 1.2), M["bio"], r, scale=(0.9, 0.8, 1.6), subsurf=1, displace=0.05)
    for a in range(3):
        C.box((0.06, 0.06, 1.7), (0.47 * math.cos(a * 2.1), 0.47 * math.sin(a * 2.1), 1.15), M["trim"], r, bevel=0.0)
    return r


PROPS = {
    # name: (builder, frames, (w, h, origin))
    "barrel": (prop_barrel, 1, (96, 144, (48, 110))),
    "crate": (prop_crate, 1, (144, 160, (72, 104))),
    "chest": (prop_chest, 2, (176, 160, (88, 108))),
    "eggs": (prop_eggs, 2, (192, 160, (96, 100))),
    "crystals": (prop_crystals, 1, (160, 176, (80, 120))),
    "canisters": (prop_canisters, 1, (128, 128, (64, 84))),
    "pylon": (prop_pylon, 1, (96, 224, (48, 190))),
    "cryotube": (prop_tube, 1, (144, 256, (72, 196))),
}


def render_props():
    for name, (build, frames, (fw, fh, org)) in PROPS.items():
        C.reset_scene()
        C.setup_lights()
        M = materials()
        C.setup_camera(fw, fh, org)
        sw = C.SheetWriter("props", name, fw, fh, org, 1, frames)
        for f in range(frames):
            C.clear_scene_objects()
            root = build(M, f)
            root.rotation_euler = (0, 0, 0.0)
            sw.put(0, f, C.render_passes())
        sw.save()


if __name__ == "__main__":
    import sys
    what = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["floors", "walls", "lows", "props"]
    if "floors" in what:
        render_floors()
    if "walls" in what:
        render_walls()
    if "lows" in what:
        render_lows()
    if "props" in what:
        render_props()
