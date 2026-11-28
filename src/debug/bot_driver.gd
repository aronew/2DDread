class_name BotDriver
extends Node
## Automated playtester. Launch with:
##   godot -- --bot --shots=/tmp/shots --quit-after=90
## Plays through the dungeon route (kiting, weapon swaps by range, dodging
## telegraphs, abilities, executes), saves periodic screenshots and prints a
## combat log so balance and stability can be checked without a human.

var enabled := false
var no_dodge := false
var inv_shot := false
var _inv_done := false
var human := false
var _aim := Vector2.ZERO
var _jitter := Vector2.ZERO
var _jitter_t := 0.0
var _last_target = null
var _switch_t := 0.0
var shots_dir := ""
var shot_every := 4.0
var quit_after := 0.0
var _start_ms := 0
var _shot_t := 2.0
var _shot_n := 0
var _log_t := 5.0
var _route := ["landing", "conduit", "hatchery", "spine", "reactor", "exit"]
var _route_i := 0
var _strafe := 1.0
var _strafe_t := 0.0
var _dash_t := 0.0
var _hold_t := 0.0   # keeps the sword button down to chain the combo
var _loot_target = null
var _loot_t := 0.0
var _skip_loot := {}
var _fire_toggle := false
var _bfs_cache := {}
var _stuck_t := 0.0
var _last_g := Vector2.ZERO
var stats := {"kills": 0, "deaths": 0, "dmg_taken": 0.0, "shots": 0, "items": 0, "levels": 0, "elite_kills": 0}


func configure(opts: Dictionary) -> void:
	enabled = opts.has("bot")
	no_dodge = opts.has("bot-nododge")
	inv_shot = opts.has("inv-shot")
	human = opts.has("bot-human")
	shots_dir = opts.get("shots", "")
	shot_every = float(opts.get("shot-every", "4"))
	quit_after = float(opts.get("quit-after", "0"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_ms = Time.get_ticks_msec()
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	var start: String = Game.world.get_meta("start_room", "") if Game.world.has_meta("start_room") else ""
	var ids: Array = Game.world.director.rooms.map(func(r): return r.id)
	if start != "" and _route.has(start):
		_route_i = _route.find(start)
	elif start != "" or not ids.has(_route[0]):
		# another level (the temple dungeon): its rooms in layout order from the start room
		_route = (ids.slice(ids.find(start)) if ids.has(start) else ([start] if start != "" else ids)) + ["exit"]
	if enabled:
		Game.bot_mode = true
		Game.player.input_override = self
	Events.enemy_killed.connect(func(e, _i):
		stats["kills"] += 1
		if e.is_elite: stats["elite_kills"] += 1)
	Events.player_died.connect(func(): stats["deaths"] += 1)
	Events.player_damaged.connect(func(_i, a): stats["dmg_taken"] += a)
	Events.shot_fired.connect(func(_w): stats["shots"] += 1)
	Events.item_picked.connect(func(_i): stats["items"] += 1)
	Events.level_up.connect(func(_l): stats["levels"] += 1)
	Events.room_cleared.connect(func(r): print("[bot] cleared ", r.id, " at ", _elapsed(), "s"))
	Events.depth_changed.connect(func(d): print("[bot] descended to depth ", d); _route_i = 0)


var _game_t := 0.0


## Unscaled game time (works with --fixed-fps for deterministic captures).
func _elapsed() -> float:
	return _game_t


func _process(dt: float) -> void:
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	_game_t += real_dt
	if shots_dir != "":
		_shot_t -= real_dt
		if _shot_t <= 0.0:
			_shot_t = shot_every
			_shot()
	_log_t -= real_dt
	if _log_t <= 0.0:
		_log_t = 10.0
		_log()
	if inv_shot and not _inv_done and _elapsed() > 2.0:
		_inv_done = true
		_inventory_test()
	if quit_after > 0.0 and _elapsed() >= quit_after:
		_log()
		print("[bot] FINAL ", stats)
		print("[bot] sword ", Game.player.blade.stats)
		get_tree().quit()


## Fills the backpack with rolled loot of every rarity, opens the inventory,
## equips + salvages through the real code paths, and screenshots it.
func _inventory_test() -> void:
	var pl = Game.player
	for r in 6:
		pl.inventory_add(Loot.make_weapon(WeaponDB.LOOTABLE[r % 4], r, 3))
		pl.inventory_add(Loot.make_gear([&"armor", &"core", &"relic"][r % 3], r, 3))
	pl.build.attr_points = 3
	Game.hud.toggle_inventory()
	await get_tree().process_frame
	pl.equip(pl.backpack[pl.backpack.size() - 2])
	pl.build.spend_point("might")
	Game.hud.inventory.refresh()
	Game.hud.inventory._show(pl.backpack[0] if not pl.backpack.is_empty() else null)
	for i in 4:
		await get_tree().process_frame
	if shots_dir != "":
		get_viewport().get_texture().get_image().save_png(shots_dir + "/inventory.png")
	print("[bot] inventory test ok: backpack=", pl.backpack.size(), " weapon=", pl.cur_weapon().display_name())
	Game.hud.toggle_inventory()


func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/shot_%03d.png" % [shots_dir, _shot_n]
	img.save_png(path)
	if Game.world.has_meta("paint_guide"):
		# where this frame looks, so a painting made from it can be laid back on the room
		var cam := Game.camera
		var c := cam.get_screen_center_position()
		# world (Node2D) position -> image pixel: the stretch transform times the camera's
		var t: Transform2D = get_viewport().get_final_transform() * get_viewport().get_canvas_transform()
		var info := {"screen_center": [c.x, c.y], "zoom": cam.zoom.x, "size": [img.get_width(), img.get_height()],
			"world_to_image": [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]}
		var f := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(info, " "))
	_shot_n += 1


func _log() -> void:
	var pl = Game.player
	var room = Game.world.director.active
	print("[bot] t=%.0fs fps=%d hp=%d/%d lvl=%d enemies=%d proj=%d room=%s route=%s cell=%s %s" % [
		_elapsed(), Engine.get_frames_per_second(), pl.hp, pl.max_hp, pl.level, Game.living_enemies(),
		Game.projectiles.list.size(), room.id if room else "-", _route[mini(_route_i, _route.size() - 1)],
		Iso.cell_of(pl.gpos), stats])
	# the last few enemies and where they are: a stalled room usually means one is stuck
	if Game.living_enemies() > 0 and Game.living_enemies() <= 3:
		var left: Array = []
		for e in Game.enemies:
			if is_instance_valid(e) and e.alive:
				left.append("%s@%s:%s" % [e.data.id, Iso.cell_of(e.gpos), Enemy.S.keys()[e.state]])
		print("[bot]   left: ", ", ".join(left))
	# active nests keep a room from clearing: where they are and how hurt
	var ns: Array = []
	for pr in Game.dungeon.props:
		if pr.alive and pr.nest_active:
			ns.append("%s hp %d" % [Iso.cell_of(pr.gpos), int(pr.hp)])
	if not ns.is_empty():
		var t = _pick_target(pl)
		var tn: String = "-" if t == null else ("nest" if t is Prop else String(t.data.id))
		print("[bot]   nests: ", ", ".join(ns), "  target: ", tn)


# ------------------------------------------------------------------ brain

func state(p) -> Dictionary:
	var s := {"move": Vector2.ZERO, "stick": Vector2.ZERO, "mouse": p.position + Vector2(100, 0),
		"fire": false, "fire_pressed": false, "fire_released": false, "alt": false, "alt_pressed": false}
	for a in ["dash", "ability_1", "ability_2", "melee", "reload", "weapon_1", "weapon_2", "weapon_3", "weapon_next", "weapon_prev"]:
		s[a] = false
	if not p.alive:
		return s
	var dt := get_process_delta_time()
	_dash_t -= dt
	_hold_t -= dt
	var target = _pick_target(p)
	if target != null:
		_fight(p, target, s, dt)
	else:
		_navigate(p, s, dt)
	_avoid_geysers(p, s)
	s["melee_held"] = _hold_t > 0.0
	return s


## Like a player reading the red ring: don't step into a geyser that is warning or erupting,
## and get out of one (dash if it is about to blow) when standing in it.
func _avoid_geysers(p, s: Dictionary) -> void:
	var mv: Vector2 = s["move"]
	var here := SoulGeyser.danger_at(get_tree(), p.gpos, p.radius + Iso.m(0.3))
	if here:
		var away: Vector2 = (p.gpos - here.hit_g).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		# leave along the way we were going if that also leads out, else straight out
		s["move"] = (mv * 0.6 + away).normalized() if mv.dot(away) > -0.2 else away
		if not no_dodge and p.dash_charges > 0 and _dash_t <= 0.0 and here._phase == 1 and here._state(here._t).y > 0.6:
			s["dash"] = true
			_dash_t = 0.6
		return
	if mv != Vector2.ZERO and SoulGeyser.danger_at(get_tree(), p.gpos + mv * Iso.m(1.2), p.radius):
		s["move"] = Vector2.ZERO   # wait at the bridge end for it to pass


func _pick_target(p):
	var best = null
	var best_d := Iso.m(15.0)
	for e in Game.enemies:
		if not e.alive or e.state == Enemy.S.SPAWN:
			continue
		var d: float = e.gpos.distance_to(p.gpos)
		if e.is_elite:
			d *= 0.8
		if e.data.id == &"bloater" and d < Iso.m(7.0):
			d *= 0.5
		if d < best_d and Game.dungeon.has_los(p.gpos, e.gpos):
			best_d = d
			best = e
	# like a player: break active nests (they spawn hounds without end) unless an enemy is
	# right on top of us
	if best == null or best_d > Iso.m(3.5):
		var nest = null
		var nest_d := Iso.m(14.0)
		for pr in Game.dungeon.props:
			if pr.alive and pr.nest_active and _clear_shot(p.gpos, pr.gpos):
				var dd: float = pr.gpos.distance_to(p.gpos)
				if dd < nest_d:
					nest_d = dd
					nest = pr
		if nest != null:
			return nest
	return best


## Line of sight wide enough for a bullet: a thin ray can graze past a column that the
## shot itself clips (the altar's nest beside a column kept the bot firing into stone).
func _clear_shot(a: Vector2, b: Vector2) -> bool:
	var side := (b - a).orthogonal().normalized() * Iso.m(0.25)
	return Game.dungeon.has_los(a, b) and Game.dungeon.has_los(a + side, b + side) \
		and Game.dungeon.has_los(a - side, b - side)


func _fight(p, t, s: Dictionary, dt: float) -> void:
	var tg: Vector2 = t.gpos
	var hh: float = t.hit_height if "hit_height" in t else 0.5
	s["mouse"] = Iso.lift(tg, hh)
	if human:
		# reaction delay on target switches, lagging + noisy tracking
		if t != _last_target:
			_last_target = t
			_switch_t = 0.22
		_switch_t -= dt
		_jitter_t -= dt
		if _jitter_t <= 0.0:
			_jitter_t = 0.35
			_jitter = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Iso.m(0.9)
		var want_aim: Vector2 = s["mouse"] + Iso.to_screen(_jitter)
		if _aim == Vector2.ZERO:
			_aim = want_aim
		_aim = _aim.lerp(want_aim, 1.0 - exp(-6.0 * dt))
		s["mouse"] = _aim
		if _switch_t > 0.0:
			s["fire"] = false
	var to: Vector2 = tg - p.gpos
	var dist := to.length()
	var dir := to.normalized()
	# weapon by range
	var want := 0
	if dist < Iso.m(4.0):
		want = 1
	elif dist < Iso.m(8.0) and p.weapons[2] and not p.weapons[2].overheated and not t is Prop:
		want = 2   # (the Stormcaller's arcs only find enemies: nests and urns need bullets)
	if p.cur != want and p.weapons[want] != null:
		s["weapon_%d" % (want + 1)] = true
	var w = p.cur_weapon()
	if w and w.data.fire_mode == "semi":
		_fire_toggle = not _fire_toggle
		s["fire_pressed"] = _fire_toggle
		s["fire"] = true
	elif w and w.data.fire_mode == "charge":
		s["fire"] = w.charge < 0.95
		s["fire_released"] = w.charge >= 0.95
	else:
		s["fire"] = true
	if human and _switch_t > 0.0:
		s["fire"] = false
		s["fire_pressed"] = false
	# movement: hold a preferred band, strafe, avoid walls
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe = -_strafe
		_strafe_t = randf_range(1.2, 2.6)
	var pref := Iso.m(5.0)
	var radial := clampf((dist - pref) / Iso.m(2.0), -1.0, 1.0)
	var mv := dir * radial + dir.orthogonal() * _strafe * 0.9
	if Game.dungeon.raycast(p.gpos, p.gpos + mv.normalized() * Iso.m(1.5), "walk").hit:
		_strafe = -_strafe
		mv = dir * radial + dir.orthogonal() * _strafe
	s["move"] = mv.normalized()
	# threats: dodge active wind-ups and incoming acid
	var close := 0
	var cluster := 0
	for e in Game.enemies:
		if not e.alive:
			continue
		var d: float = e.gpos.distance_to(p.gpos)
		if d < Iso.m(4.0):
			close += 1
		if d < Iso.m(12.0):
			cluster += 1
		if not no_dodge and e.state == Enemy.S.WINDUP and d < Iso.m(4.5) and _dash_t <= 0.0 and p.dash_charges > 0:
			s["dash"] = true
			s["move"] = (p.gpos - e.gpos).normalized().orthogonal() * _strafe
			_dash_t = 0.6
		if e.state == Enemy.S.STAGGER and d < Iso.m(Blade.MAGNET_M) and Game.dungeon.has_los(p.gpos, e.gpos):
			s["melee"] = true   # sword execute: the lunge snaps onto it
			s["mouse"] = Iso.lift(e.gpos, e.hit_height)
	for q in Game.projectiles.list:
		if not no_dodge and q.team == 1 and q.pos.distance_to(p.gpos) < Iso.m(2.0) and _dash_t <= 0.0 and p.dash_charges > 0:
			s["dash"] = true
			s["move"] = q.vel.normalized().orthogonal()
			_dash_t = 0.5
	if close >= 3:
		s["ability_1"] = true
	if cluster >= 4:
		s["ability_2"] = true
	if t is Enemy:
		# close in with the sword when an enemy is in lunge reach (not a shielded front),
		# chaining the combo; dash first now and then to open with the thrust
		var shielded: bool = t.armor_hp > 0.0 and t.facing.dot(-dir) > 0.45
		if dist < Iso.m(Blade.MAGNET_M - 0.6) and not shielded:
			s["melee"] = true
			_hold_t = 0.25
			if dist > Iso.m(2.8) and p.dash_charges > 1 and _dash_t <= 0.0 and not human:
				s["dash"] = true
				s["move"] = dir
				_dash_t = 0.5
	if cluster >= 3 and dist > Iso.m(5.0) and p.launcher.mag > 0:
		s["alt_pressed"] = true
	if not no_dodge and p.hp < p.max_hp * 0.35 and close >= 2 and p.dash_charges > 0 and _dash_t <= 0.0:
		s["dash"] = true
		s["move"] = -dir
		_dash_t = 0.8


func _navigate(p, s: Dictionary, dt: float) -> void:
	var dir_node = Game.world.director
	var target_cell := Vector2i(-999, -999)
	# loot first: walk over nearby items it can walk straight to (an altar or a brazier in
	# the way would pin it); give up on an item it can't reach within a few seconds
	for n in Game.world.entities.get_children():
		if n is Pickup and n.kind == &"item" and n.gpos.distance_to(p.gpos) < Iso.m(8.0) \
				and not _skip_loot.has(n.get_instance_id()) and not Game.dungeon.raycast(p.gpos, n.gpos, "walk").hit:
			if n != _loot_target:
				_loot_target = n
				_loot_t = 0.0
			_loot_t += dt
			if _loot_t > 4.0:
				_skip_loot[n.get_instance_id()] = true
				continue
			s["move"] = (n.gpos - p.gpos).normalized()
			s["mouse"] = Iso.lift(n.gpos, 0.5)
			return
	# an active nest out of sight (behind a column): go to it, it won't stop spawning
	var nest_c := Vector2i(-999, -999)
	var nest_d := INF
	for pr in Game.dungeon.props:
		if pr.alive and pr.nest_active and pr.gpos.distance_to(p.gpos) < nest_d:
			nest_d = pr.gpos.distance_to(p.gpos)
			nest_c = Iso.cell_of(pr.gpos)
	if nest_c.x != -999:
		target_cell = nest_c
	# enemies left but none in sight (behind a column): go and find the nearest one
	if target_cell.x == -999 and dir_node.active != null:
		var best_d := INF
		for e in Game.enemies:
			if e.alive and not e.data.flying and not Game.dungeon.walk_blocked(Iso.cell_of(e.gpos)) \
					and e.gpos.distance_to(p.gpos) < best_d:
				best_d = e.gpos.distance_to(p.gpos)
				target_cell = Iso.cell_of(e.gpos)
	while target_cell.x == -999 and _route_i < _route.size():
		var id: String = _route[_route_i]
		if id == "exit":
			if Game.world.portal and Game.world.portal.active:
				target_cell = Game.dungeon.exit_cell
			break
		var room = null
		for r in dir_node.rooms:
			if r.id == id:
				room = r
		if room == null or room.state == "cleared":
			_route_i += 1
			continue
		target_cell = Vector2i(room.rect.get_center())
		break
	if target_cell.x == -999:
		return
	var field := _bfs(target_cell)
	var c := Iso.cell_of(p.gpos)
	var best := c
	var best_d: int = field.get(c, 99999)
	for o in Dungeon.NEIGH8:
		var n: Vector2i = c + o
		if field.has(n) and field[n] < best_d:
			if o.x != 0 and o.y != 0 and (not field.has(Vector2i(c.x + o.x, c.y)) or not field.has(Vector2i(c.x, c.y + o.y))):
				continue
			best_d = field[n]
			best = n
	var goal := Iso.cell_center(best) if best != c else Iso.cell_center(target_cell)
	s["move"] = (goal - p.gpos).normalized()
	s["mouse"] = Iso.lift(p.gpos + s["move"] * Iso.m(4.0), 1.2)
	# unstick
	if p.gpos.distance_to(_last_g) < 2.0:
		_stuck_t += dt
		if _stuck_t > 1.0:
			s["move"] = s["move"].rotated(randf_range(-1.5, 1.5))
			s["dash"] = true
			_stuck_t = 0.0
			_bfs_cache.clear()
	else:
		_stuck_t = 0.0
	_last_g = p.gpos


func _bfs(target: Vector2i) -> Dictionary:
	if _bfs_cache.has(target):
		return _bfs_cache[target]
	var d: Dungeon = Game.dungeon
	var field := {target: 0}
	var q: Array[Vector2i] = [target]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for o in Dungeon.NEIGH8:
			var n: Vector2i = c + o
			if field.has(n) or d.walk_blocked(n):
				continue
			if o.x != 0 and o.y != 0 and (d.walk_blocked(Vector2i(c.x + o.x, c.y)) or d.walk_blocked(Vector2i(c.x, c.y + o.y))):
				continue
			field[n] = field[c] + 1
			q.append(n)
	_bfs_cache[target] = field
	if _bfs_cache.size() > 8:
		_bfs_cache.clear()
	return field
