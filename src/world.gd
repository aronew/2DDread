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
var hub: Hub                 # the hub's stations and figures, when the level is the hub
var level_kind := "temple"   # a shore ("temple", "phlegethon"), "hub" (The Last Obol) or "test"
var _lava_mat: ShaderMaterial
var _lava := false

## The shores the ferry sails to: title, the extra depths of difficulty, and what unlocks
## them (the shore before it, once its exit portal has been reached).
const SHORES := {
	"temple": {"name": "The Soul-Fire Temple", "tier": 0, "after": ""},
	"phlegethon": {"name": "The Phlegethon", "tier": 2, "after": "temple"},
}
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
	Meta.load_save()
	var args := OS.get_cmdline_user_args()
	if args.has("--level=test"):
		level_kind = "test"
	elif args.has("--level=hub"):
		level_kind = "hub"
	elif args.has("--level=phlegethon"):
		level_kind = "phlegethon"
	Game.shore_tier = int(SHORES[level_kind]["tier"]) if SHORES.has(level_kind) else 0
	Game.in_hub = level_kind == "hub"
	_setup_environment()
	_setup_background()
	_cm = CanvasModulate.new()
	_cm.color = AMBIENT
	add_child(_cm)
	camera = GameCamera.new()
	add_child(camera)
	camera.add_child(AmbientMotes.new())
	camera.add_child(GroundFog.new())
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
	# souls: every kill sends some into the gunslinger, every cleared room banks a few more
	Events.enemy_killed.connect(func(e, _info):
		if e and not Game.in_hub:
			Meta.add_souls(Meta.kill_value(e)))
	Events.room_cleared.connect(func(_r):
		Meta.add_souls(3 + 2 * Game.depth)
		Meta.save())
	Audio.start_music()
	Game.graphics_changed.connect(apply_graphics)
	get_window().size_changed.connect(_apply_render_cap)
	_parse_args()
	apply_graphics()
	if Game.in_hub:
		Events.message.emit("THE LAST OBOL", Color(0.55, 1.0, 0.8))
	elif SHORES.has(level_kind) and level_kind != "temple":
		Events.message.emit("%s · DEPTH %d" % [String(SHORES[level_kind]["name"]).to_upper(), Game.depth], Color(1.0, 0.6, 0.3))
	else:
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
	_lava_mat = ShaderMaterial.new()
	_lava_mat.shader = preload("res://src/vfx/shaders/lava_sea.gdshader")
	_lava_mat.set_shader_parameter("noise_tex", preload("res://src/vfx/fog_noise.tres"))


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
	_lava = layout.get("lava", false)
	dungeon.fly_margin = 3 if _lava else 0
	dungeon.build(layout["map"], entities, decals)
	if _bg_rect:
		_bg_rect.material = _lava_mat if _lava and not OS.get_cmdline_user_args().has("--paint-guide") else null
	if _lava:
		# the lava shore: every void is the lava sea (no soul-fire pits), island cliffs glow,
		# and the temple kit is tinted to ashen rock until the shore is painted
		var ls := LavaShore.new()
		ls.name = "LavaShore"
		level_root.add_child(ls)
		ls.setup(dungeon)
		dungeon.tint_kit(Color(0.86, 0.7, 0.74), Color(0.8, 0.64, 0.68))
	var pits := [] if _lava else PitFire.find_pits(dungeon)
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
		entities.add_child(portal)   # an upright gateway: y-sorted with walls and actors
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
	hub = null
	if level_kind == "hub":
		hub = Hub.new()
		hub.name = "Hub"
		level_root.add_child(hub)
		hub.setup(entities)
		if OS.get_cmdline_user_args().has("--paint-guide"):
			hub.hide_figures()   # guides show the room only: Charon, the souls and the drawn props stay out
	if camera:
		camera.snap()


## Which hand-authored level to build: the temple dungeon (LayoutTemple, the owner's painted
## rooms) by default; --level=test opens the original test level (LayoutTest).
func _layout() -> Dictionary:
	if level_kind == "hub":
		return {"map": LayoutHub.MAP, "rooms": [], "enclose": LayoutHub.ENCLOSE, "paints": LayoutHub.PAINTS}
	if level_kind == "phlegethon":
		return {"map": LayoutPhlegethon.MAP, "rooms": LayoutPhlegethon.ROOMS, "paints": LayoutPhlegethon.PAINTS, "lava": true}
	if level_kind == "test":
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
	if camera and _bg_rect.material != null:
		var m: ShaderMaterial = _bg_rect.material
		m.set_shader_parameter("cam", camera.global_position)
		m.set_shader_parameter("zoom", camera.zoom.x)
		m.set_shader_parameter("time_s", _t)


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
	# black beyond the temple's walls; the lava sea under the Phlegethon's islands
	_bg_rect.material = _lava_mat if _lava and not OS.get_cmdline_user_args().has("--paint-guide") else null
	_bg_mat.set_shader_parameter("quality", bg)
	_lava_mat.set_shader_parameter("quality", bg)
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
		"mite", "spiderling": e = Mite.new()
		"spitter": e = Spitter.new()
		"brute": e = Brute.new()
		"bloater": e = Bloater.new()
		"titan": e = Titan.new()
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


## The exit portal at the bottom of a dive: the temple throws you out at the hub (The Last
## Obol); the old test level still just goes one depth deeper.
func descend() -> void:
	VFX.screen_flash(Color(0.6, 0.85, 1.0, 0.9), 0.6)
	Audio.play("level_up")
	if SHORES.has(level_kind):
		Meta.best_depth = maxi(Meta.best_depth, Game.depth)
		for s in SHORES:
			if SHORES[s]["after"] == level_kind and not Meta.shores.has(s):
				Meta.shores[s] = true   # the ferry can go one shore further now
				Events.message.emit("A NEW SHORE: %s" % String(SHORES[s]["name"]).to_upper(), Color(1.0, 0.6, 0.25))
		Meta.crossings += 1
		Meta.drink = ""          # the drink wears off: pour another before the next crossing
		Meta.save()
		_go("hub", Game.depth)
		return
	Game.depth += 1
	call_deferred("_rebuild")


## Leave the hub on the ferry for a shore at a depth.
func sail(depth: int, shore := "temple") -> void:
	VFX.screen_flash(Color(0.45, 1.0, 0.75, 0.9), 0.6)
	Audio.play("level_up")
	Meta.save()
	_go(shore, depth)


func _go(kind: String, depth: int) -> void:
	level_kind = kind
	Game.in_hub = kind == "hub"
	Game.shore_tier = int(SHORES[kind]["tier"]) if SHORES.has(kind) else 0
	Game.depth = depth
	call_deferred("_rebuild")


func _rebuild() -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	projectiles.clear_all()
	Game.enemies.clear()
	Game.grid.rebuild([])
	level_root.free()
	build_level()
	player.build.recalc()
	player.on_stats_changed()
	player.hp = player.max_hp
	player.reset_cooldowns()
	camera.snap()
	Events.depth_changed.emit(Game.depth)
	if Game.in_hub:
		Events.message.emit("THE LAST OBOL", Color(0.55, 1.0, 0.8))
	else:
		Events.message.emit("%s · DEPTH %d" % [String(SHORES.get(level_kind, {"name": "the underworld"})["name"]).to_upper(), Game.depth], Color(1.0, 0.6, 0.3))


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
	if opts.has("hit-at"):
		# dev: a 10-damage hit from where the player aims after N seconds, then every 1.5 s
		# (to look at the hit reaction)
		var hit_fn := func():
			if player.alive:
				var d := DamageInfo.make(10.0, DamageInfo.Type.PHYSICAL, null)
				d.direction = -player.aim_dir
				d.knockback = Iso.m(2.0)
				player.take_damage(d)
		get_tree().create_timer(float(opts["hit-at"])).timeout.connect(func():
			hit_fn.call()
			var tm := Timer.new()
			tm.wait_time = 1.5
			tm.timeout.connect(hit_fn)
			add_child(tm)
			tm.start())
	if opts.has("die-at"):
		# dev: the player drops dead after N seconds, knocked back from where he aims (to
		# look at the death animation; with --look it plays in an empty room)
		get_tree().create_timer(float(opts["die-at"])).timeout.connect(func():
			player.dev_kill(-player.aim_dir))
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
	if opts.has("hub-menu") and hub:
		# dev: open a hub station's screen after a second (forge, bar or ferry), for screenshots
		get_tree().create_timer(1.0).timeout.connect(func(): hud.open_hub_menu(opts["hub-menu"]))
	if opts.has("all-shores"):
		for sh in SHORES:
			Meta.shores[sh] = true   # dev: the ferry lists every shore
	if opts.has("souls"):
		Meta.souls = int(opts["souls"])   # dev: start with this many souls (not saved by itself)
	if opts.has("open-exit") and portal:
		portal.activate()   # dev: open the descent portal now (to look at it)
	if opts.has("dmg-mult"):
		Game.damage_taken_mult = float(opts["dmg-mult"])
	if opts.has("bot") or opts.has("shots") or opts.has("quit-after") or opts.has("inv-shot"):
		bot = BotDriver.new()
		bot.configure(opts)
		add_child(bot)
