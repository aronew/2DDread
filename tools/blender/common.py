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
SS = 2              # supersampling factor for the stylized (ink) renders
CAM_DIST = 60.0     # camera distance from target (depth pass normalisation)


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


def setup_camera(width, height, origin_px, ss=None):
    """Ortho iso camera framing a width x height image with world origin at origin_px.
    Renders at ss x resolution; stylize() downsamples back to width x height."""
    ss = SS if ss is None else ss
    width, height, origin_px = width * ss, height * ss, (origin_px[0] * ss, origin_px[1] * ss)
    sc = bpy.context.scene
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    cam_data = bpy.data.cameras.get("IsoCam") or bpy.data.cameras.new("IsoCam")
    cam_data.type = "ORTHO"
    m = max(width, height)
    cam_data.ortho_scale = m / (PX_PER_M * ss)
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
    cam.location = back * CAM_DIST
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


TEX_DIR = os.path.join(ROOT, "tools", "blender", "textures")


def tex_path(filename):
    """Full path of a painted texture in tools/blender/textures, or None if it isn't there."""
    p = os.path.join(TEX_DIR, filename)
    return p if os.path.exists(p) else None


def mat(name, color, metal=0.0, rough=0.5, emit=None, emit_strength=0.0, coat=0.0,
        noise=0.0, noise_scale=8.0, noise_color=None, bump=0.0, spec=0.5, subsurface=0.0,
        tex=None, tex_size=(2.0, 2.0, 2.0), tex_rot=0.0, tex_emit=False, tex_proj="BOX",
        tex_extension="REPEAT", tex_gain=1.0):
    """Principled material + emission-only branch selectable via the PASS value node.

    tex: path to a painted texture (see tex_path). It replaces `color` (and any noise)
    as the base colour, and also feeds the flat albedo pass, so it reaches the final
    sprite. It is projected in object space, centred on the object's origin, with
    tex_size = metres per repeat along object X, Y, Z; tex_rot turns it about Z (radians).
    tex_proj "BOX" suits blocks seen from the side (walls); "FLAT" maps X to the image's
    width and Y to its height, which is what floor surfaces want (Cycles' box projection
    swaps the axes on upward faces). tex_extension "EXTEND" stops a single, non-tiling
    image (an emblem) from repeating past its edges. tex_gain brightens (>1) or darkens
    the painted colour without editing the image file.
    tex_emit: the texture is light on black (e.g. flames) and drives the emission too;
    pass emit and emit_strength as for any glowing material.
    With tex=None the material is built exactly as before."""
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
    img = None
    if tex is not None:
        ttc = nodes.new("ShaderNodeTexCoord")
        tmap = nodes.new("ShaderNodeMapping")
        tmap.inputs["Scale"].default_value = tuple(1.0 / v if abs(v) > 1e-6 else 1e6 for v in tex_size)
        tmap.inputs["Rotation"].default_value = (0.0, 0.0, tex_rot)
        tmap.inputs["Location"].default_value = (0.5, 0.5, 0.5)
        img = nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(tex, check_existing=True)
        img.image.colorspace_settings.name = "sRGB"
        img.projection = tex_proj
        img.projection_blend = 0.0
        img.extension = tex_extension
        links.new(ttc.outputs["Object"], tmap.inputs["Vector"])
        links.new(tmap.outputs["Vector"], img.inputs["Vector"])
        tex_out = img.outputs["Color"]
        if abs(tex_gain - 1.0) > 1e-3:
            gain = nodes.new("ShaderNodeVectorMath")
            gain.operation = "MULTIPLY"
            gain.inputs[1].default_value = (tex_gain, tex_gain, tex_gain)
            links.new(tex_out, gain.inputs[0])
            tex_out = gain.outputs["Vector"]
        links.new(tex_out, bsdf.inputs["Base Color"])
    use_noise = noise > 0 and tex is None
    if use_noise or bump > 0:
        tc = nodes.new("ShaderNodeTexCoord")
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = noise_scale
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Roughness"].default_value = 0.6
        links.new(tc.outputs["Object"], nz.inputs["Vector"])
        if use_noise:
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
    # --- stylized-pipeline branches: flat albedo and meta (metal, emissive, depth)
    alb = nodes.new("ShaderNodeEmission")
    bc_link = bsdf.inputs["Base Color"].links
    if bc_link:
        links.new(bc_link[0].from_socket, alb.inputs["Color"])
    else:
        alb.inputs["Color"].default_value = (*color, 1.0)
    if emit is not None:
        alb.inputs["Color"].default_value = (*emit, 1.0)
        if bc_link:
            links.remove(alb.inputs["Color"].links[0])
    if img is not None and tex_emit:
        # painted light: the texture is the glow colour in every pass
        links.new(tex_out, em.inputs["Color"])
        links.new(tex_out, bsdf.inputs["Emission Color"])
        links.new(tex_out, alb.inputs["Color"])
    camd = nodes.new("ShaderNodeCameraData")
    dmath = nodes.new("ShaderNodeMapRange")
    dmath.inputs["From Min"].default_value = CAM_DIST - 7.0
    dmath.inputs["From Max"].default_value = CAM_DIST + 7.0
    links.new(camd.outputs["View Z Depth"], dmath.inputs["Value"])
    comb = nodes.new("ShaderNodeCombineXYZ")
    comb.inputs[0].default_value = min(1.0, metal * 1.2)
    comb.inputs[1].default_value = 1.0 if emit is not None and emit_strength >= 1.5 else 0.0
    links.new(dmath.outputs["Result"], comb.inputs[2])
    meta = nodes.new("ShaderNodeEmission")
    links.new(comb.outputs["Vector"], meta.inputs["Color"])
    m_alb = nodes.new("ShaderNodeMixShader")
    v_alb = nodes.new("ShaderNodeValue")
    v_alb.name = "ALB"
    links.new(v_alb.outputs[0], m_alb.inputs["Fac"])
    links.new(mixs.outputs["Shader"], m_alb.inputs[1])
    links.new(alb.outputs["Emission"], m_alb.inputs[2])
    m_meta = nodes.new("ShaderNodeMixShader")
    v_meta = nodes.new("ShaderNodeValue")
    v_meta.name = "META"
    links.new(v_meta.outputs[0], m_meta.inputs["Fac"])
    links.new(m_alb.outputs["Shader"], m_meta.inputs[1])
    links.new(meta.outputs["Emission"], m_meta.inputs[2])
    links.new(m_meta.outputs["Shader"], out.inputs["Surface"])
    _MATS[name] = m
    return m


def light_override_material():
    """Plain white diffuse: renders pure lighting (incl. self-shadowing) for toon banding."""
    m = bpy.data.materials.get("__LIGHT__")
    if m:
        return m
    m = bpy.data.materials.new("__LIGHT__")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    d = nt.nodes.new("ShaderNodeBsdfDiffuse")
    d.inputs["Color"].default_value = (0.8, 0.8, 0.8, 1.0)
    nt.links.new(d.outputs["BSDF"], out.inputs["Surface"])
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


def _branch(pas=0.0, alb=0.0, meta=0.0):
    for m in _MATS.values():
        n = m.node_tree.nodes
        n["PASS"].outputs[0].default_value = pas
        n["ALB"].outputs[0].default_value = alb
        n["META"].outputs[0].default_value = meta


def set_pass(kind):
    """kind in {'color', 'normal', 'emit', 'albedo', 'light', 'meta'}"""
    sc = bpy.context.scene
    vl = sc.view_layers[0]
    world_bg = sc.world.node_tree.nodes["Background"]
    if kind in ("albedo", "meta"):
        vl.material_override = None
        sc.view_settings.view_transform = "Standard" if kind == "albedo" else "Raw"
        sc.cycles.samples = 4
        sc.cycles.use_denoising = False
        world_bg.inputs[1].default_value = 0.0
        _branch(alb=1.0 if kind == "albedo" else 0.0, meta=1.0 if kind == "meta" else 0.0)
        _set_lights(False)
        return
    if kind == "light":
        vl.material_override = light_override_material()
        sc.view_settings.view_transform = "Raw"
        sc.cycles.samples = 14
        sc.cycles.use_denoising = True
        world_bg.inputs[1].default_value = 0.25
        _set_lights(True)
        return
    _branch()
    if kind == "color":
        vl.material_override = None
        sc.view_settings.view_transform = "Standard"
        sc.cycles.samples = QUALITY["samples"]
        sc.cycles.use_denoising = True
        world_bg.inputs[1].default_value = sc.get("world_strength", 0.55)
        _set_lights(True)
    elif kind == "normal":
        vl.material_override = normal_override_material()
        sc.view_settings.view_transform = "Raw"
        sc.cycles.samples = 4
        sc.cycles.use_denoising = False
        _set_lights(False)
    elif kind == "emit":
        vl.material_override = None
        sc.view_settings.view_transform = "Standard"
        sc.cycles.samples = 4
        sc.cycles.use_denoising = False
        world_bg.inputs[1].default_value = 0.0
        _branch(pas=1.0)
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


STYLE = {
    "bands": (0.22, 0.52),      # light thresholds between shadow / mid / lit
    "levels": (0.42, 0.76, 1.02), # brightness of each band
    "soft": 0.035,              # band edge softness
    "shadow_tint": (0.56, 0.46, 0.86),
    "outline_px": 4,            # outer silhouette (at SS resolution)
    "inner_px": 1,              # inner line dilation (at SS resolution)
    "depth_edge": 0.018,
    "normal_edge": 0.30,
    "color_edge": 0.20,
    "color_line": 0.55,         # opacity of albedo-boundary lines
    "line_color": (0.05, 0.035, 0.05),
    "grain": 0.06,
}


def render_stylized(style=None):
    """Hand-inked, cel-shaded frame: returns {'color','normal','emit'} at final size."""
    st = dict(STYLE)
    if style:
        st.update(style)
    raw = {}
    for p in ("albedo", "light", "meta", "normal", "emit"):
        set_pass(p)
        raw[p] = _render_to_array(os.path.join(_TMP, "s_%s.png" % p))
    set_pass("color")
    return stylize(raw, st)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / max(e1 - e0, 1e-6), 0, 1)
    return t * t * (3 - 2 * t)


def _dilate(mask, r):
    if r <= 0:
        return mask
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + r * 0.5:
                continue
            out = np.maximum(out, np.roll(np.roll(mask, dy, 0), dx, 1))
    return out


_GRAIN = None


def _grain(h, w):
    global _GRAIN
    if _GRAIN is None or _GRAIN.shape != (h, w):
        g = np.random.default_rng(3).random((h // 4 + 2, w // 4 + 2))
        g = np.kron(g, np.ones((4, 4)))[:h, :w]
        g = (g + np.roll(g, 2, 0) + np.roll(g, 2, 1) + np.roll(np.roll(g, 2, 0), 2, 1)) / 4
        _GRAIN = g
    return _GRAIN


def stylize(raw, st):
    alb = raw["albedo"][..., :3].astype(np.float32) / 255.0
    a = raw["albedo"][..., 3].astype(np.float32) / 255.0
    lit = raw["light"][..., :3].astype(np.float32).mean(axis=2) / 255.0
    meta = raw["meta"][..., :3].astype(np.float32) / 255.0
    nrm = raw["normal"][..., :3].astype(np.float32) / 255.0
    emit = raw["emit"][..., :3].astype(np.float32) / 255.0
    h, w = a.shape
    solid = a > 0.5
    # --- toon bands
    t1, t2 = st["bands"]
    s1 = _smooth(t1 - st["soft"], t1 + st["soft"], lit)
    s2 = _smooth(t2 - st["soft"], t2 + st["soft"], lit)
    lv = st["levels"]
    shade = lv[0] + (lv[1] - lv[0]) * s1 + (lv[2] - lv[1]) * s2
    tint = np.array(st["shadow_tint"], np.float32)
    tint_mix = tint[None, None, :] + (1 - tint[None, None, :]) * s1[..., None]
    col = alb * shade[..., None] * tint_mix
    # metal glints (gold trim, blades)
    metal = meta[..., 0]
    glint = _smooth(0.66, 0.74, lit) * (metal > 0.4) * 0.75
    col = col * (1 - 0.55 * glint[..., None]) + (alb * 1.5 + 0.12) * 0.55 * glint[..., None]
    # painterly grain in shadows
    g = _grain(h, w)
    col *= (1 + (g[..., None] - 0.5) * st["grain"] * (1.6 - s1[..., None]))
    # emissive parts stay flat and bright
    em_flag = meta[..., 1] > 0.5
    col[em_flag] = alb[em_flag]
    # --- ink lines
    depth = meta[..., 2]
    def nbr_diff(img):
        dx = np.abs(img - np.roll(img, 1, 1))
        dy = np.abs(img - np.roll(img, 1, 0))
        return np.maximum(dx, dy)
    d_edge = nbr_diff(depth) > st["depth_edge"]
    n = nrm * 2 - 1
    ndx = (n * np.roll(n, 1, 1)).sum(2)
    ndy = (n * np.roll(n, 1, 0)).sum(2)
    n_edge = np.minimum(ndx, ndy) < (1 - st["normal_edge"])
    c_edge = nbr_diff(alb).max(axis=2) > st["color_edge"]
    both = solid & np.roll(solid, 1, 0) & np.roll(solid, 1, 1)
    both[0, :] = False
    both[:, 0] = False
    hard = (d_edge | n_edge) & both & ~em_flag
    soft = c_edge & both & ~hard & ~em_flag
    hard = _dilate(hard.astype(np.float32), st["inner_px"])
    soft = _dilate(soft.astype(np.float32), max(0, st["inner_px"] - 1)) * st["color_line"]
    line = np.maximum(hard, soft)[..., None]
    lc = np.array(st["line_color"], np.float32)[None, None, :] + alb * 0.12
    col = col * (1 - line) + lc * line
    # outer silhouette outline
    outer = _dilate(a, st["outline_px"])
    ring = np.clip(outer - a, 0, 1)
    out_rgb = col * a[..., None] + lc * ring[..., None]
    out_a = np.clip(a + ring, 0, 1)
    out_rgb = np.where(out_a[..., None] > 0, out_rgb / np.maximum(out_a[..., None], 1e-4), 0)
    # normals: flat in the outline ring
    nrm_out = nrm.copy()
    nrm_out[ring > 0.5] = (0.5, 0.5, 1.0)
    return {
        "color": _down(np.dstack([np.clip(out_rgb, 0, 1), out_a])),
        "normal": _down(np.dstack([nrm_out, out_a])),
        "emit": _down(np.dstack([emit * (a[..., None]), np.ones_like(a)])),
    }


def _down(rgba):
    """Premultiplied 1/SS downsample -> uint8 RGBA."""
    h, w = rgba.shape[:2]
    pm = rgba.copy()
    pm[..., :3] *= pm[..., 3:4]
    im = Image.fromarray((np.clip(pm, 0, 1) * 255).astype(np.uint8), "RGBA")
    im = im.resize((w // SS, h // SS), Image.LANCZOS)
    out = np.array(im).astype(np.float32) / 255.0
    out[..., :3] = np.where(out[..., 3:4] > 0.003, out[..., :3] / np.maximum(out[..., 3:4], 1e-4), 0)
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


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
