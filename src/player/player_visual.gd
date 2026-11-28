class_name PlayerVisual
extends Node2D
## Composites the player's legs (movement direction, run cycle, backpedal)
## and torso+weapon (aim direction, 32 dirs). Both layers share the feet origin.

const SHEET_DIR := "res://assets/sprites/player/"
const STRIDE_M := 2.3
const RIM := Color(1.0, 0.82, 0.55, 0.38)

var legs_sheet
var torso_sheets := {}
var legs: Sprite2D
var legs_glow: Sprite2D
var torso: Sprite2D
var torso_glow: Sprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var phase := 0.0
var leg_dir := Vector2.RIGHT
var torso_offset := Vector2.ZERO
var recoil := 0.0
var _recoil_dir := Vector2.ZERO
var _cur_torso := ""
var muzzle_alt := false   # twin revolvers alternate barrels
var _bob: Array = []
var _lean := 0.0


func _ready() -> void:
	legs_sheet = SheetDB.get_sheet(SHEET_DIR + "player_legs")
	_bob = legs_sheet.meta.get("bob_m", [])
	for t in ["rifle", "shotgun", "arc", "rail"]:
		torso_sheets[t] = SheetDB.get_sheet(SHEET_DIR + "player_torso_" + t)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://src/vfx/shaders/entity.gdshader")
	shadow = VFX.make_shadow(Iso.m(0.5))
	add_child(shadow)
	legs = _sprite(legs_sheet.tex, legs_sheet)
	legs.material = mat
	legs_glow = _glow_sprite(legs_sheet)
	torso = _sprite(null, torso_sheets["rifle"])
	torso.material = mat
	torso_glow = _glow_sprite(torso_sheets["rifle"])
	set_torso("rifle")


func _sprite(tex, sheet) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex if tex else sheet.tex
	s.region_enabled = true
	s.region_rect = sheet.region(0, 0)
	s.offset = sheet.offset()
	add_child(s)
	return s


func _glow_sprite(sheet) -> Sprite2D:
	var s := Sprite2D.new()
	s.region_enabled = true
	s.material = GlowMat.get_mat(sheet, RIM, 2.4)
	s.texture = GlowMat.glow_texture(sheet)
	s.offset = sheet.offset()
	add_child(s)
	return s


func set_torso(name: String) -> void:
	if name == _cur_torso or not torso_sheets.has(name):
		return
	_cur_torso = name
	var sh = torso_sheets[name]
	torso.texture = sh.tex
	torso.offset = sh.offset()
	torso_glow.texture = GlowMat.glow_texture(sh)
	torso_glow.offset = sh.offset()
	torso_glow.material = GlowMat.get_mat(sh, RIM, 2.4)


func muzzle_m() -> Vector3:
	var meta: Dictionary = torso_sheets[_cur_torso].meta
	var m: Array = meta.get("muzzle2_m", meta.get("muzzle_m")) if muzzle_alt and meta.has("muzzle2_m") else meta.get("muzzle_m", [1.0, -0.12, 1.3])
	return Vector3(m[0], m[1], m[2])


func kick(amount: float, gdir: Vector2) -> void:
	recoil = minf(recoil + amount, 14.0)
	_recoil_dir = -Iso.to_screen(gdir).normalized()


func update(dt: float, vel: Vector2, aim_dir: Vector2, dashing: bool) -> void:
	var speed_m := vel.length() / Iso.PX_PER_M
	var moving := speed_m > 0.6
	var col := 8
	var bob := 0.0
	if moving:
		var mdir := vel.normalized()
		var backwards := mdir.dot(aim_dir) < -0.2
		leg_dir = -mdir if backwards else mdir
		phase = fposmod(phase + (speed_m * dt / STRIDE_M) * (-1.0 if backwards else 1.0), 1.0)
		col = int(phase * 8.0) % 8
		if _bob.size() == 8:
			bob = _bob[col]
	else:
		leg_dir = leg_dir.slerp(aim_dir, minf(1.0, dt * 10.0)).normalized()
	var ld := Iso.dir_index(leg_dir, legs_sheet.dirs)
	legs.region_rect = legs_sheet.region(ld, col)
	legs_glow.region_rect = legs.region_rect
	var sh = torso_sheets[_cur_torso]
	var td := Iso.dir_index(aim_dir, 32)
	torso.region_rect = sh.dir_region(td)
	torso_glow.region_rect = torso.region_rect
	recoil = move_toward(recoil, 0.0, dt * 70.0)
	torso_offset = Vector2(0, -bob * Iso.HPX_PER_M) + _recoil_dir * recoil
	torso.position = torso_offset
	torso_glow.position = torso_offset
	# lean into the run (and hard into a dash), toward where we're going on screen
	var sv := Iso.to_screen(vel)
	var lean := clampf(sv.x / Iso.m(8.0), -1.4, 1.4) * (0.15 if dashing else 0.06)
	_lean = lerpf(_lean, lean, 1.0 - exp(-18.0 * dt))
	legs.skew = _lean
	torso.skew = _lean
	# a stretch along the dash, settling back after it
	var want := Vector2(1.07, 0.94) if dashing else Vector2.ONE
	scale = scale.lerp(want, 1.0 - exp(-20.0 * dt))


func set_flash(v: float, color := Color(1, 1, 1)) -> void:
	mat.set_shader_parameter("flash", v)
	mat.set_shader_parameter("flash_color", color)


func sprites() -> Array:
	return [legs, torso]
