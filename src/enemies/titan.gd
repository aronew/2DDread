class_name Titan
extends Enemy
## ARACHNE, THE TITAN WEAVER: the temple dungeon's boss (room 7, the arena), after the
## owner's own design: a colossal purple spider with magenta cracks, huge ivory tusks and
## yellow-gold plates on its back. Its masked front is plated (front_armor, breakable like
## the Legionnaire's shield) and it turns slowly; the amber heart glowing out of its rear
## is the weak point (back_mult). So the fight is about moving: dodge around it, bait its
## charge into a pillar, shoot the heart.
##
## Every attack is telegraphed (guardrail):
##   Stomp   close: rears up, a red circle in front of it, slams down.
##   Charge  mid range: a red lane across the arena, then it runs it down; a wall or pillar
##           in the way stuns it (STUNNED, a long stagger: free hits on the heart).
##   Volley  range: fans of magenta venom shards, three to five in a row.
##   Nova    phase 2+: a red circle under it and a roar, then a ring of magenta fire races
##           out across the arena (SoulRing): dash through it (i-frames) or outrun it.
##   Brood   rears up and births spiderlings (tiny copies of itself), and from phase 2
##           Flaming Skulls, out of its abdomen.
##   Mortar  spits venom globs that arc onto red circles at and around the player and
##           leave burning venom pools.
##   Spiral  phase 2+: spins in place spraying shards in rotating arms (bullet storm).
## Stomps and crashes shake rocks loose from the ceiling: red circles at and around the
## player, then falling stone (SkyStrike; rocks crush spiderlings too). Charges aim where
## the player is heading, not where they are.
## Phases: 1 above 60% health, 2 below (nova, spiral and skulls join in, a little faster),
## 3 below 25% (enraged: faster, shorter cooldowns, double charges and rings, more rocks).

const PHASE2 := 0.6
const PHASE3 := 0.25
const STOMP_R_M := 3.8
const CHARGE_LEN_M := 18.0
const CHARGE_SPEED_M := 15.0
const CHARGE_TIME := 1.35
const RAGE_TINT := Color(1.0, 0.35, 0.45)

var phase := 1
var _mode := ""
var _cool := {"stomp": 0.0, "charge": 3.0, "volley": 1.5, "nova": 4.0, "brood": 9.0, "mortar": 5.0, "spiral": 3.0}
var _spiral_a := 0.0
var _spiral_t := 0.0
var _slam_center := Vector2.ZERO
var _charge_dir := Vector2.ZERO
var _charge_hit := false
var _charges_left := 0
var _last_pos := Vector2.ZERO
var _volleys_left := 0
var _volley_t := 0.0
var _volley_side := 1.0
var _rings_left := 0


func setup(d: EnemyData, g: Vector2, opts := {}) -> void:
	super.setup(d, g, opts)
	_spawn_dur = 1.8   # it rises out of the soul-fire slowly


func _ready() -> void:
	super._ready()
	Events.message.emit("ARACHNE, THE TITAN WEAVER", Color(1.0, 0.55, 0.85))
	Audio.play("brute_roar", gpos, 2.0, 0.55)
	VFX.shake(0.5)
	if VFX.camera:
		VFX.camera.punch(0.06)
	VFX.ring(gpos, Iso.m(6.0), Color(1.6, 0.5, 1.5), 0.9, 0.1)


func _speed_k() -> float:
	return 1.0 if phase == 1 else (1.12 if phase == 2 else 1.32)


func _cd_k() -> float:
	return 1.0 if phase == 1 else (0.85 if phase == 2 else 0.62)


func think(dt: float) -> void:
	for k in _cool:
		_cool[k] -= dt
	var p = player()
	if p == null:
		set_attack_frame(-1.0)
		desire(Vector2.ZERO, dt)
		return
	_check_phase()
	var to: Vector2 = p.gpos - gpos
	var dist := to.length()
	match state:
		S.CHASE:
			set_attack_frame(-1.0)
			steer_to(p.gpos, move_speed() * _speed_k(), dt)
			turn_toward(to, dt)
			if attack_cd <= 0.0:
				_choose(p, to, dist)
		S.WINDUP:
			_windup(p, dt)
		S.ATTACK:
			_attack(p, to, dist, dt)
		S.RECOVER:
			desire(Vector2.ZERO, dt)
			if _mode == "stomp" or _mode == "brood":
				set_attack_frame(0.62 + 0.37 * minf(1.0, state_t / 0.8))
			else:
				set_attack_frame(-1.0)
			if state_t >= (0.8 if _mode != "charge" else 0.6) / _speed_k():
				attack_cd = data.attack_cooldown * _cd_k() * cd_mult
				enter(S.CHASE)


func _choose(p, to: Vector2, dist: float) -> void:
	if dist < Iso.m(4.8) and _cool["stomp"] <= 0.0:
		_mode = "stomp"
		_slam_center = gpos + facing * Iso.m(2.6)
		enter(S.WINDUP)
		telegraph = VFX.telegraph_circle(_slam_center, Iso.m(STOMP_R_M), _stomp_time())
		Audio.play("brute_roar", gpos, -4.0, 0.7)
	elif phase >= 2 and _cool["nova"] <= 0.0 and dist < Iso.m(11.0):
		_mode = "nova"
		_rings_left = 2 if phase >= 3 else 1
		enter(S.WINDUP)
		telegraph = VFX.telegraph_circle(gpos, Iso.m(3.4), 1.0)
		Audio.play("brute_roar", gpos, 0.0, 0.5)
	elif phase >= 2 and _cool["spiral"] <= 0.0 and dist < Iso.m(12.0):
		_mode = "spiral"
		_spiral_a = randf() * TAU
		enter(S.WINDUP)
		telegraph = VFX.telegraph_circle(gpos, Iso.m(2.6), 0.8)
		Audio.play("spitter_charge", gpos, 2.0, 0.5)
	elif _cool["brood"] <= 0.0 and Game.living_enemies() < 12:
		_mode = "brood"
		enter(S.WINDUP)
		Audio.play("brute_roar", gpos, -2.0, 0.8)
	elif dist > Iso.m(6.0) and dist < Iso.m(20.0) and _cool["charge"] <= 0.0 and absf(facing.angle_to(to)) < 0.6:
		_mode = "charge"
		_charges_left = 2 if phase >= 3 else 1
		_begin_charge(_lead(p, 0.45) - gpos)
	elif dist > Iso.m(5.0) and _cool["mortar"] <= 0.0:
		_mode = "mortar"
		enter(S.WINDUP)
		Audio.play("spitter_charge", gpos, 0.0, 0.45)
	elif dist > Iso.m(4.0) and _cool["volley"] <= 0.0:
		_mode = "volley"
		_volleys_left = 3 + phase - 1
		enter(S.WINDUP)
		Audio.play("spitter_charge", gpos, 0.0, 0.6)



func _stomp_time() -> float:
	return data.telegraph_time / _speed_k()


func _begin_charge(to: Vector2) -> void:
	_charge_dir = to.normalized()
	enter(S.WINDUP)
	telegraph = VFX.telegraph_line(gpos, gpos + _charge_dir * Iso.m(CHARGE_LEN_M), radius * 1.7, 0.85 / _speed_k())
	Audio.play("brute_roar", gpos, 0.0, 0.65)


func _windup(p, dt: float) -> void:
	desire(Vector2.ZERO, dt)
	match _mode:
		"stomp":
			set_attack_frame(0.55 * state_t / _stomp_time())
			if state_t >= _stomp_time():
				_do_stomp(p)
				enter(S.RECOVER)
		"charge":
			set_attack_frame(0.3)
			turn_toward(_charge_dir, dt, 8.0)
			if state_t >= 0.85 / _speed_k():
				clear_telegraph()
				set_attack_frame(-1.0)
				_charge_hit = false
				_last_pos = gpos
				enter(S.ATTACK)
		"volley":
			set_attack_frame(0.25 * minf(1.0, state_t / 0.6))
			turn_toward(p.gpos - gpos, dt, 3.0)
			if state_t >= 0.6:
				_volley_t = 0.0
				enter(S.ATTACK)
		"nova":
			set_attack_frame(0.55 * minf(1.0, state_t / 1.0))
			VFX.emit("embers", Iso.lift(gpos, 0.4), -PI / 2, Color(2.6, 0.7, 2.4), 0.08)
			if state_t >= 1.0:
				clear_telegraph()
				_nova()
				enter(S.ATTACK)
		"brood":
			set_attack_frame(0.55 * minf(1.0, state_t / 0.8))
			if state_t >= 0.8:
				_brood()
				enter(S.RECOVER)
		"mortar":
			set_attack_frame(0.3 * minf(1.0, state_t / 0.5))
			turn_toward(p.gpos - gpos, dt, 3.0)
			if state_t >= 0.5:
				_mortar(p)
				enter(S.RECOVER)
		"spiral":
			set_attack_frame(0.4 * minf(1.0, state_t / 0.8))
			if state_t >= 0.8:
				clear_telegraph()
				_spiral_t = 0.0
				enter(S.ATTACK)


func _attack(p, to: Vector2, dist: float, dt: float) -> void:
	match _mode:
		"charge":
			facing = _charge_dir
			vel = _charge_dir * Iso.m(CHARGE_SPEED_M) * _speed_k() * speed_mult
			if not _charge_hit and dist < radius + p.radius + Iso.m(0.4):
				_charge_hit = true
				hurt_player(data.damage * 1.2, _charge_dir, 16.0)
				VFX.shake(0.45)
			if state_t > 0.15 and gpos.distance_to(_last_pos) < Iso.m(CHARGE_SPEED_M) * dt * 0.3:
				_crash()
				return
			_last_pos = gpos
			if state_t >= CHARGE_TIME:
				vel *= 0.3
				_charges_left -= 1
				if _charges_left > 0:
					_begin_charge(to)
				else:
					_cool["charge"] = 7.0 * _cd_k()
					enter(S.RECOVER)
		"volley":
			desire(Vector2.ZERO, dt)
			turn_toward(to, dt, 3.0)
			set_attack_frame(0.25)
			_volley_t -= dt
			if _volley_t <= 0.0:
				_volley_t = 0.32 / _speed_k()
				_fire_fan(p)
				_volleys_left -= 1
				if _volleys_left <= 0:
					_cool["volley"] = 4.5 * _cd_k()
					enter(S.RECOVER)
		"spiral":
			# a bullet storm: shards spray in rotating arms while it turns in place
			desire(Vector2.ZERO, dt)
			set_attack_frame(0.4)
			var arms := 3 if phase >= 3 else 2
			_spiral_a += dt * 2.4
			facing = Vector2.from_angle(_spiral_a)
			_spiral_t -= dt
			if _spiral_t <= 0.0:
				_spiral_t = 0.11
				for k in arms:
					var dir := Vector2.from_angle(_spiral_a + k * TAU / arms)
					_shard(gpos + dir * Iso.m(1.8), dir, 9.0)
				Audio.play("spitter_spit", gpos, -8.0, 1.3)
			if state_t >= 2.6:
				_cool["spiral"] = 11.0 * _cd_k()
				enter(S.RECOVER)
		"nova":
			desire(Vector2.ZERO, dt)
			set_attack_frame(0.62 + 0.37 * minf(1.0, state_t / 0.5))
			if _rings_left > 0 and state_t >= 0.7:
				_nova()
				state_t = 0.0
			elif state_t >= 0.6:
				_cool["nova"] = 9.0 * _cd_k()
				enter(S.RECOVER)
		_:
			enter(S.RECOVER)


func _do_stomp(p) -> void:
	clear_telegraph()
	var r := Iso.m(STOMP_R_M)
	VFX.ring(_slam_center, r, Color(1.0, 0.45, 0.8), 0.4, 0.1)
	VFX.debris(_slam_center, 3.0, 24)
	VFX.emit("smoke", Iso.to_screen(_slam_center), -PI / 2, Color(0.3, 0.26, 0.3, 0.75), 1.0)
	VFX.decal(_slam_center, VFX.T.scorch, Color(0, 0, 0, 0.5), r * 1.5)
	VFX.light_flash(Iso.lift(_slam_center, 0.3), Color(1.0, 0.5, 0.8), 2.6, 5.0, 0.3)
	VFX.shake(0.6)
	if VFX.post:
		VFX.post.shockwave(Iso.to_screen(_slam_center), r * 1.4, 0.4, 1.0)
	Audio.play("brute_slam", _slam_center, 3.0, 0.7)
	if p.gpos.distance_to(_slam_center) < r + p.radius * 0.5:
		hurt_player(data.damage * 0.8, (p.gpos - _slam_center).normalized(), 14.0)
	_cool["stomp"] = 2.2 * _cd_k()
	_rockfall(p, 4 + phase * 2, 0.7)


func _crash() -> void:
	vel = Vector2.ZERO
	VFX.shake(0.7)
	VFX.debris(gpos + _charge_dir * radius, 3.0, 30)
	Audio.play("brute_slam", gpos, 2.0, 0.6)
	VFX.popup(gpos, 4.2, "STUNNED", Color(1.0, 0.8, 0.3), 40)
	var pl = player()
	if pl:
		_rockfall(pl, 6 + phase * 2, 0.9)   # the crash brings the ceiling down: the opening still costs
	_cool["charge"] = 7.0 * _cd_k()
	attack_cd = data.attack_cooldown
	stagger_meter = 0.0
	enter(S.STAGGER)
	state_t = -1.0   # a long stun: the opening to punish the heart


func _fire_fan(p) -> void:
	var lead: Vector2 = _lead(p, 0.25)
	var dir := (lead - gpos).normalized().rotated(0.12 * _volley_side)
	_volley_side = -_volley_side
	var mouth := gpos + facing * Iso.m(2.4)
	var n := 9
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.13
		var q := Projectile.new()
		q.team = 1
		q.pos = mouth
		q.height = 1.4
		q.vel = dir.rotated(a) * Iso.m(10.5)
		q.info = DamageInfo.make(data.damage * dmg_mult * 0.42, DamageInfo.Type.VOID, self)
		q.info.knockback = Iso.m(2.0)
		q.max_range = Iso.m(randf_range(9.0, 15.0))
		if i % 2 == 0:
			q.tags[&"venom_pool"] = 1.1   # every other shard falls short and splashes a pool
		q.radius = Iso.m(0.34)
		q.size = 2.8
		q.kind = &"shard"
		q.color = Color(1.0, 0.22, 0.6)
		q.impact_style = "shard"
		Game.projectiles.spawn(q)
	VFX.muzzle(Iso.lift(mouth, 1.4), dir, {"color": Color(1.0, 0.25, 0.6), "scale": 1.1, "light": 1.8, "range": 4.0})
	Audio.play("spitter_spit", gpos, 0.0, 0.7)


## Where the player will be in t seconds if they keep running (clamped to the arena).
func _lead(p, t: float) -> Vector2:
	var g: Vector2 = p.gpos + p.vel * t
	return g if Game.dungeon.is_floor(Iso.cell_of(g)) else p.gpos


func _shard(at: Vector2, dir: Vector2, speed_m: float) -> void:
	var q := Projectile.new()
	q.team = 1
	q.pos = at
	q.height = 1.3
	q.vel = dir * Iso.m(speed_m)
	q.info = DamageInfo.make(data.damage * dmg_mult * 0.38, DamageInfo.Type.VOID, self)
	q.info.knockback = Iso.m(1.5)
	q.max_range = Iso.m(16.0)
	q.radius = Iso.m(0.3)
	q.size = 2.3
	q.kind = &"shard"
	q.color = Color(1.0, 0.22, 0.6)
	q.impact_style = "shard"
	Game.projectiles.spawn(q)


## Rocks shaken loose from the ceiling: one on where the player is heading, the rest
## scattered around them, landing one after another.
func _rockfall(p, n: int, delay: float) -> void:
	for i in n:
		var at: Vector2
		if i == 0:
			at = _lead(p, delay * 0.6)
		else:
			at = p.gpos + Vector2.from_angle(randf() * TAU) * Iso.m(randf_range(1.5, 8.0))
		if not Game.dungeon.is_floor(Iso.cell_of(at)):
			continue
		var r := SkyStrike.new()
		r.setup(at, randf_range(1.1, 1.6), delay + i * 0.11, data.damage * dmg_mult * 0.75, "rock", self)
		Game.world.add_hazard(r)


## Venom globs spat high, landing on and around the player and leaving burning pools.
func _mortar(p) -> void:
	var n := 6 + phase * 2
	var mouth := gpos + facing * Iso.m(2.4)
	var a0 := randf() * TAU
	for i in n:
		# one on where they are heading, a ring close around them, the rest scattered wider
		var at: Vector2
		if i == 0:
			at = _lead(p, 1.0)
		elif i <= 4:
			at = p.gpos + Vector2.from_angle(a0 + i * TAU / 4.0) * Iso.m(3.0)
		else:
			at = p.gpos + Vector2.from_angle(randf() * TAU) * Iso.m(randf_range(4.5, 8.0))
		if not Game.dungeon.is_floor(Iso.cell_of(at)):
			continue
		var v := SkyStrike.new()
		v.setup(at, 1.4, 1.05 + i * 0.07, data.damage * dmg_mult * 0.6, "venom", self, mouth)
		Game.world.add_hazard(v)
	VFX.muzzle(Iso.lift(mouth, 1.6), facing, {"color": Color(1.0, 0.3, 0.9), "scale": 1.2, "light": 2.0, "range": 4.0})
	Audio.play("spitter_spit", gpos, 2.0, 0.55)
	_cool["mortar"] = 6.5 * _cd_k()


func _nova() -> void:
	_rings_left -= 1
	var ring := SoulRing.new()
	ring.setup(gpos, Iso.m(15.0), 1.6 / _speed_k(), data.damage * dmg_mult * 0.85, self)
	Game.world.add_hazard(ring)
	VFX.light_flash(Iso.lift(gpos, 0.6), Color(1.0, 0.35, 0.9), 3.0, 6.0, 0.35)
	VFX.shake(0.4)
	if VFX.post:
		VFX.post.shockwave(Iso.to_screen(gpos), Iso.m(6.0), 0.5, 0.8)
	Audio.play("nova", gpos, 0.0, 0.6)


func _brood() -> void:
	# spiderlings, tiny copies of itself, pour out of its abdomen; from phase 2 skulls too
	var kids: Array = []
	for i in 3 + phase:
		kids.append("spiderling")
	for i in phase - 1:
		kids.append("bloater")
	var n := kids.size()
	for i in n:
		var a := facing.angle() + PI + (i - (n - 1) * 0.5) * 0.45
		var at := gpos + Vector2.from_angle(a) * (radius + Iso.m(1.2))
		if not Game.dungeon.is_floor(Iso.cell_of(at)):
			at = gpos + Vector2.from_angle(a) * radius * 0.6
		var e = Game.world.spawn_enemy(kids[i], at, {"from_nest": true})
		if e and room:
			e.room = room
			room.enemies.append(e)
	VFX.gore(gpos - facing * radius, Color(0.9, 0.35, 1.0), 2.2)
	VFX.popup(gpos, 4.0, "THE BROOD WAKES", Color(1.0, 0.5, 0.9), 30)
	_cool["brood"] = 15.0 * _cd_k()


func _check_phase() -> void:
	var f := hp / maxf(1.0, max_hp)
	var want := 1 if f > PHASE2 else (2 if f > PHASE3 else 3)
	if want <= phase:
		return
	phase = want
	_cool["nova"] = 0.0
	_cool["spiral"] = 1.0
	_cool["brood"] = 0.5 if phase == 2 else _cool["brood"]
	attack_cd = 0.0
	Events.message.emit("ARACHNE RAGES" if phase == 3 else "THE WEAVER STIRS", Color(1.0, 0.4, 0.6))
	Audio.play("brute_roar", gpos, 3.0, 0.5)
	VFX.shake(0.6)
	if VFX.camera:
		VFX.camera.punch(0.05)
	Game.slowmo(0.45, 0.35)
	if phase == 3:
		speed_mult *= 1.15
		body.self_modulate = data.body_tint * RAGE_TINT.lerp(Color.WHITE, 0.45)


func on_death(info: DamageInfo) -> void:
	# the titan bursts apart: a chain of blasts from its amber heart across its body
	for k in 6:
		var t := get_tree().create_timer(0.12 + k * 0.16)
		var at := gpos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 1.1)
		t.timeout.connect(func():
			VFX.explosion(at, Iso.m(2.2), Color(1.0, 0.6, 0.2) if k % 2 == 0 else Color(1.0, 0.3, 0.85), k == 5)
			VFX.souls(at, 1.0, 1.0))
	VFX.soul_streaks(Iso.lift(gpos, hit_height), 14)
	Events.message.emit("ARACHNE FALLS", Color(1.0, 0.8, 0.4))
