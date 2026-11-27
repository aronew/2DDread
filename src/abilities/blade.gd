class_name Blade
extends Ability
## RMB: the Hellfire Saber. Melee is part of moving, not a pause in it.
##   Combo    tap (or hold) RMB for a three-hit chain: slash, back-slash, then a heavy
##            wide cleave. Every swing lunges you forward, and snaps onto an enemy in
##            front of you if one is in reach, so pressing on enemies closes the gap.
##            You keep steering throughout; the next swing can cancel the end of the
##            last one, and presses are buffered.
##   Thrust   RMB during or right after a dash turns it into a piercing dash-slash that
##            carries you on through the whole line.
##   Execute  any swing that connects with a staggered (or nearly dead) enemy finishes
##            it in a burst of health and ammo.
##   Rewards  every sword kill spills ammo and a health orb: the DOOM loop, so diving
##            in is how you refill.
##   Deflect  enemy shots inside the slash are cut out of the air.
## Gameplay only; the slash is drawn by SlashFX.

const SWINGS := [
	# dmg, arc (deg), reach (m), stagger, knockback (m/s), lunge (m), time (s), heavy
	{"dmg": 26.0, "arc": 150.0, "reach": 2.5, "stagger": 32.0, "kb": 4.0, "lunge": 1.3, "time": 0.22, "heavy": false},
	{"dmg": 26.0, "arc": 150.0, "reach": 2.5, "stagger": 32.0, "kb": 4.0, "lunge": 1.3, "time": 0.22, "heavy": false},
	{"dmg": 58.0, "arc": 230.0, "reach": 3.0, "stagger": 90.0, "kb": 10.0, "lunge": 2.0, "time": 0.36, "heavy": true},
]
const HIT_AT := 0.045          # the blade lands this long into a swing (heavy: x1.6)
const CANCEL_AT := 0.62        # fraction of a swing after which the next one can start
const COMBO_WINDOW := 0.45     # after a swing ends, the next press continues the chain
const BUFFER_T := 0.2          # a press this early is remembered
const LUNGE_T := 0.09
const MAGNET_M := 4.0          # the lunge snaps toward an enemy in front this far away
const MAGNET_ARC := 0.75       # radians either side of the aim
const THRUST_M := 5.0
const THRUST_T := 0.13
const THRUST_W_M := 0.9
const THRUST_DMG := 48.0
const KILL_AMMO := 0.05        # fraction of every ammo pool a sword kill spills
const KILL_HEAL := 6.0
const EXEC_HEAL := 3           # health orbs (10 hp each) from an execution

var swinging := false
var stats := {"swing": 0, "heavy": 0, "thrust": 0, "hits": 0, "kills": 0, "execute": 0, "deflect": 0}
var _i := 0                    # next swing of the combo
var _cur := {}
var _t := 0.0
var _dur := 0.0
var _hit_done := false
var _side := 1.0
var _aim_a := 0.0
var _combo_t := 0.0
var _buffer := 0.0
var _lunge := Vector2.ZERO     # ground px/s
var _lunge_t := 0.0
var _thrust := false
var _thrust_from := Vector2.ZERO
var _thrust_hit := {}
var _after_t := 0.0


func _init() -> void:
	title = "Hellfire Saber"
	key_hint = "RMB"
	color = Color(1.0, 0.55, 0.25)
	cooldown = 0.0


## RMB pressed (buffered) or held (keeps the chain going).
func input(p, pressed: bool, held: bool) -> void:
	if pressed:
		_buffer = BUFFER_T
	if (_buffer > 0.0 or held) and _can_swing():
		_buffer = 0.0
		_start(p)


func _can_swing() -> bool:
	return not swinging or _t >= _dur * CANCEL_AT


## Gun fire is held back only while the blade is actually cutting.
func blocks_fire() -> bool:
	return swinging and _t < _dur * CANCEL_AT


func cancel() -> void:
	swinging = false
	_lunge_t = 0.0


func process(dt: float, p) -> void:
	super.process(dt, p)
	_buffer = maxf(0.0, _buffer - dt)
	if not swinging:
		_combo_t = maxf(0.0, _combo_t - dt)
		if _combo_t <= 0.0:
			_i = 0
	if _lunge_t > 0.0:
		var step := minf(dt, _lunge_t)
		p.external_motion(_lunge * step)
		_lunge_t -= dt
		if _thrust:
			_thrust_hits(p)
			_after_t -= dt
			if _after_t <= 0.0:
				_after_t = 0.02
				VFX.afterimage(p.visual.sprites(), Color(2.2, 1.1, 0.5, 0.5), 0.2)
	if not swinging:
		return
	_t += dt
	var hit_at: float = HIT_AT * (1.6 if _cur.get("heavy", false) else 1.0)
	if not _hit_done and _t >= hit_at:
		_hit_done = true
		if not _thrust:
			_slash_hits(p)
	if _t >= _dur:
		swinging = false
		_combo_t = COMBO_WINDOW


# ------------------------------------------------------------------ swings

func _start(p) -> void:
	swinging = true
	_t = 0.0
	_hit_done = false
	if p.dash_recent(0.15):
		_start_thrust(p)
		return
	_thrust = false
	_cur = SWINGS[_i]
	_dur = _cur["time"] / p.build.mult("attack_speed_pct")
	_side = -1.0 if _i == 1 else 1.0
	_i = (_i + 1) % SWINGS.size()
	_aim_a = p.aim_dir.angle()
	stats["swing"] += 1
	# lunge: forward, or onto the enemy in front if one is in reach
	var dist := Iso.m(_cur["lunge"])
	var dir: Vector2 = p.aim_dir
	var tgt = _magnet(p)
	if tgt:
		var to: Vector2 = tgt.gpos - p.gpos
		dir = to.normalized()
		_aim_a = dir.angle()
		dist = clampf(to.length() - (p.radius + tgt.radius + Iso.m(0.55)), 0.0, Iso.m(MAGNET_M))
	_lunge = dir * dist / LUNGE_T
	_lunge_t = LUNGE_T
	var heavy: bool = _cur["heavy"]
	if heavy:
		stats["heavy"] += 1
	Audio.play("sword_heavy" if heavy else "sword_swing", p.gpos, 0.0, randf_range(0.92, 1.08))
	var half := deg_to_rad(_cur["arc"]) * 0.5
	var reach: float = _cur["reach"]
	SlashFX.spawn(p.gpos, 1.0, _aim_a - half * _side, _aim_a + half * _side, reach * 0.45, reach,
		0.06 if not heavy else 0.1, 0.13 if not heavy else 0.2,
		Color(1.9, 1.15, 0.55), Color(1.35, 0.32, 0.07) if not heavy else Color(1.6, 0.25, 0.05))
	VFX.emit("embers", Iso.lift(p.gpos + Vector2.from_angle(_aim_a) * Iso.m(reach * 0.75), 1.0),
		Iso.to_screen(Vector2.from_angle(_aim_a)).angle(), Color(2.6, 1.0, 0.3), 0.3 if not heavy else 0.6)
	p.visual.kick(6.0 if not heavy else 10.0, dir)


func _magnet(p):
	var best = null
	var best_s := INF
	for e in Game.grid.query(p.gpos, Iso.m(MAGNET_M) + Iso.m(1.0)):
		if not e.alive:
			continue
		var to: Vector2 = e.gpos - p.gpos
		var d := to.length()
		if d > Iso.m(MAGNET_M) + e.radius or d < 1.0:
			continue
		var a := absf(p.aim_dir.angle_to(to))
		if a > MAGNET_ARC or not Game.dungeon.has_los(p.gpos, e.gpos):
			continue
		var s := d / Iso.m(MAGNET_M) + a * 0.6
		if _executable(e):
			s -= 0.4
		if s < best_s:
			best_s = s
			best = e
	return best


func _slash_hits(p) -> void:
	var reach := Iso.m(_cur["reach"])
	var half := deg_to_rad(_cur["arc"]) * 0.5
	var heavy: bool = _cur["heavy"]
	var hits := 0
	var kills := 0
	for e in Game.grid.query(p.gpos, reach + Iso.m(1.0)):
		if not e.alive:
			continue
		var to: Vector2 = e.gpos - p.gpos
		if to.length() > reach + e.radius:
			continue
		if to.length() > e.radius and absf(angle_difference(_aim_a, to.angle())) > half + 0.15:
			continue
		var res := _hit(p, e, _cur["dmg"], _cur["stagger"], _cur["kb"], to.normalized(), heavy)
		hits += 1
		kills += res
	for pr in Game.dungeon.props.duplicate():
		if pr.alive and pr.gpos.distance_to(p.gpos) < reach + pr.radius:
			var pd := DamageInfo.make(_cur["dmg"], DamageInfo.Type.PHYSICAL, p)
			pd.is_melee = true
			pd.direction = (pr.gpos - p.gpos).normalized()
			pr.take_damage(pd)
	_deflect(p, reach, half)
	_feedback(p, hits, kills, heavy)


func _start_thrust(p) -> void:
	_thrust = true
	_cur = {"heavy": true}
	_dur = THRUST_T + 0.08
	_thrust_from = p.gpos
	_thrust_hit.clear()
	_i = 1   # a follow-up press continues with the back-slash
	stats["thrust"] += 1
	var dir: Vector2 = p.aim_dir
	_aim_a = dir.angle()
	_lunge = dir * Iso.m(THRUST_M) / THRUST_T
	_lunge_t = THRUST_T
	_after_t = 0.0
	p.grant_iframes(THRUST_T + 0.1)
	Audio.play("sword_thrust", p.gpos)
	SlashFX.spawn(p.gpos + dir * Iso.m(THRUST_M * 0.5), 1.0, _aim_a + PI * 0.5, _aim_a - PI * 0.5,
		0.05, THRUST_M * 0.5 + 0.4, 0.05, 0.22, Color(1.9, 1.15, 0.55), Color(1.5, 0.3, 0.06))
	VFX.burst_sprite(VFX.T.spark, Iso.lift(p.gpos + dir * Iso.m(THRUST_M * 0.5), 1.0), Color(2.6, 1.6, 0.7, 0.8),
		Vector2(0.6, 0.12), Vector2(Iso.m(THRUST_M) / 40.0, 0.18), 0.18, true, Iso.to_screen(dir).angle())


func _thrust_hits(p) -> void:
	var w := Iso.m(THRUST_W_M)
	var hits := 0
	var kills := 0
	for e in Game.grid.query(p.gpos, Iso.m(3.0)):
		if not e.alive or _thrust_hit.has(e.get_instance_id()):
			continue
		var cp := Geometry2D.get_closest_point_to_segment(e.gpos, _thrust_from, p.gpos)
		if cp.distance_to(e.gpos) > w + e.radius:
			continue
		_thrust_hit[e.get_instance_id()] = true
		kills += _hit(p, e, THRUST_DMG, 70.0, 7.0, Iso.left_of(p.aim_dir) * signf(Iso.left_of(p.aim_dir).dot(e.gpos - p.gpos)), true)
		hits += 1
	_deflect(p, w + Iso.m(0.6), PI)
	if hits > 0:
		_feedback(p, hits, kills, true)


## Returns 1 if the hit killed.
func _hit(p, e, dmg: float, stagger: float, kb_m: float, dir: Vector2, heavy: bool) -> int:
	stats["hits"] += 1
	var at: Vector2 = e.gpos
	if _executable(e):
		_execute(p, e, dir)
		return 1
	var d := DamageInfo.make(dmg * power(p), DamageInfo.Type.PHYSICAL, p)
	d.is_melee = true
	d.direction = dir
	d.knockback = Iso.m(kb_m)
	d.stagger = stagger
	d.hit_pos = at
	Combat.roll_crit(d, p.build.stat("crit_chance") + 0.05, 1.75)
	VFX.impact(at, e.hit_height, -dir, "flesh", e.blood_color)
	VFX.burst_sprite(VFX.T.slash, Iso.lift(at, e.hit_height), Color(3.0, 1.8, 0.8, 0.9),
		Vector2(0.18, 0.08), Vector2(0.55, 0.22), 0.1, true, Iso.to_screen(dir).angle() + PI * 0.5)
	Combat.hit_enemy(e, d)
	if not e.alive:
		_kill_reward(at)
		return 1
	return 0


func _executable(e) -> bool:
	return e.alive and not e.data.boss and (e.staggered() or (e.hp / e.max_hp < 0.15 and not e.is_elite))


func _execute(p, e, dir: Vector2) -> void:
	var at: Vector2 = e.gpos
	var d := DamageInfo.make(e.hp + 999.0, DamageInfo.Type.PHYSICAL, p)
	d.is_melee = true
	d.execute = true
	d.direction = dir
	d.knockback = Iso.m(12.0)
	d.hit_pos = at
	VFX.impact(at, e.hit_height, -dir, "flesh", e.blood_color)
	VFX.gore(at, e.blood_color, 1.2, dir)
	Audio.play("execute", at)
	VFX.popup(at, 2.0, "EXECUTED", Color(1.0, 0.75, 0.3), 32)
	VFX.screen_flash(Color(1.0, 0.55, 0.2, 0.14), 0.1)
	VFX.light_flash(Iso.lift(at, 1.0), Color(1.0, 0.6, 0.3), 2.2, 4.0, 0.2)
	Combat.hit_enemy(e, d)
	stats["execute"] += 1
	for i in EXEC_HEAL:
		Pickup.spawn(&"health", at, {"value": 10.0})
	Pickup.spawn(&"ammo", at, {"value": 0.12})
	Game.hit_stop(0.07, 0.05, true)
	VFX.shake(0.35)


func _kill_reward(at: Vector2) -> void:
	stats["kills"] += 1
	Pickup.spawn(&"ammo", at, {"value": KILL_AMMO})
	Pickup.spawn(&"health", at, {"value": KILL_HEAL})


func _deflect(p, r: float, half: float) -> void:
	var n := 0
	for q in Game.projectiles.list:
		if q.team != 1 or q.dead:
			continue
		var to: Vector2 = q.pos - p.gpos
		if to.length() > r + q.radius:
			continue
		if half < PI and absf(angle_difference(_aim_a, to.angle())) > half + 0.2:
			continue
		q.dead = true
		n += 1
		VFX.impact(q.pos, q.height, -q.vel.normalized(), "default", Color(1.0, 0.8, 0.4))
	if n > 0:
		stats["deflect"] += n
		Audio.play("impact_armor", p.gpos, -3.0, 1.5)


func _feedback(p, hits: int, kills: int, heavy: bool) -> void:
	if hits <= 0:
		return
	Audio.play("sword_hit", p.gpos, 0.0, randf_range(0.9, 1.1))
	VFX.shake(0.1 + 0.04 * hits + (0.12 if heavy else 0.0))
	VFX.kick(Iso.to_screen(Vector2.from_angle(_aim_a)).normalized(), 6.0 if heavy else 3.5)
	# a tiny freeze on contact sells the weight; budgeted by Game.hit_stop's cooldown
	Game.hit_stop(0.05 if heavy or kills > 0 else 0.025, 0.08)
