class_name EncounterDirector
extends Node
## Room-based encounters. Entering a room starts its beats; locked rooms seal
## their doors until every beat is cleared (Doom arena style). Beats trigger
## when the previous wave thins out, keeping momentum without wave timers.

class Room:
	var id := ""
	var title := ""
	var rect := Rect2i()
	var lock := false
	var secret := false
	var beats: Array = []
	var reward := ""
	var exit := false
	var state := "idle"     # idle | active | cleared
	var beat_i := 0
	var delay_t := 0.0
	var enemies: Array = []
	var doors: Array = []
	var nests: Array = []
	var spawn_queue: Array = []

	func alive_count() -> int:
		var n := 0
		for e in enemies:
			if is_instance_valid(e) and e.alive:
				n += 1
		return n

	func nests_alive() -> int:
		var n := 0
		for p in nests:
			if is_instance_valid(p) and p.alive and p.nest_active:
				n += 1
		return n


var rooms: Array = []
var active: Room = null
var checkpoint := Vector2.ZERO
var dungeon: Dungeon
var world
var _rng := RandomNumberGenerator.new()


func setup(defs: Array, dungeon_: Dungeon, world_) -> void:
	dungeon = dungeon_
	world = world_
	_rng.seed = 99 + Game.depth
	for d in defs:
		var r := Room.new()
		r.id = d["id"]
		r.title = d["name"]
		var a: Array = d["rect"]
		r.rect = Rect2i(a[0], a[1], a[2] - a[0] + 1, a[3] - a[1] + 1)
		r.lock = d.get("lock", false)
		r.secret = d.get("secret", false)
		r.beats = d["beats"]
		r.reward = d.get("reward", "")
		r.exit = d.get("exit", false)
		var grown := r.rect.grow(1)
		for c in dungeon.door_cells:
			if grown.has_point(c) and not r.rect.has_point(c):
				r.doors.append(c)
		for p in dungeon.props:
			if p.kind == "eggs" and r.rect.has_point(Iso.cell_of(p.gpos)):
				r.nests.append(p)
			if p.kind == "chest" and r.rect.has_point(Iso.cell_of(p.gpos)):
				p.chest_locked = r.lock
				p.chest_quality = "epic"
		rooms.append(r)
	checkpoint = Iso.cell_center(dungeon.start_cell)


func room_at(c: Vector2i) -> Room:
	for r in rooms:
		if r.rect.has_point(c):
			return r
	return null


func _process(dt: float) -> void:
	var pl = Game.player
	if pl == null or not pl.alive:
		return
	var c := Iso.cell_of(pl.gpos)
	var r := room_at(c)
	if r and r.state == "idle" and _inside_enough(r, c):
		_activate(r)
	for room in rooms:
		if room.state == "active":
			_update_room(room, dt)


func _inside_enough(r: Room, c: Vector2i) -> bool:
	if not r.lock:
		return true
	return r.rect.grow(-1).has_point(c) or (r.rect.size.x <= 3 or r.rect.size.y <= 3)


func _activate(r: Room) -> void:
	r.state = "active"
	r.beat_i = 0
	active = r
	Events.room_entered.emit(r)
	Events.message.emit(r.title, Color(0.85, 0.9, 1.0) if not r.secret else Color(1.0, 0.8, 0.35))
	if r.lock and not r.doors.is_empty():
		dungeon.set_doors_locked(r.doors, true)
		Audio.play("door_lock")
		Events.room_locked.emit(r)
		Events.message.emit("AREA LOCKED", Color(1.0, 0.3, 0.25))
	_try_start_beat(r, true)


func _try_start_beat(r: Room, entering: bool) -> void:
	if r.beat_i >= r.beats.size():
		return
	var b: Dictionary = r.beats[r.beat_i]
	var trig = b.get("trigger", "enter")
	if trig is String:
		if trig == "enter" and entering:
			_spawn_beat(r, b)
		elif trig == "enter_delay" and entering:
			r.delay_t = b.get("delay", 1.0)


func _update_room(r: Room, dt: float) -> void:
	# staggered spawn queue (enemies arrive over a short window, not all at once)
	if not r.spawn_queue.is_empty():
		var q: Dictionary = r.spawn_queue[0]
		q["t"] -= dt
		if q["t"] <= 0.0:
			r.spawn_queue.pop_front()
			var e = world.spawn_enemy(q["id"], q["g"], q["opts"])
			if e:
				e.room = r
				r.enemies.append(e)
	if r.delay_t > 0.0:
		r.delay_t -= dt
		if r.delay_t <= 0.0 and r.beat_i < r.beats.size():
			_spawn_beat(r, r.beats[r.beat_i])
		return
	var alive := r.alive_count() + r.spawn_queue.size()
	if r.beat_i < r.beats.size():
		var b: Dictionary = r.beats[r.beat_i]
		var trig = b.get("trigger", "enter")
		if trig is Dictionary and alive <= int(trig.get("remaining", 0)) and r.nests_alive() == 0:
			_spawn_beat(r, b)
		return
	if alive == 0 and r.nests_alive() == 0:
		_clear(r)


func _spawn_beat(r: Room, b: Dictionary) -> void:
	r.beat_i += 1
	Events.encounter_beat.emit(r, r.beat_i)
	var pl = Game.player
	var t := 0.0
	var k := 0
	var base_angle := _rng.randf() * TAU
	for entry in b.get("spawn", []):
		var id: String = entry[0]
		var n: int = entry[1]
		var opts: Dictionary = entry[2] if entry.size() > 2 else {}
		if Game.depth >= 2 and id == "mite":
			n += Game.depth - 1
		for i in n:
			var g: Vector2
			if opts.has("area"):
				# placed in a set part of the level, e.g. up on a balcony over the room
				var ar: Array = opts["area"]
				var rect := Rect2i(ar[0], ar[1], ar[2] - ar[0] + 1, ar[3] - ar[1] + 1)
				g = dungeon.random_floor_in(rect, pl.gpos, Iso.m(4.0), _rng, false)
			elif opts.has("elite") or id == "brute":
				g = dungeon.random_floor_in(r.rect, pl.gpos, Iso.m(8.0), _rng, true)
			else:
				# groups arrive from 3 directions around the player, including behind
				var a := base_angle + (k % 3) * TAU / 3.0
				g = dungeon.ring_floor_in(r.rect, pl.gpos, Iso.m(6.5), Iso.m(11.0), a, _rng)
			k += 1
			r.spawn_queue.append({"id": id, "g": g, "opts": opts, "t": t})
			t = 0.06 + _rng.randf() * 0.08
	if b.get("nests", false):
		for p in r.nests:
			if is_instance_valid(p) and p.alive:
				p.nest_active = true
		if r.nests_alive() > 0:
			Events.message.emit("DESTROY THE NESTS", Color(0.5, 1.0, 0.5))
	if b.get("boss", false):
		Events.message.emit("ELITE INBOUND", Color(1.0, 0.6, 0.2))


func _clear(r: Room) -> void:
	r.state = "cleared"
	if active == r:
		active = null
	for p in r.nests:
		if is_instance_valid(p):
			p.nest_active = false
	if r.lock and not r.doors.is_empty():
		dungeon.set_doors_locked(r.doors, false)
		Audio.play("door_open")
	for p in dungeon.props:
		if p.kind == "chest" and r.rect.has_point(Iso.cell_of(p.gpos)):
			p.chest_locked = false
	checkpoint = Iso.cell_center(Vector2i(r.rect.get_center()))
	Events.room_cleared.emit(r)
	if r.lock or r.beats.size() > 1:
		Events.message.emit(r.title + " CLEARED", Color(0.5, 1.0, 0.7))
	match r.reward:
		"chest":
			_reward_chest(r, "epic")
		"legendary":
			_reward_chest(r, "legendary")
	if r.exit:
		world.open_exit()


func _reward_chest(r: Room, quality: String) -> void:
	var c := Vector2i(r.rect.get_center())
	for i in 12:
		if dungeon.is_floor(c) and not dungeon.props_by_cell.has(c):
			break
		c += Vector2i(1, 0) if i % 2 == 0 else Vector2i(0, 1)
	var p := dungeon.add_prop(c, "chest")
	p.chest_quality = quality
	VFX.ring(p.gpos, Iso.m(3.0), Color(1.0, 0.75, 0.3), 0.6)
	VFX.light_flash(Iso.lift(p.gpos, 1.0), Color(1.0, 0.75, 0.3), 3.0, 5.0, 1.0)


## Player died: reset the active encounter so it can be retried.
func reset_active() -> Vector2:
	for r in rooms:
		if r.state == "active":
			for e in r.enemies:
				if is_instance_valid(e) and e.alive:
					e.no_loot = true
					e.alive = false
					Game.unregister_enemy(e)
					e.queue_free()
			r.enemies.clear()
			r.spawn_queue.clear()
			r.state = "idle"
			r.beat_i = 0
			r.delay_t = 0.0
			for p in r.nests:
				if is_instance_valid(p):
					p.nest_active = false
			if r.lock:
				dungeon.set_doors_locked(r.doors, false)
	active = null
	return checkpoint
