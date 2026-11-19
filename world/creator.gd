class_name Creator
extends Node
## Creator mode: the valley as a workshop. No enemies, no story, you cannot get hurt, cold or
## hungry. [F] flies (W/A/S/D, Space up, Ctrl down, Shift fast), [P] opens the creator panel:
## jump to any place, put any house type, person, gun or enemy in front of you, change the
## weather and the season. Used to try out designs that are not in the game yet.

var main: Node
var player: Player
var flying := false
var panel: Control
var _spawned: Array[Node3D] = []
var _help_shown := false

const HOUSES := ["house", "house_small", "hotel", "restaurant", "toyshop", "station", "cabin"]


func _ready() -> void:
	player = main.player
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	_hello.call_deferred()
	if "--creatortest" in OS.get_cmdline_user_args():
		_selftest.call_deferred()


func _hello() -> void:
	await get_tree().create_timer(0.8).timeout
	player.message.emit("CREATOR MODE  ·  [F] fly  ·  [P] creator panel  ·  nothing can hurt you here")


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	# nothing hurts in the workshop
	var s := player.stats
	s.health = 100.0
	s.stamina = 100.0
	s.warmth = 100.0
	s.bleeding = 0.0
	s.wet = 0.0
	s.sprain = false
	if flying and not player.ui_open:
		_fly(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc == KEY_F and not player.ui_open:
			set_fly(not flying)
			get_viewport().set_input_as_handled()
		elif kc == KEY_P:
			toggle_panel()
			get_viewport().set_input_as_handled()


func set_fly(on: bool) -> void:
	flying = on
	player.set_physics_process(not on)
	player.velocity = Vector3.ZERO
	player.message.emit("Flying  ·  Space up, Ctrl down, Shift fast" if on else "Walking")


func _fly(delta: float) -> void:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var look := player.camera.global_basis
	var dir := look * Vector3(inp.x, 0, inp.y)
	if Input.is_action_pressed("jump"):
		dir.y += 1.0
	if Input.is_action_pressed("crouch"):
		dir.y -= 1.0
	var speed := 60.0 if Input.is_action_pressed("sprint") else 14.0
	player.global_position += dir.limit_length(1.0) * speed * delta
	# never below the ground
	var g: float = main.terrain.surface_at(player.global_position.x, player.global_position.z)
	player.global_position.y = maxf(player.global_position.y, g + 0.2)
	player.head.rotation.x = player._pitch


# ------------------------------------------------------------------ panel

func toggle_panel() -> void:
	panel.visible = not panel.visible
	player.ui_open = panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(30, 70)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.4, 0.85, 0.55, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	panel.add_child(cols)

	var a := _col(cols, "GO TO")
	_btn(a, "Polaris square", func() -> void: _jump(Vector2(Terrain.VILLAGE_POS)))
	_btn(a, "Lake / Eisgrund", func() -> void: _jump(Places.SETTLE))
	for sp in main.places.spots:
		var spot: Dictionary = sp
		_btn(a, str(spot.get("name", spot["id"])), func() -> void: _jump(Vector2(spot["pos"].x, spot["pos"].z)))

	var b := _col(cols, "PUT IN FRONT")
	for k in HOUSES:
		var kind: String = k
		_btn(b, "House: " + kind, func() -> void: _spawn_house(kind))
	_btn(b, "Raider (hostile)", func() -> void: _spawn_enemy("raider"))
	_btn(b, "Wolf (hostile)", func() -> void: _spawn_enemy("wolf"))
	_btn(b, "Remove what I put down", _clear)

	var c := _col(cols, "TOOLS")
	_btn(c, "Fly on / off  [F]", func() -> void: set_fly(not flying))
	_btn(c, "All guns + ammo", _guns)
	_btn(c, "Clear weather", func() -> void: _weather(0.0))
	_btn(c, "Storm", func() -> void: _weather(1.0))
	_btn(c, "Season: summer", func() -> void: _season("summer"))
	_btn(c, "Season: winter", func() -> void: _season("winter"))
	_btn(c, "Grass on / off", _toggle_grass)
	_btn(c, "Picture (shots/creator_*.png)", _picture)
	_btn(c, "Close  [P]", toggle_panel)


func _col(parent: Control, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.45, 0.9, 0.6))
	l.add_theme_font_size_override("font_size", 18)
	v.add_child(l)
	return v


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)


# ------------------------------------------------------------------ actions

func _jump(p: Vector2) -> void:
	var y: float = main.terrain.surface_at(p.x, p.y)
	player.global_position = Vector3(p.x, y + (25.0 if flying else 1.0), p.y + 12.0)
	player.velocity = Vector3.ZERO
	toggle_panel()


func _ahead(dist: float) -> Vector3:
	var f := -player.global_basis.z
	f.y = 0.0
	var p := player.global_position + f.normalized() * dist
	p.y = main.terrain.surface_at(p.x, p.z)
	return p


func _spawn_house(kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n: Node3D = Chalet.build(kind, rng, true)
	main.add_child(n)
	n.global_position = _ahead(16.0 if kind != "hotel" else 24.0)
	n.rotation.y = player.rotation.y
	_spawned.append(n)
	toggle_panel()


func _spawn_enemy(kind: String) -> void:
	var at := _ahead(18.0) + Vector3(0, 0.5, 0)
	var e: Node3D = main.enemies.raider("assault_rifle", at) if kind == "raider" else main.enemies.wolf(at)
	_spawned.append(e)
	toggle_panel()


func _clear() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _guns() -> void:
	for id in Items.DB:
		var d: Dictionary = Items.DB[id]
		if d.get("weapon", false):
			player.inv.add(id, 1)
		elif d.get("ammo", false):
			player.inv.add(id, 120)
	player.message.emit("Every weapon and 120 rounds of each ammo are in your pack.")


func _weather(storm: float) -> void:
	main.weather.auto_cycle = false
	main.weather.storm = storm
	main.weather.target_storm = storm


func _season(s: String) -> void:
	GameMode.season = s
	GameMode.switch(get_tree(), "creator", "new")


func _toggle_grass() -> void:
	for c in main.get_children():
		if c is Grass:
			c.visible = not c.visible


func _picture() -> void:
	panel.visible = false
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var path := "res://shots/creator_%d.png" % Time.get_unix_time_from_system()
	get_viewport().get_texture().get_image().save_png(path)
	panel.visible = true
	player.message.emit("Saved " + path)


## `-- --creator --creatortest`: fly up, put a hotel and a raider down, open the panel, take pictures.
func _selftest() -> void:
	await get_tree().create_timer(2.0).timeout
	_jump(Vector2(Terrain.VILLAGE_POS) + Vector2(0, 40))
	if panel.visible:
		toggle_panel()
	set_fly(true)
	var y0 := player.global_position.y
	Input.action_press("jump")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("jump")
	print("CREATOR fly up %.1f m (flying=%s)" % [player.global_position.y - y0, flying])
	set_fly(false)
	await get_tree().create_timer(2.0).timeout
	_spawn_house("hotel")
	_spawn_enemy("raider")
	if panel.visible:
		toggle_panel()
	print("CREATOR spawned %d things, health %.0f" % [_spawned.size(), player.stats.health])
	await get_tree().create_timer(2.0).timeout
	await _picture()
	panel.visible = false
	toggle_panel()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/creator_panel.png")
	print("CREATOR done")
	get_tree().quit()
