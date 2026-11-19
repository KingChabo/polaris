class_name Settings
## Player options: look, controller, sound, graphics and key bindings, kept in three
## profiles in user://settings.cfg. `apply(main)` pushes them into the running game.

const PATH := "user://settings.cfg"
const PROFILES := 3
const QUALITY := ["Low", "Medium", "High", "Ultra"]

# action -> label, in the order the rebinding screen lists them
const ACTIONS := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["sprint", "Sprint"], ["jump", "Jump / climb"], ["crouch", "Crouch"], ["dodge", "Dodge"],
	["interact", "Use / talk"], ["fire", "Fire / strike"], ["aim", "Aim / block"], ["reload", "Reload"],
	["ammo_type", "Ammo type"], ["holster", "Holster"], ["next_weapon", "Next weapon"], ["prev_weapon", "Previous weapon"],
	["flashlight", "Flashlight / car lights"], ["winch", "Winch"], ["camera", "Car camera"],
	["inventory", "Inventory"], ["journal", "Journal"], ["quests", "Jobs"], ["map", "Map"],
	["quicksave", "Quick save"], ["quickload", "Quick load"],
]

const DEFAULTS := {
	"mouse_sens": 1.0,       # times the base sensitivity
	"invert_y": false,
	"pad_sens": 1.0,
	"deadzone": 0.15,
	"vibration": true,
	"fov": 74.0,
	"volume": 0.8,
	"music": 0.8,
	"quality": 2,
	"fullscreen": false,
	"vsync": true,
	"reduced_fx": false,
	"captions": false,        # subtitles for important sounds
	"difficulty": 1,          # 0 easy, 1 normal, 2 hard
	"season": "summer",       # the story valley in summer or in deep winter      # softer red flashes, less grain and colour fringes
	"binds": {},              # action -> [{"t": "key"/"mouse"/"pad", "c": code}]
}

const DIFFICULTY := ["Easy", "Normal", "Hard"]

static var profile := 0
static var _season_read := false


## How hard the world hits you, and how much it takes to put an enemy down.
static func dmg_taken() -> float:
	return [0.6, 1.0, 1.4][clampi(int(get_v("difficulty")), 0, 2)]


static func dmg_dealt() -> float:
	return [1.35, 1.0, 0.8][clampi(int(get_v("difficulty")), 0, 2)]
static var data := {}


static func get_v(key: String) -> Variant:
	return data.get(key, DEFAULTS[key])


static func set_v(key: String, v: Variant) -> void:
	data[key] = v


static func load_all() -> void:
	var cf := ConfigFile.new()
	data = DEFAULTS.duplicate(true)
	if cf.load(PATH) != OK:
		return
	profile = clampi(int(cf.get_value("main", "profile", 0)), 0, PROFILES - 1)
	var sec := "profile_%d" % profile
	for k in DEFAULTS:
		if cf.has_section_key(sec, k):
			data[k] = cf.get_value(sec, k)
	# the chosen season, once per run (Creator and the title menu change it themselves)
	if not _season_read:
		_season_read = true
		GameMode.season = "winter" if str(data.get("season", "summer")) == "winter" else "summer"


static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("main", "profile", profile)
	for k in DEFAULTS:
		cf.set_value("profile_%d" % profile, k, data.get(k, DEFAULTS[k]))
	cf.save(PATH)


static func switch_profile(p: int) -> void:
	save_all()
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("main", "profile", p)
	cf.save(PATH)
	load_all()


static func reset() -> void:
	data = DEFAULTS.duplicate(true)


## Re-applies everything: input map, look speed, sound, window and graphics.
static func apply(main: Node) -> void:
	_apply_binds()
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		if InputMap.has_action(a):
			InputMap.action_set_deadzone(a, float(get_v("deadzone")))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_v("volume")), 0.0001)))
	var w := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_v("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != w and not OS.has_feature("headless"):
		DisplayServer.window_set_mode(w)
	if OS.get_cmdline_user_args().is_empty():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_v("vsync")) else DisplayServer.VSYNC_DISABLED)
	if main == null:
		return
	if main.get("post"):
		main.post.look(GameMode.horror())
	var p: Player = main.get("player")
	if p:
		p.mouse_sens = 0.0022 * float(get_v("mouse_sens"))
		p.invert_y = bool(get_v("invert_y"))
		p.pad_look_speed = 2.6 * float(get_v("pad_sens"))
		p.deadzone = float(get_v("deadzone"))
		p.camera.fov = float(get_v("fov"))
		p.base_fov = float(get_v("fov"))
	_apply_quality(main, int(get_v("quality")))


static func _apply_quality(main: Node, q: int) -> void:
	var env: Environment = main.get("env")
	if env:
		env.ssao_enabled = q >= 2
		# light bouncing off snow and walls into the shadows, on the top setting
		env.ssil_enabled = q >= 3
		env.ssil_radius = 4.0
		env.ssil_intensity = 0.7
		env.ssr_enabled = q >= 3
		env.volumetric_fog_enabled = q >= 1
		env.glow_enabled = q >= 1
		env.sdfgi_enabled = false
	var vp := main.get_viewport()
	vp.scaling_3d_scale = [0.67, 0.8, 1.0, 1.0][q]
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q < 2 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.msaa_3d = Viewport.MSAA_2X if q >= 3 else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096][q], true)
	for n in main.get_children():
		if n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled:
			(n as DirectionalLight3D).directional_shadow_max_distance = [140.0, 220.0, 320.0, 420.0][q]
	# far detail (trees, lamps) fades sooner on the lower settings
	main.get_tree().root.mesh_lod_threshold = [3.0, 2.0, 1.0, 0.6][q]


# ---------------------------------------------------------------- bindings

static func _ev_to(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "key", "c": (ev as InputEventKey).physical_keycode}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "c": (ev as InputEventMouseButton).button_index}
	if ev is InputEventJoypadButton:
		return {"t": "pad", "c": (ev as InputEventJoypadButton).button_index}
	return {}


static func _ev_from(d: Dictionary) -> InputEvent:
	match str(d.get("t", "")):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d["c"])
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = int(d["c"])
			return e
		"pad":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d["c"])
			return e
	return null


static func _kind(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return "pad"
	return "kbm"


## Binds `ev` to `action`, replacing that action's keyboard/mouse (or pad) binding,
## and takes it away from any other action that had it.
static func bind(action: String, ev: InputEvent) -> void:
	var binds: Dictionary = (get_v("binds") as Dictionary).duplicate(true)
	var want := _ev_to(ev)
	for a in binds.keys():
		var lst: Array = binds[a]
		binds[a] = lst.filter(func(d: Dictionary) -> bool: return not (str(d["t"]) == str(want["t"]) and int(d["c"]) == int(want["c"])))
	# start from what the action has now, minus the old binding of the same kind
	var cur: Array = []
	for e in InputMap.action_get_events(action):
		if _kind(e) != _kind(ev) and not e is InputEventJoypadMotion:
			cur.append(_ev_to(e))
	cur.append(want)
	binds[action] = cur
	# others that lost the key keep what they have left
	for a2 in ACTIONS:
		var other: String = a2[0]
		if other == action or binds.has(other):
			continue
		for e in InputMap.action_get_events(other):
			if _ev_to(e) == want:
				var rest: Array = []
				for e2 in InputMap.action_get_events(other):
					if _ev_to(e2) != want and not e2 is InputEventJoypadMotion:
						rest.append(_ev_to(e2))
				binds[other] = rest
	set_v("binds", binds)
	_apply_binds()


static func _apply_binds() -> void:
	InputConfig.restore_defaults()
	var binds: Dictionary = get_v("binds")
	for a in binds:
		if not InputMap.has_action(str(a)):
			continue
		# keep stick/trigger axes, swap everything else for what was chosen
		for e in InputMap.action_get_events(str(a)):
			if not e is InputEventJoypadMotion:
				InputMap.action_erase_event(str(a), e)
		for d in binds[a]:
			var ev := _ev_from(d)
			if ev:
				InputMap.action_add_event(str(a), ev)


## "W / Up" style text for the keys of an action.
static func keys_of(action: String, pad := false) -> String:
	var out: Array[String] = []
	for e in InputMap.action_get_events(action):
		if pad != (_kind(e) == "pad"):
			continue
		out.append(event_name(e))
	return " / ".join(out) if not out.is_empty() else "—"


static func event_name(e: InputEvent) -> String:
	if e is InputEventKey:
		return OS.get_keycode_string((e as InputEventKey).physical_keycode)
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		return "Mouse %d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
			JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
			JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}
		return str(names.get((e as InputEventJoypadButton).button_index, "Pad %d" % (e as InputEventJoypadButton).button_index))
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		if m.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		if m.axis == JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		return "Left stick"
	return "?"
