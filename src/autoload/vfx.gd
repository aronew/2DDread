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
	for i in 10:
		var s := Sprite2D.new()
		s.texture = T.flash
		s.material = add_mat
		s.visible = false
		s.offset = Vector2(44, 0)
		fx.add_child(s)
		_flashes.append({"s": s, "t": 0.0})
	for i in 18:
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
			if f["t"] <= 0.0:
				f["s"].visible = false
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

## Weapon muzzle flash. style: {color, scale, light, range}
func muzzle(screen_pos: Vector2, gdir: Vector2, style: Dictionary) -> void:
	var sdir := Iso.to_screen(gdir).normalized()
	var ang := sdir.angle()
	var f: Dictionary = _flashes[_flash_i]
	_flash_i = (_flash_i + 1) % _flashes.size()
	var s: Sprite2D = f["s"]
	s.visible = true
	s.texture = T.flash_wide if style.get("wide", false) else T.flash
	s.position = screen_pos
	s.rotation = ang + randf_range(-0.08, 0.08)
	var sc: float = style.get("scale", 1.0) * randf_range(0.85, 1.15)
	s.scale = Vector2(sc, sc * randf_range(0.8, 1.1))
	s.modulate = style.get("color", Color(1, 0.8, 0.5)) * 2.0
	f["t"] = style.get("dur", 0.045)
	light_flash(screen_pos, style.get("color", Color(1, 0.8, 0.5)), style.get("light", 1.6), style.get("range", 4.0), 0.07, 60.0)
	if style.get("sparks", 0.0) > 0.0:
		emit("sparks", screen_pos, ang, style.get("color", Color.WHITE) * 2.5, style["sparks"])


## Bullet/beam impact at ground point g and visual height h_m.
func impact(g: Vector2, h_m: float, normal_g: Vector2, style := "metal", color := Color.WHITE) -> void:
	var sp := Iso.lift(g, h_m)
	var ang := Iso.to_screen(normal_g).angle() if normal_g != Vector2.ZERO else -PI / 2
	match style:
		"flesh":
			emit("blood", sp, ang, color, 0.45)
			burst_sprite(T.core, sp, color * 2.0, Vector2(0.25, 0.25), Vector2(0.8, 0.8), 0.09)
		"armor":
			emit("sparks", sp, ang, Color(3.0, 2.5, 1.6), 0.7)
			burst_sprite(T.core, sp, Color(3, 2.6, 2.0), Vector2(0.3, 0.3), Vector2(1.0, 1.0), 0.08)
		"energy":
			emit("electric", sp, ang, Color(1.2, 1.8, 4.0), 0.6)
			burst_sprite(T.glow, sp, Color(1.2, 1.8, 4.0), Vector2(0.15, 0.15), Vector2(0.6, 0.6), 0.1)
		"shard":
			emit("sparks", sp, ang, Color(2.6, 0.6, 1.6), 0.4)
			burst_sprite(T.glow, sp, Color(2.2, 0.5, 1.3), Vector2(0.2, 0.2), Vector2(0.8, 0.8), 0.12)
		"acid":
			emit("blood", sp, -PI / 2, Color(0.5, 1.0, 0.25), 0.5)
			burst_sprite(T.glow, sp, Color(1.0, 2.6, 0.6), Vector2(0.2, 0.2), Vector2(0.9, 0.9), 0.15)
		_:
			emit("sparks", sp, ang, color * Color(3.0, 2.2, 1.2), 0.45)
			burst_sprite(T.core, sp, Color(3, 2.5, 1.8), Vector2(0.2, 0.2), Vector2(0.7, 0.7), 0.07)


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


func lightning(a: Vector2, b: Vector2, color: Color, width := 5.0, dur := 0.12, jag := 1.0) -> void:
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
	lb.size = Vector2(400, 50)
	lb.position = Iso.lift(g, h_m) - Vector2(200, 25)
	overlay.add_child(lb)
	var tw := lb.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", lb.position.y - 60.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.4).set_delay(0.8)
	tw.chain().tween_callback(lb.queue_free)
