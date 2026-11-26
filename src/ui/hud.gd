class_name HUD
extends CanvasLayer
## In-game HUD drawn procedurally (crisp at any resolution, no texture assets
## required): health, dash, abilities, weapons, XP, minimap, elite bar, loot
## feed, messages, crosshair. Also hosts the inventory screen.

var draw_root: HudDraw
var inventory: InventoryUI


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.hud = self
	draw_root = HudDraw.new()
	draw_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draw_root)
	inventory = InventoryUI.new()
	inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory.visible = false
	add_child(inventory)


var paused_menu := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or (inventory.visible and event.is_action_pressed("pause")):
		if not paused_menu:
			toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		paused_menu = not paused_menu
		get_tree().paused = paused_menu
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused_menu else Input.MOUSE_MODE_HIDDEN
		get_viewport().set_input_as_handled()
	elif paused_menu and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_R:
			paused_menu = false
			get_tree().paused = false
			Game.depth = 1
			Game.enemies.clear()
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_Q:
			get_tree().quit()


func toggle_inventory() -> void:
	inventory.visible = not inventory.visible
	get_tree().paused = inventory.visible
	if inventory.visible:
		inventory.refresh()
		Audio.play("ui_click")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory.visible else Input.MOUSE_MODE_HIDDEN


class HudDraw extends Control:
	var font: Font
	var bold: FontVariation
	var messages: Array = []
	var feed: Array = []
	var _t := 0.0
	var _hp_shown := 1.0
	var _hint_t := 14.0
	var _fps_t := 0.0

	func _ready() -> void:
		font = ThemeDB.fallback_font
		bold = FontVariation.new()
		bold.base_font = font
		bold.variation_embolden = 0.9
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		Events.message.connect(func(t, c): messages.append({"t": 0.0, "text": t, "c": c}))
		Events.item_picked.connect(_on_item)

	func _on_item(it) -> void:
		feed.push_front({"t": 0.0, "text": "%s  ·  %s" % [it.display_name(), it.rarity_name()], "c": it.color()})
		if feed.size() > 6:
			feed.pop_back()

	func _process(dt: float) -> void:
		_t += dt
		_hint_t -= dt
		for m in messages:
			m["t"] += dt
		messages = messages.filter(func(m): return m["t"] < 3.2)
		if messages.size() > 3:
			messages = messages.slice(messages.size() - 3)
		for f in feed:
			f["t"] += dt
		feed = feed.filter(func(f): return f["t"] < 6.0)
		queue_redraw()

	func _text(pos: Vector2, s: String, size: int, col: Color, f: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 5) -> void:
		var ff := f if f else font
		draw_string_outline(ff, pos, s, align, width, size, outline, Color(0, 0, 0, 0.85 * col.a))
		draw_string(ff, pos, s, align, width, size, col)

	func _skew_rect(x: float, y: float, w: float, h: float, col: Color, filled := true) -> void:
		var k := h * 0.35
		var pts := PackedVector2Array([Vector2(x + k, y), Vector2(x + w + k, y), Vector2(x + w, y + h), Vector2(x, y + h)])
		if filled:
			draw_colored_polygon(pts, col)
		else:
			pts.append(pts[0])
			draw_polyline(pts, col, 2.0)

	func _draw() -> void:
		var pl = Game.player
		if pl == null:
			return
		var vs := get_viewport_rect().size
		_draw_health(pl, vs)
		_draw_abilities(pl, vs)
		_draw_weapons(pl, vs)
		_draw_xp(pl, vs)
		_draw_minimap(pl, vs)
		_draw_elite(pl, vs)
		_draw_messages(vs)
		_draw_feed(vs)
		_draw_room(vs)
		if _hint_t > 0.0:
			var a := clampf(_hint_t / 2.0, 0.0, 1.0)
			_text(Vector2(0, vs.y - 30), "WASD move · Mouse aim · LMB fire · RMB launcher · SPACE dash · Q nova · E seekers · F rend/execute · R reload · 1-3 weapons · TAB inventory",
				17, Color(0.8, 0.85, 0.9, 0.85 * a), null, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if not pl.alive:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(0.2, 0.0, 0.0, 0.35))
			_text(Vector2(0, vs.y * 0.45), "YOU DIED", 84, Color(1.0, 0.2, 0.2), bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 10)
		_draw_offscreen(pl, vs)
		if get_parent().paused_menu:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0.02, 0.03, 0.7))
			_text(Vector2(0, vs.y * 0.42), "PAUSED", 72, Color(0.85, 0.95, 1.0), bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 10)
			_text(Vector2(0, vs.y * 0.42 + 60), "ESC resume   ·   R restart run   ·   Q quit", 22, Color(0.7, 0.8, 0.85), null, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if Game.debug:
			_text(Vector2(20, 30), "FPS %d  enemies %d  projectiles %d  depth %d" % [Engine.get_frames_per_second(), Game.living_enemies(), Game.projectiles.list.size() if Game.projectiles else 0, Game.depth], 18, Color(0.6, 1.0, 0.6))
		if not get_tree().paused:
			_draw_crosshair(pl)

	# -------------------------------------------------------------- health / dash

	func _draw_health(pl, vs: Vector2) -> void:
		var x := 40.0
		var y := vs.y - 168.0
		var w := 400.0
		var h := 30.0
		var frac: float = clampf(pl.hp / pl.max_hp, 0.0, 1.0)
		_hp_shown = move_toward(_hp_shown, frac, get_process_delta_time() * 0.6) if _hp_shown > frac else frac
		_skew_rect(x - 6, y - 6, w + 12, h + 12, Color(0.02, 0.05, 0.06, 0.8))
		_skew_rect(x - 6, y - 6, w + 12, h + 12, Color(0.2, 0.9, 0.8, 0.5), false)
		var segs := 12
		var sw := w / segs
		for i in segs:
			var s0 := float(i) / segs
			var fill := clampf((frac - s0) * segs, 0.0, 1.0)
			var lag := clampf((_hp_shown - s0) * segs, 0.0, 1.0)
			_skew_rect(x + i * sw + 2, y, (sw - 4), h, Color(0.25, 0.04, 0.05, 0.9))
			if lag > 0.0:
				_skew_rect(x + i * sw + 2, y, (sw - 4) * lag, h, Color(1.0, 0.85, 0.75, 0.6))
			if fill > 0.0:
				var c := Color(0.95, 0.12, 0.14)
				if frac < 0.3:
					c = c.lerp(Color(1.0, 0.5, 0.4), 0.5 + 0.5 * sin(_t * 10.0))
				_skew_rect(x + i * sw + 2, y, (sw - 4) * fill, h, c)
		_text(Vector2(x + 14, y + 23), "%d / %d" % [int(ceil(pl.hp)), int(pl.max_hp)], 20, Color(1, 0.95, 0.95), bold)
		# dash pips
		for i in pl.dash_max:
			var px: float = x + 10 + i * 30
			var py := y + h + 18
			var pts := PackedVector2Array([Vector2(px, py - 9), Vector2(px + 9, py), Vector2(px, py + 9), Vector2(px - 9, py)])
			var ready: bool = i < pl.dash_charges
			draw_colored_polygon(pts, Color(0.4, 0.75, 1.0, 1.0) if ready else Color(0.1, 0.18, 0.25, 0.9))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.6, 0.9, 1.0, 0.8), 1.5)
		_text(Vector2(x + 10 + pl.dash_max * 30, y + h + 25), "DASH", 15, Color(0.6, 0.85, 1.0, 0.8))
		var lv: String = "LV %d" % pl.level
		if pl.build.attr_points > 0:
			lv += "   +%d POINTS [TAB]" % pl.build.attr_points
		_text(Vector2(x + 190, y + h + 25), lv, 16, Color(1.0, 0.85, 0.4) if pl.build.attr_points > 0 else Color(0.8, 0.85, 0.9))

	func _draw_abilities(pl, vs: Vector2) -> void:
		var items: Array = [pl.abilities[0], pl.abilities[1], pl.rend]
		var x := 40.0
		var y := vs.y - 96.0
		for i in items.size():
			var a = items[i]
			var r := Rect2(x + i * 84, y, 70, 70)
			draw_rect(r, Color(0.02, 0.05, 0.07, 0.85))
			var c: Color = a.color
			var ctr := r.get_center()
			match i:
				0:
					draw_arc(ctr, 22, 0, TAU, 32, c * 1.4, 3.0)
					draw_arc(ctr, 12, 0, TAU, 24, c * 1.4, 3.0)
					draw_circle(ctr, 4, c * 1.6)
				1:
					for k in 3:
						var o := Vector2(-14 + k * 14, 6 - (k % 2) * 12)
						draw_colored_polygon(PackedVector2Array([ctr + o + Vector2(0, -10), ctr + o + Vector2(6, 8), ctr + o + Vector2(-6, 8)]), c * 1.4)
				2:
					draw_arc(ctr + Vector2(-8, 4), 24, -1.3, 0.6, 20, c * 1.5, 5.0)
			if not a.is_ready():
				var k: float = 1.0 - a.progress()
				draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * k)), Color(0, 0, 0, 0.7))
				_text(Vector2(r.position.x, r.position.y + 44), "%.1f" % a.cd_left, 20, Color(1, 1, 1), bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			else:
				var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
				draw_rect(r, c * Color(1.5, 1.5, 1.5, 0.35 + 0.35 * pulse), false, 2.0)
			draw_rect(r, Color(0.3, 0.6, 0.7, 0.6), false, 1.5)
			_text(r.position + Vector2(5, 18), a.key_hint, 16, Color(1, 1, 1, 0.9), bold)

	# -------------------------------------------------------------- weapons

	func _draw_weapons(pl, vs: Vector2) -> void:
		var x := vs.x - 380.0
		var y := vs.y - 250.0
		for i in 3:
			var w = pl.weapons[i]
			if w == null:
				continue
			var active: bool = i == pl.cur
			var cx := x - (30.0 if active else 0.0)
			var cy := y + i * 64.0
			var col: Color = w.item.color() if w.item else Color(0.8, 0.8, 0.8)
			_skew_rect(cx, cy, 340, 54, Color(0.02, 0.05, 0.07, 0.88 if active else 0.6))
			_skew_rect(cx, cy, 340, 54, col * Color(1, 1, 1, 0.9 if active else 0.35), false)
			_text(Vector2(cx + 24, cy + 21), "%d  %s" % [i + 1, w.display_name()], 16 if active else 14, col if active else col * Color(1, 1, 1, 0.7), bold if active else null, HORIZONTAL_ALIGNMENT_LEFT, 250)
			if w.uses_heat():
				var hk: float = w.heat
				var hc := Color(0.6, 0.5, 1.0).lerp(Color(1.0, 0.3, 0.2), hk)
				if w.overheated:
					hc = Color(1.0, 0.25, 0.2) if fmod(_t, 0.3) < 0.15 else Color(0.5, 0.1, 0.1)
				draw_rect(Rect2(cx + 24, cy + 32, 220, 10), Color(0.1, 0.1, 0.15, 0.9))
				draw_rect(Rect2(cx + 24, cy + 32, 220 * hk, 10), hc)
				_text(Vector2(cx + 254, cy + 44), "HEAT" if not w.overheated else "VENT", 18, hc, bold)
			else:
				var mc := Color(1, 1, 1) if w.mag > w.s_mag * 0.25 else Color(1.0, 0.4, 0.3)
				_text(Vector2(cx + 250, cy + 44), "%d" % w.mag, 30 if active else 22, mc, bold, HORIZONTAL_ALIGNMENT_RIGHT, 60)
				_text(Vector2(cx + 314, cy + 44), "/%d" % w.reserve(pl), 16, Color(0.7, 0.8, 0.85))
				if w.reloading:
					draw_rect(Rect2(cx + 24, cy + 36, 200, 6), Color(0.1, 0.1, 0.1, 0.9))
					draw_rect(Rect2(cx + 24, cy + 36, 200 * w.reload_progress(), 6), Color(1.0, 0.8, 0.3))
				elif w.charging:
					draw_rect(Rect2(cx + 24, cy + 36, 200, 6), Color(0.1, 0.1, 0.1, 0.9))
					draw_rect(Rect2(cx + 24, cy + 36, 200 * w.charge, 6), Color(1.0, 0.4, 0.5) if w.charge < 1.0 else Color(1, 1, 1))
		# launcher charges
		var ly := y + 3 * 64.0 + 6
		_text(Vector2(x + 24, ly + 18), "RMB  HAVOC", 15, Color(1.0, 0.65, 0.3))
		var l = pl.launcher
		for k in l.s_mag:
			var px: float = x + 140 + k * 26
			var filled: bool = k < l.mag
			draw_circle(Vector2(px, ly + 12), 8, Color(1.0, 0.6, 0.25) if filled else Color(0.2, 0.12, 0.08))
			draw_arc(Vector2(px, ly + 12), 9, 0, TAU, 16, Color(1.0, 0.7, 0.4, 0.7), 1.5)

	func _draw_xp(pl, vs: Vector2) -> void:
		var w := 560.0
		var x := (vs.x - w) * 0.5
		var y := vs.y - 18.0
		draw_rect(Rect2(x, y, w, 6), Color(0.05, 0.08, 0.1, 0.9))
		draw_rect(Rect2(x, y, w * float(pl.xp) / pl.xp_next, 6), Color(0.45, 0.85, 1.0))

	# -------------------------------------------------------------- minimap

	func _draw_minimap(pl, vs: Vector2) -> void:
		var c := Vector2(vs.x - 150, 150)
		var R := 118.0
		draw_circle(c, R + 6, Color(0.01, 0.03, 0.04, 0.85))
		var d = Game.dungeon
		if d == null:
			return
		var pt := Iso.ground_to_tile(pl.gpos)
		var s := 11.0
		var to_map := func(t: Vector2) -> Vector2:
			var rel := t - pt
			return c + Vector2((rel.x - rel.y) * s, (rel.x + rel.y) * s * 0.75)
		var pc := Iso.cell_of(pl.gpos)
		for ox in range(-13, 14):
			for oy in range(-13, 14):
				var cell := pc + Vector2i(ox, oy)
				if not d.floor_kind.has(cell) or not d.visited.has(cell):
					continue
				var p0: Vector2 = to_map.call(Vector2(cell))
				if p0.distance_to(c) > R - 6:
					continue
				var b: int = d.block.get(cell, 0)
				var col := Color(0.08, 0.25, 0.27, 0.9)
				if b == Dungeon.Block.WALL:
					col = Color(0.55, 0.75, 0.8, 0.9)
				elif b == Dungeon.Block.LOW:
					col = Color(0.2, 0.4, 0.45, 0.9)
				elif b == Dungeon.Block.DOOR:
					col = Color(1.0, 0.25, 0.2, 0.95)
				var pts := PackedVector2Array([to_map.call(Vector2(cell)), to_map.call(Vector2(cell) + Vector2(1, 0)),
					to_map.call(Vector2(cell) + Vector2(1, 1)), to_map.call(Vector2(cell) + Vector2(0, 1))])
				draw_colored_polygon(pts, col)
		if d.exit_cell.x >= 0 and d.visited.has(d.exit_cell):
			var ep: Vector2 = to_map.call(Vector2(d.exit_cell) + Vector2(0.5, 0.5))
			if ep.distance_to(c) < R:
				draw_circle(ep, 5, Color(0.4, 0.9, 1.0, 0.6 + 0.4 * sin(_t * 4.0)))
		for e in Game.enemies:
			if not e.alive:
				continue
			var ep: Vector2 = to_map.call(Iso.ground_to_tile(e.gpos))
			if ep.distance_to(c) < R - 4:
				draw_circle(ep, 4.5 if e.is_elite else 3.0, Color(1.0, 0.6, 0.2) if e.is_elite else Color(1.0, 0.25, 0.25))
		var ad: Vector2 = pl.aim_dir
		var mdir := Vector2(ad.x, ad.y * 0.75).normalized()
		draw_colored_polygon(PackedVector2Array([c + mdir * 10, c + mdir.orthogonal() * 6 - mdir * 5, c - mdir.orthogonal() * 6 - mdir * 5]), Color(1, 1, 1))
		draw_arc(c, R + 4, 0, TAU, 64, Color(0.25, 0.85, 0.8, 0.7), 2.5)
		draw_arc(c, R + 9, -0.5, 0.5, 16, Color(0.25, 0.85, 0.8, 0.5), 2.0)

	# -------------------------------------------------------------- elite bar / room

	func _draw_elite(pl, vs: Vector2) -> void:
		var best = null
		for e in Game.enemies:
			if e.alive and e.is_elite and e.gpos.distance_to(pl.gpos) < Iso.m(20.0):
				best = e
				break
		if best == null:
			return
		var w := 640.0
		var x := (vs.x - w) * 0.5
		var y := 54.0
		var title: String = "ELITE " + best.data.display_name.to_upper()
		_text(Vector2(0, y - 10), title, 24, Color(1.0, 0.7, 0.3), bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		draw_rect(Rect2(x - 3, y - 3, w + 6, 22), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x, y, w * best.hp / best.max_hp, 16), Color(0.95, 0.45, 0.1))
		if best.shield_max > 0.0:
			draw_rect(Rect2(x, y + 18, w * best.shield / best.shield_max, 5), Color(0.4, 0.75, 1.0))
		var tags: String = "  ·  ".join(best.affixes.map(func(a): return String(a).to_upper()))
		_text(Vector2(0, y + 44), tags, 16, Color(1.0, 0.55, 0.45), null, HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	func _draw_room(vs: Vector2) -> void:
		var dir = Game.world.director if Game.world else null
		if dir == null or dir.active == null:
			return
		var r = dir.active
		var n: int = r.alive_count() + r.spawn_queue.size()
		var s := "HOSTILES  %d" % n
		if r.nests_alive() > 0:
			s += "   NESTS  %d" % r.nests_alive()
		_text(Vector2(vs.x - 400, 300), s, 18, Color(1.0, 0.45, 0.4), bold, HORIZONTAL_ALIGNMENT_RIGHT, 370)

	func _draw_messages(vs: Vector2) -> void:
		var y := vs.y * 0.2
		for m in messages:
			var t: float = m["t"]
			var a := clampf(t / 0.15, 0.0, 1.0) * clampf((3.2 - t) / 0.6, 0.0, 1.0)
			var sc := 1.0 + maxf(0.0, 0.25 - t) * 1.2
			var c: Color = m["c"]
			c.a = a
			_text(Vector2(0, y), m["text"], int(40 * sc), c, bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 8)
			y += 56

	func _draw_feed(vs: Vector2) -> void:
		var y := 340.0
		for f in feed:
			var a := clampf((6.0 - f["t"]) / 1.0, 0.0, 1.0)
			var c: Color = f["c"]
			c.a = a
			draw_rect(Rect2(vs.x - 420, y - 20, 400, 28), Color(0, 0, 0, 0.5 * a))
			draw_rect(Rect2(vs.x - 420, y - 20, 4, 28), c)
			_text(Vector2(vs.x - 408, y), f["text"], 17, c, null, HORIZONTAL_ALIGNMENT_LEFT, 380)
			y += 32

	## Arrows at the screen edge toward the last few hostiles of an encounter.
	func _draw_offscreen(pl, vs: Vector2) -> void:
		var dir = Game.world.director if Game.world else null
		if dir == null or dir.active == null:
			return
		var left: Array = []
		for e in dir.active.enemies:
			if is_instance_valid(e) and e.alive:
				left.append(e)
		for p in dir.active.nests:
			if is_instance_valid(p) and p.alive and p.nest_active:
				left.append(p)
		if left.is_empty() or left.size() > 4:
			return
		var xf := get_viewport().get_canvas_transform()
		var rect := Rect2(Vector2(60, 60), vs - Vector2(120, 120))
		var center := vs * 0.5
		for e in left:
			var sp: Vector2 = xf * Iso.lift(e.gpos, 0.5)
			if rect.has_point(sp):
				continue
			var d := (sp - center).normalized()
			var k := minf(absf((rect.size.x * 0.5) / maxf(absf(d.x), 0.001)), absf((rect.size.y * 0.5) / maxf(absf(d.y), 0.001)))
			var p := center + d * k
			var col := Color(1.0, 0.35, 0.3, 0.75 + 0.25 * sin(_t * 6.0))
			draw_colored_polygon(PackedVector2Array([p + d * 18, p + d.orthogonal() * 11 - d * 6, p - d.orthogonal() * 11 - d * 6]), col)

	# -------------------------------------------------------------- crosshair

	func _draw_crosshair(pl) -> void:
		if pl.input_override != null:
			return
		var m := get_viewport().get_mouse_position()
		var w = pl.cur_weapon()
		var spread := 10.0
		if w:
			spread = 8.0 + (w.s_spread + w.bloom) * 2.2
		var col := Color(1, 1, 1, 0.9)
		draw_arc(m, 3, 0, TAU, 12, col, 2.0)
		for k in 4:
			var d := Vector2.from_angle(k * PI * 0.5 + PI * 0.25)
			draw_line(m + d * spread, m + d * (spread + 9), col, 2.5)
		if w and w.reloading:
			draw_arc(m, spread + 16, -PI * 0.5, -PI * 0.5 + TAU * w.reload_progress(), 32, Color(1.0, 0.8, 0.3), 3.0)
		if w and w.charging:
			draw_arc(m, spread + 16, -PI * 0.5, -PI * 0.5 + TAU * w.charge, 32, Color(1.0, 0.4, 0.5) if w.charge < 1.0 else Color(1, 1, 1), 4.0)
		if w and w.uses_heat() and w.heat > 0.05:
			draw_arc(m, spread + 14, PI * 0.6, PI * 0.6 + PI * 0.8 * w.heat, 24, Color(0.7, 0.5, 1.0).lerp(Color(1, 0.3, 0.2), w.heat), 3.0)
