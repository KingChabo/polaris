class_name Hud
extends CanvasLayer
## The in-game display, drawn by hand so it stays small and clean:
## compass, vitals with icons, ammo counter, crosshair, hit and damage markers,
## the enemy you are fighting, and a speedometer while driving.

const INK := Color(0.93, 0.96, 1.0)
const DIM := Color(0.93, 0.96, 1.0, 0.55)
const PLATE := Color(0.03, 0.05, 0.09, 0.55)
const RED := Color(0.92, 0.22, 0.2)
const GOLD := Color(1.0, 0.8, 0.35)

var player: Player
var mood: CombatMood
var quests: Quests
var factions: Factions
var bosses: Bosses

var _c: Control
var _font: Font
var _msg := ""
var _msg_time := 0.0
var _ban_kicker := ""
var _ban_title := ""
var _ban_t := 0.0
var _scope: Control
var _vignette: Texture2D
var _health_lag := 100.0
var _stam_show := 0.0
var _slots_t := 0.0
var _last_held := ""
var _t := 0.0
var _boss_ref: Node
var _boss_phase := 0
var _phase_t := 0.0
var _kill_t := 0.0
var _kill_word := ""
var _caps: Array = []     # [text, seconds left] for sound subtitles


class Canvas extends Control:
	var hud: Hud
	func _draw() -> void:
		hud._paint()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_vignette = _make_vignette()
	_scope = _make_scope()
	var c := Canvas.new()
	c.hud = self
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_c = c
	if player:
		player.message.connect(say)


## Big line across the top when you find a place.
func banner(kicker: String, title: String) -> void:
	_ban_kicker = kicker
	_ban_title = title
	_ban_t = 5.5


func caption(text: String) -> void:
	for c in _caps:
		if c[0] == text:
			c[1] = 2.6
			return
	_caps.append([text, 2.6])
	if _caps.size() > 3:
		_caps.pop_front()


func say(text: String) -> void:
	_msg = text
	_msg_time = 5.0


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	_msg_time -= delta
	for c in _caps:
		c[1] = float(c[1]) - delta
	_caps = _caps.filter(func(c): return float(c[1]) > 0.0)
	_ban_t = maxf(_ban_t - delta, 0.0)
	var st := player.stats
	_health_lag = maxf(st.health, move_toward(_health_lag, st.health, delta * 22.0))
	_stam_show = 2.5 if st.stamina < 99.0 else _stam_show - delta
	if player.arms.held != _last_held:
		_last_held = player.arms.held
		_slots_t = 2.6
	_slots_t -= delta
	_scope.visible = player.arms.scoped
	var post: Node = player.get_parent().get("post")
	if post:
		post.pain = clampf((30.0 - st.health) / 30.0, 0.0, 1.0)
	# kills: a word under the crosshair
	_kill_t = maxf(_kill_t - delta, 0.0)
	if player.arms.hit_flash > 0.4 and player.hit_kind in ["kill", "headkill"] and _kill_t < 0.9:
		_kill_word = "HEADSHOT" if player.hit_kind == "headkill" else "DOWN"
		_kill_t = 1.2
	# a boss changing gear: the world stops for a heartbeat and the bar shouts it
	_phase_t = maxf(_phase_t - delta, 0.0)
	var boss: Node = bosses.active() if bosses else null
	if boss != _boss_ref:
		_boss_ref = boss
		_boss_phase = int(boss.get("phase")) if boss else 0
	elif boss and int(boss.get("phase")) > _boss_phase:
		_boss_phase = int(boss.get("phase"))
		_phase_t = 2.6
		Fx.hitstop(get_tree(), 0.22)
		player.shake(1.1)
		player.rumble(0.8, 0.9, 0.5)
		Sfx.play_flat(self, "shot_boom", -4.0, 0.35)
		if post:
			post.flash(Color(0.75, 0.1, 0.05), 0.3)
	_c.queue_redraw()


# ------------------------------------------------------------ drawing helpers
func _text(pos: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	_c.draw_string_outline(_font, pos, text, align, width, size, 4, Color(0, 0, 0, 0.7 * col.a))
	_c.draw_string(_font, pos, text, align, width, size, col)


func _plate(rect: Rect2, col: Color, radius := 5.0, border := Color(0, 0, 0, 0)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	sb.anti_aliasing = true
	_c.draw_style_box(sb, rect)


## A slim bar with a slanted end, the look of the whole HUD.
func _bar(pos: Vector2, size: Vector2, frac: float, col: Color, lag := -1.0, notches := 0) -> void:
	var skew := size.y * 0.6
	var back := PackedVector2Array([pos + Vector2(skew, 0), pos + Vector2(size.x + skew, 0), pos + size, pos + Vector2(0, size.y)])
	_c.draw_colored_polygon(back, Color(0, 0, 0, 0.55))
	if lag > frac:
		var lw := size.x * clampf(lag, 0.0, 1.0)
		_c.draw_colored_polygon(PackedVector2Array([pos + Vector2(skew, 0), pos + Vector2(lw + skew, 0), pos + Vector2(lw, size.y), pos + Vector2(0, size.y)]), Color(1, 1, 1, 0.75))
	var w := size.x * clampf(frac, 0.0, 1.0)
	if w > 0.5:
		_c.draw_colored_polygon(PackedVector2Array([pos + Vector2(skew, 0), pos + Vector2(w + skew, 0), pos + Vector2(w, size.y), pos + Vector2(0, size.y)]), col)
		_c.draw_line(pos + Vector2(skew, 1), pos + Vector2(w + skew, 1), Color(1, 1, 1, 0.35), 1.0)
	for i in range(1, notches):
		var x := size.x * i / notches
		_c.draw_line(pos + Vector2(x + skew, 0), pos + Vector2(x, size.y), Color(0, 0, 0, 0.6), 1.5)
	_c.draw_polyline(PackedVector2Array([back[0], back[1], back[2], back[3], back[0]]), Color(1, 1, 1, 0.22), 1.0, true)


func _icon(kind: String, at: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	match kind:
		"heart":
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(at + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * s / 34.0)
		"bolt":
			for p in [Vector2(2, -9), Vector2(-6, 1), Vector2(-1, 1), Vector2(-3, 9), Vector2(6, -2), Vector2(1, -2)]:
				pts.append(at + (p as Vector2) * s / 18.0)
		"flame":
			for p in [Vector2(0, -10), Vector2(5, -3), Vector2(7, 3), Vector2(4, 8), Vector2(0, 10), Vector2(-4, 8), Vector2(-7, 3), Vector2(-4, -1), Vector2(-2, 2)]:
				pts.append(at + (p as Vector2) * s / 20.0)
		"drop":
			for p in [Vector2(0, -10), Vector2(6, 1), Vector2(6, 5), Vector2(3, 9), Vector2(-3, 9), Vector2(-6, 5), Vector2(-6, 1)]:
				pts.append(at + (p as Vector2) * s / 20.0)
		"cog":
			for i in 16:
				var a := TAU * i / 16.0
				var r := (9.0 if i % 2 == 0 else 6.0) * s / 18.0
				pts.append(at + Vector2(cos(a), sin(a)) * r)
		"skull":
			for p in [Vector2(-7, -3), Vector2(-5, -8), Vector2(0, -10), Vector2(5, -8), Vector2(7, -3), Vector2(6, 3), Vector2(3, 5), Vector2(3, 9), Vector2(-3, 9), Vector2(-3, 5), Vector2(-6, 3)]:
				pts.append(at + (p as Vector2) * s / 20.0)
	if pts.size() >= 3:
		_c.draw_colored_polygon(pts, col)
	if kind == "snow":
		for i in 3:
			var d := Vector2.from_angle(PI * i / 3.0) * s * 0.5
			_c.draw_line(at - d, at + d, col, 2.0, true)


func _chip(pos: Vector2, text: String, col: Color) -> float:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
	_plate(Rect2(pos, Vector2(w, 20)), Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.8), 3.0, Color(col.r, col.g, col.b, 0.8))
	_c.draw_string(_font, pos + Vector2(8, 14.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	return w + 6.0


func _keycap(pos: Vector2, key: String) -> float:
	var w := maxf(24.0, _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0)
	_plate(Rect2(pos, Vector2(w, 24)), Color(0.9, 0.93, 1.0, 0.92), 4.0)
	_plate(Rect2(pos + Vector2(0, 21), Vector2(w, 3)), Color(0.5, 0.55, 0.65, 0.9), 2.0)
	_c.draw_string(_font, pos + Vector2(0, 17), key, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.05, 0.07, 0.1))
	return w


# ------------------------------------------------------------ the picture
func _paint() -> void:
	if player == null:
		return
	var size := _c.size
	var st := player.stats
	var arms := player.arms
	var mid := size * 0.5
	var fight := mood.level if mood else 0.0

	# --- screen tints: water, cold, pain
	if player.head_under_water:
		_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.12, 0.18, 0.6))
	var cold := clampf((30.0 - st.warmth) / 30.0, 0.0, 1.0)
	if cold > 0.0:
		_c.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(0.65, 0.85, 1.0, cold * 0.75))
	var low := clampf((35.0 - st.health) / 35.0, 0.0, 1.0)
	var pain := maxf(player.hurt_flash, low * (0.45 + 0.25 * sin(_t * 5.0)))
	# the red only at the edges, never a full sheet over what you need to see
	var calm := 0.35 if bool(Settings.get_v("reduced_fx")) else 0.7
	if pain > 0.01:
		_c.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(0.75, 0.0, 0.0, clampf(pain, 0.0, 1.0) * calm))
	if fight > 0.01 and not bool(Settings.get_v("reduced_fx")):
		_c.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(0.5, 0.05, 0.02, fight * 0.22))

	if arms.scoped:
		return   # nothing but the reticle while looking through a scope
	if player.ui_open:
		return   # a screen is open: it has the whole picture

	_paint_compass(size, fight)
	var boss: Enemy = bosses.active() if bosses else null
	if boss:
		_paint_boss(size, boss)
	if boss == null or player.hud_target != boss:
		_paint_target(size)
	_paint_vitals(size, st)
	if player.vehicle:
		_paint_vehicle(size)
	else:
		_paint_weapon(size, arms)
		_paint_crosshair(mid, arms)
	_paint_marks(mid)

	# --- the job you are on, and whose ground you stand on
	var ty := 96.0
	if factions:
		var zf := factions.at(player.global_position)
		if zf != "":
			var zc: Color = Factions.DEFS[zf]["col"]
			var label := "%s  ·  %s" % [str(Factions.DEFS[zf]["name"]).to_upper(), factions.tier_name(zf)]
			var zw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_plate(Rect2(size.x - zw - 54, 22, zw + 34, 26), PLATE, 4.0)
			_c.draw_rect(Rect2(size.x - zw - 46, 29, 4, 12), zc)
			_text(Vector2(size.x - zw - 34, 40), label, 12, Color(zc.r, zc.g, zc.b, 0.95))
	if quests and not player.ui_open:
		var tq: Array = quests.tracked()
		if not tq.is_empty():
			var qw := 330.0
			_text(Vector2(size.x - qw - 20, ty - 26), str(tq[0]).to_upper(), 12, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, qw)
			_c.draw_multiline_string(_font, Vector2(size.x - qw - 20, ty - 6), str(tq[1]), HORIZONTAL_ALIGNMENT_RIGHT, qw, 13, 3, Color(INK.r, INK.g, INK.b, 0.8))

	if quests and not player.ui_open and quests.main.get("jobs") and not quests.main.jobs.current.is_empty():
		var jw := 330.0
		_text(Vector2(size.x - jw - 20, ty - 78), "BOARD JOB", 11, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, jw)
		_text(Vector2(size.x - jw - 200, ty - 62), quests.main.jobs.objective(), 12, Color(INK.r, INK.g, INK.b, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, jw + 180)

	# --- what you are looking at
	if player.prompt != "" and not player.ui_open:
		var tw := _font.get_string_size(player.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var x := mid.x - (tw + 34.0) * 0.5
		_keycap(Vector2(x, mid.y + 44), "E")
		_text(Vector2(x + 34, mid.y + 62), player.prompt, 16, INK)
	if player.climbing:
		_text(Vector2(mid.x - 200, mid.y + 110), "CLIMBING", 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 400)

	# --- a place found: its name under the compass
	if _ban_t > 0.0:
		var ba := clampf(_ban_t, 0.0, 1.0) * clampf((5.5 - _ban_t) * 2.0, 0.0, 1.0)
		var tw2 := _font.get_string_size(_ban_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var by := size.y * 0.2
		_c.draw_line(Vector2(mid.x - tw2 * 0.5 * ba - 30, by + 14), Vector2(mid.x + tw2 * 0.5 * ba + 30, by + 14), Color(GOLD.r, GOLD.g, GOLD.b, 0.8 * ba), 2.0)
		_text(Vector2(0, by - 34), _ban_kicker, 14, Color(GOLD.r, GOLD.g, GOLD.b, ba), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_text(Vector2(0, by), _ban_title, 34, Color(INK.r, INK.g, INK.b, ba), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	# --- messages, low on the screen like subtitles
	if _msg_time > 0.0 and _msg != "":
		var a := clampf(_msg_time, 0.0, 1.0)
		var lines := _msg.split("\n")
		var y := size.y * 0.74
		for line in lines:
			var w := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			_plate(Rect2(mid.x - w * 0.5 - 14, y - 19, w + 28, 28), Color(0.02, 0.03, 0.06, 0.6 * a), 4.0)
			_text(Vector2(mid.x - w * 0.5, y), line, 17, Color(INK.r, INK.g, INK.b, a))
			y += 32.0
	# --- sound subtitles, small and grey under the messages
	var cy := size.y * 0.66
	for c in _caps:
		var ca := clampf(float(c[1]), 0.0, 1.0)
		_text(Vector2(0, cy), str(c[0]), 14, Color(0.85, 0.88, 0.92, ca), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		cy -= 20.0


func _paint_compass(size: Vector2, fight: float) -> void:
	var cx := size.x * 0.5
	var y := 30.0
	var half := 230.0
	var yaw := player.rotation.y if player.vehicle == null or not player.third_person else player.vehicle.global_rotation.y
	var heading := fposmod(-rad_to_deg(yaw), 360.0)    # 0 = north (-Z), 90 = east
	_c.draw_line(Vector2(cx - half, y + 12), Vector2(cx + half, y + 12), Color(1, 1, 1, 0.18), 1.0)
	for deg in range(0, 360, 15):
		var d := fposmod(deg - heading + 180.0, 360.0) - 180.0
		var x := cx + d * 3.4
		if absf(x - cx) > half:
			continue
		var fade := 1.0 - pow(absf(x - cx) / half, 3.0)
		var major := deg % 90 == 0
		_c.draw_line(Vector2(x, y + (2 if major else 7)), Vector2(x, y + 12), Color(1, 1, 1, (0.9 if major else 0.4) * fade), 2.0 if major else 1.0)
		if major:
			var letter: String = ["N", "E", "S", "W"][deg / 90]
			_text(Vector2(x - 20, y - 2), letter, 15, Color(INK.r, INK.g, INK.b, fade) if letter != "N" else Color(1.0, 0.45, 0.4, fade), HORIZONTAL_ALIGNMENT_CENTER, 40)
		elif deg % 45 == 0:
			_text(Vector2(x - 20, y - 1), ["NE", "SE", "SW", "NW"][(deg - 45) / 90], 10, Color(INK.r, INK.g, INK.b, 0.55 * fade), HORIZONTAL_ALIGNMENT_CENTER, 40)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, y + 16), Vector2(cx + 5, y + 16), Vector2(cx, y + 22)]), INK)
	# places you have found: a small diamond, with the name when you face it
	var world := player.get_parent()
	if world and world.get("places"):
		for s in world.places.spots:
			if not s["id"] in world.places.found:
				continue
			var to2: Vector3 = (s["pos"] as Vector3) - player.global_position
			if to2.length() < float(s["r"]) * 0.6:
				continue
			var d2 := fposmod(fposmod(rad_to_deg(atan2(to2.x, -to2.z)), 360.0) - heading + 180.0, 360.0) - 180.0
			var x2 := cx + d2 * 3.4
			if absf(x2 - cx) > half:
				continue
			var f2 := 1.0 - pow(absf(x2 - cx) / half, 3.0)
			_c.draw_colored_polygon(PackedVector2Array([Vector2(x2, y + 15), Vector2(x2 + 4, y + 20), Vector2(x2, y + 25), Vector2(x2 - 4, y + 20)]), Color(GOLD.r, GOLD.g, GOLD.b, 0.9 * f2))
			if absf(d2) < 5.0:
				_text(Vector2(x2 - 150, y + 44), "%s  %d m" % [str(s["name"]), int(to2.length())], 12, Color(GOLD.r, GOLD.g, GOLD.b, f2), HORIZONTAL_ALIGNMENT_CENTER, 300)
	# enemies that are after you show up as red marks
	if mood:
		for e in mood.fighting:
			if not is_instance_valid(e):
				continue
			var to := e.global_position - player.global_position
			var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
			var d := fposmod(bearing - heading + 180.0, 360.0) - 180.0
			var x := clampf(cx + d * 3.4, cx - half, cx + half)
			_c.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y + 24), Vector2(x + 5, y + 24), Vector2(x, y + 15)]), RED)
	if fight > 0.3:
		_icon("skull", Vector2(cx - half - 22, y + 8), 20.0, Color(RED.r, RED.g, RED.b, fight))
		_text(Vector2(cx + half + 12, y + 14), "COMBAT", 12, Color(RED.r, RED.g, RED.b, fight))


## The big bar of a boss fight: name, health, one small bar for every part that can be shot off.
func _paint_boss(size: Vector2, boss: Enemy) -> void:
	var b: Dictionary = boss.call("bar")
	var cx := size.x * 0.5
	var w := 460.0
	var y := 124.0 if _ban_t <= 0.0 else 238.0      # make room while a banner is up
	_plate(Rect2(cx - w * 0.5 - 16, y - 24, w + 32, 62 if (b["pips"] as Array).is_empty() else 74), PLATE, 6.0)
	_text(Vector2(cx - w * 0.5, y - 5), str(b["name"]).to_upper(), 15, GOLD)
	_text(Vector2(cx - w * 0.5, y - 5), "PHASE %d" % int(b["phase"]), 11, DIM, HORIZONTAL_ALIGNMENT_RIGHT, w)
	_bar(Vector2(cx - w * 0.5, y + 2), Vector2(w, 9), float(b["frac"]), RED, -1.0, 3)
	var py := y + 16.0
	var pips: Array = b["pips"]
	if not pips.is_empty():
		var pw := (w - (pips.size() - 1) * 6.0) / pips.size()
		for i in pips.size():
			_bar(Vector2(cx - w * 0.5 + i * (pw + 6.0), py), Vector2(pw, 4), float(pips[i]), Color(0.55, 0.85, 1.0))
		py += 12.0
	_text(Vector2(cx - w * 0.5, py + 12), str(b["sub"]), 11, Color(INK.r, INK.g, INK.b, 0.7), HORIZONTAL_ALIGNMENT_CENTER, w)
	if _phase_t > 0.0:
		var pa := clampf(_phase_t, 0.0, 1.0) * clampf((2.6 - _phase_t) * 5.0, 0.0, 1.0)
		var pulse := 0.75 + 0.25 * sin(_t * 18.0)
		_plate(Rect2(cx - w * 0.5 - 16, y - 24, w + 32, 62 if pips.is_empty() else 74), Color(0, 0, 0, 0), 6.0, Color(RED.r, RED.g, RED.b, pa * pulse))
		var title := "PHASE %d" % int(b["phase"])
		_text(Vector2(cx - 200, py + 52), title, 30, Color(RED.r, RED.g, RED.b, pa), HORIZONTAL_ALIGNMENT_CENTER, 400)
		_text(Vector2(cx - 200, py + 74), "IT CHANGES ITS WAYS", 11, Color(INK.r, INK.g, INK.b, pa * 0.8), HORIZONTAL_ALIGNMENT_CENTER, 400)


## Name and health of whoever you hit last.
func _paint_target(size: Vector2) -> void:
	if player.hud_target_t <= 0.0 or not is_instance_valid(player.hud_target):
		return
	var e := player.hud_target
	var a := clampf(player.hud_target_t, 0.0, 1.0)
	var hp := float(e.get("health"))
	var mx := maxf(float(e.get("max_health")), 1.0)
	var cx := size.x * 0.5
	var name_text := str(e.get("display_name")).to_upper()
	_text(Vector2(cx - 150, 82), name_text, 12, Color(INK.r, INK.g, INK.b, a), HORIZONTAL_ALIGNMENT_CENTER, 300)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_bar(Vector2(cx - 110, 88), Vector2(220, 7), hp / mx, Color(RED.r, RED.g, RED.b, a))
	if hp <= 0.0:
		_text(Vector2(cx - 150, 112), "DOWN", 11, Color(GOLD.r, GOLD.g, GOLD.b, a), HORIZONTAL_ALIGNMENT_CENTER, 300)


func _paint_vitals(size: Vector2, st: Stats) -> void:
	var x := 34.0
	var y := size.y - 38.0
	# warmth
	var warm_col := Color(0.45, 0.72, 1.0).lerp(Color(1.0, 0.62, 0.25), clampf(st.warmth / 60.0, 0.0, 1.0))
	_icon("flame" if st.warmth > 30.0 else "snow", Vector2(x + 9, y + 5), 18.0, warm_col)
	_bar(Vector2(x + 26, y), Vector2(150, 8), st.warmth / 100.0, warm_col)
	if absf(st.warm_rate) > 0.05:
		var up := st.warm_rate > 0.0
		var ax := x + 190.0
		var tip := -4.0 if up else 4.0
		_c.draw_colored_polygon(PackedVector2Array([Vector2(ax, y + 4 - tip), Vector2(ax + 8, y + 4 - tip), Vector2(ax + 4, y + 4 + tip)]),
			Color(1.0, 0.7, 0.35) if up else Color(0.5, 0.75, 1.0))
	# stamina: only while it matters
	y -= 20.0
	var sa := clampf(_stam_show, 0.0, 1.0)
	if sa > 0.0:
		_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_icon("bolt", Vector2(x + 9, y + 5), 18.0, Color(0.55, 0.9, 0.5, sa))
		_bar(Vector2(x + 26, y), Vector2(150, 8), st.stamina / 100.0, Color(0.5, 0.88, 0.45, sa))
	# health
	y -= 26.0
	var hc := RED if st.health > 35.0 else RED.lerp(Color(1, 0.6, 0.5), 0.5 + 0.5 * sin(_t * 6.0))
	_icon("heart", Vector2(x + 9, y + 8), 21.0, hc)
	_bar(Vector2(x + 26, y), Vector2(230, 14), st.health / 100.0, hc, _health_lag / 100.0, 10)
	# conditions, as small tags
	var cx := x
	var cy := y - 30.0
	for s in st.status():
		var word := str(s).to_upper()
		var col := Color(1.0, 0.75, 0.45)
		if word.contains("BLEED"):
			col = RED
		elif word.contains("WET") or word.contains("FREEZ") or word.contains("COLD"):
			col = Color(0.55, 0.8, 1.0)
		cx += _chip(Vector2(cx, cy), word, col)


func _paint_weapon(size: Vector2, arms: Arms) -> void:
	var rx := size.x - 40.0
	var by := size.y - 40.0
	if arms.held != "":
		if arms.is_gun():
			var s := arms.st(arms.held)
			var loaded := int(s["loaded"])
			var reserve := player.inv.count(str(s["ammo"]))
			var low := loaded <= maxi(1, int(float(arms._g.get("mag", 10)) * 0.25))
			var num := str(loaded)
			var nw := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
			var rw := _font.get_string_size("/ %d" % reserve, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			_text(Vector2(rx - rw, by), "/ %d" % reserve, 18, DIM)
			_text(Vector2(rx - rw - nw - 8, by), num, 46, RED if low else INK)
			if arms.reloading > 0.0:
				var f := 1.0 - arms.reloading / maxf(float(arms._g.get("reload", 1.0)), 0.1)
				_bar(Vector2(rx - 170, by + 10), Vector2(165, 5), f, GOLD)
			var ammo_name := Items.name_of(str(s["ammo"]))
			if str(s["ammo"]) != str(Weapons.GUNS[arms.held]["cal"]):
				_chip(Vector2(rx - _font.get_string_size(ammo_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x - 16, by - 74), ammo_name.to_upper(), GOLD)
			_text(Vector2(rx - 300, by - 46), Items.name_of(arms.held).to_upper(), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		else:
			_text(Vector2(rx - 300, by), Items.name_of(arms.held).to_upper(), 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, 300)
			if arms.blocking:
				_chip(Vector2(rx - 62, by - 44), "GUARD", Color(0.6, 0.85, 1.0))
			elif arms._counter > 0.0:
				_chip(Vector2(rx - 84, by - 44), "COUNTER!", GOLD)
	# weapon bar, shown briefly after switching
	if _slots_t > 0.0:
		var list := arms.weapons()
		var a := clampf(_slots_t, 0.0, 1.0)
		var w := 66.0
		var x := size.x * 0.5 - list.size() * (w + 6) * 0.5
		var y := size.y - 96.0
		for i in list.size():
			var on := list[i] == arms.held
			var r := Rect2(x, y - (6.0 if on else 0.0), w, 56)
			_plate(r, Color(0.1, 0.13, 0.19, 0.92 * a) if on else Color(0.03, 0.05, 0.09, 0.62 * a), 4.0, Color(1.0, 0.8, 0.35, 0.95 * a) if on else Color(1, 1, 1, 0.22 * a))
			var pic: Texture2D = ItemIcons.tex.get(list[i])
			if pic:
				_c.draw_texture_rect(pic, Rect2(r.position + Vector2(8, 3), Vector2(50, 50)), false, Color(1, 1, 1, a if on else 0.75 * a))
			else:
				var short := Items.name_of(list[i]).split(" ")[-1].substr(0, 6).to_upper()
				_c.draw_string(_font, Vector2(x, r.position.y + 34), short, HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(1, 1, 1, 0.85 * a))
			_c.draw_string(_font, Vector2(x + 5, r.position.y + 13), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.8, 0.35, a) if on else Color(1, 1, 1, 0.6 * a))
			if on:
				_c.draw_rect(Rect2(r.position.x + 6, r.end.y - 3, w - 12, 2), Color(1.0, 0.8, 0.35, a))
			x += w + 6


func _paint_crosshair(mid: Vector2, arms: Arms) -> void:
	if player.ui_open:
		return
	if arms.is_gun():
		var a := 1.0 - clampf(arms.aim * 2.0, 0.0, 1.0)
		if a <= 0.0:
			return
		var flat := Vector2(player.velocity.x, player.velocity.z).length()
		var gap := 7.0 + arms._bloom * 16.0 + flat * 1.6 + float(arms._g.get("spread", 1.0)) * 2.2
		var col := Color(1, 1, 1, 0.85 * a)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var v: Vector2 = d
			_c.draw_line(mid + v * (gap + 1), mid + v * (gap + 9), Color(0, 0, 0, 0.5 * a), 4.0)
			_c.draw_line(mid + v * (gap + 1), mid + v * (gap + 9), col, 2.0)
		_c.draw_circle(mid, 1.5, col)
	elif arms.is_melee():
		_c.draw_arc(mid, 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.6), 1.5, true)
		if arms._hold > 0.08:   # winding up a heavy blow
			_c.draw_arc(mid, 11.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(arms._hold / 0.28, 0.0, 1.0), 20, GOLD, 2.5, true)
	else:
		_c.draw_circle(mid, 2.0, Color(1, 1, 1, 0.6))


## Hit marker on what you hit, red wedges towards what hit you.
func _paint_marks(mid: Vector2) -> void:
	var hf := player.arms.hit_flash
	if hf > 0.0:
		var k := clampf(hf / 0.25, 0.0, 1.0)
		var col := Color(1, 1, 1, k)
		var r0 := 7.0 + (1.0 - k) * 5.0
		var r1 := r0 + 9.0
		var wide := 2.5
		if player.hit_kind == "kill":
			col = Color(RED.r, RED.g, RED.b, k)
			r1 = r0 + 14.0
			wide = 3.5
		elif player.hit_kind == "headkill":
			col = Color(GOLD.r, GOLD.g, GOLD.b, k)
			r1 = r0 + 18.0
			wide = 4.0
		elif player.hit_kind == "head":
			col = Color(GOLD.r, GOLD.g, GOLD.b, k)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var v: Vector2 = (d as Vector2).normalized()
			_c.draw_line(mid + v * r0, mid + v * r1, Color(0, 0, 0, 0.5 * k), wide + 2.0)
			_c.draw_line(mid + v * r0, mid + v * r1, col, wide)
	if _kill_t > 0.0:
		var ka := clampf(_kill_t / 0.5, 0.0, 1.0)
		var kc := GOLD if _kill_word == "HEADSHOT" else RED
		var rise := (1.2 - _kill_t) * 10.0
		_text(Vector2(mid.x - 100, mid.y + 58 - rise), _kill_word, 15 if _kill_word == "HEADSHOT" else 13, Color(kc.r, kc.g, kc.b, ka), HORIZONTAL_ALIGNMENT_CENTER, 200)
	for m in player.hurt_marks:
		var from: Vector3 = m[0]
		var life: float = m[1]
		var to := from - player.global_position
		var ang := atan2(to.x, -to.z) + player.rotation.y     # 0 = straight ahead, clockwise
		var a := clampf(life, 0.0, 1.0)
		var c := ang - PI * 0.5
		_c.draw_arc(mid, 118.0, c - 0.32, c + 0.32, 14, Color(0.95, 0.1, 0.08, 0.85 * a), 9.0, true)
		_c.draw_arc(mid, 128.0, c - 0.2, c + 0.2, 10, Color(0.95, 0.1, 0.08, 0.45 * a), 4.0, true)


func _paint_vehicle(size: Vector2) -> void:
	var v := player.vehicle
	var rx := size.x - 40.0
	var by := size.y - 40.0
	var speed := str(int(v.speed_kmh()))
	var sw := _font.get_string_size(speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	_text(Vector2(rx - 46, by), "km/h", 14, DIM)
	_text(Vector2(rx - 54 - sw, by), speed, 52, INK)
	var y := by - 78.0
	_icon("drop", Vector2(rx - 196, y + 4), 16.0, GOLD if v.fuel > v.tank() * 0.15 else RED)
	_bar(Vector2(rx - 180, y), Vector2(170, 7), v.fuel / v.tank(), GOLD if v.fuel > v.tank() * 0.15 else RED)
	y -= 16.0
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ec := Color(0.7, 0.85, 1.0) if v.health > 45.0 else RED
	_icon("cog", Vector2(rx - 196, y + 4), 17.0, ec)
	_bar(Vector2(rx - 180, y), Vector2(170, 7), v.health / 100.0, ec)
	_text(Vector2(rx - 300, y - 12), str(v.cfg["name"]).to_upper(), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 300)
	# warnings
	var cx := rx
	var cy := y - 56.0
	var tags: Array = []
	if v.sunk:
		tags.append(["SINKING — GET OUT", RED])
	elif v.health <= 0.0:
		tags.append(["ENGINE WRECKED", RED])
	elif v.fuel <= 0.0:
		tags.append(["NO FUEL", RED])
	if v.surface == "ice":
		var cm := int(Lake.thickness(Vector2(v.global_position.x, v.global_position.z)) * 100.0)
		var safe := Lake.capacity(Vector2(v.global_position.x, v.global_position.z)) > v.total_mass() * 1.5
		tags.append(["ICE %d CM" % cm, Color(0.6, 0.85, 1.0) if safe else RED])
	elif v.surface == "snow" and v.drag("snow") > 1.0:
		tags.append(["DEEP SNOW", Color(0.8, 0.9, 1.0)])
	if v.winching():
		tags.append(["WINCH", GOLD])
	if v.lights_on:
		tags.append(["LIGHTS", Color(1.0, 0.95, 0.7)])
	for tag in tags:
		var word: String = tag[0]
		var w := _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 22.0
		cx -= w
		_chip(Vector2(cx, cy), word, tag[1])


# ------------------------------------------------------------ textures
func _make_vignette() -> Texture2D:
	var img := Image.create(160, 90, false, Image.FORMAT_RGBA8)
	for y in 90:
		for x in 160:
			var d := Vector2((x - 79.5) / 80.0, (y - 44.5) / 45.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, pow(smoothstep(0.62, 1.35, d), 1.4)))
	return ImageTexture.create_from_image(img)


## Black mask with a round hole and a fine reticle, shown while looking through a scope.
func _make_scope() -> Control:
	var img := Image.create(512, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 512:
			var d := Vector2(x - 255.5, y - 127.5).length() / 128.0
			img.set_pixel(x, y, Color(0, 0, 0, smoothstep(0.90, 0.94, d) + smoothstep(0.5, 0.94, d) * 0.25))
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	for horizontal in [true, false]:
		var line := ColorRect.new()
		line.color = Color(0, 0, 0, 0.9)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if horizontal:
			line.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
			line.offset_top = -1
			line.offset_bottom = 1
		else:
			line.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
			line.offset_left = -1
			line.offset_right = 1
		root.add_child(line)
	root.visible = false
	add_child(root)
	return root
