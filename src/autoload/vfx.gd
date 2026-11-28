extends Node
## Reusable effect framework. Everything is pooled; callers speak in
## gameplay terms (ground positions, heights, colours) and VFX handles layers,
## lights, particles, decals, screen feedback.

const MAX_DECALS := 180
const LIGHT_POOL := 28

var fx: Node2D          # additive, unshaded, above entities
var lit: Node2D         # lit world effects (smoke, debris)
var decals: Node2D      # floor decals, telegraphs
var overlay: Node2D     # damage numbers, popups
var camera = null
var post = null

var add_mat: CanvasItemMaterial
var unshaded_mat: CanvasItemMaterial
var T := {}

var _pools := {}
var _lights: Array = []
var _light_i := 0
var _numbers: Array = []
var _num_i := 0
var _decals: Array = []
var _flashes: Array = []
var _flash_i := 0
var _bolts: Array = []
var _bolt_i := 0
var _num_settings: LabelSettings
var _crit_settings: LabelSettings
var _popup_settings: LabelSettings
var _ready_done := false
var particle_scale := 1.0   # graphics preset multiplier


func _ready() -> void:
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	unshaded_mat = CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	T.glow = TexGen.glow()
	T.core = TexGen.core()
	T.ring = TexGen.ring()
	T.shadow = TexGen.shadow()
	T.spark = TexGen.spark()
	T.shard = TexGen.shard()
	T.flash = TexGen.flash(5)
	T.flash_wide = TexGen.flash(9)
	T.star = TexGen.star(4)
	T.star6 = TexGen.star(6)
	T.slash = TexGen.slash()
	T.smoke = TexGen.smoke(64, 3)
	T.light = Dungeon.make_light_texture()
	T.blobs = []
	for i in 4:
		T.blobs.append(TexGen.noise_blob(128, 10 + i, 0.25, 0.42))
	T.splats = []
	for i in 3:
		T.splats.append(TexGen.noise_blob(128, 40 + i, 0.15, 0.55, true))
	T.scorch = TexGen.noise_blob(128, 77, 0.6, 0.35)
	_num_settings = LabelSettings.new()
	_num_settings.font_size = 30
	_num_settings.outline_size = 9
	_num_settings.outline_color = Color(0, 0, 0, 0.9)
	_crit_settings = LabelSettings.new()
	_crit_settings.font_size = 44
	_crit_settings.outline_size = 11
	_crit_settings.outline_color = Color(0.15, 0.0, 0.0, 0.95)
	_popup_settings = LabelSettings.new()
	_popup_settings.font_size = 30
	_popup_settings.outline_size = 9
	_popup_settings.outline_color = Color(0, 0, 0, 0.9)


## Called by Main once the world layers exist.
func setup(fx_: Node2D, lit_: Node2D, decals_: Node2D, overlay_: Node2D) -> void:
	fx = fx_
	lit = lit_
	decals = decals_
	overlay = overlay_
	_pools.clear()
	_lights.clear()
	_numbers.clear()
	_decals.clear()
	_flashes.clear()
	_bolts.clear()
	_make_pool("sparks", 14, {"amount": 22, "life": 0.32, "tex": T.spark, "spread": 55.0, "v": [300, 900],
		"grav": 1100.0, "damp": [200, 400], "scale": [0.35, 0.8], "align": true})
	_make_pool("embers", 8, {"amount": 34, "life": 1.0, "tex": T.core, "spread": 180.0, "v": [80, 420],
		"grav": -60.0, "damp": [120, 220], "scale": [0.1, 0.28], "rand_life": 0.5})
	_make_pool("electric", 10, {"amount": 14, "life": 0.22, "tex": T.spark, "spread": 180.0, "v": [200, 700],
		"grav": 0.0, "damp": [600, 900], "scale": [0.25, 0.5], "align": true})
	_make_pool("smoke", 8, {"amount": 12, "life": 1.3, "tex": T.smoke, "spread": 180.0, "v": [20, 110],
		"grav": -50.0, "damp": [30, 60], "scale": [1.2, 2.6], "additive": false, "angle": true, "rand_life": 0.4,
		"fade_in": true})
	_make_pool("blood", 16, {"amount": 22, "life": 0.55, "tex": T.core, "spread": 48.0, "v": [160, 620],
		"grav": 1200.0, "damp": [60, 140], "scale": [0.18, 0.42], "additive": false, "rand_life": 0.3})
	_make_pool("gibs", 8, {"amount": 12, "life": 0.85, "tex": T.shard, "spread": 70.0, "v": [220, 700],
		"grav": 1600.0, "damp": [50, 120], "scale": [0.8, 1.9], "additive": false, "angle": true, "spin": true})
	# small, frequent puffs (muzzle smoke, footsteps) get their own pool so they never steal
	# emitters from explosions and dashes
	_make_pool("puff", 16, {"amount": 5, "life": 0.55, "tex": T.smoke, "spread": 40.0, "v": [30, 90],
		"grav": -40.0, "damp": [60, 120], "scale": [0.35, 0.7], "additive": false, "angle": true, "rand_life": 0.3,
		"fade_in": true})
	# spent brass / shells kicked out of the guns
	_make_pool("casings", 24, {"amount": 1, "life": 0.55, "tex": T.shard, "spread": 22.0, "v": [170, 280],
		"grav": 1500.0, "damp": [30, 60], "scale": [0.26, 0.34], "additive": false, "angle": true, "spin": true,
		"rand_life": 0.1})
	# souls released when something dies: green motes drifting up
	_make_pool("souls", 10, {"amount": 14, "life": 1.1, "tex": T.core, "spread": 30.0, "v": [60, 200],
		"grav": -140.0, "damp": [40, 80], "scale": [0.12, 0.3], "rand_life": 0.4})
	_make_pool("debris", 8, {"amount": 16, "life": 0.9, "tex": T.shard, "spread": 80.0, "v": [200, 650],
		"grav": 1700.0, "damp": [40, 90], "scale": [0.6, 1.5], "additive": false, "angle": true, "spin": true})
	for i in LIGHT_POOL:
		var l := PointLight2D.new()
		l.texture = T.light
		l.enabled = false
		l.height = 70.0
		l.scale = Vector2(1.0, Iso.K)
		fx.add_child(l)
		_lights.append({"l": l, "t": 0.0, "dur": 1.0, "e": 0.0})
	for i in 48:
		var lb := Label.new()
		lb.label_settings = _num_settings
		lb.visible = false
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(160, 50)
		lb.pivot_offset = Vector2(80, 25)
		overlay.add_child(lb)
		_numbers.append(lb)
	# pooled, animated flash layers (muzzle flashes fire ~11 times a second: no new nodes)
	for i in 96:   # muzzle flashes and impacts each use several layers, at ~11 shots a second
		var s := Sprite2D.new()
		s.texture = T.flash
		s.material = add_mat
		s.visible = false
		s.offset = Vector2(44, 0)
		fx.add_child(s)
		_flashes.append({"s": s, "t": 0.0, "dur": 0.05, "s0": Vector2.ONE, "s1": Vector2.ONE, "a": 1.0})
	for i in 48:
		var ln := Line2D.new()
		ln.material = add_mat
		ln.width = 5.0
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.visible = false
		fx.add_child(ln)
		_bolts.append({"ln": ln, "t": 0.0, "dur": 0.1, "a": Vector2.ZERO, "b": Vector2.ZERO, "jag": 1.0, "c": Color.WHITE})
	_ready_done = true


func _make_pool(name: String, n: int, cfg: Dictionary) -> void:
	var items: Array = []
	for i in n:
		var p := _mk_particles(cfg)
		(fx if cfg.get("additive", true) else lit).add_child(p)
		items.append(p)
	_pools[name] = {"items": items, "i": 0}


func _mk_particles(cfg: Dictionary) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = cfg["amount"]
	p.lifetime = cfg["life"]
	p.explosiveness = cfg.get("explo", 1.0)
	p.randomness = 0.3
	p.texture = cfg["tex"]
	p.local_coords = false
	p.visibility_rect = Rect2(-600, -600, 1200, 1200)
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(1, 0, 0)
	m.spread = cfg["spread"]
	m.initial_velocity_min = cfg["v"][0]
	m.initial_velocity_max = cfg["v"][1]
	m.gravity = Vector3(0, cfg.get("grav", 0.0), 0)
	if cfg.has("damp"):
		m.damping_min = cfg["damp"][0]
		m.damping_max = cfg["damp"][1]
	m.scale_min = cfg["scale"][0]
	m.scale_max = cfg["scale"][1]
	m.lifetime_randomness = cfg.get("rand_life", 0.2)
	var sc := Curve.new()
	if cfg.get("fade_in", false):
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(0.3, 1.0))
		sc.add_point(Vector2(1, 1.2))
	else:
		sc.add_point(Vector2(0, 1))
		sc.add_point(Vector2(1, 0.15))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	var g := Gradient.new()
	if cfg.get("fade_in", false):
		g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	m.particle_flag_align_y = cfg.get("align", false)
	if cfg.get("angle", false):
		m.angle_min = -180.0
		m.angle_max = 180.0
	if cfg.get("spin", false):
		m.angular_velocity_min = -720.0
		m.angular_velocity_max = 720.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	p.process_material = m
	if cfg.get("additive", true):
		p.material = add_mat
	return p


func emit(type: String, screen_pos: Vector2, angle: float, color: Color, ratio := 1.0) -> void:
	if not _pools.has(type):
		return
	var pool: Dictionary = _pools[type]
	var items: Array = pool["items"]
	var p: GPUParticles2D = items[pool["i"]]
	pool["i"] = (pool["i"] + 1) % items.size()
	p.global_position = screen_pos
	p.rotation = angle
	p.modulate = color
	p.amount_ratio = clampf(ratio * particle_scale, 0.05, 1.0)
	p.restart()


# ------------------------------------------------------------------ frame update

func _process(dt: float) -> void:
	if not _ready_done:
		return
	for e in _lights:
		if e["t"] > 0.0:
			e["t"] -= dt
			var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
			e["l"].energy = e["e"] * k * k
			if e["t"] <= 0.0:
				e["l"].enabled = false
	for f in _flashes:
		if f["t"] > 0.0:
			f["t"] -= dt
			var fs: Sprite2D = f["s"]
			if f["t"] <= 0.0:
				fs.visible = false
			else:
				# burst out fast, fade late: reads as a hot flash, not a sprite growing
				var k: float = 1.0 - f["t"] / f["dur"]
				fs.scale = f["s0"].lerp(f["s1"], 1.0 - pow(1.0 - k, 3.0))
				fs.modulate.a = f["a"] * (1.0 - k * k)
	for b in _bolts:
		if b["t"] > 0.0:
			b["t"] -= dt
			var ln: Line2D = b["ln"]
			if b["t"] <= 0.0:
				ln.visible = false
			else:
				var k: float = b["t"] / b["dur"]
				ln.default_color = b["c"] * Color(1, 1, 1, k)
				ln.points = _jagged(b["a"], b["b"], b["jag"])


# ------------------------------------------------------------------ primitives

func light_flash(screen_pos: Vector2, color: Color, energy: float, range_m: float, dur: float, height := 70.0) -> void:
	if _lights.is_empty():
		return
	# merge with a fresh nearby flash instead of stacking (keeps bursts from whiting out)
	for e in _lights:
		if e["t"] > e["dur"] * 0.4 and e["l"].position.distance_to(screen_pos) < 140.0:
			e["e"] = minf(maxf(e["e"], energy) * 1.15, 3.0)
			e["t"] = maxf(e["t"], dur)
			e["dur"] = maxf(e["dur"], dur)
			return
	var e: Dictionary = _lights[_light_i]
	_light_i = (_light_i + 1) % _lights.size()
	var l: PointLight2D = e["l"]
	l.enabled = true
	l.position = screen_pos
	l.color = color
	l.height = height
	l.texture_scale = Iso.m(range_m) * 2.0 / 256.0
	e["t"] = dur
	e["dur"] = dur
	e["e"] = energy
	l.energy = energy


func shake(trauma: float) -> void:
	if camera:
		camera.add_trauma(trauma)


func kick(dir_screen: Vector2, amount: float) -> void:
	if camera:
		camera.kick(dir_screen, amount)


func screen_flash(color: Color, dur := 0.12) -> void:
	if post:
		post.flash(color, dur)


func make_shadow(radius_g: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = T.shadow
	s.scale = Vector2(radius_g * 2.0 / 128.0, radius_g * 2.0 * Iso.K / 128.0)
	s.modulate = Color(1, 1, 1, 0.75)
	s.z_index = -1
	return s


func burst_sprite(tex: Texture2D, screen_pos: Vector2, color: Color, s0: Vector2, s1: Vector2, dur: float, additive := true, rot := 0.0, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = screen_pos
	s.rotation = rot
	s.modulate = color
	s.scale = s0
	if additive:
		s.material = add_mat
	(parent if parent else fx).add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", s1, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)
	return s


func ring(g: Vector2, radius: float, color: Color, dur := 0.35, width_start := 0.25) -> void:
	var sp := Iso.to_screen(g)
	var k := 2.0 / 256.0 * 1.0
	var s1 := Vector2(radius * 2.0 / 256.0 * 1.08, radius * 2.0 * Iso.K / 256.0 * 1.08)
	burst_sprite(T.ring, sp, color * 1.25, s1 * width_start, s1, dur)


func decal(g: Vector2, tex: Texture2D, color: Color, size: float) -> void:
	if decals == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = Iso.to_screen(g)
	s.modulate = color
	s.flip_h = randf() < 0.5
	s.flip_v = randf() < 0.5
	var sc := size / 128.0
	s.scale = Vector2(sc, sc * Iso.K)
	decals.add_child(s)
	_decals.append(s)
	if _decals.size() > MAX_DECALS:
		var old: Sprite2D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


# ------------------------------------------------------------------ composite effects

## One pooled flash layer: a sprite that bursts from s0 to s1 and fades over dur.
## `off` is the texture offset (the directional flash's origin sits 44 px off centre).
func flash_layer(tex: Texture2D, screen_pos: Vector2, rot: float, color: Color, s0: Vector2, s1: Vector2,
		dur: float, off := Vector2.ZERO) -> void:
	if _flashes.is_empty():
		return
	var f: Dictionary = _flashes[_flash_i]
	_flash_i = (_flash_i + 1) % _flashes.size()
	var s: Sprite2D = f["s"]
	s.visible = true
	s.texture = tex
	s.offset = off
	s.position = screen_pos
	s.rotation = rot
	s.scale = s0
	s.modulate = color
	f["t"] = dur
	f["dur"] = dur
	f["s0"] = s0
	f["s1"] = s1
	f["a"] = color.a


## Weapon muzzle flash. style: {color, scale, light, range, wide, sparks}
## Big and layered on purpose (the owner wants gunfire to feel epic): a forward cone of
## fire, a white-hot cross flare, a bloom, a burst of light and a wisp of smoke. It lasts
## only ~4 frames, so it never hides the fight.
const MUZZLE_BOOST := 2.3

func muzzle(screen_pos: Vector2, gdir: Vector2, style: Dictionary) -> void:
	var sdir := Iso.to_screen(gdir).normalized()
	var ang := sdir.angle()
	var col: Color = style.get("color", Color(1, 0.8, 0.5))
	var gk: float = style.get("scale", 1.0) * MUZZLE_BOOST
	var wide: bool = style.get("wide", false)
	var dur: float = style.get("dur", 0.07)
	var j := randf_range(0.85, 1.15)
	# the cone of fire, punching forward
	flash_layer(T.flash_wide if wide else T.flash, screen_pos, ang + randf_range(-0.07, 0.07), col * Color(2.4, 2.2, 2.0, 1.0),
		Vector2(0.55, 0.5) * gk * j, Vector2(1.15, 0.85 if wide else 0.7) * gk * j, dur, Vector2(44, 0))
	# a second, hotter and thinner tongue inside it
	flash_layer(T.flash, screen_pos, ang + randf_range(-0.04, 0.04), Color(2.8, 2.5, 2.1, 0.9),
		Vector2(0.4, 0.22) * gk, Vector2(0.9, 0.3) * gk, dur * 0.7, Vector2(44, 0))
	# white-hot cross flare at the barrel
	flash_layer(T.star, screen_pos, ang + PI * 0.25 + randf_range(-0.3, 0.3), Color(3.0, 2.7, 2.3, 1.0),
		Vector2(0.25, 0.25) * gk, Vector2(0.75, 0.75) * gk, dur * 0.8)
	# spikes of light shooting out of the barrel, fanned forward (wider for the blunderbuss)
	spikes(screen_pos, ang, 0.75 if wide else 0.42, 6 if wide else 4, 85.0 * gk, Color(3.0, 2.6, 1.9, 0.95))
	# bloom
	flash_layer(T.glow, screen_pos + sdir * 14.0 * gk, 0.0, col * Color(1.9, 1.6, 1.3, 0.85),
		Vector2(0.3, 0.26) * gk, Vector2(1.0, 0.85) * gk, dur * 1.7)
	# rapid-fire guns keep their light lit almost constantly: boost only the big single shots
	var lk := 0.75 if style.get("rapid", false) else 1.35
	light_flash(screen_pos, col, style.get("light", 1.6) * lk, style.get("range", 4.0) * (1.0 if style.get("rapid", false) else 1.3), 0.1, 60.0)
	emit("puff", screen_pos + sdir * 22.0 * gk, ang, Color(0.62, 0.6, 0.58, 0.32), 0.3 + 0.25 * minf(gk, 2.0))
	emit("sparks", screen_pos, ang, col * 2.6, maxf(style.get("sparks", 0.0), 0.12))


## Per-weapon flourish on top of the flash (WeaponData.muzzle_fx).
func muzzle_fx(kind: String, screen_pos: Vector2, gdir: Vector2, col: Color, charge := 1.0) -> void:
	var ang := Iso.to_screen(gdir).angle()
	match kind:
		"sparks":
			emit("sparks", screen_pos, ang, col * Color(2.6, 2.0, 1.2), 0.1)
		"blast":
			emit("embers", screen_pos, ang, col * Color(3.0, 1.6, 0.6), 0.4)
			emit("sparks", screen_pos, ang, col * Color(3.0, 2.0, 1.0), 0.5)
			emit("puff", screen_pos + Iso.to_screen(gdir).normalized() * 30.0, ang, Color(0.5, 0.48, 0.46, 0.45), 1.0)
			if post:
				post.shockwave(screen_pos, 110.0, 0.22, 0.5)
		"arc":
			emit("electric", screen_pos, ang, Color(1.2, 1.7, 4.0), 0.18)
		"rail":
			emit("electric", screen_pos, ang, col * Color(3.0, 1.6, 2.0), 0.6 * charge)
			if post and charge > 0.5:
				post.shockwave(screen_pos, 150.0, 0.28, 0.8 * charge)


## Souls pulled out of a kill into the gunslinger: green motes arcing to the player.
func soul_streaks(from: Vector2, n: int) -> void:
	if fx == null or Game.player == null:
		return
	for i in n:
		var m := SoulMote.new()
		m.texture = T.core
		m.material = add_mat
		m.setup(from, i)
		fx.add_child(m)


## One soul mote: a bright green spark on a curve from a kill to the player, with a
## short streak behind it; a little flash where it arrives.
class SoulMote extends Sprite2D:
	var from := Vector2.ZERO
	var ctrl := Vector2.ZERO
	var dur := 0.5
	var t := 0.0
	var _prev := Vector2.ZERO

	func setup(from_: Vector2, i: int) -> void:
		from = from_
		position = from
		_prev = from
		ctrl = from + Vector2(randf_range(-150.0, 150.0), randf_range(-190.0, -70.0))
		dur = randf_range(0.38, 0.6) + i * 0.035
		t = -i * 0.03
		modulate = Color(0.7, 2.6, 1.2)
		scale = Vector2(0.26, 0.26)

	func _process(dt: float) -> void:
		t += dt
		var pl = Game.player
		if pl == null or not is_instance_valid(pl):
			queue_free()
			return
		var u := clampf(t / dur, 0.0, 1.0)
		var e := u * u
		var to: Vector2 = pl.position + Vector2(0.0, -Iso.h(1.0))
		_prev = position
		position = from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
		scale = Vector2.ONE * lerpf(0.3, 0.16, u)
		rotation = (position - _prev).angle()
		scale.x *= 1.0 + minf(3.0, (position - _prev).length() / 9.0)
		if u >= 1.0:
			VFX.flash_layer(VFX.T.glow, to, 0.0, Color(0.6, 2.4, 1.1, 0.7), Vector2(0.2, 0.2), Vector2(0.6, 0.6), 0.12)
			queue_free()


## Souls leaving a body: green motes rising, more for bigger deaths.
func souls(g: Vector2, h_m: float, amount := 0.4) -> void:
	emit("souls", Iso.lift(g, h_m), -PI / 2, Color(0.6, 2.4, 1.1), amount)


## A spent casing (or a shotgun shell) kicked out of the gun, to the gun's right.
func casing(screen_pos: Vector2, gdir: Vector2, shell := false) -> void:
	var side := Iso.to_screen(-Iso.left_of(gdir)).normalized()
	var ang := (side + Vector2(0, -1.2)).angle()
	emit("casings", screen_pos, ang, Color(0.85, 0.2, 0.15) if shell else Color(1.0, 0.78, 0.35))


## A burst of n thin spikes of light from screen point p, fanned around angle ang (+/- spread
## radians), each up to `length` px: the starburst of a muzzle flash or an impact.
func spikes(p: Vector2, ang: float, spread: float, n: int, length: float, col: Color, dur := 0.06) -> void:
	for i in n:
		var a := ang + randf_range(-spread, spread)
		var l := length * randf_range(0.55, 1.15)
		# T.spark is 12 px wide: stretched along x it becomes a streak bright in the middle,
		# offset so it starts at p
		flash_layer(T.spark, p, a, col, Vector2(l * 0.35 / 12.0, 0.13), Vector2(l / 12.0, 0.05), dur, Vector2(6, 0))


## Bullet/beam impact at ground point g and visual height h_m. Exaggerated: a hit should
## pop even in a crowd (a star flash, a burst of sparks or blood, a short flare of light).
func impact(g: Vector2, h_m: float, normal_g: Vector2, style := "metal", color := Color.WHITE) -> void:
	var sp := Iso.lift(g, h_m)
	var ang := Iso.to_screen(normal_g).angle() if normal_g != Vector2.ZERO else -PI / 2
	var rot := randf() * TAU
	match style:
		"flesh":
			spikes(sp, ang, 1.1, 3, 46.0, Color(3.0, 2.4, 1.7, 0.9), 0.05)
			emit("blood", sp, ang, color, 0.6)
			emit("sparks", sp, ang, Color(3.0, 2.2, 1.4), 0.18)
			flash_layer(T.glow, sp, 0.0, color * Color(2.2, 2.2, 2.2, 0.9), Vector2(0.3, 0.3), Vector2(1.1, 1.0), 0.1)
			flash_layer(T.star, sp, rot, Color(2.8, 2.4, 1.9, 1.0), Vector2(0.3, 0.3), Vector2(0.85, 0.85), 0.07)
		"armor":
			spikes(sp, ang, 1.4, 5, 60.0, Color(3.2, 2.8, 2.0, 1.0), 0.06)
			emit("sparks", sp, ang, Color(3.0, 2.5, 1.6), 0.9)
			flash_layer(T.star6, sp, rot, Color(3.2, 2.8, 2.2, 1.0), Vector2(0.35, 0.35), Vector2(1.1, 1.1), 0.08)
			flash_layer(T.glow, sp, 0.0, Color(2.4, 2.0, 1.4, 0.8), Vector2(0.3, 0.3), Vector2(1.0, 1.0), 0.1)
			light_flash(sp, Color(1.0, 0.85, 0.6), 1.0, 2.0, 0.08)
		"energy":
			emit("electric", sp, ang, Color(1.2, 1.8, 4.0), 0.8)
			flash_layer(T.glow, sp, 0.0, Color(1.2, 1.8, 4.0, 0.9), Vector2(0.25, 0.25), Vector2(1.1, 1.1), 0.12)
			flash_layer(T.star, sp, rot, Color(2.0, 2.6, 4.0, 1.0), Vector2(0.3, 0.3), Vector2(0.9, 0.9), 0.08)
		"shard":
			emit("sparks", sp, ang, Color(2.6, 0.6, 1.6), 0.5)
			flash_layer(T.glow, sp, 0.0, Color(2.2, 0.5, 1.3, 0.9), Vector2(0.25, 0.25), Vector2(1.0, 1.0), 0.13)
		"acid":
			emit("blood", sp, -PI / 2, Color(0.5, 1.0, 0.25), 0.5)
			flash_layer(T.glow, sp, 0.0, Color(1.0, 2.6, 0.6, 0.9), Vector2(0.25, 0.25), Vector2(1.0, 1.0), 0.15)
		_:
			spikes(sp, ang, 1.3, 4, 52.0, Color(3.0, 2.5, 1.7, 0.95), 0.05)
			emit("sparks", sp, ang, color * Color(3.0, 2.2, 1.2), 0.6)
			flash_layer(T.star, sp, rot, Color(3.0, 2.6, 1.9, 1.0), Vector2(0.25, 0.25), Vector2(0.8, 0.8), 0.07)
			flash_layer(T.glow, sp, 0.0, Color(2.4, 2.0, 1.4, 0.8), Vector2(0.2, 0.2), Vector2(0.8, 0.75), 0.09)
			emit("puff", sp, ang, Color(0.55, 0.53, 0.5, 0.35), 0.3)


func explosion(g: Vector2, radius: float, color := Color(1.0, 0.55, 0.2), big := true) -> void:
	var sp := Iso.to_screen(g)
	var rm := radius / Iso.PX_PER_M
	var up := Vector2(0, -Iso.h(0.6))
	light_flash(sp + up, color, 1.8 if big else 1.2, rm * 2.0, 0.3 if big else 0.22, 90.0)
	var fs := radius / 64.0
	var gk := 1.0 if big else 0.6
	burst_sprite(T.glow, sp + up, color * 0.9 * gk, Vector2(fs, fs * 0.85) * 0.2, Vector2(fs, fs * 0.8) * 0.5, 0.24)
	burst_sprite(T.core, sp + up, Color(1.8, 1.5, 1.2), Vector2(fs, fs) * 0.25, Vector2(fs, fs) * 0.55, 0.1)
	ring(g, radius * 1.05, color * 0.8, 0.32)
	emit("sparks", sp + up, -PI / 2, color * 3.0, 1.0)
	_pool_spread("sparks", 180.0)
	emit("embers", sp + up, -PI / 2, color * 3.5, 0.6 if big else 0.35)
	emit("smoke", sp + up * 1.4, -PI / 2, Color(0.16, 0.15, 0.15, 0.85), 1.0 if big else 0.6)
	if big:
		emit("debris", sp, -PI / 2, Color(0.35, 0.33, 0.32), 0.8)
	decal(g, T.scorch, Color(0, 0, 0, 0.62), radius * 1.5)
	if post:
		post.shockwave(sp, radius * (1.6 if big else 1.2), 0.38 if big else 0.28, 1.0 if big else 0.6)
	shake(0.42 if big else 0.22)
	if big and post:
		post.aberration_kick(0.5)


func _pool_spread(_name: String, _deg: float) -> void:
	pass  # sparks pool uses its configured spread; explosions read fine with it


func gore(g: Vector2, color: Color, size := 1.0, dir := Vector2.ZERO) -> void:
	var sp := Iso.lift(g, 0.4)
	var ang := Iso.to_screen(dir).angle() if dir != Vector2.ZERO else -PI / 2
	emit("blood", sp, ang, color, clampf(0.6 * size, 0.2, 1.0))
	emit("gibs", sp, ang, color * 0.8, clampf(0.5 * size, 0.2, 1.0))
	burst_sprite(T.glow, sp, color * 2.2, Vector2(0.4, 0.4) * size, Vector2(1.4, 1.3) * size, 0.2)
	var tex: Texture2D = T.splats[randi() % T.splats.size()]
	decal(g + dir * Iso.m(0.4), tex, Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 0.85), Iso.m(1.5) * size)


func debris(g: Vector2, size: float, _count: int) -> void:
	var sp := Iso.lift(g, 0.6)
	emit("debris", sp, -PI / 2, Color(0.45, 0.43, 0.42), clampf(size * 0.4, 0.2, 1.0))
	emit("smoke", sp, -PI / 2, Color(0.25, 0.24, 0.24, 0.6), clampf(size * 0.3, 0.2, 1.0))


## A lightning bolt: a wide soft halo under a thicker crackling core, and a flash of light
## where it strikes.
const LIGHTNING_BOOST := 1.6

func lightning(a: Vector2, b: Vector2, color: Color, width := 5.0, dur := 0.12, jag := 1.0) -> void:
	_bolt(a, b, color * Color(0.8, 0.9, 1.2, 0.3), width * LIGHTNING_BOOST * 3.6, dur * 1.2, jag * 0.45)
	_bolt(a, b, color, width * LIGHTNING_BOOST, dur, jag)
	light_flash(b, color * 0.4, 0.5, 1.8, 0.06)


func _bolt(a: Vector2, b: Vector2, color: Color, width: float, dur: float, jag: float) -> void:
	if _bolts.is_empty():
		return
	var e: Dictionary = _bolts[_bolt_i]
	_bolt_i = (_bolt_i + 1) % _bolts.size()
	var ln: Line2D = e["ln"]
	ln.visible = true
	ln.width = width
	e["t"] = dur
	e["dur"] = dur
	e["a"] = a
	e["b"] = b
	e["jag"] = jag
	e["c"] = color
	ln.default_color = color
	ln.points = _jagged(a, b, jag)


func _jagged(a: Vector2, b: Vector2, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := clampi(int(a.distance_to(b) / 26.0), 2, 24)
	var perp := (b - a).orthogonal().normalized()
	pts.append(a)
	for i in range(1, n):
		var t := float(i) / n
		var env := sin(t * PI)
		pts.append(a.lerp(b, t) + perp * randf_range(-18.0, 18.0) * jag * env)
	pts.append(b)
	return pts


func afterimage(src: Array, color: Color, dur := 0.22) -> void:
	for s in src:
		if s == null or not s.visible:
			continue
		var g := Sprite2D.new()
		g.texture = s.texture
		g.region_enabled = s.region_enabled
		g.region_rect = s.region_rect
		g.offset = s.offset
		g.global_position = s.global_position
		g.material = add_mat
		g.modulate = color
		fx.add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, dur)
		tw.tween_callback(g.queue_free)


func telegraph_circle(g: Vector2, radius: float, dur: float, color := Color(1.0, 0.15, 0.1)) -> Telegraph:
	var t := Telegraph.new()
	t.setup_circle(g, radius, dur, color)
	decals.add_child(t)
	return t


func telegraph_line(a: Vector2, b: Vector2, width: float, dur: float, color := Color(1.0, 0.15, 0.1)) -> Telegraph:
	var t := Telegraph.new()
	t.setup_line(a, b, width, dur, color)
	decals.add_child(t)
	return t


func burning_ground(g: Vector2, radius: float, dur: float, source: Object) -> void:
	if Game.world == null:
		return
	var h := GroundHazard.new()
	h.setup(g, radius, dur, source)
	Game.world.add_hazard(h)


# ------------------------------------------------------------------ text

func damage_number(g: Vector2, h_m: float, amount: float, crit: bool, color: Color) -> void:
	if _numbers.is_empty():
		return
	var lb: Label = _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	if lb.has_meta("tw"):
		var tw_old: Tween = lb.get_meta("tw")
		if tw_old and tw_old.is_valid():
			tw_old.kill()
	lb.visible = true
	lb.text = str(int(round(amount))) + ("!" if crit else "")
	lb.label_settings = _crit_settings if crit else _num_settings
	lb.modulate = Color(1.0, 0.78, 0.2) if crit else color
	var sp := Iso.lift(g, h_m) + Vector2(randf_range(-26, 26), randf_range(-10, 4))
	lb.position = sp - lb.pivot_offset
	lb.scale = Vector2(1.6, 1.6) if crit else Vector2(1.25, 1.25)
	var tw := lb.create_tween()
	lb.set_meta("tw", tw)
	tw.set_parallel(true)
	tw.tween_property(lb, "scale", Vector2(1, 1), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "position:y", lb.position.y - (70.0 if crit else 46.0), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "position:x", lb.position.x + randf_range(-20, 20), 0.7)
	tw.tween_property(lb, "modulate:a", 0.0, 0.25).set_delay(0.5)
	tw.chain().tween_callback(func(): lb.visible = false)


func popup(g: Vector2, h_m: float, text: String, color: Color, size := 30) -> void:
	if overlay == null:
		return
	var lb := Label.new()
	var ls := _popup_settings.duplicate()
	ls.font_size = size
	lb.label_settings = ls
	lb.text = text
	lb.modulate = color
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := Vector2(maxf(400.0, size * 16.0), size * 1.6)
	lb.size = box
	lb.pivot_offset = box * 0.5
	lb.position = Iso.lift(g, h_m) - box * 0.5
	overlay.add_child(lb)
	var tw := lb.create_tween()
	tw.set_parallel(true)
	if size >= 44:
		# big call-outs (CARNAGE...) slam in
		lb.scale = Vector2(1.6, 1.6)
		tw.tween_property(lb, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "position:y", lb.position.y - 60.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.4).set_delay(0.8)
	tw.chain().tween_callback(lb.queue_free)
