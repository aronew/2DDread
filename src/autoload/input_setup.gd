extends Node
## Builds the input map in code so bindings live in one readable place.
## Keyboard/mouse twin-stick + gamepad layout. Remapping UI can later
## read/write InputMap directly.

const DEADZONE := 0.2

func _enter_tree() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)

	_mouse("fire", MOUSE_BUTTON_LEFT)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key("alt_fire", [KEY_F, KEY_G])          # Firebomb
	_axis("alt_fire", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_key("dash", [KEY_SPACE, KEY_SHIFT])
	_joy("dash", [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER])
	_key("ability_1", [KEY_Q])
	_joy("ability_1", [JOY_BUTTON_X])
	_key("ability_2", [KEY_E])
	_joy("ability_2", [JOY_BUTTON_Y])
	_mouse("melee", MOUSE_BUTTON_RIGHT)      # Hellfire Saber
	_key("melee", [KEY_V])
	_joy("melee", [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER])
	_key("interact", [KEY_E])                 # hub only (E is the seeker swarm in a fight)
	_joy("interact", [JOY_BUTTON_Y])
	_key("reload", [KEY_R])
	_joy("reload", [JOY_BUTTON_RIGHT_STICK])
	_key("inventory", [KEY_TAB, KEY_I])
	_joy("inventory", [JOY_BUTTON_BACK])
	_key("pause", [KEY_ESCAPE])
	_joy("pause", [JOY_BUTTON_START])
	_key("weapon_1", [KEY_1])
	_key("weapon_2", [KEY_2])
	_key("weapon_3", [KEY_3])
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_joy("weapon_next", [JOY_BUTTON_DPAD_RIGHT])
	_joy("weapon_prev", [JOY_BUTTON_DPAD_LEFT])
	_key("debug_toggle", [KEY_F3])
	_key("graphics_cycle", [KEY_F4])


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)


func _key(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _joy(action: String, buttons: Array) -> void:
	_ensure(action)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)


func _axis(action: String, axis: int, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
