class_name SheetDB
extends RefCounted
## Loads sprite sheets rendered by tools/blender (json + _c/_n/_e pngs) and
## builds a CanvasTexture (diffuse + normal) plus the emission texture.

class Sheet:
	var name: String
	var fw: int
	var fh: int
	var origin: Vector2
	var rows: int
	var cols: int
	var dirs: int = 1
	var tex: CanvasTexture
	var emit: Texture2D
	var meta: Dictionary

	func region(row: int, col: int) -> Rect2:
		return Rect2(col * fw, row * fh, fw, fh)

	## Sprite2D offset (centered=true) that puts the origin pixel on the node position.
	func offset() -> Vector2:
		return Vector2(fw * 0.5 - origin.x, fh * 0.5 - origin.y)

	## Grid-layout sheets (player torso) pack N directions row-major.
	func dir_region(d: int) -> Rect2:
		return region(d / cols, d % cols)


static var _cache := {}


static func get_sheet(path: String) -> Sheet:
	if _cache.has(path):
		return _cache[path]
	var txt := FileAccess.get_file_as_string(path + ".json")
	if txt.is_empty():
		push_error("SheetDB: missing sheet " + path)
		return null
	var meta: Dictionary = JSON.parse_string(txt)
	var s := Sheet.new()
	s.name = meta.get("name", path)
	s.fw = int(meta["frame_w"])
	s.fh = int(meta["frame_h"])
	s.origin = Vector2(meta["origin"][0], meta["origin"][1])
	s.rows = int(meta["rows"])
	s.cols = int(meta["cols"])
	s.dirs = int(meta.get("dirs", s.rows))
	s.meta = meta
	var dir := path.get_base_dir()
	var files: Dictionary = meta["files"]
	s.tex = CanvasTexture.new()
	s.tex.diffuse_texture = load(dir + "/" + files["color"])
	if files.has("normal"):
		s.tex.normal_texture = load(dir + "/" + files["normal"])
	s.tex.specular_color = Color(0.55, 0.6, 0.7)
	s.tex.specular_shininess = 0.6
	if files.has("emit"):
		s.emit = load(dir + "/" + files["emit"])
	_cache[path] = s
	return s
