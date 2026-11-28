class_name World
extends Node2D
## Scene root. Owns render layers, environment, the current level, the player,
## and run flow (death/respawn, descending to deeper levels).

const ENEMY_IDS := ["mite", "spitter", "brute", "bloater"]
const AMBIENT := Color(0.93, 0.93, 0.9)

var level_root: Node2D
var entities: Node2D
var decals: Node2D
var hazards: Node2D
var dungeon: Dungeon
var director: EncounterDirector
var player: Player
var camera: GameCamera
var projectiles: ProjectileSystem
var hud: HUD
var post: PostFX
var portal: ExitPortal
var bot: BotDriver
var _bg_mat: ShaderMaterial
var _bg_rect: ColorRect
var _env: Environment
var _cm: CanvasModulate
var _enemy_data := {}
var _auto_t := 0.0
var _auto_frames := 0
var _auto_steps := 0
var _bench_until := 0.0
var _bench_start_frames := 0
var _bench_start_ms := 0
var _t := 0.0


func _ready() -> void:
	Game.world = self
	_setup_environment()
	_setup_background()
	_cm = CanvasModulate.new()
	_cm.color = AMBIENT
	add_child(_cm)
	camera = GameCamera.new()
	add_child(camera)
	camera.add_child(AmbientMotes.new())
	player = Player.new()
	player.name = "Player"
	var plight := PointLight2D.new()
	plight.texture = Dungeon.make_light_texture()
	plight.color = Color(1.0, 0.88, 0.72)
	plight.energy = 0.6
	plight.height = 140.0
	plight.texture_scale = Iso.m(9.0) * 2.0 / 256.0
	plight.scale = Vector2(1.0, Iso.K)
	plight.position = Vector2(0, -40)
	player.add_child(plight)
	build_level()
	camera.target_node = player
	camera.snap()
	post = PostFX.new()
	add_child(post)
	hud = HUD.new()
	add_child(hud)
	Events.player_died.connect(_on_player_died)
	Audio.start_music()
	Game.graphics_changed.connect(apply_graphics)
	get_window().size_changed.connect(_apply_render_cap)
	_parse_args()
	apply_graphics()
	Events.message.emit("DEPTH %d" % Game.depth, Color(0.85, 0.9, 1.0))


func _setup_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i >= 1 and i <= 5)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the world beyond the walls is black (the owner's call; the soul-fire lives in the pits)
	rect.color = Color(0.0, 0.0, 0.0)
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = preload("res://src/vfx/shaders/void_bg.gdshader")
	_bg_mat.set_shader_parameter("noise_tex", preload("res://src/vfx/fog_noise.tres"))
	layer.add_child(rect)
	_bg_rect = rect


func build_level() -> void:
	level_root = Node2D.new()
	level_root.name = "Level"
	add_child(level_root)
	dungeon = Dungeon.new()
	dungeon.name = "Dungeon"
	level_root.add_child(dungeon)
	decals = _layer("Decals", -12)
	hazards = _layer("Hazards", -11)
	entities = _layer("Entities", 0)
	entities.y_sort_enabled = true
	var lit := _layer("LitFX", 5)
	projectiles = ProjectileSystem.new()
	projectiles.name = "Projectiles"
	level_root.add_child(projectiles)
	var fx := _layer("FX", 31)
	var overlay := _layer("Overlay", 60)
	VFX.setup(fx, lit, decals, overlay)
	_warm_up()
	Game.dungeon = dungeon
	Game.enemies.clear()
	var layout := _layout()
	dungeon.enclose = layout.get("enclose", false)
	dungeon.build(layout["map"], entities, decals)
	var pits := PitFire.find_pits(dungeon)
	if not pits.is_empty():
		var pf := PitFire.new()
		pf.name = "PitFire"
		hazards.add_child(pf)
		pf.setup(pits, dungeon)
	# terrace drops and stairs between floor levels (layout `_` / `/` cells)
	if not layout.get("terraces", []).is_empty():
		var tr := Terrace.new()
		tr.name = "Terrace"
		dungeon.add_child(tr)
		tr.setup(layout["terraces"], dungeon)
	# room paintings (generated art laid over the layout); --no-paint shows the bare kit,
	# and paint guides are always taken without them
	var args := OS.get_cmdline_user_args()
	if layout.has("paints") and not args.has("--no-paint") and not args.has("--paint-guide"):
		RoomPaint.apply(layout["paints"], dungeon)
		if RoomPaint.backfill_misses > 0:
			print("[paint] near walls with a flat backfill (nothing clean to borrow): %d of %d" % [RoomPaint.backfill_misses, RoomPaint.backfill_tries])
	for c in dungeon.door_cells:
		var df := DoorField.new()
		df.setup(c, dungeon)
		entities.add_child(df)
	# soul-fire geysers erupting over bridges (room 6); dormant in paint guides, which
	# must show the room itself, not a moment of its hazards
	for gd in ([] if OS.get_cmdline_user_args().has("--paint-guide") else layout.get("geysers", [])):
		var gy := SoulGeyser.new()
		gy.setup(gd)
		hazards.add_child(gy)
	if not dungeon.shock_cells.is_empty():
		var sf := ShockFloor.new()
		sf.setup(dungeon.shock_cells)
		hazards.add_child(sf)
	if dungeon.exit_cell.x >= 0:
		portal = ExitPortal.new()
		portal.setup(Iso.cell_center(dungeon.exit_cell))
		hazards.add_child(portal)
	if player.get_parent():
		player.get_parent().remove_child(player)
	entities.add_child(player)
	player.spawn_at(Iso.cell_center(dungeon.start_cell))
	var kf := KillFeel.new()
	kf.name = "KillFeel"
	level_root.add_child(kf)
	director = EncounterDirector.new()
	director.name = "Director"
	level_root.add_child(director)
	director.setup(layout["rooms"], dungeon, self)
	if camera:
		camera.snap()


## Which hand-authored level to build: the temple dungeon (LayoutTemple, the owner's painted
## rooms) by default; --level=test opens the original test level (LayoutTest).
func _layout() -> Dictionary:
	if OS.get_cmdline_user_args().has("--level=test"):
		return {"map": LayoutTest.MAP, "rooms": LayoutTest.ROOMS}
	var paints: Array = LayoutTemple.PAINTS_V3 if OS.get_cmdline_user_args().has("--paint-set=v3") else LayoutTemple.PAINTS
	return {"map": LayoutTemple.MAP, "rooms": LayoutTemple.ROOMS, "paints": paints,
		"terraces": LayoutTemple.TERRACES, "enclose": LayoutTemple.ENCLOSE, "geysers": LayoutTemple.GEYSERS}


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	level_root.add_child(l)
	return l


func _process(dt: float) -> void:
	_t += dt
	if _bench_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _bench_until:
		var secs := (Time.get_ticks_msec() - _bench_start_ms) / 1000.0
		var frames := Engine.get_frames_drawn() - _bench_start_frames
		print("[bench] preset=%s avg_fps=%.2f frames=%d secs=%.1f lights=%d draw_calls=%d vram_tex_mb=%.0f" % [
			Game.preset, frames / secs, frames, secs, dungeon.light_count(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0])
		get_tree().quit()
	_auto_quality(dt)
	if _bg_mat and camera and _bg_rect.material != null:
		_bg_mat.set_shader_parameter("cam", camera.global_position)
		_bg_mat.set_shader_parameter("zoom", camera.zoom.x)
		_bg_mat.set_shader_parameter("time_s", _t)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		Game.debug = not Game.debug
	elif event.is_action_pressed("graphics_cycle"):
		var p := Game.cycle_preset()
		Events.message.emit("GRAPHICS: " + p.to_upper(), Color(0.7, 0.9, 1.0))


# ------------------------------------------------------------------ graphics

## If the frame rate stays low early on, step the preset down (at most twice)
## so a first launch on modest hardware becomes playable by itself.
func _auto_quality(dt: float) -> void:
	if Game.user_chose_preset or bot != null or _auto_steps >= 2 or Game.preset == "low" or get_tree().paused:
		return
	_auto_t += dt / maxf(Engine.time_scale, 0.01)
	_auto_frames += 1
	if _auto_t < 5.0:
		return
	var fps := _auto_frames / _auto_t
	_auto_t = 0.0
	_auto_frames = 0
	if fps < 45.0:
		_auto_steps += 1
		var i: int = maxi(0, Game.PRESET_ORDER.find(Game.preset) - 1)
		Game.set_preset(Game.PRESET_ORDER[i], false)
		Events.message.emit("LOW FPS (%d): GRAPHICS -> %s   [F4 to change]" % [fps, Game.preset.to_upper()], Color(1.0, 0.8, 0.4))


## Load every enemy sheet and fire each particle pool once off-screen, so the
## first spawn / explosion of a fight doesn't stall on texture upload or
## pipeline compilation.
func _warm_up() -> void:
	for id in ENEMY_IDS:
		var d: EnemyData = load("res://data/enemies/%s.tres" % id)
		_enemy_data[id] = d
		for sname in [d.sheet_move, d.sheet_attack]:
			var sh = SheetDB.get_sheet(Enemy.SHEET_DIR + sname)
			if sh:
				GlowMat.get_mat(sh, Color(1.0, 0.22, 0.18, 0.6))
	for k in ["sparks", "embers", "electric", "smoke", "blood", "gibs", "debris"]:
		VFX.emit(k, Vector2(-100000, -100000), 0.0, Color(1, 1, 1, 0), 0.05)

## Applies Game.gfx (preset) to every renderer-facing system.
func apply_graphics() -> void:
	var g: Dictionary = Game.gfx
	var hdr: bool = g["hdr"]
	get_viewport().use_hdr_2d = hdr
	_env.glow_enabled = g["glow"]
	_env.glow_hdr_threshold = 1.1 if hdr else 0.8
	# glow level 1 is the half-resolution blur and costs the most fill-rate;
	# medium skips it and leans on the cheaper wide levels
	var full: bool = g.get("glow_full", true)
	for i in 7:
		_env.set_glow_level(i, (i >= 1 if full else i >= 2) and i <= 5)
	_env.glow_intensity = 0.7 if full else 0.85
	_env.glow_bloom = 0.02 if full else 0.0
	var bg: int = g["bg"]
	_bg_rect.material = null   # black beyond the walls (void_bg is kept for a later biome)
	_bg_mat.set_shader_parameter("quality", bg)
	if post:
		post.set_full(g["post"])
	var lv: int = g["lights"]
	if dungeon:
		dungeon.apply_light_level(lv)
	# fewer static lights -> lift ambient so rooms stay readable
	_cm.color = [Color(1.0, 1.0, 0.98), Color(0.96, 0.96, 0.93), AMBIENT][lv]
	VFX.particle_scale = g["particles"]
	_apply_render_cap()


## On screens larger than 1080p, render the game at 1080p and upscale (big
## fill-rate saving on 1440p/4K) unless the High preset asks for native.
func _apply_render_cap() -> void:
	var win := get_window()
	var big := win.size.x > 1920 or win.size.y > 1080
	var cap: bool = Game.gfx["cap1080"] and big
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if cap else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


# ------------------------------------------------------------------ spawning

func spawn_enemy(id: String, g: Vector2, opts := {}) -> Enemy:
	var e: Enemy
	match id:
		"mite": e = Mite.new()
		"spitter": e = Spitter.new()
		"brute": e = Brute.new()
		"bloater": e = Bloater.new()
		_:
			push_warning("unknown enemy " + id)
			return null
	if not _enemy_data.has(id):
		_enemy_data[id] = load("res://data/enemies/%s.tres" % id)
	e.setup(_enemy_data[id], g, opts)
	entities.add_child(e)
	return e


func add_hazard(h: Node2D) -> void:
	hazards.add_child(h)


func open_exit() -> void:
	if portal:
		portal.activate()


# ------------------------------------------------------------------ run flow

func _on_player_died() -> void:
	Events.message.emit("YOU DIED", Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(2.6, true, false, true).timeout
	for q in projectiles.list:
		if q.team == 1:
			q.dead = true
	var g := director.reset_active()
	player.revive(g)
	camera.snap()
	Events.message.emit("RESPAWNED AT CHECKPOINT", Color(0.7, 0.85, 1.0))


func descend() -> void:
	Game.depth += 1
	VFX.screen_flash(Color(0.6, 0.85, 1.0, 0.9), 0.6)
	Audio.play("level_up")
	call_deferred("_rebuild")


func _rebuild() -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	projectiles.clear_all()
	Game.enemies.clear()
	Game.grid.rebuild([])
	level_root.free()
	build_level()
	Events.depth_changed.emit(Game.depth)
	Events.message.emit("DEPTH %d — THE UNDERWORLD STIRS" % Game.depth, Color(1.0, 0.6, 0.3))


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opts.has("depth"):
		Game.depth = int(opts["depth"])
	if opts.has("start"):
		# dev: jump straight to a room's entrance side (e.g. --start=hatchery)
		set_meta("start_room", opts["start"])
		for r in director.rooms:
			if r.id == opts["start"]:
				var c := Vector2i(r.rect.position.x + 1, r.rect.get_center().y)
				if not dungeon.is_floor(c):
					c = Vector2i(r.rect.get_center())
				player.spawn_at(Iso.cell_center(c))
				camera.snap()
	if opts.has("zoom"):
		# dev: camera zoom multiplier, e.g. --zoom=1.4 for the closer mockup framing
		camera.zoom_mult = float(opts["zoom"])
	if opts.has("look"):
		# dev: still look-test, e.g. --look=12.5,9 puts the player on that tile point with
		# no encounters and no mouse look-ahead, for comparing a room against concept art
		var xy: PackedStringArray = String(opts["look"]).split(",")
		if xy.size() == 2:
			player.spawn_at(Iso.tile_to_ground(Vector2(float(xy[0]), float(xy[1]))))
		director.set_process(false)
		camera.lookahead = 0.0
		camera.snap()
	if opts.has("break-props"):
		# dev: after N seconds break every destructible prop and open every chest (to check
		# that painted props go with them)
		get_tree().create_timer(float(opts["break-props"])).timeout.connect(func():
			for pr in dungeon.props.duplicate():
				if not is_instance_valid(pr) or not pr.alive:
					continue
				if pr.kind == "chest":
					pr.open_chest()
				elif pr.destructible():
					var d := DamageInfo.make(9999.0, DamageInfo.Type.PHYSICAL, player)
					pr.take_damage(d))
	if opts.has("paint-guide"):
		# dev: a clean frame of the room for an image generator to paint over (no HUD,
		# no player), plus where the camera was, so the painting can be laid back on
		# the room exactly. Use with --look and --shots.
		hud.visible = false
		player.visible = false
		if portal:
			portal.visible = false   # the dormant portal ring is an effect, not architecture
		set_meta("paint_guide", true)   # BotDriver writes the camera next to each shot
	if opts.has("gfx"):
		Game.set_preset(opts["gfx"], false)
	for k in Game.gfx.keys():
		# per-setting overrides for profiling, e.g. --g-lights=0 --g-glow=false
		if opts.has("g-" + k):
			var v: String = opts["g-" + k]
			Game.gfx[k] = (v == "true") if v in ["true", "false"] else (float(v) if "." in v else int(v))
	if opts.has("bench"):
		_bench_until = Time.get_ticks_msec() / 1000.0 + float(opts["bench"])
		_bench_start_ms = Time.get_ticks_msec()
		_bench_start_frames = Engine.get_frames_drawn()
	if opts.has("dmg-mult"):
		Game.damage_taken_mult = float(opts["dmg-mult"])
	if opts.has("bot") or opts.has("shots") or opts.has("quit-after") or opts.has("inv-shot"):
		bot = BotDriver.new()
		bot.configure(opts)
		add_child(bot)
