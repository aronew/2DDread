class_name WeaponDB
extends RefCounted
## Registry of WeaponData resources in res://data/weapons.

const DIR := "res://data/weapons/"
const LOOTABLE := [&"rifle", &"shotgun", &"arc", &"rail"]

static var _db := {}


static func _ensure() -> void:
	if not _db.is_empty():
		return
	for f in ["rifle", "shotgun", "arc", "rail", "launcher"]:
		var path: String = DIR + f + ".tres"
		if ResourceLoader.exists(path):
			var d: WeaponData = load(path)
			_db[d.id] = d


static func get_data(id: StringName) -> WeaponData:
	_ensure()
	return _db.get(id)
