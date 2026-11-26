class_name Elite
extends RefCounted
## Elite modifier layer: works on any enemy archetype. Base elite = tougher,
## bigger, golden aura; affixes add mechanics the player must respect.
##   frenzied  — faster, attacks more often
##   shielded  — regenerating energy shield; breaking it staggers
##   volatile  — drops timed mines; detonates on death
##   molten    — trails burning ground, immune to burn

const AFFIX_COLORS := {
	&"frenzied": Color(1.0, 0.3, 0.25), &"shielded": Color(0.4, 0.7, 1.0),
	&"volatile": Color(1.0, 0.75, 0.2), &"molten": Color(1.0, 0.45, 0.1),
}


static func apply(e, list: Array) -> void:
	e.is_elite = true
	e.affixes = list.map(func(a): return StringName(a))
	e.max_hp *= 3.2
	e.dmg_mult *= 1.3
	e.radius *= 1.18
	for a in e.affixes:
		match a:
			&"frenzied":
				e.speed_mult *= 1.35
				e.cd_mult *= 0.65
			&"shielded":
				e.shield_max = e.max_hp * 0.4
				e.shield = e.shield_max


static func decorate(e) -> void:
	var aura := EliteAura.new()
	aura.enemy = e
	e.add_child(aura)
	e.move_child(aura, 0)
	Audio.play("elite_spawn", e.gpos)
	Events.elite_engaged.emit(e)


static func process(e, dt: float) -> void:
	e._affix_t -= dt
	if &"shielded" in e.affixes and e.shield < e.shield_max:
		e._shield_regen_t -= dt
		if e._shield_regen_t <= 0.0:
			e.shield = minf(e.shield_max, e.shield + e.shield_max * 0.25 * dt)
	if e._affix_t <= 0.0:
		if &"volatile" in e.affixes and e.dist_to_player() < Iso.m(12.0):
			e._affix_t = 4.5
			_drop_mine(e)
		elif &"molten" in e.affixes and e.vel.length() > 20.0:
			e._affix_t = 0.55
			var h := GroundHazard.new()
			h.setup(e.gpos, Iso.m(1.1), 4.0, e)
			h.hurts_enemies = false
			h.dps = 16.0
			Game.world.add_hazard(h)
		else:
			e._affix_t = 0.3


static func _drop_mine(e) -> void:
	var g: Vector2 = e.gpos + Vector2.from_angle(randf() * TAU) * Iso.m(randf_range(1.0, 3.0))
	g = Game.dungeon.resolve(g, Iso.m(0.3))
	var mine := TimedBlast.new()
	mine.setup(g, Iso.m(2.2), 1.3, 26.0 * e.dmg_mult, e, Color(1.0, 0.75, 0.2))
	Game.world.add_hazard(mine)


static func shield_broken(e) -> void:
	VFX.popup(e.gpos, 2.6, "SHIELD BROKEN", Color(0.5, 0.8, 1.0), 26)
	VFX.ring(e.gpos, e.radius * 3.0, Color(0.5, 0.8, 1.0), 0.35)
	Audio.play("shield_break", e.gpos)
	e._stagger()


static func on_death(e) -> void:
	if &"volatile" in e.affixes:
		var mine := TimedBlast.new()
		mine.setup(e.gpos, Iso.m(3.8), 0.9, 40.0 * e.dmg_mult, e, Color(1.0, 0.6, 0.2))
		Game.world.add_hazard(mine)


class EliteAura extends Node2D:
	var enemy
	var t := 0.0

	func _ready() -> void:
		material = VFX.add_mat
		z_index = -1

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		if enemy == null or not enemy.alive:
			return
		var r: float = enemy.radius * 1.7
		var col := Color(1.0, 0.65, 0.2)
		if not enemy.affixes.is_empty():
			col = Elite.AFFIX_COLORS.get(enemy.affixes[0], col)
		var pulse := 0.7 + 0.3 * sin(t * 5.0)
		draw_polyline(Telegraph._ellipse(Vector2.ZERO, r, 40), col * Color(2.0, 2.0, 2.0, 0.8 * pulse), 3.0, true)
		draw_colored_polygon(Telegraph._ellipse(Vector2.ZERO, r, 28), col * Color(1, 1, 1, 0.12 * pulse))
		if enemy.shield > 0.0:
			var sr: float = enemy.radius * 1.5
			var c := Vector2(0, -Iso.h(enemy.hit_height))
			draw_arc(c, sr * 1.3, 0, TAU, 40, Color(0.5, 0.8, 2.2, 0.5 + 0.2 * sin(t * 8.0)), 3.0, true)
