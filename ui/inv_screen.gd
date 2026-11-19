class_name InvScreen
extends CanvasLayer
## Inventory screen, drawn by hand: a grid of slots with icons for what you
## carry, the chest you are searching on the left, and on the right your figure
## with what you wear and the weapon in your hands.
## Left click = use / wear / take.  Right click = drop (or put into the chest).

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.93, 0.96, 1.0, 0.5)
const PANEL := Color(0.05, 0.075, 0.12, 0.94)
const LINE := Color(0.45, 0.62, 0.85, 0.35)
const GOLD := Color(1.0, 0.8, 0.35)
const RED := Color(0.92, 0.25, 0.22)
const CELL := 74.0
const STEP := 80.0
const SLOT_ORDER := ["weapon", "ammo", "mod", "slot", "use", "upgrade"]

var player: Player
var box: LootBox
var icons: ItemIcons

var _c: Control
var _font: Font
var _hits: Array = []        # {rect, kind, id}
var _mouse := Vector2(-1, -1)
var _u := 1.0
var _off := Vector2.ZERO
var _scroll := {"inv": 0, "box": 0}
var _rows_max := {"inv": 0, "box": 0}
var _t := 0.0


class Painter extends Control:
	var host: InvScreen
	func _draw() -> void:
		host._paint()
	func _gui_input(event: InputEvent) -> void:
		host._on_input(event)


func _ready() -> void:
	layer = 5
	_font = ThemeDB.fallback_font
	var p := Painter.new()
	p.host = self
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_c = p
	add_child(_c)
	_c.visible = false
	icons = ItemIcons.new()
	add_child(icons)


func is_open() -> bool:
	return _c.visible


func open(container: LootBox) -> void:
	box = container
	_c.visible = true
	_t = 0.0
	_scroll = {"inv": 0, "box": 0}
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()


func close() -> void:
	_c.visible = false
	box = null
	player.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func refresh() -> void:
	if _c.visible:
		_c.queue_redraw()


func _process(delta: float) -> void:
	if _c.visible:
		_t += delta
		_c.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _c.visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event.position - _off) / _u
	elif event is InputEventMouseButton and event.pressed:
		_mouse = (event.position - _off) / _u
		var h := _hit_at(_mouse)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var which := "box" if (box and _mouse.x < _box_right) else "inv"
			var d := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			_scroll[which] = clampi(int(_scroll[which]) + d, 0, int(_rows_max[which]))
		elif h.is_empty():
			pass
		elif event.button_index == MOUSE_BUTTON_LEFT:
			match str(h["kind"]):
				"inv": _use(str(h["id"]))
				"box": _take(str(h["id"]))
				"worn": _unequip(str(h["id"]))
				"mod": _detach(str(h["id"]))
				"all": _take_all()
				"held": player.arms.hold("")
		elif event.button_index == MOUSE_BUTTON_RIGHT and str(h["kind"]) == "inv":
			_drop(str(h["id"]))
	refresh()


func _hit_at(p: Vector2) -> Dictionary:
	for h in _hits:
		if (h["rect"] as Rect2).has_point(p):
			return h
	return {}


# ------------------------------------------------------------ drawing helpers
var _box_right := 0.0


func _text(pos: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_c.draw_string(_font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, col.a * 0.6))
	_c.draw_string(_font, pos, text, align, width, size, col)


func _panel(r: Rect2, title: String, right := "", right_col := DIM) -> void:
	# soft shadow, dark body, a header that fades out to the right, corner ticks
	for i in 4:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.1)
		sb.set_corner_radius_all(8 + i * 4)
		_c.draw_style_box(sb, r.grow(4.0 + i * 5.0))
	_c.draw_rect(r, PANEL)
	var hb := Rect2(r.position, Vector2(r.size.x, 40))
	_c.draw_polygon(PackedVector2Array([hb.position, hb.position + Vector2(hb.size.x, 0), hb.end, hb.position + Vector2(0, hb.size.y)]),
		PackedColorArray([Color(0.13, 0.19, 0.3, 0.95), Color(0.07, 0.1, 0.16, 0.9), Color(0.07, 0.1, 0.16, 0.9), Color(0.13, 0.19, 0.3, 0.95)]))
	_c.draw_rect(Rect2(r.position, Vector2(4, 40)), GOLD)
	_c.draw_rect(Rect2(r.position + Vector2(0, 40), Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, 0.25))
	_c.draw_rect(r, LINE, false, 1.0)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var cp: Vector2 = corner
		var sx := 1.0 if cp.x == r.position.x else -1.0
		var sy := 1.0 if cp.y == r.position.y else -1.0
		_c.draw_line(cp + Vector2(sx * 4, sy * 4), cp + Vector2(sx * 14, sy * 4), Color(1, 1, 1, 0.3), 1.0)
		_c.draw_line(cp + Vector2(sx * 4, sy * 4), cp + Vector2(sx * 4, sy * 14), Color(1, 1, 1, 0.3), 1.0)
	_text(r.position + Vector2(18, 27), title.to_upper(), 17, INK)
	if right != "":
		_text(r.position + Vector2(0, 27), right, 15, right_col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16)


func _rarity(id: String) -> Color:
	var v := Items.num(id, "value")
	if v >= 300:
		return GOLD
	if v >= 100:
		return Color(0.45, 0.72, 1.0)
	if v >= 30:
		return Color(0.5, 0.85, 0.6)
	return Color(0.6, 0.65, 0.72)


func _slot(r: Rect2, id: String, n: int, kind: String, hit_id := "") -> void:
	var hover := r.has_point(_mouse)
	_c.draw_rect(r, Color(0.09, 0.13, 0.2, 0.95) if id != "" else Color(0.07, 0.1, 0.15, 0.6))
	if id != "":
		var rc := _rarity(id)
		_c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), rc)
		_c.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5 - 3)), Color(rc.r, rc.g, rc.b, 0.07))
		_item_icon(id, r.get_center() + Vector2(0, -3), r.size.y * 0.36)
		if n > 1:
			_text(r.position + Vector2(0, r.size.y - 8), str(n), 14, INK, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6)
		_hits.append({"rect": r, "kind": kind, "id": hit_id if hit_id != "" else id, "item": id})
	_c.draw_rect(r, Color(1, 1, 1, 0.75) if (hover and id != "") else Color(0.5, 0.65, 0.85, 0.22), false, 2.0 if (hover and id != "") else 1.0)


func _sorted(items: Dictionary) -> Array:
	var ids: Array = items.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka := _cat(a)
		var kb := _cat(b)
		return ka < kb if ka != kb else Items.name_of(a) < Items.name_of(b))
	return ids


func _cat(id: String) -> int:
	var it := Items.get_item(id)
	for i in SLOT_ORDER.size():
		if it.has(SLOT_ORDER[i]):
			return i
	return SLOT_ORDER.size()


func _grid(origin: Vector2, cols: int, rows: int, items: Dictionary, kind: String) -> void:
	var ids := _sorted(items)
	var need := int(ceil(ids.size() / float(cols)))
	_rows_max[kind] = maxi(need - rows, 0)
	_scroll[kind] = clampi(int(_scroll[kind]), 0, int(_rows_max[kind]))
	var first := int(_scroll[kind]) * cols
	for i in rows * cols:
		var r := Rect2(origin + Vector2((i % cols) * STEP, (i / cols) * STEP), Vector2(CELL, CELL))
		var j := first + i
		if j < ids.size():
			_slot(r, ids[j], int(items[ids[j]]), kind)
		else:
			_slot(r, "", 0, kind)
	if int(_rows_max[kind]) > 0:
		var track := Rect2(origin + Vector2(cols * STEP - 2, 0), Vector2(4, rows * STEP - 6))
		_c.draw_rect(track, Color(1, 1, 1, 0.08))
		var frac := rows / float(need)
		var at := int(_scroll[kind]) / float(need)
		_c.draw_rect(Rect2(track.position + Vector2(0, track.size.y * at), Vector2(4, track.size.y * frac)), Color(1, 1, 1, 0.5))


func _meter(pos: Vector2, width: float, label: String, frac: float, value: String, col: Color) -> void:
	_text(pos + Vector2(0, 11), label, 12, DIM)
	var bx := pos.x + 92.0
	var bw := width - 92.0 - 54.0
	_c.draw_rect(Rect2(bx, pos.y + 2, bw, 9), Color(1, 1, 1, 0.1))
	_c.draw_rect(Rect2(bx, pos.y + 2, bw * clampf(frac, 0.0, 1.0), 9), col)
	_text(Vector2(pos.x, pos.y + 12), value, 13, INK, HORIZONTAL_ALIGNMENT_RIGHT, width)


# ------------------------------------------------------------ the screen
func _paint() -> void:
	var size := _c.size
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.82 * minf(_t * 6.0, 1.0)))
	_u = minf(size.x / 1600.0, size.y / 900.0)
	_off = (size - Vector2(1600, 900) * _u) * 0.5
	var slide := (1.0 - minf(_t * 7.0, 1.0)) * 18.0
	_c.draw_set_transform(_off + Vector2(0, slide * _u), 0.0, Vector2(_u, _u))
	_hits.clear()
	var inv := player.inv
	var wbox := 4 * STEP + 30.0
	var wpack := 6 * STEP + 30.0
	var wchar := 400.0
	var total := wpack + wchar + 20.0 + ((wbox + 20.0) if box else 0.0)
	var x := (1600.0 - total) * 0.5
	var y := 130.0
	var h := 5 * STEP + 84.0
	var x0 := x
	_text(Vector2(x, y - 26), "INVENTORY" if box == null else "SEARCHING", 30, INK)
	_text(Vector2(x, y - 26), "TAB  close", 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT, total)

	_box_right = 0.0
	if box:
		var rb := Rect2(x, y, wbox, h)
		_panel(rb, box.title)
		_grid(Vector2(x + 18, y + 54), 4, 4, box.items, "box")
		var btn := Rect2(x + 18, y + h - 62, wbox - 36, 44)
		var any := not box.items.is_empty()
		var hov := btn.has_point(_mouse) and any
		_c.draw_rect(btn, Color(0.85, 0.65, 0.25, 0.9) if hov else Color(0.2, 0.28, 0.4, 0.9 if any else 0.4))
		_text(btn.position + Vector2(0, 29), "TAKE EVERYTHING" if any else "EMPTY", 16, Color(0.05, 0.05, 0.08) if hov else (INK if any else DIM), HORIZONTAL_ALIGNMENT_CENTER, btn.size.x)
		if any:
			_hits.append({"rect": btn, "kind": "all", "id": "", "item": ""})
		x += wbox + 20.0
		_box_right = x

	var over := player.stats.overloaded()
	var rp := Rect2(x, y, wpack, h)
	_panel(rp, "Backpack", "%.1f / %.0f kg" % [inv.weight(), inv.capacity()], RED if over else INK)
	var wf := inv.weight() / maxf(inv.capacity(), 1.0)
	_c.draw_rect(Rect2(x, y + 40, wpack, 4), Color(1, 1, 1, 0.08))
	_c.draw_rect(Rect2(x, y + 40, wpack * clampf(wf, 0.0, 1.0), 4), RED if over else (GOLD if wf > 0.8 else Color(0.5, 0.8, 1.0)))
	_grid(Vector2(x + 18, y + 54), 6, 5, inv.items, "inv")
	x += wpack + 20.0

	_paint_character(Rect2(x, y, wchar, h))

	# what the mouse is on
	var info := Rect2(x0, y + h + 16, total, 128)
	_c.draw_rect(info, PANEL)
	_c.draw_rect(info, LINE, false, 1.0)
	var hit := _hit_at(_mouse)
	var item := str(hit.get("item", ""))
	if item != "":
		var rc := _rarity(item)
		_c.draw_rect(Rect2(info.position, Vector2(4, info.size.y)), rc)
		_item_icon(item, info.position + Vector2(64, 64), 34.0)
		var lines := Items.describe(item).split("\n")
		_text(info.position + Vector2(128, 36), str(lines[0]).to_upper(), 22, rc)
		var rest: Array[String] = []
		for i in range(1, lines.size()):
			rest.append(str(lines[i]))
		_c.draw_multiline_string(_font, info.position + Vector2(128, 62), "   ·   ".join(rest), HORIZONTAL_ALIGNMENT_LEFT, total - 400, 14, 3, Color(0.93, 0.96, 1.0, 0.8))
		var act := ""
		var it := Items.get_item(item)
		match str(hit["kind"]):
			"box": act = "LEFT CLICK   take"
			"worn", "mod": act = "LEFT CLICK   take off"
			"held": act = "LEFT CLICK   put away"
			"inv":
				if it.has("slot"): act = "LEFT CLICK   wear"
				elif it.has("weapon"): act = "LEFT CLICK   take in hand"
				elif it.has("mod"): act = "LEFT CLICK   fit to weapon"
				elif it.has("use"): act = "LEFT CLICK   use"
		if act != "":
			_text(info.position + Vector2(0, 40), act, 14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, total - 22)
		if str(hit["kind"]) == "inv":
			_text(info.position + Vector2(0, 64), "RIGHT CLICK   " + ("put in chest" if box else "drop"), 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT, total - 22)
	else:
		_text(info.position + Vector2(0, 70), "Point at something to see what it is.", 15, DIM, HORIZONTAL_ALIGNMENT_CENTER, total)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What the worn clothes look like on a figure (a Humanoid look).
func _outfit(eq: Dictionary) -> Dictionary:
	var coat: String = {"light_jacket": "khaki", "parka": "navy", "expedition_suit": "orange", "frost_pelt": "pelt", "commander_coat": "navy"}.get(str(eq.get("body", "")), "grey")
	var hat: String = {"wool_hat": "beanie", "fur_hood": "hood", "helmet": "helmet"}.get(str(eq.get("head", "")), "none")
	return {"coat": coat, "trousers": "navy" if str(eq.get("legs", "")) == "snow_pants" else "denim", "hat": hat, "hat_col": "red" if hat == "beanie" else coat,
		"hair": "fur_brown", "vest": eq.has("armor"), "pack": eq.has("pack")}


func _paint_character(r: Rect2) -> void:
	var inv := player.inv
	_panel(r, "Equipment")
	var top := r.position.y + 54.0
	var lx := r.position.x + 18.0
	var rx := r.end.x - 18.0 - 66.0
	var cx := r.position.x + r.size.x * 0.5
	# the figure: a photograph of yourself in what you are wearing
	var eq := inv.equipped
	var cy := top + 4.0
	var key := "%s|%s|%s|%s|%s" % [eq.get("head", ""), eq.get("body", ""), eq.get("legs", ""), eq.get("armor", ""), eq.get("pack", "")]
	if icons.done:
		icons.shoot_figure(_outfit(eq), key)
	_c.draw_set_transform(Vector2(cx, cy + 286), 0.0, Vector2(1.0, 0.16))
	_c.draw_circle(Vector2.ZERO, 62.0, Color(0, 0, 0, 0.45))
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ItemIcons.figure_tex:
		_c.draw_texture_rect(ItemIcons.figure_tex, Rect2(cx - 75, cy, 150, 290), false)
	# slots around it
	var places := {
		"head": Vector2(lx, top), "body": Vector2(lx, top + 74), "hands": Vector2(lx, top + 148), "feet": Vector2(lx, top + 222),
		"pack": Vector2(rx, top), "armor": Vector2(rx, top + 74), "legs": Vector2(rx, top + 148),
	}
	for slot in places:
		var sr := Rect2(places[slot], Vector2(66, 66))
		var worn := str(eq.get(slot, ""))
		_slot(sr, worn, 1, "worn", slot)
		if worn == "":
			_text(sr.position + Vector2(0, 38), str(Items.SLOT_NAMES[slot]).to_upper(), 10, Color(1, 1, 1, 0.28), HORIZONTAL_ALIGNMENT_CENTER, 66)
	# weapon in hand, with its parts
	var arms := player.arms
	var wy := top + 300.0
	var wr := Rect2(lx, wy, r.size.x - 36, 58)
	_c.draw_rect(wr, Color(0.09, 0.13, 0.2, 0.95))
	_c.draw_rect(wr, Color(0.5, 0.65, 0.85, 0.22), false, 1.0)
	if arms.held != "":
		_item_icon(arms.held, wr.position + Vector2(42, 29), 24.0)
		_text(wr.position + Vector2(84, 25), Items.name_of(arms.held).to_upper(), 14, INK)
		_text(wr.position + Vector2(84, 44), "IN HAND" + ("   " + arms.ammo_text() if arms.is_gun() else ""), 11, DIM)
		_hits.append({"rect": Rect2(wr.position, Vector2(200, 58)), "kind": "held", "id": arms.held, "item": arms.held})
		var mods: Array = arms.st(arms.held)["mods"]
		var mx := wr.end.x - 46.0
		for m in mods:
			_slot(Rect2(mx, wy + 8, 42, 42), str(m), 1, "mod")
			mx -= 46.0
	else:
		_text(wr.position + Vector2(0, 35), "EMPTY HANDS", 13, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, wr.size.x)
	var my := wy + 70.0
	var mw := r.size.x - 36.0
	_meter(Vector2(lx, my), mw, "WARMTH", inv.warmth() / 100.0, str(int(inv.warmth())), Color(1.0, 0.6, 0.25))
	_meter(Vector2(lx, my + 19), mw, "ARMOUR", inv.armor() / 75.0, str(int(inv.armor())), Color(0.6, 0.75, 0.95))
	var sp := player.stats.speed_mult()
	_meter(Vector2(lx, my + 38), mw, "SPEED", sp, "%d %%" % int(round(sp * 100.0)), Color(0.5, 0.85, 0.6) if sp > 0.85 else RED)


# ------------------------------------------------------------ icons
func _pts(c: Vector2, s: float, a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(c + Vector2(float(a[i]), float(a[i + 1])) * s)
	return out


func _poly(c: Vector2, s: float, a: Array, col: Color) -> void:
	_c.draw_colored_polygon(_pts(c, s, a), col)


func _box_at(c: Vector2, s: float, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	_c.draw_rect(Rect2(c + Vector2(x0, y0) * s, Vector2(x1 - x0, y1 - y0) * s), col)


const CLOTH_COL := {
	"parka": Color(0.25, 0.4, 0.7), "frost_pelt": Color(0.86, 0.93, 1.0), "commander_coat": Color(0.2, 0.25, 0.42), "plate_harness": Color(0.9, 0.72, 0.15), "expedition_suit": Color(0.95, 0.5, 0.15), "light_jacket": Color(0.55, 0.6, 0.5),
	"wool_hat": Color(0.8, 0.25, 0.25), "fur_hood": Color(0.6, 0.45, 0.3), "helmet": Color(0.45, 0.52, 0.45),
	"jeans": Color(0.3, 0.42, 0.65), "snow_pants": Color(0.75, 0.78, 0.85), "boots": Color(0.5, 0.33, 0.2), "fur_boots": Color(0.65, 0.5, 0.35),
	"gloves": Color(0.35, 0.35, 0.4), "mittens": Color(0.8, 0.3, 0.3), "kevlar_vest": Color(0.3, 0.36, 0.3), "plate_carrier": Color(0.55, 0.5, 0.38),
	"small_pack": Color(0.45, 0.55, 0.35), "large_pack": Color(0.8, 0.45, 0.2),
}


## Lets other screens (the trader's stall) draw the same item pictures on their own canvas.
func icon_on(canvas: Control, id: String, c: Vector2, s: float) -> void:
	var keep := _c
	_c = canvas
	_item_icon(id, c, s)
	_c = keep


func _item_icon(id: String, c: Vector2, s: float) -> void:
	# the photographed 3D model, once it is ready; the flat drawing below is only the stand-in
	var pic: Texture2D = ItemIcons.tex.get(id)
	if pic:
		var h := s * (1.3 if s > 14.0 else 1.55)
		if s > 14.0:       # small list pictures go without the shadow: it only muddies them
			_c.draw_set_transform(c + Vector2(0, h * 0.86), 0.0, Vector2(1.0, 0.22))
			_c.draw_circle(Vector2.ZERO, h * 0.62, Color(0, 0, 0, 0.28))
			_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_c.draw_texture_rect(pic, Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false)
		return
	var it := Items.get_item(id)
	var steel := Color(0.72, 0.76, 0.82)
	var dark := Color(0.28, 0.3, 0.35)
	var wood := Color(0.62, 0.42, 0.25)
	var brass := Color(0.9, 0.72, 0.35)
	if it.has("slot"):
		var col: Color = CLOTH_COL.get(id, Color(0.6, 0.66, 0.75))
		var shade := col.darkened(0.3)
		match str(it["slot"]):
			"head":
				if id == "helmet":
					_poly(c, s, [-0.85, 0.3, -0.8, -0.2, -0.45, -0.65, 0.45, -0.65, 0.8, -0.2, 0.85, 0.3], col)
					_box_at(c, s, -0.95, 0.25, 0.95, 0.42, shade)
				else:
					_poly(c, s, [-0.7, 0.35, -0.65, -0.25, -0.3, -0.6, 0.3, -0.6, 0.65, -0.25, 0.7, 0.35], col)
					_box_at(c, s, -0.75, 0.25, 0.75, 0.6, shade)
					_c.draw_circle(c + Vector2(0, -0.72) * s, s * 0.17, col.lightened(0.3))
			"body":
				_poly(c, s, [-0.45, -0.8, 0.45, -0.8, 0.5, 0.85, -0.5, 0.85], col)
				_poly(c, s, [-0.45, -0.8, -0.95, -0.45, -0.85, 0.5, -0.55, 0.45, -0.5, -0.2], shade)
				_poly(c, s, [0.45, -0.8, 0.95, -0.45, 0.85, 0.5, 0.55, 0.45, 0.5, -0.2], shade)
				_c.draw_line(c + Vector2(0, -0.8) * s, c + Vector2(0, 0.85) * s, shade, 2.0)
				_poly(c, s, [-0.28, -0.95, 0.28, -0.95, 0.2, -0.7, -0.2, -0.7], col.lightened(0.25))
			"legs":
				_poly(c, s, [-0.6, -0.85, 0.6, -0.85, 0.7, 0.9, 0.12, 0.9, 0.0, -0.2, -0.12, 0.9, -0.7, 0.9], col)
				_box_at(c, s, -0.6, -0.85, 0.6, -0.65, shade)
			"feet":
				_poly(c, s, [-0.55, -0.85, 0.05, -0.85, 0.1, 0.1, 0.8, 0.35, 0.85, 0.7, -0.55, 0.7], col)
				_box_at(c, s, -0.6, 0.62, 0.9, 0.85, shade)
				_box_at(c, s, -0.6, -0.9, 0.1, -0.68, col.lightened(0.25))
			"hands":
				_poly(c, s, [-0.4, 0.85, -0.5, -0.1, -0.35, -0.8, 0.35, -0.8, 0.5, -0.1, 0.4, 0.85], col)
				_poly(c, s, [0.45, 0.2, 0.85, -0.25, 0.95, 0.0, 0.5, 0.55], col)
				_box_at(c, s, -0.45, 0.6, 0.45, 0.9, shade)
			"armor":
				_poly(c, s, [-0.7, -0.5, -0.35, -0.85, -0.2, -0.5, 0.2, -0.5, 0.35, -0.85, 0.7, -0.5, 0.65, 0.85, -0.65, 0.85], col)
				_box_at(c, s, -0.45, -0.1, 0.45, 0.55, shade)
				_box_at(c, s, -0.45, 0.1, 0.45, 0.16, col)
				_box_at(c, s, -0.45, 0.32, 0.45, 0.38, col)
			"pack":
				_poly(c, s, [-0.6, -0.5, -0.4, -0.8, 0.4, -0.8, 0.6, -0.5, 0.65, 0.85, -0.65, 0.85], col)
				_poly(c, s, [-0.62, -0.5, 0.62, -0.5, 0.55, -0.05, -0.55, -0.05], shade)
				_box_at(c, s, -0.3, 0.15, 0.3, 0.6, shade)
				_box_at(c, s, -0.06, -0.3, 0.06, 0.0, brass)
		return
	if it.has("weapon"):
		match id:
			"knife":
				_poly(c, s, [-0.1, 0.1, 0.75, -0.75, 0.95, -0.95, 0.1, 0.3], steel)
				_poly(c, s, [-0.85, 0.65, -0.2, 0.0, 0.0, 0.2, -0.65, 0.85], wood)
				_poly(c, s, [-0.3, -0.1, 0.1, 0.3, 0.2, 0.2, -0.2, -0.2], dark)
			"sword":
				_poly(c, s, [-0.45, 0.35, 0.85, -0.95, 0.95, -0.85, -0.35, 0.45], steel)
				_poly(c, s, [-0.65, 0.2, -0.2, 0.65, -0.3, 0.75, -0.75, 0.3], brass)
				_poly(c, s, [-0.9, 0.75, -0.5, 0.35, -0.4, 0.45, -0.8, 0.85], dark)
			"axe":
				_poly(c, s, [-0.85, 0.75, 0.45, -0.55, 0.6, -0.4, -0.7, 0.9], wood)
				_poly(c, s, [0.1, -0.5, 0.45, -0.95, 0.95, -0.45, 0.85, 0.05, 0.5, -0.15], steel)
			"ice_pick":
				_poly(c, s, [-0.8, 0.8, 0.35, -0.35, 0.5, -0.2, -0.65, 0.95], dark)
				_poly(c, s, [-0.35, -0.5, 0.2, -0.75, 0.8, -0.55, 0.95, -0.1, 0.5, -0.35, 0.15, -0.4], steel)
			_:
				_gun_icon(id, c, s)
		return
	if it.has("ammo"):
		var shell := id.begins_with("12g")
		var tip := Color(0.75, 0.5, 0.3)
		if id.ends_with("_ap"):
			tip = Color(0.2, 0.2, 0.24)
		for i in 3:
			var o := Vector2((i - 1) * 0.55, 0.12 if i != 1 else -0.08) * s
			if shell:
				_box_at(c + o, s, -0.2, -0.45, 0.2, 0.45, RED if id == "12g" else Color(0.3, 0.5, 0.3))
				_box_at(c + o, s, -0.22, 0.4, 0.22, 0.7, brass)
			elif id == "flare":
				_box_at(c + o, s, -0.2, -0.55, 0.2, 0.7, Color(0.95, 0.45, 0.2))
				_box_at(c + o, s, -0.2, -0.75, 0.2, -0.55, Color(0.95, 0.9, 0.8))
			else:
				_box_at(c + o, s, -0.17, -0.25, 0.17, 0.7, brass)
				_poly(c + o, s, [-0.17, -0.25, 0.0, -0.85, 0.17, -0.25], tip)
		return
	if it.has("mod"):
		match id:
			"red_dot":
				_box_at(c, s, -0.7, 0.3, 0.7, 0.6, dark)
				_c.draw_arc(c + Vector2(0, -0.15) * s, s * 0.5, 0.0, TAU, 20, dark, s * 0.16)
				_c.draw_circle(c + Vector2(0, -0.15) * s, s * 0.1, RED)
			"scope":
				_box_at(c, s, -0.95, -0.3, -0.5, 0.3, dark)
				_box_at(c, s, -0.5, -0.17, 0.45, 0.17, steel.darkened(0.4))
				_box_at(c, s, 0.45, -0.38, 0.95, 0.38, dark)
				_box_at(c, s, -0.1, -0.4, 0.1, -0.17, dark)
				_box_at(c, s, -0.3, 0.17, 0.3, 0.5, dark)
			"silencer":
				_box_at(c, s, -0.9, -0.24, 0.9, 0.24, dark)
				for i in 5:
					_box_at(c, s, -0.7 + i * 0.32, -0.24, -0.66 + i * 0.32, 0.24, steel.darkened(0.3))
			"muzzle_brake":
				_box_at(c, s, -0.6, -0.3, 0.6, 0.3, steel.darkened(0.3))
				for i in 3:
					_box_at(c, s, -0.35 + i * 0.3, -0.3, -0.2 + i * 0.3, 0.3, Color(0.05, 0.05, 0.08))
			"grip":
				_box_at(c, s, -0.6, -0.8, 0.6, -0.5, steel.darkened(0.3))
				_poly(c, s, [-0.22, -0.5, 0.22, -0.5, 0.3, 0.85, -0.3, 0.85], dark)
			_:
				_poly(c, s, [-0.25, -0.9, 0.3, -0.9, 0.45, 0.2, 0.2, 0.9, -0.4, 0.9, -0.2, 0.2], dark)
				_box_at(c, s, -0.22, -0.9, 0.28, -0.7, brass)
		return
	if it.has("key"):
		if id == "keycard_lab":
			_poly(c, s, [-0.85, -0.5, 0.85, -0.5, 0.85, 0.5, -0.85, 0.5], Color(0.9, 0.9, 0.86))
			_box_at(c, s, -0.85, -0.5, 0.85, -0.22, Color(0.9, 0.45, 0.1))
			_box_at(c, s, -0.65, -0.05, -0.2, 0.35, Color(0.3, 0.5, 0.7))
			_box_at(c, s, 0.0, 0.0, 0.65, 0.08, dark)
			_box_at(c, s, 0.0, 0.2, 0.45, 0.28, dark)
		else:
			_c.draw_arc(c + Vector2(-0.45, -0.45) * s, s * 0.3, 0.0, TAU, 18, brass, s * 0.17)
			_poly(c, s, [-0.3, -0.15, -0.15, -0.3, 0.85, 0.7, 0.7, 0.85], brass)
			_poly(c, s, [0.45, 0.6, 0.65, 0.4, 0.85, 0.6, 0.65, 0.8], brass.darkened(0.2))
			_poly(c, s, [0.2, 0.35, 0.4, 0.15, 0.55, 0.3, 0.35, 0.5], brass.darkened(0.2))
		return
	if it.has("tool"):
		if id == "crowbar":
			_poly(c, s, [-0.8, 0.85, 0.55, -0.6, 0.68, -0.47, -0.67, 0.98], Color(0.75, 0.2, 0.15))
			_poly(c, s, [0.5, -0.65, 0.9, -0.9, 0.98, -0.6, 0.7, -0.45], steel)
			_poly(c, s, [-0.95, 0.75, -0.75, 0.8, -0.7, 0.98, -0.9, 0.98], steel)
		else:
			_poly(c, s, [-0.85, 0.9, -0.1, 0.0, 0.05, 0.12, -0.65, 0.98], Color(0.75, 0.2, 0.15))
			_poly(c, s, [0.85, 0.9, 0.1, 0.0, -0.05, 0.12, 0.65, 0.98], Color(0.75, 0.2, 0.15))
			_poly(c, s, [-0.12, 0.05, 0.3, -0.85, 0.45, -0.8, 0.08, 0.15], steel)
			_poly(c, s, [0.12, 0.05, -0.3, -0.85, -0.45, -0.8, -0.08, 0.15], steel.darkened(0.2))
			_c.draw_circle(c + Vector2(0, 0.05) * s, s * 0.1, dark)
		return
	match id:
		"coin":
			_c.draw_circle(c + Vector2(-0.2, 0.2) * s, s * 0.5, Color(0.75, 0.55, 0.15))
			_c.draw_circle(c + Vector2(0.15, -0.1) * s, s * 0.55, Color(1.0, 0.8, 0.35))
			_c.draw_circle(c + Vector2(0.15, -0.1) * s, s * 0.36, Color(0.8, 0.6, 0.2))
		"parcel":
			_box_at(c, s, -0.75, -0.5, 0.75, 0.7, Color(0.62, 0.47, 0.3))
			_box_at(c, s, -0.08, -0.5, 0.08, 0.7, Color(0.85, 0.8, 0.65))
			_box_at(c, s, -0.75, 0.02, 0.75, 0.18, Color(0.85, 0.8, 0.65))
		"medicine_crate":
			_box_at(c, s, -0.8, -0.55, 0.8, 0.7, Color(0.85, 0.86, 0.84))
			_box_at(c, s, -0.8, -0.55, 0.8, -0.38, Color(0.6, 0.62, 0.6))
			_box_at(c, s, -0.12, -0.25, 0.12, 0.5, Color(0.8, 0.15, 0.12))
			_box_at(c, s, -0.4, 0.02, 0.4, 0.24, Color(0.8, 0.15, 0.12))
		"canned_food":
			_box_at(c, s, -0.5, -0.6, 0.5, 0.75, steel.darkened(0.15))
			_box_at(c, s, -0.5, -0.25, 0.5, 0.45, Color(0.8, 0.3, 0.25))
			_box_at(c, s, -0.55, -0.72, 0.55, -0.58, steel)
		"hot_tea":
			_box_at(c, s, -0.35, -0.45, 0.35, 0.9, Color(0.25, 0.5, 0.45))
			_box_at(c, s, -0.3, -0.9, 0.3, -0.45, steel)
			_box_at(c, s, -0.35, 0.0, 0.35, 0.12, steel.darkened(0.2))
		"hand_warmer":
			_box_at(c, s, -0.6, -0.4, 0.6, 0.75, Color(0.85, 0.85, 0.8))
			_poly(c, s, [0.0, -0.2, 0.28, 0.25, 0.0, 0.55, -0.28, 0.25], Color(1.0, 0.55, 0.2))
		"bandage":
			_c.draw_circle(c + Vector2(-0.15, 0.1) * s, s * 0.6, Color(0.92, 0.9, 0.85))
			_c.draw_circle(c + Vector2(-0.15, 0.1) * s, s * 0.22, Color(0.7, 0.68, 0.62))
			_poly(c, s, [0.2, -0.4, 0.9, -0.75, 0.95, -0.45, 0.4, -0.1], Color(0.92, 0.9, 0.85))
		"medkit":
			_box_at(c, s, -0.8, -0.5, 0.8, 0.75, Color(0.8, 0.2, 0.2))
			_box_at(c, s, -0.25, -0.75, 0.25, -0.5, dark)
			_box_at(c, s, -0.12, -0.25, 0.12, 0.5, Color.WHITE)
			_box_at(c, s, -0.38, 0.0, 0.38, 0.25, Color.WHITE)
		"splint":
			_poly(c, s, [-0.9, 0.55, 0.65, -0.9, 0.85, -0.7, -0.7, 0.75], wood)
			_poly(c, s, [-0.55, 0.9, 0.9, -0.5, 0.7, -0.7, -0.75, 0.7], wood.lightened(0.2))
			_poly(c, s, [-0.3, 0.0, 0.1, 0.4, 0.3, 0.2, -0.1, -0.2], Color(0.92, 0.9, 0.85))
		"painkillers":
			_box_at(c, s, -0.4, -0.35, 0.4, 0.85, Color(0.9, 0.55, 0.2))
			_box_at(c, s, -0.45, -0.75, 0.45, -0.35, Color.WHITE)
			_box_at(c, s, -0.4, 0.05, 0.4, 0.5, Color(0.95, 0.95, 0.9))
		"scrap":
			_poly(c, s, [-0.85, 0.3, -0.5, -0.6, 0.1, -0.35, 0.3, 0.2, -0.2, 0.75], steel.darkened(0.35))
			_poly(c, s, [-0.1, -0.2, 0.5, -0.8, 0.9, -0.2, 0.6, 0.7, 0.1, 0.4], steel.darkened(0.1))
		"cloth":
			_poly(c, s, [-0.8, -0.3, 0.5, -0.6, 0.85, 0.2, -0.5, 0.6], Color(0.6, 0.3, 0.3))
			_poly(c, s, [-0.5, 0.6, 0.85, 0.2, 0.85, 0.45, -0.5, 0.85], Color(0.42, 0.2, 0.2))
		"firewood":
			_box_at(c, s, -0.9, 0.1, 0.9, 0.6, wood.darkened(0.25))
			_box_at(c, s, -0.75, -0.45, 0.75, 0.05, wood)
			_c.draw_circle(c + Vector2(0.75, -0.2) * s, s * 0.26, wood.lightened(0.35))
			_c.draw_circle(c + Vector2(0.9, 0.35) * s, s * 0.26, wood.lightened(0.2))
		"batteries":
			_box_at(c, s, -0.6, -0.55, -0.05, 0.8, Color(0.2, 0.2, 0.25))
			_box_at(c, s, -0.6, -0.55, -0.05, -0.15, brass)
			_box_at(c, s, -0.42, -0.72, -0.22, -0.55, steel)
			_box_at(c, s, 0.1, -0.55, 0.65, 0.8, Color(0.2, 0.2, 0.25))
			_box_at(c, s, 0.1, -0.55, 0.65, -0.15, brass)
			_box_at(c, s, 0.28, -0.72, 0.48, -0.55, steel)
		"rope":
			for i in 4:
				_c.draw_arc(c, s * (0.3 + i * 0.17), 0.0, TAU, 24, Color(0.85, 0.55, 0.25) if i % 2 == 0 else Color(0.7, 0.42, 0.18), s * 0.14)
		"fuel_can":
			_poly(c, s, [-0.65, -0.5, 0.3, -0.5, 0.65, -0.15, 0.65, 0.85, -0.65, 0.85], Color(0.75, 0.2, 0.15))
			_box_at(c, s, -0.5, -0.8, -0.05, -0.5, Color(0.55, 0.14, 0.1))
			_c.draw_line(c + Vector2(-0.4, -0.1) * s, c + Vector2(0.4, 0.6) * s, Color(0.5, 0.12, 0.1), 2.0)
			_c.draw_line(c + Vector2(0.4, -0.1) * s, c + Vector2(-0.4, 0.6) * s, Color(0.5, 0.12, 0.1), 2.0)
		_:
			# vehicle parts and anything else: a cog
			_c.draw_circle(c, s * 0.6, steel.darkened(0.2))
			for i in 8:
				var a := i * TAU / 8.0
				_c.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.5, c + Vector2(cos(a), sin(a)) * s * 0.9, steel.darkened(0.2), s * 0.26)
			_c.draw_circle(c, s * 0.25, PANEL)


func _gun_icon(id: String, c: Vector2, s: float) -> void:
	var dark := Color(0.25, 0.27, 0.32)
	var steel := Color(0.55, 0.6, 0.68)
	var wood := Color(0.62, 0.42, 0.25)
	if id == "pistol" or id == "revolver" or id == "flare_gun":
		var body := Color(0.9, 0.45, 0.2) if id == "flare_gun" else steel
		_box_at(c, s, -0.65, -0.5, 0.85, -0.15, body)
		_poly(c, s, [-0.65, -0.15, -0.15, -0.15, -0.3, 0.8, -0.8, 0.8], wood if id == "revolver" else dark)
		_c.draw_arc(c + Vector2(0.05, 0.02) * s, s * 0.2, 0.0, PI, 10, dark, 2.0)
		if id == "revolver":
			_c.draw_circle(c + Vector2(0.05, -0.3) * s, s * 0.27, dark)
		if id == "flare_gun":
			_box_at(c, s, 0.3, -0.6, 0.85, -0.05, body.darkened(0.2))
		return
	var long := id == "sniper_rifle" or id == "marksman_rifle"
	var furn := wood if (id == "shotgun" or id == "marksman_rifle") else dark
	var muzzle := 0.98 if (long or id == "shotgun") else (0.6 if id == "smg" else 0.9)
	# barrel, receiver, stock, grip
	_box_at(c, s, 0.1, -0.2, muzzle, -0.1, steel)
	_box_at(c, s, -0.4, -0.28, 0.25, 0.02, dark)
	if id == "smg":
		_box_at(c, s, -0.9, -0.24, -0.4, -0.14, steel)
		_box_at(c, s, -0.92, -0.26, -0.84, 0.12, steel)
	else:
		_poly(c, s, [-0.4, -0.26, -0.98, -0.16, -0.98, 0.22, -0.4, 0.0], furn)
	_poly(c, s, [-0.36, 0.02, -0.18, 0.02, -0.28, 0.42, -0.46, 0.42], furn)
	match id:
		"shotgun":
			_box_at(c, s, 0.25, -0.08, 0.9, 0.0, steel.darkened(0.25))
			_box_at(c, s, 0.3, -0.12, 0.62, 0.08, wood)
		"smg":
			_box_at(c, s, -0.05, 0.02, 0.07, 0.75, dark.lightened(0.1))
			_box_at(c, s, 0.25, -0.26, 0.5, -0.04, dark)
		"assault_rifle":
			_poly(c, s, [-0.05, 0.02, 0.14, 0.02, 0.26, 0.6, 0.07, 0.62], dark.lightened(0.1))
			_box_at(c, s, 0.25, -0.27, 0.65, -0.03, dark.lightened(0.08))
			_box_at(c, s, 0.72, -0.36, 0.78, -0.2, dark)
		_:
			_box_at(c, s, 0.25, -0.24, 0.6, -0.04, furn)
			_box_at(c, s, -0.02, 0.02, 0.12, 0.3, dark.lightened(0.1))
			_box_at(c, s, -0.3, -0.5, 0.35 if id == "sniper_rifle" else 0.2, -0.36, dark)
			_box_at(c, s, -0.38, -0.56, -0.26, -0.3, dark)
			_box_at(c, s, -0.15, -0.36, -0.07, -0.28, dark)
			if id == "sniper_rifle":
				_c.draw_line(c + Vector2(0.55, -0.04) * s, c + Vector2(0.45, 0.4) * s, steel, 2.0)
				_c.draw_line(c + Vector2(0.55, -0.04) * s, c + Vector2(0.68, 0.4) * s, steel, 2.0)


# ------------------------------------------------------------ actions
func _take(id: String) -> void:
	if box and box.take(id):
		player.inv.add(id)
	refresh()


func _take_all() -> void:
	if box:
		for id in box.items.keys():
			player.inv.add(id, int(box.items[id]))
		box.items.clear()
	refresh()


func _use(id: String) -> void:
	var it := Items.get_item(id)
	if it.has("slot"):
		player.inv.equip(id)
	elif it.has("weapon"):
		player.arms.hold("" if player.arms.held == id else id)
	elif it.has("mod"):
		var msg := player.arms.attach(id)
		if msg != "":
			player.message.emit(msg)
	elif it.has("use"):
		if player.stats.consume(id):
			player.inv.remove(id)
	refresh()


func _drop(id: String) -> void:
	if not player.inv.remove(id):
		return
	if box:
		box.put(id)
	else:
		player.drop_item(id)
	refresh()


func _unequip(slot: String) -> void:
	player.inv.unequip(slot)
	refresh()


func _detach(mod: String) -> void:
	player.arms.detach(mod)
	refresh()
