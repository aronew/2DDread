class_name Lash
extends Ability
## F: Fury's Lash, the gunslinger's hellfire bullwhip.
##   Tap     CRACK along the aim line (soft-locks the enemy you point at). The
##           far end of the reach is a sweet spot that always crits, and the
##           rope snaps enemy projectiles out of the air.
##   Hold    keep F down and the tip latches on. Light enemies are YANKED to
##           point-blank range and dazed (blunderbuss time). Heavies drag YOU
##           to them instead; yanking a Legionnaire from the front wrenches
##           its tower shield aside.
##   Execute cracking a staggered (or nearly dead) enemy wraps it, drags it in
##           and finishes it with a point-blank shot that bursts into health.
##   Dash    F during or right after a dash spins the whip in a full circle.
## Gameplay only. The rope is drawn by WhipVisual.

const REACH_M := 5.0
const SWEET_M := 1.5          # the last 1.5 m of reach is the sweet spot
const ROPE_R_M := 0.35        # hit thickness of the rope
const SNAP_R_M := 0.55        # enemy shots this close to the rope are snapped
const OUT_T := 0.085          # hand to tip
const HOLD_T := 0.2           # F still held this long after the press = yank
const LATCH_T := 0.14         # how long the tip clings, waiting for the hold
const YANK_T := 0.16
const DRAG_T := 0.14          # execute drag before the finishing shot
const RETRACT_T := 0.15
const WHIRL_T := 0.2
const WHIRL_M := 3.2
const HEAVY_MASS := 3.0
const CRACK_CD := 0.5
const YANK_CD := 2.0

const BODY_DMG := 24.0
const SWEET_DMG := 44.0
const SWEET_CRIT := 1.75
const WHIRL_DMG := 30.0

enum P { IDLE, OUT, LATCH, YANK, EXECUTE, RETRACT, WHIRL }

var visual: WhipVisual
var phase: int = P.IDLE
var t := 0.0
var holding := false
var held_t := 0.0
var target = null             # enemy the tip is aimed at / latched onto
var tip_g := Vector2.ZERO     # ground position of the tip
var tip_h := 0.9              # tip height (m)
var heavy := false
var _zip_vel := Vector2.ZERO
var _after_t := 0.0
var _whirl_a0 := 0.0
var _whirl_hit := {}
var _retract_from := Vector2.ZERO
var _retract_h := 0.9
## Usage counters (the bot prints them; handy for tuning)
var stats := {"crack": 0, "sweet": 0, "yank": 0, "wrench": 0, "execute": 0, "whirl": 0, "snapped": 0}


func _init() -> void:
	title = "Fury's Lash"
	key_hint = "F"
	color = Color(1.0, 0.72, 0.3)
	cooldown = CRACK_CD


func set_held(down: bool) -> void:
	holding = holding and down


func busy() -> bool:
	return phase != P.IDLE and phase != P.RETRACT


func cancel() -> void:
	phase = P.IDLE
	target = null
	if visual:
		visual.hide_rope()


func use(p) -> bool:
	if busy():
		return false
	cooldown = CRACK_CD
	holding = true
	held_t = 0.0
	t = 0.0
	if p.dash_recent(0.12):
		_start_whirl(p)
		return true
	target = _pick_target(p)
	phase = P.OUT
	_update_tip(p)
	Audio.play("whip_lash", p.gpos)
	return true


func process(dt: float, p) -> void:
	super.process(dt, p)
	if phase == P.IDLE:
		return
	held_t += dt
	t += dt
	if target != null and not (is_instance_valid(target) and target.alive):
		target = null
	match phase:
		P.OUT:
			_update_tip(p)
			_snap_shots(p.gpos, p.gpos.lerp(tip_g, minf(1.0, t / OUT_T)))
			if t >= OUT_T:
				_crack(p)
		P.LATCH:
			if target == null:
				_retract()
			else:
				tip_g = target.gpos
				if holding and held_t >= HOLD_T:
					_start_yank(p)
				elif not holding or t >= LATCH_T:
					_retract()
		P.YANK, P.EXECUTE:
			_drag(dt, p)
		P.RETRACT:
			if t >= RETRACT_T:
				phase = P.IDLE
				visual.hide_rope()
				return
		P.WHIRL:
			_whirl(p)
	_draw(p)


# ------------------------------------------------------------------ crack

func _pick_target(p):
	var reach := Iso.m(REACH_M)
	var best = null
	var best_s := INF
	for e in Game.grid.query(p.gpos, reach + Iso.m(1.0)):
		if not e.alive:
			continue
		var to: Vector2 = e.gpos - p.gpos
		var d := to.length()
		if d > reach + e.radius * 0.5:
			continue
		var a := absf(p.aim_dir.angle_to(to)) if d > 1.0 else 0.0
		if a > 0.42 or not Game.dungeon.has_los(p.gpos, e.gpos):
			continue
		var s := a + d / reach * 0.25
		if e.gpos.distance_to(p.aim_target) < e.radius + Iso.m(0.4):
			s -= 0.5   # the enemy under the cursor wins
		if _executable(e):
			s -= 0.2
		if s < best_s:
			best_s = s
			best = e
	return best


func _update_tip(p) -> void:
	if target:
		var to: Vector2 = target.gpos - p.gpos
		tip_g = p.gpos + to.limit_length(Iso.m(REACH_M))
		tip_h = target.hit_height
	else:
		var want: Vector2 = p.gpos + p.aim_dir * Iso.m(REACH_M)
		var hit: Dictionary = Game.dungeon.raycast(p.gpos, want)
		tip_g = hit["point"] - p.aim_dir * 4.0 if hit["hit"] else want
		tip_h = 0.9


func _executable(e) -> bool:
	return e.alive and not e.data.boss and e.data.yankable \
		and (e.staggered() or (e.hp / e.max_hp < 0.2 and not e.is_elite))


func _crack(p) -> void:
	var from: Vector2 = p.gpos
	var tip := tip_g
	var rope_len := from.distance_to(tip)
	var sweet_zone := rope_len >= Iso.m(REACH_M - SWEET_M)
	var rope_r := Iso.m(ROPE_R_M)
	var exec = target if target and _executable(target) else null
	var hits := 0
	var sweet_hits := 0
	for e in Game.grid.query((from + tip) * 0.5, rope_len * 0.5 + Iso.m(1.2)):
		if not e.alive:
			continue
		var cp := Geometry2D.get_closest_point_to_segment(e.gpos, from, tip)
		if cp.distance_to(e.gpos) > e.radius + rope_r:
			continue
		var at_tip: bool = e == target or e.gpos.distance_to(tip) < e.radius + Iso.m(0.6)
		if exec == null and at_tip and _executable(e):
			exec = e
		if e == exec:
			continue
		var sweet := at_tip and sweet_zone
		var d := DamageInfo.make(SWEET_DMG if sweet else BODY_DMG, DamageInfo.Type.PHYSICAL, p)
		d.is_melee = true
		d.direction = (e.gpos - from).normalized()
		d.knockback = Iso.m(5.0 if sweet else 2.5)
		d.stagger = 75.0 if sweet else 30.0
		d.hit_pos = e.gpos
		if sweet:
			d.crit = true
			d.crit_mult = SWEET_CRIT
			d.amount *= SWEET_CRIT
			sweet_hits += 1
		VFX.impact(e.gpos, e.hit_height, -d.direction, "flesh", e.blood_color)
		Combat.hit_enemy(e, d)
		hits += 1
	var ph: Dictionary = Game.dungeon.segment_prop(from, tip, rope_r)
	if not ph.is_empty():
		var pd := DamageInfo.make(SWEET_DMG, DamageInfo.Type.PHYSICAL, p)
		pd.is_melee = true
		pd.direction = (tip - from).normalized()
		ph["prop"].take_damage(pd)
	_snap_shots(from, tip)
	_crack_fx(p, sweet_hits > 0, hits > 0)
	stats["crack"] += 1
	stats["sweet"] += sweet_hits
	if exec:
		_start_execute(p, exec)
	elif target and target.alive and holding:
		phase = P.LATCH
		t = 0.0
	else:
		_retract()


func _crack_fx(p, sweet: bool, hit: bool) -> void:
	var sp := Iso.lift(tip_g, tip_h)
	var ang := Iso.to_screen(tip_g - p.gpos).angle()
	Audio.play("whip_crack", tip_g)
	VFX.burst_sprite(VFX.T.flash, sp, Color(2.6, 2.0, 1.1), Vector2(0.25, 0.2), Vector2(0.75, 0.5), 0.08, true, ang)
	VFX.emit("sparks", sp, ang, Color(3.0, 2.2, 1.0), 0.35 if not sweet else 0.7)
	if sweet:
		VFX.burst_sprite(VFX.T.ring, sp, Color(2.4, 1.8, 0.8), Vector2(0.1, 0.1 * Iso.K), Vector2(0.55, 0.55 * Iso.K), 0.14)
		VFX.light_flash(sp, Color(1.0, 0.75, 0.35), 1.8, 3.0, 0.12)
		VFX.shake(0.14)
		Game.hit_stop(0.035, 0.1)
	elif hit:
		VFX.shake(0.07)


## Enemy shots touching the rope are snapped out of the air.
func _snap_shots(a: Vector2, b: Vector2) -> void:
	var snap_r := Iso.m(SNAP_R_M)
	var snapped := 0
	for q in Game.projectiles.list:
		if q.team != 1 or q.dead:
			continue
		var cp := Geometry2D.get_closest_point_to_segment(q.pos, a, b)
		if cp.distance_to(q.pos) < snap_r + q.radius:
			q.dead = true
			snapped += 1
			VFX.impact(q.pos, q.height, -q.vel.normalized(), "default", Color(1.0, 0.8, 0.4))
	if snapped > 0:
		stats["snapped"] += snapped
		Audio.play("impact_armor", b, -4.0, 1.4)


# ------------------------------------------------------------------ yank / execute

func _stop_dist(p, e) -> float:
	return p.radius + e.radius + Iso.m(0.9)


func _start_yank(p) -> void:
	var e = target
	if not e.data.yankable:
		_retract()   # too volatile to drag: the whip slips off
		return
	_set_cd(p, YANK_CD)
	stats["yank"] += 1
	phase = P.YANK
	t = 0.0
	var dir: Vector2 = (e.gpos - p.gpos).normalized()
	heavy = e.data.mass >= HEAVY_MASS
	Audio.play("whip_yank", e.gpos)
	if heavy:
		if e.armor_hp > 0.0 and e.facing.dot(-dir) > 0.45:
			e.wrench_shield(0.5, 1.2)
			stats["wrench"] += 1
		else:
			_tug_hit(p, e, 12.0, 55.0)
		_start_zip(p, e)
	else:
		_tug_hit(p, e, 12.0, 0.0)
		e.yank(p.gpos + dir * _stop_dist(p, e), YANK_T, 0.45)


func _start_execute(p, e) -> void:
	target = e
	phase = P.EXECUTE
	t = 0.0
	tip_g = e.gpos
	tip_h = e.hit_height
	heavy = e.data.mass >= HEAVY_MASS
	Audio.play("whip_yank", e.gpos)
	if heavy:
		_start_zip(p, e)
	else:
		e.yank(p.gpos + (e.gpos - p.gpos).normalized() * _stop_dist(p, e), DRAG_T, 0.6)


func _start_zip(p, e) -> void:
	var to: Vector2 = e.gpos - p.gpos
	var dist := maxf(0.0, to.length() - _stop_dist(p, e))
	var dur := DRAG_T if phase == P.EXECUTE else YANK_T
	_zip_vel = to.normalized() * dist / dur
	p.grant_iframes(dur + 0.08)
	_after_t = 0.0


func _tug_hit(p, e, amount: float, stagger: float) -> void:
	var d := DamageInfo.make(amount, DamageInfo.Type.PHYSICAL, p)
	d.is_melee = true
	d.direction = (p.gpos - e.gpos).normalized()
	d.stagger = stagger
	d.hit_pos = e.gpos
	Combat.hit_enemy(e, d)


func _drag(dt: float, p) -> void:
	var dur := YANK_T if phase == P.YANK else DRAG_T
	if target == null:
		_retract()
		return
	tip_g = target.gpos
	tip_h = target.hit_height
	if heavy:
		p.external_motion(_zip_vel * dt)
		_after_t -= dt
		if _after_t <= 0.0:
			_after_t = 0.035
			VFX.afterimage(p.visual.sprites(), Color(2.0, 1.3, 0.5, 0.45), 0.18)
	else:
		target.yank_to = p.gpos + (target.gpos - p.gpos).normalized() * _stop_dist(p, target)
	if t < dur:
		return
	if phase == P.EXECUTE:
		_finish(p, target)
	else:
		VFX.shake(0.12)
		VFX.emit("smoke", Iso.lift(target.gpos, 0.2), -PI / 2, Color(0.5, 0.45, 0.4, 0.5), 0.3)
	_retract()


## The point-blank finishing shot.
func _finish(p, e) -> void:
	if not e.alive:
		return
	var dir: Vector2 = (e.gpos - p.gpos).normalized()
	var w = p.cur_weapon()
	var mcol: Color = w.data.muzzle_color if w else Color(1.0, 0.75, 0.35)
	VFX.muzzle(p.muzzle_screen(), dir, {"color": mcol, "scale": 1.3, "light": 2.4, "range": 4.0, "sparks": 0.6})
	if w:
		Audio.play(w.data.sound_fire, p.gpos)
	p.visual.kick(10.0, dir)
	var d := DamageInfo.make(e.hp + 999.0, DamageInfo.Type.PHYSICAL, p)
	d.is_melee = true
	d.execute = true
	d.direction = dir
	d.knockback = Iso.m(12.0)
	d.hit_pos = e.gpos
	VFX.impact(e.gpos, e.hit_height, -dir, "flesh", e.blood_color)
	Audio.play("execute", e.gpos)
	VFX.popup(e.gpos, 2.0, "EXECUTED", Color(1.0, 0.75, 0.3), 32)
	VFX.screen_flash(Color(1.0, 0.6, 0.2, 0.16), 0.1)
	VFX.shake(0.45)
	Game.hit_stop(0.1, 0.04, true)
	var at: Vector2 = e.gpos
	Combat.hit_enemy(e, d)
	stats["execute"] += 1
	for i in 3:
		Pickup.spawn(&"health", at, {"value": 10.0})
	if randf() < 0.5:
		Pickup.spawn(&"ammo", at, {"value": 0.15})


# ------------------------------------------------------------------ whirl

func _start_whirl(p) -> void:
	phase = P.WHIRL
	stats["whirl"] += 1
	target = null
	_whirl_a0 = p.aim_dir.angle()
	_whirl_hit.clear()
	tip_h = 0.85
	Audio.play("whip_lash", p.gpos, 0.0, 0.8)


func _whirl(p) -> void:
	var k := minf(1.0, t / WHIRL_T)
	var r := Iso.m(WHIRL_M)
	tip_g = p.gpos + Vector2.from_angle(_whirl_a0 + k * TAU) * r
	for e in Game.grid.query(p.gpos, r + Iso.m(0.5)):
		if not e.alive or _whirl_hit.has(e.get_instance_id()):
			continue
		var to: Vector2 = e.gpos - p.gpos
		if to.length() > r + e.radius:
			continue
		if fposmod(to.angle() - _whirl_a0, TAU) > k * TAU + 0.15:
			continue
		_whirl_hit[e.get_instance_id()] = true
		var d := DamageInfo.make(WHIRL_DMG, DamageInfo.Type.PHYSICAL, p)
		d.is_melee = true
		d.direction = to.normalized()
		d.knockback = Iso.m(6.0)
		d.stagger = 45.0
		d.hit_pos = e.gpos
		VFX.impact(e.gpos, e.hit_height, -d.direction, "flesh", e.blood_color)
		Combat.hit_enemy(e, d)
	for q in Game.projectiles.list:
		if q.team == 1 and not q.dead and q.pos.distance_to(p.gpos) < r + q.radius:
			if fposmod((q.pos - p.gpos).angle() - _whirl_a0, TAU) <= k * TAU + 0.15:
				q.dead = true
				VFX.impact(q.pos, q.height, -q.vel.normalized(), "default", Color(1.0, 0.8, 0.4))
	if k >= 1.0:
		if not _whirl_hit.is_empty():
			VFX.shake(0.15)
		_crack_fx(p, false, false)
		_retract()


# ------------------------------------------------------------------ helpers

func _retract() -> void:
	_retract_from = tip_g
	_retract_h = tip_h
	phase = P.RETRACT
	t = 0.0
	target = null


func _set_cd(p, cd: float) -> void:
	cd_total = cd * maxf(0.3, 1.0 - p.build.stat("cooldown_pct"))
	cd_left = maxf(cd_left, cd_total)


func _draw(p) -> void:
	if visual == null:
		return
	var origin := Iso.to_screen(p.gpos)
	var hand: Vector2 = p.whip_hand_screen() - origin
	var tip := Iso.lift(tip_g, tip_h) - origin
	var pts: PackedVector2Array
	var glow := 0.85
	match phase:
		P.OUT:
			var k := minf(1.0, t / OUT_T)
			var ext := 1.0 - (1.0 - k) * (1.0 - k)
			pts = WhipVisual.rope_points(hand, tip, ext, 38.0 * (1.0 - k), k * TAU * 1.5, -30.0 * (1.0 - k))
			glow = 0.5 + 0.5 * k
		P.LATCH, P.YANK, P.EXECUTE:
			pts = WhipVisual.rope_points(hand, tip, 1.0, 5.0 * maxf(0.0, 1.0 - t * 8.0), t * 60.0, 0.0)
		P.RETRACT:
			var k := minf(1.0, t / RETRACT_T)
			var rt := Iso.lift(_retract_from, _retract_h) - origin
			pts = WhipVisual.rope_points(hand, rt, 1.0 - k * k, 22.0 * k, k * TAU, 34.0 * k)
			glow = 1.0 - k
		P.WHIRL:
			var k := minf(1.0, t / WHIRL_T)
			pts = WhipVisual.whirl_points(p.gpos, origin, _whirl_a0 + k * TAU, Iso.m(WHIRL_M), hand)
	visual.show_rope(pts, glow)
