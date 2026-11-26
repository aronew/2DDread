extends Node
## Loads every script/resource so parse/compile errors surface in one pass.
## Run as a scene (autoloads must exist):
##   godot --headless --path . res://tools/dev/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	for path in _walk("res://src") + _walk("res://data"):
		if path.ends_with(".gd") or path.ends_with(".tres") or path.ends_with(".gdshader"):
			var r = load(path)
			if r == null:
				bad += 1
				print("FAILED: ", path)
	print("check done, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _walk(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out
