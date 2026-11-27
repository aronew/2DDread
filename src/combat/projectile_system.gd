class_name ProjectileSystem
extends Node2D
## Simulates every projectile and hitscan beam in plain data and draws them
## in one additive canvas item (cheap, batch-friendly, hundreds on screen).

var list: Array = []
var beams: Array = []


func _ready() -> void:
	material = VFX.add_mat
	z_index = 30
	Game.projectiles = self


func spawn(p: Projectile) -> void:
	list.append(p)


func clear_all() -> void:
	list.clear()
	beams.clear()


func _process(dt: float) -> void:
	var i := 0
	while i < list.size():
		var p: Projectile = list[i]
		_step(p, dt)
		if p.dead:
			list[i] = list[list.size() - 1]
			list.pop_back()
		else:
			i += 1
	for b in beams:
		b["t"] -= dt
	beams = beams.filter(func(b): return b["t"] > 0.0)
	queue_redraw()


func _step(p: Projectile, dt: float) -> void:
	p.age += dt
	p.prev = p.pos
	if p.homing != null:
		if is_instance_valid(p.homing) and p.homing.alive:
			var want: Vector2 = (p.homing.gpos - p.pos).normalized()
			var cur := p.vel.normalized()
			var ang := cur.angle_to(want)
			var turn := clampf(ang, -p.homing_turn * dt, p.homing_turn * dt)
			p.vel = cur.rotated(turn) * p.vel.length()
		else:
			p.homing = null
	if p.lob:
		p.vz -= p.gravity * dt
		p.height += p.vz * dt
	var from := p.pos
	var to := p.pos + p.vel * dt
	if p.kind == &"missile" or p.lob:
		p.trail.append(Iso.lift(p.pos, p.height))
		if p.trail.size() > 14:
			p.trail.remove_at(0)
	# walls (lobbed shots fly over low geometry until they come down)
	var wall := {"hit": false}
	if not p.lob or p.height < 2.8:
		wall = Game.dungeon.raycast(from, to)
	var seg_end: Vector2 = wall["point"] if wall["hit"] else to
	if p.team == 0:
		while true:
			var h := Game.grid.segment_first(from, seg_end, p.radius, p.hit_ids)
			if h.is_empty():
				break
			if p.lob and p.height > 1.8:
				break
			var e = h["enemy"]
			var at: Vector2 = from.lerp(seg_end, h["t"])
			p.hit_ids[e.get_instance_id()] = true
			_hit_enemy(p, e, at)
			if p.pierce > 0 and p.explode_radius <= 0.0:
				p.pierce -= 1
				continue
			p.dead = true
			return
		var ph := Game.dungeon.segment_prop(from, seg_end, p.radius)
		if not ph.is_empty() and not (p.lob and p.height > 1.2):
			var at: Vector2 = from.lerp(seg_end, ph["t"])
			var d := p.info.copy()
			d.hit_pos = at
			d.direction = p.vel.normalized()
			ph["prop"].take_damage(d)
			if p.explode_radius > 0.0:
				_explode(p, at)
			else:
				VFX.impact(at, minf(p.height, 0.7), -p.vel.normalized(), "metal")
			p.dead = true
			return
	else:
		var pl = Game.player
		if pl and pl.alive and not pl.invulnerable():
			var dd := to - from
			var t := clampf((pl.gpos - from).dot(dd) / maxf(dd.length_squared(), 0.001), 0.0, 1.0)
			if (from + dd * t).distance_to(pl.gpos) < pl.radius + p.radius:
				var d := p.info.copy()
				d.direction = p.vel.normalized()
				d.hit_pos = pl.gpos
				pl.take_damage(d)
				VFX.impact(pl.gpos, 1.0, -p.vel.normalized(), p.impact_style)
				if p.kind == &"acid":
					Audio.play("acid_splash", pl.gpos)
				p.dead = true
				return
	if wall["hit"]:
		var n: Vector2 = wall["normal"]
		if Game.dungeon.breakables.has(wall["cell"]) and p.team == 0:
			Game.dungeon.damage_cell(wall["cell"], p.info.amount)
		if p.ricochet > 0 and p.explode_radius <= 0.0:
			p.ricochet -= 1
			p.vel = p.vel.bounce(n)
			p.pos = wall["point"] + n * 3.0
			p.hit_ids.clear()
			VFX.impact(wall["point"], p.height, n, "metal", p.color)
			return
		if p.explode_radius > 0.0:
			_explode(p, wall["point"] + n * 4.0)
		else:
			VFX.impact(wall["point"], p.height, n, p.impact_style if p.team == 1 else "metal", p.color)
			if p.team == 0:
				Audio.play("impact_metal", wall["point"])
			if p.kind == &"acid":
				_acid_splat(wall["point"] + n * 20.0)
		p.dead = true
		return
	p.pos = to
	p.traveled += from.distance_to(to)
	if p.lob and p.height <= 0.0:
		p.height = 0.0
		_explode(p, p.pos)
		p.dead = true
		return
	if p.traveled >= p.max_range:
		if p.explode_radius > 0.0:
			_explode(p, p.pos)
		elif p.kind == &"acid":
			_acid_splat(p.pos)
		p.dead = true


func _hit_enemy(p: Projectile, e, at: Vector2) -> void:
	var d := p.info.copy()
	d.hit_pos = at
	d.direction = p.vel.normalized()
	if p.traveled > p.falloff_start:
		var k := clampf((p.traveled - p.falloff_start) / maxf(1.0, p.max_range - p.falloff_start), 0.0, 1.0)
		d.amount *= lerpf(1.0, p.falloff_min, k)
		d.knockback *= lerpf(1.0, 0.4, k)
	Combat.roll_crit(d, p.crit_chance, p.crit_mult)
	var style: String = e.impact_style
	Combat.hit_enemy(e, d)
	VFX.impact(at, minf(p.height, e.hit_height), -d.direction, style, e.blood_color)
	if d.crit:   # crits get a gold flare so they read at a glance
		var sp := Iso.lift(at, minf(p.height, e.hit_height))
		VFX.burst_sprite(VFX.T.flash_wide, sp, Color(2.6, 1.9, 0.7, 0.9), Vector2(0.25, 0.25), Vector2(0.75, 0.6), 0.09, true, randf() * TAU)
	if p.explode_radius > 0.0:
		_explode(p, at)
	if p.split > 0:
		_split(p, at)
	if p.chain > 0:
		var c := d.copy()
		c.amount *= 0.6
		c.type = DamageInfo.Type.SHOCK
		c.proc_depth += 1
		chain_lightning(e, p.chain, Iso.m(4.0), c)


func _explode(p: Projectile, at: Vector2) -> void:
	var d := p.info.copy()
	d.hit_pos = at
	var col := Color(1.0, 0.55, 0.2)
	if p.kind == &"missile":
		col = Color(1.0, 0.45, 0.25)
	Combat.explode(at, p.explode_radius, d, p.team == 1, col, p.explode_radius > Iso.m(2.2))


func _split(p: Projectile, at: Vector2) -> void:
	var base := p.vel.normalized()
	for k in 3:
		var q := Projectile.new()
		q.team = p.team
		q.pos = at + base * 8.0
		q.prev = q.pos
		q.height = p.height
		q.vel = base.rotated(deg_to_rad(-35.0 + 35.0 * k)) * p.vel.length() * 0.8
		q.info = p.info.copy()
		q.info.amount *= 0.35
		q.info.proc_depth += 1
		q.crit_chance = p.crit_chance
		q.crit_mult = p.crit_mult
		q.max_range = Iso.m(5.0)
		q.kind = &"pellet"
		q.color = p.color
		q.width = p.width * 0.7
		q.length = p.length * 0.5
		q.radius = p.radius
		q.hit_ids = p.hit_ids.duplicate()
		q.weapon = p.weapon
		spawn(q)


func _acid_splat(at: Vector2) -> void:
	VFX.impact(at, 0.1, Vector2.UP, "acid")
	if randf() < 0.5:
		return
	var h := GroundHazard.new()
	h.setup(at, Iso.m(0.9), 2.2, null, "acid")
	if Game.world:
		Game.world.add_hazard(h)


# ------------------------------------------------------------------ hitscan

func fire_arc(owner, w, origin: Vector2, mh: float, dir: Vector2, info: DamageInfo) -> void:
	var end: Vector2 = origin + dir * w.s_range
	var wall := Game.dungeon.raycast(origin, end)
	if wall["hit"]:
		end = wall["point"]
	var h := Game.grid.segment_first(origin, end, Iso.m(0.55))
	var a: Vector2 = owner.muzzle_screen()
	if h.is_empty():
		var stop := origin.lerp(end, randf_range(0.55, 1.0))
		VFX.lightning(a, Iso.lift(stop, mh), Color(1.4, 1.2, 3.2), 3.0, 0.06, 1.3)
		if wall["hit"]:
			VFX.impact(wall["point"], mh, wall["normal"], "energy")
		return
	var e = h["enemy"]
	var d := info.copy()
	d.hit_pos = e.gpos
	d.direction = dir
	Combat.roll_crit(d, w.s_crit, w.s_crit_mult)
	VFX.lightning(a, Iso.lift(e.gpos, e.hit_height), Color(1.6, 1.4, 4.0), 4.5, 0.08, 1.0)
	VFX.lightning(a, Iso.lift(e.gpos, e.hit_height), Color(0.9, 1.6, 3.0), 2.0, 0.06, 1.8)
	VFX.impact(e.gpos, e.hit_height, -dir, "energy")
	Combat.hit_enemy(e, d)
	if w.s_chain > 0:
		var c := info.copy()
		c.amount *= 0.75
		c.proc_depth += 1
		chain_lightning(e, w.s_chain, Iso.m(w.data.chain_range_m), c)
	Audio.play("impact_flesh", e.gpos, -6.0)


## Jumps from `from_e` to up to `count` nearby enemies with line of sight.
func chain_lightning(from_e, count: int, rng: float, info: DamageInfo, color := Color(1.4, 1.6, 4.0)) -> void:
	if info.proc_depth > 3:
		return
	var hit := {from_e.get_instance_id(): true}
	var cur = from_e
	for _i in count:
		var best = null
		var best_d := rng
		for e in Game.grid.query(cur.gpos, rng):
			if hit.has(e.get_instance_id()):
				continue
			var dd: float = e.gpos.distance_to(cur.gpos)
			if dd < best_d and Game.dungeon.has_los(cur.gpos, e.gpos):
				best_d = dd
				best = e
		if best == null:
			break
		hit[best.get_instance_id()] = true
		VFX.lightning(Iso.lift(cur.gpos, cur.hit_height), Iso.lift(best.gpos, best.hit_height), color, 3.5, 0.14, 1.2)
		var d := info.copy()
		d.hit_pos = best.gpos
		d.direction = (best.gpos - cur.gpos).normalized()
		d.knockback *= 0.3
		d.status[&"shock"] = maxf(d.status.get(&"shock", 0.0), 0.35)
		Combat.hit_enemy(best, d)
		VFX.impact(best.gpos, best.hit_height, -d.direction, "energy")
		cur = best
	Audio.play("shock_zap", from_e.gpos)


func fire_rail(owner, w, origin: Vector2, mh: float, dir: Vector2, info: DamageInfo, charge: float) -> void:
	var end: Vector2 = origin + dir * w.s_range
	var wall := Game.dungeon.raycast(origin, end)
	if wall["hit"]:
		end = wall["point"]
	var hits: Array = []
	var skip := {}
	while true:
		var h := Game.grid.segment_first(origin, end, Iso.m(0.25), skip)
		if h.is_empty():
			break
		skip[h["enemy"].get_instance_id()] = true
		hits.append(h)
	var kills := 0
	for h in hits:
		var e = h["enemy"]
		var d := info.copy()
		d.hit_pos = e.gpos
		d.direction = dir
		Combat.roll_crit(d, w.s_crit, w.s_crit_mult)
		var was_alive: bool = e.alive
		VFX.impact(e.gpos, e.hit_height, -dir, e.impact_style, e.blood_color)
		Combat.hit_enemy(e, d)
		if was_alive and not e.alive:
			kills += 1
	var a: Vector2 = owner.muzzle_screen()
	var b := Iso.lift(end, mh)
	var col: Color = w.data.proj_color
	beams.append({"a": a, "b": b, "color": col, "width": 7.0 + 9.0 * charge, "t": 0.28, "dur": 0.28})
	VFX.lightning(a, b, col * 1.5, 2.0, 0.12, 0.35)
	if wall["hit"]:
		VFX.impact(wall["point"], mh, wall["normal"], "energy")
		VFX.light_flash(b, col, 2.0, 3.0, 0.2)
		if Game.dungeon.breakables.has(wall["cell"]):
			Game.dungeon.damage_cell(wall["cell"], info.amount)
	var steps := int(a.distance_to(b) / 70.0)
	for i in steps:
		if i % 2 == 0:
			VFX.emit("electric", a.lerp(b, float(i) / maxf(1, steps)), randf() * TAU, col * 2.0, 0.15)
	if kills >= 2 or (charge >= 0.99 and hits.size() > 0):
		Game.hit_stop(0.06, 0.05)


# ------------------------------------------------------------------ draw

func _draw() -> void:
	for p in list:
		var head := Iso.lift(p.pos, p.height)
		match p.kind:
			&"shard":
				var sd := Iso.to_screen(p.vel).normalized()
				var sn := sd.orthogonal()
				var pts := PackedVector2Array([head + sd * 13.0, head + sn * 5.0, head - sd * 11.0, head - sn * 5.0])
				draw_colored_polygon(pts, p.color * Color(2.4, 2.4, 2.4, 1))
				draw_texture_rect(VFX.T.glow, Rect2(head - Vector2(16, 16), Vector2(32, 32)), false, p.color * Color(1.4, 1.4, 1.4, 0.7))
				draw_line(head - sd * 11.0, head - sd * 34.0, p.color * Color(1.2, 1.2, 1.2, 0.35), 3.0, true)
			&"acid":
				var r := 9.0 + sin(p.age * 30.0) * 1.5
				draw_texture_rect(VFX.T.glow, Rect2(head - Vector2(r, r) * 2.4, Vector2(r, r) * 4.8), false, p.color * Color(1.6, 1.6, 1.6, 0.9))
				draw_circle(head, r * 0.55, Color(2.2, 3.5, 1.2))
				draw_circle(Iso.to_screen(p.pos), 6.0, Color(0.4, 1.0, 0.2, 0.25))
			&"grenade", &"missile":
				if p.trail.size() > 1:
					var cols := PackedColorArray()
					for k in p.trail.size():
						var a: float = float(k) / p.trail.size()
						cols.append(Color(1.0, 0.5, 0.2, a * 0.6) if p.kind == &"missile" else Color(1.0, 0.7, 0.4, a * 0.35))
					draw_polyline_colors(p.trail, cols, 3.0 if p.kind == &"missile" else 4.0, true)
				var blink := 1.0 + 0.6 * sin(p.age * 40.0)
				draw_texture_rect(VFX.T.glow, Rect2(head - Vector2(18, 18), Vector2(36, 36)), false, p.color * Color(2, 2, 2, 0.8) * blink)
				draw_circle(head, 4.5, Color(4, 3, 2))
				if p.lob:
					draw_circle(Iso.to_screen(p.pos), 5.0 + p.height * 2.0, Color(1.0, 0.4, 0.1, 0.18))
			_:
				var sdir := Iso.to_screen(p.vel).normalized()
				var l := minf(p.length, p.traveled + 12.0)
				var tail := head - sdir * l
				var c: Color = p.color
				var gw: float = p.width * 4.5
				draw_texture_rect(VFX.T.glow, Rect2(head - Vector2(gw, gw), Vector2(gw, gw) * 2.0), false, c * Color(1.5, 1.4, 1.3, 0.55))
				draw_line(tail, head, c * Color(1, 1, 1, 0.35), p.width * 3.2, true)
				draw_line(tail.lerp(head, 0.25), head, c * Color(2.4, 2.4, 2.4, 1), p.width * 1.15, true)
				draw_circle(head, p.width * 0.8, Color(3.5, 3.5, 3.5))
	for b in beams:
		var k: float = b["t"] / b["dur"]
		var c: Color = b["color"]
		draw_line(b["a"], b["b"], c * Color(1.2, 1.2, 1.2, 0.35 * k), b["width"] * 2.8 * k, true)
		draw_line(b["a"], b["b"], c * Color(2.5, 2.5, 2.5, k), b["width"] * k, true)
		draw_line(b["a"], b["b"], Color(4, 4, 4, k), b["width"] * 0.3 * k, true)
