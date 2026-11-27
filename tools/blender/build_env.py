"""Underworld environment kit (ink/cel-shaded): floor slabs, wall blocks, low
blocks, props. Kind indices are stable: the ASCII legend in
src/dungeon/layout_test.gd maps characters to them.

Grid: 1 cell = 2 m x 2 m.  Godot isometric cell = 256 x 192 px diamond.
"""
import math
import random
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

CELL = 2.0
FLOOR_FRAME = (264, 240, (132, 100))
WALL_FRAME = (260, 388, (130, 286))
LOW_FRAME = (260, 276, (130, 174))
ENV_STYLE = {"outline_px": 3, "normal_edge": 0.5, "color_edge": 0.24, "color_line": 0.45, "grain": 0.09}
# floors: soft, textured stone — few crease lines so the ground stays calm under combat
FLOOR_STYLE = {"outline_px": 0, "inner_px": 0, "normal_edge": 0.75, "depth_edge": 0.05, "color_edge": 0.3,
               "color_line": 0.32, "grain": 0.14}


def materials():
    return {
        "stone": [C.mat("v_st%d" % i, c, rough=0.85, noise=0.55, noise_scale=5 + i, noise_color=tuple(x * 0.62 for x in c))
                  for i, c in enumerate([(0.2, 0.24, 0.21), (0.17, 0.21, 0.2), (0.23, 0.24, 0.21), (0.16, 0.2, 0.2),
                                         (0.21, 0.21, 0.23)])],
        "grout": C.mat("v_grout", (0.05, 0.06, 0.06), rough=0.95),
        "wall": C.mat("v_wall", (0.16, 0.2, 0.18), rough=0.85),
        "wall2": C.mat("v_wall2", (0.12, 0.16, 0.15), rough=0.85),
        "wall_dk": C.mat("v_wall_dk", (0.06, 0.08, 0.08), rough=0.9),
        "cap": C.mat("v_cap", (0.04, 0.05, 0.05), rough=0.95),
        "gold": C.mat("v_gold", (0.9, 0.62, 0.2), metal=1.0, rough=0.3),
        "bronze": C.mat("v_bronze", (0.36, 0.25, 0.12), metal=0.6, rough=0.45),
        "iron": C.mat("v_iron", (0.12, 0.12, 0.13), metal=0.7, rough=0.5),
        "soul": C.mat("v_soul", (0.3, 1.0, 0.55), emit=(0.35, 1.0, 0.55), emit_strength=7),
        "soul2": C.mat("v_soul2", (0.15, 0.75, 0.4), emit=(0.2, 0.9, 0.45), emit_strength=4),
        "fire": C.mat("v_fire", (1.0, 0.6, 0.15), emit=(1.0, 0.6, 0.18), emit_strength=8),
        "ember": C.mat("v_ember", (0.9, 0.25, 0.08), emit=(1.0, 0.3, 0.08), emit_strength=5),
        "rune": C.mat("v_rune", (0.55, 0.06, 0.08), emit=(0.8, 0.08, 0.1), emit_strength=1.2),
        "moss": C.mat("v_moss", (0.15, 0.32, 0.14), rough=0.9),
        "bone": C.mat("v_bone", (0.82, 0.76, 0.62), rough=0.5),
        "terracotta": C.mat("v_terra", (0.6, 0.27, 0.12), rough=0.6),
        "black": C.mat("v_black", (0.05, 0.04, 0.04), rough=0.7),
        "banner": C.mat("v_banner", (0.62, 0.07, 0.07), rough=0.8),
        "wax": C.mat("v_wax", (0.92, 0.88, 0.75), rough=0.5),
        "rock": C.mat("v_rock", (0.12, 0.14, 0.13), rough=0.9, noise=0.6, noise_scale=4, noise_color=(0.06, 0.07, 0.07)),
        "marble": C.mat("v_marble", (0.4, 0.42, 0.38), rough=0.5, noise=0.3, noise_scale=6),
        "pillar": C.mat("v_pillar", (0.24, 0.31, 0.27), rough=0.7, noise=0.35, noise_scale=6,
                        noise_color=(0.13, 0.18, 0.15)),
        **painted_materials(),
    }


# Painted textures (tools/blender/textures, made with docs' prompt book). Each one is
# optional: when its file is missing, the kit falls back to the modelled look.
PAINTED = {
    # key: (file, metres per repeat along object X, Y, Z, extra options)
    # large 50-90 cm slabs (slab_* are made by prep_textures.py from the kit's large-slab
    # floors). They are painted darker than the mockup's lit stone, so lift them here.
    # flag2 uses the same slabs turned 90 degrees so the 2 m repeat doesn't line up.
    "t_floor": ("slab_worn.png", (CELL, CELL, CELL), {"tex_proj": "FLAT", "tex_gain": 1.3}),
    "t_floor2": ("slab_worn.png", (CELL, CELL, CELL), {"tex_proj": "FLAT", "tex_gain": 1.3, "tex_rot": math.pi / 2}),
    "t_cracked": ("slab_damaged.png", (CELL, CELL, CELL), {"tex_proj": "FLAT", "tex_gain": 1.3}),
    "t_moss": ("slab_moss_bones.png", (CELL, CELL, CELL), {"tex_proj": "FLAT", "tex_gain": 1.3}),
    "t_border": ("floor_border_meander.png", (CELL, CELL / 2.96, CELL), {"tex_proj": "FLAT"}),  # strip ~2.96:1
    # turned 45 degrees so the skull stands upright on screen; edges clamp to plain stone
    "t_emblem": ("floor_emblem_skull.png", (1.7, 1.7, 1.7),
                 {"tex_proj": "FLAT", "tex_rot": -math.pi / 4, "tex_extension": "EXTEND"}),
    "t_sun": ("floor_emblem_sun.png", (1.7, 1.7, 1.7),
              {"tex_proj": "FLAT", "tex_rot": -math.pi / 4, "tex_extension": "EXTEND"}),
    "t_wall": ("wall_ashlar.png", (CELL, CELL, 3.0), {}),
    "t_flames": ("soulfire_flames.png", (1.0, 3.24, 1.62),
                 {"tex_emit": True, "emit": (1.0, 1.0, 1.0), "emit_strength": 6.0}),
}


def painted_materials():
    out = {}
    for key, (fn, size, opts) in PAINTED.items():
        path = C.tex_path(fn)
        if path:
            out[key] = C.mat("p_" + key, (0.2, 0.22, 0.2), rough=0.85, tex=path, tex_size=size, **opts)
    return out


def flame(M, parent, pos, h, rng, strong=True):
    """Teardrop flame tongues (reads as fire in the ink style, glows via emission)."""
    base = Vector(pos)
    for k in range(3):
        o = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0))
        hh = h * (1.0 - k * 0.28)
        C.sphere(0.5, base + o + Vector((0, 0, hh * 0.42)), M["soul"] if (strong and k == 0) else M["soul2"], parent,
                 scale=(0.13 * (1 - k * 0.2), 0.13 * (1 - k * 0.2), hh * 0.55), segs=12,
                 rot=(rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0))


def stone(M, rng):
    return M["stone"][rng.randrange(len(M["stone"]))]


# ======================================================================= floors

def slab(M, size=CELL * 1.012):
    root = C.empty("slab")

    # edge pieces sit flush with the slab's side (3 mm proud), never past the floor's top
    # edge, or they peek through as a dotted line where neighbouring tiles overlap
    def inset(d):
        k = 1.0 - d / (size / 2)
        return Vector((k, k, 1.0))

    C.box((size, size, 0.5), (0, 0, -0.25), M["grout"], root, bevel=0.01)
    # ledge blocks + gold lip on the two camera-facing sides (only seen at platform edges)
    for (dx, dy, rz) in ((size / 2, 0, 0), (0, -size / 2, math.pi / 2)):
        for k in (-0.5, 0.5):
            off = Vector((0, k, 0)) if rz == 0 else Vector((k, 0, 0))
            C.box((0.04, size * 0.48, 0.42), Vector((dx, dy, -0.26)) * inset(0.017) + off, M["wall2"], root, bevel=0.02,
                  rot=(0, 0, rz))
        C.box((0.05, size, 0.06), Vector((dx, dy, -0.05)) * inset(0.022), M["gold"], root, bevel=0.01, rot=(0, 0, rz))
    return root


def flagstones(M, root, rng, top=0.0, rows=3):
    """Irregular, staggered stone slabs filling the cell, with moss/dirt flecks."""
    y = -CELL / 2
    ws = [rng.uniform(0.7, 1.3) for _ in range(rows)]
    tot = sum(ws)
    for r in range(rows):
        h = CELL * ws[r] / tot
        x = -CELL / 2
        while x < CELL / 2 - 0.05:
            w = min(rng.uniform(0.35, 0.95), CELL / 2 - x)
            if CELL / 2 - (x + w) < 0.2:
                w = CELL / 2 - x
            C.box((w - 0.03, h - 0.03, 0.06), (x + w / 2, y + h / 2, top - 0.02 + rng.uniform(-0.003, 0.003)),
                  stone(M, rng), root, bevel=0.018, rot=(0, 0, rng.uniform(-0.01, 0.01)))
            x += w
        y += h
    for i in range(rng.randint(1, 3)):
        C.sphere(rng.uniform(0.06, 0.14), (rng.uniform(-0.85, 0.85), rng.uniform(-0.85, 0.85), top + 0.0), M["moss"], root,
                 scale=(1.4, 1.0, 0.1), segs=10)


def meander(M, parent, origin, along, up, normal, length, height, unit=0.24, offset=0.012, thick=0.022):
    """Greek-key band made of small gold bars on a surface."""
    n_units = max(1, int(length / unit))
    u0 = -n_units * unit / 2
    s = unit / 10.0
    path = [(0, 0), (0, 8), (8, 8), (8, 2), (4, 2), (4, 5), (6, 5)]
    for i in range(n_units):
        base = u0 + i * unit
        pts = [Vector(origin) + along * (base + px * s) + up * (py * s * height / unit * 1.25 - height / 2) + normal * offset
               for px, py in path]
        for a, b in zip(pts[:-1], pts[1:]):
            d = b - a
            if d.length < 1e-4:
                continue
            C.box((thick, thick, d.length + thick), (a + b) / 2, M["gold"], parent, bevel=0.0,
                  rot=d.to_track_quat("Z", "Y").to_euler())
        a = Vector(origin) + along * base + up * (-height / 2) + normal * offset
        b = Vector(origin) + along * (base + unit) + up * (-height / 2) + normal * offset
        C.box((thick, thick, (b - a).length + thick), (a + b) / 2, M["gold"], parent, bevel=0.0,
              rot=(b - a).to_track_quat("Z", "Y").to_euler())


def floor_top(M, r, rng, key="t_floor", rows=3):
    """The walkable surface: the painted texture when it exists, else modelled flagstones.
    The painted top is 1.2% larger than the cell, like the slab, so neighbouring tiles
    overlap; the texture repeats every CELL, so the overlap shows matching stone."""
    if key in M:
        # paper-thin, so no lit side edge shows where neighbouring tiles overlap
        C.box((CELL * 1.012, CELL * 1.012, 0.004), (0, 0, 0.008), M[key], r, bevel=0.0)
        return True
    flagstones(M, r, rng, rows=rows)
    return False


def floor_variant(M, kind, rng):
    r = slab(M)
    up = Vector((0, 0, 1))
    if kind == "flag":
        floor_top(M, r, rng, rows=3)
    elif kind == "flag2":
        floor_top(M, r, rng, key="t_floor2" if "t_floor2" in M else "t_floor", rows=2)
    elif kind == "grate":
        floor_top(M, r, rng, rows=3)
        C.box((1.3, 1.3, 0.1), (0, 0, -0.02), M["grout"], r, bevel=0.0)
        C.box((1.2, 1.2, 0.04), (0, 0, -0.12), M["soul2"], r, bevel=0.0)
        for i in range(-5, 6):
            C.box((1.26, 0.05, 0.07), (0, i * 0.11, 0.0), M["iron"], r, bevel=0.005)
        for s in (-1, 1):
            C.box((1.36, 0.07, 0.07), (0, s * 0.66, 0.0), M["iron"], r, bevel=0.01)
            C.box((0.07, 1.36, 0.07), (s * 0.66, 0, 0.0), M["iron"], r, bevel=0.01)
    elif kind == "meander":
        floor_top(M, r, rng, rows=3)
        if "t_border" in M:  # painted gold Greek-key strip; repeats every CELL so runs join up
            C.box((CELL * 1.012, CELL / 2.96, 0.04), (0, 0.45, 0.005), M["t_border"], r, bevel=0.0)
        else:
            C.box((CELL, 0.42, 0.05), (0, 0.45, 0.0), M["wall_dk"], r, bevel=0.01)
            meander(M, r, (0, 0.45, 0.03), Vector((1, 0, 0)), Vector((0, 1, 0)), up, CELL * 0.95, 0.3, offset=0.0)
    elif kind == "sun":
        floor_top(M, r, rng, rows=2)
        if "t_sun" in M:  # painted sunburst inlay on a raised plate, like the emblem
            C.box((1.7, 1.7, 0.03), (0, 0, 0.012), M["t_sun"], r, bevel=0.01)
            return r
        C.cyl(0.24, 0.05, (0, 0, 0.02), M["gold"], r, verts=24)
        for i in range(12):
            a = i * math.pi / 6
            C.box((0.4, 0.07, 0.03), (0.45 * math.cos(a), 0.45 * math.sin(a), 0.03), M["gold"], r, bevel=0.005, rot=(0, 0, a))
    elif kind == "drain":
        floor_top(M, r, rng, rows=3)
        C.cyl(0.55, 0.06, (0, 0, -0.005), M["wall_dk"], r, verts=32, bevel=0.01)
        C.cyl(0.42, 0.04, (0, 0, -0.05), M["soul2"], r, verts=32, bevel=0.0)
        C.torus(0.48, 0.04, (0, 0, 0.02), M["bronze"], r, seg=32, mseg=6)
        for i in range(6):
            C.box((0.86, 0.05, 0.05), (0, 0, 0.0), M["iron"], r, bevel=0.005, rot=(0, 0, i * math.pi / 6))
    elif kind == "cracked":
        if floor_top(M, r, rng, key="t_cracked", rows=3):
            return r
        for i in range(5):
            x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
            C.box((0.22, 0.16, 0.08), (x, y, 0.02), stone(M, rng), r, bevel=0.03, rot=(rng.random(), rng.random() * 0.3, rng.random() * 3))
        C.box((1.4, 0.035, 0.08), (0.1, -0.1, 0.0), M["grout"], r, bevel=0.0, rot=(0, 0, 0.7))
    elif kind == "moss":
        if floor_top(M, r, rng, key="t_moss", rows=3):
            return r
        for i in range(6):
            x, y = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
            C.sphere(rng.uniform(0.2, 0.36), (x, y, 0.0), M["moss"], r, scale=(1.3, 1.0, 0.15), subsurf=1, displace=0.03)
        for i in range(3):
            x, y = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
            C.cyl(0.03, 0.34, (x, y, 0.05), M["bone"], r, verts=8, rot=(math.pi / 2, 0, rng.random() * 3))
        C.sphere(0.1, (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0.08), M["bone"], r, scale=(1.1, 0.9, 1.0))
    elif kind == "emblem":
        floor_top(M, r, rng, rows=2)
        if "t_emblem" in M:  # inlaid plate, slightly raised so it gets an ink edge
            C.box((1.7, 1.7, 0.03), (0, 0, 0.012), M["t_emblem"], r, bevel=0.01)
            return r
        for s in (-1, 1):
            for i in range(7):  # laurel leaves
                a = -0.3 + i * 0.36
                px, py = 0.55 * math.cos(a) * s, 0.55 * math.sin(a) - 0.05
                C.sphere(0.09, (px, py, 0.04), M["gold"], r, scale=(1.6, 0.6, 0.3), rot=(0, 0, a + (0.6 if s > 0 else -0.6)))
        C.sphere(0.2, (0, 0.05, 0.04), M["bone"], r, scale=(1.0, 1.1, 0.3))
        for s in (-1, 1):
            C.sphere(0.05, (0.07 * s, 0.1, 0.09), M["black"], r, scale=(1, 1, 0.4))
    elif kind == "runes":
        floor_top(M, r, rng, rows=3)
        C.torus(0.6, 0.025, (0, 0, 0.02), M["rune"], r, seg=40, mseg=4)
        for i in range(6):
            a = i * math.pi / 3
            C.box((0.12, 0.03, 0.02), (0.6 * math.cos(a), 0.6 * math.sin(a), 0.03), M["rune"], r, bevel=0.0, rot=(0, 0, a))
    elif kind == "rockfloor":
        C.box((CELL, CELL, 0.06), (0, 0, -0.02), M["rock"], r, bevel=0.02)
        for i in range(7):
            x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8)
            C.sphere(rng.uniform(0.12, 0.28), (x, y, -0.03), M["rock"], r, scale=(1.2, 1.0, 0.3), subsurf=1, displace=0.04)
    return r


FLOOR_KINDS = ["flag", "flag2", "grate", "meander", "sun", "drain", "cracked", "moss", "emblem", "runes",
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
        sw.put(0, i, C.render_stylized(FLOOR_STYLE))
    sw.save()


# ======================================================================= walls

H = 3.0
UP = Vector((0, 0, 1))


def _face_items(fn):
    """Call fn(origin, along, normal) for the two camera-facing faces (+X and -Y)."""
    fn(Vector((CELL / 2, 0, 0)), Vector((0, -1, 0)), Vector((1, 0, 0)))
    fn(Vector((0, -CELL / 2, 0)), Vector((1, 0, 0)), Vector((0, -1, 0)))


def _rot_for_normal(n):
    return (0, 0, math.atan2(n.y, n.x))


def wall_base(M, rng, body="wall"):
    r = C.empty("wall")
    painted = "t_wall" in M  # the painted ashlar has its own joints and gold frieze band
    C.box((CELL, CELL, H), (0, 0, H / 2), M["t_wall"] if painted else M[body], r, bevel=0.02)
    C.box((CELL + 0.1, CELL + 0.1, 0.18), (0, 0, H - 0.09), M["wall_dk"], r, bevel=0.03)  # cornice
    C.box((CELL * 0.94, CELL * 0.94, 0.05), (0, 0, H + 0.01), M["cap"], r, bevel=0.01)
    C.box((CELL + 0.08, CELL + 0.08, 0.3), (0, 0, 0.15), M["wall_dk"], r, bevel=0.03)  # plinth

    def courses(o, a, n):
        rot = _rot_for_normal(n)
        if painted:
            C.box((0.05, CELL * 1.0, 0.05), o + n * 0.01 + UP * (H - 0.2), M["gold"], r, rot=rot, bevel=0.005)
            return
        for z in (0.75, 1.25, 1.75):  # masonry courses
            C.box((0.03, CELL * 0.98, 0.025), o + n * 0.005 + UP * z, M["wall_dk"], r, rot=rot, bevel=0.0)
        for i, z in enumerate((0.5, 1.0, 1.5)):
            k = (-0.5 if i % 2 else 0.0) + rng.uniform(-0.1, 0.1)
            C.box((0.03, 0.025, 0.5), o + n * 0.005 + a * k + UP * z, M["wall_dk"], r, rot=rot, bevel=0.0)
        C.box((0.05, CELL * 1.0, 0.05), o + n * 0.01 + UP * (H - 0.2), M["gold"], r, rot=rot, bevel=0.005)
    _face_items(courses)
    return r


def wall_variant(M, kind, rng):
    if kind == "frieze":
        r = wall_base(M, rng)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.06, CELL * 1.0, 0.42), o + n * 0.02 + UP * 2.25, M["wall_dk"], r, rot=rot, bevel=0.01)
            meander(M, r, o + n * 0.05 + UP * 2.25, a, UP, n, CELL * 0.96, 0.3)
            C.box((0.07, CELL * 1.0, 0.035), o + n * 0.04 + UP * 2.48, M["gold"], r, rot=rot, bevel=0.005)
            C.box((0.07, CELL * 1.0, 0.035), o + n * 0.04 + UP * 2.02, M["gold"], r, rot=rot, bevel=0.005)
        _face_items(face)
    elif kind == "column":
        r = wall_base(M, rng, "wall2")
        c = Vector((CELL / 2, -CELL / 2, 0))
        C.cyl(0.34, 2.4, c + UP * 1.5, M["marble"], r, verts=20, bevel=0.0)
        for i in range(10):  # flutes
            a = i * 2 * math.pi / 10
            C.box((0.04, 0.04, 2.3), c + Vector((0.34 * math.cos(a), 0.34 * math.sin(a), 1.5)), M["wall2"], r, bevel=0.0,
                  rot=(0, 0, a))
        for z in (0.3, 2.72):
            C.cyl(0.44, 0.2, c + UP * z, M["marble"], r, verts=20, bevel=0.03)
            C.torus(0.38, 0.03, c + UP * (z + 0.12 if z > 1 else z + 0.12), M["gold"], r, seg=24, mseg=6)
    elif kind == "firealcove":
        r = wall_base(M, rng)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.12, 1.06, 1.9), o + n * 0.02 + UP * 1.25, M["wall_dk"], r, rot=rot, bevel=0.04)
            C.cyl(0.53, 0.12, o + n * 0.02 + UP * 2.2, M["wall_dk"], r, verts=24, rot=(math.pi / 2, 0, rot[2] + math.pi / 2))
            if "t_flames" in M:  # painted soul-fire on the back of the niche
                C.box((0.1, 0.84, 1.62), o + n * 0.05 + UP * 1.2, M["t_flames"], r, rot=rot, bevel=0.0)
            else:
                C.box((0.1, 0.84, 1.62), o + n * 0.05 + UP * 1.2, M["black"], r, rot=rot, bevel=0.0)
                for i in range(4):  # soul flames rising in the niche
                    k = -0.27 + i * 0.18
                    flame(M, r, o + n * 0.14 + a * k + UP * 0.4, rng.uniform(0.7, 1.2), rng, i % 2 == 0)
            C.box((0.14, 1.12, 0.06), o + n * 0.06 + UP * 0.34, M["gold"], r, rot=rot, bevel=0.01)
            C.torus(0.52, 0.03, o + n * 0.09 + UP * 2.2, M["gold"], r, rot=(math.pi / 2, 0, rot[2] + math.pi / 2), seg=32, mseg=6)
        _face_items(face)
    elif kind == "relief":
        r = wall_base(M, rng, "wall2")

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.08, 1.3, 1.5), o + n * 0.02 + UP * 1.55, M["wall"], r, rot=rot, bevel=0.06)
            C.box((0.09, 1.36, 0.05), o + n * 0.05 + UP * 2.32, M["gold"], r, rot=rot, bevel=0.01)
            C.box((0.09, 1.36, 0.05), o + n * 0.05 + UP * 0.78, M["gold"], r, rot=rot, bevel=0.01)
            for s in (-1, 1):
                for i in range(6):  # laurel branch
                    ang = -1.1 + i * 0.4
                    p = o + n * 0.08 + a * (s * (0.32 + 0.18 * math.cos(ang))) + UP * (1.55 + 0.42 * math.sin(ang))
                    C.sphere(0.07, p, M["gold"], r, scale=(0.4, 1.4, 0.5), rot=(s * (ang + 1.2), 0, rot[2]))
            C.sphere(0.2, o + n * 0.08 + UP * 1.6, M["marble"], r, scale=(0.4, 0.8, 1.0))
        _face_items(face)
    elif kind == "banner":
        r = wall_base(M, rng, "wall_dk")

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.04, 0.7, 1.6), o + n * 0.05 + a * 0.35 + UP * 1.7, M["banner"], r, rot=rot, bevel=0.01)
            C.box((0.05, 0.74, 0.05), o + n * 0.07 + a * 0.35 + UP * 2.52, M["gold"], r, rot=rot, bevel=0.005)
            C.sphere(0.13, o + n * 0.09 + a * 0.35 + UP * 1.9, M["gold"], r, scale=(0.3, 1.0, 1.2))
            for k in (0.04, 0.66):
                C.box((0.04, 0.12, 0.25), o + n * 0.05 + a * k + UP * 0.82, M["banner"], r, rot=(0.3, 0, rot[2]), bevel=0.0)
            # torch sconce
            C.box((0.12, 0.1, 0.3), o + n * 0.1 + a * -0.55 + UP * 1.6, M["iron"], r, rot=rot, bevel=0.01)
            C.cyl(0.08, 0.1, o + n * 0.2 + a * -0.55 + UP * 1.8, M["iron"], r, verts=10, r2=0.12)
            C.cyl(0.1, 0.3, o + n * 0.2 + a * -0.55 + UP * 2.0, M["fire"], r, r2=0.0, verts=8)
            for z in (0.6, 0.9, 1.2):  # chain
                C.torus(0.05, 0.015, o + n * 0.08 + a * -0.85 + UP * (z + 0.9), M["iron"], r, rot=(0, (z * 7) % 2, 0), seg=10, mseg=4)
        _face_items(face)
    elif kind == "rock":
        r = C.empty("wall")
        C.box((CELL * 0.98, CELL * 0.98, H * 0.95), (0, 0, H * 0.47), M["rock"], r, bevel=0.2)
        for i in range(9):
            p = Vector((rng.uniform(-0.6, 1.0), rng.uniform(-1.0, 0.6), rng.uniform(0.3, 2.6)))
            C.sphere(rng.uniform(0.35, 0.6), p, M["rock"], r, scale=(1.0, 1.0, 1.3), subsurf=1, displace=0.15, disp_scale=0.6)
        for i in range(3):
            p = Vector((rng.uniform(0.7, 1.05), rng.uniform(-1.05, -0.7), rng.uniform(0.2, 1.4)))
            C.cyl(0.08, 0.5, p, M["soul2"], r, r2=0.0, verts=6, rot=(rng.uniform(-0.6, 0.6), rng.uniform(0.3, 0.9), 0))
    elif kind in ("pillar", "pillar_broken"):
        r = C.empty("wall")
        pillar(M, r, rng, broken=kind == "pillar_broken")
    elif kind == "breach":
        r = wall_base(M, rng)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            pts = [(0.0, 0.3), (0.12, 0.9), (-0.08, 1.4), (0.1, 2.0), (-0.05, 2.6)]
            for (u0, z0), (u1, z1) in zip(pts[:-1], pts[1:]):
                p0 = o + n * 0.03 + a * u0 + UP * z0
                p1 = o + n * 0.03 + a * u1 + UP * z1
                d = p1 - p0
                C.box((0.05, 0.06, d.length + 0.06), (p0 + p1) / 2, M["soul"], r, bevel=0.0,
                      rot=d.to_track_quat("Z", "Y").to_euler())
            for i in range(6):
                C.box((0.2, 0.2, 0.2), o + n * 0.12 + a * rng.uniform(-0.8, 0.8) + UP * 0.1, M["wall"], r,
                      rot=(rng.random(), rng.random(), rng.random()), bevel=0.03)
        _face_items(face)
    return r


def pillar(M, r, rng, broken=False):
    """Freestanding fluted temple pillar on a plinth (the mockup's columns); broken = snapped stump."""
    C.box((1.5, 1.5, 0.35), (0, 0, 0.175), M["wall_dk"], r, bevel=0.04)
    C.box((1.56, 1.56, 0.045), (0, 0, 0.31), M["gold"], r, bevel=0.01)   # gold rim just under the plinth top
    C.cyl(0.66, 0.2, (0, 0, 0.45), M["pillar"], r, verts=32, bevel=0.04)
    C.torus(0.6, 0.035, (0, 0, 0.62), M["gold"], r, seg=32, mseg=6)
    top = 1.85 if broken else 3.5
    shaft = top - 0.6
    C.cyl(0.5, shaft, (0, 0, 0.6 + shaft / 2), M["pillar"], r, verts=32, bevel=0.0)
    for i in range(14):  # flutes
        a = i * 2 * math.pi / 14
        C.box((0.06, 0.07, shaft - 0.12), (0.49 * math.cos(a), 0.49 * math.sin(a), 0.6 + shaft / 2), M["wall_dk"], r,
              bevel=0.0, rot=(0, 0, a))
    if not broken:
        C.torus(0.52, 0.04, (0, 0, top - 0.06), M["gold"], r, seg=32, mseg=6)
        C.cyl(0.54, 0.2, (0, 0, top + 0.08), M["pillar"], r, verts=32, bevel=0.04, r2=0.66)  # flared capital
        C.box((1.18, 1.18, 0.16), (0, 0, top + 0.26), M["wall_dk"], r, bevel=0.03)     # abacus
        C.box((1.22, 1.22, 0.04), (0, 0, top + 0.22), M["gold"], r, bevel=0.005)
        return
    for i in range(6):  # jagged break
        a = i * 2 * math.pi / 6 + rng.uniform(-0.3, 0.3)
        C.box((0.32, 0.3, rng.uniform(0.12, 0.42)), (0.26 * math.cos(a), 0.26 * math.sin(a), top + 0.05), M["pillar"], r,
              rot=(rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), a), bevel=0.03)
    C.cyl(0.34, 0.42, (0.42, -0.42, 0.62), M["pillar"], r, verts=20, bevel=0.03, rot=(math.pi / 2, 0, 0.7))  # fallen drum
    C.box((0.3, 0.24, 0.2), (-0.5, 0.45, 0.48), M["pillar"], r, rot=(0.3, 0.2, 1.1), bevel=0.03)


WALL_KINDS = ["frieze", "column", "firealcove", "relief", "banner", "rock", "breach", "pillar", "pillar_broken"]


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
        sw.put(0, i, C.render_stylized(ENV_STYLE))
    sw.save()


# ======================================================================= low blocks (block movement, not bullets)

def low_variant(M, kind, rng):
    r = C.empty("low")
    if kind == "altar":
        C.box((CELL * 0.86, CELL * 0.86, 0.9), (0, 0, 0.45), M["wall2"], r, bevel=0.06)
        C.box((CELL * 0.92, CELL * 0.92, 0.12), (0, 0, 0.96), M["wall_dk"], r, bevel=0.04)
        C.box((CELL * 0.92, CELL * 0.92, 0.04), (0, 0, 0.88), M["gold"], r, bevel=0.01)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.06, 0.8, 0.42), o * 0.86 + n * 0.02 + UP * 0.48, M["black"], r, rot=rot, bevel=0.0)
            C.box((0.04, 0.7, 0.32), o * 0.86 + n * 0.0 + UP * 0.48, M["ember"], r, rot=rot, bevel=0.0)
            for k in (-0.3, -0.15, 0.0, 0.15, 0.3):
                C.box((0.05, 0.04, 0.44), o * 0.86 + n * 0.05 + a * k + UP * 0.48, M["iron"], r, rot=rot, bevel=0.0)
        _face_items(face)
    elif kind == "rubble":
        for (x, y, rz) in ((-0.3, 0.25, 0.3), (0.35, -0.2, 1.1)):
            C.cyl(0.34, 0.5, (x, y, 0.34), M["wall2"], r, verts=16, rot=(math.pi / 2, 0, rz), bevel=0.03)
        C.cyl(0.36, 0.42, (0.3, 0.45, 0.21), M["wall2"], r, verts=16, bevel=0.03)
        C.torus(0.36, 0.025, (0.3, 0.45, 0.41), M["gold"], r, seg=20, mseg=4)
        for i in range(8):
            C.box((rng.uniform(0.15, 0.35),) * 3, (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0.1), stone(M, rng), r,
                  rot=(rng.random(), rng.random(), rng.random()), bevel=0.03)
    elif kind == "balustrade":
        C.box((CELL * 0.95, CELL * 0.95, 0.22), (0, 0, 0.11), M["wall2"], r, bevel=0.04)

        def face(o, a, n):
            rot = _rot_for_normal(n)
            C.box((0.18, CELL * 0.94, 0.12), o * 0.88 + UP * 1.0, M["marble"], r, rot=rot, bevel=0.04)
            C.box((0.19, CELL * 0.95, 0.03), o * 0.88 + UP * 0.94, M["gold"], r, rot=rot, bevel=0.005)
            for k in range(-4, 5):
                C.cyl(0.06, 0.7, o * 0.88 + a * (k * 0.2) + UP * 0.58, M["marble"], r, verts=10, r2=0.04, bevel=0.0)
        _face_items(face)
        for (o, n) in ((Vector((-CELL / 2, 0, 0)), Vector((-1, 0, 0))), (Vector((0, CELL / 2, 0)), Vector((0, 1, 0)))):
            C.box((0.18, CELL * 0.94, 0.12), o * 0.88 + UP * 1.0, M["marble"], r, rot=_rot_for_normal(n), bevel=0.04)
        C.box((CELL * 0.82, CELL * 0.82, 0.04), (0, 0, 0.24), M["black"], r, bevel=0.0)
        prng = random.Random(4)
        for i in range(5):
            flame(M, r, (prng.uniform(-0.5, 0.5), prng.uniform(-0.5, 0.5), 0.24), prng.uniform(0.5, 0.85), prng, i % 2 == 0)
    return r


LOW_KINDS = ["altar", "rubble", "balustrade"]


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
        sw.put(0, i, C.render_stylized(ENV_STYLE))
    sw.save()


# ======================================================================= props

def _vase(M, r, x, y, h, body):
    C.cyl(0.13 * h, 0.08 * h, (x, y, 0.04 * h), M["black"], r, verts=16, r2=0.16 * h)
    C.sphere(0.24 * h, (x, y, 0.36 * h), body, r, scale=(1.0, 1.0, 1.25))
    C.cyl(0.1 * h, 0.3 * h, (x, y, 0.75 * h), body, r, verts=16, r2=0.12 * h)
    C.cyl(0.13 * h, 0.05 * h, (x, y, 0.9 * h), M["black"], r, verts=16)
    C.cyl(0.245 * h, 0.08 * h, (x, y, 0.42 * h), M["black"], r, verts=20)
    for s in (-1, 1):
        C.torus(0.08 * h, 0.018 * h, (x, y + s * 0.15 * h, 0.7 * h), body, r, rot=(math.pi / 2, 0, 0), seg=12, mseg=4)


def prop_barrel(M, frame):  # explosive fire urn
    r = C.empty("urn")
    _vase(M, r, 0, 0, 1.1, M["banner"])
    C.cyl(0.11, 0.26, (0, 0, 1.12), M["fire"], r, r2=0.0, verts=8)
    C.box((0.05, 0.2, 0.2), (0.27, 0, 0.42), M["ember"], r, bevel=0.0, rot=(0, 0, 0.0))
    return r


def prop_crate(M, frame):  # amphora pair — breaks into supplies
    r = C.empty("amphorae")
    _vase(M, r, -0.12, 0.15, 1.0, M["terracotta"])
    _vase(M, r, 0.24, -0.18, 0.75, M["terracotta"])
    return r


def prop_chest(M, frame):
    r = C.empty("chest")
    C.box((0.9, 1.4, 0.55), (0, 0, 0.275), M["bronze"], r, bevel=0.06)
    for y in (-0.5, 0.0, 0.5):
        C.box((0.92, 0.08, 0.57), (0, y, 0.28), M["gold"], r, bevel=0.01)
    lid = C.empty("lid", (-0.45, 0, 0.55), r)
    C.cyl(0.45, 1.4, (0.45, 0, 0.0), M["bronze"], lid, rot=(math.pi / 2, 0, 0), verts=20, bevel=0.03)
    C.box((0.1, 0.25, 0.16), (0.88, 0, 0.0), M["gold"], lid, bevel=0.02)
    if frame == 1:
        lid.rotation_euler = (0, -1.9, 0)
        C.box((0.7, 1.2, 0.05), (0, 0, 0.5), M["fire"], r, bevel=0.0)
    return r


def prop_eggs(M, frame):  # soul nest: bone pile + green cocoon flames
    r = C.empty("nest")
    rng = random.Random(11)
    C.sphere(0.6, (0, 0, 0.0), M["rock"], r, scale=(1.2, 1.1, 0.22), subsurf=1, displace=0.05)
    for i in range(9):
        a = rng.uniform(0, 6.28)
        C.cyl(0.035, 0.5, (0.45 * math.cos(a), 0.45 * math.sin(a), 0.1), M["bone"], r, verts=8,
              rot=(math.pi / 2 + rng.uniform(-0.4, 0.4), 0, a + 1.4))
    for (x, y) in ((0.3, -0.25), (-0.3, 0.3)):
        C.sphere(0.1, (x, y, 0.12), M["bone"], r, scale=(1.1, 0.9, 1.0))
    grow = 1.12 if frame == 1 else 1.0
    for i in range(5):
        a = i * 2 * math.pi / 5
        flame(M, r, (0.16 * math.cos(a), 0.16 * math.sin(a), 0.05), rng.uniform(0.6, 0.95) * grow, rng, i % 2 == 0)
    C.sphere(0.2 * grow, (0, 0, 0.22), M["soul"], r, scale=(1, 1, 1.2))
    return r


def prop_crystals(M, frame):  # soul brazier
    r = C.empty("brazier")
    for i in range(3):
        a = i * 2 * math.pi / 3
        C.tube_between((0.32 * math.cos(a), 0.32 * math.sin(a), 0.0), (0.12 * math.cos(a), 0.12 * math.sin(a), 0.75), 0.04,
                       M["bronze"], r)
    C.cyl(0.36, 0.2, (0, 0, 0.82), M["bronze"], r, verts=20, r2=0.42, bevel=0.02)
    C.torus(0.42, 0.03, (0, 0, 0.92), M["gold"], r, seg=24, mseg=6)
    rng = random.Random(2)
    for i in range(4):
        a = i * 2 * math.pi / 4
        flame(M, r, (0.12 * math.cos(a), 0.12 * math.sin(a), 0.9), rng.uniform(0.5, 0.8), rng, i % 2 == 0)
    return r


def prop_canisters(M, frame):  # candle cluster
    r = C.empty("candles")
    rng = random.Random(9)
    C.sphere(0.36, (0, 0, 0.0), M["wax"], r, scale=(1.2, 1.0, 0.12))
    for (x, y, h) in ((0, 0, 0.5), (0.2, -0.12, 0.34), (-0.16, 0.18, 0.4), (0.18, 0.2, 0.24), (-0.22, -0.15, 0.28)):
        C.cyl(0.055, h, (x, y, h / 2), M["wax"], r, verts=12, bevel=0.01)
        C.sphere(0.04, (x, y, h + 0.06), M["fire"], r, scale=(0.7, 0.7, 1.5), segs=8)
    return r


def prop_pylon(M, frame):  # candelabra
    r = C.empty("candelabra")
    C.cyl(0.26, 0.08, (0, 0, 0.04), M["iron"], r, verts=6, bevel=0.01)
    C.cyl(0.04, 1.8, (0, 0, 0.95), M["iron"], r, verts=8)
    for z, rad in ((1.5, 0.32), (1.9, 0.0)):
        if rad > 0:
            C.torus(rad, 0.02, (0, 0, z), M["iron"], r, seg=20, mseg=4)
        for i in range(4 if rad > 0 else 1):
            a = i * math.pi / 2
            p = (rad * math.cos(a), rad * math.sin(a), z)
            C.cyl(0.05, 0.16, (p[0], p[1], z + 0.08), M["wax"], r, verts=10)
            C.sphere(0.045, (p[0], p[1], z + 0.22), M["fire"], r, scale=(0.7, 0.7, 1.6), segs=8)
    return r


def prop_tube(M, frame):  # broken hooded statue on a plinth
    r = C.empty("statue")
    C.box((0.9, 0.9, 0.4), (0, 0, 0.2), M["wall2"], r, bevel=0.04)
    C.box((0.92, 0.92, 0.05), (0, 0, 0.4), M["gold"], r, bevel=0.01)
    C.cyl(0.34, 1.2, (0, 0, 1.02), M["marble"], r, verts=16, r2=0.22, bevel=0.02)
    C.sphere(0.24, (0.02, 0, 1.75), M["marble"], r, scale=(1.0, 0.95, 1.2))
    C.sphere(0.2, (0.1, 0, 1.72), M["black"], r, scale=(0.6, 0.8, 0.9))
    C.box((0.2, 0.5, 0.14), (0.24, 0, 1.15), M["marble"], r, bevel=0.03, rot=(0, -0.4, 0))
    return r


PROPS = {
    # name: (builder, frames, (w, h, origin))
    "barrel": (prop_barrel, 1, (112, 160, (56, 120))),
    "crate": (prop_crate, 1, (144, 160, (72, 116))),
    "chest": (prop_chest, 2, (176, 160, (88, 108))),
    "eggs": (prop_eggs, 2, (192, 176, (96, 112))),
    "crystals": (prop_crystals, 1, (160, 200, (80, 140))),
    "canisters": (prop_canisters, 1, (128, 112, (64, 72))),
    "pylon": (prop_pylon, 1, (112, 240, (56, 200))),
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
            build(M, f)
            sw.put(0, f, C.render_stylized(ENV_STYLE))
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
