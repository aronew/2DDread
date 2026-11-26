class_name Bloater
extends Enemy
## Volatile sac. Waddles in, primes (pulsing ring), detonates — hurting the
## player AND other enemies. Shooting it early pops it where it stands, which
## is the smart play when it's next to its friends.

var _exploded := false


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
			steer_to(p.gpos, move_speed(), dt)
			turn_toward(to, dt)
			if dist < Iso.m(data.attack_range_m):
				enter(S.WINDUP)
				telegraph = VFX.telegraph_circle(gpos, Iso.m(3.2), data.telegraph_time, Color(1.0, 0.3, 0.15))
				Audio.play("bloater_prime", gpos)
		S.WINDUP:
			steer_to(p.gpos, move_speed() * 0.35, dt)
			if telegraph and is_instance_valid(telegraph):
				telegraph.move_to(gpos)
			set_attack_frame(fmod(state_t * 3.0, 1.0))
			glow.modulate = Color(1, 1, 1) * (1.0 + 1.5 * absf(sin(state_t * 14.0)))
			if state_t >= data.telegraph_time:
				_detonate(false)


func _detonate(killed: bool) -> void:
	if _exploded:
		return
	_exploded = true
	clear_telegraph()
	var d := DamageInfo.make(data.damage * dmg_mult, DamageInfo.Type.EXPLOSIVE, self)
	d.knockback = Iso.m(10.0)
	d.stagger = 80.0
	var r := Iso.m(3.2)
	if killed:
		# popped by the player: big damage to nearby enemies, still dangerous up close
		d.amount *= 2.0
	Combat.explode(gpos, r, d, true, Color(0.4, 1.0, 0.55), true)
	VFX.gore(gpos, blood_color, 1.6)
	if not killed:
		no_loot = true
		var k := DamageInfo.make(hp + 1.0, DamageInfo.Type.EXPLOSIVE, self)
		die(k)


func on_death(info: DamageInfo) -> void:
	if not _exploded:
		_exploded = true
		var blast := TimedBlast.new()
		blast.setup(gpos, Iso.m(3.2), 0.16, data.damage * dmg_mult * 2.0, self, Color(0.4, 1.0, 0.55))
		Game.world.add_hazard(blast)
