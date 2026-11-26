extends Node
## Audio hooks. Every combat action calls Audio.play(name, ground_pos).
## Sounds live in res://assets/audio/<name>.wav (synthesised by
## tools/audio/gen_sfx.py — replace any file with a real recording to upgrade it).
## Handles voice limiting, per-sound rate limiting, pitch variation and the
## two-layer music intensity system.

const SFX := {
	# name: [volume_db, pitch_variation, min_interval_s, max_voices]
	"rifle_fire": [-9.0, 0.06, 0.03, 6],
	"shotgun_fire": [-4.0, 0.05, 0.05, 3],
	"arc_fire": [-13.0, 0.12, 0.05, 4],
	"rail_charge": [-10.0, 0.0, 0.2, 1],
	"rail_fire": [-3.0, 0.03, 0.1, 2],
	"launcher_fire": [-6.0, 0.06, 0.08, 2],
	"reload": [-10.0, 0.04, 0.1, 2],
	"reload_done": [-10.0, 0.04, 0.1, 2],
	"empty": [-10.0, 0.05, 0.15, 1],
	"overheat": [-7.0, 0.0, 0.3, 1],
	"impact_flesh": [-13.0, 0.18, 0.025, 6],
	"impact_metal": [-15.0, 0.2, 0.03, 4],
	"impact_armor": [-10.0, 0.12, 0.05, 3],
	"explosion_small": [-5.0, 0.1, 0.05, 4],
	"explosion_big": [-1.0, 0.08, 0.06, 4],
	"enemy_death": [-8.0, 0.15, 0.04, 5],
	"enemy_death_big": [-4.0, 0.1, 0.1, 3],
	"mite_attack": [-12.0, 0.15, 0.1, 3],
	"spitter_charge": [-10.0, 0.1, 0.15, 2],
	"spitter_spit": [-9.0, 0.1, 0.1, 3],
	"acid_splash": [-12.0, 0.15, 0.06, 4],
	"brute_roar": [-4.0, 0.06, 0.4, 2],
	"brute_slam": [-2.0, 0.06, 0.2, 2],
	"bloater_prime": [-6.0, 0.05, 0.2, 3],
	"dash": [-8.0, 0.08, 0.05, 2],
	"nova": [-2.0, 0.03, 0.2, 1],
	"seeker_launch": [-8.0, 0.1, 0.03, 4],
	"melee_swing": [-8.0, 0.1, 0.05, 2],
	"melee_hit": [-4.0, 0.08, 0.05, 2],
	"execute": [-2.0, 0.04, 0.1, 1],
	"whip_lash": [-9.0, 0.1, 0.05, 2],
	"whip_crack": [-4.0, 0.08, 0.04, 3],
	"whip_yank": [-5.0, 0.06, 0.1, 2],
	"pickup_item": [-6.0, 0.03, 0.05, 2],
	"pickup_orb": [-12.0, 0.15, 0.03, 4],
	"xp_orb": [-17.0, 0.2, 0.02, 4],
	"level_up": [-3.0, 0.0, 0.5, 1],
	"door_lock": [-4.0, 0.0, 0.3, 1],
	"door_open": [-5.0, 0.0, 0.3, 1],
	"chest_open": [-4.0, 0.0, 0.2, 1],
	"crate_break": [-8.0, 0.12, 0.05, 3],
	"wall_break": [-2.0, 0.05, 0.2, 1],
	"player_hurt": [-6.0, 0.08, 0.12, 2],
	"shock_zap": [-12.0, 0.15, 0.08, 3],
	"spawn": [-12.0, 0.15, 0.05, 4],
	"legendary_drop": [-2.0, 0.0, 0.3, 1],
	"ui_click": [-10.0, 0.05, 0.03, 2],
	"elite_spawn": [-3.0, 0.0, 0.5, 1],
	"shield_break": [-4.0, 0.05, 0.2, 1],
}

var _streams := {}
var _last := {}
var _voices := {}
var _pool2d: Array = []
var _pool_i := 0
var _ui: Array = []
var _ui_i := 0
var _music_calm: AudioStreamPlayer
var _music_combat: AudioStreamPlayer
var _intensity := 0.0
var _intensity_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 32:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 2600.0
		p.attenuation = 1.4
		p.bus = "Master"
		add_child(p)
		_pool2d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_ui.append(p)
	for n in SFX:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	_music_calm = _music_player("music_calm")
	_music_combat = _music_player("music_combat")
	Events.room_locked.connect(func(_r): _intensity_target = 1.0)
	Events.room_cleared.connect(func(_r): _intensity_target = 0.0)


func _music_player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := "res://assets/audio/%s.wav" % name
	if ResourceLoader.exists(path):
		var s: AudioStreamWAV = load(path)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p


func start_music() -> void:
	if _music_calm.stream:
		_music_calm.play()
	if _music_combat.stream:
		_music_combat.play()


func _process(dt: float) -> void:
	# combat layer also swells with how many enemies are actually engaging
	var live := 0
	if Game.player:
		for e in Game.enemies:
			if e.alive and e.gpos.distance_to(Game.player.gpos) < Iso.m(14.0):
				live += 1
	var t := maxf(_intensity_target, clampf(live / 6.0, 0.0, 1.0))
	_intensity = move_toward(_intensity, t, dt * (0.6 if t > _intensity else 0.18))
	_music_calm.volume_db = linear_to_db(lerpf(0.55, 0.25, _intensity) + 0.0001) - 6.0
	_music_combat.volume_db = linear_to_db(_intensity * 0.75 + 0.0001) - 6.0


func play(name: String, g = null, volume_offset := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var cfg: Array = SFX.get(name, [-8.0, 0.1, 0.03, 4])
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last.get(name, -10.0) < cfg[2]:
		return
	_last[name] = now
	var pv: float = cfg[1]
	var p_scale := pitch * (1.0 + randf_range(-pv, pv))
	if g == null:
		var u: AudioStreamPlayer = _ui[_ui_i]
		_ui_i = (_ui_i + 1) % _ui.size()
		u.stream = _streams[name]
		u.volume_db = cfg[0] + volume_offset
		u.pitch_scale = p_scale
		u.play()
		return
	# cap simultaneous voices per sound
	var active := 0
	for p in _pool2d:
		if p.playing and p.get_meta("sfx", "") == name:
			active += 1
	if active >= cfg[3]:
		return
	var p: AudioStreamPlayer2D = _pool2d[_pool_i]
	_pool_i = (_pool_i + 1) % _pool2d.size()
	p.stream = _streams[name]
	p.set_meta("sfx", name)
	p.global_position = Iso.to_screen(g)
	p.volume_db = cfg[0] + volume_offset
	p.pitch_scale = p_scale
	p.play()
