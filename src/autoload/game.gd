extends Node
## Run-level coordinator: references to live systems, hit-stop, difficulty
## depth, and graphics settings (persisted to user://settings.cfg).

signal graphics_changed

const SETTINGS_PATH := "user://settings.cfg"
const PRESETS := {
	# bg: 0 flat, 1 textured fog, 2 + light shafts/motes
	# lights: 0 key lights only, 1 + accents, 2 + overhead fill pools
	"low": {"bg": 0, "glow": false, "glow_full": false, "post": false, "lights": 0, "hdr": false, "cap1080": true, "particles": 0.5},
	"medium": {"bg": 1, "glow": true, "glow_full": false, "post": true, "lights": 1, "hdr": true, "cap1080": true, "particles": 0.8},
	"high": {"bg": 2, "glow": true, "glow_full": true, "post": true, "lights": 2, "hdr": true, "cap1080": false, "particles": 1.0},
}
const PRESET_ORDER := ["low", "medium", "high"]

var player: Player = null
var dungeon: Dungeon = null
var projectiles: ProjectileSystem = null
var world: World = null
var camera: GameCamera = null
var hud: HUD = null
var enemies: Array = []
var grid := CombatGrid.new()
var rng := RandomNumberGenerator.new()
var depth := 1
var in_hub := false   # at The Last Obol (the hub): weapons and abilities are holstered
var debug := false
var bot_mode := false  # automated playtest driver active
var damage_taken_mult := 1.0  # debug: --dmg-mult=N

var preset := "medium"
var gfx: Dictionary = PRESETS["medium"].duplicate()
var hitstop_enabled := true
var user_chose_preset := false   # true once a preset was saved/picked; disables auto-downgrade

var _hitstop_until := 0
var _hitstop_cooldown_until := 0
var _slowmo_start := 0
var _slowmo_until := 0
var _slowmo_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_load_settings()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if _hitstop_until > 0 and now >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0
	if _hitstop_until == 0 and _slowmo_until > 0:
		if now >= _slowmo_until:
			_slowmo_until = 0
			Engine.time_scale = 1.0
		else:
			# hold the slow-motion, then ease back to full speed over the last 40%
			var total := float(_slowmo_until - _slowmo_start)
			var k := clampf(float(_slowmo_until - now) / maxf(1.0, total * 0.4), 0.0, 1.0)
			Engine.time_scale = lerpf(1.0, _slowmo_scale, k)
	grid.rebuild(enemies)


## A short dramatic slow-motion (real seconds), for big moments only: the last kill of an
## encounter, a massacre. Hit-stops still freeze on top of it.
func slowmo(duration: float, scale := 0.3) -> void:
	if not hitstop_enabled:
		return
	var now := Time.get_ticks_msec()
	_slowmo_start = now
	_slowmo_until = now + int(duration * 1000.0)
	_slowmo_scale = scale
	if _hitstop_until == 0:
		Engine.time_scale = scale


## Freeze-frame on impact. Kept short, shallow and rare: frequent freezes read
## as lag, so non-forced requests are budgeted to one per ~0.35 s.
func hit_stop(duration: float, scale := 0.06, force := false) -> void:
	if not hitstop_enabled:
		return
	var now := Time.get_ticks_msec()
	if not force and now < _hitstop_cooldown_until:
		return
	duration = minf(duration, 0.09 if force else 0.05)
	scale = maxf(scale, 0.15)
	var until := now + int(duration * 1000.0)
	if until > _hitstop_until:
		_hitstop_until = until
	_hitstop_cooldown_until = until + (200 if force else 350)
	Engine.time_scale = scale


func register_enemy(e: Node) -> void:
	enemies.append(e)


func unregister_enemy(e: Node) -> void:
	enemies.erase(e)


func living_enemies() -> int:
	var n := 0
	for e in enemies:
		if e.alive:
			n += 1
	return n


## Difficulty scaling for deeper dungeon runs.
func depth_hp_mult() -> float:
	return depth_hp_mult_at(depth)


func depth_hp_mult_at(d: int) -> float:
	return 1.0 + 0.45 * (d - 1)


func depth_dmg_mult() -> float:
	return 1.0 + 0.25 * (depth - 1)


# ------------------------------------------------------------------ graphics settings

func set_preset(name: String, save := true) -> void:
	if not PRESETS.has(name):
		return
	preset = name
	gfx = PRESETS[name].duplicate()
	if save:
		_save_settings()
	graphics_changed.emit()


func cycle_preset() -> String:
	user_chose_preset = true
	var i := (PRESET_ORDER.find(preset) + 1) % PRESET_ORDER.size()
	set_preset(PRESET_ORDER[i])
	return preset


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		preset = cf.get_value("graphics", "preset", "medium")
		hitstop_enabled = cf.get_value("gameplay", "hitstop", true)
		user_chose_preset = true
	else:
		# first launch: integrated / software GPUs start on Low
		var t := RenderingServer.get_video_adapter_type()
		preset = "low" if t in [RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, RenderingDevice.DEVICE_TYPE_CPU] else "medium"
	set_preset(preset, false)


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("graphics", "preset", preset)
	cf.set_value("gameplay", "hitstop", hitstop_enabled)
	cf.save(SETTINGS_PATH)
