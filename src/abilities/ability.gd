class_name Ability
extends RefCounted
## Active ability base: cooldown bookkeeping + HUD metadata.

var title := "Ability"
var key_hint := "Q"
var color := Color(0.5, 0.8, 1.0)
var cooldown := 8.0
var cd_left := 0.0
var cd_total := 1.0


func is_ready() -> bool:
	return cd_left <= 0.0


func try_use(p) -> bool:
	if cd_left > 0.0 or not p.alive:
		return false
	if not use(p):
		return false
	cd_total = cooldown * maxf(0.3, 1.0 - p.build.stat("cooldown_pct"))
	cd_left = cd_total
	return true


func use(_p) -> bool:
	return true


func process(dt: float, _p) -> void:
	cd_left = maxf(0.0, cd_left - dt)


func progress() -> float:
	return 1.0 - cd_left / maxf(0.01, cd_total) if cd_left > 0.0 else 1.0


func power(p) -> float:
	return p.build.mult("ability_power_pct")
