class_name World
extends Node2D
## Scene root. Owns render layers, environment, the current level, the player,
## and run flow (death/respawn, descending to deeper levels).

const ENEMY_IDS := ["mite", "spitter", "brute", "bloater"]
const AMBIENT := Color(0.64, 0.67, 0.76)

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
var _enemy_data := {}
var _t := 0.0


func _ready() -> void:
	Game.world = self
	_setup_environment()
	_setup_background()
	var cm := CanvasModulate.new()
	cm.color = AMBIENT
	add_child(cm)
	camera = GameCamera.new()
	add_child(camera)
	player = Player.new()
	player.name = "Player"
	var plight := PointLight2D.new()
	plight.texture = Dungeon.make_light_texture()
	plight.color = Color(1.0, 0.92, 0.85)
	plight.energy = 0.75
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
	_parse_args()
	Events.message.emit("DEPTH %d" % Game.depth, Color(0.85, 0.9, 1.0))


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.95
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
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = preload("res://src/vfx/shaders/void_bg.gdshader")
	rect.material = _bg_mat
	layer.add_child(rect)


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
	Game.dungeon = dungeon
	Game.enemies.clear()
	dungeon.build(LayoutTest.MAP, entities, decals)
	for c in dungeon.door_cells:
		var df := DoorField.new()
		df.setup(c, dungeon)
		entities.add_child(df)
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
	director = EncounterDirector.new()
	director.name = "Director"
	level_root.add_child(director)
	director.setup(LayoutTest.ROOMS, dungeon, self)
	if camera:
		camera.snap()


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	level_root.add_child(l)
	return l


func _process(dt: float) -> void:
	_t += dt
	if _bg_mat and camera:
		_bg_mat.set_shader_parameter("cam", camera.global_position)
		_bg_mat.set_shader_parameter("zoom", camera.zoom.x)
		_bg_mat.set_shader_parameter("time_s", _t)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		Game.debug = not Game.debug


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
	Events.message.emit("DEPTH %d — THE HIVE GROWS STRONGER" % Game.depth, Color(1.0, 0.6, 0.3))


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var opts := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if opts.has("depth"):
		Game.depth = int(opts["depth"])
	if opts.has("bot") or opts.has("shots") or opts.has("quit-after"):
		bot = BotDriver.new()
		bot.configure(opts)
		add_child(bot)
