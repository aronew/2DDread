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
	add_child(MinimapDraw.new())
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
		HUD.set_game_cursor(not paused_menu)
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


func _exit_tree() -> void:
	# release the static cursor texture before the renderer shuts down
	Input.set_custom_mouse_cursor(null)
	_reticle = null


func toggle_inventory() -> void:
	inventory.visible = not inventory.visible
	get_tree().paused = inventory.visible
	if inventory.visible:
		inventory.refresh()
		Audio.play("ui_click")
	HUD.set_game_cursor(not inventory.visible)


static var _reticle: ImageTexture


## Gameplay uses a hardware (OS-drawn) reticle: it never lags behind the mouse,
## whatever the frame rate. Menus get the normal arrow.
static func set_game_cursor(game: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not game:
		Input.set_custom_mouse_cursor(null)
		return
	if _reticle == null:
		var s := 32
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var c := Vector2(15.5, 15.5)
		for y in s:
			for x in s:
				var p := Vector2(x, y) - c
				var r := p.length()
				var a := 0.0
				if absf(r - 3.0) < 1.1:
					a = 1.0
				var ax := absf(p.x) < 1.1 or absf(p.y) < 1.1
				if ax and r > 7.0 and r < 13.0:
					a = 1.0
				if a > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, a))
				elif (absf(r - 3.0) < 2.2) or (ax and r > 6.0 and r < 14.0 and (absf(p.x) < 2.1 or absf(p.y) < 2.1)):
					img.set_pixel(x, y, Color(0, 0, 0, 0.75))
		_reticle = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(_reticle, Input.CURSOR_ARROW, Vector2(16, 16))


class HudDraw extends Control:
	var font: Font
	var bold: FontVariation
	var messages: Array = []
	var feed: Array = []
	var _t := 0.0
	var _hp_shown := 1.0
	var _hint_t := 14.0
	var _fps_t := 0.0

	var portrait: Texture2D

	func _ready() -> void:
		var cinzel: FontFile = load("res://assets/fonts/Cinzel.ttf")
		var fv := FontVariation.new()
		fv.base_font = cinzel
		fv.variation_opentype = {"weight": 700}
		font = fv
		bold = FontVariation.new()
		bold.base_font = cinzel
		bold.variation_opentype = {"weight": 900}
		if ResourceLoader.exists("res://assets/sprites/ui/portrait.png"):
			portrait = load("res://assets/sprites/ui/portrait.png")
		HUD.set_game_cursor(true)
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
		_draw_elite(pl, vs)
		_draw_messages(vs)
		_draw_feed(vs)
		_draw_room(vs)
		if _hint_t > 0.0:
			var a := clampf(_hint_t / 2.0, 0.0, 1.0)
			_text(Vector2(0, 30), "WASD move · Mouse aim · LMB fire · RMB sword (hold: combo, after a dash: thrust) · SPACE dash · F firebomb · Q nova · E seekers · R reload · 1-3 weapons · TAB inventory",
				17, Color(0.8, 0.85, 0.9, 0.85 * a), null, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if not pl.alive:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(0.2, 0.0, 0.0, 0.35))
			_text(Vector2(0, vs.y * 0.45), "YOU HAVE FALLEN", 84, Color(0.9, 0.15, 0.12), bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 10)
		_draw_offscreen(pl, vs)
		if get_parent().paused_menu:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0.02, 0.03, 0.7))
			_text(Vector2(0, vs.y * 0.42), "PAUSED", 72, Color(0.85, 0.95, 1.0), bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 10)
			_text(Vector2(0, vs.y * 0.42 + 60), "ESC resume   ·   R restart run   ·   Q quit   ·   F4 graphics: %s" % Game.preset.to_upper(), 22, Color(0.7, 0.8, 0.85), null, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		if Game.debug:
			_text(Vector2(20, 30), "FPS %d (%.1f ms)  script %.1f ms  draw calls %d  VRAM %d MB" % [Engine.get_frames_per_second(),
				1000.0 / maxf(1.0, Engine.get_frames_per_second()), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0], 18, Color(0.6, 1.0, 0.6))
			_text(Vector2(20, 54), "graphics %s [F4]  lights %d  enemies %d  projectiles %d  GPU %s" % [Game.preset.to_upper(),
				Game.dungeon.light_count() if Game.dungeon else 0, Game.living_enemies(),
				Game.projectiles.list.size() if Game.projectiles else 0, RenderingServer.get_video_adapter_name()], 16, Color(0.6, 1.0, 0.6))
		if not get_tree().paused:
			_draw_crosshair(pl)

	# -------------------------------------------------------------- shared ornaments

	const GOLD := Color(0.93, 0.74, 0.38)
	const GOLD_DK := Color(0.42, 0.3, 0.13)
	const PANEL := Color(0.045, 0.035, 0.045, 0.88)

	func _diamond(c: Vector2, r: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

	func _gold_frame(pts: PackedVector2Array, w := 2.5) -> void:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(0, 0, 0, 0.8), w + 3.0, true)
		draw_polyline(closed, GOLD_DK, w + 1.0, true)
		draw_polyline(closed, GOLD, w * 0.6, true)

	static func _area(poly: PackedVector2Array) -> float:
		var s := 0.0
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			s += p0.x * p1.y - p1.x * p0.y
		return s * 0.5

	func _plate(r: Rect2, notch := 12.0) -> PackedVector2Array:
		var n := notch
		return PackedVector2Array([r.position + Vector2(n, 0), Vector2(r.end.x - n, r.position.y), Vector2(r.end.x, r.position.y + r.size.y * 0.5),
			Vector2(r.end.x - n, r.end.y), Vector2(r.position.x + n, r.end.y), Vector2(r.position.x, r.position.y + r.size.y * 0.5)])

	# -------------------------------------------------------------- portrait + health

	func _draw_health(pl, vs: Vector2) -> void:
		var pc := Vector2(98, vs.y - 104)
		var pr := 66.0
		var dia := _diamond(pc, pr)
		draw_colored_polygon(dia, PANEL)
		if portrait:
			var uv := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
			draw_colored_polygon(_diamond(pc, pr - 4), Color.WHITE, uv, portrait)
		_gold_frame(dia, 3.5)
		_gold_frame(_diamond(pc, pr + 7), 1.5)
		var x := 168.0
		var y := vs.y - 118.0
		var w := 430.0
		var h := 24.0
		var frac: float = clampf(pl.hp / pl.max_hp, 0.0, 1.0)
		_hp_shown = move_toward(_hp_shown, frac, get_process_delta_time() * 0.6) if _hp_shown > frac else frac
		var bar := _plate(Rect2(x, y, w, h), 10)
		draw_colored_polygon(bar, PANEL)
		var inner := Rect2(x + 9, y + 5, w - 18, h - 10)
		if _hp_shown > frac:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _hp_shown, inner.size.y)), Color(1.0, 0.85, 0.7, 0.55))
		var c := Color(0.8, 0.06, 0.07)
		if frac < 0.3:
			c = c.lerp(Color(1.0, 0.4, 0.3), 0.5 + 0.5 * sin(_t * 10.0))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y)), c)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * frac, inner.size.y * 0.35)), Color(1.0, 0.45, 0.4, 0.35))
		_gold_frame(bar, 2.0)
		_text(Vector2(x + w + 16, y + 20), "%d / %d" % [int(ceil(pl.hp)), int(pl.max_hp)], 22, Color(0.96, 0.92, 0.86), font)
		# xp line + dash diamonds + level
		var xy := y + h + 10
		draw_rect(Rect2(x + 10, xy, w - 20, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(x + 10, xy, (w - 20) * float(pl.xp) / pl.xp_next, 4), GOLD)
		for i in pl.dash_max:
			var dc := Vector2(x + 20 + i * 24, xy + 22)
			draw_colored_polygon(_diamond(dc, 8), Color(0.45, 0.85, 1.0) if i < pl.dash_charges else Color(0.08, 0.12, 0.16))
			_gold_frame(_diamond(dc, 8), 1.2)
		var lv: String = "Level %d" % pl.level
		if pl.build.attr_points > 0:
			lv += "    +%d points  [Tab]" % pl.build.attr_points
		_text(Vector2(x + 30 + pl.dash_max * 24, xy + 29), lv, 16, GOLD if pl.build.attr_points > 0 else Color(0.82, 0.8, 0.75), font)

	# -------------------------------------------------------------- abilities (diamonds)

	func _draw_abilities(pl, vs: Vector2) -> void:
		var items: Array = [pl.abilities[0], pl.abilities[1], pl.blade]
		var cx := vs.x * 0.5
		for i in items.size():
			var a = items[i]
			var small := i == 2
			var r := 40.0 if not small else 30.0
			var c := Vector2(cx + (i - 0.5) * 112.0 + (14.0 if small else 0.0), vs.y - 92 + (10.0 if small else 0.0))
			var dia := _diamond(c, r)
			draw_colored_polygon(dia, PANEL)
			var col: Color = a.color
			match i:
				0:
					draw_arc(c, r * 0.42, 0, TAU, 28, col * 1.3, 3.0)
					draw_arc(c, r * 0.22, 0, TAU, 20, col * 1.4, 3.0)
					for k in 6:
						var d := Vector2.from_angle(k * TAU / 6.0)
						draw_line(c + d * r * 0.5, c + d * r * 0.68, col * 1.4, 2.0)
				1:
					for k in 3:
						var o := Vector2(-r * 0.32 + k * r * 0.32, r * 0.12 - (k % 2) * r * 0.24)
						draw_colored_polygon(PackedVector2Array([c + o + Vector2(0, -r * 0.24), c + o + Vector2(r * 0.12, r * 0.16), c + o + Vector2(-r * 0.12, r * 0.16)]), col * 1.4)
				2:  # the saber: a curved blade, crossguard and grip, on the diagonal
					var dg := Vector2(0.7071, -0.7071)
					var nm := Vector2(0.7071, 0.7071)
					var base := c - dg * r * 0.18
					var blade_pts := PackedVector2Array([base + nm * r * 0.07, base + dg * r * 0.42 + nm * r * 0.1,
						base + dg * r * 0.62 - nm * r * 0.02, base + dg * r * 0.4 - nm * r * 0.06, base - nm * r * 0.06])
					draw_colored_polygon(blade_pts, Color(2.0, 1.5, 0.9))
					draw_line(base + nm * r * 0.2, base - nm * r * 0.2, col * 1.4, 3.0)
					draw_line(base, base - dg * r * 0.3, Color(0.55, 0.25, 0.15), 4.0)
					draw_circle(base - dg * r * 0.34, 3.0, col * 1.5)
			if not a.is_ready():
				var k: float = 1.0 - a.progress()
				var top := c.y - r + 2.0 * r * (1.0 - k)
				var clip := Geometry2D.intersect_polygons(dia, PackedVector2Array([Vector2(c.x - r, top), Vector2(c.x + r, top), Vector2(c.x + r, c.y + r), Vector2(c.x - r, c.y + r)]))
				for poly in clip:
					# skip slivers (degenerate polygons fail to triangulate)
					if poly.size() >= 3 and absf(_area(poly)) > 4.0:
						draw_colored_polygon(poly, Color(0, 0, 0, 0.68))
				_text(Vector2(c.x - r, c.y + 7), "%.1f" % a.cd_left, 18, Color(1, 1, 1), font, HORIZONTAL_ALIGNMENT_CENTER, r * 2)
			_gold_frame(dia, 3.0 if not small else 2.2)
			if a.is_ready():
				var pulse := 0.4 + 0.3 * sin(_t * 4.0 + i)
				var glow := dia.duplicate()
				glow.append(dia[0])
				draw_polyline(glow, col * Color(1.6, 1.6, 1.6, pulse), 2.0, true)
			var kc := c + Vector2(0, r + 18)
			draw_colored_polygon(_diamond(kc, 13), PANEL)
			_gold_frame(_diamond(kc, 13), 1.4)
			_text(Vector2(kc.x - 13, kc.y + (6 if a.key_hint.length() == 1 else 4)), a.key_hint, 15 if a.key_hint.length() == 1 else 10,
				Color(0.95, 0.92, 0.85), font, HORIZONTAL_ALIGNMENT_CENTER, 26, 3)

	# -------------------------------------------------------------- weapon / ammo plate

	func _draw_weapons(pl, vs: Vector2) -> void:
		var w = pl.cur_weapon()
		if w == null:
			return
		var pr := Rect2(vs.x - 330, vs.y - 104, 300, 62)
		var pts := _plate(pr, 16)
		draw_colored_polygon(pts, PANEL)
		var col: Color = w.item.color() if w.item else Color(0.9, 0.9, 0.85)
		if w.uses_heat():
			var hk: float = w.heat
			var hc := Color(0.55, 0.8, 1.0).lerp(Color(1.0, 0.3, 0.2), hk)
			if w.overheated:
				hc = Color(1.0, 0.25, 0.2) if fmod(_t, 0.3) < 0.15 else Color(0.5, 0.1, 0.1)
			draw_rect(Rect2(pr.position.x + 26, pr.position.y + 25, 150, 12), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(pr.position.x + 26, pr.position.y + 25, 150 * hk, 12), hc)
			_text(Vector2(pr.position.x + 186, pr.position.y + 42), "VENT" if w.overheated else "HEAT", 24, hc, font)
		else:
			for k in 3:  # bullet icons
				var bx := pr.position.x + 30 + k * 16
				var by := pr.position.y + 16
				draw_rect(Rect2(bx, by + 8, 9, 22), GOLD_DK)
				draw_rect(Rect2(bx + 1, by + 10, 7, 18), GOLD if w.mag > k else Color(0.2, 0.15, 0.1))
				draw_circle(Vector2(bx + 4.5, by + 8), 4.5, GOLD if w.mag > k else Color(0.2, 0.15, 0.1))
			var mc := Color(0.97, 0.94, 0.88) if w.mag > w.s_mag * 0.25 else Color(1.0, 0.4, 0.3)
			_text(Vector2(pr.position.x + 92, pr.position.y + 44), "%d" % w.mag, 32, mc, font)
			_text(Vector2(pr.position.x + 150, pr.position.y + 44), "/ %d" % w.reserve(pl), 22, Color(0.8, 0.76, 0.68), font)
			if w.reloading or w.charging:
				var k2: float = w.reload_progress() if w.reloading else w.charge
				draw_rect(Rect2(pr.position.x + 26, pr.end.y - 12, 248, 4), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(pr.position.x + 26, pr.end.y - 12, 248 * k2, 4), GOLD if w.reloading else Color(1.0, 0.4, 0.4))
		_gold_frame(pts, 2.2)
		_text(Vector2(pr.position.x, pr.position.y - 10), w.display_name(), 17, col, font, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 10)
		# other weapon slots, compact
		var sx := pr.position.x - 8
		for i in range(2, -1, -1):
			var ow = pl.weapons[i]
			if ow == null:
				continue
			var active: bool = i == pl.cur
			var c := Vector2(sx - 22, pr.position.y + 31)
			draw_colored_polygon(_diamond(c, 18), PANEL if not active else Color(0.25, 0.18, 0.08, 0.95))
			_gold_frame(_diamond(c, 18), 1.6 if not active else 2.4)
			_text(Vector2(c.x - 18, c.y + 7), str(i + 1), 18, GOLD if active else Color(0.75, 0.72, 0.66), font, HORIZONTAL_ALIGNMENT_CENTER, 36, 3)
			sx -= 44
		# firebomb charges (F)
		var l = pl.launcher
		for k in l.s_mag:
			var bc := Vector2(pr.end.x - 20 - k * 22, pr.end.y + 16)
			draw_circle(bc, 7, Color(1.0, 0.55, 0.2) if k < l.mag else Color(0.18, 0.1, 0.06))
			draw_arc(bc, 8, 0, TAU, 16, GOLD_DK, 1.5)
		_text(Vector2(pr.end.x - 30 - l.s_mag * 22 - 90, pr.end.y + 22), "F bomb", 14, Color(0.85, 0.7, 0.5), font, HORIZONTAL_ALIGNMENT_RIGHT, 90)

	func _draw_xp(_pl, _vs: Vector2) -> void:
		pass  # xp lives under the health bar now

	# -------------------------------------------------------------- elite bar

	func _draw_elite(pl, vs: Vector2) -> void:
		var best = null
		for e in Game.enemies:
			if e.alive and e.is_elite and e.gpos.distance_to(pl.gpos) < Iso.m(20.0):
				best = e
				break
		if best == null:
			return
		var w := 620.0
		var x := (vs.x - w) * 0.5
		var y := 60.0
		_text(Vector2(0, y - 12), best.data.display_name, 26, GOLD, font, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		var pts := _plate(Rect2(x - 12, y - 4, w + 24, 24), 12)
		draw_colored_polygon(pts, PANEL)
		draw_rect(Rect2(x, y + 2, w * best.hp / best.max_hp, 12), Color(0.85, 0.25, 0.08))
		if best.shield_max > 0.0:
			draw_rect(Rect2(x, y + 14, w * best.shield / best.shield_max, 4), Color(0.45, 0.8, 1.0))
		_gold_frame(pts, 2.0)
		var tags: String = "   ·   ".join(best.affixes.map(func(a): return String(a).capitalize()))
		_text(Vector2(0, y + 46), tags, 17, Color(1.0, 0.6, 0.45), font, HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# -------------------------------------------------------------- wave plate (top right)

	func _draw_room(vs: Vector2) -> void:
		var dir = Game.world.director if Game.world else null
		if dir == null or dir.active == null:
			return
		var r = dir.active
		var total: int = r.beats.size()
		var cur: int = clampi(r.beat_i, 1, total)
		var pr := Rect2(vs.x - 290, 22, 260, 52)
		var pts := _plate(pr, 14)
		draw_colored_polygon(pts, PANEL)
		_gold_frame(pts, 2.2)
		var ic := Vector2(pr.position.x - 4, pr.position.y + 26)
		draw_colored_polygon(_diamond(ic, 30), PANEL)
		_gold_frame(_diamond(ic, 30), 2.2)
		draw_colored_polygon(PackedVector2Array([ic + Vector2(0, -14), ic + Vector2(8, 4), ic + Vector2(0, 12), ic + Vector2(-8, 4)]), Color(0.4, 1.0, 0.6))
		_text(Vector2(pr.position.x + 34, pr.position.y + 35), "WAVE %d / %d" % [cur, total], 24, Color(0.96, 0.92, 0.84), font)
		for k in total:
			var dc := Vector2(pr.position.x + 46 + k * 22, pr.end.y + 16)
			var filled: bool = k < cur
			draw_colored_polygon(_diamond(dc, 7), GOLD if filled else Color(0.08, 0.07, 0.07))
			_gold_frame(_diamond(dc, 7), 1.0)
		var n: int = r.alive_count() + r.spawn_queue.size()
		var s := "%d foes" % n
		if r.nests_alive() > 0:
			s += "  ·  %d nests" % r.nests_alive()
		_text(Vector2(pr.position.x, pr.end.y + 22), s, 15, Color(1.0, 0.5, 0.42), font, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 6)

	func _draw_messages(vs: Vector2) -> void:
		var y := vs.y * 0.2
		for m in messages:
			var t: float = m["t"]
			var a := clampf(t / 0.15, 0.0, 1.0) * clampf((3.2 - t) / 0.6, 0.0, 1.0)
			var sc := 1.0 + maxf(0.0, 0.25 - t) * 1.2
			var c: Color = m["c"]
			c.a = a
			_text(Vector2(0, y), m["text"], int(42 * sc), c, bold, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 8)
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
		var col := Color(1, 1, 1, 0.55)
		if spread > 14.0:
			for k in 4:
				var d := Vector2.from_angle(k * PI * 0.5 + PI * 0.25)
				draw_line(m + d * spread, m + d * (spread + 7), col, 2.0)
		if w and w.reloading:
			draw_arc(m, spread + 16, -PI * 0.5, -PI * 0.5 + TAU * w.reload_progress(), 32, Color(1.0, 0.8, 0.3), 3.0)
		if w and w.charging:
			draw_arc(m, spread + 16, -PI * 0.5, -PI * 0.5 + TAU * w.charge, 32, Color(1.0, 0.4, 0.5) if w.charge < 1.0 else Color(1, 1, 1), 4.0)
		if w and w.uses_heat() and w.heat > 0.05:
			draw_arc(m, spread + 14, PI * 0.6, PI * 0.6 + PI * 0.8 * w.heat, 24, Color(0.7, 0.5, 1.0).lerp(Color(1, 0.3, 0.2), w.heat), 3.0)


## Minimap on its own canvas item, re-recorded at 10 Hz instead of every frame
## (hundreds of cell polygons are too much GDScript work per frame).
class MinimapDraw extends Control:
	var _t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_t += dt
		_acc += dt
		if _acc >= 0.1:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var pl = Game.player
		if pl == null:
			return
		var vs := get_viewport_rect().size
		var c := Vector2(vs.x - 120, 210)
		var R := 84.0
		draw_circle(c, R + 6, Color(0.01, 0.03, 0.04, 0.85))
		var d = Game.dungeon
		if d == null:
			return
		var pt := Iso.ground_to_tile(pl.gpos)
		var s := 8.0
		var to_map := func(t: Vector2) -> Vector2:
			var rel := t - pt
			return c + Vector2((rel.x - rel.y) * s, (rel.x + rel.y) * s * Iso.K)
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
				var col := Color(0.12, 0.2, 0.15, 0.9)
				if b == Dungeon.Block.WALL:
					col = Color(0.72, 0.6, 0.38, 0.95)
				elif b == Dungeon.Block.LOW:
					col = Color(0.3, 0.32, 0.25, 0.9)
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
		var mdir := Vector2(ad.x, ad.y * Iso.K).normalized()
		draw_colored_polygon(PackedVector2Array([c + mdir * 10, c + mdir.orthogonal() * 6 - mdir * 5, c - mdir.orthogonal() * 6 - mdir * 5]), Color(1, 1, 1))
		draw_arc(c, R + 4, 0, TAU, 64, Color(0, 0, 0, 0.8), 5.0)
		draw_arc(c, R + 4, 0, TAU, 64, Color(0.93, 0.74, 0.38, 0.9), 2.0)

