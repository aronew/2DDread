class_name KillFeel
extends Node
## The big moments of a fight, on top of each kill's own feedback (Enemy.die):
## * a massacre: 3+ kills within KILL_WINDOW pops "CARNAGE xN" over the gunslinger with a
##   forced hit-stop, a camera punch and a jolt of shake (escalating at 5 and 8);
## * an elite falls: a short slow-motion;
## * the last enemy of an encounter dies: a longer slow-motion, a zoom punch and a gold
##   flash, so clearing a room lands.
## Lives under the level root, so it is rebuilt with the level.

const KILL_WINDOW := 0.8
const TIERS := [3, 5, 8, 12]
const WORDS := ["CARNAGE", "MASSACRE", "ANNIHILATION", "APOCALYPSE"]

var _kills: Array = []     # real-time stamps (ms) of recent kills
var _tier := -1


func _ready() -> void:
	Events.enemy_killed.connect(_on_kill)
	Events.room_cleared.connect(_on_clear)


func _on_kill(e, _info) -> void:
	var now := Time.get_ticks_msec()
	_kills.append(now)
	while not _kills.is_empty() and now - int(_kills[0]) > int(KILL_WINDOW * 1000.0):
		_kills.pop_front()
	if _kills.size() <= 1:
		_tier = -1
	var n := _kills.size()
	var tier := -1
	for k in TIERS.size():
		if n >= TIERS[k]:
			tier = k
	if tier > _tier:
		_tier = tier
		_massacre(n, tier)
	if e and e.data.boss:
		Game.slowmo(1.6, 0.18)
		if VFX.camera:
			VFX.camera.punch(0.1)
		VFX.screen_flash(Color(0.6, 1.0, 0.7, 0.35), 0.4)
	elif e and e.is_elite:
		Game.slowmo(0.35, 0.35)


func _massacre(n: int, tier: int) -> void:
	var pl = Game.player
	if pl == null:
		return
	var col := Color(1.0, 0.78, 0.3).lerp(Color(1.0, 0.3, 0.2), tier / 3.0)
	VFX.popup(pl.gpos, 3.2 + tier * 0.2, "%s  x%d" % [WORDS[tier], n], col, 54 + tier * 8)
	Game.hit_stop(0.05, 0.1, true)
	VFX.shake(0.25 + 0.08 * tier)
	if VFX.camera:
		VFX.camera.punch(0.035 + 0.012 * tier)
	VFX.flash_layer(VFX.T.star6, Iso.lift(pl.gpos, 1.0), randf() * TAU, col * Color(2.6, 2.4, 2.2, 0.8),
		Vector2(0.6, 0.6), Vector2(2.6, 2.6) + Vector2.ONE * tier * 0.5, 0.25)
	Audio.play("execute", pl.gpos, -3.0, 1.1 + tier * 0.05)


func _on_clear(_room) -> void:
	Game.slowmo(0.8, 0.22)
	if VFX.camera:
		VFX.camera.punch(0.06)
	VFX.screen_flash(Color(1.0, 0.82, 0.45, 0.22), 0.25)
