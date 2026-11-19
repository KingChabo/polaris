extends Node3D
## Builds the whole world in code and starts the game.
## Run with `-- --shot` to save test screenshots into shots/ and quit.

const GLOW_DIR := Vector3(0.35, 0.0, -1.0)

var terrain: Terrain
var weather: Weather
var player: Player
var env: Environment
var noise_tex: NoiseTexture2D
var normal_tex: NoiseTexture2D
var prints: Footprints
var lake: Lake
var forest: Forest
var village: Village
var screen: InvScreen
var wilds: Wilds
var people: People
var places: Places
var hud: Hud
var reader: ReadScreen
var factions: Factions
var trade: Trade
var quests: Quests
var town: TownScreen
var bullets: Bullets
var enemies: Enemies
var bosses: Bosses
var garage: Garage
var mood: CombatMood
var menu: GameMenu
var story: Story
var map: MapScreen
var post: PostFx
var horror: Horror          # only in horror mode
var jobs: Jobs
var sun: DirectionalLight3D
var aurora_light: DirectionalLight3D


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	# autosave every 5 minutes of play (paused menus do not count)
	var at := Timer.new()
	at.wait_time = 300.0
	at.process_mode = Node.PROCESS_MODE_PAUSABLE
	at.timeout.connect(func() -> void:
		if not GameMode.creator() and player and player.stats.health > 0.0 and not menu.visible:
			SaveGame.autosave(self))
	add_child(at)
	at.start()
	if "--horror" in OS.get_cmdline_user_args():
		GameMode.mode = "horror"
	if "--creator" in OS.get_cmdline_user_args():
		GameMode.mode = "creator"
	if "--noscan" in OS.get_cmdline_user_args():      # compare: the code-built people
		ScanPerson.enabled = false
		ModelLib.enabled = not ("--noscan=all" in OS.get_cmdline_user_args())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skip="):
			for id in a.trim_prefix("--skip=").split(","):
				ModelLib.skip[id] = true
	SaveGame.path = GameMode.save_path()
	Mats._cache.clear()        # materials are shared statics; a reload must not keep the last mode's tweaks
	_make_noise_textures()
	_make_environment()

	var tmat := ShaderMaterial.new()
	tmat.shader = load("res://world/terrain.gdshader")
	tmat.set_shader_parameter("noise_tex", noise_tex)
	tmat.set_shader_parameter("normal_tex", normal_tex)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.prepare(tmat)
	Places.plan(terrain)
	Village.plan(terrain)
	terrain.build_mesh()
	Mats.noise_tex = noise_tex
	lake = Lake.new()
	add_child(lake)
	lake.build(noise_tex, normal_tex)

	Wilds.plan(terrain)
	forest = Forest.new()
	forest.noise_tex = noise_tex
	add_child(forest)
	forest.build(terrain)

	var t1 := Time.get_ticks_msec()
	village = Village.new()
	add_child(village)
	village.build(terrain, forest)
	var wilds_light_start := Props.lights.size()
	wilds = Wilds.new()
	add_child(wilds)
	wilds.build(terrain, village)
	places = Places.new()
	add_child(places)
	village.add_lights_from(wilds_light_start)
	print("Village built in %d ms" % (Time.get_ticks_msec() - t1))

	player = Player.new()
	add_child(player)
	var sp := Terrain.VILLAGE_POS + Vector2(0.0, 138.0)
	player.position = Vector3(sp.x, terrain.height_at(sp.x, sp.y) + 0.5, sp.y)
	player.spawn = player.position
	player.lake = lake
	player.village = village
	mood = CombatMood.new()
	mood.player = player
	add_child(mood)
	hud = Hud.new()
	hud.player = player
	hud.mood = mood
	add_child(hud)
	screen = InvScreen.new()
	screen.player = player
	add_child(screen)
	player.screen = screen
	reader = ReadScreen.new()
	reader.player = player
	reader.places = places
	add_child(reader)
	places.build(terrain, village, self)
	factions = Factions.new()
	factions.main = self
	add_child(factions)
	factions.setup_zones()
	trade = Trade.new()
	trade.main = self
	add_child(trade)
	quests = Quests.new()
	quests.main = self
	add_child(quests)
	town = TownScreen.new()
	town.main = self
	town.player = player
	add_child(town)
	hud.quests = quests
	hud.factions = factions
	player.inv.add("coin", 40)
	for wb: Array in [[village._w(Vector2(10.2, 121.0)), -PI * 0.5], [places.gy(Places.SETTLE + Vector2(5.0, 6.0)), 0.6]]:
		var bench := Workbench.new()
		bench.town = town
		bench.setup()
		add_child(bench)
		bench.position = wb[0]
		bench.rotation.y = wb[1]
	bullets = Bullets.new()
	add_child(bullets)
	player.bullets = bullets
	enemies = Enemies.new()
	enemies.main = self
	add_child(enemies)
	bosses = Bosses.new()
	bosses.main = self
	add_child(bosses)
	bosses.spawn_all()
	hud.bosses = bosses

	people = People.new()
	people.main = self
	add_child(people)
	people.spawn_all()

	garage = Garage.new()
	garage.main = self
	add_child(garage)
	garage.spawn_all()

	prints = Footprints.new()
	prints.terrain = terrain
	add_child(prints)
	player.stepped.connect(prints.add_print)

	if GameMode.summer() and not "--nograss" in OS.get_cmdline_user_args():
		var grass := Grass.new()
		grass.terrain = terrain
		grass.village = village
		grass.noise_tex = noise_tex
		add_child(grass)

	weather = Weather.new()
	weather.env = env
	weather.follow = player
	add_child(weather)
	player.weather = weather

	map = MapScreen.new()
	map.main = self
	add_child(map)
	story = Story.new()
	story.main = self
	add_child(story)
	menu = GameMenu.new()
	menu.main = self
	add_child(menu)
	post = PostFx.new()
	post.setup(noise_tex)
	add_child(post)
	jobs = Jobs.new()
	add_child(jobs)
	jobs.build(self)
	if GameMode.horror():
		horror = Horror.new()
		add_child(horror)
		horror.build(self)
		people.horror_setup()
		people.update_story(quests)
	Settings.apply(self)

	print("World built in %d ms" % (Time.get_ticks_msec() - t0))
	if not player.camera.current:
		push_error("the player's camera is not the active one")
	if not OS.get_cmdline_user_args().is_empty():
		# test runs must not slow to a crawl when the window is hidden behind another one
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# scripted runs must not react to the real keyboard and mouse of whoever sits at the machine
		for arg in OS.get_cmdline_user_args():
			if str(arg).ends_with("test"):
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
				player.set_process_unhandled_input(false)
		Engine.max_fps = 60
	if "--shot" in OS.get_cmdline_user_args():
		_shot_mode()
	elif "--scanshot" in OS.get_cmdline_user_args():
		_scan_shot.call_deferred()
	elif "--walktest" in OS.get_cmdline_user_args():
		_walk_test()
	elif "--survtest" in OS.get_cmdline_user_args():
		_surv_test()
	elif "--combattest" in OS.get_cmdline_user_args():
		_combat_test()
	elif "--looktest" in OS.get_cmdline_user_args():
		_look_test()
	elif "--drivetest" in OS.get_cmdline_user_args():
		_drive_test()
	elif "--climbtest" in OS.get_cmdline_user_args():
		_climb_test()
	elif "--placestest" in OS.get_cmdline_user_args():
		_places_test()
	elif "--econtest" in OS.get_cmdline_user_args():
		_econ_test()
	elif "--iconsheet" in OS.get_cmdline_user_args():
		while not player.screen.icons.done:
			await get_tree().process_frame
		ItemIcons.sheet(ProjectSettings.globalize_path("res://shots/300_icons.png"))
		get_tree().quit()
	elif "--doortest" in OS.get_cmdline_user_args():
		_door_test()
	elif "--buildtest" in OS.get_cmdline_user_args():
		_build_test()
	elif "--southtest" in OS.get_cmdline_user_args():
		_south_test()
	elif "--probe" in OS.get_cmdline_user_args():
		_probe()
	elif "--bosstest" in OS.get_cmdline_user_args():
		_boss_test()
	elif "--playtest" in OS.get_cmdline_user_args():
		var pt := PlayTest.new()
		pt.main = self
		add_child(pt)
		pt.run.call_deferred()
	elif "--storytest" in OS.get_cmdline_user_args():
		_story_test()
	elif "--horrortest" in OS.get_cmdline_user_args():
		_horror_test()
	elif GameMode.creator():
		var cr := Creator.new()
		cr.main = self
		add_child(cr)
		GameMode.pending = ""
		if not "--creatortest" in OS.get_cmdline_user_args():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		enemies.spawn_all()
		bosses.wake()
		var then := GameMode.pending
		GameMode.pending = ""
		if then == "new":
			start_new_game()
		elif then == "load" and SaveGame.load_game(self):
			ensure_story()
		else:
			menu.show_title()


## "New game" on the title screen: the opening cards, then the first chapter.
func start_new_game() -> void:
	story.show_intro(func() -> void:
		if quests.status(Quests.first_chapter()) == "none":
			quests.accept(Quests.first_chapter())
		_first_steps())


## The first minutes: one short hint at a time on the keys that matter (only on a new game).
func _first_steps() -> void:
	if GameMode.creator() or "test" in " ".join(OS.get_cmdline_user_args()):
		return
	var K := func(a: String) -> String: return Settings.keys_of(a)
	var tips := [
		[3.0, "Move %s / %s / %s / %s, run with %s, jump with %s." % [K.call("move_forward"), K.call("move_left"), K.call("move_back"), K.call("move_right"), K.call("sprint"), K.call("jump")]],
		[14.0, "Your goal is the marker on the compass at the top. %s opens the map, %s the quest log." % [K.call("map"), K.call("quests")]],
		[30.0, "%s talks to people, opens doors and picks things up." % K.call("interact")],
		[48.0, "%s opens your pack. Clothes keep you warm and dry, food and bandages heal." % K.call("inventory")],
		[70.0, "The bars bottom left: health, stamina, warmth. Rain and cold water chill you; a warm house fixes it."],
		[95.0, "%s turns the flashlight on. %s saves, %s loads the newest save (it also saves by itself)." % [K.call("flashlight"), K.call("quicksave"), K.call("quickload")]],
	]
	var t0 := 0.0
	for tip in tips:
		await get_tree().create_timer(float(tip[0]) - t0, false).timeout
		t0 = float(tip[0])
		if player:
			player.message.emit(str(tip[1]))


## Saves from before the story existed get the first chapter too.
func ensure_story() -> void:
	if quests.status(Quests.first_chapter()) == "none":
		quests.accept(Quests.first_chapter())


func _walk_test() -> void:
	AudioServer.set_bus_mute(0, true)
	var start := player.global_position
	await get_tree().create_timer(1.0).timeout
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await get_tree().create_timer(4.0).timeout
	var p := player.global_position
	print("walktest moved=%.1f m  feet=%.2f ground=%.2f on_floor=%s prints=%d" % [
		Vector2(p.x - start.x, p.z - start.z).length(), p.y, terrain.height_at(p.x, p.z),
		player.is_on_floor(), prints.get_child_count()])
	get_tree().quit()


func _snap(shot: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % shot)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Scripted check of guns, bullets, mods, melee, enemies and saving.
func _combat_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	SaveGame.path = "user://test_save.json"
	var arms := player.arms
	var inv := player.inv
	var st := player.stats
	arms.free_input = true
	inv.add("large_pack")
	inv.equip("large_pack")
	for id in Arms.ORDER:
		if inv.count(id) == 0:
			inv.add(id)
	for a in ["9mm", "9mm_ap", "357", "556", "556_ap", "762", "338", "12g", "12g_slug", "flare"]:
		inv.add(a, 150)
	for m in ["red_dot", "scope", "silencer", "muzzle_brake", "grip", "ext_mag"]:
		inv.add(m, 2)
	player.global_position = village._w(Vector2(0, 100), 0.3)
	await _wait(0.6)

	# --- bullets: drop after half a second of flight
	for id in ["pistol", "sniper_rifle", "flare_gun"]:
		var v := float(Weapons.GUNS[id]["vel"])
		bullets.fire(Vector3(0, 600, 0), Vector3(v, 0, 0), 1.0, 0.0, null)
		for i in 30:
			await get_tree().physics_frame
		var b: Dictionary = bullets._list[bullets._list.size() - 1]
		var bp: Vector3 = b["pos"]
		print("ballistics %s: after 0.5 s  %.0f m out, dropped %.2f m, speed %.0f of %.0f m/s" % [id, bp.x, 600.0 - bp.y, (b["vel"] as Vector3).length(), v])

	# --- pistol on a target dummy: body and head
	var dummy := enemies.raider("knife", village._w(Vector2(0, 88), 0.3))
	dummy.passive = true
	dummy.health = 9999.0
	var tank := enemies.raider("assault_rifle", village._w(Vector2(2.5, 88), 0.3))
	tank.passive = true
	await _wait(0.6)
	arms.hold("pistol")
	arms.reload()
	await _wait(1.9)
	Input.action_press("aim")
	await _wait(0.5)
	player.aim_at(dummy.global_position + Vector3(0, 1.15, 0))
	await _wait(0.1)
	arms.fire()
	await _wait(0.3)
	print("pistol body shot: damage %.1f head=%s (dummy armour %d)" % [dummy.last_damage, dummy.last_head, int(dummy.armor)])
	player.aim_at(dummy.global_position + Vector3(0, 1.63, 0))
	await _wait(0.1)
	arms.fire()
	await _wait(0.3)
	print("pistol head shot: damage %.1f head=%s  state=%s" % [dummy.last_damage, dummy.last_head, dummy.state])
	# --- armour and armour-piercing rounds
	tank.health = 9999.0
	player.aim_at(tank.global_position + Vector3(0, 1.15, 0))
	await _wait(0.1)
	arms.fire()
	await _wait(0.3)
	var plain := tank.last_damage
	arms.cycle_ammo()
	await _wait(1.9)
	player.aim_at(tank.global_position + Vector3(0, 1.15, 0))
	await _wait(0.1)
	arms.fire()
	await _wait(0.3)
	print("armour %d: 9 mm does %.1f, 9 mm AP does %.1f  (loaded: %s)" % [int(tank.armor), plain, tank.last_damage, arms.st("pistol")["ammo"]])
	Input.action_release("aim")

	# --- every gun fires once
	for id in Arms.ORDER:
		if not Weapons.is_gun(id):
			continue
		arms.hold(id)
		arms.reload()
		await _wait(float(Weapons.GUNS[id]["reload"]) + 0.25)
		tank.health = 9999.0
		tank.last_damage = 0.0
		var before := tank.health
		Input.action_press("aim")
		await _wait(0.6)
		player.aim_at(tank.global_position + Vector3(0, 1.15, 0))
		await _wait(0.1)
		var ok := arms.fire()
		await _wait(0.45)
		Input.action_release("aim")
		print("  %-15s fired=%s  %s  total damage on armoured dummy %.1f" % [id, ok, arms.ammo_text(), before - tank.health])
	await _wait(0.3)

	# --- mods
	arms.hold("assault_rifle")
	var g0 := Weapons.stats("assault_rifle", [])
	for m in ["red_dot", "grip", "silencer", "ext_mag"]:
		print("  ", arms.attach(m))
	print("  ", arms.attach("scope"), " (replaces the red dot; red dots carried: ", inv.count("red_dot"), ")")
	print("  revolver + silencer: ", "n/a")
	var g1: Dictionary = arms._g
	print("mods on assault rifle: recoil %.2f -> %.2f, noise %.0f -> %.0f m, magazine %d -> %d, zoom %.2f -> %.1f" % [
		g0["recoil"], g1["recoil"], g0["noise"], g1["noise"], g0["mag"], g1["mag"], g0["zoom"], g1["zoom"]])
	arms.hold("revolver")
	print("  revolver: ", arms.attach("silencer"))
	arms.hold("assault_rifle")
	arms.attach("red_dot")
	player.aim_at(tank.global_position + Vector3(0, 1.3, 0))
	await _snap("18_rifle_hip")
	Input.action_press("aim")
	await _wait(0.6)
	await _snap("19_rifle_red_dot")
	arms.hold("sniper_rifle")
	await _wait(1.2)
	player.aim_at(tank.global_position + Vector3(0, 1.5, 0))
	await _snap("20_scope")
	Input.action_release("aim")
	arms.hold("shotgun")
	await _wait(0.5)
	await _snap("21_shotgun")

	# --- melee
	dummy.health = 9999.0
	st.stamina = 100.0
	player.global_position = dummy.global_position + Vector3(0, 0.1, 1.5)
	await _wait(0.3)
	arms.hold("sword")
	player.aim_at(dummy.global_position + Vector3(0, 1.2, 0))
	await _wait(0.3)
	var chain: Array[String] = []
	for i in 3:
		arms._start_attack(false)
		await _wait(float(Weapons.MELEE["sword"]["windup"]) + 0.08)
		chain.append("%.0f" % dummy.last_damage)
		await _wait(float(Weapons.MELEE["sword"]["cool"]) + 0.05)
	print("sword, three light blows in a row: ", chain, "  (third is the chain finisher)")
	await _wait(1.2)
	arms._start_attack(true)
	await _wait(0.2)
	await _snap("22_sword_swing")
	await _wait(0.5)
	print("sword heavy blow: %.0f  stamina left %.0f" % [dummy.last_damage, st.stamina])
	st.stamina = 100.0
	st.health = 100.0
	var h0 := st.health
	print("blow with no guard: ", player.melee_hit(20.0, 0.0, dummy), "  health %.0f -> %.0f" % [h0, st.health])
	Input.action_press("aim")
	for i in 4:
		await get_tree().physics_frame
	print("blow just after raising the guard: ", player.melee_hit(20.0, 0.0, dummy), "  health %.0f" % st.health)
	arms._start_attack(false)
	await _wait(0.4)
	print("counter after the parry: %.0f" % dummy.last_damage)
	Input.action_press("aim")
	await _wait(0.8)
	await _snap("23_sword_block")
	h0 = st.health
	print("blow on a held guard: ", player.melee_hit(20.0, 0.0, dummy), "  health %.0f -> %.0f" % [h0, st.health])
	Input.action_release("aim")
	await _wait(0.2)
	var p0 := player.global_position
	arms.dodge()
	await _wait(0.1)
	print("blow during a dodge: ", player.melee_hit(20.0, 0.0, dummy), "  health %.0f" % st.health)
	await _wait(0.5)
	print("dodge moved %.1f m" % player.global_position.distance_to(p0))
	for id in ["knife", "ice_pick", "axe"]:
		arms.hold(id)
		st.stamina = 100.0
		player.global_position = dummy.global_position + Vector3(0, 0.1, 1.4)
		await _wait(0.5)
		player.aim_at(dummy.global_position + Vector3(0, 1.2, 0))
		tank.last_damage = 0.0
		arms._start_attack(false)
		await _wait(float(Weapons.MELEE[id]["windup"]) + 0.1)
		print("  %-9s light blow %.0f" % [id, dummy.last_damage])
		await _wait(0.8)

	# --- line-up picture
	dummy.queue_free()
	tank.queue_free()
	await _wait(0.2)
	player.global_position = village._w(Vector2(0, 100), 0.3)
	var lineup: Array[Enemy] = []
	var wi := 0
	for w in ["pistol", "assault_rifle", "axe", "sniper_rifle"]:
		var e := enemies.raider(w, village._w(Vector2(-3.0 + wi * 1.6, 95.5), 0.3))
		e.passive = true
		e.rotation.y = PI
		lineup.append(e)
		wi += 1
	var lw := enemies.wolf(village._w(Vector2(3.6, 96.5), 0.3))
	lw.passive = true
	lw.rotation.y = PI * 0.6
	lineup.append(lw)
	arms.hold("")
	await _wait(0.6)
	player.aim_at(village._w(Vector2(0.4, 95.5), 1.0))
	await _snap("24_enemies")
	for e in lineup:
		e.queue_free()
	await _wait(0.2)

	# --- a live gunner
	st.health = 100.0
	st.bleeding = 0.0
	st.warmth = 100.0
	var gunner := enemies.raider("smg", village._w(Vector2(0, 76), 0.3))
	gunner.rotation.y = PI
	gunner._wander_t = 6.0
	gunner._wander = Vector3.INF
	arms.hold("assault_rifle")
	arms.reload()
	player.aim_at(gunner.global_position + Vector3(0, 1.2, 0))
	var t := 0.0
	while t < 7.0 and st.health > 99.0:
		await _wait(0.25)
		t += 0.25
	print("gunner: state=%s after %.1f s, player health %.0f, distance %.0f m" % [gunner.state, t, st.health, gunner.global_position.distance_to(player.global_position)])
	await _snap("25_firefight")
	t = 0.0
	Input.action_press("aim")
	Input.action_press("fire")
	while t < 10.0 and gunner.state != "dead":
		player.aim_at(gunner.global_position + Vector3(0, 1.2, 0))
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Input.action_release("fire")
	Input.action_release("aim")
	var bags := 0
	for n in get_tree().get_nodes_in_group("loot"):
		if (n as LootBox).dynamic:
			bags += 1
			print("  body holds ", (n as LootBox).items)
	print("shot the gunner: state=%s in %.1f s, bodies to search=%d, player health %.0f" % [
		gunner.state, t, bags, st.health])

	# --- wolves, and a flare
	st.health = 100.0
	st.bleeding = 0.0
	arms.hold("sword")
	var pack: Array[Wolf] = []
	for i in 3:
		pack.append(enemies.wolf(village._w(Vector2(-6.0 + i * 6.0, 122), 0.4)))
	t = 0.0
	while t < 14.0 and st.health > 99.0:
		await _wait(0.25)
		t += 0.25
	print("wolves: first bite after %.1f s (%s), health %.0f, states %s" % [t, arms.last_melee, st.health, pack.map(func(w: Wolf) -> String: return w.state)])
	await _snap("26_wolves")
	arms.hold("flare_gun")
	arms.reload()
	await _wait(2.2)
	player.aim_at(player.global_position + Vector3(0, -0.5, 3.0))
	await _wait(0.1)
	arms.fire()
	await _wait(1.0)
	print("after a flare at their feet: states %s" % [pack.map(func(w: Wolf) -> String: return w.state)])
	await _snap("27_flare")

	# --- saving
	st.health = 80.0
	arms.hold("assault_rifle")
	enemies.dead.append("raider_3")
	var saved := arms.to_dict()
	print("save ok=", SaveGame.save(self))
	arms.detach("grip")
	arms.st("assault_rifle")["loaded"] = 0
	arms.hold("knife")
	enemies.dead.clear()
	print("load ok=", SaveGame.load_game(self))
	await _wait(0.3)
	print("after load: weapons identical=%s  held=%s  dead=%s" % [arms.to_dict() == saved, arms.held, enemies.dead])
	get_tree().quit()


## Scripted check of survival, gear, chests and saving.
func _surv_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	SaveGame.path = "user://test_save.json"
	var st := player.stats
	var inv := player.inv
	await get_tree().create_timer(0.5).timeout
	print("start: warm=%d weight=%.1f/%.0f speed=%.2f" % [inv.warmth(), inv.weight(), inv.capacity(), st.speed_mult()])
	var w0 := st.warmth
	for i in 600:
		st.tick(0.1, false, true, false, 0, 1.0)
	print("60 s storm, light clothes: warmth %.0f -> %.0f" % [w0, st.warmth])
	var cold := st.warmth
	for i in 300:
		st.tick(0.1, false, false, false, 2, 1.0)
	print("30 s in heated house: warmth %.0f -> %.0f" % [cold, st.warmth])
	var chest: LootBox = null
	for c in village.houses[4].get_children():
		if c is LootBox:
			chest = c
	print("chest ", chest.id, " holds ", chest.items)
	var cam_at := chest.global_position
	player.global_position = village.houses[4].to_global(Vector3(1.5, Chalet.Y0 + 0.1, 0.5))
	player.look_at(Vector3(cam_at.x, player.global_position.y, cam_at.z))
	screen.open(chest)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/16_inventory.png")
	print("shelter in house 4 = ", village.shelter_at(player.global_position), "  prompt='", player.prompt, "'")
	screen._take_all()
	screen._use("parka")
	screen._use("wool_hat")
	screen.close()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/17_chest.png")
	st.warmth = 100.0
	for i in 600:
		st.tick(0.1, false, true, false, 0, 0.1)
	print("60 s calm with parka+hat (warm=%d): warmth -> %.0f, speed=%.2f" % [inv.warmth(), st.warmth, st.speed_mult()])
	for i in 100:
		st.tick(0.1, false, true, true, 0, 0.1)
	print("10 s in the lake: warmth -> %.0f wet=%.1f" % [st.warmth, st.wet])
	st.fall(13.0)
	print("fall 13 m/s: health=%.0f sprain=%s speed=%.2f status=%s" % [st.health, st.sprain, st.speed_mult(), st.status()])
	inv.add("scrap", 40)
	print("with 40 scrap: load=%.2f overloaded=%s can_sprint=%s" % [st.load_ratio(), st.overloaded(), st.can_sprint()])
	inv.remove("scrap", 1)
	player.drop_item("scrap")
	print("save ok=", SaveGame.save(self))
	var s_health := st.health
	var s_warmth := st.warmth
	var s_items: Dictionary = inv.items.duplicate()
	var s_eq: Dictionary = inv.equipped.duplicate()
	var s_chest: Dictionary = chest.items.duplicate()
	var s_pos := player.global_position
	inv.remove("scrap", 39)
	inv.unequip("body")
	st.health = 5.0
	chest.put("fuel_can", 3)
	player.global_position += Vector3(30, 0, 0)
	print("load ok=", SaveGame.load_game(self))
	await get_tree().process_frame
	await get_tree().process_frame
	var same: bool = absf(st.health - s_health) < 0.5 and absf(st.warmth - s_warmth) < 1.0 and inv.items == s_items \
		and inv.equipped == s_eq and chest.items == s_chest and player.global_position.distance_to(s_pos) < 0.3
	var bags := 0
	for n in get_tree().get_nodes_in_group("loot"):
		if (n as LootBox).dynamic and not n.is_queued_for_deletion():
			bags += 1
	print("after load identical=", same, " dropped bags=", bags)
	if not same:
		print("  differs: health %.1f/%.1f warmth %.1f/%.1f items %s eq %s chest %s moved %.2f" % [st.health, s_health, st.warmth, s_warmth, inv.items == s_items, inv.equipped == s_eq, chest.items == s_chest, player.global_position.distance_to(s_pos)])
	st.hurt(500.0)
	await get_tree().process_frame
	print("after death: health=%.0f at spawn=%s" % [st.health, player.global_position.distance_to(player.spawn) < 1.0])
	get_tree().quit()


func _make_noise_textures() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 5
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = n
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n2.frequency = 0.03
	n2.fractal_octaves = 5
	normal_tex = NoiseTexture2D.new()
	normal_tex.width = 512
	normal_tex.height = 512
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 6.0
	normal_tex.generate_mipmaps = true
	normal_tex.noise = n2


func _make_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://world/sky.gdshader")
	sky_mat.set_shader_parameter("noise_tex", noise_tex)
	sky_mat.set_shader_parameter("glow_dir", GLOW_DIR.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.21, 0.29, 0.46)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX keeps bright lamps and snow from burning out to flat white the way film does
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.tonemap_agx_contrast = 1.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.17, 0.28)
	env.fog_density = 0.0008
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.75, 0.84, 1.0)
	env.volumetric_fog_emission = Color(0.03, 0.05, 0.09)
	env.volumetric_fog_emission_energy = 0.6
	env.volumetric_fog_length = 220.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# low twilight light from the glowing part of the horizon
	sun = DirectionalLight3D.new()
	var g := GLOW_DIR.normalized()
	var travel := (-g * cos(deg_to_rad(13.0)) + Vector3.DOWN * sin(deg_to_rad(13.0))).normalized()
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, travel)
	sun.light_color = Color(0.62, 0.70, 1.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 320.0
	sun.light_volumetric_fog_energy = 0.12

	# soft green light from the aurora overhead
	aurora_light = DirectionalLight3D.new()
	add_child(aurora_light)
	aurora_light.look_at_from_position(Vector3.ZERO, Vector3(0.1, -1.0, 0.25).normalized())
	aurora_light.light_color = Color(0.55, 0.9, 0.85)
	aurora_light.light_energy = 0.05
	aurora_light.light_volumetric_fog_energy = 0.0
	if GameMode.summer():
		_summer_environment()


## Arctic summer: the midnight sun stands low but never sets, a clear blue sky, warm light,
## a thin haze over the valley instead of the winter night.
func _summer_environment() -> void:
	var ps := PhysicalSkyMaterial.new()
	ps.rayleigh_coefficient = 2.2
	ps.mie_coefficient = 0.003
	ps.mie_eccentricity = 0.8
	ps.turbidity = 3.0
	ps.sun_disk_scale = 1.4
	ps.ground_color = Color(0.22, 0.26, 0.2)
	ps.energy_multiplier = 1.6
	env.sky.sky_material = ps
	env.sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_exposure = 1.0
	env.tonemap_agx_contrast = 1.15
	env.adjustment_saturation = 1.1
	env.fog_light_color = Color(0.62, 0.72, 0.86)
	env.fog_density = 0.00035
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.25
	env.volumetric_fog_density = 0.0015
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	# afternoon sun from the south-west, 32 degrees up
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.55, -sin(deg_to_rad(32.0)), 0.62).normalized())
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 2.2
	sun.light_volumetric_fog_energy = 0.15
	aurora_light.light_energy = 0.0
	aurora_light.visible = false


# ---------------------------------------------------------------- screenshots

func _shot_mode() -> void:
	weather.auto_cycle = false
	AudioServer.set_bus_mute(0, true)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	var v := Terrain.VILLAGE_POS
	var l := Terrain.LAKE_POS
	# [name, eye xz, eye height above ground, look-at xz, look height offset, storm]
	var shots := [
		["1_valley", Vector2(v.x - 60, v.y + 150), 3.0, Vector2(l.x, l.y - 400), 120.0, 0.1],
		["2_lake", Vector2(l.x + 150, l.y + 60), 1.7, Vector2(l.x - 200, l.y - 300), 40.0, 0.1],
		["3_forest", Vector2(40, 60), 1.7, Vector2(200, -300), 30.0, 0.3],
		["4_overview", Vector2(0, 900), 420.0, Vector2(0, 0), -100.0, 0.0],
		["5_storm", Vector2(v.x - 60, v.y + 150), 1.7, Vector2(l.x, l.y), 10.0, 1.0],
		["7_water", Vector2(Lake.HOLE_C.x + 62, Lake.HOLE_C.y + 24), 3.2, Lake.HOLE_C, -22.0, 0.05],
		["8_tree", Vector2(52, 60), 1.7, Vector2(120, -40), 6.0, 0.05],
		["9_plaza", Vector2(v.x + 7, v.y + 36), 1.7, Vector2(v.x, v.y - 10), 5.0, 0.1],
		["10_street", Vector2(v.x, v.y + 122), 1.7, Vector2(v.x, v.y), 3.0, 0.15],
		["11_market", Vector2(v.x - 9, v.y + 9), 1.7, Vector2(v.x + 16, v.y - 14), 1.0, 0.05],
		["12_inside", Vector2(v.x + 33.5, v.y - 26.5), 1.75, Vector2(v.x + 40, v.y - 33), -0.4, 0.05],
		["13_village_air", Vector2(v.x - 95, v.y + 125), 48.0, Vector2(v.x, v.y - 10), -45.0, 0.0],
		["14_cable", Vector2(v.x + 60, v.y - 78), 1.7, Vector2(v.x + 130, v.y - 170), 22.0, 0.1],
		["15_shop", Vector2(v.x - 22, v.y - 19), 1.7, Vector2(v.x - 33, v.y - 30), 0.6, 0.05],
		["6_ground", Vector2(v.x - 40, v.y + 140), 1.7, Vector2(v.x - 60, v.y + 100), -1.5, 0.1],
		["16_meadow", Vector2(v.x - 70, v.y + 60), 1.6, Vector2(v.x - 130, v.y + 10), -1.2, 0.05],
		["17_flowers", Vector2(v.x - 150, v.y + 40), 0.9, Vector2(v.x - 160, v.y + 30), -0.7, 0.05],
		["20_trees_near", Vector2(40, 60), 1.7, Vector2(60, 20), 4.0, 0.05],
		["21_trees_edge", Vector2(-20, 140), 2.5, Vector2(80, -60), 8.0, 0.05],
		["22_pier", Vector2(-112, 62), 2.2, Vector2(-237, 187), -3.0, 0.05],
		["23_grauwasser", Vector2(-120 + 30, 1420 + 26), 2.0, Vector2(-120 - 20, 1420 - 8), -1.0, 0.05],
		["24_grauwasser_street", Vector2(-120 + 95, 1420 + 2), 1.8, Vector2(-120 - 40, 1420), -0.5, 0.05],
	]
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	if only != "":
		shots = shots.filter(func(sh: Array) -> bool: return (sh[0] as String) in only.split(","))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	for i in 90:
		await get_tree().process_frame
	for s in shots:
		var e: Vector2 = s[1]
		var t: Vector2 = s[3]
		var eye := Vector3(e.x, terrain.surface_at(e.x, e.y) + s[2], e.y)
		cam.global_position = eye
		cam.look_at(Vector3(t.x, eye.y + s[4], t.y))
		weather.storm = s[5]
		weather.target_storm = s[5]
		weather.follow = cam
		if s[0] == "6_ground":
			for k in 8:
				var p := eye + Vector3(-1.5 - k * 0.3, 0, -3.0 - k * 0.8)
				p.y = terrain.height_at(p.x, p.z)
				prints.add_print(p, 0.35, k % 2 == 0)
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % s[0])
		print("shot ", s[0], " fps ", Engine.get_frames_per_second(), " tris ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


## Close-ups of the Blender-made assets: the six people (standing, walking, aiming),
## the scanned guns, and street, forest and props.
func _scan_shot() -> void:
	weather.auto_cycle = false
	AudioServer.set_bus_mute(0, true)
	player.set_process_unhandled_input(false)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	weather.storm = 0.05
	weather.target_storm = 0.05
	weather.follow = cam
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var v := Terrain.VILLAGE_POS
	var base := Vector2(v.x - 40, v.y + 120)
	var looks := [
		{"body": "m_work", "coat": "olive", "trousers": "black", "hat": "hood"},
		{"body": "f_young", "coat": "red", "trousers": "navy", "hat": "beanie", "hat_col": "cream", "scarf": "yellow", "pack": false},
		{"body": "m_old", "coat": "fur_brown", "trousers": "grey", "hat": "none", "hair": "white", "pack": false},
		{"body": "m_dark", "coat": "navy", "trousers": "black", "hat": "ushanka", "hat_col": "fur_dark", "pack": true},
		{"body": "f_old", "coat": "teal", "trousers": "leather", "hat": "none", "scarf": "red", "pack": false},
		{"body": "m_asian", "coat": "orange", "trousers": "navy", "hat": "helmet", "vest": true, "pack": false},
	]
	var figs := []
	for i in looks.size():
		var m := Humanoid.build(looks[i])
		add_child(m)
		var x := base.x + (i - 2.5) * 1.3
		m.global_position = Vector3(x, terrain.height_at(x, base.y), base.y)
		figs.append(m)
	# poses: 1 walks, 2 aims a pistol, 3 aims the rifle, others stand
	var pistol := Weapons.model("pistol", [])
	pistol.rotation.x = -PI * 0.5
	(figs[1].get_meta("hand_r") as Node3D).add_child(pistol)
	var rifle := Weapons.model("marksman_rifle", [])
	rifle.rotation.x = -PI * 0.5
	(figs[3].get_meta("hand_r") as Node3D).add_child(rifle)
	for k in 4:
		Humanoid.walk(figs[0], 1.2, 1.0, true, 1.0)
		Humanoid.walk(figs[2], 2.6, 1.0, true, 1.0)
	(figs[1].get_meta("arm_r") as Node3D).rotation = Vector3(PI * 0.5, -0.12, 0)
	(figs[1].get_meta("elbow_r") as Node3D).rotation.x = 0.08
	(figs[1].get_meta("arm_l") as Node3D).rotation = Vector3(PI * 0.5 - 0.12, -0.35, 0)
	(figs[1].get_meta("elbow_l") as Node3D).rotation.x = 0.12
	(figs[3].get_meta("arm_r") as Node3D).rotation = Vector3(PI * 0.5, 0.12, 0)
	(figs[3].get_meta("elbow_r") as Node3D).rotation.x = 0.08
	(figs[3].get_meta("arm_l") as Node3D).rotation = Vector3(PI * 0.5 - 0.12, -0.62, 0)
	(figs[3].get_meta("elbow_l") as Node3D).rotation.x = 0.3
	var lamp := OmniLight3D.new()     # a work lamp, the polar night is dark
	lamp.omni_range = 22.0
	lamp.light_energy = 2.2
	lamp.light_color = Color(1.0, 0.9, 0.75)
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.global_position = Vector3(base.x + 4.0, terrain.height_at(base.x, base.y) + 3.2, base.y - 3.5)
	# the scanned props in a row behind the people
	var props := ["metal_trash_can", "trashbag", "Barrel_01", "wooden_crate_01", "painted_wooden_bench", "fire_hydrant", "propane_tank", "old_tyre", "Lantern_01"]
	for i in props.size():
		var pm := ModelLib.spawn(props[i])
		if pm:
			add_child(pm)
			var px := base.x + 6.0 + i * 1.1
			pm.global_position = Vector3(px, terrain.height_at(px, base.y), base.y)
	# a tree of the forest to look at
	var tree_at := Vector3.ZERO
	for mmi in forest.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (mmi as MultiMeshInstance3D).multimesh
		if mm and mm.instance_count > 1000 and mm.mesh and mm.mesh.get_aabb().size.y > 8.0:
			tree_at = (mmi as Node3D).global_transform * mm.get_instance_transform(mm.instance_count / 2).origin
			break
	for i in 90:
		await get_tree().process_frame
	var gy := terrain.height_at(base.x, base.y)
	var shots := [
		["s1_people", Vector3(base.x, gy + 1.3, base.y - 6.5), Vector3(base.x, gy + 0.95, base.y)],
		["s2_faces", Vector3(base.x - 1.3, gy + 1.65, base.y - 2.4), Vector3(base.x - 1.3, gy + 1.5, base.y)],
		["s3_aim", Vector3(base.x + 3.2, gy + 1.5, base.y - 1.8), Vector3(base.x - 0.2, gy + 1.3, base.y)],
		["s4_side", Vector3(base.x - 5.0, gy + 1.4, base.y + 0.3), Vector3(base.x, gy + 1.0, base.y)],
		["s5_street", Vector3(v.x, terrain.surface_at(v.x, v.y + 60) + 1.7, v.y + 60), Vector3(v.x, terrain.surface_at(v.x, v.y + 60) + 1.2, v.y)],
		["s6_forest", Vector3(tree_at.x + 9, terrain.surface_at(tree_at.x + 9, tree_at.z + 9) + 1.7, tree_at.z + 9), Vector3(tree_at.x, terrain.height_at(tree_at.x, tree_at.z) + 5.0, tree_at.z)],
		["s8_forest_far", Vector3(tree_at.x + 40, terrain.surface_at(tree_at.x + 40, tree_at.z + 40) + 1.7, tree_at.z + 40), Vector3(tree_at.x, terrain.height_at(tree_at.x, tree_at.z) + 4.0, tree_at.z)],
		["s7_props", Vector3(base.x + 10.4, gy + 1.5, base.y - 3.8), Vector3(base.x + 10.4, gy + 0.4, base.y)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % s[0])
		print("shot ", s[0], " fps ", Engine.get_frames_per_second(), " tris ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


# ------------------------------------------------------------ vehicles test
func _vput(v: Vehicle, p: Vector2, yaw: float) -> void:
	v.scripted = true
	v.test_input = Vector3.ZERO
	v.place(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, terrain.surface_at(p.x, p.y) + 0.35, p.y)))
	await _wait(1.6)


## Full throttle for `secs`, then full brake. Returns [speed reached, metres to get there, metres to stop].
func _sprint_stop(v: Vehicle, secs: float) -> Array:
	var a := v.global_position
	v.test_input = Vector3(1, 0, 0)
	await _wait(secs)
	var speed := v.linear_velocity.length()
	var b := v.global_position
	v.test_input = Vector3(-1, 0, 0)
	var t := 0.0
	while t < 8.0 and v.linear_velocity.dot(-v.global_basis.z) > 0.6:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	v.test_input = Vector3(0, 0, 1)
	var c := v.global_position
	return [speed, a.distance_to(b), b.distance_to(c)]


func _cam_at(cam: Camera3D, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()


## Scripted check of the vehicles: driving, surfaces, fuel, damage, winch, ice, saving.
func _drive_test() -> void:
	AudioServer.set_bus_mute(0, true)
	SaveGame.path = "user://test_save.json"
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	var st := player.stats
	var vp := Terrain.VILLAGE_POS
	var cam := Camera3D.new()
	cam.far = 5000.0
	add_child(cam)
	var sm := garage.by_id("snowmobile_1")
	var pk := garage.by_id("pickup_1")
	var off := garage.by_id("offroader_1")
	var tr := garage.by_id("tracked_1")
	var all: Array[Vehicle] = [sm, pk, off, tr]
	await _wait(2.0)
	print("--- parked where the game puts them")
	for v in all:
		var g := v.global_position
		print("%-16s y above ground %.2f  upright %.2f  wheels on ground %d/%d  fuel %.0f/%.0f  engine %.0f  cargo %s" % [
			v.cfg["name"], g.y - terrain.surface_at(g.x, g.z), v.global_basis.y.y,
			v.wheels.filter(func(w: VehicleWheel3D) -> bool: return w.is_in_contact()).size(), v.wheels.size(),
			v.fuel, v.tank(), v.health, v.cargo.items])
	_cam_at(cam, sm.global_position + Vector3(4.5, 1.8, 3.5), sm.global_position + Vector3(0, 0.6, 0))
	await _snap("28_snowmobile")
	_cam_at(cam, pk.global_position + Vector3(-6, 2.2, -5), pk.global_position + Vector3(0, 0.9, 0))
	await _snap("29_pickup")
	_cam_at(cam, off.global_position + Vector3(5.5, 2.2, 4.5), off.global_position + Vector3(0, 1.0, 0))
	await _snap("30_offroader")
	_cam_at(cam, tr.global_position + Vector3(7, 3.0, 6), tr.global_position + Vector3(0, 1.2, 0))
	await _snap("31_tracked")

	# --- a clear strip of thick ice and a field of deep snow
	var ice_at := Vector2.ZERO
	var thin_at := Vector2.ZERO
	for i in 4000:
		var p := Terrain.LAKE_POS + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		var ok := true
		var thin_ok := Lake.hole(p) > 75.0 and terrain.height_at(p.x, p.y) < Terrain.LAKE_LEVEL - 2.5
		for s in 14:
			var q := p + Vector2(0, -s * 12.0)
			if terrain.height_at(q.x, q.y) > Terrain.LAKE_LEVEL - 0.5 or Lake.thickness(q) < 0.58:
				ok = false
		for s in 9:
			var q := p + Vector2((s % 3 - 1) * 4.0, (s / 3 - 1) * 4.0)
			if Lake.thickness(q) > 0.325 or Lake.thickness(q) < 0.29:
				thin_ok = false
		if ok and ice_at == Vector2.ZERO:
			ice_at = p
		if thin_ok and thin_at == Vector2.ZERO:
			thin_at = p
	print("thick ice strip starts at %s (%.0f cm), thin patch at %s (%.0f cm, carries %.0f kg)" % [
		ice_at, Lake.thickness(ice_at) * 100.0, thin_at, Lake.thickness(thin_at) * 100.0, Lake.capacity(thin_at)])
	var snow_at := Vector2(20.0, 40.0)
	for i in 3000:
		var p := Vector2(randf_range(-250, 150), randf_range(-100, 120))
		if p.distance_to(vp) < 190.0 or p.distance_to(Terrain.LAKE_POS) < 330.0:
			continue
		var flat := true
		for s in 9:
			var q := p + Vector2(0, -s * 8.0)
			if terrain.normal_at(q.x, q.y).y < 0.985:
				flat = false
		if not flat:
			continue
		var clear := true
		for s in 10:
			var a := p + Vector2(0, 4.0 - s * 8.0)
			var b := a + Vector2(0, -8.0)
			var q3 := PhysicsRayQueryParameters3D.create(Vector3(a.x, terrain.height_at(a.x, a.y) + 1.0, a.y), Vector3(b.x, terrain.height_at(b.x, b.y) + 1.0, b.y))
			for off_x in [-1.5, 1.5]:
				var ox: float = off_x
				q3.from.x = a.x + ox
				q3.to.x = b.x + ox
				if not get_world_3d().direct_space_state.intersect_ray(q3).is_empty():
					clear = false
		if clear:
			snow_at = p
			break

	print("--- 4 s full throttle, then full brake (speed km/h, metres to stop)")
	var street := vp + Vector2(0, 118)
	for v in all:
		v.fuel = v.tank()
		v.health = 100.0
		var row := "%-16s" % v.cfg["name"]
		for place in [["packed", street], ["ice", ice_at], ["snow", snow_at]]:
			var where: Vector2 = place[1]
			await _vput(v, where, 0.0)
			var z0 := v.global_position
			var r: Array = await _sprint_stop(v, 4.0)
			var moved := v.to_local(z0)
			row += "   %s(%s): %3.0f km/h, stop %4.1f m%s" % [place[0], v.surface, float(r[0]) * 3.6, r[2],
				"" if moved.z > 5.0 and Vector2(z0.x, z0.z).distance_to(where) < 2.0 else "  [moved %s from %s]" % [moved, z0]]
			if v.last_crash > 0.0:
				row += " [crash %.0f]" % v.last_crash
				v.last_crash = 0.0
				v.health = 100.0
		print(row)
		await _vput(v, vp + Vector2(-60.0 + all.find(v) * 12.0, 126.0), 0.0)
	# chains
	pk.upgrades.append("snow_chains")
	pk._apply_upgrades()
	await _vput(pk, ice_at, 0.0)
	var rc: Array = await _sprint_stop(pk, 4.0)
	print("pickup with snow chains on ice: %.0f km/h, stop %.1f m" % [float(rc[0]) * 3.6, rc[2]])
	pk.upgrades.clear()
	pk._apply_upgrades()
	await _vput(pk, vp + Vector2(-48, 126), 0.0)

	print("--- steering: 3 s throttle with the wheel to the right, on ice")
	for v in all:
		await _vput(v, ice_at + Vector2(0, -40), 0.0)
		v.test_input = Vector3(0.7, 1, 0)
		await _wait(3.0)
		print("%-16s heading changed %.0f° (minus = to the right), upright %.2f, %.0f km/h, engine %.0f, fuel %.0f, on %s" % [v.cfg["name"], rad_to_deg(v.global_rotation.y), v.global_basis.y.y, v.speed_kmh(), v.health, v.fuel, v.surface])
		v.test_input = Vector3(0, 0, 1)
		await _vput(v, vp + Vector2(-60.0 + all.find(v) * 12.0, 126.0), 0.0)

	print("--- getting in and out, fuel")
	await _vput(pk, street, 0.0)
	pk.scripted = false
	var door: Vector3 = pk.to_global(Vector3(-2.3, 0.2, -0.35))
	player.global_position = door
	await _wait(0.4)
	player.aim_at(pk.to_global(Vector3(-0.95, 1.3, -0.35)))
	await _wait(0.2)
	print("looking at the door: prompt '%s'" % player.prompt)
	if player._target:
		player._target.interact(player)
	await _wait(0.5)
	print("after E: driving=%s  hud shows cabin shelter, arms hidden=%s" % [player.vehicle != null, not player.arms.visible])
	await _snap("32_pickup_chase")
	player.third_person = false
	player._set_view()
	await _wait(0.3)
	await _snap("33_pickup_inside")
	player.third_person = true
	player._set_view()
	pk.fuel = 0.05
	Input.action_press("move_forward")
	await _wait(4.0)
	var dry_speed := pk.linear_velocity.length()
	await _wait(3.0)
	Input.action_release("move_forward")
	print("with 0.05 l in the tank: fuel %.2f, speed after 4 s %.1f km/h, after 7 s %.1f km/h" % [pk.fuel, dry_speed * 3.6, pk.speed_kmh()])
	Input.action_press("jump")
	await _wait(2.0)
	Input.action_release("jump")
	var gone := player.exit_vehicle()
	await _wait(0.3)
	print("got out=%s, standing %.1f m from the pickup, on floor=%s" % [gone, player.global_position.distance_to(pk.global_position), player.is_on_floor()])
	player.inv.add("fuel_can", 2)
	player.global_position = pk.to_global(Vector3(0, 0.2, -4.2))
	await _wait(0.4)
	player.aim_at(pk.to_global(Vector3(0, 1.0, -2.5)))
	await _wait(0.2)
	print("looking at the bonnet: prompt '%s'" % player.prompt)
	if player._target:
		player._target.interact(player)
	print("after pouring: fuel %.0f l, cans left %d" % [pk.fuel, player.inv.count("fuel_can")])
	player.global_position = pk.to_global(Vector3(0, 0.2, 4.2))
	await _wait(0.4)
	player.aim_at(pk.to_global(Vector3(0, 1.0, 2.5)))
	await _wait(0.2)
	print("looking at the back: prompt '%s', cargo %s" % [player.prompt, pk.cargo.items])

	print("--- crash, bullets, repair, armour")
	pk.fuel = pk.tank()
	pk.health = 100.0
	await _vput(pk, vp + Vector2(0, 100), 0.0)
	pk.scripted = false
	player.enter_vehicle(pk)
	st.health = 100.0
	pk.scripted = true
	pk.test_input = Vector3(1, 0, 0)
	var t := 0.0
	var fastest := 0.0
	while t < 12.0 and pk.last_crash == 0.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		fastest = maxf(fastest, pk.linear_velocity.length())
	pk.test_input = Vector3(0, 0, 1)
	await _wait(1.0)
	print("drove up the street into the plaza at up to %.0f km/h: hit of %.1f m/s, engine %.0f %%, driver health %.0f" % [
		fastest * 3.6, pk.last_crash, pk.health, st.health])
	await _snap("34_crash")
	player.exit_vehicle(true)
	st.health = 100.0
	var h0 := pk.health
	pk.hit(40.0, pk.global_position, Vector3.FORWARD, 25.0, null)
	print("a rifle bullet (40): engine %.1f -> %.1f" % [h0, pk.health])
	player.inv.add("armor_plates")
	pk.health = 100.0
	var m0 := pk.mass
	var top0 := pk.top_speed()
	print("bonnet offers: '%s'" % pk.service_action(player)[1])
	pk.service(player)
	pk.hit(40.0, pk.global_position, Vector3.FORWARD, 25.0, null)
	print("with armour plates: engine 100 -> %.1f, mass %.0f -> %.0f kg, top speed %.0f -> %.0f km/h" % [pk.health, m0, pk.mass, top0 * 3.6, pk.top_speed() * 3.6])
	pk.health = 30.0
	player.inv.add("scrap", 2)
	print("bonnet offers: '%s'" % pk.service_action(player)[1])
	pk.service(player)
	pk.service(player)
	print("after two scrap: engine %.0f %%, scrap left %d" % [pk.health, player.inv.count("scrap")])

	print("--- winch")
	await _vput(off, vp + Vector2(0, 118), 0.0)
	await _vput(sm, vp + Vector2(0, 100), 1.2)
	off.scripted = false
	player.enter_vehicle(off)
	off.scripted = true
	var gap0 := off.global_position.distance_to(sm.global_position)
	off.toggle_winch()
	await _wait(0.4)
	_cam_at(cam, off.global_position + Vector3(7, 3, 2), (off.global_position + sm.global_position) * 0.5)
	await _snap("35_winch")
	player._set_view()
	await _wait(4.0)
	print("off-roader winches the snowmobile: gap %.1f m -> %.1f m, still pulling=%s" % [gap0, off.global_position.distance_to(sm.global_position), off.winching()])
	if off.winching():
		off.toggle_winch()
	await _vput(sm, vp + Vector2(-60, 126), 0.0)
	# pull itself towards a house wall
	await _vput(off, vp + Vector2(0, 65), -PI * 0.5)
	var o0 := off.global_position
	off.toggle_winch()
	var hooked := off.winching()
	await _wait(3.0)
	print("hooked on the house ahead=%s: pulled itself %.1f m with no throttle" % [hooked, o0.distance_to(off.global_position)])
	if off.winching():
		off.toggle_winch()
	pk.toggle_winch()
	player.exit_vehicle(true)

	print("--- thin ice (%.0f cm, carries %.0f kg)" % [Lake.thickness(thin_at) * 100.0, Lake.capacity(thin_at)])
	for v in [sm, pk]:
		var veh: Vehicle = v
		if veh == pk:
			veh.upgrades.clear()
			veh._apply_upgrades()
		await _vput(veh, thin_at, 0.0)
		await _wait(3.0)
		print("%-16s %4.0f kg: sunk=%s" % [veh.cfg["name"], veh.total_mass(), veh.sunk])
		await _vput(veh, vp + Vector2(-60.0 + all.find(veh) * 12.0, 126.0), 0.0)
	var edge := Lake.HOLE_C + Vector2(0, 1) * 70.0
	while Lake.hole(edge) < 14.0 or Lake.hole(edge) > 17.0:
		edge += Vector2(0, 0.5) if Lake.hole(edge) < 14.0 else Vector2(0, -0.5)
	await _vput(sm, edge, 0.0)
	await _wait(2.0)
	await _vput(pk, edge + Vector2(8, 0), 0.0)
	await _wait(2.0)
	print("15 m from the open water (%.0f cm, carries %.0f kg): snowmobile sunk=%s, pickup sunk=%s" % [
		Lake.thickness(edge) * 100.0, Lake.capacity(edge), sm.sunk, pk.sunk])
	await _vput(sm, vp + Vector2(-60, 126), 0.0)
	await _vput(tr, thin_at + Vector2(0, 30), 0.0)
	tr.scripted = false
	player.enter_vehicle(tr)
	tr.scripted = true
	tr.toggle_lights()
	tr.test_input = Vector3(0.6, 0, 0)
	t = 0.0
	while t < 14.0 and not tr.sunk:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var broke_at := tr.global_position
	print("tracked carrier %.0f kg drove onto it: broke through after %.1f s, %.0f m in, ice there %.0f cm" % [
		tr.total_mass(), t, 30.0 - Vector2(broke_at.x, broke_at.z).distance_to(thin_at), Lake.thickness(Vector2(broke_at.x, broke_at.z)) * 100.0])
	tr.test_input = Vector3.ZERO
	await _wait(0.8)
	_cam_at(cam, broke_at + Vector3(9, 4, 8), broke_at)
	await _snap("36_ice_breaks")
	await _wait(5.0)
	_cam_at(cam, broke_at + Vector3(9, 4, 8), broke_at)
	await _snap("37_sunk")
	player._set_view()
	print("6 s later: %.1f m below the ice, lake bed %.1f m below, holes in the ice %d, driver wet=%.1f under water=%s" % [
		Terrain.LAKE_LEVEL - tr.global_position.y, Terrain.LAKE_LEVEL - terrain.height_at(broke_at.x, broke_at.z), lake.breaks.size(), st.wet, player.head_under_water])
	player.exit_vehicle()
	await _wait(1.0)
	print("got out: on the ice=%s (y %.2f, ice at %.2f), %.1f m from the hole centre, in water=%s" % [
		player.is_on_floor(), player.global_position.y, Terrain.LAKE_LEVEL, player.global_position.distance_to(broke_at), lake.in_water(player.global_position)])
	# walking back into the hole
	player.global_position = Vector3(broke_at.x, Terrain.LAKE_LEVEL + 0.3, broke_at.z + 1.0)
	await _wait(2.0)
	print("stepping onto the broken ice: swimming=%s y %.2f" % [player.swimming, player.global_position.y])
	player.global_position = lake.edge_of_break(broke_at)
	await _wait(0.5)

	print("--- save and load")
	await _vput(sm, vp + Vector2(30, 126), 0.7)
	sm.scripted = false
	sm.fuel = 11.5
	sm.health = 64.0
	sm.upgrades.append("aux_tank")
	sm._apply_upgrades()
	sm.cargo.items = {"scrap": 5}
	player.enter_vehicle(sm)
	await _wait(0.3)
	var before := [sm.global_position, sm.fuel, sm.health, sm.upgrades.duplicate(), tr.sunk, lake.breaks.size(), pk.upgrades.duplicate()]
	print("save ok=%s" % SaveGame.save(self))
	player.exit_vehicle(true)
	sm.place(Transform3D(Basis.IDENTITY, Vector3(vp.x, 60, vp.y + 100)))
	sm.fuel = 1.0
	sm.health = 5.0
	sm.upgrades.clear()
	sm.cargo.items = {}
	tr.sunk = false
	lake.set_breaks([])
	print("load ok=%s" % SaveGame.load_game(self))
	await _wait(0.5)
	var after := [sm.global_position, sm.fuel, sm.health, sm.upgrades.duplicate(), tr.sunk, lake.breaks.size(), pk.upgrades.duplicate()]
	print("snowmobile moved %.2f m, fuel %.1f=%.1f, engine %.0f=%.0f, upgrades %s=%s, carrier sunk %s=%s, holes %d=%d, cargo %s, back at the wheel=%s" % [
		(before[0] as Vector3).distance_to(after[0]), before[1], after[1], before[2], after[2], before[3], after[3],
		before[4], after[4], before[5], after[5], sm.cargo.items, player.vehicle == sm])
	print("pickup still sunk after load=%s" % pk.sunk)

	# --- pictures of a drive at night
	sm.fuel = sm.tank()
	sm.health = 100.0
	await _vput(sm, snow_at, 0.0)
	sm.scripted = true
	if not sm.lights_on:
		sm.toggle_lights()
	sm.test_input = Vector3(1, 0.15, 0)
	await _wait(2.5)
	await _snap("38_snowmobile_ride")
	sm.test_input = Vector3(0, 0, 1)
	_cam_at(cam, Vector3(thin_at.x + 40, Terrain.LAKE_LEVEL + 14, thin_at.y + 40), Vector3(thin_at.x, Terrain.LAKE_LEVEL, thin_at.y))
	await _snap("39_thin_ice_from_above")
	get_tree().quit()



# ------------------------------------------------------------ model and HUD pictures
func _look_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var vp := Terrain.VILLAGE_POS
	var at := Vector3(vp.x, terrain.height_at(vp.x, vp.y + 100.0) + 0.1, vp.y + 100.0)
	player.global_position = at
	player.rotation.y = 0.0
	var arms := player.arms
	arms.free_input = true
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.light_color = Color(1.0, 0.95, 0.88)
	add_child(lamp)
	await _wait(1.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	if only == "npcs":
		# villagers idling: talking, arms folded, rubbing hands, weight on one leg, walking
		var acts := ["talk", "fold", "rub", "hip", "walk"]
		var folk: Array[Npc] = []
		for i in acts.size():
			var n := Npc.new()
			n.player = player
			n.setup({"coat": ["red", "olive", "blue", "brown", "grey"][i], "hair": "white" if i == 3 else "brown"})
			add_child(n)
			n.place(at + Vector3(-3.2 + i * 1.6, 0.1, -5.0), PI)
			n.set("_gesture", acts[i])
			n.set("_gesture_t", 99.0)
			if acts[i] == "talk":
				n.set("_talk_t", 99.0)
			folk.append(n)
		player.global_position = at + Vector3(0, 0, 40)     # far enough not to be looked at
		folk[4].roam = 6.0
		folk[4].set("_wander", folk[4].global_position + Vector3(0, 0, 4.5))
		folk[4].set("_wander_t", 99.0)
		lamp.global_position = at + Vector3(0, 2.6, -2.0)
		for f in 3:
			await _wait(0.7)
			_cam_at(cam, at + Vector3(0.0, 1.5, 1.8), at + Vector3(0.0, 1.0, -5.0))
			await _snap("44_npcs_%d" % f)
		_cam_at(cam, at + Vector3(5.5, 1.4, -1.0), folk[4].global_position + Vector3(0, 0.9, 0))
		await _snap("44_npc_walk")
		get_tree().quit()
		return
	if only == "" or only == "people":
		var kinds := ["pistol", "axe", "smg", "shotgun", "sniper_rifle"]
		var row: Array[Enemy] = []
		for i in kinds.size():
			var r := enemies.raider(kinds[i], at + Vector3(-3.2 + i * 1.6, 0.1, -5.0))
			r.passive = true
			r.rotation.y = PI
			if i == 2:
				r.state = "fight"
			if i == 1:
				r.state = "alert"
			row.append(r)
		var w := enemies.wolf(at + Vector3(4.6, 0.1, -4.6))
		w.passive = true
		w.rotation.y = PI * 0.75
		row.append(w)
		lamp.global_position = at + Vector3(0, 2.6, -2.0)
		await _wait(1.2)
		_cam_at(cam, at + Vector3(0.6, 1.5, 1.6), at + Vector3(0.6, 1.0, -5.0))
		await _snap("40_raiders")
		_cam_at(cam, at + Vector3(-1.6, 1.5, -3.2), at + Vector3(-1.6, 1.45, -5.0))
		await _snap("41_raider_close")
		_cam_at(cam, at + Vector3(3.2, 0.9, -2.6), at + Vector3(4.6, 0.6, -4.6))
		await _snap("42_wolf_close")
		for e in row:
			e.queue_free()
	if only == "rooms":
		cam.fov = 72.0
		cam.make_current()
		lamp.light_energy = 1.2
		lamp.omni_range = 12.0
		var n := 61
		# [house index, camera (local), look-at (local), name]
		var views := [
			[0, Vector3(1.5, 1.7, 4.6), Vector3(3.5, 1.0, -4.0), "hotel_lobby"],
			[0, Vector3(-8.8, 1.7, 4.6), Vector3(-6.0, 0.9, -4.0), "hotel_room"],
			[0, Vector3(9.0, 1.7, 1.5), Vector3(5.5, 0.9, -5.0), "hotel_fire"],
			[1, Vector3(-4.6, 1.75, 3.4), Vector3(2.5, 0.9, -2.5), "toyshop"],
			[1, Vector3(4.8, 1.75, 3.4), Vector3(-1.5, 0.9, -3.0), "toyshop_2"],
			[2, Vector3(5.6, 1.75, 4.0), Vector3(-3.5, 0.9, -3.0), "inn"],
			[2, Vector3(-2.2, 1.6, 0.2), Vector3(-4.2, 1.2, -4.0), "inn_bar"],
			[3, Vector3(-3.6, 1.75, 3.4), Vector3(2.0, 1.0, -3.0), "station"],
			[4, Vector3(-3.2, 1.75, 2.8), Vector3(1.5, 0.9, -2.5), "home_a"],
			[4, Vector3(3.2, 1.75, -1.6), Vector3(-1.5, 0.8, 1.8), "home_a2"],
			[5, Vector3(-3.2, 1.75, 2.8), Vector3(1.5, 0.9, -2.5), "home_b"],
			[6, Vector3(-3.2, 1.75, 2.8), Vector3(1.5, 0.9, -2.5), "home_c"],
		]
		# the stairs and the rooms upstairs
		for hi in [0, 4, 5]:
			var hh: Node3D = village.houses[hi]
			if not hh.has_meta("stair"):
				continue
			var st: Dictionary = hh.get_meta("stair")
			var sz: Vector2 = hh.get_meta("size")
			var up := Chalet.Y0 + Chalet.FH + 0.13
			views.append([hi, Vector3(st.xa + 1.6, 1.6, st.zp + 1.8), Vector3(st.xt + 1.0, 2.6, st.z0 + 0.5), "stairs_%d" % hi])
			views.append([hi, Vector3(st.xb + 0.5, up + 1.6, st.zc - 0.6), Vector3(st.xt, up + 0.3, st.z0 + 0.4), "stairwell_%d" % hi])
			views.append([hi, Vector3(sz.x * 0.5 - 0.6, up + 1.6, sz.y * 0.5 - 0.6), Vector3(-1.0, up + 0.6, float(st.zc) + 0.5), "upstairs_%d" % hi])
		for v in views:
			var h: Node3D = village.houses[int(v[0])]
			var from: Vector3 = h.to_global(v[1])
			player.global_position = h.to_global(Vector3(0, 12, 0))
			lamp.global_position = h.to_global(Vector3(0, (v[1] as Vector3).y + 0.8, 1.0))
			_cam_at(cam, from, h.to_global(v[2]))
			await _snap("%d_%s" % [n, str(v[3])])
			n += 1
		var cp := village._w(Vector2(62, -66), 0.0)
		var cb := Basis(Vector3.UP, atan2(-1.0, 1.0))
		player.global_position = cp + Vector3(0, 30, 0)
		lamp.global_position = cp + Vector3(0, 3.0, 0)
		_cam_at(cam, cp + cb * Vector3(0.6, 1.7, 4.2), cp + cb * Vector3(0, 1.3, -4.0))
		await _snap("73_chapel")
	if only == "nature":
		cam.fov = 62.0
		cam.far = 5000.0
		cam.make_current()
		lamp.light_energy = 0.0
		var cb: Vector3 = Wilds.climb.get("base", Vector3(380, 62, -383))
		var cd: Vector3 = Wilds.climb.get("dir", Vector3(0.57, 0, -0.82))
		var c0: Vector2 = Wilds.sites[0]["pos"]
		var g := func(x: float, z: float, up: float) -> Vector3: return Vector3(x, terrain.height_at(x, z) + up, z)
		var views := [
			[g.call(c0.x + 16.0, c0.y + 4.0, 1.7), g.call(c0.x + 30.0, c0.y + 6.0, 6.0), "85_tree_close"],
			[g.call(c0.x + 22.0, c0.y + 20.0, 1.7), g.call(c0.x + 60.0, c0.y + 70.0, 4.0), "86_forest_inside"],
			[cb - cd * 30.0 + Vector3(0, 4, 0), cb + cd * 30.0 + Vector3(0, 30, 0), "87_rock_wall"],
			[cb - cd * 3.0 + Vector3(0, 1.7, 0), cb + cd * 6.0 + Vector3(0, 5.0, 0), "88_rock_close"],
			[g.call(260.0, -20.0, 12.0), g.call(700.0, -700.0, 60.0), "89_mountains"],
			[g.call(-260.0, 220.0, 30.0), g.call(-900.0, 300.0, 120.0), "90_mountains_lake"],
			[g.call(0.0, 0.0, 160.0), g.call(500.0, 700.0, 100.0), "91_peaks_air"],
		]
		for v in views:
			var from: Vector3 = v[0]
			player.global_position = from + Vector3(0, 0.0, 2.0)
			player.velocity = Vector3.ZERO
			_cam_at(cam, from, v[1])
			await _wait(1.0)
			await _snap(str(v[2]))
			print("fps %s: %d" % [v[2], Engine.get_frames_per_second()])
	if only.begins_with("places"):
		cam.fov = 62.0
		cam.far = 5000.0
		cam.make_current()
		lamp.light_energy = 0.0
		var g := func(x: float, z: float, up: float) -> Vector3: return Vector3(x, terrain.height_at(x, z) + up, z)
		var st := Vector3(Places.STATION.x, Places.D["station_h"], Places.STATION.y)
		var ba := Vector3(Places.BASE.x, Places.D["base_h"], Places.BASE.y)
		var br := Vector3(Places.BRIDGE.x, Places.D["bridge_h"], Places.BRIDGE.y)
		var mf: float = Places.D["mine_floor"]
		var mx: float = Places.D["mine_px"]
		var tf: float = Places.D["tunnel_floor"]
		var tz: float = Places.D["tunnel_pz"]
		var b0 := Vector3(terrain.gx(Places.BUNKERS[0][0]), Places.D["bunker_h"][0], terrain.gx(Places.BUNKERS[0][1] - 1))
		var se := g.call(Places.SETTLE.x, Places.SETTLE.y, 0.0) as Vector3
		var tw := g.call(Places.TOWER.x, Places.TOWER.y, 0.0) as Vector3
		var r1: Array = places._road_at("west", 0.22)
		var views := [
			[g.call(60.0, -60.0, 230.0), g.call(-120.0, -260.0, 0.0), "100_air_roads", "a"],
			[(r1[0] as Vector3) + (r1[1] as Vector3) * 14.0 + Vector3(0, 2.2, 0), (r1[0] as Vector3) + Vector3(0, 1.0, 0), "101_road_wreck", "a"],
			[g.call(Places.J1.x + 4.0, Places.J1.y + 0.0, 1.9), g.call(Places.J1.x - 7.0, Places.J1.y + 6.0, 2.6), "102_signpost", "a"],
			[br + Vector3(26, 7, 30), br + Vector3(0, -3, 0), "103_bridge", "b"],
			[br + Vector3(12, 1.8, 12), br + Vector3(-10, 1.0, -10), "104_bridge_deck", "b"],
			[br + Vector3(18, -14.0, -22), br + Vector3(0, -4, 0), "105_gorge_floor", "b"],
			[st + Vector3(40, 16, 46), st + Vector3(-8, 0, -6), "106_station", "c"],
			[st + Vector3(4, 1.7, 2), st + Vector3(-10, 1.8, -8), "107_station_lab_door", "c"],
			[st + Vector3(-9.5, 1.75, -7.0), st + Vector3(-21, 1.2, -9.5), "108_lab_inside", "c"],
			[st + Vector3(-1.5, 1.75, -14.5), st + Vector3(-1.0, 1.2, -8.0), "109_lab_office", "c"],
			[st + Vector3(-20, 2.2, 2), st + Vector3(-32, 1.0, -12), "110_containment", "c"],
			[ba + Vector3(10, 22, 78), ba + Vector3(0, 0, 0), "111_base", "d"],
			[ba + Vector3(-2, 1.8, 52), ba + Vector3(0, 1.5, 34), "112_base_gate", "d"],
			[ba + Vector3(-6, 1.8, 6), ba + Vector3(-28, 1.5, -16), "113_base_inside", "d"],
			[ba + Vector3(-25.0, 1.75, -14.5), ba + Vector3(-31.5, 1.0, -20.0), "114_ops_room", "d"],
			[ba + Vector3(-23.0, 1.75, -18.0), ba + Vector3(-19.4, 1.0, -20.0), "115_armoury", "d"],
			[ba + Vector3(-62, 4.0, -50), ba + Vector3(-46, 2.0, -34), "116_snow_drift", "d"],
			[Vector3(466, mf + 3.5, 152), Vector3(mx, mf + 2.0, 140), "117_mine_outside", "e"],
			[Vector3(mx + 5.0, mf + 1.7, 140.3), Vector3(574, mf + 1.5, 140), "118_mine_adit", "e"],
			[Vector3(553.0, mf + 1.75, 98.0), Vector3(548, mf + 0.9, 89), "119_mine_office", "e"],
			[Vector3(579.0, mf + 2.0, 136.5), Vector3(600, mf + 2.2, 141), "120_mine_chamber", "e"],
			[Vector3(566.0, mf + 1.6, 149.0), Vector3(566, mf + 0.6, 160), "121_mine_hidden", "e"],
			[Vector3(100, tf + 3.0, tz - 34.0), Vector3(100, tf + 3.5, tz), "122_tunnel_outside", "f"],
			[Vector3(97.5, tf + 1.8, tz + 3.0), Vector3(101, tf + 2.0, 570), "123_tunnel_inside", "f"],
			[Vector3(113.5, tf + 1.75, 552.0), Vector3(125, tf + 1.2, 550), "124_tunnel_service", "f"],
			[b0 + Vector3(12, 3.0, -14), b0 + Vector3(0, 1.0, 2), "125_bunker_outside", "g"],
			[b0 + Vector3(2.0, 1.7, -0.9), b0 + Vector3(2.0, -4.0, 7.5), "126_bunker_stairs", "g"],
			[b0 + Vector3(-1.2, -4.7 + 1.75, 10.5), b0 + Vector3(-9.0, -4.0, 0.0), "127_bunker_room", "g"],
			[se + Vector3(26, 9, -24), se + Vector3(-4, 0, 6), "128_eisgrund", "h"],
			[se + Vector3(-30, 3, 6), se + Vector3(-60, -6, 30), "129_jetty", "h"],
			[tw + Vector3(16, 7, -16), tw + Vector3(0, 7, 0), "130_tower", "h"],
			[tw + Vector3(0.5, 10.8, 0.5), Vector3(Terrain.LAKE_POS.x, 20.0, Terrain.LAKE_POS.y), "131_tower_view", "h"],
			[g.call(Places.VIEW.x + 6.0, Places.VIEW.y + 3.0, 2.2), g.call(260.0, -160.0, 10.0), "132_stollenkopf", "h"],
		]
		var pick := only.trim_prefix("places")
		for v in views:
			if pick != "" and pick != str(v[3]):
				continue
			var from: Vector3 = v[0]
			player.global_position = from + Vector3(0, 0.0, 2.0)
			player.velocity = Vector3.ZERO
			_cam_at(cam, from, v[1])
			await _wait(1.0)
			await _snap(str(v[2]))
			print("fps %s: %d" % [v[2], Engine.get_frames_per_second()])
		if pick == "" or pick == "u":
			cam.current = false
			player.camera.make_current()
			hud.banner("DISCOVERED", "Research Station Polaris-7")
			await _wait(1.2)
			await _snap("133_banner")
			reader.show_note(get_tree().get_nodes_in_group("note")[0])
			await _wait(0.3)
			await _snap("134_note")
			for n in get_tree().get_nodes_in_group("note"):
				reader.show_note(n)
			reader.open_journal()
			await _wait(0.3)
			await _snap("135_journal")
	if only.begins_with("town"):
		cam.fov = 62.0
		cam.far = 5000.0
		cam.make_current()
		lamp.light_energy = 0.0
		var vq := Terrain.VILLAGE_POS
		var tg := func(x: float, z: float, up: float) -> Vector3: return Vector3(vq.x + x, terrain.height_at(vq.x + x, vq.y + z) + up, vq.y + z)
		var tviews := [
			[tg.call(1.0, 124.0, 1.8), tg.call(0.0, 60.0, 3.0), "140_main_street", "a"],
			[tg.call(2.5, 72.0, 1.75), tg.call(-15.0, 64.0, 3.0), "141_house_front", "a"],
			[tg.call(-3.0, 49.0, 1.7), tg.call(-12.0, 44.0, 2.0), "142_house_door", "a"],
			[tg.call(-27.0, 54.0, 1.8), tg.call(-15.0, 46.0, 2.5), "143_house_back", "a"],
			[tg.call(1.5, 106.0, 1.75), tg.call(-8.0, 98.0, 1.4), "144_bus_stop", "b"],
			[tg.call(28.0, 1.5, 1.8), tg.call(100.0, 0.0, 3.0), "145_cross_street", "b"],
			[tg.call(-56.0, 2.0, 1.75), tg.call(-64.0, 12.0, 1.2), "146_parked_car", "b"],
			[tg.call(8.0, 32.0, 2.0), tg.call(0.0, -50.0, 6.0), "147_square", "c"],
			[tg.call(7.0, -27.0, 1.8), tg.call(-1.0, -50.0, 5.0), "148_hotel", "c"],
			[tg.call(-18.0, -14.0, 1.8), tg.call(-33.0, -30.0, 3.0), "149_toyshop", "c"],
			[tg.call(60.0, 150.0, 90.0), tg.call(0.0, 40.0, 0.0), "150_town_air", "d"],
			[tg.call(-30.0, 60.0, 22.0), tg.call(10.0, 75.0, 0.0), "151_street_air", "d"],
		]
		var tpick := only.trim_prefix("town")
		for v in tviews:
			if tpick != "" and tpick != str(v[3]):
				continue
			var from: Vector3 = v[0]
			player.global_position = from + Vector3(0, 0.0, 2.0)
			player.velocity = Vector3.ZERO
			_cam_at(cam, from, v[1])
			await _wait(1.0)
			await _snap(str(v[2]))
			print("fps %s: %d" % [v[2], Engine.get_frames_per_second()])
	if only == "world":
		cam.fov = 60.0
		cam.make_current()
		lamp.light_energy = 0.0
		var shots := []
		if not wilds.cabins.is_empty():
			var c: Node3D = wilds.cabins[0]
			shots.append([c.to_global(Vector3(7.5, 2.6, 10.0)), c.to_global(Vector3(0, 1.3, 0)), "74_cabin"])
			shots.append([c.to_global(Vector3(-2.3, 1.7, 2.0)), c.to_global(Vector3(1.5, 0.9, -1.5)), "75_cabin_inside"])
		if not wilds.camps.is_empty():
			var c: Vector3 = wilds.camps[0]
			shots.append([c + Vector3(9, 3.5, 9), c + Vector3(0, 0.8, 0), "76_raider_camp"])
		var fs := wilds.fisher_spot
		shots.append([fs + Vector3(3.0, 1.5, -3.5), fs + Vector3(0, 0.7, -0.3), "77_ice_fisher"])
		if not Wilds.climb.is_empty():
			var b: Vector3 = Wilds.climb["base"]
			var d: Vector3 = Wilds.climb["dir"]
			shots.append([b - d * 14.0 + Vector3(0, 3.0, 0), b + d * 10.0 + Vector3(0, 9.0, 0), "78_climb_route"])
		var v := village
		shots.append([v._w(Vector2(-1.0, 121.0), 1.6), v._w(Vector2(3.5, 124.0), 1.2), "79_jonas"])
		shots.append([v._w(Vector2(-3.0, 108.5), 1.6), v._w(Vector2(-3.0, 112.0), 1.3), "80_ilse"])
		var inn: Node3D = v.houses[2]
		shots.append([inn.to_global(Chalet.room(inn, Vector3(-3.4, 1.75, -0.9))), inn.to_global(Chalet.room(inn, Vector3(-4.05, 1.5, -3.7))), "81_marta"])
		var hotel: Node3D = v.houses[0]
		shots.append([hotel.to_global(Chalet.room(hotel, Vector3(8.6, 1.5, -3.6))), hotel.to_global(Chalet.room(hotel, Vector3(6.3, 0.9, -1.95))), "82_henrik"])
		shots.append([v._w(Vector2(14, 30), 5.0), v._w(Vector2(6, 8), 1.0), "83_plaza_people"])
		for sh in shots:
			var from: Vector3 = sh[0]
			player.global_position = from + Vector3(1.5, 0.0, 1.5)
			player.velocity = Vector3.ZERO
			lamp.global_position = from + Vector3(0, 1.0, 0)
			lamp.light_energy = 1.0 if "inside" in str(sh[2]) else 0.6
			_cam_at(cam, from, sh[1])
			await _wait(1.2)
			await _snap(str(sh[2]))
		print("sites: ", Wilds.sites)
		print("climb: ", Wilds.climb)
	if only == "" or only == "guns":
		player.camera.make_current()
		lamp.reparent(player.camera)
		lamp.position = Vector3(0.2, 0.5, 0.3)
		lamp.omni_range = 4.0
		lamp.light_energy = 1.4
		for a in ["9mm", "357", "556", "762", "338", "12g", "flare"]:
			player.inv.add(a, 60)
		var n := 43
		for id in ["pistol", "revolver", "smg", "assault_rifle", "marksman_rifle", "shotgun", "sniper_rifle", "flare_gun", "knife", "sword", "axe", "ice_pick"]:
			player.inv.add(id)
			arms.hold(id)
			if Weapons.is_gun(id):
				arms.reload()
			if Weapons.is_gun(id):
				arms._finish_reload()
			arms.reloading = 0.0
			await _wait(0.9)
			await _snap("%d_%s" % [n, id])
			n += 1
		arms.hold("assault_rifle")
		arms.attach("red_dot")
		await _wait(0.8)
		Input.action_press("aim")
		await _wait(0.7)
		await _snap("55_rifle_aim")
		Input.action_release("aim")
		await _wait(0.5)
		arms.st("assault_rifle")["loaded"] = 3
		arms.reload()
		await _wait(0.85)
		await _snap("56_rifle_reload")
		await _wait(2.5)
	if only == "" or only == "hud":
		player.camera.make_current()
		player.inv.add("assault_rifle")
		player.inv.add("556", 90)
		arms.hold("assault_rifle")
		arms.reload()
		await _wait(3.0)
		var foe := enemies.raider("smg", at + Vector3(3.0, 0.1, -14.0))
		foe._wander = Vector3.INF
		player.stats.health = 100.0
		var t := 0.0
		while t < 6.0 and player.stats.health > 80.0:
			await _wait(0.2)
			t += 0.2
		player.aim_at(foe.global_position + Vector3(0, 1.2, 0))
		arms.fire()
		await _wait(0.25)
		arms.fire()
		await _wait(0.12)
		await _snap("57_hud_fight")
		player.stats.health = 22.0
		player.stats.bleeding = 1.0
		foe.health = 1.0
		player.aim_at(foe.global_position + Vector3(0, 1.2, 0))
		await _wait(0.2)
		arms.fire()
		await _wait(0.2)
		await _snap("58_hud_kill_low_health")
		foe.queue_free()
		player.stats.health = 78.0
		player.stats.bleeding = 0.0
		for id in ["parka", "wool_hat", "snow_pants", "fur_boots", "gloves", "kevlar_vest", "small_pack"]:
			player.inv.add(id)
			player.inv.equip(id)
		for id in ["pistol", "shotgun", "sniper_rifle", "knife", "sword", "axe", "ice_pick", "canned_food", "hot_tea", "bandage", "medkit", "rope", "fuel_can", "scrap", "firewood", "batteries", "scope", "silencer", "snow_chains", "helmet", "large_pack", "painkillers", "splint", "cloth", "hand_warmer", "revolver", "smg", "flare_gun", "mittens", "plate_carrier", "expedition_suit", "jeans"]:
			player.inv.add(id)
		player.inv.add("9mm", 45)
		player.inv.add("12g", 18)
		player.inv.add("762_ap", 20)
		arms.attach("red_dot")
		arms.attach("grip")
		screen.open(null)
		screen._mouse = Vector2(560, 300)
		await _wait(0.6)
		await _snap("59_inventory")
		screen.close()
		var lb := LootBox.new()
		lb.title = "Station locker"
		lb.items = {"medkit": 1, "556": 30, "expedition_suit": 1, "fuel_can": 2, "muzzle_brake": 1}
		add_child(lb)
		screen.open(lb)
		screen._mouse = Vector2(250, 230)
		await _wait(0.6)
		await _snap("60_inventory_chest")
		screen.close()
	get_tree().quit()


## Scripted climb of the marked route: bare hands first, then with pick and rope.
func _climb_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	if Wilds.climb.is_empty():
		print("climbtest: no route found")
		get_tree().quit()
		return
	var base: Vector3 = Wilds.climb["base"]
	var top: Vector3 = Wilds.climb["top"]
	var dir: Vector3 = Wilds.climb["dir"]
	print("climbtest: route rises %.0f m over %.0f m" % [top.y - base.y, Vector2(top.x - base.x, top.z - base.z).length()])
	var prof := ""
	for i in 17:
		var q := base.lerp(top, i / 16.0)
		prof += "%.0f/%.2f " % [terrain.height_at(q.x, q.z) - base.y, terrain.normal_at(q.x, q.z).y]
	print("profile (height/normal.y): ", prof)
	player.arms.free_input = true
	if "--perf" in OS.get_cmdline_user_args():
		for spot in [player.global_position, base + Vector3(0, 0.4, 0)]:
			player.global_position = spot
			player.rotation.y = atan2(-dir.x, -dir.z)
			await _wait(3.0)
			for k in 3:
				await _wait(3.0)
				print("perf at %s: fps %d  process %.1f ms  physics %.1f ms  draws %d  prims %d  objects %d  nodes %d" % [spot, Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		get_tree().quit()
		return
	for geared in [false, true]:
		player.global_position = base + Vector3(0, 0.4, 0)
		player.velocity = Vector3.ZERO
		player.rotation.y = atan2(-dir.x, -dir.z)
		player.stats.stamina = 100.0
		player.stats.health = 100.0
		player.stats.warmth = 100.0
		if geared:
			player.inv.add("ice_pick")
			player.inv.add("rope")
		await _wait(0.5)
		Input.action_press("move_forward")
		Input.action_press("jump")
		var t := 0.0
		var climbed := 0.0
		var best := 0.0
		while t < 80.0:
			await _wait(0.5)
			t += 0.5
			if player.climbing:
				climbed += 0.5
			best = maxf(best, player.global_position.y - base.y)
			player.rotation.y = atan2(-dir.x, -dir.z)
			if player.global_position.y > top.y - 1.0:
				break
			if geared and player.climbing:
				# rest in the rope when the arms are empty
				if player.stats.stamina < 12.0:
					Input.action_release("move_forward")
				elif player.stats.stamina > 85.0:
					Input.action_press("move_forward")
			if int(t * 2.0) % 20 == 0:
				print("   t=%.0f (wall clock %d s) height +%.1f  stamina %.0f  climbing=%s  fps %d" % [t, Time.get_ticks_msec() / 1000, player.global_position.y - base.y, player.stats.stamina, player.climbing, Engine.get_frames_per_second()])
		Input.action_release("move_forward")
		Input.action_release("jump")
		var sp := get_world_3d().direct_space_state
		var fq := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.45, 0), player.global_position + Vector3(0, 0.45, 0) - player.global_basis.z * 3.0)
		fq.exclude = [player.get_rid()]
		var fr := sp.intersect_ray(fq)
		print("   ended at %s (base %s), ahead: %s" % [player.global_position, base, [fr.get("collider"), fr.get("normal"), (fr.get("position", Vector3.ZERO) as Vector3).distance_to(player.global_position)] if not fr.is_empty() else "nothing within 3 m"])
		print("climb %s: reached +%.1f of %.1f m in %.0f s (%.0f s on the wall), stamina left %.0f, health %.0f" % ["with pick and rope" if geared else "bare hands", best, top.y - base.y, t, climbed, player.stats.stamina, player.stats.health])
		if geared:
			await _snap("84_summit")
			# back down on the rope
			var h0 := player.global_position.y
			player.rotation.y = atan2(dir.x, dir.z)
			Input.action_press("move_forward")
			await _wait(10.0)
			Input.action_release("move_forward")
			print("walking back down for 10 s: dropped %.1f m, health %.0f" % [h0 - player.global_position.y, player.stats.health])
	get_tree().quit()


func _ok(what: String, good: bool, extra := "") -> void:
	print("%s  %s %s" % ["PASS" if good else "FAIL", what, extra])


func _gated(gid: String) -> Node:
	for n in get_tree().get_nodes_in_group("gated"):
		if str(n.get("id")) == gid:
			return n
	return null


## Walks the player forward for `secs` from a spot, looking along `yaw`. Returns where they end up.
func _walk_from(pos: Vector3, yaw: float, secs: float) -> Vector3:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	await _wait(0.5)
	Input.action_press("move_forward")
	await _wait(secs)
	Input.action_release("move_forward")
	await _wait(0.2)
	return player.global_position


## Debug: walk a few set lines and print where the player is twice a second.
func _probe() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	var tw := Vector3(Places.TOWER.x, terrain.height_at(Places.TOWER.x, Places.TOWER.y), Places.TOWER.y)
	var tb := Basis(Vector3.UP, 0.6)
	var u := Places._u()
	var bh: float = Places.D["bridge_h"]
	var side := Vector2(u.y, -u.x) * 2.2
	places.bridge_lever.pulled = true
	places.span.rotation.x = 0.0
	var runs := [
		["tower 1", tw + tb * Vector3(2.8, 0.4, -6.4), 0.6 + PI, 8.0, tw, tb],
		["tower 2", tw + tb * Vector3(4.0, 4.9, 3.6), 0.6, 8.0, tw, tb],
		["span", Vector3(Places.BRIDGE.x - u.x * 12.0 + side.x, bh + 0.4, Places.BRIDGE.y - u.y * 12.0 + side.y), PI * 0.25, 8.0, Vector3(Places.BRIDGE.x, bh, Places.BRIDGE.y), Basis(Vector3.UP, PI * 0.25)],
	]
	await _wait(1.0)
	for r in runs:
		player.global_position = r[1]
		player.velocity = Vector3.ZERO
		player.rotation.y = r[2]
		player.stats.health = 100.0
		player.stats.sprain = false
		await _wait(0.5)
		Input.action_press("move_forward")
		var n := int(float(r[3]) * 2.0)
		for i in n:
			await _wait(0.5)
			var l: Vector3 = (r[5] as Basis).inverse() * (player.global_position - (r[4] as Vector3))
			print("%s  %.1fs  local %.2f %.2f %.2f  floor=%s wall=%s" % [r[0], (i + 1) * 0.5, l.x, l.y, l.z, player.is_on_floor(), player.is_on_wall()])
		Input.action_release("move_forward")
	var car: Vehicle = garage.by_id("offroader_1")
	car.fuel = 50.0
	car.health = 100.0
	await _vput(car, Places.BRIDGE - u * 30.0, PI * 0.25)
	car.test_input = Vector3(0.7, 0, 0)
	for i in 24:
		await _wait(0.5)
		var l: Vector3 = Basis(Vector3.UP, PI * 0.25).inverse() * (car.global_position - Vector3(Places.BRIDGE.x, bh, Places.BRIDGE.y))
		print("car %.1fs local %.2f %.2f %.2f speed %.1f surface %s" % [(i + 1) * 0.5, l.x, l.y, l.z, car.linear_velocity.length(), car.surface])
	get_tree().quit()


## Milestone 6: places, locks, tools, documents, the bridge, saving.
func _places_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	SaveGame.path = "user://test_places.json"
	var inv := player.inv
	var mf: float = Places.D["mine_floor"]
	var mx: float = Places.D["mine_px"]
	var tf: float = Places.D["tunnel_floor"]
	var tz: float = Places.D["tunnel_pz"]
	var said: Array[String] = []
	player.message.connect(func(t: String) -> void: said.append(t))
	await _wait(1.0)
	print("spots=%d notes=%d gated=%d guards=%d" % [places.spots.size(), get_tree().get_nodes_in_group("note").size(), get_tree().get_nodes_in_group("gated").size(), places.crews.size()])
	# --- people of Eisgrund hand over what opens the valley
	for nid in ["tove", "mikkel"]:
		for n in people.list:
			if n.id == nid:
				n.interact(player)
				town.close()
	_ok("Tove gives the mine key and the crowbar, Mikkel a rope", inv.count("key_mine") == 1 and inv.count("crowbar") == 1 and inv.count("rope") >= 1)
	inv.remove("crowbar")
	# --- every place is found by going there
	for sp in places.spots:
		player.global_position = (sp["pos"] as Vector3) + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		await _wait(0.7)
	_ok("all places discovered", places.found.size() == places.spots.size(), "%d/%d" % [places.found.size(), places.spots.size()])
	# --- mine: boards need a tool, the gate needs the key
	var boards: Breakable = _gated("mine_boards")
	player.global_position = Vector3(mx - 3.0, mf + 0.3, 140.0)
	await _wait(0.4)
	boards.interact(player)
	_ok("boards hold without a tool", not boards.broken, said[-1] if not said.is_empty() else "")
	var stuck: Vector3 = await _walk_from(Vector3(mx - 6.0, mf + 0.3, 140.0), -PI * 0.5, 3.0)
	_ok("boards block the adit", stuck.x < mx + 1.0, "x=%.1f" % stuck.x)
	boards.hit(200.0, boards.global_position, Vector3.RIGHT, 0.0, player)
	_ok("an axe blow breaks the boards", boards.broken)
	var into: Vector3 = await _walk_from(Vector3(mx - 6.0, mf + 0.3, 140.0), -PI * 0.5, 4.0)
	_ok("walk into the mine", into.x > mx + 6.0 and absf(into.y - mf) < 0.6, "x=%.1f y=%.2f floor=%.2f" % [into.x, into.y, mf])
	_ok("underground counts as shelter, no snowfall", Places.shelter_at(into) == 1 and Places.underground(into))
	var gate: LockDoor = _gated("mine_gate")
	inv.remove("key_mine")
	gate.interact(player)
	_ok("mine gate stays locked without the key", gate.locked and not gate.is_open)
	inv.add("key_mine")
	gate.interact(player)
	_ok("mine gate opens with the key", not gate.locked and gate.is_open)
	await _wait(1.2)
	var deep: Vector3 = await _walk_from(Vector3(572.0, mf + 0.3, 140.0), -PI * 0.5, 3.0)
	_ok("through the gate into the chamber", deep.x > 579.0, "x=%.1f" % deep.x)
	var hid: Breakable = _gated("mine_hidden")
	inv.add("crowbar")
	hid.interact(player)
	var hidden: Vector3 = await _walk_from(Vector3(566.0, mf + 0.3, 140.5), PI, 3.5)
	_ok("hidden room behind the planks", hid.broken and hidden.z > 150.0, "z=%.1f" % hidden.z)
	var office: Vector3 = await _walk_from(Vector3(552.0, mf + 0.3, 136.0), 0.0, 12.0)
	_ok("drift to the office", office.z < 100.0, "z=%.1f" % office.z)
	# --- tunnel
	var tin: Vector3 = await _walk_from(Vector3(100.0, tf + 0.3, tz - 9.0), PI, 4.5)
	_ok("walk into the tunnel", tin.z > tz + 6.0, "z=%.1f y=%.2f floor=%.2f" % [tin.z, tin.y, tf])
	var jam: Breakable = _gated("tunnel_door")
	jam.hit(500.0, jam.global_position, Vector3.RIGHT, 0.0, player)
	_ok("service door ignores blows", not jam.broken)
	jam.interact(player)
	var svc: Vector3 = await _walk_from(Vector3(102.5, tf + 0.3, 552.0), -PI * 0.5, 4.0)
	_ok("crowbar forces the service door", jam.broken and svc.x > 112.0, "x=%.1f" % svc.x)
	# --- shelter B-2: locked, then down the stairs
	var bx := terrain.gx(Places.BUNKERS[0][0])
	var bz := terrain.gx(Places.BUNKERS[0][1] - 1)
	var bs: float = Places.D["bunker_h"][0]
	var bdoor: LockDoor = _gated("bunker1_door")
	bdoor.interact(player)
	_ok("shelter B-2 locked", bdoor.locked)
	inv.add("key_bunker")
	player.global_position = Vector3(bx + 2.0, bs + 0.3, bz - 4.0)
	await _wait(0.3)
	bdoor.interact(player)
	await _wait(1.3)
	var down: Vector3 = await _walk_from(Vector3(bx + 2.0, bs + 0.3, bz - 4.0), PI, 7.0)
	_ok("down the shelter stairs", down.y < bs - 4.0 and down.z > bz + 5.0, "y=%.2f (floor %.2f) z=%.1f" % [down.y, bs - 4.7, down.z - bz])
	var up: Vector3 = await _walk_from(Vector3(bx + 2.0, bs - 4.6, bz + 7.0), 0.0, 7.0)
	_ok("and back up", up.y > bs - 0.5, "y=%.2f" % (up.y - bs))
	# --- station: dormitory floor, lab keycard
	var st := Vector3(Places.STATION.x, Places.D["station_h"], Places.STATION.y)
	var lab: LockDoor = _gated("lab_door")
	lab.interact(player)
	_ok("lab locked without the keycard", lab.locked)
	inv.add("keycard_lab")
	player.global_position = st + Vector3(-4.0, 0.4, -3.0)
	await _wait(0.3)
	lab.interact(player)
	await _wait(1.3)
	var inlab: Vector3 = await _walk_from(st + Vector3(-4.0, 0.4, -3.0), 0.0, 3.5)
	_ok("into the lab over the door step", inlab.z < st.z - 7.5, "z=%.1f" % (inlab.z - st.z))
	# --- tower stairs
	var tw := Vector3(Places.TOWER.x, terrain.height_at(Places.TOWER.x, Places.TOWER.y), Places.TOWER.y)
	var tb := Basis(Vector3.UP, 0.6)
	var f1: Vector3 = await _walk_from(tw + tb * Vector3(2.8, 0.4, -6.4), 0.6 + PI, 2.9)
	var f2: Vector3 = await _walk_from(tw + tb * Vector3(4.0, 4.9, 3.6), 0.6, 7.5)
	_ok("tower stairs", f1.y > tw.y + 3.8 and f2.y > tw.y + 8.6, "flight 1 +%.1f m, flight 2 +%.1f m" % [f1.y - tw.y, f2.y - tw.y])
	# --- base: ram the gate with the pickup
	var bgate: Breakable = _gated("base_gate")
	var pk: Vehicle = garage.by_id("pickup_1")
	pk.fuel = 60.0
	pk.health = 100.0
	player.global_position = Vector3(Places.BASE.x + 20.0, Places.D["base_h"] + 1.0, Places.BASE.y + 60.0)
	await _vput(pk, Places.BASE + Vector2(0.0, 62.0), 0.0)
	pk.test_input = Vector3(1, 0, 0)
	await _wait(6.0)
	pk.test_input = Vector3(-1, 0, 0)
	await _wait(1.5)
	pk.test_input = Vector3(0, 0, 1)
	_ok("pickup bursts the base gate", bgate.broken and pk.global_position.z < Places.BASE.y + 34.0, "pickup z=%.1f (gate %.1f)" % [pk.global_position.z, Places.BASE.y + 34.0])
	var fence: Breakable = _gated("base_fence")
	fence.interact(player)
	_ok("fence holds without bolt cutters", not fence.broken)
	inv.add("bolt_cutters")
	fence.interact(player)
	_ok("bolt cutters open the fence", fence.broken)
	var drift: Vector3 = await _walk_from(Vector3(Places.BASE.x - 46.0 - 9.5, terrain.height_at(Places.BASE.x - 55.5, Places.BASE.y - 43.5) + 0.5, Places.BASE.y - 34.0 - 9.5), -PI * 0.75, 7.0)
	_ok("over the snow drift into the base", drift.x > Places.BASE.x - 45.0 and drift.z > Places.BASE.y - 33.0, "at %.1f / %.1f" % [drift.x - Places.BASE.x, drift.z - Places.BASE.y])
	# --- bridge: lever lowers the span, the off-roader crosses
	var u := Places._u()
	var bh: float = Places.D["bridge_h"]
	var side := Vector2(u.y, -u.x) * 2.2
	var gap: Vector3 = await _walk_from(Vector3(Places.BRIDGE.x - u.x * 12.0 + side.x, bh + 0.4, Places.BRIDGE.y - u.y * 12.0 + side.y), PI * 0.25, 4.0)
	_ok("the gap is a gap", gap.y < bh - 5.0, "fell to %.1f" % (gap.y - bh))
	player.stats.health = 100.0
	player.stats.sprain = false
	places.bridge_lever.interact(player)
	await _wait(6.5)
	_ok("span is down", absf(places.span.rotation.x) < 0.01)
	var over: Vector3 = await _walk_from(Vector3(Places.BRIDGE.x - u.x * 8.6, bh + 0.4, Places.BRIDGE.y - u.y * 8.6), PI * 0.25, 6.0)
	_ok("walk across the span", (Vector2(over.x, over.z) - Places.BRIDGE).dot(u) > 9.0 and over.y > bh - 1.0, "%.1f m past the middle" % (Vector2(over.x, over.z) - Places.BRIDGE).dot(u))
	var car: Vehicle = garage.by_id("offroader_1")
	car.fuel = 50.0
	car.health = 100.0
	player.global_position = Vector3(Places.BRIDGE.x - u.x * 34.0 + side.x * 4.0, bh + 0.6, Places.BRIDGE.y - u.y * 34.0 + side.y * 4.0)   # out of the car's way
	await _vput(car, Places.BRIDGE - u * 30.0, PI * 0.25)
	car.test_input = Vector3(0.7, 0, 0)
	await _wait(9.0)
	car.test_input = Vector3(0, 0, 1)
	var cd := (Vector2(car.global_position.x, car.global_position.z) - Places.BRIDGE).dot(u)
	_ok("off-roader drives across", cd > 15.0 and car.global_position.y > bh - 1.5, "%.1f m past the middle, y %.1f" % [cd, car.global_position.y - bh])
	# --- documents and the journal
	for n in get_tree().get_nodes_in_group("note"):
		(n as Note).interact(player)
		reader.close()
	_ok("journal holds every document", reader.found.size() == Lore.NOTES.size(), "%d/%d" % [reader.found.size(), Lore.NOTES.size()])
	# --- saving
	_ok("save", SaveGame.save(self))
	gate.set_state(false)
	boards.set_state(false)
	places.bridge_lever.set_state(false)
	places.found.clear()
	reader.found.clear()
	_ok("load", SaveGame.load_game(self))
	await _wait(0.5)
	_ok("locks, barriers, lever, places and journal come back", not gate.locked and boards.broken and places.bridge_lever.pulled and places.found.size() == places.spots.size() and reader.found.size() == Lore.NOTES.size())
	enemies.roster = false
	enemies.spawn_all()
	await _wait(0.5)
	print("enemies alive with the garrison: %d" % enemies.alive())
	print("messages: ", said.slice(0, 12))
	get_tree().quit()


func _npc(nid: String) -> Npc:
	for n in people.list:
		if n.id == nid:
			return n
	return null


## Milestone 7: factions, traders, crafting, jobs, saving.
func _econ_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	SaveGame.path = "user://test_econ.json"
	var inv := player.inv
	var said: Array[String] = []
	player.message.connect(func(t: String) -> void: said.append(t))
	await _wait(0.5)
	_ok("start with 40 Kronen", inv.count("coin") == 40)
	# --- territory
	var vq := Terrain.VILLAGE_POS
	_ok("ground belongs to someone", factions.at(Vector3(vq.x, 0, vq.y)) == "village" and factions.at(Vector3(Places.BASE.x, 0, Places.BASE.y)) == "nordwacht"
		and factions.at(Vector3(vq.x + 80.0, 0, vq.y - 100.0)) == "raiders" and factions.at(Vector3(Places.SETTLE.x, 0, Places.SETTLE.y)) == "eisgrund" and factions.at(Vector3(-800, 0, 800)) == "")
	# --- talking opens the window, trading works
	var pavel := _npc("pavel")
	player.global_position = pavel.global_position + Vector3(1.5, 0.3, 1.5)
	pavel.interact(player)
	_ok("talking to a trader opens the talk window", town.mode == "talk" and town._opts.size() >= 2, str(town._opts))
	await _wait(1.6)
	_ok("the line is typed out, then stands", not town.typing() and town._shown >= town.line.length())
	await _snap("160_talk")
	var row1: Dictionary = town._hits[1] if town._hits.size() > 1 else {}
	_ok("pointing at an answer chooses it", not row1.is_empty() and town._point((row1["r"] as Rect2).get_center()) and town._sel == 1)
	town._sel = 0
	town.open_trade(pavel)
	_ok("trade window", town.mode == "trade" and not trade.offers("pavel").is_empty(), "%d kinds on offer" % trade.offers("pavel").size())
	inv.add("scrap", 5)
	inv.add("cloth", 3)
	inv.add("9mm", 30)
	await _wait(0.6)
	await _snap("161_trade")
	trade.stock["pavel"]["canned_food"] = 3
	var p0 := trade.buy_price("pavel", "canned_food")
	var f0 := inv.count("canned_food")
	var res := trade.buy("pavel", "canned_food", inv)
	_ok("buy canned food", res == "" and inv.count("canned_food") == f0 + 1 and inv.count("coin") == 40 - p0, "price %d, %d Kronen left" % [p0, inv.count("coin")])
	trade.stock["pavel"]["canned_food"] = 1
	_ok("the last one costs more", trade.buy_price("pavel", "canned_food") > p0, "%d > %d" % [trade.buy_price("pavel", "canned_food"), p0])
	trade.stock["pavel"]["scrap"] = 0
	trade.stock["marta"]["scrap"] = 0
	var sp := trade.sell_price("pavel", "scrap")
	var sm := trade.sell_price("marta", "scrap")
	_ok("Pavel pays more for scrap than Marta", sp > sm, "%d vs %d" % [sp, sm])
	var c0 := inv.count("coin")
	trade.sell("pavel", "scrap", inv)
	trade.sell("pavel", "scrap", inv)
	trade.sell("pavel", "scrap", inv)
	trade.sell("pavel", "scrap", inv)
	_ok("selling pays, and the price drops as he fills up", inv.count("coin") > c0 and trade.sell_price("pavel", "scrap") < sp, "+%d Kronen, now %d each" % [inv.count("coin") - c0, trade.sell_price("pavel", "scrap")])
	inv.remove("coin", inv.count("coin"))
	trade.stock["pavel"]["bandage"] = 2
	var b0 := inv.count("bandage")
	_ok("no money, no deal", trade.buy("pavel", "bandage", inv) != "" and inv.count("bandage") == b0)
	inv.add("coin", 3000)
	trade.stock["ilse"]["plate_carrier"] = 1
	_ok("rare goods are not for strangers", trade.buy("ilse", "plate_carrier", inv) != "", trade.buy("ilse", "plate_carrier", inv))
	var pb := trade.buy_price("ilse", "plate_carrier")
	factions.add("village", 75)
	_ok("allies pay less and may buy everything", trade.buy_price("ilse", "plate_carrier") < pb and trade.buy("ilse", "plate_carrier", inv) == "" and inv.count("plate_carrier") == 1,
		"%d -> %d" % [pb, trade.buy_price("ilse", "plate_carrier")])
	factions.add("village", -75)
	# --- new stock comes
	var before := str(trade.stock["jonas"])
	trade.clock = Trade.RESTOCK + 1.0
	await _wait(0.3)
	_ok("a delivery changes the stock", trade.wave == 1 and str(trade.stock["jonas"]) != before)
	# --- enemies of the village get nothing
	factions.add("village", -60)
	town.close()
	said.clear()
	pavel.interact(player)
	_ok("a hostile village will not talk or trade", not trade.can_trade("pavel") and town.mode == "" and not said.is_empty(), said[-1] if not said.is_empty() else "")
	factions.add("village", 60)
	# --- crafting
	inv.remove("cloth", inv.count("cloth"))
	inv.remove("bandage", inv.count("bandage"))
	_ok("no parts, no bandage", not Recipes.make(0, inv))
	inv.add("cloth", 2)
	_ok("two cloth make a bandage", Recipes.make(0, inv) and inv.count("bandage") == 1 and inv.count("cloth") == 0)
	inv.add("scrap", 1)
	var ap0 := inv.count("9mm_ap")
	_ok("armour-piercing rounds from plain ones", Recipes.make(4, inv) and inv.count("9mm_ap") == ap0 + 10)
	var benches := 0
	for c in get_children():
		if c is Workbench:
			benches += 1
			if benches == 1:
				player.global_position = (c as Node3D).global_position + (c as Node3D).global_basis.z * 1.6 + Vector3(0, 0.3, 0)
				(c as Workbench).interact(player)
	_ok("two workbenches, E opens the list", benches == 2 and town.mode == "craft")
	await _snap("162_workbench")
	town.close()
	# --- jobs
	var marta := _npc("marta")
	_ok("Marta offers a job", str(quests.options("marta")).contains("offer:parcel"))
	marta.interact(player)
	town._sel = 0
	town.confirm()
	_ok("the offer is shown before you accept", town._pending == "parcel" and quests.status("parcel") == "none")
	town.confirm()
	_ok("delivery: accepted, parcel in the pack", quests.status("parcel") == "active" and inv.count("parcel") == 1, str(quests.tracked()))
	town.close()
	await _wait(0.6)
	await _snap("163_hud_job")
	var re := int(factions.rep["eisgrund"])
	var co := inv.count("coin")
	quests.act("give:parcel", "tove")
	_ok("delivery: Tove takes it, pay and standing follow", quests.status("parcel") == "done" and inv.count("parcel") == 0 and inv.count("coin") == co + 60 and int(factions.rep["eisgrund"]) == re + 12)
	quests.act("offer:station", "otto")
	enemies.dead.append_array(["raider_1", "raider_2"])
	await _wait(1.3)
	_ok("clear out: two of three is not enough", quests.objective("station").contains("2/3"), quests.objective("station"))
	enemies.dead.append("raider_7")
	await _wait(1.3)
	_ok("clear out: then back to Otto", str(quests.options("otto")).contains("talk:station"))
	quests.act("talk:station", "otto")
	_ok("clear out: done", quests.status("station") == "done")
	quests.act("offer:parts", "jonas")
	inv.remove("scrap", inv.count("scrap"))
	inv.remove("batteries", inv.count("batteries"))
	quests.act("give:parts", "jonas")
	_ok("collect: not without the parts", quests.status("parts") == "active")
	inv.add("scrap", 6)
	inv.add("batteries", 2)
	quests.act("give:parts", "jonas")
	_ok("collect: parts handed over, tank received", quests.status("parts") == "done" and inv.count("scrap") == 0 and inv.count("aux_tank") == 1)
	quests.act("offer:survey", "mikkel")
	places.found.append_array(["tower", "bridge", "tunnel"])
	await _wait(1.3)
	quests.act("talk:survey", "mikkel")
	_ok("explore: three places, then the report", quests.status("survey") == "done" and inv.count("bolt_cutters") == 1)
	quests.act("offer:truth", "aurel")
	for i in 5:
		reader.found.append("n_test_%d" % i)
	await _wait(1.3)
	quests.act("talk:truth", "aurel")
	_ok("investigate: five documents", quests.status("truth") == "done")
	quests.act("offer:wolves", "annika")
	enemies.dead.append_array(["wolf_b_0", "wolf_b_1", "wolf_b_2"])
	await _wait(1.3)
	quests.act("talk:wolves", "annika")
	_ok("hunt: the pack is gone", quests.status("wolves") == "done" and inv.count("fur_hood") == 1)
	# --- the choice
	quests.act("offer:crate", "ilse")
	var crate_box: LootBox = null
	for n in get_tree().get_nodes_in_group("loot"):
		if (n as LootBox).id == "bunker2":
			crate_box = n
	_ok("choice: the crate lies in shelter B-5", crate_box != null and int(crate_box.items.get("medicine_crate", 0)) == 1)
	_ok("choice: nobody can take what you do not carry", quests.options("aurel").is_empty() or not str(quests.options("aurel")).contains("choose"))
	crate_box.items.erase("medicine_crate")
	inv.add("medicine_crate")
	var three := str(quests.options("aurel")).contains("choose:crate") and str(quests.options("tove")).contains("choose:crate") and str(quests.options("pavel")).contains("choose:crate")
	_ok("choice: three people want it", three)
	_npc("tove").interact(player)
	await _snap("164_choice")
	town.close()
	var rv := int(factions.rep["village"])
	re = int(factions.rep["eisgrund"])
	quests.act("choose:crate", "tove")
	_ok("choice: Eisgrund gains, the village does not forgive", quests.outcome("crate") == "eisgrund" and int(factions.rep["eisgrund"]) == re + 25 and int(factions.rep["village"]) == rv - 8 and inv.count("medicine_crate") == 0)
	_ok("all seven jobs done", quests.done_count() == 7)
	town.open_quests()
	await _snap("165_jobs")
	town.close()
	# --- killing and hurting people moves standing
	var rr := int(factions.rep["raiders"])
	rv = int(factions.rep["village"])
	var e := enemies.raider("pistol", player.global_position + Vector3(6, 0.4, 0))
	e.passive = true
	await _wait(0.3)
	e.hit(999.0, e.global_position + Vector3(0, 1.0, 0), Vector3.RIGHT, 100.0, player)
	await _wait(0.3)
	_ok("a dead raider: Red Flags down, village up", int(factions.rep["raiders"]) == rr - 4 and int(factions.rep["village"]) == rv + 2)
	rv = int(factions.rep["village"])
	pavel.hit(1.0, pavel.global_position, Vector3.RIGHT, 0.0, player)
	_ok("hurting a villager costs standing", int(factions.rep["village"]) == rv - 12)
	# --- saving
	var s_rep := factions.rep.duplicate()
	var s_coin := inv.count("coin")
	var s_stock: Dictionary = (trade.stock["mikkel"] as Dictionary).duplicate()
	_ok("save", SaveGame.save(self))
	factions.reset()
	quests.state.clear()
	inv.remove("coin", 500)
	trade.stock["mikkel"] = {}
	_ok("load", SaveGame.load_game(self))
	await _wait(0.5)
	_ok("standing, jobs, stock and money come back", factions.rep == s_rep and quests.done_count() == 7 and quests.outcome("crate") == "eisgrund" and inv.count("coin") == s_coin and trade.stock["mikkel"] == s_stock, "rep %s jobs %d coin %s stock %s" % [factions.rep == s_rep, quests.done_count(), inv.count("coin") == s_coin, trade.stock["mikkel"] == s_stock])
	print("messages: ", said.slice(0, 10))
	get_tree().quit()


func _look_at(target: Vector3) -> void:
	player.aim_at(target)


## Lets the game run for `secs`, keeps the player alive, and notes every `mode`/weapon the boss goes through.
func _watch(e: Enemy, secs: float, what := "mode") -> Dictionary:
	var seen := {}
	var n := int(secs / 0.1)
	for i in n:
		player.stats.health = 100.0
		player.stats.bleeding = 0.0
		player.stats.warmth = 80.0
		seen[str(e.get(what))] = true
		await _wait(0.1)
	return seen


func _bag_with(item: String) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("loot"):
		if (b as LootBox).dynamic and (b as LootBox).items.has(item) and not b.is_queued_for_deletion():
			n += 1
	return n


## Milestone 8: the three bosses.
func _boss_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	SaveGame.path = "user://test_boss.json"
	var said: Array[String] = []
	player.message.connect(func(t: String) -> void: said.append(t))
	await _wait(1.0)
	var b := bosses.beast
	var m := bosses.machine
	var c := bosses.commander
	_ok("three bosses wait, asleep in a test run", b.passive and m.passive and c.passive and bosses.active() == null)
	_ok("the beast stands on the lake ice", absf(b.global_position.y - Terrain.LAKE_LEVEL) < 1.0 and Lake.hole(Vector2(b.global_position.x, b.global_position.z)) > 60.0,
		"y %.2f, lake %.2f" % [b.global_position.y, Terrain.LAKE_LEVEL])
	_ok("K-9 stands in the lower chamber", m.global_position.distance_to(Places.D["k9"]) < 1.0, str(m.global_position))
	_ok("Falk stands in the fort yard", c.global_position.distance_to(Vector3(Places.BASE.x - 13.0, Places.D["base_h"], Places.BASE.y - 5.0)) < 2.5, str(c.global_position))

	# ------------------------------------------------------------ the beast
	player.global_position = b.global_position + b.global_basis.x * 9.0 + Vector3(0, 0.6, 0)
	_look_at(b.global_position + Vector3(0, 1.5, 0))
	await _wait(0.6)
	await _snap("170_beast")
	b.hit(40.0, b.to_global(Vector3(1.0, 1.5, 0.0)), -b.global_basis.x, 20.0, player)
	var plate_dmg := b.last_damage
	_ok("a flank plate soaks the bullet", plate_dmg < 12.0 and float(b.parts["right"]["hp"]) < 170.0, "%.1f through, plate %.0f/170" % [plate_dmg, float(b.parts["right"]["hp"])])
	b.hit(40.0, b.to_global(Vector3(0.0, 1.4, 2.0)), -b.global_basis.z, 20.0, player)
	_ok("the bare rump takes it in full", b.last_damage > 45.0, "%.1f" % b.last_damage)
	for i in 8:
		b.hit(40.0, b.to_global(Vector3(1.0, 1.5, 0.0)), -b.global_basis.x, 20.0, player)
	_ok("the plate breaks and falls away", not b.part_alive("right") and not (b.parts["right"]["node"] as Node3D).visible and said.any(func(t: String) -> bool: return "right flank plate destroyed" in t))
	b.hit(40.0, b.to_global(Vector3(1.0, 1.5, 0.0)), -b.global_basis.x, 20.0, player)
	_ok("without the plate the flank is soft", b.last_damage > 35.0, "%.1f" % b.last_damage)
	_ok("still asleep while passive", b.state != "fight")
	# it wakes, roars, charges
	bosses.wake()
	b.health = b.max_health
	player.global_position = b.global_position - b.global_basis.z * 26.0 + Vector3(0, 0.6, 0)
	_look_at(b.global_position + Vector3(0, 1.5, 0))
	var b0 := b.global_position
	var seen: Dictionary = await _watch(b, 7.0)
	_ok("it sees you, winds up and charges", seen.has("windup") and seen.has("charge"), str(seen.keys()))
	_ok("the charge carries it across the ice", b.global_position.distance_to(b0) > 12.0, "%.1f m" % b.global_position.distance_to(b0))
	_ok("the boss bar is up", bosses.active() == b and str(b.bar()["name"]) == "The White One" and (b.bar()["pips"] as Array).size() == 3)
	_look_at(b.global_position + Vector3(0, 1.5, 0))
	await _wait(0.2)
	await _snap("171_beast_fight")
	# a flare stops a charge
	b.mode = "charge"
	b._t = 2.0
	b.scare(b.global_position, 22.0)
	_ok("a flare breaks the charge", b.mode == "skid")
	# it breaks the ice
	var holes := lake.breaks.size()
	b.mode = "stalk"
	b._slam()
	_ok("its slam breaks the ice", lake.breaks.size() == holes + 1, "%d holes" % lake.breaks.size())
	# its gifts: frost breath, ice spikes, the howl
	player.stats.health = 100.0
	player.stats.warmth = 80.0
	post.frost = 0.0
	player.global_position = b.global_position - b.global_basis.z * 9.0 + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	_look_at(b.global_position + Vector3(0, 2.0, 0))
	b.mode = "breath"
	b._t = 2.8
	b._breath_cd = 99.0
	b._spike_cd = 99.0
	await _wait(1.7)
	await _snap("178_beast_breath")
	await _wait(0.8)
	_ok("its breath freezes you", player.stats.warmth < 68.0 and post.frost > 0.3 and player.stats.health < 100.0,
		"warmth %.0f, frost %.2f, health %.0f" % [player.stats.warmth, post.frost, player.stats.health])
	b.passive = true
	b.mode = "stalk"
	await _wait(0.6)
	player.stats.health = 100.0
	player.global_position = b.global_position - b.global_basis.z * 13.0 + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	await _wait(0.4)
	var hp0 := player.stats.health
	b._spike_line()
	var spikes := 0
	for n in b.get_parent().get_children():
		if n is IceSpike:
			spikes += 1
	_look_at(b.global_position + Vector3(0, 0.5, 0))
	await _wait(0.35)
	await _snap("179_spikes_warn")
	await _wait(1.3)
	await _snap("180_spikes")
	_ok("ice spikes burst out of the lake towards you", spikes >= 5 and player.stats.health < hp0 - 10.0, "%d spikes, %.0f -> %.0f" % [spikes, hp0, player.stats.health])
	var fog0 := weather.fog_add
	b._howl()
	await _wait(0.3)
	_ok("its howl whites the world out", post.whiteout > 0.5 and weather.fog_add > fog0 + 0.04 and said.any(func(t: String) -> bool: return "howls" in t),
		"whiteout %.2f, fog +%.2f" % [post.whiteout, weather.fog_add - fog0])
	await _snap("181_howl")
	b.passive = false
	player.stats.health = 100.0
	# it runs at two thirds
	b.health = b.max_health * 0.68
	b.hit(60.0, b.to_global(Vector3(0.0, 1.4, 2.0)), -b.global_basis.z, 20.0, player)
	_ok("hurt enough, it runs", b.mode == "run" and b.phase == 2 and said.any(func(t: String) -> bool: return "runs across the ice" in t), b.mode)
	var r0 := b.global_position
	await _watch(b, 4.0)
	_ok("and you have to go after it", b.global_position.distance_to(r0) > 20.0, "%.0f m away" % b.global_position.distance_to(r0))
	_ok("it stayed out of the open water", not lake.in_water(b.global_position) or lake.in_break(b.global_position))
	var eis := int(factions.rep["eisgrund"])
	b.hit(9000.0, b.to_global(Vector3(0.0, 1.4, 2.0)), -b.global_basis.z, 20.0, player)
	await _wait(1.2)
	_ok("the beast dies", b.state == "dead" and "boss_beast" in enemies.dead and bosses.active() == null)
	_ok("it leaves the pelt, once", _bag_with("frost_pelt") == 1 and int(factions.rep["eisgrund"]) == eis + 20, "bags %d, Eisgrund %+d" % [_bag_with("frost_pelt"), int(factions.rep["eisgrund"]) - eis])
	_ok("the pelt is the warmest coat there is", Items.num("frost_pelt", "warm") > Items.num("expedition_suit", "warm") and Items.tier("frost_pelt") == 3)
	player.global_position = b.global_position + Vector3(7, 1.0, 5)
	_look_at(b.global_position + Vector3(0, 0.8, 0))
	await _wait(0.4)
	await _snap("172_beast_dead")

	# ------------------------------------------------------------ K-9
	var kf: Vector3 = Places.D["k9"]
	player.global_position = Vector3(581.0, kf.y + 0.4, 136.5)
	player.velocity = Vector3.ZERO
	_look_at(m.global_position + Vector3(0, 1.6, 0))
	await _wait(0.8)
	await _snap("173_machine")
	m.passive = true
	m.state = "idle"
	var front := -m.global_basis.z
	m.hit(40.0, m.to_global(Vector3(0.0, 1.5, -2.7)), -front, 0.0, player)
	_ok("the hull shrugs a bullet off", is_equal_approx(m.last_damage, 8.0), "%.1f of 40" % m.last_damage)
	m.hit(40.0, m.to_global(Vector3(-1.9, 1.5, 1.6)), m.global_basis.x, 0.0, player)
	_ok("a power cell does not", is_equal_approx(float(m.parts["cell_l"]["hp"]), 110.0), "cell %.0f/150" % float(m.parts["cell_l"]["hp"]))
	var mh := m.health
	for i in 3:
		m.hit(40.0, m.to_global(Vector3(-1.9, 1.5, 1.6)), m.global_basis.x, 0.0, player)
	_ok("one cell gone: phase 2, a big bite out of it", m.phase == 2 and not m.part_alive("cell_l") and m.health < mh - 150.0 and said.any(func(t: String) -> bool: return "left power cell destroyed" in t),
		"health %.0f -> %.0f" % [mh, m.health])
	for i in 2:
		m.hit(40.0, m.to_global(Vector3(0.0, 2.0, -2.2)), -front, 0.0, player)
	_ok("the sensor head can be shot out", not m.part_alive("sensor"))
	# barrels
	var barrels := get_tree().get_nodes_in_group("barrel")
	var near: Barrel = null
	for q in barrels:
		if near == null or (q as Barrel).global_position.distance_to(m.global_position) < near.global_position.distance_to(m.global_position):
			near = q
	mh = m.health
	player.stats.health = 100.0
	var bd := near.global_position.distance_to(m.global_position)
	near.hit(60.0, near.global_position, Vector3.FORWARD, 0.0, player)
	await _wait(0.5)
	_ok("five fuel barrels stand in the chamber", barrels.size() == 5)
	_ok("a barrel next to it hurts more than a rifle", m.health < mh - 50.0 and get_tree().get_nodes_in_group("barrel").size() < 5, "%.0f damage from %.1f m" % [mh - m.health, bd])
	_ok("far from the blast you are safe", player.stats.health > 99.0)
	# it wakes and works through its programme
	m.passive = false
	var m0 := m.global_position
	player.global_position = Vector3(583.0, kf.y + 0.4, 136.0)
	_look_at(m.global_position + Vector3(0, 1.6, 0))
	await _wait(0.4)
	_ok("it wakes when you come close", m.state == "fight" and said.any(func(t: String) -> bool: return "K-9 is still running" in t), m.state)
	m._t = 1.5
	var shots0 := bullets._list.size()
	var got_shot := false
	var modes := {}
	var drone_seen := false
	var drone_snap := false
	var pulled := 0.0
	var last_p := player.global_position
	for i in 180:
		player.stats.health = 100.0
		player.stats.bleeding = 0.0
		modes[m.mode] = true
		if bullets._list.size() > shots0:
			got_shot = true
		if m.mode == "magnet":
			pulled += player.global_position.distance_to(last_p)
		last_p = player.global_position
		if i == 20:
			_look_at(m.global_position + Vector3(0, 1.6, 0))
			await _snap("174_machine_fight")
		if not get_tree().get_nodes_in_group("drone").is_empty():
			drone_seen = true
			if not drone_snap:
				drone_snap = true
				await _wait(0.4)
				_look_at((get_tree().get_nodes_in_group("drone")[0] as Node3D).global_position)
				await _snap("182_mine_drones")
		await _wait(0.1)
	_ok("phase 2: grinds, shoots rivets, brings the roof down", modes.has("grind") and modes.has("rivets") and modes.has("rocks") and got_shot and m.rocks_made >= 4,
		"%s, rocks %d" % [str(modes.keys()), m.rocks_made])
	_ok("its magnet drags you in", modes.has("magnet") and pulled > 3.0, "pulled %.1f m" % pulled)
	_ok("it sends mine drones after you", modes.has("drones") and m.drones_made >= 2 and drone_seen, "%d drones" % m.drones_made)
	var dr := MineDrone.launch(bosses, player.global_position + Vector3(6, 0, 0), player, player.global_position.y - 0.4)
	await _wait(0.1)
	dr.hit(10.0, dr.global_position, Vector3.FORWARD, 0.0, player)
	await _wait(0.1)
	_ok("one shot sets a drone off", not is_instance_valid(dr) or dr.is_queued_for_deletion())
	_ok("it drove, and stayed in its lane", m.global_position.distance_to(m0) > 1.0 and MiningMachine.LANE.grow(0.01).has_point(Vector2(m.global_position.x, m.global_position.z)),
		"moved %.1f m to %s" % [m.global_position.distance_to(m0), str(m.global_position)])
	# a rock on the head
	player.global_position = Vector3(581.0, kf.y + 0.4, 126.0)
	await _wait(0.3)
	player.stats.health = 100.0
	var rock := Rockfall.new()
	rock.player = player
	bosses.add_child(rock)
	rock.global_position = Vector3(581.0, kf.y, 126.0)
	await _wait(0.8)
	var before_rock := player.stats.health
	await _wait(1.4)
	_ok("a falling rock warns first, then hurts", before_rock > 99.0 and player.stats.health < 90.0 and rock.landed, "%.0f -> %.0f" % [before_rock, player.stats.health])
	# phase 3
	m.passive = true
	for i in 4:
		m.hit(40.0, m.to_global(Vector3(1.9, 1.5, 1.6)), -m.global_basis.x, 0.0, player)
	_ok("both cells gone: phase 3, the core lies open", m.phase == 3 and not m._hatch.visible and m.parts_left() == 0)
	m.hit(40.0, m.to_global(Vector3(0.0, 1.5, 3.3)), front, 0.0, player)
	var core_dmg := m.last_damage
	m.hit(40.0, m.to_global(Vector3(0.0, 1.5, -2.7)), -front, 0.0, player)
	_ok("the core is the weak point", core_dmg > 80.0 and m.last_damage < 20.0, "core %.0f, hull %.0f" % [core_dmg, m.last_damage])
	m.passive = false
	player.global_position = Vector3(583.0, kf.y + 0.4, 140.0)
	m._step = 4
	m._t = 0.1
	modes = await _watch(m, 12.0)
	_ok("phase 3: rams and has to vent", modes.has("ram") and modes.has("vent"), str(modes.keys()))
	m.passive = true
	await _wait(0.3)
	player.global_position = m.global_position + m.global_basis.x * 4.0 + Vector3(0, 0.4, 0)
	player.velocity = Vector3.ZERO
	player.stats.health = 100.0
	await _wait(0.3)
	m._steam_blast()
	_ok("venting, it throws a blast of steam", player.stats.health < 95.0 and player.velocity.length() > 2.0, "health %.0f, thrown %.1f m/s" % [player.stats.health, player.velocity.length()])
	m.passive = false
	m.hit(9000.0, m.to_global(Vector3(0.0, 1.5, 3.3)), front, 0.0, player)
	await _wait(1.5)
	_ok("K-9 dies and the wreck stays solid", m.state == "dead" and "boss_machine" in enemies.dead and m.collision_layer == 1)
	_ok("it leaves the plate harness", _bag_with("plate_harness") == 1 and Items.num("plate_harness", "armor") > Items.num("plate_carrier", "armor"))
	player.global_position = Vector3(583.0, kf.y + 0.4, 136.0)
	_look_at(m.global_position + Vector3(0, 1.4, 0))
	await _wait(0.4)
	await _snap("175_machine_dead")

	# ------------------------------------------------------------ Oberst Falk
	c.passive = true
	var cp := c.global_position
	player.global_position = cp + Vector3(0, 0.4, 9.0)
	_look_at(cp + Vector3(0, 1.4, 0))
	await _wait(0.6)
	await _snap("176_commander")
	_ok("Falk is no ordinary guard", c.max_health > 400.0 and c.armor >= 45.0 and c.display_name == "Oberst Falk" and c.faction == "nordwacht")
	c.passive = false
	player.global_position = cp + Vector3(0, 0.4, 32.0)
	_look_at(cp + Vector3(0, 1.4, 0))
	await _wait(0.2)
	c._engage()
	var guns: Dictionary = await _watch(c, 3.0, "weapon")
	_ok("far away he uses the marksman rifle", c.weapon == "marksman_rifle", str(guns.keys()))
	player.global_position = c.global_position + Vector3(0, 0.4, 17.0)
	_look_at(c.global_position + Vector3(0, 1.4, 0))
	guns = await _watch(c, 5.0, "weapon")
	_ok("in the yard he takes the assault rifle", guns.has("assault_rifle"), str(guns.keys()))
	await _snap("177_commander_fight")
	player.global_position = c.global_position + Vector3(0, 0.4, 5.5)
	_look_at(c.global_position + Vector3(0, 1.4, 0))
	guns = await _watch(c, 5.0, "weapon")
	_ok("up close he takes the shotgun", guns.has("shotgun") and c.swaps >= 2, "%s, %d swaps" % [str(guns.keys()), c.swaps])
	# reinforcements
	var n0 := enemies.alive()
	c.hit(150.0, c.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, 999.0, player)
	await _wait(0.4)
	var men := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Raider and e != c and (e as Raider).faction == "nordwacht":
			men += 1
	_ok("at two thirds he calls two men", c.calls == 1 and c.phase == 2 and enemies.alive() == n0 + 2 and men == 2 and said.any(func(t: String) -> bool: return "reinforcements" in t),
		"%d -> %d enemies" % [n0, enemies.alive()])
	var cover_seen := false
	var went := false
	for i in 80:
		player.stats.health = 100.0
		player.stats.bleeding = 0.0
		went = went or c._cover_t > 0.0
		cover_seen = cover_seen or c.in_cover
		await _wait(0.1)
	_ok("hurt, he goes behind cover", went and cover_seen, "went %s, reached %s, he %s, cover %s" % [went, cover_seen, str(c.global_position - Vector3(Places.BASE.x, 0, Places.BASE.y)), str(c._cover - Vector3(Places.BASE.x, 0, Places.BASE.y))])
	c.hit(150.0, c.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, 999.0, player)
	await _wait(0.4)
	_ok("at one third he calls two more", c.calls == 2 and enemies.alive() == n0 + 4)
	# grenades (his men hold their fire for this part)
	var hushed: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != c and not (e as Enemy).passive:
			(e as Enemy).passive = true
			hushed.append(e)
	c.passive = true
	player.global_position = c.global_position + Vector3(0, 0.4, 14.0)
	player.velocity = Vector3.ZERO
	_look_at(c.global_position + Vector3(0, 1.0, 0))
	await _wait(0.3)
	player.stats.health = 100.0
	c.throw_grenade(player.global_position, false)
	var nade: Grenade = null
	for n in c.get_parent().get_children():
		if n is Grenade:
			nade = n
	_ok("he throws a grenade, and you hear about it", nade != null and said.any(func(t: String) -> bool: return t == "Grenade!"))
	await _wait(1.3)
	_look_at(nade.global_position if is_instance_valid(nade) else player.global_position + Vector3(0, 0, -3))
	await _snap("183_grenade")
	await _wait(1.36)
	await _snap("184_grenade_blast")
	_ok("a grenade near your feet hurts", player.stats.health < 95.0, "health %.0f" % player.stats.health)
	player.stats.health = 100.0
	c.throw_grenade(c.global_position.lerp(player.global_position, 0.5), true)
	await _wait(2.6)
	var smoke := false
	for n in c.get_parent().get_children():
		if n is CPUParticles3D and n.has_meta("smoke"):
			smoke = true
	_look_at(c.global_position + Vector3(0, 1.0, 0))
	await _snap("185_smoke")
	_ok("his smoke hides him", smoke)
	for e in hushed:
		if is_instance_valid(e):
			(e as Enemy).passive = false
	player.global_position = c.global_position + Vector3(0, 0.4, 12.0)
	# the last stand
	c.passive = false
	c.health = c.max_health * 0.2
	await _wait(0.6)
	_ok("at a quarter he makes his last stand", c.last_stand and not c.in_cover and said.any(func(t: String) -> bool: return "Für Nordwacht" in t) and is_equal_approx(Engine.time_scale, 1.0),
		"stand %s, cover %s, time %.2f, state %s, passive %s" % [c.last_stand, c.in_cover, Engine.time_scale, c.state, c.passive])
	player.stats.health = 100.0
	_ok("the garrison is hostile while he lives", factions.hostile("nordwacht"))
	c.hit(9000.0, c.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, 999.0, player)
	await _wait(1.0)
	_ok("Falk dies", c.state == "dead" and "boss_commander" in enemies.dead)
	_ok("he leaves his coat and his rifle", _bag_with("commander_coat") == 1 and _bag_with("sniper_rifle") >= 1)
	var calm := true
	var some: Raider = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Raider and (e as Raider).faction == "nordwacht":
			some = e
			calm = calm and (e as Raider).peaceful() and (e as Raider).state == "idle"
	_ok("the garrison stands down", not factions.hostile("nordwacht") and factions.tier("nordwacht") == 2 and calm and some != null, "standing %d" % int(factions.rep["nordwacht"]))
	player.global_position = some.global_position - some.global_basis.z * 6.0 + Vector3(0, 0.4, 0)
	await _watch(some, 3.0, "state")
	_ok("a soldier lets you walk past", some.state == "idle", some.state)
	some.hit(5.0, some.global_position + Vector3(0, 1.0, 0), Vector3.FORWARD, 0.0, player)
	await _watch(some, 1.0, "state")
	_ok("unless you shoot him", some.provoked and some.state == "fight", some.state)

	# ------------------------------------------------------------ saving
	player.global_position = village._w(Vector2(0, 100), 0.5)
	await _wait(0.3)
	var ok := SaveGame.save(self)
	bosses.spawn_all()
	enemies.dead.clear()
	factions.reset()
	await _wait(0.3)
	_ok("a new game has all three alive", bosses.beast.health == bosses.beast.max_health and bosses.machine.state == "idle" and bosses.commander.state == "idle" and bosses.machine.parts_left() == 3)
	ok = ok and SaveGame.load_game(self)
	await _wait(0.5)
	_ok("after loading the dead stay dead", ok and bosses.beast.state == "dead" and bosses.machine.state == "dead" and bosses.commander.state == "dead"
		and bosses.machine.collision_layer == 1 and bosses.active() == null, str(enemies.dead))
	_ok("the rewards are there once, the truce holds", _bag_with("frost_pelt") == 1 and _bag_with("plate_harness") == 1 and _bag_with("commander_coat") == 1 and not factions.hostile("nordwacht"))
	_ok("the dead do not count as enemies", not bosses.beast.is_in_group("enemy") and not bosses.commander.is_in_group("enemy"))
	print("boss test done")
	get_tree().quit()


# ---------------------------------------------------------------- story, menus, map

func _story_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.05
	weather.target_storm = 0.05
	SaveGame.path = "user://test_story.json"
	Settings.data = Settings.DEFAULTS.duplicate(true)
	await _wait(0.5)
	# --- title screen and settings pictures
	menu.show_title()
	_ok("title screen pauses the game", get_tree().paused and menu.page == "title")
	await _snap("190_title")
	menu._back = "title"
	menu._open("settings")
	await _snap("191_settings")
	menu._open("binds")
	await _snap("192_binds")
	menu.close()
	_ok("closing the menu un-pauses", not get_tree().paused and not player.ui_open)
	menu.open_pause()
	await _snap("193_pause")
	menu.close()
	# --- rebinding
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	Settings.bind("jump", ev)
	_ok("K now jumps, Space no longer does", InputMap.event_is_action(ev, "jump") and Settings.keys_of("jump") == "K", Settings.keys_of("jump"))
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_E
	Settings.bind("reload", ev2)
	_ok("taking E for reload takes it away from use", Settings.keys_of("reload") == "E" and not "E" in Settings.keys_of("interact").split(" / "), Settings.keys_of("interact"))
	Settings.set_v("binds", {})
	Settings.apply(self)
	_ok("default keys come back", Settings.keys_of("jump") == "Space" and Settings.keys_of("interact") == "E")
	Settings.set_v("mouse_sens", 2.0)
	Settings.set_v("invert_y", true)
	Settings.set_v("fov", 90.0)
	Settings.apply(self)
	_ok("look settings reach the player", is_equal_approx(player.mouse_sens, 0.0044) and player.invert_y and is_equal_approx(player.camera.fov, 90.0))
	var fps_line := ""
	Engine.max_fps = 0
	for q in 4:
		Settings.set_v("quality", q)
		Settings.apply(self)
		await _wait(2.5)
		fps_line += "%s %.0f   " % [Settings.QUALITY[q], Engine.get_frames_per_second()]
	print("fps by quality in town: ", fps_line)
	Engine.max_fps = 60
	Settings.data = Settings.DEFAULTS.duplicate(true)
	Settings.apply(self)
	# --- the opening
	start_new_game()
	await _wait(0.3)
	_ok("intro cards show", story.is_open() and get_tree().paused)
	await _snap("194_intro")
	story._finish()
	await _wait(0.3)
	_ok("Mirja is not in the valley yet", not _npc("mirja").visible)
	_ok("chapter 1 starts after the intro", quests.status("main_1") == "active" and quests.main_quest() == "main_1")
	var t1 := quests.target("main_1")
	_ok("chapter 1 points at Eisgrund", t1 != Vector3.INF and Vector2(t1.x, t1.z).distance_to(Places.SETTLE) < 10.0, str(t1))
	map.open()
	await _snap("195_map")
	map.close()
	# --- play the chapters through the quest functions
	places.found.append("settle")
	await _wait(1.2)
	_ok("reaching Eisgrund moves on to Tove", quests._step("main_1").get("npc", "") == "tove")
	var opts := quests.options("tove")
	_ok("Tove has the story line to talk about", opts.any(func(o: Array) -> bool: return str(o[1]) == "talk:main_1"), str(opts))
	quests.act("talk:main_1", "tove")
	_ok("chapter 1 done, chapter 2 runs", quests.status("main_1") == "done" and quests.main_quest() == "main_2")
	places.found.append("mine")
	await _wait(1.2)
	_ok("chapter 2 now points at K-9", quests.target("main_2").distance_to(bosses.machine.global_position) < 1.0)
	enemies.dead.append("boss_machine")
	await _wait(1.2)
	quests.act("talk:main_2", "tove")
	_ok("chapter 3 runs", quests.main_quest() == "main_3")
	_ok("chapter 3 points at Order 44", quests.target("main_3") != Vector3.INF)
	reader.found.append("n_tunnel_order")
	places.found.append_array(["bunker1", "base"])
	enemies.dead.append("boss_commander")
	await _wait(3.5)
	_ok("chapter 4 runs after Falk", quests.main_quest() == "main_4", quests.objective(quests.main_quest()))
	places.found.append("station")
	reader.found.append("n_station_log")
	await _wait(1.2)
	_ok("one of two documents read shows progress", quests.objective("main_4").ends_with("(1/2)"), quests.objective("main_4"))
	reader.found.append("n_station_beast")
	await _wait(1.2)
	quests.act("talk:main_4", "aurel")
	_ok("chapter 5 runs", quests.main_quest() == "main_5")
	await _wait(1.2)
	_ok("Mirja waits in Eisgrund now", _npc("mirja").visible and _npc("mirja").collision_layer != 0)
	_ok("the beast drops the heart", "core_heart" in bosses.beast.reward)
	enemies.dead.append("boss_beast")
	await _wait(1.2)
	player.inv.add("core_heart", 1)
	_ok("Tove, Aurel and Pavel can take the heart", quests.options("tove").size() > 0 and quests.options("aurel").size() > 0 and quests.options("pavel").size() > 0)
	_ok("save mid-ending", SaveGame.save(self))
	quests.act("choose:main_5", "tove")
	await _wait(0.3)
	_ok("part one ends and chapter 6 starts", quests.status("main_5") == "done" and quests.outcome("main_5") == "returned" and quests.main_quest() == "main_6")
	_ok("the interlude card shows", story.is_open())
	await _snap("196_ending")
	story._finish()
	_ok("Mirja's blasting charge is in the pack", player.inv.count("blasting_charge") == 1)
	# --- part two: the Vorland
	places.found.append("gorge")
	places.found.append("cordon")
	reader.found.append("n_cordon_order")
	await _wait(3.4)
	_ok("chapter 7 runs", quests.main_quest() == "main_7", quests.main_quest())
	places.found.append("grauwasser")
	await _wait(1.2)
	_ok("the doctor is in the hotel of Grauwasser", _npc("edda") != null and quests.options("edda").size() > 0)
	quests.act("talk:main_7", "edda")
	_ok("Reiss holds the sawmill", bosses.reiss != null and bosses.reiss.boss_name == "Hauptmann Reiss" and quests.target("main_7") != Vector3.INF)
	enemies.dead.append("boss_reiss")
	await _wait(1.2)
	quests.act("talk:main_7", "ragnar")
	_ok("chapter 8 runs", quests.main_quest() == "main_8")
	reader.found.append("n_camp_triage")
	await _wait(1.2)
	_ok("Lars wants the fuse and fuel", quests.act("give:main_8", "lars").begins_with("That is not all"))
	player.inv.add("relay_fuse", 1)
	player.inv.add("fuel_can", 3)
	quests.act("give:main_8", "lars")
	quests.act("talk:main_8", "brandt")
	_ok("chapter 9 runs", quests.main_quest() == "main_9")
	places.found.append("quarry")
	_ok("the Grey Mother carries the rotor hub", bosses.mother != null and "rotor_hub" in bosses.mother.reward)
	enemies.dead.append("boss_mother")
	await _wait(2.4)
	player.inv.add("rotor_hub", 1)
	quests.act("give:main_9", "brandt")
	_ok("chapter 10 runs with the blank manifest", quests.main_quest() == "main_10" and player.inv.count("flight_manifest") == 1)
	_ok("three people can take the manifest", quests.options("brandt").size() > 0 and quests.options("edda").size() > 0 and quests.options("ragnar").size() > 0)
	quests.act("choose:main_10", "ragnar")
	await _wait(0.3)
	_ok("the story ends", quests.status("main_10") == "done" and quests.outcome("main_10") == "line" and quests.main_quest() == "")
	_ok("the epilogue shows", story.is_open())
	await _snap("197_the_end")
	story._i = 1
	story._t = 2.0
	await _snap("198_thanks")
	story._finish()
	# --- the notice boards never run dry
	_ok("three notice boards stand", jobs.boards.size() == 3, "%d" % jobs.boards.size())
	for round in 6:
		var b: JobBoard = jobs.boards[round % 3]
		jobs.use(b)
		var kind := str(jobs.current.get("kind", ""))
		match kind:
			"clear":
				jobs.current["ready"] = true
			"courier":
				b = jobs.boards[int(jobs.current["to"])]
			_:
				player.inv.add(str(jobs.current["item"]), int(jobs.current["n"]))
		jobs.use(b)
	_ok("six board jobs in a row can be done", jobs.done == 6 and jobs.current.is_empty(), "done %d" % jobs.done)
	_ok("the next job is already pinned up", jobs.prompt_for(jobs.boards[0]).begins_with("Take job"), jobs.prompt_for(jobs.boards[0]))
	var crew := jobs.fill(jobs.sites()[0])
	_ok("an emptied camp gets a new crew", crew >= 2, "%d" % crew)
	var jb := jobs.boards[2]
	player.global_position = jb.global_position - jb.global_basis.z * 3.2 + Vector3(0, 0.4, 0)
	_look_at(jb.global_position + Vector3(0, 1.5, 0))
	await _wait(0.6)
	await _snap("199_job_board")
	_ok("load", SaveGame.load_slot(self, SaveGame.slot))
	await _wait(0.4)
	_ok("chapter 5 comes back from the save", quests.status("main_5") == "active" and quests.status("main_4") == "done")
	get_tree().quit()


# ---------------------------------------------------------------- horror mode

## Run with `-- --horror --horrortest`: the dark valley, the Hollow, every puzzle, the ending.
func _horror_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	SaveGame.path = "user://test_horror.json"
	await _wait(0.6)
	_ok("horror mode is on", GameMode.horror() and horror != null)
	_ok("the people are all hidden", people.list.all(func(n: Npc) -> bool: return not n.visible))
	_ok("puzzles are placed", horror.props.size() >= 12 and horror.prop("fusebox") != null and horror.prop("keypad") != null, "%d props" % horror.props.size())
	_ok("three fire baskets in Eisgrund", horror.props.filter(func(p: PuzzleProp) -> bool: return p.id.begins_with("brazier_")).size() == 3)
	# --- menu pictures
	menu.show_title()
	await _snap("200_h_title")
	menu._open("mode")
	await _snap("201_mode_select")
	menu.close()
	start_new_game()
	await _wait(0.3)
	await _snap("202_h_intro")
	story._finish()
	await _wait(0.4)
	_ok("chapter 1 starts", quests.main_quest() == "h_1")
	# --- the dark village
	var sq := village._w(Vector2(0, 30), 1.0)
	player.global_position = sq
	player.velocity = Vector3.ZERO
	_look_at(village._w(Vector2(0, 0), 5.0))
	await _wait(1.5)
	await _snap("203_h_village")
	# --- the Hollow: behind you it comes closer, watched it freezes, the flashlight burns it away
	horror._spawn_t = 999.0
	horror._event_t = 999.0
	_ok("the flashlight starts on in horror mode", player.flashlight.visible)
	player.flashlight.visible = false
	_look_at(sq + Vector3(0, 1.6, -20))
	var h := Hollow.new()
	h.setup(self)
	add_child(h)
	h.place(sq + Vector3(0, 0, 24))
	h.gone.connect(func(_how: String) -> void: pass)
	await _wait(0.5)
	var d0 := h.dist
	await _wait(2.0)
	_ok("unwatched, the Hollow closes in", h.dist < d0 - 4.0, "%.1f → %.1f m" % [d0, h.dist])
	_look_at(h.global_position + Vector3(0, 2.0, 0))
	await _wait(0.4)
	var d1 := h.dist
	await _wait(1.5)
	_ok("watched, it stands still", h.seen and absf(h.dist - d1) < 0.5, "seen %s, %.1f → %.1f m" % [h.seen, d1, h.dist])
	await _snap("204_hollow_far")
	player.flashlight.visible = true
	h.global_position = player.global_position + (h.global_position - player.global_position).normalized() * 5.0
	h.global_position.y = terrain.height_at(h.global_position.x, h.global_position.z)
	_look_at(h.global_position + Vector3(0, 2.1, 0))
	await _wait(0.6)
	var near_fear := horror.fear
	await _snap("205_hollow_close")
	await _wait(1.8)
	_ok("the flashlight drives it off", not is_instance_valid(h) or h.state == "banish")
	await _wait(1.4)
	_ok("fear rises while it is near", near_fear > 0.5, "%.2f" % near_fear)
	# a Hollow that reaches you strikes once and is gone
	var hp0: float = player.stats.health
	var h2 := Hollow.new()
	h2.setup(self)
	add_child(h2)
	h2.place(player.global_position + Vector3(0, 0, 1.2))
	await _wait(0.2)
	await _snap("206_hollow_attack")
	await _wait(0.8)
	_ok("its strike hurts", player.stats.health < hp0 - 10.0, "%.0f → %.0f" % [hp0, player.stats.health])
	_ok("and then it is gone", not is_instance_valid(h2))
	player.stats.health = 100.0
	# --- chapter 1 → 2
	reader.found.append("h_note_square")
	await _wait(1.2)
	_ok("the note starts chapter 2", quests.main_quest() == "h_2", quests.main_quest())
	var fb := horror.prop("fusebox")
	player.global_position = fb.global_position - fb.global_basis.z * 2.2 + Vector3(0, 0.5, 0)
	_look_at(fb.global_position + Vector3(0, 1.5, 0))
	await _wait(0.8)
	await _snap("207_fusebox")
	player.inv.add("fuse", 2)
	horror.use(fb, player)
	_ok("two fuses are not enough", not horror.flags.get("power", false) and int(horror.flags.get("fuses", 0)) == 2)
	_ok("the objective counts fuses", quests.objective("h_2").ends_with("(2/3)"), quests.objective("h_2"))
	player.inv.add("fuse", 1)
	horror.use(fb, player)
	await _wait(1.2)
	_ok("the third fuse brings the power back", horror.flags.get("power", false) and fb.done)
	_ok("Henrik and the villagers come out", _npc("henrik").visible and _npc("marta").visible and not _npc("tove").visible)
	quests.act("talk:h_2", "henrik")
	_ok("chapter 3 runs", quests.main_quest() == "h_3")
	reader.found.append("h_note_toys")
	await _wait(1.2)
	var kp := horror.prop("keypad")
	player.global_position = kp.global_position - kp.global_basis.z * 1.6 + Vector3(0, 0.5, 0)
	_look_at(kp.global_position + Vector3(0, 1.3, 0))
	horror.use(kp, player)
	await _wait(0.3)
	_ok("the number lock opens a keypad", horror.keypad.visible and player.ui_open)
	await _snap("208_keypad")
	horror._on_code("1234")
	await _wait(1.0)
	_ok("a wrong code does nothing", not horror.flags.get("code", false))
	horror._on_code(Horror.CODE)
	await _wait(1.3)
	_ok("the right code opens the shop", horror.flags.get("code", false) and _npc("lena").visible and not horror.keypad.visible)
	var board := horror.props.filter(func(p: PuzzleProp) -> bool: return p.kind == "board")[0] as PuzzleProp
	player.global_position = board.global_position - board.global_basis.z * 2.5 + Vector3(0, 0.5, 0)
	_look_at(board.global_position + Vector3(0, 0.8, 0))
	await _wait(0.6)
	await _snap("209_code_board")
	await _wait(1.2)
	quests.act("talk:h_3", "lena")
	_ok("chapter 4 runs", quests.main_quest() == "h_4")
	reader.found.append("h_note_boxes")
	await _wait(1.2)
	var star := horror.prop("box_star")
	player.global_position = star.global_position - star.global_basis.z * 1.8 + Vector3(0, 0.5, 0)
	_look_at(star.global_position + Vector3(0, 0.7, 0))
	await _wait(0.6)
	await _snap("210_music_box")
	horror.use(horror.prop("box_swan"), player)
	_ok("starting with the swan is wrong", horror._seq.is_empty())
	await _wait(1.6)
	for hh in get_tree().get_nodes_in_group("hollow"):
		hh.queue_free()
	for b in ["star", "swan", "bear"]:
		horror.use(horror.prop("box_" + b), player)
	await _wait(2.5)
	_ok("star, swan, bear rings the bell", horror.flags.get("boxes", false) and _npc("aurel").visible)
	quests.act("talk:h_4", "aurel")
	await _wait(1.2)
	_ok("chapter 5: a child is crying", quests.main_quest() == "h_5" and horror.cry != null and horror.cry.playing)
	_ok("Annika hides in a forest cabin", _npc("annika").visible and Vector2(_npc("annika").global_position.x, _npc("annika").global_position.z).distance_to(Places.SETTLE) > 60.0)
	_ok("the map does not give her away", quests.target("h_5") == Vector3.INF)
	quests.act("talk:h_5", "annika")
	await _wait(1.2)
	_ok("chapter 6 runs, the crying stops", quests.main_quest() == "h_6" and not horror.cry.playing)
	var fires := horror.props.filter(func(p: PuzzleProp) -> bool: return p.kind == "brazier")
	player.inv.remove("firewood", player.inv.count("firewood"))
	horror.use(fires[0], player)
	_ok("no firewood, no fire", not (fires[0] as PuzzleProp).done)
	player.inv.add("firewood", 3)
	for f in fires:
		horror.use(f, player)
	await _wait(1.2)
	_ok("three fires bring Tove out", horror.flags.get("fires", false) and _npc("tove").visible)
	_ok("near a fire you are safe", horror.safe_at((fires[0] as PuzzleProp).global_position + Vector3(2, 0, 0)))
	var f0 := fires[0] as PuzzleProp
	player.global_position = f0.global_position + Vector3(4.0, 0.5, 3.0)
	_look_at(f0.global_position + Vector3(0, 0.8, 0))
	await _wait(0.8)
	await _snap("211_fires")
	quests.act("talk:h_6", "tove")
	_ok("chapter 7: the White One", quests.main_quest() == "h_7")
	# --- a Frozen up close, in the street
	player.global_position = village._w(Vector2(0, 60), 0.5)
	player.velocity = Vector3.ZERO
	var fp := village._w(Vector2(0, 56.5), 0.3)
	var fr := enemies.raider("pistol", fp)
	fr.passive = true
	_ok("raiders are the Frozen here", fr.display_name == "The Frozen")
	_look_at(fr.global_position + Vector3(0, 1.6, 0))
	await _wait(0.6)
	await _snap("212_frozen")
	fr.queue_free()
	# --- saving and loading the puzzles
	_ok("save", SaveGame.save(self))
	horror.from_dict({})
	_ok("cleared flags hide the people again", not _npc("henrik").visible or not horror.flags.get("power", false))
	_ok("load", SaveGame.load_game(self))
	await _wait(0.5)
	_ok("the puzzles come back from the save", horror.flags.get("power", false) and horror.flags.get("fires", false) and _npc("tove").visible)
	enemies.dead.append("boss_beast")
	for i in 40:
		await _wait(0.1)
		if story.is_open():
			break
	_ok("killing the White One ends part one", quests.status("h_7") == "done" and story.is_open())
	await _snap("213_h_ending")
	story._finish()
	await _wait(1.2)
	# --- part two: the fog went south
	_ok("chapter 8 runs with a blasting charge", quests.main_quest() == "h_8" and player.inv.count("blasting_charge") == 1)
	_ok("the Vorland puzzles are placed", horror.prop("generator") != null and horror.prop("radio") != null and horror.props.filter(func(p: PuzzleProp) -> bool: return p.id.begins_with("drum_")).size() == 4)
	_ok("Grauwasser hides", not _npc("ragnar").visible and not _npc("lars").visible)
	places.found.append("cordon")
	reader.found.append("h_note_south")
	places.found.append("grauwasser")
	await _wait(3.4)
	var gen := horror.prop("generator")
	horror.use(gen, player)
	_ok("a dry generator does nothing", not horror.flags.get("siren", false))
	player.inv.add("fuel_can", 3)
	horror.use(gen, player)
	await _wait(1.2)
	_ok("three cans start the siren", horror.flags.get("siren", false) and gen.done and _npc("ragnar").visible and horror._siren != null)
	_ok("the square is safe while the siren sounds", horror.safe_at(Vector3(SiteSouth.TOWN.x, 0, SiteSouth.TOWN.y)))
	player.global_position = gen.global_position + gen.global_basis.z * -2.0 + Vector3(0, 0.3, 0)
	_look_at(gen.global_position + Vector3(0, 0.8, 0))
	await _wait(0.5)
	await _snap("214_h_generator")
	quests.act("talk:h_8", "ragnar")
	_ok("chapter 9 runs", quests.main_quest() == "h_9")
	reader.found.append("h_note_mast")
	await _wait(1.2)
	var radio := horror.prop("radio")
	horror.use(radio, player)
	_ok("the radio lock opens the number pad", horror.keypad.visible)
	horror._on_code(Horror.CODE)
	_ok("the toy shop code is wrong here", not horror.flags.get("radio", false))
	horror._on_code(Horror.RADIO_CODE)
	await _wait(1.2)
	_ok("the frequency brings Lars out", horror.flags.get("radio", false) and _npc("lars").visible)
	quests.act("talk:h_9", "lars")
	_ok("chapter 10 runs", quests.main_quest() == "h_10")
	reader.found.append("h_note_mill")
	await _wait(1.2)
	player.inv.add("firewood", 4)
	for i in 4:
		horror.use(horror.prop("drum_%d" % i), player)
	var dr0 := horror.prop("drum_0")
	player.global_position = dr0.global_position + Vector3(5.0, 0.6, 4.0)
	_look_at(dr0.global_position + Vector3(0, 0.8, 0))
	await _wait(1.3)
	_ok("four fires burn the nest and end the story", horror.flags.get("nest", false) and quests.status("h_10") == "done" and story.is_open())
	await _snap("215_h_nest")
	story._finish()
	var hl := Hollow.new()
	hl.setup(self)
	add_child(hl)
	hl.place(player.global_position + Vector3(0, 0, -6.0))
	var bags0 := get_tree().get_nodes_in_group("loot").size()
	hl.hit(999.0, hl.global_position, Vector3.FORWARD, 0.0, player)
	_ok("a Hollow can be killed and leaves ash", get_tree().get_nodes_in_group("loot").size() == bags0 + 1 and hl.state == "banish")
	_ok("Mirja comes back", _npc("mirja").visible)
	get_tree().quit()


func _all_doors(n: Node, out: Array) -> void:
	if n is Door:
		out.append(n)
	for c in n.get_children():
		_all_doors(c, out)


## Every door in the valley: counts them, opens each one that is not locked, and takes
## pictures of a house door, a cargo door and a barracks door, shut and open.
func _door_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.0
	weather.target_storm = 0.0
	menu.close()
	await _wait(1.0)
	player.stats.set_physics_process(false)
	var doors: Array = []
	_all_doors(self, doors)
	var by_style := {}
	for d: Door in doors:
		var st := "steel_lock" if d is LockDoor and not d.has_meta("style") else str(d.get_meta("style", "?"))
		by_style[st] = int(by_style.get(st, 0)) + 1
	_ok("the valley has doors", doors.size() > 30, str(by_style))
	_ok("containers have cargo doors", int(by_style.get("container", 0)) >= 6)
	_ok("the barracks have doors", int(by_style.get("steel", 0)) >= 2)
	var shots := {"house": "220_door_house", "container": "222_door_cargo", "steel": "224_door_barracks"}
	var shown := {}
	for d: Door in doors:
		var st := str(d.get_meta("style", "?"))
		if not shots.has(st) or shown.has(st) or (d is LockDoor and (d as LockDoor).locked):
			continue
		if st == "container" and d.swing > 0.0:
			continue
		shown[st] = d
		var gt := d.global_transform
		var mid := gt * Vector3(1.1 if st == "container" else 0.5, 1.1, 0.0)
		var out := gt.basis.z
		player.global_position = mid + out * 3.6 + gt.basis.x * (0.3 if st == "container" else 1.2) - Vector3(0, 0.9, 0)
		player.velocity = Vector3.ZERO
		_look_at(mid)
		player.flashlight.visible = true
		await _wait(0.8)
		await _snap(shots[st])
		d.interact(player)
		if st == "container":
			for o: Door in doors:
				if o != d and o.get_meta("style", "") == "container" and o.global_position.distance_to(d.global_position) < 3.0:
					o.interact(player)
		await _wait(1.3)
		await _snap(str(shots[st]).replace("0_", "1_").replace("2_", "3_").replace("4_", "5_"))
	_ok("pictures of three kinds of door", shown.size() == 3, str(shown.keys()))
	var can := 0
	var opened := 0
	for d: Door in doors:
		if d is LockDoor and (d as LockDoor).locked:
			continue
		can += 1
		if not d.is_open:
			d.interact(player)
		if d.is_open:
			opened += 1
	await _wait(1.2)
	var swung := 0
	for d: Door in doors:
		if d.is_open and absf(d.rotation.y) > 1.5:
			swung += 1
	_ok("every door that is not locked opens", opened == can and swung == can, "%d of %d, %d locked with a key" % [swung, can, doors.size() - can])
	get_tree().quit()


## The Vorland: the way through the tunnel, and a picture of every new place.
func _south_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.0
	weather.target_storm = 0.0
	menu.close()
	await _wait(1.0)
	player.stats.set_physics_process(false)
	var f: float = Places.D["tunnel_floor"]
	var fall: Breakable = _gated("tunnel_fall")
	_ok("the roof fall blocks the tunnel", fall != null and not fall.broken)
	var stuck: Vector3 = await _walk_from(Vector3(100.0, f + 0.3, 566.0), PI, 6.0)
	_ok("nobody walks through the fall", stuck.z < 580.0, "stopped at z=%.1f" % stuck.z)
	fall.interact(player)
	_ok("the fall holds without a charge", not fall.broken)
	player.inv.add("blasting_charge")
	fall.interact(player)
	_ok("a blasting charge clears it", fall.broken)
	await _wait(0.4)
	var out: Vector3 = await _walk_from(Vector3(100.0, f + 0.3, 566.0), PI, 12.0)
	_ok("out through the south portal into the gorge", out.z > 604.0, "reached z=%.1f, y=%.1f (floor %.1f)" % [out.z, out.y, f])
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.6
	lamp.omni_range = 60.0
	add_child(lamp)
	var g := func(x: float, z: float, lift: float) -> Vector3:
		return Vector3(x, terrain.height_at(x, z) + lift, z)
	_cam_at(cam, Vector3(100.0, f + 2.2, 640.0), Vector3(100.0, f + 2.6, 596.0))
	lamp.global_position = Vector3(100.0, f + 6.0, 620.0)
	await _snap("400_south_portal")
	_cam_at(cam, g.call(Terrain.gorge_x(700.0), 700.0, 2.0), g.call(Terrain.gorge_x(820.0), 820.0, 4.0))
	await _snap("401_gorge")
	var sites := [["402_cordon", SiteSouth.CHECK, Vector2(-26, 30)], ["403_town_square", SiteSouth.TOWN, Vector2(-30, 44)], ["404_town_street", SiteSouth.TOWN + Vector2(70, 0), Vector2(46, 2)],
		["405_mill", SiteSouth.MILL, Vector2(-34, 34)], ["406_camp", SiteSouth.CAMP, Vector2(-30, 30)], ["407_mast", SiteSouth.MAST, Vector2(26, 22)],
		["408_strip", SiteSouth.STRIP + Vector2(-5, -14), Vector2(-4, 26)], ["409_quarry", SiteSouth.QUARRY, Vector2(-30, 30)], ["410_farm", SiteSouth.FARM, Vector2(26, 26)]]
	for sdef: Array in sites:
		var c: Vector2 = sdef[1]
		var off: Vector2 = sdef[2]
		_cam_at(cam, g.call(c.x + off.x, c.y + off.y, 5.0), g.call(c.x, c.y, 1.6))
		lamp.global_position = g.call(c.x + off.x * 0.5, c.y + off.y * 0.5, 9.0)
		await _snap(str(sdef[0]))
	# from high above: the whole Vorland
	cam.far = 6000.0
	_cam_at(cam, Vector3(0.0, 900.0, 2100.0), Vector3(0.0, 40.0, 1300.0))
	await _snap("411_vorland_air")
	var names := []
	for sp in places.spots:
		names.append(str(sp["id"]))
	for need in ["gorge", "cordon", "grauwasser", "mill", "camp", "mast", "strip", "quarry", "farm"]:
		_ok("place '%s' exists" % need, need in names)
	_ok("Grauwasser has houses", village.houses.size() - SiteSouth.first_house >= 18, "%d houses" % (village.houses.size() - SiteSouth.first_house))
	get_tree().quit()


## Run with `-- --buildtest`: every house must have a whole floor and roof, the snow must not
## come up through the boards, and every door that is not locked must let you walk through.
func _build_test() -> void:
	AudioServer.set_bus_mute(0, true)
	weather.auto_cycle = false
	weather.storm = 0.0
	weather.target_storm = 0.0
	menu.close()
	await _wait(1.0)
	player.stats.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Enemy).passive = true
	var space := player.get_world_3d().direct_space_state
	var homes: Array = []
	for h in village.houses:
		homes.append(h)
	for c in wilds.cabins:
		homes.append(c)
	for c in places.cabins:
		homes.append(c)
	var bad_floor: Array[String] = []
	var bad_roof: Array[String] = []
	var bad_snow: Array[String] = []
	for hv in homes:
		var h: Node3D = hv
		var size: Vector2 = h.get_meta("size")
		var holes := 0
		var open_sky := 0
		var snow := 0
		var nx := int(size.x / 0.8)
		var nz := int(size.y / 0.8)
		for ix in nx:
			for iz in nz:
				var l := Vector3(-size.x * 0.5 + 0.6 + ix * (size.x - 1.2) / maxf(nx - 1, 1), Chalet.Y0 + 1.0, -size.y * 0.5 + 0.6 + iz * (size.y - 1.2) / maxf(nz - 1, 1))
				var g := h.to_global(l)
				var q := PhysicsRayQueryParameters3D.create(g, g + Vector3(0, -2.2, 0))
				q.exclude = [player.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty() or hit.collider == terrain or (hit.collider as Node).get_parent() == terrain:
					holes += 1
				elif terrain.height_at(g.x, g.z) > (hit.position as Vector3).y + 0.03:
					snow += 1
				var q2 := PhysicsRayQueryParameters3D.create(g, g + Vector3(0, 14.0, 0))
				q2.exclude = [player.get_rid()]
				if space.intersect_ray(q2).is_empty():
					open_sky += 1
		var where := "%s at (%.0f, %.0f)" % [str(h.get_meta("kind", h.name)), h.global_position.x, h.global_position.z]
		if holes > 0:
			bad_floor.append("%s: %d" % [where, holes])
		if open_sky > 0:
			bad_roof.append("%s: %d" % [where, open_sky])
		if snow > 0:
			bad_snow.append("%s: %d" % [where, snow])
	_ok("every house has a whole floor", bad_floor.is_empty(), "%d houses; %s" % [homes.size(), ", ".join(bad_floor)])
	_ok("every house has a whole roof", bad_roof.is_empty(), ", ".join(bad_roof))
	_ok("no snow comes up through a floor", bad_snow.is_empty(), ", ".join(bad_snow))
	# --- every door lets you through
	var doors: Array = []
	if not "--stairsonly" in OS.get_cmdline_user_args():
		_all_doors(self, doors)
	var shut: Array[String] = []
	var tried := 0
	for d: Door in doors:
		if (d is LockDoor and (d as LockDoor).locked) or str(d.get_meta("style", "")) == "container":
			continue
		tried += 1
		var gt := d.global_transform
		var mid := gt * Vector3(0.45, 0.0, 0.0)
		var n := gt.basis.z.normalized()
		var ok := false
		var far := 0.0
		for tryi in 6:
			var side: float = 1.0 if tryi % 2 == 0 else -1.0
			var lat: float = [0.0, 0.0, 0.3, 0.3, -0.3, -0.3][tryi]
			if d.is_open:
				d.interact(player)
				await _wait(1.0)
			var start := mid + gt.basis.x.normalized() * lat + n * side * 1.7 + Vector3(0, 0.35, 0)
			player.global_position = start
			player.velocity = Vector3.ZERO
			await _wait(0.15)
			d.interact(player)
			await _wait(1.0)
			var dir := -n * side
			var end: Vector3 = await _walk_from(player.global_position, atan2(-dir.x, -dir.z), 1.7)
			far = (end - mid).dot(dir)
			if far > 0.7:
				ok = true
				break
		if not ok:
			shut.append("%s (%.0f, %.1f, %.0f) got %.1f m" % [str(d.get_meta("style", "?")), gt.origin.x, gt.origin.y, gt.origin.z, far])
			for side: float in [1.0, -1.0]:
				player.global_position = mid + n * side * 4.0 + gt.basis.x.normalized() * 0.8 + Vector3(0, 0.6, 0)
				_look_at(mid + Vector3(0, 1.0, 0))
				player.flashlight.visible = true
				await _wait(0.5)
				await _snap("48%d_blocked_door_%s" % [shut.size(), "a" if side > 0.0 else "b"])
	_ok("you can walk through every unlocked door", shut.is_empty(), "%d doors; blocked: %s" % [tried, "; ".join(shut)])
	# --- every floor of every house can be reached by its stairs
	var floors_tried := 0
	var stuck: Array[String] = []
	for hv in homes:
		var h: Node3D = hv
		if not h.has_meta("stair"):
			continue
		var st: Dictionary = h.get_meta("stair")
		var hb := h.global_basis
		var zm: float = (st.z0 + st.z1) * 0.5
		for f in range(1, int(h.get_meta("floors"))):
			floors_tried += 1
			var y0 := Chalet.Y0 + (0.0 if f == 1 else (f - 1) * Chalet.FH + 0.13)
			var y1 := Chalet.Y0 + f * Chalet.FH + 0.13
			var dir := hb * Vector3.LEFT
			var start := h.to_global(Vector3(st.xa - 0.35, y0 + 0.4, zm))
			await _walk_from(start, atan2(-dir.x, -dir.z), 4.5)
			var up := h.to_local(player.global_position).y
			if up < y1 - 0.3 and stuck.size() < 2:
				Input.action_press("move_forward")
				for fr in 6:
					await get_tree().physics_frame
					for ci in player.get_slide_collision_count():
						var c := player.get_slide_collision(ci)
						print("STAIRDBG feet %s hit %s n %s by %s" % [h.to_local(player.global_position), h.to_local(c.get_position()), hb.inverse() * c.get_normal(), (c.get_collider() as Node).name])
				Input.action_release("move_forward")
			# off the top landing into the corridor
			var out := hb * Vector3.BACK
			var end: Vector3 = await _walk_from(player.global_position, atan2(-out.x, -out.z), 1.2)
			var l := h.to_local(end)
			var ok := absf(l.y - y1) < 0.35 and l.z > float(st.z1) + 0.2
			if not ok:
				stuck.append("%s floor %d: reached %.2f, top %.2f (want %.2f), out at z %.2f" % [str(h.get_meta("kind", h.name)), f, up, l.y, y1, l.z])
				await _snap("49%d_stairs_stuck" % stuck.size())
			if f == 1 and floors_tried <= 1:
				await _snap("49_stairs_top")
	_ok("every upper floor can be reached by stairs", stuck.is_empty() and floors_tried > 0, "%d floors; %s" % [floors_tried, "; ".join(stuck)])
	get_tree().quit()
