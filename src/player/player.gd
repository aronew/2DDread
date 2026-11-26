class_name Player
extends Node2D
## The hunter. Fast, momentum-preserving movement, dash with i-frames,
## twin-stick aim (mouse or right stick with aim assist), 3 primary weapons +
## Havoc launcher on RMB, Q/E abilities, F melee/execute.

const SPEED_M := 6.6
const ACCEL_M := 75.0
const DECEL_M := 60.0
const DASH_SPEED_M := 25.0
const DASH_TIME := 0.15
const DASH_IFRAMES := 0.24
const DASH_RECHARGE := 0.95
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
var rend: Rend

var dash_charges := 2
var dash_max := 2
var _dash_recharge_t := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _dash_from := Vector2.ZERO
var _iframes := 0.0
var _hurt_iframes := 0.0
var _hurt_flash := 0.0
var _regen_delay := 0.0
var _swap_t := 0.0
var _launcher_t := 0.0
var _afterimage_t := 0.0
var _last_fire_t := 0.0
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
	rend = Rend.new()
	build.recalc()
	on_stats_changed()
	hp = max_hp
	visual.set_torso(weapons[cur].data.torso)


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
	for a in ["dash", "ability_1", "ability_2", "melee", "reload", "weapon_1", "weapon_2", "weapon_3", "weapon_next", "weapon_prev"]:
		s[a] = Input.is_action_just_pressed(a)
	return s


# ------------------------------------------------------------------ update

func _process(dt: float) -> void:
	if not alive:
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
	visual.update(dt, vel, aim_dir, dashing())
	_hurt_flash = maxf(0.0, _hurt_flash - dt * 6.0)
	visual.set_flash(_hurt_flash * 0.8, Color(1.0, 0.25, 0.2))
	visual.modulate.a = 0.55 if _iframes > 0.0 and not dashing() and fmod(_iframes, 0.1) < 0.05 else 1.0
	Game.dungeon.update_flow(Iso.cell_of(gpos))


func _timers(dt: float) -> void:
	_iframes = maxf(0.0, _iframes - dt)
	_hurt_iframes = maxf(0.0, _hurt_iframes - dt)
	_swap_t = maxf(0.0, _swap_t - dt)
	_last_fire_t += dt
	if dash_charges < dash_max:
		_dash_recharge_t += dt
		if _dash_recharge_t >= DASH_RECHARGE:
			_dash_recharge_t = 0.0
			dash_charges += 1
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
	if s.get("dash", false) and dash_charges > 0 and _dash_t <= 0.0:
		_start_dash()
	if _dash_t > 0.0:
		_dash_t -= dt
		vel = _dash_dir * Iso.m(DASH_SPEED_M)
		_afterimage_t -= dt
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.03
			VFX.afterimage(visual.sprites(), Color(0.5, 0.75, 2.2, 0.55))
		if _dash_t <= 0.0:
			vel = _dash_dir * _max_speed()
			build.on_dash(_dash_from, gpos)
			Events.dashed.emit(_dash_from, gpos)
	else:
		var target := _move_input * _max_speed()
		var accel := Iso.m(ACCEL_M) if _move_input.length() > 0.05 else Iso.m(DECEL_M)
		if target.dot(vel) < 0.0:
			accel *= 1.7
		vel = vel.move_toward(target, accel * dt)
	var motion := vel * dt + _extern_motion
	_extern_motion = Vector2.ZERO
	var before := gpos
	gpos = Game.dungeon.move_circle(gpos, motion, radius)
	if not dashing():
		_push_from_enemies(dt)
	if dt > 0.0 and motion.length() > 0.01:
		# kill velocity into walls so we slide instead of grinding
		var actual := (gpos - before) / dt
		if actual.length() < vel.length() * 0.5 and _dash_t <= 0.0:
			vel = vel.lerp(actual, 0.5)


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
	Audio.play("dash", gpos)
	VFX.emit("smoke", Iso.lift(gpos, 0.2), (-_dash_dir).angle(), Color(0.5, 0.55, 0.65, 0.5), 0.35)
	VFX.light_flash(Iso.lift(gpos, 1.0), Color(0.4, 0.6, 1.0), 1.4, 3.0, 0.2)


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
	var can_fire := _swap_t <= 0.0 and not dashing()
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
	rend.process(dt, self)
	if s.get("ability_1", false):
		abilities[0].try_use(self)
	if s.get("ability_2", false):
		abilities[1].try_use(self)
	if s.get("melee", false):
		rend.try_use(self)


func reset_cooldowns() -> void:
	for a in abilities:
		a.cd_left = 0.0


# ------------------------------------------------------------------ health

func take_damage(info: DamageInfo) -> void:
	if not alive or invulnerable():
		return
	if _hurt_iframes > 0.0 and not info.is_dot:
		return
	var amt := info.amount * 100.0 / (100.0 + build.stat("armor")) * Game.damage_taken_mult
	hp -= amt
	_hurt_flash = 1.0
	_regen_delay = 4.0
	if not info.is_dot:
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
	VFX.gore(gpos, Color(0.8, 0.1, 0.1), 2.0)
	VFX.explosion(gpos, Iso.m(2.0), Color(0.4, 0.6, 1.0), false)
	visual.visible = false
	Game.hit_stop(0.25, 0.05, true)
	Events.player_died.emit()


func revive(g: Vector2) -> void:
	alive = true
	hp = max_hp
	visual.visible = true
	_iframes = 2.0
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
