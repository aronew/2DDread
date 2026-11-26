class_name Perk
extends RefCounted
## Base class for behaviour modifiers. Weapon-bound perks only fire for hits
## produced by that weapon; gear perks apply to everything.

var id: StringName
var build
var weapon = null


func applies(info: DamageInfo) -> bool:
	return weapon == null or info.weapon == weapon


func stat_bonus() -> Dictionary:
	return {}


func before_hit(_e, _info: DamageInfo) -> void:
	pass


func after_hit(_e, _info: DamageInfo, _dealt: float, _killed: bool) -> void:
	pass


func on_kill(_e, _info: DamageInfo) -> void:
	pass


func on_fire(_w, _projs: Array) -> void:
	pass


func on_dash(_a: Vector2, _b: Vector2) -> void:
	pass


func on_explosion(_g: Vector2, _r: float, _info: DamageInfo) -> void:
	pass


func process(_dt: float) -> void:
	pass
