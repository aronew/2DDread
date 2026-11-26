class_name EnemyOverlay
extends Node2D
## Health/shield bar above an enemy (shown briefly after damage, always for
## elites) plus elite nameplate and affix tags.

var enemy
var _font: Font


func _ready() -> void:
	z_index = 40
	_font = ThemeDB.fallback_font


func _draw() -> void:
	var e = enemy
	if e == null or not e.alive or e.state == Enemy.S.SPAWN:
		return
	if not e.is_elite and e._show_bar_t <= 0.0:
		return
	var top: float = -Iso.h(e.hit_height * 2.0 + 0.6) * e.data.visual_scale - (34.0 if e.is_elite else 0.0)
	var w := 70.0 if not e.is_elite else 150.0
	var hgt := 7.0 if not e.is_elite else 10.0
	var x := -w * 0.5
	draw_rect(Rect2(x - 2, top - 2, w + 4, hgt + 4), Color(0, 0, 0, 0.75))
	var frac: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
	var col := Color(0.95, 0.2, 0.2) if not e.is_elite else Color(1.0, 0.6, 0.15)
	draw_rect(Rect2(x, top, w * frac, hgt), col)
	if e.shield_max > 0.0 and e.shield > 0.0:
		draw_rect(Rect2(x, top - 5, w * e.shield / e.shield_max, 4), Color(0.4, 0.75, 1.0))
	if e.state == Enemy.S.STAGGER:
		draw_rect(Rect2(x - 2, top - 2, w + 4, hgt + 4), Color(1.0, 0.8, 0.3, 0.9), false, 2.0)
	if e.is_elite:
		var name: String = "ELITE " + e.data.display_name.to_upper()
		var fs := 18
		var tw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, Vector2(-tw * 0.5, top - 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
		draw_string(_font, Vector2(-tw * 0.5, top - 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.75, 0.3))
		var tags: String = " · ".join(e.affixes.map(func(a): return String(a).to_upper()))
		var tw2 := _font.get_string_size(tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(_font, Vector2(-tw2 * 0.5, top + hgt + 18), tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
		draw_string(_font, Vector2(-tw2 * 0.5, top + hgt + 18), tags, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.45))
