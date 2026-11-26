class_name GlowMat
extends RefCounted
## Shared glow/rim materials keyed by sprite sheet + rim colour, so many
## enemies of one type batch together.

const SHADER := preload("res://src/vfx/shaders/glow_rim.gdshader")
static var _cache := {}


static func get_mat(sheet, rim: Color, intensity := 2.2) -> ShaderMaterial:
	var key := "%s|%s|%.2f" % [sheet.name, rim.to_html(), intensity]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("body_tex", sheet.tex.diffuse_texture)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("emit_on", 1.0 if sheet.emit else 0.0)
	m.set_shader_parameter("rim_color", rim)
	_cache[key] = m
	return m


## Texture to give the glow sprite (emission if present, else the diffuse just to drive the rim).
static func glow_texture(sheet) -> Texture2D:
	return sheet.emit if sheet.emit else sheet.tex.diffuse_texture
