class_name HubMenu
extends Control
## The hub's station screens (pauses the game; ESC or E closes):
##   forge  the Soul Forge: permanent upgrades bought with souls (Meta.UPGRADES);
##   bar    Charon's bar: one drink per crossing, a bonus until you come back (Meta.DRINKS);
##   ferry  the crossing: the temple at any depth up to one past the deepest reached, and the
##          shores still to come.

const GOLD := Color(0.93, 0.74, 0.38)
const SOUL := Color(0.45, 1.0, 0.7)

var kind := ""
var _box: VBoxContainer
var _title: Label
var _souls: Label
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Cinzel.ttf")
	fv.variation_opentype = {"weight": 700}
	_font = fv
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.95)
	sb.border_color = Color(GOLD, 0.85)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(760, 0)
	p.position = Vector2(-380, -330)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = _label("", 34, GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_souls = _label("", 24, SOUL)
	top.add_child(_souls)
	var sep := ColorRect.new()
	sep.color = Color(GOLD, 0.5)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	v.add_child(_box)
	v.add_child(_label("ESC / E   close", 15, Color(0.6, 0.65, 0.68)))
	Events.souls_changed.connect(func(_t, _d): if visible: refresh())


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l


func open(kind_: String) -> void:
	kind = kind_
	visible = true
	get_tree().paused = true
	HUD.set_game_cursor(false)
	refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	HUD.set_game_cursor(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	_souls.text = "◆ %d SOULS" % Meta.souls
	match kind:
		"forge":
			_title.text = "THE SOUL FORGE"
			_box.add_child(_label("Souls in, iron out. These stay with you forever.", 17, Color(0.8, 0.78, 0.72)))
			for id in Meta.UPGRADES:
				var u: Array = Meta.UPGRADES[id]
				var lv := Meta.level(id)
				var pips := "◆".repeat(lv) + "◇".repeat(int(u[4]) - lv)
				var can := not Meta.maxed(id) and Meta.souls >= Meta.cost(id)
				var right := "MAXED" if Meta.maxed(id) else "%d souls" % Meta.cost(id)
				_row("%s   %s" % [u[0], pips], str(u[1]), right, can, func(): _buy(id))
		"bar":
			_title.text = "THE LAST OBOL"
			if Meta.drink != "":
				var d: Array = Meta.DRINKS[Meta.drink]
				_box.add_child(_label("Poured for this crossing: %s\n%s" % [d[0], d[1]], 19, SOUL))
				_box.add_child(_label("One drink per crossing. Come back after the next dive.", 16, Color(0.7, 0.7, 0.68)))
			else:
				_box.add_child(_label("One drink per crossing. It lasts until you come back.", 17, Color(0.8, 0.78, 0.72)))
				for id in Meta.DRINKS:
					var d: Array = Meta.DRINKS[id]
					_row(str(d[0]), str(d[1]), "%d souls" % int(d[3]), Meta.souls >= int(d[3]), func(): _pour(id))
		"ferry":
			_title.text = "THE FERRY"
			_box.add_child(_label("The boat still knows the way, if you feed it souls. Where to?", 17, Color(0.8, 0.78, 0.72)))
			var deepest := Meta.best_depth + 1
			for dp in range(maxi(1, deepest - 2), deepest + 1):
				var note := "deeper than you have ever been" if dp == deepest and dp > 1 else ("enemies +%d%% health" % int((Game.depth_hp_mult_at(dp) - 1.0) * 100.0) if dp > 1 else "where it began")
				_row("The Soul-Fire Temple   ·   depth %d" % dp, note, "CROSS", true, func(): _sail(dp, "temple"))
			if Meta.shores.has("phlegethon"):
				for dp in range(maxi(1, deepest - 2), deepest + 1):
					var hp := int((Game.depth_hp_mult_at(dp, 2) - 1.0) * 100.0)
					_row("The Phlegethon, river of fire   ·   depth %d" % dp, "the second shore: islands in a sea of lava, enemies +%d%% health" % hp, "CROSS", true, func(): _sail(dp, "phlegethon"))
			else:
				_row("The Second Shore", "Beyond the Weaver. Reach the temple's portal to chart it.", "LOCKED", false, func(): pass)


func _row(name: String, desc: String, right: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(700, 64)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.09, 0.08, 0.08, 0.95)
	n.border_color = Color(GOLD, 0.55 if enabled else 0.2)
	n.set_border_width_all(1)
	var hv := n.duplicate()
	hv.bg_color = Color(0.16, 0.13, 0.09, 0.95)
	hv.border_color = GOLD
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", n)
	b.pressed.connect(cb)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var a := 1.0 if enabled else 0.45
	v.add_child(_label(name, 21, Color(0.97, 0.92, 0.82, a)))
	v.add_child(_label(desc, 15, Color(0.7, 0.75, 0.72, a)))
	var r := _label(right, 19, Color(SOUL, a) if right.ends_with("souls") else Color(GOLD, a))
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.size_flags_vertical = Control.SIZE_FILL
	h.add_child(r)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(b)


func _buy(id: String) -> void:
	if Meta.buy(id):
		Audio.play("level_up")
		Game.player.build.recalc()
		Game.player.on_stats_changed()
		Game.player.hp = Game.player.max_hp
		VFX.popup(Game.player.gpos, 2.6, Meta.UPGRADES[id][0].to_upper(), Color(1.0, 0.7, 0.35), 30)
	refresh()


func _pour(id: String) -> void:
	if Meta.pour(id):
		Audio.play("pickup_item")
		Game.player.build.recalc()
		Game.player.on_stats_changed()
		Game.player.hp = Game.player.max_hp
		if Game.world.hub and Game.world.hub.charon:
			Game.world.hub.charon.say("%s. Drink up, gunslinger." % Meta.DRINKS[id][0])
	refresh()


func _sail(dp: int, shore: String) -> void:
	close()
	if Game.world.hub:
		Game.world.hub.sail(dp, shore)
