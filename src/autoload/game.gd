extends Node
## Run-level coordinator: references to live systems, hit-stop, difficulty depth.

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
var debug := false
var bot_mode := false  # automated playtest driver active

var _hitstop_until := 0
var _hitstop_cooldown_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()


func _process(_dt: float) -> void:
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
		_hitstop_until = 0
	grid.rebuild(enemies)


## Freeze-frame on impact. Budgeted so rapid kills don't turn into stutter.
func hit_stop(duration: float, scale := 0.06, force := false) -> void:
	var now := Time.get_ticks_msec()
	if not force and now < _hitstop_cooldown_until:
		return
	var until := now + int(duration * 1000.0)
	if until > _hitstop_until:
		_hitstop_until = until
	_hitstop_cooldown_until = until + 90
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
	return 1.0 + 0.45 * (depth - 1)


func depth_dmg_mult() -> float:
	return 1.0 + 0.25 * (depth - 1)
