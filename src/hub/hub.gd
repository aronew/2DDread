class_name Hub
extends Node2D
## The hub's live parts, built over LayoutHub's map: the stations (bar, forge, ferry), the
## lingering souls, Charon and the moored ferry, and the "E" prompt. Stations open a
## HubMenu; souls say a line. Lives under the level root, so it goes with the level.

const TALK_REACH_M := 1.7

var stations: Array = []    # {kind, name, at, use, reach, node}
var shades: Array = []      # Shade nodes
var charon: Shade
var _focus = null           # the station dict or Shade the prompt points at
var _prompt: HubPrompt


func setup(entities: Node2D) -> void:
	for sd in LayoutHub.STATIONS:
		var st: Dictionary = sd.duplicate()
		st["at_g"] = Iso.tile_to_ground(Vector2(sd["at"][0], sd["at"][1]))
		st["use_g"] = Iso.tile_to_ground(Vector2(sd["use"][0], sd["use"][1]))
		match st["kind"]:
			"bar":
				charon = Shade.new()
				charon.setup("charon", st["at_g"], [], Shade.CHARON)
				entities.add_child(charon)
				var bar := HubProp.new()   # bottles, mugs and a candle along the counter
				bar.setup("bar", Iso.tile_to_ground(Vector2(5.0, 3.55)))
				entities.add_child(bar)
				st["node"] = charon
			"forge":
				var a := HubProp.new()
				a.setup("anvil", st["at_g"])
				entities.add_child(a)
				st["node"] = a
			"ferry":
				var b := HubProp.new()
				b.setup("ferry", st["at_g"])
				entities.add_child(b)
				st["node"] = b
		stations.append(st)
	for sd in LayoutHub.SHADES:
		var s := Shade.new()
		s.setup(sd["id"], Iso.tile_to_ground(Vector2(sd["at"][0], sd["at"][1])), sd["lines"],
			Shade.SMITH if sd.get("smith", false) else Shade.SOUL)
		entities.add_child(s)
		shades.append(s)
	_prompt = HubPrompt.new()
	_prompt.z_index = 40
	add_child(_prompt)


func hide_figures() -> void:
	for st in stations:
		st["node"].visible = false
	for s in shades:
		s.visible = false
	for n in get_parent().find_children("*", "HubProp", true, false):
		n.visible = false


func station(kind: String) -> Dictionary:
	for st in stations:
		if st["kind"] == kind:
			return st
	return {}


func _process(_dt: float) -> void:
	var pl = Game.player
	if pl == null or not pl.alive or get_tree().paused:
		_set_focus(null)
		return
	var best = null
	var best_d := INF
	for st in stations:
		var d: float = pl.gpos.distance_to(st["use_g"])
		if d < Iso.m(st["reach"]) and d < best_d:
			best = st
			best_d = d
	for s in shades:
		var d: float = pl.gpos.distance_to(s.gpos)
		if d < Iso.m(TALK_REACH_M) and d < best_d:
			best = s
			best_d = d
	_set_focus(best)
	if best != null and Input.is_action_just_pressed("interact"):
		interact(best)


func _set_focus(f) -> void:
	_focus = f
	if f == null:
		_prompt.visible = false
		return
	_prompt.visible = true
	if f is Dictionary:
		_prompt.text = "E   " + str(f["name"])
		_prompt.at = Iso.lift(f["at_g"], 2.9 if f["kind"] == "bar" else 2.2)
	else:
		_prompt.text = "E   TALK"
		_prompt.at = Iso.lift(f.gpos, 2.3)
	_prompt.queue_redraw()


func interact(f) -> void:
	Audio.play("ui_click")
	if f is Dictionary:
		if f["kind"] == "bar":
			charon.say(Meta.next_line("charon", LayoutHub.CHARON_LINES))
		Game.hud.open_hub_menu(f["kind"])
	else:
		f.say(Meta.next_line(f.npc_id, f.lines))


## Leave for a shore at a depth (the ferry menu, or the bot).
func sail(depth: int, shore := "temple") -> void:
	Events.message.emit("THE FERRY PUSHES OFF", Color(0.55, 1.0, 0.8))
	Game.world.sail(depth, shore)


## "E  NAME" floating over whatever is in reach.
class HubPrompt extends Node2D:
	var text := ""
	var at := Vector2.ZERO
	var _font: Font

	func _ready() -> void:
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Cinzel.ttf")
		fv.variation_opentype = {"weight": 700}
		_font = fv

	func _draw() -> void:
		var size := 22
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var r := Rect2(at - Vector2(w * 0.5 + 22, 20), Vector2(w + 44, 34))
		draw_rect(r, Color(0.04, 0.03, 0.04, 0.85))
		draw_rect(r, Color(0.93, 0.74, 0.38, 0.9), false, 2.0)
		# the key in a small gold diamond
		var kc := r.position + Vector2(20, 17)
		draw_colored_polygon(PackedVector2Array([kc + Vector2(0, -12), kc + Vector2(12, 0), kc + Vector2(0, 12), kc + Vector2(-12, 0)]), Color(0.93, 0.74, 0.38))
		draw_string_outline(_font, r.position + Vector2(14, 25), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 2, Color(0, 0, 0))
		draw_string(_font, r.position + Vector2(14, 25), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.05, 0.03, 0.02))
		draw_string_outline(_font, r.position + Vector2(40, 25), text.substr(4), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0))
		draw_string(_font, r.position + Vector2(40, 25), text.substr(4), HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.98, 0.92, 0.8))
