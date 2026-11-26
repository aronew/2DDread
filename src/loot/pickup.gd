class_name Pickup
extends Node2D
## World pickup: XP / health / ammo orbs (pop out, then magnetise) and items
## (rarity-coloured beam + nameplate, collected on contact).

var kind: StringName
var data: Dictionary
var gpos := Vector2.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _z := 0.0
var _age := 0.0
var _vel := Vector2.ZERO
var _label: Label
var _beam: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _done := false


static func spawn(kind_: StringName, g: Vector2, data_: Dictionary) -> Pickup:
	if Game.world == null:
		return null
	var p := Pickup.new()
	p.kind = kind_
	p.data = data_
	p._from = g
	p._to = Loot.scatter(g, 1.6 if kind_ == &"item" else 1.1)
	p.gpos = g
	Game.world.entities.add_child(p)
	return p


func _ready() -> void:
	var col := _color()
	_glow = Sprite2D.new()
	_glow.texture = VFX.T.glow
	_glow.material = VFX.add_mat
	add_child(_glow)
	match kind:
		&"xp":
			_glow.scale = Vector2(0.28, 0.28)
			_glow.modulate = col * 2.5
		&"health":
			_glow.scale = Vector2(0.32, 0.32)
			_glow.modulate = col * 2.0
		&"ammo":
			_glow.scale = Vector2(0.3, 0.3)
			_glow.modulate = col * 1.8
		&"item":
			var it: Item = data["item"]
			_glow.scale = Vector2(0.38, 0.38)
			_glow.modulate = col * (1.0 + it.rarity * 0.3)
			if it.rarity >= Item.Rarity.RARE:
				_beam = Sprite2D.new()
				_beam.texture = VFX.T.spark
				_beam.material = VFX.add_mat
				_beam.scale = Vector2(1.2 + it.rarity * 0.35, 3.0 + it.rarity * 0.9)
				_beam.offset = Vector2(0, -16)
				_beam.modulate = col * Color(1.6, 1.6, 1.6, 0.7)
				add_child(_beam)
			_light = PointLight2D.new()
			_light.texture = VFX.T.light
			_light.color = col
			_light.energy = 0.6 + it.rarity * 0.15
			_light.texture_scale = 1.1
			_light.scale = Vector2(1, Iso.K)
			_light.height = 40.0
			add_child(_light)
			_label = Label.new()
			var ls := LabelSettings.new()
			ls.font_size = 20
			ls.outline_size = 6
			ls.outline_color = Color(0, 0, 0, 0.9)
			ls.font_color = col
			_label.label_settings = ls
			_label.text = it.display_name()
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.size = Vector2(320, 28)
			_label.position = Vector2(-160, -78)
			_label.z_index = 50
			add_child(_label)
	position = Iso.to_screen(gpos)


func _color() -> Color:
	match kind:
		&"xp":
			return Color(0.55, 1.0, 0.78)
		&"health":
			return Color(1.0, 0.18, 0.2)
		&"ammo":
			return Color(1.0, 0.75, 0.25)
		&"item":
			return data["item"].color()
	return Color.WHITE


func _process(dt: float) -> void:
	if _done:
		return
	_age += dt
	var pl = Game.player
	if _t < 1.0:
		_t = minf(1.0, _t + dt / 0.45)
		gpos = _from.lerp(_to, _t)
		_z = sin(_t * PI) * (1.2 if kind == &"item" else 0.8)
	else:
		_z = 0.12 + sin(_age * 4.0) * 0.06
		if pl and pl.alive:
			var d: float = pl.gpos.distance_to(gpos)
			var magnet := Iso.m(4.5 if kind == &"xp" else 3.0)
			var wants: bool = kind != &"item" and not (kind == &"health" and pl.hp >= pl.max_hp) and not (kind == &"ammo" and pl.ammo_need() <= 0.0)
			if wants and d < magnet:
				var acc: float = lerpf(3000.0, 9000.0, 1.0 - d / magnet)
				_vel = _vel.move_toward((pl.gpos - gpos).normalized() * Iso.m(16.0), acc * dt)
				gpos += _vel * dt
			if d < pl.radius + Iso.m(0.35 if kind != &"item" else 0.6):
				_collect(pl)
				return
	position = Iso.to_screen(gpos)
	_glow.position = Vector2(0, -Iso.h(_z) - 6.0)
	if _beam:
		_beam.position = _glow.position
		_beam.modulate.a = 0.5 + 0.2 * sin(_age * 3.0)


func _collect(pl) -> void:
	match kind:
		&"xp":
			pl.add_xp(int(data.get("value", 1)))
			Audio.play("xp_orb", gpos)
		&"health":
			pl.heal(data.get("value", 10.0))
			Audio.play("pickup_orb", gpos)
			VFX.burst_sprite(VFX.T.glow, Iso.lift(gpos, 0.5), Color(3, 0.6, 0.6), Vector2(0.3, 0.3), Vector2(1.2, 1.2), 0.2)
		&"ammo":
			pl.add_ammo_fraction(data.get("value", 0.12))
			Audio.play("pickup_orb", gpos, 0.0, 0.8)
		&"item":
			if not pl.inventory_add(data["item"]):
				return
			Audio.play("pickup_item", gpos)
	_done = true
	queue_free()
