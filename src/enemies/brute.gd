class_name Brute
extends Enemy
## Armoured heavy. Frontal plating shrugs off most damage (flank it or blow it
## up), glowing back is a weak point. Turns slowly. Two telegraphed attacks:
##   Slam   — overhead smash on a marked circle in front of it.
##   Charge — locks a direction, bulldozes in a line; hitting a wall stuns it.

const RECOVER_SLAM := 0.95
const CHARGE_TIME := 1.2
var _mode := ""
var _slam_center := Vector2.ZERO
var _charge_dir := Vector2.ZERO
var _charge_cd := 3.5
var _charge_hit := false
var _last_pos := Vector2.ZERO


func think(dt: float) -> void:
	_charge_cd -= dt
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
			steer_to(p.gpos, move_speed(), dt)
			turn_toward(to, dt)
			if dist < Iso.m(data.attack_range_m) and attack_cd <= 0.0:
				_mode = "slam"
				_slam_center = gpos + facing * Iso.m(1.4)
				enter(S.WINDUP)
				telegraph = VFX.telegraph_circle(_slam_center, Iso.m(3.0), data.telegraph_time)
				Audio.play("brute_roar", gpos, -6.0, 1.2)
			elif dist > Iso.m(5.0) and dist < Iso.m(13.0) and _charge_cd <= 0.0 and attack_cd <= 0.0 \
					and absf(facing.angle_to(to)) < 0.5 and not Game.dungeon.raycast(gpos, p.gpos, "walk").hit:
				_mode = "charge"
				_charge_dir = to.normalized()
				enter(S.WINDUP)
				telegraph = VFX.telegraph_line(gpos, gpos + _charge_dir * Iso.m(13.0), radius * 2.0, 0.75)
				Audio.play("brute_roar", gpos)
		S.WINDUP:
			desire(Vector2.ZERO, dt)
			if _mode == "slam":
				set_attack_frame(0.5 * state_t / data.telegraph_time)
				if state_t >= data.telegraph_time:
					_do_slam(p)
					enter(S.RECOVER)
			else:
				set_attack_frame(-1.0)
				turn_toward(_charge_dir, dt, 10.0)
				if state_t >= 0.75:
					clear_telegraph()
					_charge_hit = false
					_last_pos = gpos
					enter(S.ATTACK)
		S.ATTACK:
			facing = _charge_dir
			vel = _charge_dir * Iso.m(12.5) * speed_mult
			set_attack_frame(-1.0)
			if not _charge_hit and dist < radius + p.radius + Iso.m(0.3):
				_charge_hit = true
				hurt_player(data.damage * 1.1, _charge_dir, 14.0)
				VFX.shake(0.4)
			if state_t > 0.12:
				var moved := gpos.distance_to(_last_pos)
				if moved < Iso.m(12.5) * dt * 0.3:
					_crash()
					return
			_last_pos = gpos
			if state_t >= CHARGE_TIME:
				vel *= 0.3
				enter(S.RECOVER)
		S.RECOVER:
			desire(Vector2.ZERO, dt)
			if _mode == "slam":
				set_attack_frame(0.62 + 0.37 * state_t / RECOVER_SLAM)
			if state_t >= RECOVER_SLAM:
				attack_cd = data.attack_cooldown * cd_mult
				if _mode == "charge":
					_charge_cd = 6.5
				enter(S.CHASE)


func _do_slam(p) -> void:
	clear_telegraph()
	var r := Iso.m(3.0)
	VFX.ring(_slam_center, r, Color(1.0, 0.5, 0.2), 0.35, 0.1)
	VFX.debris(_slam_center, 2.0, 18)
	VFX.emit("smoke", Iso.to_screen(_slam_center), -PI / 2, Color(0.3, 0.28, 0.26, 0.7), 0.9)
	VFX.decal(_slam_center, VFX.T.scorch, Color(0, 0, 0, 0.45), r * 1.4)
	VFX.light_flash(Iso.lift(_slam_center, 0.3), Color(1.0, 0.55, 0.25), 2.2, 4.0, 0.25)
	VFX.shake(0.55)
	Audio.play("brute_slam", _slam_center)
	if p.gpos.distance_to(_slam_center) < r + p.radius * 0.5:
		hurt_player(data.damage, (p.gpos - _slam_center).normalized(), 12.0)


func _crash() -> void:
	vel = Vector2.ZERO
	VFX.shake(0.5)
	VFX.debris(gpos + _charge_dir * radius, 2.0, 20)
	Audio.play("brute_slam", gpos, -3.0, 0.8)
	VFX.popup(gpos, 2.8, "STUNNED", Color(1.0, 0.8, 0.3), 26)
	_charge_cd = 6.5
	attack_cd = data.attack_cooldown
	stagger_meter = 0.0
	enter(S.STAGGER)
	state_t = -0.6  # longer than a normal stagger
