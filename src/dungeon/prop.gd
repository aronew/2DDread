class_name Prop
extends Node2D
## Placed environment object. Some block movement/shots, some are destructible:
## explosive barrels chain-react, crates drop supplies, egg nests spawn mites
## while an encounter is live, chests release loot.

const DEFS := {
	"barrel": {"r": 0.36, "hp": 22.0, "explode": true},
	"crate": {"r": 0.55, "hp": 40.0, "loot": "supply"},
	"canisters": {"r": 0.42, "hp": 14.0, "loot": "minor"},
	"chest": {"r": 0.75, "hp": -1.0, "chest": true},
	"eggs": {"r": 0.62, "hp": 110.0, "nest": true, "light": [Color(0.4, 1.0, 0.5), 0.55, 2.8, 0.4]},
	"crystals": {"r": 0.5, "hp": -1.0, "light": [Color(0.3, 0.9, 1.0), 0.8, 3.6, 0.7]},
	"pylon": {"r": 0.28, "hp": -1.0, "light": [Color(0.4, 0.9, 1.0), 1.25, 6.5, 2.2]},
	"cryotube": {"r": 0.52, "hp": -1.0, "light": [Color(0.3, 0.95, 0.85), 0.8, 3.8, 1.2]},
}

var kind := ""
var gpos := Vector2.ZERO
var radius := 30.0
var hp := -1.0
var max_hp := -1.0
var alive := true
var blocks_movement := true
var blocks_shots := true
var light_color := Color(0, 0, 0, 0)
var light_energy := 0.0
var light_range_m := 0.0
var light_height_m := 0.5
var chest_quality := "rare"
var chest_locked := false
var nest_active := false
var dungeon

var _def: Dictionary
var _sheet
var _body: Sprite2D
var _glow: Sprite2D
var _flash := 0.0
var _spawn_t := 3.0
var _opened := false
var _pulse := 0.0


func setup(kind_: String, g: Vector2, dungeon_) -> void:
	kind = kind_
	gpos = g
	dungeon = dungeon_
	_def = DEFS[kind]
	radius = Iso.m(_def["r"])
	hp = _def["hp"]
	max_hp = hp
	if _def.has("light"):
		var l: Array = _def["light"]
		light_color = l[0]
		light_energy = l[1]
		light_range_m = l[2]
		light_height_m = l[3]
	position = Iso.to_screen(g)
	_sheet = SheetDB.get_sheet("res://assets/sprites/props/" + kind)
	var shadow := VFX.make_shadow(Iso.m(_def["r"]) * 1.25)
	add_child(shadow)
	_body = Sprite2D.new()
	_body.texture = _sheet.tex
	_body.region_enabled = true
	_body.region_rect = _sheet.region(0, 0)
	_body.offset = _sheet.offset()
	add_child(_body)
	if _sheet.emit:
		_glow = Sprite2D.new()
		_glow.texture = _sheet.emit
		_glow.region_enabled = true
		_glow.region_rect = _body.region_rect
		_glow.offset = _body.offset
		_glow.material = VFX.add_mat
		_glow.modulate = Color(2.2, 2.2, 2.2)
		add_child(_glow)


func destructible() -> bool:
	return max_hp > 0.0


func take_damage(info: DamageInfo) -> void:
	if not alive:
		return
	if not destructible():
		VFX.impact(info.hit_pos if info.hit_pos != Vector2.ZERO else gpos, 0.6, -info.direction, "metal")
		return
	hp -= info.amount
	_flash = 1.0
	if hp <= 0.0:
		_break(info)


func _break(info: DamageInfo) -> void:
	alive = false
	dungeon.remove_prop(self)
	if _def.get("explode", false):
		# short fuse so chained barrels ripple instead of popping on one frame
		var t := get_tree().create_timer(0.08 if info.is_explosion else 0.0)
		await t.timeout
		var d := DamageInfo.make(70.0, DamageInfo.Type.EXPLOSIVE, self)
		d.knockback = Iso.m(9.0)
		d.stagger = 60.0
		d.status = {&"burn": 1.0}
		Combat.explode(gpos, Iso.m(3.2), d, true)
		VFX.burning_ground(gpos, Iso.m(2.0), 4.0, d.source)
	else:
		VFX.debris(gpos, 1.2, 16)
		Audio.play("crate_break", gpos)
		match _def.get("loot", ""):
			"supply":
				Loot.drop_supplies(gpos, 2, 0.12)
			"minor":
				Loot.drop_supplies(gpos, 1, 0.0)
	if _def.get("nest", false):
		VFX.gore(gpos, Color(0.4, 1.0, 0.45), 1.6)
		Audio.play("enemy_death_big", gpos)
		Game.hit_stop(0.05)
	queue_free()


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 8.0)
		_body.modulate = Color(1, 1, 1).lerp(Color(3, 3, 3), _flash)
	if _def.get("chest", false) and not _opened and not chest_locked:
		var pl = Game.player
		if pl and pl.alive and pl.gpos.distance_to(gpos) < radius + Iso.m(1.1):
			open_chest()
	if _def.get("nest", false) and alive:
		_update_nest(dt)


func _update_nest(dt: float) -> void:
	_pulse += dt * (6.0 if nest_active else 1.5)
	var s := 1.0 + sin(_pulse) * (0.04 if nest_active else 0.015)
	_body.scale = Vector2(s, s)
	if _glow:
		_glow.scale = _body.scale
		_glow.modulate = Color(1, 1, 1) * (2.0 + (sin(_pulse * 2.0) * 1.2 if nest_active else 0.0))
	if not nest_active:
		return
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = 4.5
		if Game.living_enemies() < 26 and Game.world:
			var off := Vector2.from_angle(randf() * TAU) * (radius + Iso.m(0.6))
			Game.world.spawn_enemy("mite", gpos + off, {"from_nest": true})
			VFX.gore(gpos, Color(0.4, 1.0, 0.45), 0.6)


func open_chest() -> void:
	_opened = true
	_body.region_rect = _sheet.region(0, 1)
	if _glow:
		_glow.region_rect = _body.region_rect
	Audio.play("chest_open", gpos)
	VFX.light_flash(position - Vector2(0, 30), Color(1.0, 0.75, 0.35), 2.5, 4.0, 0.6)
	VFX.ring(gpos, Iso.m(2.0), Color(1.0, 0.7, 0.3), 0.5)
	Loot.drop_chest(gpos, chest_quality)
