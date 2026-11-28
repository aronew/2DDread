class_name PlayerVisual
extends Node2D
## Composites the player's legs (movement direction, run cycle, backpedal)
## and torso+weapon (aim direction, 32 dirs). Both layers share the feet origin.
## Two animations take over from them for a moment:
##   swing()  the Hellfire Saber: the torso shows a sword-swing sheet (16 dirs) in the
##            swing's direction while the legs keep running;
##   dash     the whole body in a low lunge (one sheet, 16 dirs x 3 frames) drawn on the
##            legs sprite with the torso hidden, while update()'s dash_k >= 0.

const SHEET_DIR := "res://assets/sprites/player/"
const STRIDE_M := 2.3
const RIM := Color(1.0, 0.82, 0.55, 0.38)
## Saber swings: (fraction of the swing, frame) keys. The slash effect sweeps in the first
## ~30% of a swing, so the blade gets across by then. "back" is the light sheet played
## backwards (the combo's second swing sweeps the other way).
const SWING_SEQ := {
	"light": [[0.08, 0], [0.17, 1], [0.45, 2], [0.75, 3], [1.0, 4]],
	"back": [[0.08, 3], [0.16, 2], [0.26, 1], [1.0, 0]],
	"heavy": [[0.07, 0], [0.15, 1], [0.24, 2], [0.45, 3], [0.75, 4], [1.0, 5]],
	"thrust": [[0.25, 0], [1.0, 1]],
}
const DASH_SEQ := [[0.2, 0], [0.78, 1], [9.0, 2]]   # push off, flight, landing (k past 1 = landing hold)

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
var saber_sheets := {}
var dash_sheet
var _act := {}            # the saber swing being shown: kind, sheet, dir, t, dur
var _dash_shown := false


func _ready() -> void:
	legs_sheet = SheetDB.get_sheet(SHEET_DIR + "player_legs")
	_bob = legs_sheet.meta.get("bob_m", [])
	for t in ["rifle", "shotgun", "arc", "rail"]:
		torso_sheets[t] = SheetDB.get_sheet(SHEET_DIR + "player_torso_" + t)
	for k in ["light", "heavy", "thrust"]:
		if FileAccess.file_exists(SHEET_DIR + "player_saber_" + k + ".json"):
			saber_sheets[k] = SheetDB.get_sheet(SHEET_DIR + "player_saber_" + k)
	if FileAccess.file_exists(SHEET_DIR + "player_dash.json"):
		dash_sheet = SheetDB.get_sheet(SHEET_DIR + "player_dash")
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
	if _act.is_empty():
		_show_sheet(torso, torso_glow, torso_sheets[name])


func _show_sheet(s: Sprite2D, glow: Sprite2D, sh) -> void:
	s.texture = sh.tex
	s.offset = sh.offset()
	glow.texture = GlowMat.glow_texture(sh)
	glow.offset = sh.offset()
	glow.material = GlowMat.get_mat(sh, RIM, 2.4)


## Show a saber swing: kind "light", "back" (light, reversed), "heavy" or "thrust",
## toward ground direction gdir, over dur seconds.
func swing(kind: String, gdir: Vector2, dur: float) -> void:
	var sk := "light" if kind == "back" else kind
	if not saber_sheets.has(sk):
		return
	_act = {"kind": kind, "sheet": saber_sheets[sk], "dir": gdir, "t": 0.0, "dur": maxf(dur, 0.05)}
	_show_sheet(torso, torso_glow, _act["sheet"])


## Back to the gun (a shot ends the tail of a swing early).
func end_swing() -> void:
	if _act.is_empty():
		return
	_act = {}
	_show_sheet(torso, torso_glow, torso_sheets[_cur_torso])


static func _key_frame(seq: Array, f: float) -> int:
	for k in seq:
		if f < k[0]:
			return k[1]
	return seq.back()[1]


func muzzle_m() -> Vector3:
	var meta: Dictionary = torso_sheets[_cur_torso].meta
	var m: Array = meta.get("muzzle2_m", meta.get("muzzle_m")) if muzzle_alt and meta.has("muzzle2_m") else meta.get("muzzle_m", [1.0, -0.12, 1.3])
	return Vector3(m[0], m[1], m[2])


func kick(amount: float, gdir: Vector2) -> void:
	recoil = minf(recoil + amount, 14.0)
	_recoil_dir = -Iso.to_screen(gdir).normalized()


## dash_k: progress through a dash (0..1, then a moment past 1 for the landing), or < 0.
func update(dt: float, vel: Vector2, aim_dir: Vector2, dashing: bool, dash_k := -1.0) -> void:
	if not _act.is_empty():
		_act["t"] += dt
		if _act["t"] >= _act["dur"]:
			end_swing()
	var dash_on := dash_k >= 0.0 and dash_sheet != null and _act.is_empty()
	if dash_on != _dash_shown:
		_dash_shown = dash_on
		_show_sheet(legs, legs_glow, dash_sheet if dash_on else legs_sheet)
		torso.visible = not dash_on
		torso_glow.visible = not dash_on
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
	if dash_on:
		if speed_m > 0.6:
			leg_dir = vel.normalized()
		legs.region_rect = dash_sheet.region(Iso.dir_index(leg_dir, dash_sheet.dirs), _key_frame(DASH_SEQ, dash_k))
	else:
		legs.region_rect = legs_sheet.region(Iso.dir_index(leg_dir, legs_sheet.dirs), col)
	legs_glow.region_rect = legs.region_rect
	if not _act.is_empty():
		var ash = _act["sheet"]
		var fr := _key_frame(SWING_SEQ[_act["kind"]], _act["t"] / _act["dur"])
		torso.region_rect = ash.region(Iso.dir_index(_act["dir"], ash.dirs), fr)
	else:
		torso.region_rect = torso_sheets[_cur_torso].dir_region(Iso.dir_index(aim_dir, 32))
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
