class_name KeypadScreen
extends CanvasLayer
## A number lock up close: type the code with the number keys or click the buttons.
## Enter / OK tries it, Backspace / C clears, Esc leaves.

signal entered(code: String)

const INK := Color(0.93, 0.96, 1.0)
const GOLD := Color(1.0, 0.8, 0.35)

var player: Player
var digits := 4
var _code := ""
var _shown: Label
var _panel: PanelContainer
var _msg: Label


func _ready() -> void:
	layer = 8
	visible = false
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.11, 0.97)
	sb.border_color = Color(0.4, 0.42, 0.45)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	sb.shadow_size = 24
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_panel.add_theme_stylebox_override("panel", sb)
	c.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var t := Label.new()
	t.text = "SPIELWAREN LINDQVIST  ·  BACK DOOR"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.6))
	v.add_child(t)
	var screen := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.05, 0.12, 0.08)
	ss.set_corner_radius_all(4)
	ss.content_margin_left = 14
	ss.content_margin_right = 14
	ss.content_margin_top = 6
	ss.content_margin_bottom = 6
	screen.add_theme_stylebox_override("panel", ss)
	v.add_child(screen)
	_shown = Label.new()
	_shown.add_theme_font_size_override("font_size", 44)
	_shown.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
	_shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_shown)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(84, 64)
		b.add_theme_font_size_override("font_size", 26)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.16, 0.17, 0.19)
		bs.border_color = Color(0, 0, 0, 0.8)
		bs.border_width_bottom = 4
		bs.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", bs)
		var bh := bs.duplicate() as StyleBoxFlat
		bh.bg_color = Color(0.25, 0.22, 0.14)
		bh.border_color = GOLD
		b.add_theme_stylebox_override("hover", bh)
		b.add_theme_stylebox_override("focus", bh)
		b.add_theme_color_override("font_color", GOLD if label in ["C", "OK"] else INK)
		b.pressed.connect(_press.bind(label))
		g.add_child(b)
	_msg = Label.new()
	_msg.text = "[0-9] type   [Enter] try   [Esc] leave"
	_msg.add_theme_font_size_override("font_size", 13)
	_msg.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.55))
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_msg)
	_show()


func open() -> void:
	if player.ui_open:
		return
	_code = ""
	_show()
	visible = true
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show() -> void:
	var s := ""
	for i in digits:
		s += (_code[i] if i < _code.length() else "_") + (" " if i < digits - 1 else "")
	_shown.text = s


func _press(label: String) -> void:
	match label:
		"C":
			_code = ""
		"OK":
			Sfx.play(player.get_parent(), "beep", player.global_position, -6.0, 0.8)
			entered.emit(_code)
			_code = ""
		_:
			if _code.length() < digits:
				_code += label
				Sfx.play(player.get_parent(), "beep", player.global_position, -10.0, 1.0)
	_show()


## Flashes the screen red or green after a try.
func result(ok: bool) -> void:
	_shown.text = "OPEN" if ok else "- - - -"
	_shown.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6) if ok else Color(1.0, 0.25, 0.2))
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		_shown.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
		if ok:
			close()
		else:
			_show())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_0 and k <= KEY_9:
			_press(str(k - KEY_0))
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			_press(str(k - KEY_KP_0))
		elif k == KEY_BACKSPACE:
			_press("C")
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_press("OK")
		elif k == KEY_ESCAPE:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
