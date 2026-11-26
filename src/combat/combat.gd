class_name Combat
extends RefCounted
## Shared combat resolution so every damage source (bullets, beams, melee,
## abilities, explosions, hazards) goes through the same perk hooks.


static func roll_crit(info: DamageInfo, chance: float, mult: float) -> void:
	if randf() < chance:
		info.crit = true
		info.crit_mult = mult
		info.amount *= mult


## Player-owned damage to an enemy. Perks may modify the hit before it lands
## and react after (on_hit / on_crit / on_kill are dispatched by the Build).
static func hit_enemy(e, info: DamageInfo) -> float:
	if e == null or not e.alive:
		return 0.0
	var pl = Game.player
	var from_player: bool = pl != null and info.source == pl
	if from_player:
		pl.build.before_hit(e, info)
	var was_alive: bool = e.alive
	var dealt: float = e.take_damage(info)
	if from_player:
		pl.build.after_hit(e, info, dealt, was_alive and not e.alive)
	return dealt


## Radial explosion: damages enemies, props (chain reactions), breakable walls
## and optionally the player. Damage falls off to 50% at the edge.
static func explode(g: Vector2, radius: float, info: DamageInfo, hurt_player := true,
		color := Color(1.0, 0.55, 0.2), big := true) -> void:
	var pl = Game.player
	if pl and info.source == pl:
		radius *= pl.build.mult("explosion_radius_pct")
	VFX.explosion(g, radius, color, big)
	Audio.play("explosion_big" if big else "explosion_small", g)
	Events.explosion.emit(g, radius, info)
	if pl and info.source == pl:
		pl.build.on_explosion(g, radius, info)
	for e in Game.grid.query(g, radius):
		var d := info.copy()
		d.is_explosion = true
		var dist: float = e.gpos.distance_to(g)
		d.amount *= 1.0 - 0.5 * clampf(dist / (radius + e.radius), 0.0, 1.0)
		d.direction = (e.gpos - g).normalized() if dist > 1.0 else Vector2.from_angle(randf() * TAU)
		d.hit_pos = e.gpos
		if info.source is Node and info.source.get("is_enemy") == true and e == info.source:
			continue
		hit_enemy(e, d)
	if Game.dungeon:
		for p in Game.dungeon.props.duplicate():
			if p.alive and p.gpos.distance_to(g) < radius + p.radius and p != info.source:
				var d := info.copy()
				d.is_explosion = true
				d.direction = (p.gpos - g).normalized()
				p.take_damage(d)
		var c := Iso.cell_of(g)
		for ox in range(-2, 3):
			for oy in range(-2, 3):
				var cc := c + Vector2i(ox, oy)
				if Game.dungeon.breakables.has(cc) and Iso.cell_center(cc).distance_to(g) < radius + Iso.TILE_GPX * 0.6:
					Game.dungeon.damage_cell(cc, info.amount * 1.5)
	if hurt_player and pl and pl.alive and info.source != pl:
		var dist: float = pl.gpos.distance_to(g)
		if dist < radius + pl.radius:
			var d := info.copy()
			d.is_explosion = true
			d.amount *= 1.0 - 0.5 * clampf(dist / radius, 0.0, 1.0)
			d.direction = (pl.gpos - g).normalized() if dist > 1.0 else Vector2.RIGHT
			pl.take_damage(d)
	if big:
		Game.hit_stop(0.045, 0.1)
