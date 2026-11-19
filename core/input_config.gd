extends Node
## Central place for all input actions, so every action can be rebound later.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"inventory": [KEY_TAB, KEY_I],
	"journal": [KEY_J],
	"quests": [KEY_L],
	"map": [KEY_M],
	"quicksave": [KEY_F5],
	"quickload": [KEY_F9],
	"reload": [KEY_R],
	"dodge": [KEY_ALT],
	"holster": [KEY_H],
	"ammo_type": [KEY_B],
	"winch": [KEY_G],
	"camera": [KEY_V],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],
	"weapon_5": [KEY_5],
	"weapon_6": [KEY_6],
}
const MOUSE := {
	"fire": MOUSE_BUTTON_LEFT,
	"aim": MOUSE_BUTTON_RIGHT,
	"next_weapon": MOUSE_BUTTON_WHEEL_DOWN,
	"prev_weapon": MOUSE_BUTTON_WHEEL_UP,
}
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"interact": JOY_BUTTON_X,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"flashlight": JOY_BUTTON_DPAD_UP,
	"pause": JOY_BUTTON_START,
	"inventory": JOY_BUTTON_Y,
	"next_weapon": JOY_BUTTON_RIGHT_SHOULDER,
	"prev_weapon": JOY_BUTTON_LEFT_SHOULDER,
	"reload": JOY_BUTTON_DPAD_RIGHT,
	"dodge": JOY_BUTTON_RIGHT_STICK,
	"holster": JOY_BUTTON_DPAD_DOWN,
	"ammo_type": JOY_BUTTON_DPAD_LEFT,
	"map": JOY_BUTTON_BACK,
}
# action: [axis, direction]
const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_add_event(action, ev)


func _enter_tree() -> void:
	restore_defaults()
	Settings.load_all()
	Settings.apply(null)


## Puts every action back to the keys above (Settings then lays the player's own on top).
func restore_defaults() -> void:
	for action in InputMap.get_actions():
		if not str(action).begins_with("ui_"):
			InputMap.erase_action(action)
	for action in KEYS:
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			_add(action, ev)
	for action in MOUSE:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE[action]
		_add(action, ev)
	for action in PAD_BUTTONS:
		var ev := InputEventJoypadButton.new()
		ev.button_index = PAD_BUTTONS[action]
		_add(action, ev)
	for action in PAD_AXES:
		var ev := InputEventJoypadMotion.new()
		ev.axis = PAD_AXES[action][0]
		ev.axis_value = PAD_AXES[action][1]
		_add(action, ev)
