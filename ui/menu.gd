class_name GameMenu
extends CanvasLayer
## Title screen, pause menu, settings and key rebinding. Works with mouse, keyboard
## and controller (Godot's focus moves with the arrow keys / d-pad).

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.93, 0.96, 1.0, 0.55)
const GOLD := Color(1.0, 0.8, 0.35)
const ICE := Color(0.55, 0.85, 1.0)

var main: Node
var page := ""                # "" closed, "title", "mode", "pause", "settings", "binds"
var _back := ""               # where settings return to
var _root: Control
var _bg: ColorRect
var _box: Control
var _theme: Theme
var _wait_action := ""        # rebinding: waiting for a key for this action
var _wait_pad := false
var _wait_btn: Button
var _toast := ""
var _toast_t := 0.0
var _toast_lbl: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	add_child(_root)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_bg)
	_toast_lbl = Label.new()
	_toast_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_lbl.position = Vector2(-300, -70)
	_toast_lbl.size = Vector2(600, 30)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.add_theme_color_override("font_color", GOLD)
	_root.add_child(_toast_lbl)
	visible = false


func is_open() -> bool:
	return page != ""


func _process(delta: float) -> void:
	_toast_t = maxf(_toast_t - delta, 0.0)
	_toast_lbl.text = _toast if _toast_t > 0.0 else ""


func _say(t: String) -> void:
	_toast = t
	_toast_t = 2.5


# ---------------------------------------------------------------- theme

func _flat(bg: Color, border := Color(0, 0, 0, 0), bw := 0, r := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("normal", "Button", _flat(Color(0.03, 0.05, 0.09, 0.72), Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", _flat(Color(0.12, 0.10, 0.06, 0.85), GOLD, 1))
	t.set_stylebox("focus", "Button", _flat(Color(0.12, 0.10, 0.06, 0.85), GOLD, 2))
	t.set_stylebox("pressed", "Button", _flat(Color(0.25, 0.19, 0.08, 0.9), GOLD, 2))
	t.set_stylebox("disabled", "Button", _flat(Color(0.03, 0.05, 0.09, 0.4)))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(INK.r, INK.g, INK.b, 0.3))
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", _flat(Color(0.02, 0.035, 0.065, 0.9), Color(1, 1, 1, 0.1), 1, 6))
	var grab := _flat(GOLD, Color(0, 0, 0, 0), 0, 8)
	t.set_stylebox("slider", "HSlider", _flat(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	for st in ["normal", "hover", "focus", "pressed"]:
		t.set_stylebox(st, "OptionButton", t.get_stylebox(st, "Button"))
		t.set_stylebox(st, "CheckButton", _flat(Color(0, 0, 0, 0), GOLD if st == "focus" else Color(0, 0, 0, 0), 1))
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", GOLD)
	t.set_color("font_focus_color", "CheckButton", GOLD)
	t.set_stylebox("panel", "PopupMenu", _flat(Color(0.03, 0.05, 0.09, 0.97), GOLD, 1))
	return t


# ---------------------------------------------------------------- pages

func _clear() -> void:
	if _box:
		_box.queue_free()
		_box = null


func _open(p: String) -> void:
	page = p
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if main and main.get("player"):
		main.player.ui_open = true
	if main and main.get("hud"):
		main.hud.visible = false
	_clear()
	match p:
		"title":
			_build_title()
		"mode":
			_build_mode()
		"pause":
			_build_pause()
		"settings":
			_build_settings()
		"binds":
			_build_binds()
		"saves":
			_build_saves()


func close() -> void:
	page = ""
	visible = false
	_clear()
	get_tree().paused = false
	if main and main.get("player"):
		main.player.ui_open = false
	if main and main.get("hud"):
		main.hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_title() -> void:
	_open("title")


func open_pause() -> void:
	if page == "":
		_open("pause")


func _title_text(parent: Control, big: String, small: String) -> void:
	var t := Label.new()
	t.text = big
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", INK)
	t.add_theme_color_override("font_shadow_color", Color(0.9, 0.08, 0.05, 0.5) if GameMode.horror() else Color(0.2, 0.6, 1.0, 0.45))
	t.add_theme_constant_override("shadow_offset_y", 0)
	t.add_theme_constant_override("shadow_outline_size", 18)
	parent.add_child(t)
	var s := Label.new()
	s.text = small
	s.add_theme_font_size_override("font_size", 16)
	s.add_theme_color_override("font_color", ICE)
	parent.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	parent.add_child(gap)


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _column(bg_alpha: float) -> VBoxContainer:
	_bg.color = Color(0.01, 0.02, 0.04, bg_alpha)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 110)
	m.add_theme_constant_override("margin_top", 120)
	_root.add_child(m)
	_box = m
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


## The newest save of either mode: [path, mode], or [] if there is none.
func _latest_save() -> Array:
	var best: Array = []
	var bt := -1
	for m in GameMode.MODES:
		var base := GameMode.save_path(m)
		for p in [base, base.replace(".json", "_auto.json"), base.replace(".json", "_2.json"), base.replace(".json", "_3.json")]:
			if FileAccess.file_exists(p) and int(FileAccess.get_modified_time(p)) > bt:
				bt = int(FileAccess.get_modified_time(p))
				best = [p, m]
	return best


func _build_title() -> void:
	var v := _column(0.35)
	_title_text(v, "POLARIS", "THE FOG HAS COME  ·  DO NOT LOOK AWAY" if GameMode.horror() else ("THE SENKE  ·  A SHORT SUMMER, A LONG SHADOW" if GameMode.summer() else "THE SENKE  ·  A VALLEY THAT NEVER SEES THE SUN"))
	var last := _latest_save()
	var cont := _button(v, "Continue" + ("" if last.is_empty() else ("  ·  Horror" if last[1] == "horror" else "  ·  Story")), _on_continue, not last.is_empty())
	var ng := _button(v, "Story mode   ·   new game", func() -> void: _start_mode("normal"))
	var hb := _button(v, "HORROR MODE   ·   new game", func() -> void: _start_mode("horror"))
	_horror_style(hb)
	var hs := Label.new()
	hs.text = "      The same valley, gone dark. Everyone is hidden. Something follows you."
	hs.add_theme_color_override("font_color", Color(0.95, 0.42, 0.36, 0.85))
	hs.add_theme_font_size_override("font_size", 13)
	v.add_child(hs)
	var cb := _button(v, "CREATOR MODE   ·   build, fly and test", func() -> void: _start_mode("creator"))
	cb.add_theme_color_override("font_color", Color(0.45, 0.9, 0.6))
	_button(v, "Compare the two modes", func() -> void: _open("mode"))
	var other_season := "winter" if GameMode.season == "summer" else "summer"
	_button(v, "Season: %s   ·   switch to %s" % [GameMode.season.capitalize(), other_season], func() -> void:
		GameMode.season = other_season
		Settings.set_v("season", other_season)
		Settings.save_all()
		GameMode.switch(get_tree(), "normal" if GameMode.horror() else GameMode.mode, ""))
	_button(v, "Settings", func() -> void: _back = "title"; _open("settings"))
	_button(v, "Quit", func() -> void: get_tree().quit())
	(cont if not last.is_empty() else ng).grab_focus.call_deferred()
	var hint := Label.new()
	hint.text = "\n\nMouse, keyboard or controller.  Esc pauses the game."
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 13)
	v.add_child(hint)


## Two big cards: the story as it was, or the same valley as a horror game.
func _build_mode() -> void:
	_bg.color = Color(0.01, 0.015, 0.03, 0.82)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	_box = c
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	c.add_child(v)
	var t := Label.new()
	t.text = "CHOOSE YOUR NIGHT"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	v.add_child(h)
	var a := _mode_card(h, "normal", "STORY",
		"The Senke under the aurora.\n\nRaiders in the woods, a machine that digs by itself, soldiers behind a gate, and something white on the lake.\n\nFind your sister. Three bosses, three endings, a whole valley to explore.",
		Color(0.35, 0.85, 1.0))
	_mode_card(h, "horror", "HORROR",
		"The same valley, gone dark.\n\nThe lights are failing and everyone has hidden. Something tall stands in the fog, and it only moves when you look away.\n\nFind the hidden people, solve what they left behind, keep your light on it. Headphones recommended.",
		Color(0.95, 0.15, 0.1))
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(200, 42)
	back.pressed.connect(func() -> void: _open("title"))
	v.add_child(back)
	a.grab_focus.call_deferred()


func _mode_card(parent: Control, m: String, title: String, text: String, accent: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(440, 420)
	var normal := _flat(Color(0.02, 0.03, 0.06, 0.88), Color(accent.r, accent.g, accent.b, 0.35), 2, 10)
	var hover := _flat(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.95), accent, 3, 10)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func() -> void: _start_mode(m))
	parent.add_child(b)
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 30
	inner.offset_right = -30
	inner.offset_top = 26
	inner.offset_bottom = -20
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 14)
	b.add_child(inner)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 40)
	tl.add_theme_color_override("font_color", accent)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(tl)
	var line := ColorRect.new()
	line.color = Color(accent.r, accent.g, accent.b, 0.6)
	line.custom_minimum_size = Vector2(90, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(line)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.85))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(body)
	var go := Label.new()
	go.text = "START  ›"
	go.add_theme_font_size_override("font_size", 15)
	go.add_theme_color_override("font_color", accent)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(go)
	return b


## The horror entry is red and pulses slowly, so nobody can miss it.
func _horror_style(b: Button) -> void:
	var red := Color(0.95, 0.16, 0.1)
	b.add_theme_stylebox_override("normal", _flat(Color(0.16, 0.02, 0.02, 0.9), Color(red.r, red.g, red.b, 0.7), 2, 4))
	var hot := _flat(Color(0.32, 0.03, 0.02, 0.96), red, 3, 4)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", hot)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(1.0, 0.8, 0.76))
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "modulate", Color(1.25, 1.0, 1.0), 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "modulate", Color(0.85, 0.85, 0.85), 1.1).set_trans(Tween.TRANS_SINE)


func _start_mode(m: String) -> void:
	close()
	if m == GameMode.mode and m != "creator":
		main.start_new_game()
	else:
		GameMode.switch(get_tree(), m, "new")


func _build_pause() -> void:
	var v := _column(0.6)
	_title_text(v, "PAUSED", _chapter_line())
	var r := _button(v, "Resume", close)
	_button(v, "Save / load", func() -> void: _open("saves"))
	_button(v, "Map", func() -> void: close(); main.map.open())
	_button(v, "Settings", func() -> void: _back = "pause"; _open("settings"))
	var other := "normal" if GameMode.horror() else "horror"
	var sw := _button(v, "Switch to STORY mode" if GameMode.horror() else "Switch to HORROR mode", func() -> void:
		SaveGame.save(main)
		GameMode.switch(get_tree(), other, "load" if FileAccess.file_exists(GameMode.save_path(other)) else "new"))
	if not GameMode.horror():
		_horror_style(sw)
	_button(v, "Main menu", func() -> void: get_tree().paused = false; get_tree().reload_current_scene())
	_button(v, "Quit game", func() -> void: get_tree().quit())
	r.grab_focus.call_deferred()


func _chapter_line() -> String:
	if main == null or not main.get("quests"):
		return ""
	var id: String = main.quests.main_quest()
	if id == "":
		return "THE STORY IS OVER  ·  THE VALLEY IS STILL YOURS" if main.quests.status("h_7" if GameMode.horror() else "main_5") == "done" else ""
	var n := int(id.trim_prefix("main_").trim_prefix("h_"))
	return "CHAPTER %d  ·  %s" % [n, str(Quests.DEFS[id]["title"]).to_upper()]


func _on_continue() -> void:
	var last := _latest_save()
	close()
	if not last.is_empty() and str(last[1]) != GameMode.mode:
		GameMode.switch(get_tree(), str(last[1]), "load")
		return
	var ok := false
	if not last.is_empty():
		for n in [1, 2, 3, 0]:
			if SaveGame.slot_path(n) == str(last[0]):
				ok = SaveGame.load_slot(main, n)
	if not ok and not SaveGame.load_game(main):
		main.start_new_game()
	else:
		main.ensure_story()


## Three slots and the autosave of the mode being played.
func _build_saves() -> void:
	var v := _column(0.6)
	_title_text(v, "SAVE / LOAD", "F5 saves to the slot you used last, F9 loads the newest")
	for n in range(1, SaveGame.SLOTS + 1):
		var nn := n
		_button(v, "Save:  " + SaveGame.describe(n), func() -> void:
			_say("Saved to slot %d." % nn if SaveGame.save_slot(main, nn) else "Saving failed.")
			_open("saves"))
	for n in [1, 2, 3, 0]:
		var nn: int = n
		_button(v, "Load:  " + SaveGame.describe(nn), func() -> void:
			close()
			main.player.message.emit("Game loaded." if SaveGame.load_slot(main, nn) else "That save could not be read."),
			FileAccess.file_exists(SaveGame.slot_path(nn)))
	var b := _button(v, "Back", func() -> void: _open("pause"))
	b.grab_focus.call_deferred()


func _on_load() -> void:
	close()
	main.player.message.emit("Game loaded." if SaveGame.load_game(main) else "No saved game.")


# ---------------------------------------------------------------- settings

func _panel(title: String) -> VBoxContainer:
	_bg.color = Color(0.01, 0.02, 0.04, 0.8)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	_box = c
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(860, 720)
	c.add_child(pc)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	pc.add_child(outer)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", GOLD)
	outer.add_child(t)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	outer.set_meta("rows", v)
	return outer


func _section(v: Control, text: String) -> void:
	var l := Label.new()
	l.text = "\n" + text.to_upper()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", ICE)
	v.add_child(l)


func _row(v: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	v.add_child(h)
	return h


func _slider(v: Control, text: String, key: String, lo: float, hi: float, step: float, fmt := "%.2f") -> HSlider:
	var h := _row(v, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(320, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var val := Label.new()
	val.text = fmt % s.value
	val.add_theme_color_override("font_color", GOLD)
	h.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = fmt % x
		Settings.set_v(key, x)
		Settings.apply(main))
	return s


func _check(v: Control, text: String, key: String) -> CheckButton:
	var h := _row(v, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_v(key, on)
		Settings.apply(main))
	h.add_child(c)
	return c


func _choice(v: Control, text: String, items: Array, current: int, cb: Callable) -> OptionButton:
	var h := _row(v, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.selected = current
	o.custom_minimum_size = Vector2(320, 40)
	o.item_selected.connect(cb)
	h.add_child(o)
	return o


func _build_settings() -> void:
	var outer := _panel("SETTINGS")
	var v: VBoxContainer = outer.get_meta("rows")
	var names: Array = []
	for i in Settings.PROFILES:
		names.append("Profile %d" % (i + 1))
	var first := _choice(v, "Profile", names, Settings.profile, func(i: int) -> void:
		Settings.switch_profile(i)
		Settings.apply(main)
		_open("settings")
		_say("Profile %d loaded." % (i + 1)))
	_section(v, "Mouse and keyboard")
	_slider(v, "Mouse sensitivity", "mouse_sens", 0.2, 3.0, 0.05)
	_check(v, "Invert look up / down", "invert_y")
	_check(v, "Reduced effects (less red flash, grain, colour fringes)", "reduced_fx")
	var kb := _row(v, "Keys and buttons")
	var bb := Button.new()
	bb.text = "Rebind…"
	bb.pressed.connect(func() -> void: _open("binds"))
	kb.add_child(bb)
	_section(v, "Controller")
	_slider(v, "Stick look speed", "pad_sens", 0.3, 3.0, 0.05)
	_slider(v, "Stick dead zone", "deadzone", 0.02, 0.5, 0.01)
	_check(v, "Vibration", "vibration")
	var pads := Input.get_connected_joypads()
	var pl := _row(v, "Connected")
	var pn := Label.new()
	pn.text = Input.get_joy_name(pads[0]) if not pads.is_empty() else "No controller found"
	pn.add_theme_color_override("font_color", DIM)
	pl.add_child(pn)
	_section(v, "Game")
	_choice(v, "Difficulty", Settings.DIFFICULTY, int(Settings.get_v("difficulty")), func(i: int) -> void:
		Settings.set_v("difficulty", i)
		Settings.apply(main))
	_section(v, "Display")
	_slider(v, "Field of view", "fov", 60.0, 100.0, 1.0, "%.0f°")
	_choice(v, "Graphics quality", Settings.QUALITY, int(Settings.get_v("quality")), func(i: int) -> void:
		Settings.set_v("quality", i)
		Settings.apply(main))
	_check(v, "Fullscreen", "fullscreen")
	_check(v, "V-sync", "vsync")
	_section(v, "Sound")
	_check(v, "Sound subtitles ([growling, behind you] …)", "captions")
	_slider(v, "Volume", "volume", 0.0, 1.0, 0.01)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	outer.add_child(bottom)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_settings_back)
	bottom.add_child(back)
	var rs := Button.new()
	rs.text = "Reset this profile"
	rs.pressed.connect(func() -> void:
		Settings.reset()
		Settings.apply(main)
		_open("settings")
		_say("Defaults restored."))
	bottom.add_child(rs)
	first.grab_focus.call_deferred()


func _settings_back() -> void:
	Settings.save_all()
	_open(_back if _back != "" else "pause")


func _build_binds() -> void:
	var outer := _panel("KEYS AND BUTTONS")
	var v: VBoxContainer = outer.get_meta("rows")
	var head := _row(v, "Action")
	for t in ["Keyboard / mouse", "Controller"]:
		var l := Label.new()
		l.text = t
		l.custom_minimum_size = Vector2(230, 0)
		l.add_theme_color_override("font_color", ICE)
		head.add_child(l)
	var first: Button = null
	for a in Settings.ACTIONS:
		var action: String = a[0]
		var h := _row(v, str(a[1]))
		for pad in [false, true]:
			var b := Button.new()
			b.text = Settings.keys_of(action, pad)
			b.custom_minimum_size = Vector2(230, 38)
			b.pressed.connect(func() -> void: _start_wait(action, pad, b))
			h.add_child(b)
			if first == null:
				first = b
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	outer.add_child(bottom)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: Settings.save_all(); _open("settings"))
	bottom.add_child(back)
	var rs := Button.new()
	rs.text = "Default keys"
	rs.pressed.connect(func() -> void:
		Settings.set_v("binds", {})
		Settings.apply(main)
		_open("binds")
		_say("Default keys restored."))
	bottom.add_child(rs)
	var hint := Label.new()
	hint.text = "Click a slot, then press the new key or button.  Esc cancels."
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 13)
	bottom.add_child(hint)
	if first:
		first.grab_focus.call_deferred()


func _start_wait(action: String, pad: bool, b: Button) -> void:
	_wait_action = action
	_wait_pad = pad
	_wait_btn = b
	b.text = "press a button…" if pad else "press a key…"


func _input(event: InputEvent) -> void:
	if page == "":
		return
	if _wait_action != "":
		var ok := false
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
				_wait_action = ""
				_open("binds")
				get_viewport().set_input_as_handled()
				return
			ok = not _wait_pad
		elif event is InputEventMouseButton and event.pressed:
			ok = not _wait_pad
		elif event is InputEventJoypadButton and event.pressed:
			ok = _wait_pad
		if ok:
			Settings.bind(_wait_action, event)
			_say("%s  →  %s" % [_wait_action.replace("_", " "), Settings.event_name(event)])
			_wait_action = ""
			_open("binds")
		get_viewport().set_input_as_handled()
		return
	var back: bool = event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	if back:
		get_viewport().set_input_as_handled()
		match page:
			"pause":
				close()
			"settings":
				_settings_back()
			"binds":
				Settings.save_all()
				_open("settings")
			"mode":
				_open("title")
