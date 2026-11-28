class_name Player
extends Node2D
## The hunter. Fast, momentum-preserving movement, a long dash with i-frames,
## twin-stick aim (mouse or right stick with aim assist), 3 primary weapons,
## RMB Hellfire Saber (combo / dash-slash / execute, see Blade), F Firebomb, Q/E abilities.

const SPEED_M := 7.6
const ACCEL_M := 100.0
const DECEL_M := 85.0
const DASH_SPEED_M := 34.0
const DASH_TIME := 0.18           # 6.1 m
const DASH_IFRAMES := 0.26
const DASH_RECHARGE := 0.8
const DASH_CARRY := 1.45          # you come out of a dash this much faster than a run...
const CARRY_DECAY_M := 8.0        # ...and keep that momentum, bleeding it off at this m/s^2
const DASH_BUFFER := 0.16         # a dash pressed this soon before one is possible still fires
const DASH_KILL_WINDOW := 0.45    # a kill during or this soon after a dash refunds a charge
const STEP_T := 0.26              # footstep dust while running
const DASH_LAND := 0.07           # the dash's landing pose holds this long after it
const AMMO_MAX := {"light": 420, "shells": 64, "cells": 30}
const BACKPACK_SIZE := 24

var gpos := Vector2.ZERO
var vel := Vector2.ZERO
var radius := Iso.m(0.36)
var alive := true
var hp := 120.0
var max_hp := 120.0
var level := 1
var xp := 0
var xp_next := 70

var aim_dir := Vector2.RIGHT
var aim_target := Vector2.ZERO
var weapons: Array = [null, null, null]
var cur := 0
var launcher: Weapon
var ammo := {"light": 300, "shells": 44, "cells": 18}
var gear := {&"armor": null, &"core": null, &"relic": null}
var backpack: Array = []
var build: Build
var abilities: Array = []
var blade: Blade

var dash_charges := 2
var dash_max := 2
var _dash_recharge_t := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _dash_from := Vector2.ZERO
var _since_dash := 99.0
var _iframes := 0.0
var _hurt_iframes := 0.0
var _hurt_flash := 0.0
var _last_hit_dir := Vector2.ZERO   # the push of the last hit: a killing blow knocks him over backward
var _regen_delay := 0.0
var _swap_t := 0.0
var _launcher_t := 0.0
var _afterimage_t := 0.0
var _dash_buffer := 0.0
var _streak: DashStreak
var _last_fire_t := 0.0
var _step_t := 0.0
var _move_input := Vector2.ZERO
var _extern_motion := Vector2.ZERO
var visual: PlayerVisual
var input_override = null   # automated playtest driver (see BotDriver)


func _ready() -> void:
	Game.player = self
	visual = PlayerVisual.new()
	add_child(visual)
	build = Build.new(self)
	weapons[0] = _starter(&"rifle")
	weapons[1] = _starter(&"shotgun")
	weapons[2] = _starter(&"arc")
	launcher = Weapon.new(WeaponDB.get_data(&"launcher"))
	abilities = [ShockNova.new(), SeekerSwarm.new()]
	blade = Blade.new()
	build.recalc()
	on_stats_changed()
	hp = max_hp
	visual.set_torso(weapons[cur].data.torso)
	Events.enemy_killed.connect(_on_enemy_killed)


func _starter(id: StringName) -> Weapon:
	var it := Item.new()
	it.kind = &"weapon"
	it.base_id = id
	it.rarity = Item.Rarity.COMMON
	return Weapon.new(WeaponDB.get_data(id), it)


func spawn_at(g: Vector2) -> void:
	gpos = g
	vel = Vector2.ZERO
	aim_target = g + Vector2(Iso.m(3.0), 0)
	position = Iso.to_screen(gpos)


func invulnerable() -> bool:
	return _iframes > 0.0 or not alive


func dashing() -> bool:
	return _dash_t > 0.0


## Where the dash animation is: 0..1 through the dash, past 1 for a short landing after
## it, -1 when not dashing.
func _dash_anim() -> float:
	if dashing():
		return 1.0 - _dash_t / DASH_TIME
	if _since_dash < DASH_LAND:
		return 1.0 + _since_dash / DASH_LAND
	return -1.0


## True while dashing or within `window` seconds after a dash ended.
func dash_recent(window: float) -> bool:
	return dashing() or _since_dash < window


func grant_iframes(t: float) -> void:
	_iframes = maxf(_iframes, t)


func cur_weapon() -> Weapon:
	return weapons[cur]


# ------------------------------------------------------------------ input

func _input_state() -> Dictionary:
	if input_override != null:
		return input_override.state(self)
	var s := {}
	s["move"] = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	s["stick"] = stick
	s["mouse"] = get_global_mouse_position()
	s["fire"] = Input.is_action_pressed("fire")
	s["fire_pressed"] = Input.is_action_just_pressed("fire")
	s["fire_released"] = Input.is_action_just_released("fire")
	s["alt"] = Input.is_action_pressed("alt_fire")
	s["alt_pressed"] = Input.is_action_just_pressed("alt_fire")
	s["melee_held"] = Input.is_action_pressed("melee")
	for a in ["dash", "ability_1", "ability_2", "melee", "reload", "weapon_1", "weapon_2", "weapon_3", "weapon_next", "weapon_prev"]:
		s[a] = Input.is_action_just_pressed(a)
	return s


# ------------------------------------------------------------------ update

func _process(dt: float) -> void:
	if not alive:
		visual.update_death(dt)
		return
	if get_tree().paused:
		return
	var s := _input_state()
	build.process(dt)
	_timers(dt)
	_update_aim(s)
	_update_move(s, dt)
	_update_weapons(s, dt)
	_update_abilities(s, dt)
	position = Iso.to_screen(gpos)
	visual.update(dt, vel, aim_dir, dashing(), _dash_anim())
	_hurt_flash = maxf(0.0, _hurt_flash - dt * 6.0)
	visual.set_flash(_hurt_flash * 0.8, Color(1.0, 0.25, 0.2))
	visual.modulate.a = 0.55 if _iframes > 0.0 and not dashing() and fmod(_iframes, 0.1) < 0.05 else 1.0
	Game.dungeon.update_flow(Iso.cell_of(gpos))


func _timers(dt: float) -> void:
	_iframes = maxf(0.0, _iframes - dt)
	_hurt_iframes = maxf(0.0, _hurt_iframes - dt)
	_swap_t = maxf(0.0, _swap_t - dt)
	_last_fire_t += dt
	_since_dash += dt
	if dash_charges < dash_max:
		_dash_recharge_t += dt
		if _dash_recharge_t >= DASH_RECHARGE:
			_dash_recharge_t = 0.0
			dash_charges += 1
			# a charge coming back: a quick cold glint at the feet
			VFX.burst_sprite(VFX.T.ring, Iso.to_screen(gpos), Color(0.6, 1.0, 2.2, 0.6),
				Vector2(0.15, 0.15 * Iso.K), Vector2(0.4, 0.4 * Iso.K), 0.18)
	if launcher.mag < launcher.s_mag:
		_launcher_t += dt
		if _launcher_t >= launcher.data.reload_time:
			_launcher_t = 0.0
			launcher.mag += 1
	_regen_delay -= dt
	if _regen_delay <= 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + 3.0 * dt)


func _update_aim(s: Dictionary) -> void:
	var stick: Vector2 = s.get("stick", Vector2.ZERO)
	var mz := visual.muzzle_m()
	if stick.length() > 0.35:
		var d := stick.normalized()
		aim_dir = _aim_assist(d)
		aim_target = gpos + aim_dir * Iso.m(9.0)
		return
	var mouse: Vector2 = s.get("mouse", position)
	# soft lock: cursor over an enemy body aims at that enemy
	var locked = null
	var best := 70.0
	for e in Game.grid.query(Iso.to_ground(mouse), Iso.m(2.5)):
		var c := Iso.lift(e.gpos, e.hit_height)
		var dd := c.distance_to(mouse)
		if dd < maxf(best, e.radius * 0.9) and dd < best:
			best = dd
			locked = e
	if locked == null and Game.dungeon:
		# breakable props too (nests, urns, amphorae): shots fly at muzzle height, so a cursor
		# on a low prop's body would otherwise send them past it on diagonal shots
		var best_p := 46.0
		for pr in Game.dungeon.props:
			if pr.alive and pr.destructible() and pr.gpos.distance_to(gpos) < Iso.m(16.0):
				var dd := Iso.lift(pr.gpos, 0.4).distance_to(mouse)
				if dd < best_p:
					best_p = dd
					locked = pr
	if locked:
		aim_target = locked.gpos
	else:
		aim_target = Iso.to_ground(mouse + Vector2(0, Iso.h(mz.z)))
	var to := aim_target - gpos
	if to.length() < Iso.m(0.6):
		return
	var d0 := to.normalized()
	var muzzle := gpos + d0 * Iso.m(mz.x) + Iso.left_of(d0) * Iso.m(mz.y)
	var to2 := aim_target - muzzle
	aim_dir = to2.normalized() if to2.length() > Iso.m(1.2) else d0


func _aim_assist(d: Vector2) -> Vector2:
	var best = null
	var best_a := 0.3
	for e in Game.grid.query(gpos, Iso.m(14.0)):
		var to: Vector2 = e.gpos - gpos
		var a := absf(d.angle_to(to))
		if a < best_a and Game.dungeon.has_los(gpos, e.gpos):
			best_a = a
			best = e
	return (best.gpos - gpos).normalized() if best else d


func _update_move(s: Dictionary, dt: float) -> void:
	var mv: Vector2 = s.get("move", Vector2.ZERO)
	_move_input = mv.limit_length(1.0)
	# buffered dash: a press during a dash (or just before a charge is back) still fires,
	# so dashes chain without frame-perfect timing
	if s.get("dash", false):
		_dash_buffer = DASH_BUFFER
	_dash_buffer -= dt
	if _dash_buffer > 0.0 and dash_charges > 0 and _dash_t <= 0.0:
		_dash_buffer = 0.0
		_start_dash()
	_update_streak()
	if _dash_t > 0.0:
		_dash_t -= dt
		# fast at first, easing at the end, so the dash snaps out and lands
		var k := 1.0 - _dash_t / DASH_TIME
		vel = _dash_dir * Iso.m(DASH_SPEED_M) * lerpf(1.25, 0.7, k)
		_afterimage_t -= dt
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.022
			VFX.afterimage(visual.sprites(), Color(1.5, 1.35, 1.25, 0.5), 0.26)
		if _dash_t <= 0.0:
			vel = _dash_dir * _max_speed() * DASH_CARRY
			_since_dash = 0.0
			VFX.emit("smoke", Iso.lift(gpos, 0.1), (_dash_dir).angle(), Color(0.45, 0.45, 0.48, 0.45), 0.3)
			build.on_dash(_dash_from, gpos)
			Events.dashed.emit(_dash_from, gpos)
	else:
		var target := _move_input * _max_speed()
		var spd := vel.length()
		if spd > _max_speed() * 1.02 and _move_input.length() > 0.3 and vel.normalized().dot(_move_input.normalized()) > 0.3:
			# riding the dash's momentum: steer it toward the stick, bleed the extra off gently
			var keep := move_toward(spd, _max_speed(), Iso.m(CARRY_DECAY_M) * dt)
			vel = vel.normalized().slerp(_move_input.normalized(), minf(1.0, dt * 9.0)) * keep
		else:
			var accel := Iso.m(ACCEL_M) if _move_input.length() > 0.05 else Iso.m(DECEL_M)
			if target.dot(vel) < 0.0:
				accel *= 1.7
			vel = vel.move_toward(target, accel * dt)
	_footsteps(dt)
	var motion := vel * dt + _extern_motion
	_extern_motion = Vector2.ZERO
	var before := gpos
	gpos = Game.dungeon.unstick(Game.dungeon.move_circle(gpos, motion, radius))
	if not dashing():
		_push_from_enemies(dt)
	if dt > 0.0 and motion.length() > 0.01:
		# kill velocity into walls so we slide instead of grinding
		var actual := (gpos - before) / dt
		if actual.length() < vel.length() * 0.5 and _dash_t <= 0.0:
			vel = vel.lerp(actual, 0.5)


func _footsteps(dt: float) -> void:
	if dashing() or vel.length() < Iso.m(SPEED_M * 0.6):
		_step_t = minf(_step_t, 0.05)
		return
	_step_t -= dt
	if _step_t <= 0.0:
		_step_t = STEP_T
		VFX.emit("puff", Iso.lift(gpos - vel.normalized() * Iso.m(0.2), 0.05), (-vel).angle(),
			Color(0.42, 0.42, 0.44, 0.3), 0.4)


func _max_speed() -> float:
	var w := cur_weapon()
	var m := 1.0
	if w and w.charging:
		m *= w.data.move_speed_mult
	return Iso.m(SPEED_M) * build.mult("move_speed_pct") * m


func _start_dash() -> void:
	dash_charges -= 1
	_dash_t = DASH_TIME
	_iframes = DASH_IFRAMES
	_dash_from = gpos
	_dash_dir = _move_input.normalized() if _move_input.length() > 0.1 else aim_dir
	_afterimage_t = 0.0
	Audio.play("dash", gpos, 0.0, randf_range(0.95, 1.08))
	var sdir := Iso.to_screen(_dash_dir).normalized()
	var feet := Iso.to_screen(gpos)
	# kick-off: dust thrown back, a flattened shock ring, a streak along the path
	VFX.emit("smoke", Iso.lift(gpos, 0.15), (-_dash_dir).angle(), Color(0.5, 0.5, 0.55, 0.55), 0.5)
	# a burst of golden spikes and sparks thrown back off the heels
	VFX.spikes(Iso.lift(gpos, 0.5), (-sdir).angle(), 0.9, 5, 95.0, Color(2.8, 2.1, 1.0, 0.9), 0.09)
	VFX.emit("sparks", Iso.lift(gpos, 0.3), (-sdir).angle(), Color(2.8, 2.0, 0.9), 0.5)
	VFX.burst_sprite(VFX.T.ring, feet, Color(1.6, 1.5, 1.4, 0.55), Vector2(0.12, 0.12 * Iso.K), Vector2(0.55, 0.55 * Iso.K), 0.2)
	VFX.burst_sprite(VFX.T.spark, feet + sdir * Iso.m(3.0) + Vector2(0, -Iso.h(0.9)), Color(1.4, 1.3, 1.2, 0.35),
		Vector2(1.0, 0.25), Vector2(Iso.m(6.0) / 32.0, 0.06), 0.22, true, sdir.angle())
	VFX.light_flash(Iso.lift(gpos, 1.0), Color(1.0, 0.8, 0.5), 1.6, 3.6, 0.18)
	VFX.flash_layer(VFX.T.star, Iso.lift(gpos, 0.9), sdir.angle(), Color(2.4, 2.0, 1.4, 0.8),
		Vector2(0.3, 0.2), Vector2(1.2, 0.5), 0.12)
	if VFX.camera:
		VFX.camera.punch(0.012)
		VFX.kick(sdir, 5.0)
	if VFX.post:
		VFX.post.shockwave(feet, 70.0, 0.2, 0.45)


## The golden light streak a dash leaves (it outlives the dash by a moment).
func _update_streak() -> void:
	if not is_instance_valid(_streak):
		if VFX.fx == null or not is_instance_valid(VFX.fx):
			return
		_streak = DashStreak.new()
		VFX.fx.add_child(_streak)
	_streak.feed(Iso.lift(gpos, 0.9), dashing())


## Killing on the move refunds a dash: aggression keeps you mobile.
func _on_enemy_killed(_e, _info) -> void:
	if not alive or dash_charges >= dash_max:
		return
	if dashing() or _since_dash < DASH_KILL_WINDOW:
		dash_charges += 1
		_dash_recharge_t = 0.0
		VFX.flash_layer(VFX.T.ring, Iso.to_screen(gpos), 0.0, Color(2.2, 1.7, 0.8, 0.8),
			Vector2(0.15, 0.15 * Iso.K), Vector2(0.6, 0.6 * Iso.K), 0.22)


func _push_from_enemies(_dt: float) -> void:
	for e in Game.grid.query(gpos, radius + Iso.m(0.2)):
		var d: Vector2 = gpos - e.gpos
		var l := d.length()
		var rr: float = radius + e.radius * 0.8
		if l < rr and l > 0.01:
			var heavy: float = 0.6 if e.data.mass >= 3.0 else 0.25
			gpos = Game.dungeon.resolve(gpos + d / l * (rr - l) * heavy, radius)


func external_motion(m: Vector2) -> void:
	_extern_motion += m


# ------------------------------------------------------------------ weapons

func _update_weapons(s: Dictionary, dt: float) -> void:
	var want := -1
	if s.get("weapon_1", false): want = 0
	if s.get("weapon_2", false): want = 1
	if s.get("weapon_3", false): want = 2
	if s.get("weapon_next", false): want = (cur + 1) % 3
	if s.get("weapon_prev", false): want = (cur + 2) % 3
	if want >= 0 and want != cur and weapons[want] != null:
		switch_weapon(want)
	if s.get("reload", false) and cur_weapon():
		cur_weapon().start_reload(self)
	var can_fire := _swap_t <= 0.0 and not dashing() and not blade.blocks_fire()
	for i in 3:
		var w: Weapon = weapons[i]
		if w == null:
			continue
		var active := i == cur
		w.update(dt, self, s.get("fire", false) and can_fire and active, s.get("fire_pressed", false) and can_fire and active,
			s.get("fire_released", false) and active, active)
	launcher.update(dt, self, false, s.get("alt_pressed", false) and not dashing(), false, true)


func switch_weapon(i: int) -> void:
	var old := cur_weapon()
	if old:
		old.charging = false
		if old.reloading and not old.data.reload_per_round:
			old.reloading = false
	cur = i
	_swap_t = 0.12
	visual.set_torso(weapons[i].data.torso)
	Audio.play("reload", gpos, -4.0, 1.3)
	Events.weapon_switched.emit(i)


func on_weapon_fired(w: Weapon, charge: float) -> void:
	_last_fire_t = 0.0
	visual.fired()
	visual.muzzle_alt = not visual.muzzle_alt
	visual.kick(w.data.recoil_kick * (0.5 + charge * 0.5), aim_dir)
	VFX.shake(w.data.shake * (0.5 + charge * 0.5))
	VFX.kick(Iso.to_screen(aim_dir).normalized(), w.data.recoil_kick * 0.6)
	if w.data.hitstop > 0.0 and charge > 0.9:
		Game.hit_stop(w.data.hitstop)
	if w.data.pellets > 1:
		external_motion(-aim_dir * Iso.m(0.08))


func muzzle_ground() -> Vector2:
	var mz := visual.muzzle_m()
	return gpos + aim_dir * Iso.m(mz.x) + Iso.left_of(aim_dir) * Iso.m(mz.y)


func muzzle_height() -> float:
	return visual.muzzle_m().z


func muzzle_screen() -> Vector2:
	return Iso.lift(muzzle_ground(), muzzle_height()) + visual.torso_offset


func ammo_need() -> float:
	var need := 0.0
	for k in AMMO_MAX:
		need += 1.0 - float(ammo[k]) / AMMO_MAX[k]
	return need / AMMO_MAX.size()


func add_ammo_fraction(f: float) -> void:
	for k in AMMO_MAX:
		ammo[k] = mini(AMMO_MAX[k], ammo[k] + int(ceil(AMMO_MAX[k] * f)))
	VFX.popup(gpos, 2.0, "+AMMO", Color(1.0, 0.8, 0.3), 22)
	Events.ammo_changed.emit()


# ------------------------------------------------------------------ abilities

func _update_abilities(s: Dictionary, dt: float) -> void:
	for a in abilities:
		a.process(dt, self)
	if s.get("ability_1", false):
		abilities[0].try_use(self)
	if s.get("ability_2", false):
		abilities[1].try_use(self)
	blade.process(dt, self)
	blade.input(self, s.get("melee", false), s.get("melee_held", false))


func reset_cooldowns() -> void:
	for a in abilities:
		a.cd_left = 0.0
	blade.cd_left = 0.0


# ------------------------------------------------------------------ health

func take_damage(info: DamageInfo) -> void:
	if not alive or invulnerable():
		return
	if _hurt_iframes > 0.0 and not info.is_dot:
		return
	var amt := info.amount * 100.0 / (100.0 + build.stat("armor")) * Game.damage_taken_mult
	hp -= amt
	_hurt_flash = 1.0
	if info.direction.length() > 0.1:
		_last_hit_dir = info.direction
	_regen_delay = 4.0
	if not info.is_dot:
		visual.hit(info.direction, amt)
		_hurt_iframes = 0.12 if amt < 20.0 else 0.35
		vel += info.direction * info.knockback * 0.6
		Audio.play("player_hurt", gpos)
		VFX.shake(clampf(0.15 + amt / 60.0, 0.15, 0.6))
		if VFX.post:
			VFX.post.damage_pulse(clampf(amt / 35.0, 0.25, 1.0))
		if amt >= 20.0:
			Game.hit_stop(0.06, 0.1, true)
	Events.player_damaged.emit(info, amt)
	if hp <= 0.0:
		_die()


func heal(amount: float, show := true) -> void:
	if not alive:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show and hp - before >= 1.0:
		VFX.popup(gpos, 2.1, "+%d" % int(hp - before), Color(0.4, 1.0, 0.45), 24)
	Events.player_healed.emit(hp - before)


func _die() -> void:
	alive = false
	hp = 0.0
	blade.cancel()
	VFX.gore(gpos, Color(0.8, 0.1, 0.1), 2.0)
	VFX.ring(gpos, Iso.m(2.5), Color(1.0, 0.3, 0.2), 0.4)
	# he falls over backward, away from the killing blow, in slow motion
	visual.play_death(-_last_hit_dir if _last_hit_dir.length() > 0.1 else aim_dir)
	Game.hit_stop(0.25, 0.05, true)
	Game.slowmo(0.9, 0.35)
	Events.player_died.emit()


## Dev (--die-at): drop dead now, knocked along `push`.
func dev_kill(push: Vector2) -> void:
	if alive:
		_last_hit_dir = push
		_die()


func revive(g: Vector2) -> void:
	alive = true
	hp = max_hp
	visual.revived()
	_iframes = 2.0
	_last_hit_dir = Vector2.ZERO
	spawn_at(g)
	VFX.ring(gpos, Iso.m(3.0), Color(0.5, 0.8, 1.0), 0.5)


# ------------------------------------------------------------------ progression

func add_xp(n: int) -> void:
	xp += n
	Events.xp_gained.emit(n)
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(70.0 * pow(level, 1.45))
		build.attr_points += 2
		build.recalc()
		on_stats_changed()
		hp = max_hp
		_level_up_fx()
		Events.level_up.emit(level)


func _level_up_fx() -> void:
	Audio.play("level_up")
	VFX.ring(gpos, Iso.m(5.0), Color(1.0, 0.8, 0.35), 0.6, 0.05)
	VFX.light_flash(Iso.lift(gpos, 1.2), Color(1.0, 0.85, 0.4), 4.0, 6.0, 0.8)
	VFX.popup(gpos, 2.6, "LEVEL %d" % level, Color(1.0, 0.85, 0.35), 40)
	VFX.screen_flash(Color(1.0, 0.85, 0.4, 0.15), 0.2)
	for e in Game.grid.query(gpos, Iso.m(4.0)):
		var d := DamageInfo.make(1.0, DamageInfo.Type.VOID, self)
		d.direction = (e.gpos - gpos).normalized()
		d.knockback = Iso.m(10.0)
		d.stagger = 60.0
		e.take_damage(d)


func on_stats_changed() -> void:
	var old_max := max_hp
	max_hp = 120.0 + build.stat("max_hp")
	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	dash_max = 2 + int(build.stat("dash_charges"))


# ------------------------------------------------------------------ inventory

func inventory_add(it: Item) -> bool:
	# fill empty slots first so new players feel the upgrade immediately
	if not it.is_weapon() and gear[it.kind] == null:
		equip(it)
		_announce(it, true)
		return true
	if backpack.size() >= BACKPACK_SIZE:
		VFX.popup(gpos, 2.2, "INVENTORY FULL", Color(1, 0.4, 0.3), 22)
		return false
	backpack.append(it)
	_announce(it, false)
	return true


func _announce(it: Item, equipped: bool) -> void:
	VFX.popup(gpos, 2.3, ("EQUIPPED " if equipped else "") + it.display_name(), it.color(), 24)
	Events.item_picked.emit(it)
	Events.inventory_changed.emit()


## Equip an item from the backpack. Weapons replace the active slot unless `slot` is given.
func equip(it: Item, slot := -1) -> void:
	backpack.erase(it)
	if it.is_weapon():
		var i := cur if slot < 0 else slot
		var old: Weapon = weapons[i]
		if old and old.item:
			backpack.append(old.item)
		var w := Weapon.new(WeaponDB.get_data(it.base_id), it)
		weapons[i] = w
		if i == cur:
			visual.set_torso(w.data.torso)
	else:
		var old_it = gear[it.kind]
		if old_it:
			backpack.append(old_it)
		gear[it.kind] = it
	build.recalc()
	on_stats_changed()
	Events.inventory_changed.emit()


func salvage(it: Item) -> void:
	backpack.erase(it)
	add_xp(4 * (it.rarity + 1) * it.level)
	Events.inventory_changed.emit()
