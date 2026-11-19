class_name TownScreen
extends CanvasLayer
## Everything you do with people and benches: talking, taking jobs, trading, crafting,
## and (with L) the job log with your standing among the factions.
## Keys: W/S choose, A/D switch side, E confirm, 1-9 pick, Esc or Tab close.
## The mouse works too: point at a row, click it, wheel to scroll.
## Talking is framed like a film: black bars, a name plate, the words typed out.

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.93, 0.96, 1.0, 0.55)
const GOLD := Color(1.0, 0.8, 0.35)
const RED := Color(0.92, 0.3, 0.26)
const GREEN := Color(0.5, 0.85, 0.5)
const TIER_COL := [Color(0.8, 0.82, 0.86), Color(0.45, 0.85, 0.5), Color(0.4, 0.65, 1.0), Color(0.8, 0.5, 1.0)]
const TIER_NAME := ["Common", "Uncommon", "Rare", "Epic"]

var main: Node
var player: Player
var mode := ""              # "" closed, talk, trade, craft, quests
var npc: Npc
var line := ""              # what the person just said
var note := ""              # result of the last deal
var _opts: Array = []       # [label, action]
var _pending := ""          # quest id being offered
var _sel := 0
var _side := 0              # trade: 0 their goods, 1 yours
var _c: Control
var _font: Font
var _hits: Array = []       # {r: Rect2, i: row, side: trade side} from the last paint
var _k := 0.0               # opening animation 0..1
var _typed := ""            # the line being typed out
var _shown := 0.0           # how many of its letters are out
var _tick := 0
var _time := 0.0
var _fov_keep := -1.0       # the view narrows a little while you talk


class Painter extends Control:
	var scr: TownScreen
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


func is_open() -> bool:
	return mode != ""


func _open(m: String) -> void:
	if mode == "":
		_k = 0.0
	mode = m
	_sel = 0
	note = ""
	visible = true
	player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_c.queue_redraw()


func close() -> void:
	mode = ""
	npc = null
	_pending = ""
	visible = false
	_hits.clear()
	_restore_view()
	if player:
		player.ui_open = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restore_view() -> void:
	if _fov_keep > 0.0 and player:
		player.base_fov = _fov_keep
	_fov_keep = -1.0


## True when this person has more to offer than a line of talk.
func has_business(n: Npc) -> bool:
	return main.trade.is_trader(n.id) or not main.quests.options(n.id).is_empty()


func open_talk(n: Npc, said: String) -> void:
	npc = n
	line = said
	_pending = ""
	_build_talk()
	_open("talk")


func _build_talk() -> void:
	_opts = main.quests.options(npc.id)
	if main.trade.is_trader(npc.id):
		_opts.append(["Trade", "trade"])
	_opts.append(["Goodbye", "bye"])
	_sel = clampi(_sel, 0, _opts.size() - 1)


func open_trade(n: Npc) -> void:
	npc = n
	if not main.trade.can_trade(n.id):
		line = "I don't deal with your kind. Not after what you've done."
		_build_talk()
		_open("talk")
		return
	_side = 0
	_open("trade")


func open_craft() -> void:
	npc = null
	_open("craft")


func open_quests() -> void:
	npc = null
	_open("quests")


func _sellable() -> Array:
	var out := []
	var ids: Array = player.inv.items.keys()
	ids.sort()
	for id in ids:
		var it := Items.get_item(str(id))
		if str(id) == "coin" or it.has("key") or it.has("quest"):
			continue
		out.append(str(id))
	return out


func _rows() -> int:
	match mode:
		"talk":
			return 2 if _pending != "" else _opts.size()
		"trade":
			return main.trade.offers(npc.id).size() if _side == 0 else _sellable().size()
		"craft":
			return Recipes.LIST.size()
		"quests":
			return _quest_ids().size()
	return 0


func _quest_ids() -> Array:
	var out: Array = main.quests.active()
	for id in Quests.DEFS:
		if main.quests.status(id) == "done":
			out.append(id)
	return out


func typing() -> bool:
	return mode == "talk" and _shown < line.length()


func _process(delta: float) -> void:
	if mode == "":
		return
	_time += delta
	_k = move_toward(_k, 1.0, delta * 4.5)
	# talking: the view turns to the person and closes in a little, like a film
	if mode == "talk" and is_instance_valid(npc) and player.vehicle == null:
		if _fov_keep < 0.0:
			_fov_keep = player.base_fov
		player.base_fov = lerpf(player.base_fov, _fov_keep * 0.8, minf(delta * 3.0, 1.0))
		var face := npc.global_position + Vector3(0, 1.58, 0)
		var to := face - player.camera.global_position
		var dist := to.length()
		to.y = 0.0
		if to.length() > 0.2:
			var right := to.normalized().cross(Vector3.UP)
			player.face_toward(face + right * 0.2 * dist - Vector3(0, 0.1 * dist, 0), delta, 4.0)
	elif _fov_keep > 0.0:
		_restore_view()
	if line != _typed:
		_typed = line
		_shown = 0.0
	if _shown < line.length():
		var before := int(_shown)
		_shown = minf(_shown + delta * 62.0, float(line.length()))
		# a soft tick now and then while the words come out
		if int(_shown) / 5 != before / 5 and line[mini(int(_shown), line.length() - 1)] != " ":
			_tick += 1
			Sfx.play_flat(self, "click", -27.0, randf_range(1.6, 2.1))
	_c.queue_redraw()


func _input(event: InputEvent) -> void:
	if mode == "":
		if event.is_action_pressed("quests") and player and not player.ui_open:
			open_quests()
			get_viewport().set_input_as_handled()
		return
	# the mouse: point to choose, click to say / buy / make, wheel to scroll
	if event is InputEventMouseMotion:
		_point(_c.get_local_mouse_position())
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_sel = clampi(_sel + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(_rows() - 1, 0))
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if typing():
				_shown = line.length()
			elif _point(_c.get_local_mouse_position()):
				confirm()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_back()
		_c.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory") or (mode == "quests" and event.is_action_pressed("quests")):
		_back()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("move_back") or event.is_action_pressed("next_weapon"):
		step = 1
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("prev_weapon"):
		step = -1
	var pick := -1
	if event is InputEventKey and event.pressed and not event.echo and mode == "talk":
		var kc := (event as InputEventKey).keycode
		if kc >= KEY_1 and kc <= KEY_9:
			pick = kc - KEY_1
	if pick >= 0 and pick < _rows():
		_sel = pick
		if typing():
			_shown = line.length()
		confirm()
	elif step != 0:
		_sel = clampi(_sel + step, 0, maxi(_rows() - 1, 0))
		note = ""
	elif mode == "trade" and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		_side = 0 if event.is_action_pressed("move_left") else 1
		_sel = 0
		note = ""
	elif event.is_action_pressed("interact"):
		if typing():
			_shown = line.length()      # first press: show the whole line
		else:
			confirm()
	else:
		return
	_c.queue_redraw()
	get_viewport().set_input_as_handled()


## Esc: out of the trade back into the talk, otherwise close.
func _back() -> void:
	if mode == "trade" and npc:
		var n := npc
		line = "Anything else?"
		_build_talk()
		npc = n
		_open("talk")
	else:
		close()


## Moves the choice to the row under the mouse. True when there is one.
func _point(at: Vector2) -> bool:
	for h in _hits:
		if (h["r"] as Rect2).has_point(at):
			if mode == "trade" and int(h["side"]) != _side:
				_side = int(h["side"])
				note = ""
			if _sel != int(h["i"]):
				_sel = int(h["i"])
				note = "" if mode != "talk" else note
			_c.queue_redraw()
			return true
	return false


## E on the chosen row. Also called by the tests.
func confirm() -> void:
	match mode:
		"talk":
			if _pending != "":
				if _sel == 0:
					line = main.quests.act("offer:" + _pending, npc.id)
				else:
					line = "Think about it."
				_pending = ""
				_sel = 0
				_build_talk()
				return
			var act := str(_opts[_sel][1])
			if act == "bye":
				close()
			elif act == "trade":
				open_trade(npc)
			elif act.begins_with("offer:"):
				_pending = act.trim_prefix("offer:")
				line = main.quests.offer_text(_pending)
				_sel = 0
			else:
				line = main.quests.act(act, npc.id)
				Sfx.play(main, "click", player.global_position, -8.0, 1.2)
				_build_talk()
		"trade":
			if _side == 0:
				var offers: Array = main.trade.offers(npc.id)
				if _sel < offers.size():
					note = main.trade.buy(npc.id, str(offers[_sel][0]), player.inv)
					if note == "":
						note = "Bought " + Items.name_of(str(offers[_sel][0])) + "."
						Sfx.play(main, "click", player.global_position, -8.0, 1.5)
			else:
				var mine := _sellable()
				if _sel < mine.size():
					note = main.trade.sell(npc.id, mine[_sel], player.inv)
					if note == "":
						note = "Sold " + Items.name_of(mine[_sel]) + "."
						Sfx.play(main, "click", player.global_position, -8.0, 1.1)
			_sel = clampi(_sel, 0, maxi(_rows() - 1, 0))
		"craft":
			if Recipes.make(_sel, player.inv):
				note = "Made %d × %s." % [int(Recipes.LIST[_sel][1]), Items.name_of(str(Recipes.LIST[_sel][0]))]
				Sfx.play(main, "click", player.global_position, -6.0, 0.8)
			else:
				note = "You lack the parts."


# ---------------------------------------------------------------- drawing

func _t(pos: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_c.draw_string(_font, pos + Vector2(0, 1.5), text, align, width, size, Color(0, 0, 0, col.a * 0.55))
	_c.draw_string(_font, pos, text, align, width, size, col)


func _tw(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Word wrap by hand, so typed-out words never jump from one line to the next.
func _wrap(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var trial := word if cur == "" else cur + " " + word
			if cur != "" and _tw(trial, size) > width:
				out.append(cur)
				cur = word
			else:
				cur = trial
		out.append(cur)
	return out


## A vertical fade between two colours.
func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	_c.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## A sideways fade (the glow behind a chosen row).
func _hgrad(r: Rect2, left: Color, right: Color) -> void:
	_c.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([left, right, right, left]))


func _plate(r: Rect2, col: Color, border := Color(0, 0, 0, 0), radius := 6) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	_c.draw_style_box(sb, r)


## The panel every screen here is built from: a soft shadow, a dark body that is a little
## lighter at the top, a thin coloured line along the top edge and corner ticks.
func _panel(r: Rect2, accent: Color, lit := true) -> void:
	for i in 4:
		var g := 4.0 + i * 5.0
		_plate(r.grow(g), Color(0, 0, 0, 0.11), Color(0, 0, 0, 0), 10 + i * 4)
	_plate(r, Color(0.028, 0.04, 0.068, 0.95), Color(1, 1, 1, 0.09 if lit else 0.05), 8)
	_grad(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, minf(90.0, r.size.y * 0.4))), Color(0.12, 0.17, 0.26, 0.45), Color(0.12, 0.17, 0.26, 0.0))
	_c.draw_rect(Rect2(r.position + Vector2(10, 0), Vector2(r.size.x - 20, 2)), Color(accent.r, accent.g, accent.b, 0.85 if lit else 0.3))
	var tk := Color(1, 1, 1, 0.28)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var cp: Vector2 = corner
		var sx := 1.0 if cp.x == r.position.x else -1.0
		var sy := 1.0 if cp.y == r.position.y else -1.0
		_c.draw_line(cp + Vector2(sx * 5, sy * 5), cp + Vector2(sx * 15, sy * 5), tk, 1.0)
		_c.draw_line(cp + Vector2(sx * 5, sy * 5), cp + Vector2(sx * 5, sy * 15), tk, 1.0)


func _row(r: Rect2, chosen: bool, accent := GOLD, chevron := true) -> void:
	if chosen:
		var pulse := 0.85 + 0.15 * sin(_time * 5.0)
		_hgrad(r, Color(accent.r, accent.g, accent.b, 0.26 * pulse), Color(accent.r, accent.g, accent.b, 0.0))
		_c.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), accent)
		if chevron:
			_t(Vector2(r.end.x - 26, r.position.y + r.size.y * 0.5 + 7), "›", 22, Color(accent.r, accent.g, accent.b, pulse))


func _keycap(pos: Vector2, key: String, lit := true) -> float:
	var w := maxf(24.0, _tw(key, 13) + 14.0)
	_plate(Rect2(pos, Vector2(w, 24)), Color(0.88, 0.92, 1.0, 0.92 if lit else 0.35), Color(0, 0, 0, 0), 4)
	_plate(Rect2(pos + Vector2(0, 20), Vector2(w, 4)), Color(0.45, 0.5, 0.6, 0.92 if lit else 0.35), Color(0, 0, 0, 0), 2)
	_c.draw_string(_font, pos + Vector2(0, 16.5), key, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.04, 0.06, 0.1))
	return w


## The key hints along the bottom: [["W","S"], "choose"], ...
func _hints(y: float, width: float, list: Array) -> void:
	var total := 0.0
	for h in list:
		for k in h[0]:
			total += maxf(24.0, _tw(str(k), 13) + 14.0) + 4.0
		total += _tw(str(h[1]), 14) + 30.0
	var x := (width - total) * 0.5
	for h in list:
		for k in h[0]:
			x += _keycap(Vector2(x, y - 17), str(k)) + 4.0
		_t(Vector2(x + 4, y), str(h[1]), 14, DIM)
		x += _tw(str(h[1]), 14) + 30.0


func _chip(pos: Vector2, text: String, col: Color) -> float:
	var w := _tw(text, 11) + 16.0
	_plate(Rect2(pos, Vector2(w, 19)), Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.9), Color(col.r, col.g, col.b, 0.75), 3)
	_c.draw_string(_font, pos + Vector2(8, 13.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	return w


func _coins(pos: Vector2) -> void:
	_c.draw_circle(pos + Vector2(8, -6), 9.0, Color(0.55, 0.38, 0.1))
	_c.draw_circle(pos + Vector2(8, -7), 8.0, GOLD)
	_c.draw_circle(pos + Vector2(8, -7), 5.0, Color(0.78, 0.58, 0.18))
	_t(pos + Vector2(24, 0), "%d Kronen" % player.inv.count("coin"), 18, GOLD)


func _icon(id: String, c: Vector2, s: float) -> void:
	if player.screen:
		player.screen.icon_on(_c, id, c, s)


func _standing(pos: Vector2, f: String, w: float) -> void:
	var fa: Factions = main.factions
	var d: Dictionary = Factions.DEFS[f]
	var col: Color = d["col"]
	_t(pos, str(d["name"]), 15, INK)
	_t(pos, fa.tier_name(f), 13, col, HORIZONTAL_ALIGNMENT_RIGHT, w)
	var y := pos.y + 9.0
	_plate(Rect2(pos.x, y, w, 6), Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 3)
	var r := int(fa.rep[f])
	var mid := pos.x + w * 0.5
	if r >= 0:
		_plate(Rect2(mid, y, maxf(w * 0.5 * r / 100.0, 1.0), 6), col, Color(0, 0, 0, 0), 3)
	else:
		_plate(Rect2(mid + w * 0.5 * r / 100.0, y, -w * 0.5 * r / 100.0, 6), RED, Color(0, 0, 0, 0), 3)
	_c.draw_rect(Rect2(mid - 1, y - 3, 2, 12), INK)


func _paint() -> void:
	_hits.clear()
	if mode == "":
		return
	var size := _c.size
	if mode == "talk":
		_paint_talk(size)
		return
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.03, 0.62 * _k))
	_grad(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.3)), Color(0, 0, 0, 0.5 * _k), Color(0, 0, 0, 0))
	_grad(Rect2(Vector2(0, size.y * 0.7), Vector2(size.x, size.y * 0.3)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55 * _k))
	var slide := (1.0 - _k) * 24.0
	_c.draw_set_transform(Vector2(0, slide), 0.0, Vector2.ONE)
	match mode:
		"trade":
			_paint_trade(size)
		"craft":
			_paint_craft(size)
		"quests":
			_paint_quests(size)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A conversation, framed like a film.
func _paint_talk(size: Vector2) -> void:
	var k := ease(_k, 0.4)
	var bar := size.y * 0.085 * k
	# the picture darkens from below so the words stand out; the face stays clear
	_grad(Rect2(0, size.y * 0.38, size.x, size.y * 0.62), Color(0.0, 0.01, 0.03, 0.0), Color(0.0, 0.01, 0.03, 0.82 * k))
	_c.draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.94))
	_c.draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.94))
	var w := minf(960.0, size.x - 80.0)
	var labels: Array = [["Accept the job", "accept"], ["Not now", "decline"]] if _pending != "" else _opts
	var lines := _wrap(line, w - 76.0, 19)
	var h := 74.0 + lines.size() * 28.0 + 22.0 + labels.size() * 42.0 + 16.0
	var x := (size.x - w) * 0.5
	var y := size.y - bar - 30.0 - h + (1.0 - k) * 50.0
	var f := str(npc.faction)
	var fcol: Color = Factions.DEFS[f]["col"] if Factions.DEFS.has(f) else GOLD
	_panel(Rect2(x, y, w, h), fcol)
	# the name plate sits on the top edge, with a badge in the colours of their people
	var nm := npc.npc_name.to_upper()
	var nw := _tw(nm, 22) + 86.0
	var plate := Rect2(x + 26, y - 24, nw, 46)
	_plate(plate.grow(3), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 9)
	_plate(plate, Color(0.06, 0.08, 0.13, 0.98), Color(fcol.r, fcol.g, fcol.b, 0.6), 7)
	var bc := plate.position + Vector2(25, 23)
	_c.draw_circle(bc, 15.0, Color(fcol.r * 0.35, fcol.g * 0.35, fcol.b * 0.35))
	_c.draw_arc(bc, 15.0, 0.0, TAU, 32, fcol, 2.0, true)
	var initials := ""
	for part in npc.npc_name.split(" "):
		if part != "" and initials.length() < 2:
			initials += part[0].to_upper()
	_c.draw_string(_font, bc + Vector2(-15, 5), initials, HORIZONTAL_ALIGNMENT_CENTER, 30, 13, INK)
	_t(plate.position + Vector2(50, 31), nm, 22, GOLD)
	if Factions.DEFS.has(f):
		var stand := "%s  ·  %s" % [Factions.DEFS[f]["name"], main.factions.tier_name(f)]
		_c.draw_circle(Vector2(x + w - 34 - _tw(stand, 13) - 12, y + 26), 4.0, fcol)
		_t(Vector2(x, y + 31), stand, 13, Color(fcol.r, fcol.g, fcol.b, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, w - 34)
	# what they say, typed out
	var left := int(_shown)
	var ty := y + 66.0
	for ln in lines:
		var part := ln.substr(0, clampi(left, 0, ln.length()))
		left -= ln.length() + 1
		_t(Vector2(x + 38, ty + 14), part, 19, INK)
		ty += 28.0
	# the answers
	var oy := ty + 18.0
	_c.draw_line(Vector2(x + 30, oy - 8), Vector2(x + w - 30, oy - 8), Color(1, 1, 1, 0.07), 1.0)
	var fade := 0.35 if typing() else 1.0
	for i in labels.size():
		var r := Rect2(x + 22, oy, w - 44, 36)
		var act := str(labels[i][1])
		var chosen := i == _sel and not typing()
		var accent := GOLD
		if act == "bye" or act == "decline":
			accent = Color(0.7, 0.75, 0.85)
		_row(r, chosen, accent)
		_keycap(Vector2(r.position.x + 14, r.position.y + 6), str(i + 1), chosen)
		var col := INK if chosen else Color(INK.r, INK.g, INK.b, 0.62 * fade)
		if act.begins_with("offer:") or act == "accept":
			col = GOLD if chosen else Color(GOLD.r, GOLD.g, GOLD.b, 0.75 * fade)
		_t(Vector2(r.position.x + 52, r.position.y + 24), str(labels[i][0]), 17, col, HORIZONTAL_ALIGNMENT_LEFT, w - 220)
		var cx := r.end.x - 44.0
		if act.begins_with("offer:"):
			cx -= _tw("NEW JOB", 11) + 16.0
			_chip(Vector2(cx, r.position.y + 9), "NEW JOB", GOLD)
		elif act == "trade":
			cx -= _tw("TRADE", 11) + 16.0
			_chip(Vector2(cx, r.position.y + 9), "TRADE", Color(0.55, 0.85, 1.0))
		elif act != "bye" and act != "decline" and act != "accept":
			cx -= _tw("JOB", 11) + 16.0
			_chip(Vector2(cx, r.position.y + 9), "JOB", GREEN)
		_hits.append({"r": r, "i": i, "side": 0})
		oy += 42.0
	_hints(size.y - bar * 0.5 + 6.0, size.x, [[["W", "S"], "choose"], [["1-%d" % labels.size()], "answer"], [["E"], "say  /  skip"], [["Esc"], "leave"]])


func _item_line(x: float, y: float, w: float, id: String, count: int, price: int, chosen: bool, locked := "") -> void:
	var r := Rect2(x - 8, y - 27, w + 16, 40)
	var tier := Items.tier(id)
	var tc: Color = TIER_COL[tier]
	_row(r, chosen, tc if tier > 0 else GOLD, false)
	_plate(Rect2(x + 2, y - 25, 36, 36), Color(tc.r * 0.18, tc.g * 0.18, tc.b * 0.18, 0.9), Color(tc.r, tc.g, tc.b, 0.55), 4)
	_icon(id, Vector2(x + 20, y - 7), 13.5)
	var col := INK if chosen else Color(INK.r, INK.g, INK.b, 0.78)
	if locked != "":
		col = Color(INK.r, INK.g, INK.b, 0.35)
	_t(Vector2(x + 52, y), Items.name_of(id), 16, col, HORIZONTAL_ALIGNMENT_LEFT, w - 226)
	_t(Vector2(x + w - 190, y), "×%d" % count, 13, DIM)
	if locked != "":
		_t(Vector2(x, y), locked, 13, RED, HORIZONTAL_ALIGNMENT_RIGHT, w - 22)
	else:
		_t(Vector2(x, y), "%d Kr" % price if price > 0 else "—", 16, GOLD if price > 0 else DIM, HORIZONTAL_ALIGNMENT_RIGHT, w - 22)


func _paint_trade(size: Vector2) -> void:
	var tr: Trade = main.trade
	var x0 := maxf((size.x - 1180.0) * 0.5, 30.0)
	var top := maxf((size.y - 780.0) * 0.5, 24.0)
	var cw := minf(540.0, (size.x - x0 * 2.0 - 60.0) * 0.5)
	var f := tr.faction_of(npc.id)
	var fcol: Color = Factions.DEFS[f]["col"]
	_c.draw_rect(Rect2(x0, top + 6, 4, 50), fcol)
	_t(Vector2(x0 + 18, top + 32), str(Trade.TRADERS[npc.id]["title"]).to_upper(), 28, GOLD)
	_t(Vector2(x0 + 18, top + 56), "%s  ·  %s  ·  new stock in %d min" % [Factions.DEFS[f]["name"], main.factions.tier_name(f), int(ceil((Trade.RESTOCK - fmod(tr.clock, Trade.RESTOCK)) / 60.0))], 14, DIM)
	_coins(Vector2(x0 + cw * 2.0 + 60.0 - 150.0, top + 34))
	var chosen_id := ""
	var rows := 12
	for side in 2:
		var x := x0 + side * (cw + 60.0)
		var y := top + 128.0
		var pr := Rect2(x - 16, top + 76, cw + 32, 560)
		_panel(pr, GOLD if side == _side else Color(0.5, 0.6, 0.75), side == _side)
		var head := "FOR SALE" if side == 0 else "YOUR PACK"
		_t(Vector2(x, top + 104), head, 14, GOLD if side == _side else DIM)
		_hits.append({"r": Rect2(x - 16, top + 76, cw + 32, 40), "i": 0, "side": side})
		if side == 0:
			var offers: Array = tr.offers(npc.id)
			var first := clampi(_sel - rows + 3, 0, maxi(offers.size() - rows, 0)) if _side == 0 else 0
			for q in range(first, mini(first + rows, offers.size())):
				var o: Array = offers[q]
				_item_line(x, y + 20, cw, str(o[0]), int(o[1]), int(o[2]) * (mini(10, int(o[1])) if Items.get_item(str(o[0])).has("ammo") else 1), _side == 0 and q == _sel, str(o[3]))
				_hits.append({"r": Rect2(x - 8, y - 7, cw + 16, 40), "i": q, "side": 0})
				if _side == 0 and q == _sel:
					chosen_id = str(o[0])
				y += 42.0
			if offers.is_empty():
				_t(Vector2(x, y + 20), "Nothing left. Come back after the next delivery.", 14, DIM)
		else:
			var mine := _sellable()
			var first := clampi(_sel - rows + 3, 0, maxi(mine.size() - rows, 0)) if _side == 1 else 0
			for q in range(first, mini(first + rows, mine.size())):
				var id: String = mine[q]
				_item_line(x, y + 20, cw, id, player.inv.count(id), tr.sell_quote(npc.id, id, player.inv), _side == 1 and q == _sel)
				_hits.append({"r": Rect2(x - 8, y - 7, cw + 16, 40), "i": q, "side": 1})
				if _side == 1 and q == _sel:
					chosen_id = id
				y += 42.0
			if mine.is_empty():
				_t(Vector2(x, y + 20), "You carry nothing to sell.", 14, DIM)
	# what the chosen thing is
	var by := top + 662.0
	var dr := Rect2(x0 - 16, by, cw * 2.0 + 92.0, 84)
	_panel(dr, TIER_COL[Items.tier(chosen_id)] if chosen_id != "" else DIM, false)
	if chosen_id != "":
		var tier := Items.tier(chosen_id)
		var tc: Color = TIER_COL[tier]
		_plate(Rect2(x0 - 4, by + 7, 70, 70), Color(tc.r * 0.18, tc.g * 0.18, tc.b * 0.18, 0.9), Color(tc.r, tc.g, tc.b, 0.6), 6)
		_icon(chosen_id, Vector2(x0 + 31, by + 42), 25.0)
		_t(Vector2(x0 + 84, by + 36), Items.name_of(chosen_id), 19, INK)
		_chip(Vector2(x0 + 94 + _tw(Items.name_of(chosen_id), 19), by + 21), TIER_NAME[tier].to_upper(), tc)
		var info := str(Items.get_item(chosen_id).get("info", ""))
		_t(Vector2(x0 + 84, by + 60), info if info != "" else "%.1f kg" % Items.num(chosen_id, "w"), 14, DIM, HORIZONTAL_ALIGNMENT_LEFT, cw * 2.0 - 60.0)
	if note != "":
		var good := note.begins_with("Bought") or note.begins_with("Sold")
		_t(Vector2(x0, by + 36), note, 15, GREEN if good else RED, HORIZONTAL_ALIGNMENT_RIGHT, cw * 2.0 + 60.0)
	_hints(size.y - 24, size.x, [[["W", "S"], "choose"], [["A", "D"], "their goods / your pack"], [["E"], "buy" if _side == 0 else "sell"], [["Esc"], "back"]])


func _paint_craft(size: Vector2) -> void:
	var x0 := maxf((size.x - 940.0) * 0.5, 30.0)
	var top := maxf((size.y - 720.0) * 0.5, 24.0)
	_c.draw_rect(Rect2(x0, top + 6, 4, 50), GOLD)
	_t(Vector2(x0 + 18, top + 32), "WORKBENCH", 28, GOLD)
	_t(Vector2(x0 + 18, top + 56), "Make what you need from what you carry.", 14, DIM)
	_panel(Rect2(x0 - 16, top + 76, 972, 40.0 * Recipes.LIST.size() + 34), GOLD)
	var y := top + 122.0
	for i in Recipes.LIST.size():
		var rc: Array = Recipes.LIST[i]
		var ok := Recipes.can_make(i, player.inv)
		var r := Rect2(x0 - 8, y - 28, 956, 40)
		_row(r, i == _sel, GOLD if ok else Color(0.6, 0.65, 0.75), false)
		_hits.append({"r": r, "i": i, "side": 0})
		var id := str(rc[0])
		var tc: Color = TIER_COL[Items.tier(id)]
		_plate(Rect2(x0 + 2, y - 26, 36, 36), Color(tc.r * 0.18, tc.g * 0.18, tc.b * 0.18, 0.9), Color(tc.r, tc.g, tc.b, 0.55), 4)
		_icon(id, Vector2(x0 + 20, y - 8), 13.5)
		_t(Vector2(x0 + 52, y), "%s%s" % [Items.name_of(id), " ×%d" % int(rc[1]) if int(rc[1]) > 1 else ""], 16, INK if ok else Color(INK.r, INK.g, INK.b, 0.45))
		var x := x0 + 340.0
		var need: Dictionary = rc[2]
		for n in need:
			var have := player.inv.count(str(n))
			var part := "%s %d/%d" % [Items.name_of(str(n)), mini(have, 999), int(need[n])]
			x += _chip(Vector2(x, y - 15), part, GREEN if have >= int(need[n]) else RED) + 6.0
		y += 40.0
	if note != "":
		_t(Vector2(x0, y + 26), note, 15, GREEN if note.begins_with("Made") else RED)
	_hints(size.y - 24, size.x, [[["W", "S"], "choose"], [["E"], "make"], [["Esc"], "close"]])


func _paint_quests(size: Vector2) -> void:
	var qs: Quests = main.quests
	var x0 := maxf((size.x - 1180.0) * 0.5, 30.0)
	var top := maxf((size.y - 760.0) * 0.5, 24.0)
	_c.draw_rect(Rect2(x0, top + 6, 4, 50), GOLD)
	_t(Vector2(x0 + 18, top + 32), "JOBS", 28, GOLD)
	_t(Vector2(x0 + 18, top + 56), "%d open  ·  %d of %d done" % [qs.active().size(), qs.done_count(), qs.mode_count()], 14, DIM)
	_coins(Vector2(x0 + 260, top + 34))
	var ids := _quest_ids()
	_panel(Rect2(x0 - 16, top + 76, 452, 600), GOLD)
	var y := top + 118.0
	var first := clampi(_sel - 9, 0, maxi(ids.size() - 11, 0))
	for i in range(first, mini(first + 11, ids.size())):
		var id: String = ids[i]
		var q: Dictionary = Quests.DEFS[id]
		var done := qs.status(id) == "done"
		var r := Rect2(x0 - 8, y - 24, 436, 48)
		_row(r, i == _sel, GREEN if done else GOLD)
		_hits.append({"r": r, "i": i, "side": 0})
		_c.draw_circle(Vector2(x0 + 12, y - 1), 6.0, GREEN if done else Color(GOLD.r, GOLD.g, GOLD.b, 0.9))
		if done:
			_c.draw_polyline(PackedVector2Array([Vector2(x0 + 9, y - 1), Vector2(x0 + 11.5, y + 1.5), Vector2(x0 + 15.5, y - 3.5)]), Color(0.05, 0.1, 0.05), 1.6, true)
		_t(Vector2(x0 + 28, y - 2), str(q["title"]), 16, (INK if i == _sel else Color(INK.r, INK.g, INK.b, 0.72)) if not done else Color(INK.r, INK.g, INK.b, 0.42))
		_t(Vector2(x0 + 28, y + 16), "%s%s" % [str(q["type"]).to_upper(), "  ·  DONE" if done else ""], 11, GREEN if done else GOLD)
		y += 52.0
	if ids.is_empty():
		_c.draw_multiline_string(_font, Vector2(x0 + 6, y), "No jobs yet. People in the village and in Eisgrund have work for someone who gets around.", HORIZONTAL_ALIGNMENT_LEFT, 400, 15, 4, DIM)
	# details of the chosen job
	var dx := x0 + 480.0
	var dw := minf(700.0, size.x - dx - 30.0)
	_panel(Rect2(dx - 20, top + 76, dw + 40, 360), GOLD)
	if _sel < ids.size():
		var id: String = ids[_sel]
		var q: Dictionary = Quests.DEFS[id]
		_t(Vector2(dx, top + 114), str(q["title"]), 23, INK)
		var giver := str(q["giver"])
		for n in main.people.list:
			if n.id == giver:
				giver = n.npc_name
		_t(Vector2(dx, top + 140), "%s  ·  from %s" % [str(q["type"]).to_upper(), giver], 12, GOLD)
		_c.draw_line(Vector2(dx, top + 156), Vector2(dx + dw, top + 156), Color(1, 1, 1, 0.07), 1.0)
		_c.draw_multiline_string(_font, Vector2(dx, top + 184), "“%s”" % str(q["offer"]), HORIZONTAL_ALIGNMENT_LEFT, dw, 15, 6, Color(INK.r, INK.g, INK.b, 0.75))
		if qs.status(id) == "active":
			_plate(Rect2(dx - 6, top + 318, dw + 12, 100), Color(GOLD.r, GOLD.g, GOLD.b, 0.06), Color(GOLD.r, GOLD.g, GOLD.b, 0.25), 6)
			_t(Vector2(dx + 8, top + 340), "NEXT", 11, GOLD)
			_c.draw_multiline_string(_font, Vector2(dx + 8, top + 364), qs.objective(id), HORIZONTAL_ALIGNMENT_LEFT, dw - 16, 16, 3, INK)
		else:
			var how := qs.outcome(id)
			var txt := "Done."
			match how:
				"village":
					txt = "Done. The antibiotics went to the village."
				"eisgrund":
					txt = "Done. The antibiotics went to Eisgrund."
				"sold":
					txt = "Done. You sold the antibiotics to Pavel."
			_t(Vector2(dx, top + 352), txt, 16, GREEN)
	# standing
	var sy := top + 470.0
	_panel(Rect2(dx - 20, sy - 14, dw + 40, 220), Color(0.55, 0.75, 1.0), false)
	_t(Vector2(dx, sy + 14), "STANDING", 13, GOLD)
	var i2 := 0
	for f in Factions.DEFS:
		_standing(Vector2(dx + (i2 % 2) * (dw * 0.5 + 10.0), sy + 50.0 + (i2 / 2) * 52.0), str(f), dw * 0.5 - 20.0)
		i2 += 1
	_hints(size.y - 24, size.x, [[["W", "S"], "choose"], [["L"], "close"]])
