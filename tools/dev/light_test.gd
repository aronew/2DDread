extends SceneTree
## Lighting sanity check for normal-map orientation: wall blocks lit by a
## point light from 4 sides. Captures light_test_<dir>.png.
##   xvfb-run godot --path . --script res://tools/dev/light_test.gd -- out_dir

var out := "/tmp"
var l: PointLight2D
var frame := 0
var spots := [["below", Vector2(0, 300)], ["above", Vector2(0, -260)], ["left", Vector2(-520, 120)], ["right", Vector2(520, 120)]]


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var root := Node2D.new()
	get_root().add_child(root)
	var cm := CanvasModulate.new()
	cm.color = Color(0.15, 0.15, 0.18)
	root.add_child(cm)
	var cam := Camera2D.new()
	root.add_child(cam)
	var sh = SheetDB.get_sheet("res://assets/sprites/env/wall_blocks")
	for i in 3:
		var s := Sprite2D.new()
		s.texture = sh.tex
		s.region_enabled = true
		s.region_rect = sh.region(0, i)
		s.offset = sh.offset()
		s.position = Vector2(-300 + i * 300, 100)
		root.add_child(s)
	l = PointLight2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	l.texture = gt
	l.texture_scale = 5.0
	l.energy = 2.0
	l.height = 120.0
	root.add_child(l)


func _process(_dt: float) -> bool:
	frame += 1
	var idx := frame / 8
	if idx >= spots.size():
		return true
	l.position = spots[idx][1]
	if frame % 8 == 7:
		get_root().get_texture().get_image().save_png("%s/light_test_%s.png" % [out, spots[idx][0]])
	return false
