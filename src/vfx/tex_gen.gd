class_name TexGen
extends RefCounted
## Procedural textures for VFX (generated once at startup).


static func radial(size: int, stops: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


static func glow() -> Texture2D:
	return radial(128, [0.0, 0.2, 0.55, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])


static func core() -> Texture2D:
	return radial(64, [0.0, 0.35, 0.7, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])


static func ring() -> Texture2D:
	return radial(256, [0.0, 0.72, 0.86, 0.93, 1.0],
		[Color(1, 1, 1, 0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])


static func shadow() -> Texture2D:
	return radial(128, [0.0, 0.5, 1.0], [Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])


static func spark() -> Texture2D:
	var img := Image.create(12, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 12:
			var dx := (x - 5.5) / 5.5
			var fy := float(y) / 47.0
			var a := exp(-dx * dx * 4.0) * pow(1.0 - absf(fy - 0.35) / 0.65, 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)


static func noise_blob(size: int, seed_: int, softness := 0.35, threshold := 0.45, holes := false) -> Texture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 3.2 / size
	n.fractal_octaves = 4
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var shape := 1.0 - d + (v - 0.5) * 0.9
			var a := smoothstep(threshold - softness * 0.5, threshold + softness * 0.5, shape)
			if holes:
				a *= smoothstep(0.25, 0.55, v + (1.0 - d) * 0.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func smoke(size: int, seed_: int) -> Texture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 4.0 / size
	n.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.6, 0, 1) * (0.45 + v * 0.75)
			a = clampf(a * (1.0 - d * d), 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func shard() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var pts := [Vector2(8, 0), Vector2(15, 6), Vector2(10, 15), Vector2(1, 9)]
	for y in 16:
		for x in 16:
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array(pts)):
				var shade := 0.7 + 0.3 * (1.0 - float(y) / 16.0)
				img.set_pixel(x, y, Color(shade, shade, shade, 1))
	return ImageTexture.create_from_image(img)


## Muzzle flash: bright core with n spikes, pointing along +X.
static func flash(spikes := 5) -> Texture2D:
	var w := 128
	var hgt := 64
	var img := Image.create(w, hgt, false, Image.FORMAT_RGBA8)
	for y in hgt:
		for x in w:
			var p := Vector2(x - 20.0, (y - hgt * 0.5))
			var ang := atan2(p.y, maxf(p.x, 0.001))
			var r := p.length()
			var lobe := pow(maxf(0.0, cos(ang * spikes * 0.5)), 6.0)
			var reach := 14.0 + 30.0 * lobe + (90.0 * exp(-ang * ang * 30.0))
			var a := clampf(1.0 - r / reach, 0, 1)
			a = pow(a, 1.4)
			if p.x < 0:
				a *= clampf(1.0 + p.x / 14.0, 0, 1)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Crescent slash arc for melee, opening toward +X.
## A centred star with thin rays (a lens-flare cross): the white-hot heart of a muzzle
## flash or a kill pop.
static func star(spikes := 4) -> Texture2D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x - c + 0.5, y - c + 0.5)
			var r := p.length() / c
			var ang := atan2(p.y, p.x)
			var ray := pow(absf(cos(ang * spikes * 0.5)), 40.0)
			var a := exp(-r * r * 30.0) + ray * clampf(1.0 - r, 0, 1) * 0.9
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)


static func slash() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var p := Vector2(x, y) - c
			var r := p.length() / (size * 0.5)
			var ang := atan2(p.y, p.x)
			var band := exp(-pow((r - 0.82) / 0.09, 2.0))
			var arc := clampf(1.0 - absf(ang) / 1.35, 0, 1)
			var tip := pow(arc, 0.6)
			var a := band * tip * (0.6 + 0.4 * (1.0 - absf(ang) / 1.35))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0, 1)))
	return ImageTexture.create_from_image(img)
