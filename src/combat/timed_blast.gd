class_name TimedBlast
extends Node2D
## Telegraphed delayed explosion (elite mines, volatile death, bloater pops).

var gpos := Vector2.ZERO
var radius := 100.0
var delay := 1.0
var damage := 20.0
var source: Object = null
var color := Color(1.0, 0.6, 0.2)
var _t := 0.0
var _tele: Telegraph


func setup(g: Vector2, r: float, d: float, dmg: float, src: Object, col: Color) -> void:
	gpos = g
	radius = r
	delay = d
	damage = dmg
	source = src
	color = col
	position = Iso.to_screen(g)


func _ready() -> void:
	_tele = VFX.telegraph_circle(gpos, radius, delay, color)
	Audio.play("bloater_prime", gpos, -6.0, 1.4)


func _process(dt: float) -> void:
	_t += dt
	if _t >= delay:
		var d := DamageInfo.make(damage, DamageInfo.Type.EXPLOSIVE, source)
		d.knockback = Iso.m(9.0)
		d.stagger = 50.0
		Combat.explode(gpos, radius, d, true, color, radius > Iso.m(3.0))
		queue_free()
	queue_redraw()


func _draw() -> void:
	var blink := 0.5 + 0.5 * sin(_t * (10.0 + _t * 30.0))
	draw_texture_rect(VFX.T.glow, Rect2(Vector2(-18, -26), Vector2(36, 36)), false, color * Color(2.5, 2.5, 2.5, blink))
