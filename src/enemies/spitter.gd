class_name Spitter
extends Enemy
## Ranged zoner. Keeps 6-10 m away, retreats when pressed, strafes, and lobs
## a 3-glob acid volley that leads the player and leaves short acid puddles.

const RECOVER_TIME := 0.45
var _strafe := 1.0
var _strafe_t := 0.0


func think(dt: float) -> void:
	var p = player()
	if p == null:
		set_attack_frame(-1.0)
		desire(Vector2.ZERO, dt)
		return
	var to: Vector2 = p.gpos - gpos
	var dist := to.length()
	match state:
		S.CHASE:
			set_attack_frame(-1.0)
			var los := Game.dungeon.has_los(gpos, p.gpos)
			if not los or dist > Iso.m(10.5):
				steer_to(p.gpos, move_speed(), dt)
			elif dist < Iso.m(5.5):
				var away := -to.normalized()
				if Game.dungeon.raycast(gpos, gpos + away * Iso.m(2.0), "walk").hit:
					away = away.rotated(PI * 0.5 * _strafe)
				desire(away * move_speed() * 1.1, dt)
			else:
				_strafe_t -= dt
				if _strafe_t <= 0.0:
					_strafe = -_strafe
					_strafe_t = randf_range(1.4, 2.8)
				desire(to.normalized().orthogonal() * _strafe * move_speed() * 0.6, dt)
			turn_toward(to, dt)
			if los and dist < Iso.m(data.attack_range_m) and attack_cd <= 0.0:
				enter(S.WINDUP)
				Audio.play("spitter_charge", gpos)
				telegraph = VFX.telegraph_circle(gpos, radius * 1.8, data.telegraph_time, Color(0.5, 1.0, 0.25))
		S.WINDUP:
			desire(Vector2.ZERO, dt)
			turn_toward(to, dt, 10.0)
			set_attack_frame(0.55 * state_t / data.telegraph_time)
			glow.modulate = Color(1, 1, 1) * (1.0 + state_t / data.telegraph_time * 1.5)
			if state_t >= data.telegraph_time:
				glow.modulate = Color(1, 1, 1)
				_fire(p)
				enter(S.RECOVER)
		S.RECOVER:
			desire(Vector2.ZERO, dt)
			set_attack_frame(0.6 + 0.39 * state_t / RECOVER_TIME)
			if state_t >= RECOVER_TIME:
				attack_cd = data.attack_cooldown * cd_mult * randf_range(0.85, 1.25)
				enter(S.CHASE)


func _fire(p) -> void:
	var lead: Vector2 = p.gpos + p.vel * 0.3
	var dir := (lead - gpos).normalized()
	var mouth := gpos + dir * Iso.m(0.7)
	var n := 4 if not is_elite else 6
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.15
		var q := Projectile.new()
		q.team = 1
		q.pos = mouth
		q.height = 1.05
		q.vel = dir.rotated(a) * Iso.m(12.0)
		q.info = DamageInfo.make(data.damage * dmg_mult, DamageInfo.Type.TOXIC, self)
		q.info.knockback = Iso.m(2.0)
		q.max_range = Iso.m(15.0)
		q.radius = Iso.m(0.22)
		q.kind = &"acid"
		q.color = Color(0.5, 1.0, 0.25)
		q.impact_style = "acid"
		Game.projectiles.spawn(q)
	VFX.muzzle(Iso.lift(mouth, 1.05), dir, {"color": Color(0.5, 1.0, 0.3), "scale": 0.7, "light": 1.5, "range": 3.0})
	Audio.play("spitter_spit", gpos)
