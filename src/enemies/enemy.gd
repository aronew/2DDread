class_name Enemy
extends Node2D
## Base enemy: body, steering, damage model (armour arcs, weak points, shields),
## stagger, knockback, status effects, telegraphed attack state machine,
## death dissolve. Subclasses implement think() and the attack itself.

enum S { SPAWN, CHASE, WINDUP, ATTACK, RECOVER, STAGGER, DEAD }

const SHEET_DIR := "res://assets/sprites/enemies/"
const NOISE := preload("res://src/vfx/noise_tex.tres")

var data: EnemyData
var gpos := Vector2.ZERO
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var facing := Vector2.DOWN
var radius := 30.0
var hit_height := 0.5
var alive := true
var is_enemy := true
var no_loot := false
var armor_hp := 0.0          # destructible frontal plating (0 = none / broken)
var hp := 10.0
var max_hp := 10.0
var dmg_mult := 1.0
var speed_mult := 1.0
var cd_mult := 1.0
var is_elite := false
var affixes: Array = []
var shield := 0.0
var shield_max := 0.0
var blood_color := Color.RED
var impact_style := "flesh"

var state: int = S.SPAWN
var state_t := 0.0
var attack_cd := 0.0
var stagger_meter := 0.0
var status := {}
var telegraph: Telegraph
var room = null

var body: Sprite2D
var glow: Sprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var overlay: EnemyOverlay
var _sheet_move
var _sheet_attack
var _anim_phase := 0.0
var _attack_frame := -1.0
var _flash := 0.0
var _show_bar_t := 0.0
var _dissolve := 0.0
var _spawn_dur := 0.55
var _shock_arc_t := 0.0
var _shield_regen_t := 0.0
var _rng_offset := randf() * 100.0
var _flank := 0.0
var _affix_t := 0.0
var yank_to := Vector2.ZERO   # whip drag destination (Lash keeps it next to the player)
var _yank_t := 0.0


func setup(d: EnemyData, g: Vector2, opts := {}) -> void:
	data = d
	gpos = g
	radius = Iso.m(d.radius_m)
	hit_height = d.hit_height_m
	max_hp = d.max_hp * Game.depth_hp_mult()
	dmg_mult = Game.depth_dmg_mult()
	blood_color = d.blood_color
	impact_style = d.impact_style
	_flank = randf_range(-1.0, 1.0)
	if opts.has("elite"):
		Elite.apply(self, opts["elite"])
	hp = max_hp
	if d.front_armor > 0.0:
		armor_hp = max_hp * 0.45
	if opts.get("from_nest", false):
		_spawn_dur = 0.3
	position = Iso.to_screen(g)


func _ready() -> void:
	_sheet_move = SheetDB.get_sheet(SHEET_DIR + data.sheet_move)
	_sheet_attack = SheetDB.get_sheet(SHEET_DIR + data.sheet_attack)
	var vs: float = data.visual_scale * (1.22 if is_elite else 1.0)
	shadow = VFX.make_shadow(radius * 1.25)
	add_child(shadow)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://src/vfx/shaders/entity.gdshader")
	mat.set_shader_parameter("noise_tex", NOISE)
	mat.set_shader_parameter("noise_scale", Vector2(_sheet_move.cols, _sheet_move.rows) * 2.5)
	mat.set_shader_parameter("dissolve_color", blood_color)
	body = Sprite2D.new()
	body.texture = _sheet_move.tex
	body.region_enabled = true
	body.offset = _sheet_move.offset()
	body.material = mat
	body.self_modulate = data.body_tint
	body.scale = Vector2(vs, vs)
	add_child(body)
	glow = Sprite2D.new()
	glow.region_enabled = true
	glow.scale = body.scale
	add_child(glow)
	overlay = EnemyOverlay.new()
	overlay.enemy = self
	add_child(overlay)
	_set_sheet(_sheet_move)
	if is_elite:
		Elite.decorate(self)
	_spawn_fx()
	Game.register_enemy(self)
	Events.enemy_spawned.emit(self)
	_update_visual(0.0)


func _set_sheet(sh) -> void:
	if body.texture == sh.tex:
		return
	body.texture = sh.tex
	body.offset = sh.offset()
	glow.texture = GlowMat.glow_texture(sh)
	glow.offset = sh.offset()
	glow.material = GlowMat.get_mat(sh, rim_color())
	mat.set_shader_parameter("noise_scale", Vector2(sh.cols, sh.rows) * 2.5)


func rim_color() -> Color:
	return Color(1.0, 0.72, 0.25, 0.9) if is_elite else Color(1.0, 0.22, 0.15, 0.62)


func _spawn_fx() -> void:
	state = S.SPAWN
	state_t = 0.0
	# portal-violet so spawns never read as attack telegraphs (those are red)
	var pc := Color(0.35, 1.0, 0.6) if not is_elite else Color(1.0, 0.7, 0.2)
	VFX.ring(gpos, radius * 1.6, pc * 0.7, 0.45, 0.2)
	VFX.emit("embers", Iso.lift(gpos, 0.2), -PI / 2, pc * 1.6, 0.25)
	Audio.play("spawn", gpos)


# ------------------------------------------------------------------ frame

func _process(dt: float) -> void:
	if state == S.DEAD:
		_dissolve = minf(1.0, _dissolve + dt / 0.45)
		mat.set_shader_parameter("dissolve", _dissolve)
		glow.modulate.a = maxf(0.0, 1.0 - _dissolve * 3.0)
		shadow.modulate.a = 0.75 * (1.0 - _dissolve)
		if _dissolve >= 1.0:
			Game.unregister_enemy(self)
			queue_free()
		return
	state_t += dt
	attack_cd -= dt
	_process_status(dt)
	stagger_meter = maxf(0.0, stagger_meter - data.stagger_threshold * 0.25 * dt)
	if is_elite:
		Elite.process(self, dt)
	match state:
		S.SPAWN:
			var k := clampf(state_t / _spawn_dur, 0.0, 1.0)
			mat.set_shader_parameter("dissolve", 1.0 - k)
			if k >= 1.0:
				mat.set_shader_parameter("dissolve", 0.0)
				state = S.CHASE
				state_t = 0.0
		S.STAGGER:
			if _yank_t > 0.0:
				# dragged by the whip: arrive exactly when the drag ends, then stop dead
				_yank_t -= dt
				var to := yank_to - gpos
				vel = (to / maxf(_yank_t, dt)).limit_length(Iso.m(45.0)) if _yank_t > 0.0 else Vector2.ZERO
			else:
				vel = vel.move_toward(Vector2.ZERO, Iso.m(30.0) * dt)
			if state_t >= data.stagger_time:
				state = S.CHASE
				state_t = 0.0
		_:
			think(dt)
	_integrate(dt)
	_update_visual(dt)


## Override: decide movement + attacks. Called in CHASE/WINDUP/ATTACK/RECOVER.
func think(_dt: float) -> void:
	pass


func player():
	var p = Game.player
	return p if p and p.alive else null


func dist_to_player() -> float:
	var p = player()
	return gpos.distance_to(p.gpos) if p else INF


func move_speed() -> float:
	var s := Iso.m(data.speed_m) * speed_mult
	if status.has(&"shock"):
		s *= 0.72
	return s


## Steer toward a ground point: straight when there is a clear walk line,
## flow field around obstacles otherwise.
func steer_to(target: Vector2, speed: float, dt: float) -> void:
	var dir := Vector2.ZERO
	var to := target - gpos
	if to.length() < 4.0:
		dir = Vector2.ZERO
	elif data.flying or not Game.dungeon.raycast(gpos, target, "walk").hit:
		dir = to.normalized()
	else:
		dir = Game.dungeon.flow_dir(gpos)
		if dir == Vector2.ZERO:
			dir = to.normalized()
	desire(dir * speed, dt)


func desire(v: Vector2, dt: float) -> void:
	vel = vel.move_toward(v, Iso.m(data.accel_m) * dt)


func turn_toward(dir: Vector2, dt: float, rate := -1.0) -> void:
	if dir.length() < 0.01:
		return
	var r := data.turn_rate if rate < 0.0 else rate
	var a := facing.angle_to(dir.normalized())
	facing = facing.rotated(clampf(a, -r * dt, r * dt)).normalized()


func _integrate(dt: float) -> void:
	# separation from other enemies (soft, keeps swarms from stacking)
	var sep := Vector2.ZERO
	for o in Game.grid.query(gpos, radius * 1.6):
		if o == self:
			continue
		var d: Vector2 = gpos - o.gpos
		var l := d.length()
		var rr: float = (radius + o.radius) * 0.9
		if l < rr:
			var push := (rr - l) / rr
			sep += (d / maxf(l, 0.01) if l > 0.01 else Vector2.from_angle(_rng_offset)) * push * (o.data.mass / (o.data.mass + data.mass))
	var motion := (vel + knock) * dt + sep * Iso.m(5.0) * dt
	var before := gpos
	gpos = Game.dungeon.move_circle(gpos, motion, radius, data.flying)
	if knock.length() > 1.0 and (gpos - before).length() < (knock * dt).length() * 0.3:
		on_wall_impact(knock)
		knock *= 0.2
	knock = knock.move_toward(Vector2.ZERO, Iso.m(55.0) * dt * maxf(1.0, data.mass * 0.6))
	position = Iso.to_screen(gpos)


func on_wall_impact(_k: Vector2) -> void:
	pass


# ------------------------------------------------------------------ visuals

var _params := {}


func _set_param(n: String, v) -> void:
	if _params.get(n) != v:
		_params[n] = v
		mat.set_shader_parameter(n, v)


func _update_visual(dt: float) -> void:
	var d := Iso.dir_index(facing, 16)
	if _attack_frame >= 0.0:
		_set_sheet(_sheet_attack)
		var f: int = clampi(int(_attack_frame * _sheet_attack.cols), 0, _sheet_attack.cols - 1)
		body.region_rect = _sheet_attack.region(d, f)
	else:
		_set_sheet(_sheet_move)
		var spd := vel.length() / Iso.PX_PER_M
		_anim_phase = fposmod(_anim_phase + spd * dt / data.stride_m, 1.0)
		var f: int = int(_anim_phase * _sheet_move.cols) % _sheet_move.cols
		body.region_rect = _sheet_move.region(d, f)
	glow.region_rect = body.region_rect
	_flash = maxf(0.0, _flash - dt * 9.0)
	var fl := _flash
	if state == S.STAGGER:
		fl = maxf(fl, 0.25 + 0.2 * sin(state_t * 30.0))
	_set_param("flash", snappedf(fl, 0.02))
	var tint_a := 0.0
	var tint_c := Color.WHITE
	if status.has(&"shock"):
		tint_a = 0.45
		tint_c = Color(0.5, 0.7, 1.0)
	elif status.has(&"burn"):
		tint_a = 0.4
		tint_c = Color(1.0, 0.5, 0.2)
	if state == S.WINDUP:
		tint_a = maxf(tint_a, 0.35 + 0.3 * sin(state_t * 40.0))
		tint_c = Color(1.0, 0.25, 0.2)
	_set_param("tint_amount", snappedf(tint_a, 0.02))
	_set_param("tint", tint_c)
	_show_bar_t -= dt
	var show_ov := is_elite or _show_bar_t > 0.0
	if show_ov or overlay.visible:
		overlay.visible = show_ov
		overlay.queue_redraw()


## Animate the attack sheet: k in [0,1], or -1 to return to locomotion.
func set_attack_frame(k: float) -> void:
	_attack_frame = k


# ------------------------------------------------------------------ attacks

func begin_windup(dur: float) -> void:
	state = S.WINDUP
	state_t = 0.0
	_attack_frame = 0.0


func enter(s: int) -> void:
	state = s
	state_t = 0.0


func clear_telegraph() -> void:
	if telegraph and is_instance_valid(telegraph):
		telegraph.cancel()
	telegraph = null


func hurt_player(amount: float, dir: Vector2, knock_m: float, type := DamageInfo.Type.PHYSICAL) -> void:
	var p = player()
	if p == null:
		return
	var d := DamageInfo.make(amount * dmg_mult, type, self)
	d.direction = dir
	d.knockback = Iso.m(knock_m)
	p.take_damage(d)


# ------------------------------------------------------------------ damage

func staggered() -> bool:
	return state == S.STAGGER


func take_damage(info: DamageInfo) -> float:
	if not alive:
		return 0.0
	var amt := info.amount
	var weak := false
	var deflect := false
	if data.front_armor > 0.0 and not info.is_dot and not info.is_explosion and info.direction != Vector2.ZERO:
		var face_dot := facing.dot(-info.direction)
		if face_dot > 0.45 and state != S.STAGGER and armor_hp > 0.0:
			armor_hp -= amt * data.front_armor
			amt *= 1.0 - data.front_armor
			deflect = true
			if armor_hp <= 0.0:
				_armor_shattered()
		elif face_dot < -0.3:
			amt *= data.back_mult
			weak = true
	if status.has(&"shock"):
		amt *= 1.2
		_shock_arc(info, amt)
	if shield > 0.0:
		var absorbed := minf(shield, amt)
		shield -= absorbed
		amt -= absorbed
		_shield_regen_t = 4.0
		if shield <= 0.0:
			Elite.shield_broken(self)
	hp -= amt
	_flash = 1.0 if not info.is_dot else maxf(_flash, 0.35)
	_show_bar_t = 3.0
	if info.knockback > 0.0 and info.direction != Vector2.ZERO:
		var kb := info.knockback / maxf(0.3, data.mass)
		if state == S.STAGGER:
			kb *= 1.3
		knock += info.direction * kb
	if not info.is_dot:
		stagger_meter += info.stagger * (1.5 if weak else 1.0)
		if stagger_meter >= data.stagger_threshold * (2.0 if is_elite else 1.0) and state != S.STAGGER:
			_stagger()
	for s in info.status:
		if randf() < info.status[s]:
			apply_status(s, info)
	var col := info.color()
	if deflect:
		col = Color(0.6, 0.6, 0.65)
		VFX.impact(info.hit_pos if info.hit_pos != Vector2.ZERO else gpos, hit_height, -info.direction, "armor")
		Audio.play("impact_armor", gpos)
	elif weak:
		col = Color(1.0, 0.85, 0.3)
	if amt >= 0.5 or info.crit:
		VFX.damage_number(gpos, hit_height + 0.5 * data.visual_scale + (0.3 if is_elite else 0.0), amt, info.crit or weak, col)
	if not info.is_dot and not deflect:
		Audio.play("impact_flesh", gpos)
	Events.enemy_damaged.emit(self, info, amt)
	if hp <= 0.0:
		die(info)
	return amt


func _armor_shattered() -> void:
	armor_hp = 0.0
	VFX.popup(gpos, hit_height + 1.4, "ARMOR SHATTERED", Color(1.0, 0.8, 0.4), 30)
	VFX.debris(gpos + facing * radius, 2.0, 24)
	VFX.emit("sparks", Iso.lift(gpos + facing * radius, hit_height), Iso.to_screen(facing).angle(), Color(3.0, 2.4, 1.6), 1.0)
	Audio.play("wall_break", gpos, -4.0, 1.3)
	VFX.shake(0.35)
	Game.hit_stop(0.06, 0.08, true)
	mat.set_shader_parameter("dissolve_color", Color(1.0, 0.5, 0.2))
	_stagger()


func _stagger() -> void:
	stagger_meter = 0.0
	clear_telegraph()
	_attack_frame = -1.0
	enter(S.STAGGER)
	if is_elite or data.stagger_threshold >= 60.0:
		VFX.popup(gpos, hit_height + 1.0, "STAGGERED", Color(1.0, 0.75, 0.3), 22)
	on_staggered()


func on_staggered() -> void:
	pass


## Whip drag: pulled to `to` over `dur` seconds, any attack interrupted, then
## dazed for `daze` seconds (counts as staggered, like any other stun).
func yank(to: Vector2, dur: float, daze: float) -> void:
	if not alive:
		return
	yank_to = to
	_yank_t = dur
	knock = Vector2.ZERO
	stagger_meter = 0.0
	clear_telegraph()
	_attack_frame = -1.0
	enter(S.STAGGER)
	state_t = data.stagger_time - (dur + daze)


## Whip yank on a heavy's front: tears the tower shield aside. Costs plating and
## exposes the body for `expose` seconds (no frontal armour while staggered).
func wrench_shield(frac: float, expose: float) -> void:
	if not alive or armor_hp <= 0.0:
		return
	armor_hp -= max_hp * 0.45 * frac
	if armor_hp <= 0.0:
		_armor_shattered()
		return
	VFX.popup(gpos, hit_height + 1.4, "SHIELD WRENCHED", Color(1.0, 0.8, 0.4), 26)
	VFX.emit("sparks", Iso.lift(gpos + facing * radius, hit_height), Iso.to_screen(facing).angle(), Color(3.0, 2.4, 1.6), 0.7)
	Audio.play("impact_armor", gpos)
	_flash = 1.0
	_show_bar_t = 3.0
	stagger_meter = 0.0
	clear_telegraph()
	_attack_frame = -1.0
	enter(S.STAGGER)
	state_t = data.stagger_time - expose


func apply_status(s: StringName, info: DamageInfo) -> void:
	match s:
		&"burn":
			if is_elite and &"molten" in affixes:
				return
			status[&"burn"] = {"t": 3.0, "tick": 0.0, "dps": maxf(6.0, info.amount * 0.35) * (1.0 if info.source != Game.player else Game.player.build.mult("ability_power_pct")), "src": info.source}
		&"shock":
			if not status.has(&"shock"):
				Audio.play("shock_zap", gpos)
			status[&"shock"] = {"t": 3.0}
	Events.status_applied.emit(self, s)


func _process_status(dt: float) -> void:
	if status.has(&"burn"):
		var b: Dictionary = status[&"burn"]
		b["t"] -= dt
		b["tick"] -= dt
		if b["tick"] <= 0.0:
			b["tick"] = 0.5
			var d := DamageInfo.make(b["dps"] * 0.5, DamageInfo.Type.FIRE, b["src"])
			d.is_dot = true
			d.hit_pos = gpos
			if b["src"] == Game.player:
				Combat.hit_enemy(self, d)
			else:
				take_damage(d)
			if not alive:
				return
			VFX.emit("embers", Iso.lift(gpos, hit_height), -PI / 2, Color(3.0, 1.4, 0.4), 0.12)
		if b["t"] <= 0.0:
			status.erase(&"burn")
	if status.has(&"shock"):
		status[&"shock"]["t"] -= dt
		_shock_arc_t -= dt
		if _shock_arc_t <= 0.0:
			_shock_arc_t = randf_range(0.25, 0.6)
			var a := Iso.lift(gpos, hit_height) + Vector2(randf_range(-20, 20), randf_range(-30, 10))
			VFX.lightning(a, a + Vector2(randf_range(-40, 40), randf_range(-40, 20)), Color(1.2, 1.6, 4.0), 2.0, 0.08, 1.5)
		if status[&"shock"]["t"] <= 0.0:
			status.erase(&"shock")


## Shocked enemies leak a share of incoming damage to a nearby shocked ally.
func _shock_arc(info: DamageInfo, amt: float) -> void:
	if info.proc_depth > 1 or info.is_dot or randf() > 0.3:
		return
	for o in Game.grid.query(gpos, Iso.m(3.5)):
		if o != self and o.status.has(&"shock"):
			var d := info.copy()
			d.amount = amt * 0.35
			d.type = DamageInfo.Type.SHOCK
			d.proc_depth += 1
			d.knockback = 0.0
			d.status = {}
			VFX.lightning(Iso.lift(gpos, hit_height), Iso.lift(o.gpos, o.hit_height), Color(1.2, 1.6, 4.0), 2.5, 0.1)
			o.take_damage(d)
			return


func die(info: DamageInfo) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	state = S.DEAD
	clear_telegraph()
	_attack_frame = -1.0
	var big := data.death_size >= 2.0 or is_elite
	var size := data.death_size * (1.4 if info.crit or info.is_explosion or info.execute else 1.0) * (1.3 if is_elite else 1.0)
	VFX.gore(gpos, blood_color, size, info.direction)
	VFX.light_flash(Iso.lift(gpos, hit_height), blood_color, 1.6 if not big else 3.0, 2.0 + size, 0.3)
	Audio.play("enemy_death_big" if big else "enemy_death", gpos)
	if big:
		VFX.shake(0.4)
		Game.hit_stop(0.09 if is_elite else 0.06, 0.05, is_elite)
	elif info.crit:
		Game.hit_stop(0.03, 0.15)
	if not no_loot:
		Loot.drop_from_enemy(self)
	Events.enemy_killed.emit(self, info)
	if is_elite:
		Elite.on_death(self)
	on_death(info)


func on_death(_info: DamageInfo) -> void:
	pass
