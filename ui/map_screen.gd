class_name MapScreen
extends CanvasLayer
## The valley map (M): shaded relief drawn from the terrain once, roads, the lake and the town,
## every place you have discovered, where you stand, and where the tracked job wants you.

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.93, 0.96, 1.0, 0.55)
const GOLD := Color(1.0, 0.8, 0.35)
const RES := 320

var main: Node
var _tex: ImageTexture
var _c: Control
var _font: Font
var _zoom := 1.0
var _pan := Vector2.ZERO        # world metres at the map centre


class Painter extends Control:
	var m: MapScreen
	func _draw() -> void:
		m._paint()


func _ready() -> void:
	layer = 7
	_font = ThemeDB.fallback_font
	var p := Painter.new()
	p.m = self
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	_c = p
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if main.player.ui_open:
		return
	if _tex == null:
		_tex = ImageTexture.create_from_image(_bake())
	var pp: Vector3 = main.player.global_position
	_pan = Vector2(pp.x, pp.z)
	_zoom = 1.0
	visible = true
	main.player.ui_open = true
	_c.queue_redraw()


func close() -> void:
	visible = false
	main.player.ui_open = false


func _bake() -> Image:
	var t: Terrain = main.terrain
	var rows := int(RES * Terrain.DEPTH / Terrain.SIZE)
	var img := Image.create(RES, rows, false, Image.FORMAT_RGB8)
	var step := Terrain.SIZE / RES
	var light := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in rows:
		for i in RES:
			var x := -Terrain.HALF + (i + 0.5) * step
			var z := -Terrain.HALF + (j + 0.5) * step
			var h := t.height_at(x, z)
			var n := t.normal_at(x, z)
			var shade := clampf(n.dot(light) * 0.9 + 0.25, 0.0, 1.0)
			var g := clampf((h - 15.0) / 280.0, 0.0, 1.0)
			# snowfield paper: low ground blue-white, high rock grey, steep ground darker
			var c := Color(0.80, 0.85, 0.90).lerp(Color(0.62, 0.64, 0.68), g)
			if n.y < 0.75:
				c = c.lerp(Color(0.35, 0.36, 0.40), 0.6)
			c = c * (0.55 + 0.55 * shade)
			if t.on_lake(x, z) and h < Terrain.LAKE_LEVEL + 0.5:
				c = Color(0.42, 0.58, 0.72) * (0.85 + 0.15 * shade)
			if t.on_road(x, z):
				c = Color(0.30, 0.27, 0.24)
			# faint contour every 25 m
			if fmod(h, 25.0) < 1.6 and n.y > 0.75:
				c = c.darkened(0.12)
			img.set_pixel(i, j, Color(c.r, c.g, c.b))
	return img


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause") or event.is_action_pressed("inventory") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("next_weapon"):
		_zoom = clampf(_zoom / 1.25, 0.66, 5.0)
	elif event.is_action_pressed("prev_weapon"):
		_zoom = clampf(_zoom * 1.25, 0.66, 5.0)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pan -= (event as InputEventMouseMotion).relative / _scale()
	else:
		return
	get_viewport().set_input_as_handled()
	_c.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mv != Vector2.ZERO:
		_pan += mv * delta * 500.0 / _zoom
		_c.queue_redraw()


func _rect() -> Rect2:
	var s := minf(_c.size.y - 110.0, _c.size.x - 420.0)
	return Rect2((_c.size.x - s) * 0.5 - 150.0, 60.0, s, s)


func _scale() -> float:
	return _rect().size.x / Terrain.SIZE * _zoom


func _to_screen(w: Vector3) -> Vector2:
	var r := _rect()
	var hv := Terrain.HALF / _zoom      # half of what the window shows, in metres
	_pan.x = 0.0 if hv >= Terrain.HALF else clampf(_pan.x, -Terrain.HALF + hv, Terrain.HALF - hv)
	var mid_z := (Terrain.Z_MAX - Terrain.HALF) * 0.5
	_pan.y = mid_z if hv >= Terrain.DEPTH * 0.5 else clampf(_pan.y, -Terrain.HALF + hv, Terrain.Z_MAX - hv)
	return r.get_center() + (Vector2(w.x, w.z) - _pan) * _scale()


func _paint() -> void:
	if not visible:
		return
	var size := _c.size
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.82))
	var r := _rect()
	# map image, cropped to the zoomed window
	var tl := _to_screen(Vector3(-Terrain.HALF, 0, -Terrain.HALF))
	var px := _scale() * Terrain.SIZE / RES      # screen pixels per map pixel
	var vis := r.intersection(Rect2(tl, Vector2(Terrain.SIZE, Terrain.DEPTH) * _scale()))
	_c.draw_texture_rect_region(_tex, vis, Rect2((vis.position - tl) / px, vis.size / px))
	_c.draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
	# town and the grid
	var tp0 := _to_screen(Vector3(Terrain.VILLAGE_POS.x, 0, Terrain.VILLAGE_POS.y)) + Vector2(-34, -16)
	_c.draw_string_outline(_font, tp0, "POLARIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.85, 0.88, 0.92))
	_c.draw_string(_font, tp0, "POLARIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.12, 0.10, 0.08))
	_c.draw_string(_font, _to_screen(Vector3(Terrain.LAKE_POS.x, 0, Terrain.LAKE_POS.y)) + Vector2(-50, 4), "THE LAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.95, 1.0, 0.75))
	var gp := _to_screen(Vector3(SiteSouth.TOWN.x, 0, SiteSouth.TOWN.y)) + Vector2(-44, -16)
	if r.has_point(gp) and "grauwasser" in main.places.found:
		_c.draw_string_outline(_font, gp, "GRAUWASSER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0.85, 0.88, 0.92))
		_c.draw_string(_font, gp, "GRAUWASSER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.12, 0.10, 0.08))
	# places
	var pl: Places = main.places
	for s in pl.spots:
		var p := _to_screen(s["pos"])
		if not r.has_point(p):
			continue
		var known: bool = str(s["id"]) in pl.found
		if known:
			_c.draw_circle(p, 6.0, Color(0.12, 0.1, 0.08))
			_c.draw_circle(p, 4.0, GOLD if s["kind"] != "view" else Color(0.55, 0.85, 1.0))
			_c.draw_string_outline(_font, p + Vector2(10, 5), str(s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.85, 0.88, 0.92))
			_c.draw_string(_font, p + Vector2(10, 5), str(s["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.07, 0.06))
		else:
			_c.draw_string(_font, p + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.12, 0.45))
	# where the tracked job wants you
	var q: Quests = main.quests
	var tq := ""
	var qid: String = q.main_quest()
	var ids: Array = q.active()
	if qid == "" and not ids.is_empty():
		qid = ids[ids.size() - 1]
	if qid != "":
		var tp: Vector3 = q.target(qid)
		if tp != Vector3.INF:
			var p := _to_screen(tp)
			var pulse := 9.0 + sin(Time.get_ticks_msec() * 0.006) * 3.0
			_c.draw_arc(p, pulse, 0, TAU, 24, Color(0.95, 0.25, 0.2), 3.0)
			_c.draw_circle(p, 3.5, Color(0.95, 0.25, 0.2))
		tq = q.objective(qid)
	# you
	var pp: Vector3 = main.player.global_position
	var me := _to_screen(pp)
	var fwd: Vector3 = -main.player.global_basis.z
	var a := atan2(fwd.z, fwd.x)
	var pts := PackedVector2Array([me + Vector2.from_angle(a) * 13.0, me + Vector2.from_angle(a + 2.5) * 8.0, me + Vector2.from_angle(a + PI) * 3.0, me + Vector2.from_angle(a - 2.5) * 8.0])
	_c.draw_colored_polygon(pts, Color(0.9, 0.15, 0.1))
	_c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1), 1.5)
	# side panel
	var x := r.end.x + 36.0
	_c.draw_string(_font, Vector2(x, 90), "THE SENKE" if main.player.global_position.z < 600.0 else "THE VORLAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
	_c.draw_string(_font, Vector2(x, 116), "%d of %d places discovered" % [pl.found.size(), pl.spots.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	if qid != "":
		_c.draw_string(_font, Vector2(x, 170), str(Quests.DEFS[qid]["title"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 300, 13, GOLD)
		_c.draw_multiline_string(_font, Vector2(x, 194), tq, HORIZONTAL_ALIGNMENT_LEFT, 280, 15, 5, INK)
	var ly := 330.0
	for leg in [[Color(0.9, 0.15, 0.1), "You"], [Color(0.95, 0.25, 0.2), "Next goal"], [GOLD, "Place"], [Color(0.55, 0.85, 1.0), "Viewpoint"], [Color(0.3, 0.27, 0.24), "Road"]]:
		_c.draw_circle(Vector2(x + 6, ly - 5), 5.0, leg[0])
		_c.draw_string(_font, Vector2(x + 20, ly), str(leg[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
		ly += 24.0
	_c.draw_string(_font, Vector2(0, size.y - 22), "[W A S D] / drag  move      [wheel]  zoom      [M]  close", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, DIM)
	_c.queue_redraw()
