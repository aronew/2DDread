"""Shared Blender rig for rendering isometric sprite sheets.

Every asset is rendered from the same orthographic camera so that all sprites
share one projection:

  * elevation  = asin(ISO_K)  (~48.6 deg)  -> a ground diamond is 4:3 (256x192)
  * azimuth    = 45 deg        -> world +X runs to the screen lower-right
  * PX_PER_M   = 90.51         -> a 2 m floor tile is exactly 256 px wide

Three passes are produced per frame:
  _c  colour  (lit albedo, Standard view transform)
  _n  normal  (top-down normal frame: R = screen right, G = screen up,
               B = world up -> matches Godot's Light2D "height" model)
  _e  emission only (drawn additively + HDR glow in Godot)

The "ground frame" used by the game is (u, v): u = screen right, v = toward
the camera (screen down).  A facing angle phi in that frame maps to a Blender
yaw of (45deg - phi) for a model whose forward axis is +X.
"""
import bpy
import bmesh
import math
import os
import json
import shutil
import tempfile
from mathutils import Vector, Euler, Matrix

import numpy as np
from PIL import Image

ISO_K = 0.75
ELEV = math.asin(ISO_K)
COS_EL = math.cos(ELEV)
PX_PER_M = 256.0 / (2.0 * math.sqrt(2.0))  # 90.51

U_AXIS = Vector((1, 1, 0)).normalized()   # screen right on the ground
V_AXIS = Vector((1, -1, 0)).normalized()  # toward camera on the ground

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites")

QUALITY = {"samples": 40, "normal_samples": 6, "emit_samples": 6}


# --------------------------------------------------------------------------
# Scene
# --------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = QUALITY["samples"]
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 2
    sc.cycles.transmission_bounces = 2
    sc.cycles.transparent_max_bounces = 4
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.blur_glossy = 1.0
    sc.render.film_transparent = True
    sc.render.dither_intensity = 0.0
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.render.use_persistent_data = True
    world = bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.47, 0.55, 1.0)
    bg.inputs[1].default_value = 0.55
    _MATS.clear()
    return sc


def setup_camera(width, height, origin_px):
    """Ortho iso camera framing a width x height image with world origin at origin_px."""
    sc = bpy.context.scene
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    cam_data = bpy.data.cameras.get("IsoCam") or bpy.data.cameras.new("IsoCam")
    cam_data.type = "ORTHO"
    m = max(width, height)
    cam_data.ortho_scale = m / PX_PER_M
    cam_data.shift_x = (width / 2.0 - origin_px[0]) / m
    cam_data.shift_y = (origin_px[1] - height / 2.0) / m
    cam_data.clip_start = 0.1
    cam_data.clip_end = 200.0
    cam = bpy.data.objects.get("IsoCam")
    if cam is None:
        cam = bpy.data.objects.new("IsoCam", cam_data)
        sc.collection.objects.link(cam)
    cam.rotation_euler = Euler((math.pi / 2 - ELEV, 0.0, math.radians(45.0)))
    back = cam.rotation_euler.to_matrix() @ Vector((0, 0, 1))
    cam.location = back * 60.0
    sc.camera = cam
    return cam


def ground_dir_world(u, v):
    """Convert a ground-frame direction (u right, v toward camera) to world XY."""
    return (U_AXIS * u + V_AXIS * v)


def setup_lights(key=3.2, fill=0.9, rim=2.2, key_color=(1.0, 0.95, 0.88), rim_color=(0.55, 0.75, 1.0)):
    """Key light from screen upper-left, soft fill from the camera, cool rim from behind."""
    sc = bpy.context.scene

    def sun(name, energy, color, direction, angle_deg):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(angle_deg)
        ob = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(ob)
        d = Vector(direction).normalized()  # direction light travels
        ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        return ob

    # light travels from upper-left-back (screen) toward lower-right-front
    k_dir = ground_dir_world(0.55, 0.35) + Vector((0, 0, -1.15))
    sun("Key", key, key_color, k_dir, 18)
    f_dir = ground_dir_world(-0.2, -1.0) + Vector((0, 0, -0.6))
    sun("Fill", fill, (0.75, 0.82, 1.0), f_dir, 40)
    r_dir = ground_dir_world(-0.3, 1.0) + Vector((0, 0, -0.35))
    sun("Rim", rim, rim_color, r_dir, 10)


# --------------------------------------------------------------------------
# Materials (pass-switchable)
# --------------------------------------------------------------------------

_MATS = {}


def mat(name, color, metal=0.0, rough=0.5, emit=None, emit_strength=0.0, coat=0.0,
        noise=0.0, noise_scale=8.0, noise_color=None, bump=0.0, spec=0.5, subsurface=0.0):
    """Principled material + emission-only branch selectable via the PASS value node."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = spec
    if coat > 0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.15
    if subsurface > 0:
        bsdf.inputs["Subsurface Weight"].default_value = subsurface
        bsdf.inputs["Subsurface Radius"].default_value = (0.3, 0.1, 0.1)
        bsdf.inputs["Subsurface Scale"].default_value = 0.05
    if noise > 0 or bump > 0:
        tc = nodes.new("ShaderNodeTexCoord")
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = noise_scale
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Roughness"].default_value = 0.6
        links.new(tc.outputs["Object"], nz.inputs["Vector"])
        if noise > 0:
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].position = 0.35
            ramp.color_ramp.elements[1].position = 0.75
            links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.inputs["Factor"].default_value = noise
            links.new(ramp.outputs["Color"], mix.inputs["Factor"])
            mix.inputs[6].default_value = (*color, 1.0)
            nc = noise_color if noise_color else tuple(c * 0.45 for c in color)
            mix.inputs[7].default_value = (*nc, 1.0)
            # scale factor by noise amount
            mul = nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = noise
            links.new(ramp.outputs["Color"], mul.inputs[0])
            links.new(mul.outputs[0], mix.inputs["Factor"])
            links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        if bump > 0:
            bmp = nodes.new("ShaderNodeBump")
            bmp.inputs["Strength"].default_value = bump
            bmp.inputs["Distance"].default_value = 0.02
            links.new(nz.outputs["Fac"], bmp.inputs["Height"])
            links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
    em = nodes.new("ShaderNodeEmission")
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_strength * 0.16
        em.inputs["Color"].default_value = (*emit, 1.0)
        em.inputs["Strength"].default_value = min(1.0, emit_strength)
    else:
        em.inputs["Color"].default_value = (0, 0, 0, 1)
        em.inputs["Strength"].default_value = 0.0
    mixs = nodes.new("ShaderNodeMixShader")
    val = nodes.new("ShaderNodeValue")
    val.name = "PASS"
    val.outputs[0].default_value = 0.0
    links.new(val.outputs[0], mixs.inputs["Fac"])
    links.new(bsdf.outputs["BSDF"], mixs.inputs[1])
    links.new(em.outputs["Emission"], mixs.inputs[2])
    links.new(mixs.outputs["Shader"], out.inputs["Surface"])
    _MATS[name] = m
    return m


def normal_override_material():
    m = bpy.data.materials.get("__NORMAL__")
    if m:
        return m
    m = bpy.data.materials.new("__NORMAL__")
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    geo = nodes.new("ShaderNodeNewGeometry")
    comps = []
    for axis in (U_AXIS, -V_AXIS, Vector((0, 0, 1))):  # R=right, G=screen up (away), B=world up
        dp = nodes.new("ShaderNodeVectorMath")
        dp.operation = "DOT_PRODUCT"
        dp.inputs[1].default_value = axis
        links.new(geo.outputs["Normal"], dp.inputs[0])
        mad = nodes.new("ShaderNodeMath")
        mad.operation = "MULTIPLY_ADD"
        mad.inputs[1].default_value = 0.5
        mad.inputs[2].default_value = 0.5
        links.new(dp.outputs["Value"], mad.inputs[0])
        comps.append(mad)
    comb = nodes.new("ShaderNodeCombineXYZ")
    for i, c in enumerate(comps):
        links.new(c.outputs[0], comb.inputs[i])
    em = nodes.new("ShaderNodeEmission")
    links.new(comb.outputs["Vector"], em.inputs["Color"])
    links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def set_pass(kind):
    """kind in {'color', 'normal', 'emit'}"""
    sc = bpy.context.scene
    vl = sc.view_layers[0]
    world_bg = sc.world.node_tree.nodes["Background"]
    if kind == "color":
        vl.material_override = None
        sc.view_settings.view_transform = "Standard"
        sc.cycles.samples = QUALITY["samples"]
        sc.cycles.use_denoising = True
        world_bg.inputs[1].default_value = sc.get("world_strength", 0.55)
        for m in _MATS.values():
            m.node_tree.nodes["PASS"].outputs[0].default_value = 0.0
        _set_lights(True)
    elif kind == "normal":
        vl.material_override = normal_override_material()
        sc.view_settings.view_transform = "Raw"
        sc.cycles.samples = QUALITY["normal_samples"]
        sc.cycles.use_denoising = False
        _set_lights(False)
    elif kind == "emit":
        vl.material_override = None
        sc.view_settings.view_transform = "Standard"
        sc.cycles.samples = QUALITY["emit_samples"]
        sc.cycles.use_denoising = False
        world_bg.inputs[1].default_value = 0.0
        for m in _MATS.values():
            m.node_tree.nodes["PASS"].outputs[0].default_value = 1.0
        _set_lights(False)


def _set_lights(on):
    for ob in bpy.context.scene.objects:
        if ob.type == "LIGHT":
            ob.hide_render = not on


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

def _link(ob, parent=None):
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    ob.location = loc
    ob.rotation_euler = rot
    return _link(ob, parent)


def _mesh_obj(name, bm, material, parent, loc, rot, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    if material is not None:
        me.materials.append(material)
    ob.location = loc
    ob.rotation_euler = rot
    return _link(ob, parent)


def _bevel(ob, width, segments=2):
    if width <= 0:
        return ob
    md = ob.modifiers.new("Bevel", "BEVEL")
    md.width = width
    md.segments = segments
    md.limit_method = "ANGLE"
    md.harden_normals = False
    return ob


def box(size, loc=(0, 0, 0), material=None, parent=None, rot=(0, 0, 0), bevel=0.02, name="box", segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = _mesh_obj(name, bm, material, parent, loc, rot)
    return _bevel(ob, min(bevel, min(size) * 0.45), segs)


def wedge(size, loc=(0, 0, 0), material=None, parent=None, rot=(0, 0, 0), taper=(0.6, 0.6), bevel=0.015, name="wedge"):
    """Box whose top face is scaled by taper (x,y) -> armour plates, tapered limbs."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= taper[0]
            v.co.y *= taper[1]
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = _mesh_obj(name, bm, material, parent, loc, rot)
    return _bevel(ob, min(bevel, min(size) * 0.3))


def cyl(radius, depth, loc=(0, 0, 0), material=None, parent=None, rot=(0, 0, 0), verts=20, bevel=0.01,
        name="cyl", r2=None, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=depth)
    ob = _mesh_obj(name, bm, material, parent, loc, rot, smooth=smooth)
    return _bevel(ob, bevel, 2)


def sphere(radius, loc=(0, 0, 0), material=None, parent=None, rot=(0, 0, 0), scale=(1, 1, 1), segs=24,
           name="sph", subsurf=0, displace=0.0, disp_scale=1.5):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=max(8, segs // 2), radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = _mesh_obj(name, bm, material, parent, loc, rot, smooth=True)
    if subsurf:
        md = ob.modifiers.new("Sub", "SUBSURF")
        md.levels = subsurf
        md.render_levels = subsurf
    if displace > 0:
        tex = bpy.data.textures.new(name + "_dt", "CLOUDS")
        tex.noise_scale = 0.25 * disp_scale
        md = ob.modifiers.new("Disp", "DISPLACE")
        md.texture = tex
        md.strength = displace
        md.mid_level = 0.5
    return ob


def torus(major, minor, loc=(0, 0, 0), material=None, parent=None, rot=(0, 0, 0), name="torus", seg=32, mseg=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg,
                                     minor_segments=mseg, location=(0, 0, 0))
    ob = bpy.context.object
    ob.name = name
    ob.data.materials.append(material) if material else None
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.location = loc
    ob.rotation_euler = rot
    if parent is not None:
        ob.parent = parent
    return ob


def tube_between(p0, p1, radius, material=None, parent=None, verts=12, name="tube", r2=None):
    """Cylinder from p0 to p1 (in parent space)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    length = d.length
    mid = (p0 + p1) / 2
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cyl(radius, length, loc=mid, material=material, parent=parent, rot=rot, verts=verts, bevel=0.0,
               name=name, r2=r2)


def clear_scene_objects():
    for ob in list(bpy.context.scene.objects):
        if ob.type in ("MESH", "EMPTY", "CURVE") and not ob.name.startswith("__"):
            bpy.data.objects.remove(ob, do_unlink=True)


def shadow_catcher(size=12.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    me = bpy.data.meshes.new("__catcher")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("__catcher", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.is_shadow_catcher = True
    return ob


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

_TMP = tempfile.mkdtemp(prefix="isorender_")


def _render_to_array(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = Image.open(path).convert("RGBA")
    return np.array(im)


def render_passes(passes=("color", "normal", "emit")):
    out = {}
    for p in passes:
        set_pass(p)
        out[p] = _render_to_array(os.path.join(_TMP, "f_%s.png" % p))
    set_pass("color")
    return out


def yaw_for_ground_angle(phi):
    """Blender Z rotation for a +X-forward model to face ground angle phi."""
    return math.pi / 4 - phi


class SheetWriter:
    """Packs frames into rows (directions) x cols (frames) for each pass."""

    def __init__(self, category, name, frame_w, frame_h, origin, rows, cols, passes=("color", "normal", "emit"),
                 meta=None):
        self.category, self.name = category, name
        self.fw, self.fh = frame_w, frame_h
        self.rows, self.cols = rows, cols
        self.origin = origin
        self.passes = passes
        self.meta = meta or {}
        self.sheets = {p: np.zeros((rows * frame_h, cols * frame_w, 4), dtype=np.uint8) for p in passes}

    def put(self, row, col, frames):
        for p, arr in frames.items():
            if p in self.sheets:
                y, x = row * self.fh, col * self.fw
                self.sheets[p][y:y + self.fh, x:x + self.fw] = arr

    def save(self):
        d = os.path.join(OUT, self.category)
        os.makedirs(d, exist_ok=True)
        suffix = {"color": "c", "normal": "n", "emit": "e", "shadow": "s"}
        files = {}
        for p, arr in self.sheets.items():
            if p == "emit":
                # skip empty emission sheets
                if arr[..., :3].max() < 8:
                    continue
                # emission is drawn additively: premultiply so alpha never matters
                rgb = arr[..., :3].astype(np.float32) * (arr[..., 3:4].astype(np.float32) / 255.0)
                arr = np.clip(rgb, 0, 255).astype(np.uint8)  # RGB only, black = no light
            if p == "normal":
                # flat-fill transparent area with neutral up normal to keep filtering clean
                a = arr[..., 3:4]
                neutral = np.array([128, 128, 255, 0], dtype=np.uint8)
                arr = np.where(a > 0, arr, neutral)
                arr[..., 3] = np.maximum(a[..., 0], 0)
            fn = "%s_%s.png" % (self.name, suffix[p])
            Image.fromarray(arr).save(os.path.join(d, fn), optimize=True)
            files[p] = fn
        meta = {
            "name": self.name,
            "frame_w": self.fw,
            "frame_h": self.fh,
            "origin": list(self.origin),
            "rows": self.rows,
            "cols": self.cols,
            "files": files,
        }
        meta.update(self.meta)
        with open(os.path.join(d, self.name + ".json"), "w") as f:
            json.dump(meta, f, indent=1)
        print("[sheet] saved %s/%s  %dx%d frames" % (self.category, self.name, self.rows, self.cols))


def set_threads(n):
    sc = bpy.context.scene
    if n > 0:
        sc.render.threads_mode = "FIXED"
        sc.render.threads = n
