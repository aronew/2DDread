class_name Rend
extends Ability
## F — melee arc. Lunges toward the nearest target in front, parries enemy
## projectiles, and EXECUTES staggered (or nearly dead) non-boss enemies,
## which bursts them into health — the aggressive way to heal.

const RANGE_M := 2.5
const ARC := 2.4  # radians (~140 deg)
var lunge_t := 0.0
var lunge_vel := Vector2.ZERO


func _init() -> void:
	title = "Rend"
	key_hint = "F"
	color = Color(1.0, 0.3, 0.3)
	cooldown = 0.65


func use(p) -> bool:
	var dir: Vector2 = p.aim_dir
	# lunge toward the closest enemy in the cone
	var best = null
	var best_d := Iso.m(5.0)
	for e in Game.grid.query(p.gpos, Iso.m(5.0)):
		var to: Vector2 = e.gpos - p.gpos
		if absf(dir.angle_to(to)) < 0.6 and to.length() < best_d:
			best_d = to.length()
			best = e
	if best and best_d > Iso.m(1.4):
		lunge_t = 0.09
		lunge_vel = (best.gpos - p.gpos).normalized() * ((best_d - Iso.m(1.0)) / 0.09)
		dir = (best.gpos - p.gpos).normalized()
	_swing(p, dir)
	return true


func process(dt: float, p) -> void:
	super.process(dt, p)
	if lunge_t > 0.0:
		lunge_t -= dt
		p.external_motion(lunge_vel * dt)


func _swing(p, dir: Vector2) -> void:
	var g: Vector2 = p.gpos + dir * Iso.m(0.4)
	var r := Iso.m(RANGE_M)
	var sp := Iso.lift(p.gpos, 1.0)
	VFX.burst_sprite(VFX.T.slash, sp, Color(2.0, 0.75, 0.65), Vector2(0.8, 0.8 * Iso.K), Vector2(1.35, 1.35 * Iso.K), 0.14, true, Iso.to_screen(dir).angle())
	Audio.play("melee_swing", p.gpos)
	VFX.light_flash(sp, Color(1.0, 0.35, 0.3), 1.6, 3.0, 0.12)
	var hit_any := false
	for e in Game.grid.query(g, r):
		var to: Vector2 = e.gpos - p.gpos
		if to.length() > r + e.radius or absf(dir.angle_to(to)) > ARC * 0.5 + 0.2:
			continue
		hit_any = true
		var executable: bool = e.alive and not e.data.boss and (e.staggered() or (e.hp / e.max_hp < 0.2 and not e.is_elite))
		var d := DamageInfo.make(48.0, DamageInfo.Type.PHYSICAL, p)
		d.is_melee = true
		d.direction = to.normalized()
		d.knockback = Iso.m(11.0)
		d.stagger = 70.0
		d.hit_pos = e.gpos
		if executable:
			d.execute = true
			d.amount = e.hp + 999.0
			_execute_fx(p, e)
		VFX.impact(e.gpos, e.hit_height, -d.direction, "flesh", e.blood_color)
		Combat.hit_enemy(e, d)
	for q in Game.projectiles.list:
		if q.team == 1 and q.pos.distance_to(p.gpos) < r and absf(dir.angle_to(q.pos - p.gpos)) < ARC * 0.5 + 0.3:
			q.dead = true
			VFX.impact(q.pos, q.height, -q.vel.normalized(), "energy")
			Audio.play("impact_armor", q.pos)
	if hit_any:
		Audio.play("melee_hit", p.gpos)
		VFX.shake(0.22)
		Game.hit_stop(0.045, 0.08)


func _execute_fx(p, e) -> void:
	Audio.play("execute", e.gpos)
	VFX.popup(e.gpos, 2.0, "EXECUTED", Color(1.0, 0.3, 0.25), 32)
	VFX.screen_flash(Color(1.0, 0.15, 0.1, 0.18), 0.1)
	VFX.shake(0.45)
	Game.hit_stop(0.1, 0.04, true)
	for i in 3:
		Pickup.spawn(&"health", e.gpos, {"value": 10.0})
	if randf() < 0.5:
		Pickup.spawn(&"ammo", e.gpos, {"value": 0.15})
