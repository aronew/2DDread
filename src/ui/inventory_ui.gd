class_name InventoryUI
extends Control
## TAB screen. Equipped weapons/gear, backpack, item tooltips with comparison,
## attribute spending. Left-click equips (weapons go to the chosen slot),
## right-click salvages for XP.

var _equip_box: VBoxContainer
var _grid: GridContainer
var _tip: RichTextLabel
var _attr_box: VBoxContainer
var _points: Label
var _slot := 0
var _slot_buttons: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-820, -420)
	root.size = Vector2(1640, 840)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	var left := _panel(root, 520)
	_header(left, "LOADOUT")
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 8)
	left.add_child(_equip_box)
	_header(left, "ATTRIBUTES")
	_points = Label.new()
	_points.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	left.add_child(_points)
	_attr_box = VBoxContainer.new()
	left.add_child(_attr_box)

	var mid := _panel(root, 560)
	_header(mid, "BACKPACK")
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	mid.add_child(_grid)
	var hint := Label.new()
	hint.text = "Left-click: equip   ·   Right-click: salvage for XP\nWeapons equip into the selected slot (click a slot above to select it)"
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	hint.add_theme_font_size_override("font_size", 14)
	mid.add_child(hint)

	var right := _panel(root, 500)
	_header(right, "DETAILS")
	_tip = RichTextLabel.new()
	_tip.bbcode_enabled = true
	_tip.fit_content = false
	_tip.custom_minimum_size = Vector2(470, 700)
	_tip.add_theme_font_size_override("normal_font_size", 18)
	right.add_child(_tip)
	Events.inventory_changed.connect(func(): if visible: refresh())


func _panel(parent: Control, w: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.94)
	sb.border_color = Color(0.93, 0.74, 0.38, 0.8)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, 820)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _header(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.93, 0.74, 0.38))
	parent.add_child(l)


func _item_button(it: Item, label: String, size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.text = label
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	var col := it.color() if it else Color(0.3, 0.35, 0.4)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.95) if st != "hover" else Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.95)
		sb.border_color = col
		sb.set_border_width_all(2 if st != "focus" else 3)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", col.lightened(0.2))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


func refresh() -> void:
	var pl = Game.player
	if pl == null:
		return
	for c in _equip_box.get_children():
		c.queue_free()
	_slot_buttons.clear()
	_slot = pl.cur
	for i in 3:
		var w = pl.weapons[i]
		var it: Item = w.item if w else null
		var b := _item_button(it, "%d   %s%s" % [i + 1, w.display_name() if w else "(empty)", "   ◄" if i == _slot else ""], Vector2(480, 54))
		b.mouse_entered.connect(func(): _show(it))
		b.pressed.connect(func(): _slot = i; pl.switch_weapon(i); refresh())
		_equip_box.add_child(b)
		_slot_buttons.append(b)
	for slot in [&"armor", &"core", &"relic"]:
		var it: Item = pl.gear[slot]
		var b := _item_button(it, "%s   %s" % [String(slot).to_upper(), it.display_name() if it else "(empty)"], Vector2(480, 48))
		b.mouse_entered.connect(func(): _show(it))
		_equip_box.add_child(b)
	for c in _grid.get_children():
		c.queue_free()
	for it in pl.backpack:
		var short: String = it.display_name()
		var b := _item_button(it, short, Vector2(86, 86))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.mouse_entered.connect(func(): _show(it))
		b.gui_input.connect(func(ev): _on_item_input(ev, it))
		_grid.add_child(b)
	for i in range(pl.backpack.size(), Player.BACKPACK_SIZE):
		var e := Panel.new()
		e.custom_minimum_size = Vector2(86, 86)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.07, 0.09, 0.8)
		sb.border_color = Color(0.15, 0.25, 0.28)
		sb.set_border_width_all(1)
		e.add_theme_stylebox_override("panel", sb)
		_grid.add_child(e)
	for c in _attr_box.get_children():
		c.queue_free()
	_points.text = "Unspent points: %d" % pl.build.attr_points
	for a in Build.ATTRS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s  %d" % [a.to_upper(), pl.build.attributes[a]]
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var d := Label.new()
		d.text = Build.ATTR_DESC[a]
		d.custom_minimum_size = Vector2(240, 0)
		d.add_theme_color_override("font_color", Color(0.6, 0.75, 0.8))
		d.add_theme_font_size_override("font_size", 14)
		row.add_child(d)
		var b := Button.new()
		b.text = " + "
		b.disabled = pl.build.attr_points <= 0
		b.pressed.connect(func(): pl.build.spend_point(a); Audio.play("ui_click"); refresh())
		row.add_child(b)
		_attr_box.add_child(row)
	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 15)
	stats.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	stats.text = "Max HP %d   Armour %d   Damage +%d%%   Crit +%d%%   Move +%d%%   CDR %d%%" % [
		pl.max_hp, pl.build.stat("armor"), pl.build.stat("damage_pct") * 100, pl.build.stat("crit_chance") * 100,
		pl.build.stat("move_speed_pct") * 100, pl.build.stat("cooldown_pct") * 100]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(480, 0)
	_attr_box.add_child(stats)
	_show(pl.weapons[pl.cur].item if pl.weapons[pl.cur] else null)


func _on_item_input(ev: InputEvent, it: Item) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	var pl = Game.player
	if ev.button_index == MOUSE_BUTTON_LEFT:
		pl.equip(it, _slot if it.is_weapon() else -1)
		Audio.play("pickup_item")
		refresh()
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		pl.salvage(it)
		Audio.play("crate_break")
		refresh()


func _show(it: Item) -> void:
	if it == null:
		_tip.text = "[color=#7a8a90]Empty slot[/color]"
		return
	var c := it.color().to_html(false)
	var s := "[font_size=26][color=#%s]%s[/color][/font_size]\n" % [c, it.display_name()]
	s += "[color=#%s]%s %s[/color]   ·   Item level %d\n\n" % [c, it.rarity_name(), String(it.kind).capitalize(), it.level]
	if it.is_weapon():
		var d: WeaponData = WeaponDB.get_data(it.base_id)
		var w := Weapon.new(d, it)
		w.recalc(Game.player.build)
		var dps := w.s_damage * d.pellets / maxf(0.01, w.s_interval)
		if d.fire_mode == "charge":
			dps = w.s_damage / (w.s_interval + d.charge_time)
		s += "[color=#e8e8e8]Damage %d%s   ·   %.1f/s   ·   DPS %d[/color]\n" % [w.s_damage, (" x%d" % d.pellets) if d.pellets > 1 else "", 1.0 / w.s_interval, dps]
		s += "[color=#b0bcc2]Crit %d%% x%.1f   ·   %s[/color]\n" % [w.s_crit * 100, w.s_crit_mult, ("Magazine %d" % w.s_mag) if not w.uses_heat() else "Heat-based"]
		var cur = Game.player.weapons[_slot]
		if cur and cur.item != it:
			var cdps: float = cur.s_damage * cur.data.pellets / maxf(0.01, cur.s_interval)
			if cur.data.fire_mode == "charge":
				cdps = cur.s_damage / (cur.s_interval + cur.data.charge_time)
			var delta := dps - cdps
			s += "[color=#%s]%+d DPS vs slot %d[/color]\n" % ["6cff8a" if delta >= 0 else "ff6a5a", delta, _slot + 1]
		s += "\n[i][color=#8fa0a8]%s[/color][/i]\n\n" % d.flavor
	for line in it.describe():
		s += "[color=#%s]• %s[/color]\n" % [line[1].to_html(false), line[0]]
	_tip.text = s
