class_name ReadScreen
extends CanvasLayer
## Shows a document on a sheet of paper, and (with J) the journal:
## every document found so far and every place discovered.

var player: Player
var places: Node
var found: Array[String] = []      # note ids in the order they were found
var _notes := {}                   # id -> {title, text}
var _mode := ""                    # "" closed, "note", "journal"
var _cur := ""
var _sel := 0
var _c: Control
var _font: Font


class Painter extends Control:
	var scr: ReadScreen
	func _draw() -> void:
		scr._paint()


func _ready() -> void:
	layer = 6
	_font = ThemeDB.fallback_font
	var c := Painter.new()
	c.scr = self
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_c = c
	visible = false


func register(n: Note) -> void:
	_notes[n.id] = {"title": n.title, "text": n.text}


func is_open() -> bool:
	return _mode != ""


func show_note(n: Note) -> void:
	register(n)
	if not n.id in found:
		found.append(n.id)
	_cur = n.id
	_open("note")


func open_journal() -> void:
	_sel = clampi(_sel, 0, maxi(found.size() - 1, 0))
	_open("journal")


func _open(mode: String) -> void:
	_mode = mode
	visible = true
	player.ui_open = true
	_c.queue_redraw()


func close() -> void:
	_mode = ""
	visible = false
	player.ui_open = false


func _input(event: InputEvent) -> void:
	if _mode == "":
		if event.is_action_pressed("journal") and player and not player.ui_open:
			open_journal()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("journal") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()
	elif _mode == "journal" and not found.is_empty():
		var step := 0
		if event.is_action_pressed("move_back") or event.is_action_pressed("next_weapon"):
			step = 1
		elif event.is_action_pressed("move_forward") or event.is_action_pressed("prev_weapon"):
			step = -1
		if step != 0:
			_sel = clampi(_sel + step, 0, found.size() - 1)
			_c.queue_redraw()
			get_viewport().set_input_as_handled()


## A sheet of old paper: yellowed towards the edges, flecked, with a ring where a cup
## stood on it, tilted a little as if it had just been put down.
func _sheet(r: Rect2, title: String, text: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)
	var tilt := rng.randf_range(-0.012, 0.012)
	var c := r.get_center()
	_c.draw_set_transform(c, tilt, Vector2.ONE)
	var rr := Rect2(r.position - c, r.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.88, 0.84, 0.73)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(4, 8)
	_c.draw_style_box(sb, rr)
	# yellowed edges
	var edge := Color(0.62, 0.5, 0.3, 0.0)
	var age := Color(0.62, 0.5, 0.3, 0.35)
	var e := 46.0
	_quad(Rect2(rr.position, Vector2(rr.size.x, e)), age, age, edge, edge)
	_quad(Rect2(Vector2(rr.position.x, rr.end.y - e), Vector2(rr.size.x, e)), edge, edge, age, age)
	_quad(Rect2(rr.position, Vector2(e, rr.size.y)), age, edge, edge, age)
	_quad(Rect2(Vector2(rr.end.x - e, rr.position.y), Vector2(e, rr.size.y)), edge, age, age, edge)
	# flecks and a cup ring
	for i in 140:
		var p := rr.position + Vector2(rng.randf() * rr.size.x, rng.randf() * rr.size.y)
		_c.draw_circle(p, rng.randf_range(0.4, 1.5), Color(0.35, 0.27, 0.16, rng.randf_range(0.05, 0.22)))
	var ring := rr.position + Vector2(rng.randf_range(0.6, 0.85) * rr.size.x, rng.randf_range(0.62, 0.86) * rr.size.y)
	var rad := rng.randf_range(38.0, 52.0)
	_c.draw_arc(ring, rad, 0.3, TAU - 0.5, 48, Color(0.5, 0.33, 0.15, 0.16), 5.0, true)
	_c.draw_arc(ring, rad - 3.0, 0.0, TAU - 1.2, 48, Color(0.5, 0.33, 0.15, 0.1), 2.0, true)
	# faint ruled lines and a folded corner
	var y := rr.position.y + 96.0
	while y < rr.end.y - 30.0:
		_c.draw_line(Vector2(rr.position.x + 36, y), Vector2(rr.end.x - 36, y), Color(0.3, 0.35, 0.5, 0.10), 1.0)
		y += 27.0
	_c.draw_line(Vector2(rr.position.x + 30, rr.position.y + 20), Vector2(rr.position.x + 30, rr.end.y - 20), Color(0.7, 0.2, 0.18, 0.18), 1.0)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(rr.end.x - 34, rr.position.y), rr.position + Vector2(rr.size.x, 34), rr.position + Vector2(rr.size.x - 34, 34)]), Color(0.7, 0.65, 0.54))
	_c.draw_line(Vector2(rr.end.x - 34, rr.position.y), rr.position + Vector2(rr.size.x - 34, 34), Color(0.4, 0.33, 0.22, 0.4), 1.0)
	var ink := Color(0.11, 0.1, 0.15)
	if GameMode.horror():
		ink = Color(0.2, 0.06, 0.05)
	_c.draw_string(_font, rr.position + Vector2(44, 58), title, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 90, 24, ink)
	_c.draw_line(rr.position + Vector2(44, 72), rr.position + Vector2(rr.size.x - 40, 72), Color(0.45, 0.1, 0.08, 0.7), 2.0)
	_c.draw_multiline_string(_font, rr.position + Vector2(44, 112), text, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 86, 17, 30, Color(ink.r, ink.g, ink.b, 0.92))
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A rectangle with a colour at each corner (top-left, top-right, bottom-right, bottom-left).
func _quad(r: Rect2, a: Color, b: Color, cc: Color, d: Color) -> void:
	_c.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]), PackedColorArray([a, b, cc, d]))


## The key hints along the bottom, drawn as key caps.
func _hints(y: float, width: float, list: Array) -> void:
	var total := 0.0
	for h in list:
		total += maxf(24.0, _font.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0) + _font.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0
	var x := (width - total) * 0.5
	for h in list:
		var w := maxf(24.0, _font.get_string_size(str(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.88, 0.92, 1.0, 0.92)
		sb.set_corner_radius_all(4)
		sb.border_width_bottom = 4
		sb.border_color = Color(0.45, 0.5, 0.6, 0.92)
		_c.draw_style_box(sb, Rect2(x, y - 17, w, 24))
		_c.draw_string(_font, Vector2(x, y - 1), str(h[0]), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.04, 0.06, 0.1))
		_c.draw_string(_font, Vector2(x + w + 8, y), str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.93, 0.96, 1.0, 0.65))
		x += w + _font.get_string_size(str(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36.0


func _paint() -> void:
	if _mode == "":
		return
	var size := _c.size
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.72))
	var hint := Color(0.93, 0.96, 1.0, 0.7)
	if _mode == "note":
		var d: Dictionary = _notes.get(_cur, {})
		var w := minf(680.0, size.x - 80.0)
		var h := minf(760.0, size.y - 110.0)
		_sheet(Rect2((size.x - w) * 0.5, (size.y - h) * 0.5 - 12.0, w, h), str(d.get("title", "")), GameMode.season_text(str(d.get("text", ""))))
		_hints(size.y - 24, size.x, [["E", "put it away"], ["J", "journal"]])
		return
	# --- journal: list on the left, the chosen sheet on the right
	var x0 := maxf((size.x - 1240.0) * 0.5, 30.0)
	var top := maxf((size.y - 780.0) * 0.5, 30.0)
	_c.draw_string(_font, Vector2(x0, top + 26), "JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.8, 0.35))
	_c.draw_string(_font, Vector2(x0, top + 52), "%d documents" % found.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, hint)
	var y := top + 86.0
	var first := clampi(_sel - 9, 0, maxi(found.size() - 13, 0))
	for q in range(first, mini(first + 13, found.size())):
		var d: Dictionary = _notes.get(found[q], {})
		if q == _sel:
			_c.draw_rect(Rect2(x0 - 8, y - 20, 380, 30), Color(1.0, 0.8, 0.35, 0.16))
			_c.draw_rect(Rect2(x0 - 8, y - 20, 3, 30), Color(1.0, 0.8, 0.35))
		_c.draw_string(_font, Vector2(x0 + 4, y), str(d.get("title", found[q])), HORIZONTAL_ALIGNMENT_LEFT, 360, 16, Color(0.93, 0.96, 1.0, 1.0 if q == _sel else 0.65))
		y += 32.0
	if found.is_empty():
		_c.draw_string(_font, Vector2(x0 + 4, y), "Nothing yet. Letters, logs and orders you read end up here.", HORIZONTAL_ALIGNMENT_LEFT, 380, 15, hint)
	# places
	y = top + 86.0 + 13 * 32.0 + 26.0
	_c.draw_string(_font, Vector2(x0, y), "PLACES", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.8, 0.35))
	y += 26.0
	if places:
		var names: Array = places.found_names()
		var line := ", ".join(names) if not names.is_empty() else "None discovered."
		_c.draw_multiline_string(_font, Vector2(x0 + 4, y), line + "\n%d of %d" % [names.size(), places.spots.size()], HORIZONTAL_ALIGNMENT_LEFT, 380, 14, 8, hint)
	if not found.is_empty():
		var d: Dictionary = _notes.get(found[_sel], {})
		_sheet(Rect2(x0 + 420, top, minf(680.0, size.x - x0 - 450.0), minf(760.0, size.y - top - 60.0)), str(d.get("title", "")), GameMode.season_text(str(d.get("text", ""))))
	_hints(size.y - 22, size.x, [["W / S", "choose"], ["J", "close"]])
