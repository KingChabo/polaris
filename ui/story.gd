class_name Story
extends CanvasLayer
## Full-screen story cards: the opening when a new game starts, and the epilogue
## that matches what you did with the heart of Core 31. Text fades in page by page.

const INK := Color(0.93, 0.96, 1.0)
const GOLD := Color(1.0, 0.8, 0.35)
const ICE := Color(0.55, 0.85, 1.0)

const INTRO := [
	["POLARIS", "December. The Senke, a valley in the far north where the sun stays below the mountains all winter.\n\nYou came up on the bus with your sister Mirja for the Christmas market: a carousel, a tree with a thousand lights, Glühwein in paper cups."],
	["THE TUNNEL", "On the way out, soldiers stopped the bus at the tunnel. Then the roof came down behind it.\n\nThirty-one passengers walked back to the village in the dark. The army has not answered since. The road is gone. The lights under the lake ice have not stopped."],
	["MIRJA", "That first night Mirja put on her red scarf and walked out towards the lake. She did not come back.\n\nThe people who stayed in Polaris say the valley has gone wrong: raiders in the woods, a machine that digs by itself, something white walking on the ice.\n\nFind your sister. Find out what happened here."],
]

const SUMMER_INTRO := [
	["POLARIS", "August. The Senke, a valley in the far north where the sun drops behind the mountains by four in the afternoon, even in summer.\n\nYou came up on the bus with your sister Mirja for the summer fair: a carousel, a maypole hung with a thousand lights, berry wine in paper cups."],
	INTRO[1],
	INTRO[2],
]

const HORROR_INTRO := [
	["POLARIS", "December. The last bus out of the Senke stopped at the tunnel, and then the roof came down behind it.\n\nThe driver turned around. Nobody spoke on the way back."],
	["THE FOG", "Polaris was dark when you came back. The carousel was turning with nobody on it. The loudspeakers played the carol slower and slower, like a tape running down.\n\nEvery door was locked. Every window was black.\n\nYour sister Mirja got off the bus first, and walked into the fog towards the lake."],
	["DO NOT LOOK AWAY", "There is something in the fog. It is very tall. It does not move while you are looking at it.\n\nThe flashlight is on F. Keep it on whatever watches you.\n\nFind the people who hid. Find Mirja. Do not turn your back."],
]

## Cards between the two parts of the story: the lake is settled, the valley is still shut.
const CARDS := {
	"part_destroyed": ["THE LIGHTS GO OUT", "Father Aurel shut the heart of Core 31 in the chapel stove, and it burned blue for a whole night.\n\nIn the morning the aurora was only an aurora, and the ice on the lake was quiet. But the tunnel was still shut, the radio still dead, and thirty-one passengers still wanted to go home.\n\nMirja came up from Eisgrund with something heavy in her pack: Arvid's last blasting charge. \"The roof fall is fourteen metres,\" she said. \"Not a mountain. Somebody only has to light it.\""],
	"part_returned": ["THE LAKE KEEPS ITS SECRET", "Tove and the people of Eisgrund lowered the heart through the deep hole on a fishing line, and the water closed over it.\n\nThe lights under the ice dimmed but did not die. The tunnel was still shut, the radio still dead, and thirty-one passengers still wanted to go home.\n\nMirja put something heavy on Tove's table: Arvid's last blasting charge. \"The roof fall is fourteen metres,\" she said. \"Not a mountain. Somebody only has to light it.\""],
	"part_sold": ["BOUGHT AND SOLD", "Pavel paid in old Kronen and new promises. The men who were to come for the case never came: there is no way into the valley for them either.\n\nSo the heart sits in a tin box under Pavel's stall, the tunnel is still shut, and fifteen hundred Kronen buy nothing where there is nothing to buy.\n\nMirja put something heavy on the table: Arvid's last blasting charge. \"The roof fall is fourteen metres,\" she said. \"Not a mountain. Somebody only has to light it.\""],
	"h_part": ["THE FOG MOVES ON", "The White One fell through the ice, and the lights under the lake went out one by one.\n\nThe fog did not lift. It drew together, the way water finds a drain, and went south through the broken tunnel. At noon Mirja walked out of the trees in her red scarf and took your hand. Her hand was very cold.\n\n\"It is not finished,\" she said. \"It has only gone where there are more people.\"\n\nShe has not blinked since."],
}

const ENDINGS := {
	"horror": ["ASH", "The sawmill burned until the roof fell in, and what came out of the rafters did not scream. It only folded up, one after another, and blew away over the snow as grey ash.\n\nThe fog was gone by morning. In Grauwasser the siren ran down and stopped, and nobody started it again.\n\nMirja stood at the edge of the yard and watched the fire. When you took her hand it was warm. Then she blinked — once, slowly, like somebody waking up — and asked what day it was."],
	"flown": ["LAST FLIGHT", "The helicopter lifted out of the Vorland on a grey morning with six seats and two of them yours. Mirja watched the valley shrink until the pass closed behind it like a door.\n\nOn the coast they gave you blankets and forms to sign. Nobody asked about Grauwasser. The pass stayed shut until the thaw.\n\nIn spring the first convoy found the town still standing, and a ward with nine empty beds. Nobody there said your name. Mirja still wears the red scarf. Some nights she stands at the window, facing north."],
	"ward": ["SIX SEATS", "Dr. Brandt wrote six names on the manifest, and none of them was yours.\n\nThe helicopter lifted out on a grey morning and the pass closed behind it. You stayed: hauling wood, clearing wolves from the roads, walking the tunnel between two valleys that had each thought the other dead.\n\nIn spring the convoy came, and with it six people who could walk again. Mirja met them on the square. Grauwasser put up a second name on the memorial — not for the dead this time."],
	"line": ["THE LIFELINE", "There was no last flight. There were a hundred short ones.\n\nAll winter Jorun's helicopter flew the tunnel line: medicine to Polaris, fish from Eisgrund, the sick to the ward, fuel to the mast. Two valleys that had been written off became one, and the coast learned to say its name.\n\nWhen the thaw opened the pass, hardly anyone left. Mirja runs the radio at the Hochfunk now. Her call sign is 3186, and she signs off every night the same way: \"The Senke is open.\""],
}

var main: Node
var _pages: Array = []
var _i := 0
var _t := 0.0
var _done: Callable
var _c: Control
var _font: Font


class Painter extends Control:
	var s: Story
	func _draw() -> void:
		s._paint()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	var p := Painter.new()
	p.s = self
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	_c = p
	visible = false


func is_open() -> bool:
	return visible


func show_pages(pages: Array, done: Callable) -> void:
	_pages = pages
	_i = 0
	_t = 0.0
	_done = done
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if main and main.get("player"):
		main.player.ui_open = true
	if main and main.get("hud"):
		main.hud.visible = false


func show_intro(done: Callable) -> void:
	show_pages(HORROR_INTRO if GameMode.horror() else (SUMMER_INTRO if GameMode.summer() else INTRO), done)


func show_ending(outcome: String) -> void:
	var e: Array = ENDINGS.get(outcome, ENDINGS["line"])
	var stats := "Documents found: %d of %d      Places discovered: %d of %d      Jobs done: %d of %d" % [
		main.reader.found.size(), get_tree().get_nodes_in_group("note").size(),
		main.places.found.size(), main.places.spots.size(),
		main.quests.done_count(), main.quests.mode_count()]
	show_pages([e, ["THE END", "Thank you for playing POLARIS.\n\n" + stats + "\n\nBoth valleys stay open: the notice boards never run dry. Take jobs, hunt, trade, or simply walk under the aurora."]], func() -> void: pass)


## A card in the middle of the story: the game goes on afterwards.
func show_card(key: String) -> void:
	if not CARDS.has(key):
		return
	show_pages([CARDS[key], ["PART TWO", "THE VORLAND\n\nBeyond the Polaris tunnel lies a second valley. The road south is yours to open."]], func() -> void: pass)


func _finish() -> void:
	visible = false
	get_tree().paused = false
	if main and main.get("player"):
		main.player.ui_open = false
	if main and main.get("hud"):
		main.hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _done.is_valid():
		_done.call()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_c.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var go: bool = event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("pause") \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ENTER)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if _t < 0.6:
		return
	if event.is_action_pressed("pause"):
		_finish()      # skip the rest
		return
	_i += 1
	_t = 0.0
	if _i >= _pages.size():
		_finish()


func _paint() -> void:
	if _i >= _pages.size():
		return
	var size := _c.size
	var a := clampf(_t * 1.2, 0.0, 1.0)
	# deep night with a band of aurora across the top
	var horror := GameMode.horror()
	_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.008, 0.01) if horror else Color(0.008, 0.015, 0.03))
	# soft aurora curtain: many faint strands that sway slowly
	var tm := Time.get_ticks_msec() * 0.0003
	for i in 220:
		var f := i / 219.0
		var x := size.x * (f * 1.2 - 0.1)
		var w := sin(f * 7.0 + tm) * 40.0 + sin(f * 19.0 - tm * 1.7) * 12.0
		var tall := 120.0 + 90.0 * (0.5 + 0.5 * sin(f * 11.0 + tm * 0.8))
		var al := 0.018 + 0.016 * (0.5 + 0.5 * sin(f * 23.0 + tm * 2.0))
		var top := Vector2(x + 30.0, 40.0 + w)
		var bot := Vector2(x, 40.0 + w + tall)
		_c.draw_line(top, bot, Color(0.8, 0.06, 0.04, al * 0.8) if horror else Color(0.25, 0.95, 0.65, al), 9.0)
		_c.draw_line(top - Vector2(0, 40), top, Color(0.3, 0.0, 0.06, al * 0.6) if horror else Color(0.6, 0.35, 0.9, al * 0.6), 9.0)
	var page: Array = _pages[_i]
	var w := minf(820.0, size.x - 120.0)
	var x0 := (size.x - w) * 0.5
	var y0 := size.y * 0.32
	var head := Color(0.85, 0.12, 0.08) if horror else GOLD
	var jit := Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)) if horror and randf() < 0.08 else Vector2.ZERO
	_c.draw_string(_font, Vector2(x0, y0) + jit, str(page[0]), HORIZONTAL_ALIGNMENT_LEFT, w, 40, Color(head.r, head.g, head.b, a))
	_c.draw_line(Vector2(x0, y0 + 18), Vector2(x0 + 120.0 * a, y0 + 18), Color(ICE.r, ICE.g, ICE.b, a), 2.0)
	var ta := clampf((_t - 0.4) * 0.9, 0.0, 1.0)
	_c.draw_multiline_string(_font, Vector2(x0, y0 + 64), str(page[1]), HORIZONTAL_ALIGNMENT_LEFT, w, 20, -1, Color(INK.r, INK.g, INK.b, 0.9 * ta))
	var dots := ""
	for k in _pages.size():
		dots += "●  " if k == _i else "○  "
	_c.draw_string(_font, Vector2(0, size.y - 60), dots, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(INK.r, INK.g, INK.b, 0.5))
	if _t > 1.2:
		_c.draw_string(_font, Vector2(0, size.y - 32), "[E] / click  continue        [Esc]  skip", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(INK.r, INK.g, INK.b, 0.45))
