class_name Bosses
extends Node3D
## The three big fights of the valley: where they wait, what they leave behind,
## and what changes when they fall.

const BEAST := Vector2(-330.0, 272.0)       # far out on the lake ice
const IDS := ["boss_beast", "boss_machine", "boss_commander", "boss_reiss", "boss_mother"]

var main: Node
var awake := false           # false in test runs: they stand there and do nothing
var beast: IceBeast
var machine: MiningMachine
var commander: Commander
var reiss: Commander
var mother: GreyMother
var _rng := RandomNumberGenerator.new()


func spawn_all(dead_ids: Array = []) -> void:
	for c in get_children():
		c.queue_free()
	_rng.seed = 9001
	var f: Factions = main.factions if main.get("factions") else null

	beast = IceBeast.new()
	beast.id = "boss_beast"
	beast.lake = main.lake
	beast.setup()
	beast.reward = {"frost_pelt": 1, "coin": 120, "cloth": 4, "core_heart": 1}
	_place(beast, Vector3(BEAST.x, Terrain.LAKE_LEVEL + 0.4, BEAST.y), f)
	beast.rotation.y = 2.2

	machine = MiningMachine.new()
	machine.id = "boss_machine"
	machine.bullets = main.bullets
	machine.setup()
	machine.reward = {"plate_harness": 1, "scrap": 24, "batteries": 6, "coin": 90}
	var kp: Vector3 = Places.D.get("k9", Vector3(600.0, 0.0, 140.0))
	_place(machine, kp + Vector3(0, 0.05, 0), f)
	machine.rotation.y = PI * 0.5
	for b: Vector2 in [Vector2(590.5, 131.6), Vector2(595.5, 148.2), Vector2(601.0, 148.4), Vector2(603.2, 131.8), Vector2(583.0, 146.5)]:
		var br := Barrel.new()
		br.player = main.player
		add_child(br)
		br.global_position = Vector3(b.x, kp.y, b.y)
		br.rotation.y = b.x

	commander = Commander.new()
	commander.id = "boss_commander"
	commander.main = main
	commander.bullets = main.bullets
	commander.setup_boss(_rng)
	commander.reward = {"commander_coat": 1, "sniper_rifle": 1, "338": 20, "coin": 150, "medkit": 1}
	var o := Vector3(Places.BASE.x, float(Places.D.get("base_h", 0.0)), Places.BASE.y)
	_place(commander, o + Vector3(-13.0, 0.4, -5.0), f)
	commander.rotation.y = PI
	for c: Vector2 in [Vector2(-22, -13.2), Vector2(-22, -9.8), Vector2(-7.5, 26.8), Vector2(-7.5, 30.2), Vector2(6, 24.4), Vector2(6, 27.6),
			Vector2(4, -31.5), Vector2(0.8, -27), Vector2(8.4, -27), Vector2(16.2, -27), Vector2(-17.6, -18), Vector2(-28, -12.2),
			Vector2(-34.4, -18), Vector2(-28, -23.8), Vector2(17.6, -23), Vector2(34.4, -23)]:
		commander.cover_points.append(o + Vector3(c.x, 0.1, c.y))
	for b: Array in [[-9.5, -1.0, 0.15], [-17.5, 3.0, -0.2], [-11.0, 9.0, 0.05], [-3.5, -6.0, 1.3], [-20.0, 12.0, 1.1]]:
		for side: float in [-1.0, 1.0]:
			commander.cover_points.append(o + Vector3(b[0], 0.1, b[1]) + Basis(Vector3.UP, float(b[2])) * Vector3(0, 0, side * 0.95))
	commander.rally_points = [o + Vector3(24.0, 0.4, -14.0), o + Vector3(-36.0, 0.4, -6.0), o + Vector3(30.0, 0.4, 14.0), o + Vector3(-30.0, 0.4, 24.0)]

	# --- the Vorland
	reiss = Commander.new()
	reiss.id = "boss_reiss"
	reiss.main = main
	reiss.bullets = main.bullets
	reiss.boss_name = "Hauptmann Reiss"
	reiss.boss_sub = "A deserter with a sawmill full of Red Flags. He hides to reload."
	reiss.voice = "Reiss"
	reiss.cry = "Keiner geht hier lebend raus!"
	reiss.call_line = "Rote Fahne! Her zu mir!"
	reiss.men_name = "Red Flag raider"
	reiss.setup_boss(_rng, {"coat": "red", "trousers": "camo", "hat": "helmet", "beard": true, "hair": "fur_dark",
		"scarf": "black", "vest": true, "pack": false})
	reiss.faction = "raiders"
	reiss.max_health = 520.0
	reiss.health = 520.0
	reiss._last_health = 520.0
	reiss.armor = 50.0
	reiss.reward = {"assault_rifle": 1, "556": 60, "coin": 220, "medkit": 2, "bounty_tag": 5, "plate_carrier": 1}
	_place(reiss, Places.D.get("reiss", Vector3(380.0, 60.0, 1350.0)), f)
	for c in Places.D.get("reiss_cover", []):
		reiss.cover_points.append(c)
	for c in Places.D.get("reiss_rally", []):
		reiss.rally_points.append(c)

	mother = GreyMother.new()
	mother.id = "boss_mother"
	mother.main = main
	mother.setup_boss(_rng)
	mother.reward = {"grey_pelt": 1, "rotor_hub": 1, "wolf_pelt": 3, "coin": 80}
	_place(mother, Places.D.get("mother", Vector3(457.0, 60.0, 1634.0)), f)
	mother.den = mother.global_position

	for b in [beast, machine, commander, reiss, mother]:
		var e: Enemy = b
		e.passive = not awake
		if e.id in dead_ids:
			e.call("make_dead")


func _place(e: Enemy, pos: Vector3, f: Factions) -> void:
	e.player = main.player
	e.factions = f
	if e is Boss:
		(e as Boss).main = main
	add_child(e)
	e.global_position = pos
	e.home = pos


func wake() -> void:
	awake = true
	for c in get_children():
		if c is Enemy and (c as Enemy).state != "dead":
			(c as Enemy).passive = false


## The one you are fighting right now, for the bar at the top of the screen.
func active() -> Enemy:
	for c in get_children():
		if c is Enemy and (c as Enemy).state == "fight" and not c.is_queued_for_deletion():
			var e: Enemy = c
			if e.global_position.distance_to(main.player.global_position) < 150.0:
				return e
	return null


func alive(id: String) -> bool:
	return not (id in main.enemies.dead)


func on_died(e: Enemy) -> void:
	if e.id == "" or e.id in main.enemies.dead:
		return
	main.enemies.dead.append(e.id)
	var f: Factions = main.factions if main.get("factions") else null
	var hud: Node = main.get("hud")
	match e.id:
		"boss_beast":
			if hud:
				hud.banner("THE LAKE IS QUIET", "The White One is dead")
			if f:
				f.add("eisgrund", 20)
		"boss_machine":
			if hud:
				hud.banner("POWER LOST", "K-9 is scrap")
			if f:
				f.add("village", 10)
		"boss_reiss":
			if hud:
				hud.banner("THE RED FLAG IS DOWN", "Hauptmann Reiss is dead")
			if f:
				f.add("grauwasser", 20)
				f.add("village", 5)
		"boss_mother":
			if hud:
				hud.banner("THE QUARRY IS SILENT", "The Grey Mother is dead")
			if f:
				f.add("grauwasser", 15)
		"boss_commander":
			if hud:
				hud.banner("FORT NORDWACHT", "The garrison stands down")
			if f:
				# without the colonel nobody wants this fight: the fort is neutral ground now
				if int(f.rep["nordwacht"]) < 0:
					f.add("nordwacht", -int(f.rep["nordwacht"]))
				f.add("village", 10)
				f.add("eisgrund", 5)
			for n in get_tree().get_nodes_in_group("enemy"):
				if n is Enemy and (n as Enemy).faction == "nordwacht":
					(n as Enemy).provoked = false
					(n as Enemy).calm()
