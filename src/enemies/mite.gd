class_name Mite
extends Enemy
## Fast swarmer. Approaches on a flanking arc so packs surround the player,
## plants itself (telegraph), then lunges in a straight, dodgeable line.

const LUNGE_TIME := 0.22
const RECOVER_TIME := 0.45
var _lunge_dir := Vector2.ZERO
var _lunge_hit := false


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
			var target: Vector2 = p.gpos
			if dist > Iso.m(4.5):
				target += to.normalized().orthogonal() * _flank * minf(dist * 0.45, Iso.m(4.0))
			steer_to(target, move_speed(), dt)
			turn_toward(vel if vel.length() > 20.0 else to, dt)
			if dist < Iso.m(data.attack_range_m) and attack_cd <= 0.0 and Game.dungeon.has_los(gpos, p.gpos):
				_lunge_dir = to.normalized()
				enter(S.WINDUP)
				telegraph = VFX.telegraph_line(gpos, gpos + _lunge_dir * Iso.m(3.1), radius * 1.6, data.telegraph_time)
				Audio.play("mite_attack", gpos)
		S.WINDUP:
			desire(Vector2.ZERO, dt)
			turn_toward(_lunge_dir, dt, 25.0)
			set_attack_frame(0.45 * state_t / data.telegraph_time)
			if state_t >= data.telegraph_time:
				clear_telegraph()
				_lunge_hit = false
				enter(S.ATTACK)
		S.ATTACK:
			set_attack_frame(0.45 + 0.25 * state_t / LUNGE_TIME)
			vel = _lunge_dir * Iso.m(12.5) * (1.0 - 0.5 * state_t / LUNGE_TIME)
			if not _lunge_hit and dist < radius + p.radius + Iso.m(0.3):
				_lunge_hit = true
				hurt_player(data.damage, _lunge_dir, 5.0)
			if state_t >= LUNGE_TIME:
				enter(S.RECOVER)
		S.RECOVER:
			desire(Vector2.ZERO, dt)
			set_attack_frame(0.7 + 0.29 * state_t / RECOVER_TIME)
			if state_t >= RECOVER_TIME:
				attack_cd = data.attack_cooldown * cd_mult * randf_range(0.8, 1.35)
				enter(S.CHASE)
