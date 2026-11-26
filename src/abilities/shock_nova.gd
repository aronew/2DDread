class_name ShockNova
extends Ability
## Q — get-off-me button: shock blast that hurls enemies back, staggers them,
## applies Shock and erases enemy projectiles inside the radius.

const RADIUS_M := 4.6


func _init() -> void:
	title = "Shock Nova"
	key_hint = "Q"
	color = Color(0.45, 0.7, 1.0)
	cooldown = 8.0


func use(p) -> bool:
	var g: Vector2 = p.gpos
	var r := Iso.m(RADIUS_M)
	var pw := power(p)
	var sp := Iso.to_screen(g)
	VFX.ring(g, r, Color(0.5, 0.75, 1.0), 0.45, 0.1)
	VFX.ring(g, r * 0.6, Color(0.8, 0.9, 1.0), 0.3, 0.1)
	VFX.burst_sprite(VFX.T.glow, sp - Vector2(0, 40), Color(1.5, 2.5, 6.0), Vector2(0.5, 0.4), Vector2(5.0, 3.8), 0.35)
	VFX.light_flash(sp - Vector2(0, 50), Color(0.5, 0.7, 1.0), 4.5, RADIUS_M * 2.2, 0.5, 100.0)
	VFX.emit("electric", sp - Vector2(0, 40), 0.0, Color(1.5, 2.0, 5.0), 1.0)
	VFX.screen_flash(Color(0.55, 0.75, 1.0, 0.22), 0.12)
	VFX.shake(0.5)
	Audio.play("nova", g)
	var hits := 0
	for e in Game.grid.query(g, r):
		var d := DamageInfo.make(55.0 * pw, DamageInfo.Type.SHOCK, p)
		d.is_ability = true
		d.direction = (e.gpos - g).normalized() if e.gpos.distance_to(g) > 1.0 else Vector2.RIGHT
		d.knockback = Iso.m(15.0)
		d.stagger = 120.0
		d.status = {&"shock": 1.0}
		d.hit_pos = e.gpos
		VFX.lightning(sp - Vector2(0, 50), Iso.lift(e.gpos, e.hit_height), Color(1.4, 1.8, 4.5), 3.0, 0.16, 1.4)
		Combat.hit_enemy(e, d)
		hits += 1
	for q in Game.projectiles.list:
		if q.team == 1 and q.pos.distance_to(g) < r:
			q.dead = true
			VFX.impact(q.pos, q.height, Vector2.UP, "energy")
	if hits > 0:
		Game.hit_stop(0.07, 0.05, true)
	Events.ability_used.emit(0)
	return true
