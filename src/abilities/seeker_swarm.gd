class_name SeekerSwarm
extends Ability
## E — launches a volley of homing micro-missiles that spread across the
## nearest threats around the aim point.

const COUNT := 10
var _queue := 0
var _t := 0.0
var _targets: Array = []


func _init() -> void:
	title = "Seeker Swarm"
	key_hint = "E"
	color = Color(1.0, 0.55, 0.25)
	cooldown = 10.0


func use(p) -> bool:
	_targets.clear()
	var center: Vector2 = p.aim_target
	var cands: Array = []
	for e in Game.enemies:
		if e.alive and e.gpos.distance_to(p.gpos) < Iso.m(16.0):
			cands.append(e)
	cands.sort_custom(func(a, b): return a.gpos.distance_squared_to(center) < b.gpos.distance_squared_to(center))
	_targets = cands.slice(0, 6)
	_queue = COUNT
	_t = 0.0
	Events.ability_used.emit(1)
	return true


func process(dt: float, p) -> void:
	super.process(dt, p)
	if _queue <= 0:
		return
	_t -= dt
	while _t <= 0.0 and _queue > 0:
		_t += 0.035
		_launch(p, COUNT - _queue)
		_queue -= 1


func _launch(p, i: int) -> void:
	var q := Projectile.new()
	q.team = 0
	var back: Vector2 = -p.aim_dir * Iso.m(0.25)
	q.pos = p.gpos + back
	q.height = 1.9
	var fan := deg_to_rad(lerpf(-75.0, 75.0, float(i) / (COUNT - 1)))
	q.vel = p.aim_dir.rotated(fan + randf_range(-0.15, 0.15)) * Iso.m(13.0)
	var d := DamageInfo.make(32.0 * power(p), DamageInfo.Type.EXPLOSIVE, p)
	d.is_ability = true
	d.knockback = Iso.m(5.0)
	d.stagger = 25.0
	q.info = d
	q.max_range = Iso.m(24.0)
	q.explode_radius = Iso.m(1.5)
	q.kind = &"missile"
	q.color = Color(1.0, 0.55, 0.25)
	q.width = 4.0
	q.radius = Iso.m(0.3)
	q.homing_turn = 7.5
	if not _targets.is_empty():
		q.homing = _targets[i % _targets.size()]
	else:
		q.vel = (p.aim_target - q.pos).normalized().rotated(fan * 0.4) * Iso.m(15.0)
		q.max_range = maxf(Iso.m(3.0), q.pos.distance_to(p.aim_target))
	Game.projectiles.spawn(q)
	Audio.play("seeker_launch", p.gpos)
	VFX.emit("smoke", Iso.lift(q.pos, 1.9), -PI / 2, Color(0.3, 0.3, 0.3, 0.5), 0.15)
