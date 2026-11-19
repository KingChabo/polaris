class_name People
extends Node3D
## The friendly people of the valley: who they are, where they live and what they say.

var main: Node
var list: Array[Npc] = []


## Which scanned body (made in Blender) each named person gets.
const BODIES := {"marta": "f_young", "lena": "f_young", "ilse": "f_young", "greta": "f_old", "tove": "f_old",
	"annika": "f_young", "mirja": "f_young", "edda": "f_old", "sigrid": "f_young", "oda": "f_old", "brandt": "f_old",
	"henrik": "m_old", "aurel": "m_old", "ragnar": "m_old", "eino": "m_old", "pavel": "m_dark", "jonas": "m_work",
	"otto": "m_asian", "mikkel": "m_work", "lars": "m_work"}


func _add(id: String, npc_name: String, look: Dictionary, pos: Vector3, yaw: float, lines: Array, opts := {}) -> Npc:
	if BODIES.has(id):
		look = look.duplicate()
		look["body"] = BODIES[id]
	var n := Npc.new()
	n.id = id
	n.npc_name = npc_name
	n.lines = lines.map(func(l): return GameMode.season_text(str(l)) if l is String else l)
	n.gift = opts.get("gift", {})
	n.roam = float(opts.get("roam", 0.0))
	n.pose = str(opts.get("pose", "stand"))
	n.player = main.player
	n.faction = str(opts.get("faction", "village"))
	n.town = main.town
	n.factions = main.factions
	n.setup(look, str(opts.get("weapon", "")))
	add_child(n)
	n.place(pos, yaw)
	list.append(n)
	return n


## The dead come back after a while: named people return home (the story needs them),
## passers-by are replaced by somebody new. Never in sight of the player.
var _revive_check := 0.0

func _process(delta: float) -> void:
	_revive_check -= delta
	var dt := delta
	for n in list:
		if n.dead:
			n.respawn_t -= dt
	if _revive_check > 0.0:
		return
	_revive_check = 2.0
	var p: Player = main.player
	if p == null:
		return
	for n in list:
		if not n.dead or n.respawn_t > 0.0:
			continue
		if p.global_position.distance_to(n.home) < 45.0 or p.global_position.distance_to(n.global_position) < 30.0:
			continue
		if n.has_meta("passer"):
			_replace_passer(n)
		else:
			n.revive()


const FIRST := ["Karin", "Elin", "Nils", "Sven", "Ingrid", "Bo", "Freja", "Leif", "Astrid", "Rune", "Hedda", "Tor", "Signe", "Ulf", "Maja", "Erik"]
const COATS := ["navy", "olive", "red", "cream", "grey", "teal", "fur_brown", "blue"]
var _passer_n := 0

## Passers-by: people out on the streets of Polaris. Killed, they are gone; later someone
## else walks the same street.
func _passers() -> void:
	var v: Village = main.village
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var spots := [Vector2(0, 30), Vector2(0, 70), Vector2(-30, 0), Vector2(35, 0), Vector2(10, -25), Vector2(-15, 45), Vector2(25, 55), Vector2(-40, -20)]
	for sp in spots:
		var at: Vector2 = Terrain.VILLAGE_POS + sp
		var pos := Vector3(at.x, main.terrain.height_at(at.x, at.y) + 0.1, at.y)
		_new_passer(rng, pos)


func _new_passer(rng: RandomNumberGenerator, pos: Vector3) -> Npc:
	_passer_n += 1
	var female := rng.randf() < 0.5
	var look := {"coat": COATS[rng.randi() % COATS.size()], "trousers": ["grey", "navy", "leather", "olive"][rng.randi() % 4],
		"hat": ["none", "beanie", "none", "hood"][rng.randi() % 4], "hair": ["leather", "black", "grey", "white", "cream"][rng.randi() % 5],
		"scarf": ["red", "teal", "none", "cream"][rng.randi() % 4], "pack": rng.randf() < 0.3, "beard": not female and rng.randf() < 0.4,
		"body": (["f_young", "f_old"] if female else ["m_work", "m_old", "m_dark", "m_asian"])[rng.randi() % (2 if female else 4)]}
	var nm: String = FIRST[rng.randi() % FIRST.size()]
	var n := _add("passer_%d" % _passer_n, nm, look, pos, rng.randf() * TAU,
		["Morning. Or whatever this is.", "Mind the raiders up at the cable car.", "Haven't seen the bus come back. Nobody has.", "Keep your head down out there."],
		{"roam": 18.0})
	n.set_meta("passer", true)
	return n


func _replace_passer(old: Npc) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pos := old.home
	list.erase(old)
	old.queue_free()
	_new_passer(rng, pos)


func _in_house(i: int, local: Vector3) -> Vector3:
	var h := main.village.houses[i] as Node3D
	return h.to_global(Chalet.room(h, local) + Vector3(0, Chalet.Y0 + 0.02, 0))


func _house_yaw(i: int, yaw: float) -> float:
	return (main.village.houses[i] as Node3D).rotation.y + yaw


func spawn_all() -> void:
	if "--drivetest" in OS.get_cmdline_user_args():
		return      # nobody may stand on the test track
	var v: Village = main.village
	# --- in the village
	_add("marta", "Marta", {"coat": "cream", "trousers": "leather", "hat": "none", "hair": "leather", "scarf": "red", "pack": false},
		_in_house(2, Vector3(-4.05, 0, -3.72)), _house_yaw(2, PI),
		["Sit down, you look frozen. Tea is on the house — the stove is the only thing still working here.",
		"The raiders took the cable-car station. They come down at night for food.",
		"If you go up to the lake, mind the ice. It sings before it breaks.",
		"Stay as long as you like. It is warm in here."],
		{"gift": {"hot_tea": 1, "canned_food": 1}, "pose": "work"})
	_add("henrik", "Old Henrik", {"coat": "fur_brown", "trousers": "grey", "hat": "none", "hair": "white", "beard": true, "pack": false},
		_in_house(0, Vector3(6.3, 0, -1.95)), _house_yaw(0, 0.0),
		["Forty winters I kept this hotel. Now I keep the fire.",
		"There is an old sabre in the chest by the door. My grandfather's. Better you carry it than they do.",
		"The lights on the big tree have never gone out. Nobody knows who keeps them burning.",
		"Go on, warm yourself."],
		{"pose": "sit"})
	_add("lena", "Lena", {"coat": "teal", "trousers": "navy", "hat": "beanie", "hat_col": "yellow", "scarf": "cream", "pack": false},
		_in_house(1, Vector3(4.15, 0, -2.75)), _house_yaw(1, 0.0),
		["Careful with the shelves! I am the last toymaker in Polaris. Take these, they keep fingers alive.",
		"I still wind up the carousel every morning. Somebody has to.",
		"A flare gun is in the chest. Wolves hate the light.",
		"Come back when the trains run again."],
		{"gift": {"hand_warmer": 2}, "pose": "work"})
	_add("aurel", "Father Aurel", {"coat": "black", "trousers": "black", "hat": "none", "hair": "grey", "scarf": "white", "pack": false},
		v._w(Vector2(62, -66), 0.25) + Basis(Vector3.UP, atan2(-1.0, 1.0)) * Vector3(0.9, 0, -2.4), atan2(-1.0, 1.0) + PI,
		["The door is open for anyone who comes without a gun in their hand. Here, for your wounds.",
		"I ring no bells any more. They carry too far.",
		"Peace be with you."],
		{"gift": {"bandage": 2}})
	_add("jonas", "Jonas", {"coat": "orange", "trousers": "navy", "hat": "ushanka", "hat_col": "fur_dark", "beard": true, "pack": false},
		v._w(Vector2(3.5, 124.0), 0.25), 0.0,
		["You drive? The sled runs. The pickup needs fuel and a new heart — bring scrap to the bonnet and I'll say you did it yourself.",
		"Snow chains. Without them the lake is a skating rink with a grave under it.",
		"Heavy cars and thin ice do not mix. The carrier weighs four tonnes. Think about that.",
		"Check the fuel before you leave. Always."],
		{"gift": {"scrap": 2}, "roam": 4.0})
	_add("ilse", "Ilse", {"coat": "olive", "trousers": "olive", "hat": "helmet", "vest": true, "scarf": "fur_dark", "pack": true},
		v._w(Vector2(-3.0, 112.0), 0.25), PI,
		["Halt. ...You are no raider. Go on in. Take these, you'll need them out there.",
		"Three camps, north and east. Red flags. They post a sniper at the cable-car station.",
		"If you hear wolves, find a wall for your back.",
		"Eyes open."],
		{"gift": {"9mm": 15}, "weapon": "marksman_rifle", "roam": 3.0})
	_add("greta", "Greta", {"coat": "cloth", "trousers": "fur_dark", "hat": "hood", "scarf": "cream", "pack": true},
		v._w(Vector2(9.0, 15.0), 0.25), 1.0,
		["Firewood, firewood, firewood. That is all we talk about now.",
		"Marta at the inn will give you something hot.",
		"Don't stay out in a storm. You stop feeling cold and then you stop feeling anything."],
		{"roam": 11.0})
	_add("otto", "Otto", {"coat": "navy", "trousers": "black", "hat": "ushanka", "hat_col": "navy", "pack": false},
		v._w(Vector2(-11.5, -4.0), 0.25), -1.2,
		["I ran the cable car for thirty years. Now raiders sleep in my station.",
		"There's a rifle in the locker room up there, if they haven't found it. And fuel.",
		"The motor is fine. It is the people who broke down."],
		{"roam": 6.0})
	_add("pavel", "Pavel", {"coat": "fur_dark", "trousers": "leather", "hat": "beanie", "hat_col": "red", "beard": true, "scarf": "green", "pack": false},
		v._w(Vector2(cos(deg_to_rad(22.5)), sin(deg_to_rad(22.5))) * 17.4, 0.25), atan2(cos(deg_to_rad(22.5)), sin(deg_to_rad(22.5))),
		["Kronen still buy things at my stall, friend. And I pay best for scrap — ask anyone.",
		"New goods come when the fishers bring them up. Look in again later.",
		"Glühwein? Ha. I have snow, and hot snow."],
		{})
	# --- outside
	var w: Wilds = main.wilds
	var fs := w.fisher_spot
	var fdir := (Terrain.VILLAGE_POS - Terrain.LAKE_POS).normalized()
	_add("eino", "Eino", {"coat": "navy", "trousers": "fur_dark", "hat": "ushanka", "hat_col": "fur_brown", "beard": true, "scarf": "red", "pack": false},
		fs + Vector3(0, 0.05, 0), atan2(fdir.x, fdir.y),
		["Shh. They bite at dusk, and it is always dusk. Here — smoked this morning.",
		"Dark ice is thin ice. Out in the middle it would not hold a dog.",
		"A snowmobile, fine. Anything with a roof, keep it on the shore."],
		{"gift": {"canned_food": 2}, "pose": "sit", "faction": "eisgrund"})
	var names := [["Runa", "The wall behind the signpost — the Gipfelblick. Take my rope if you mean to climb it. Push into the rock and hold on.", {"rope": 1}],
		["Bram", "Wolves keep to the east woods. Shoot one and the rest think twice.", {"12g": 8}],
		["Sorrel", "I came out here for the quiet. It found me.", {"firewood": 2}]]
	var ni := 0
	for c in w.cabins:
		if not bool(c.get_meta("lit")) or ni >= names.size():
			continue
		var size: Vector2 = c.get_meta("size")
		var d: Array = names[ni]
		var outside := ni == 1
		var pos := c.to_global(Vector3(2.2, 0.3, size.y * 0.5 + 2.4)) if outside else c.to_global(Vector3(0.5, Chalet.Y0 + 0.02, 1.2))
		_add("hermit_%d" % ni, str(d[0]), [{"coat": "fur_brown", "trousers": "olive", "hat": "hood", "beard": false, "scarf": "green"}, {"coat": "camo", "trousers": "fur_dark", "hat": "ushanka", "hat_col": "fur_brown", "beard": true}, {"coat": "leather", "trousers": "grey", "hat": "beanie", "hat_col": "teal", "scarf": "cream"}][ni],
			pos, c.rotation.y,
			[str(d[1]), "Stay by the stove a while. Storms come fast up here.", "Mind how you go."],
			{"gift": d[2], "roam": 5.0 if outside else 0.0, "weapon": "shotgun" if outside else "", "faction": ""})
		ni += 1

	# --- Eisgrund, the fishing hamlet on the lake
	var pl: Places = main.places
	if pl and pl.cabins.size() >= 3:
		var c0: Node3D = pl.cabins[0]
		_add("tove", "Tove", {"coat": "fur_brown", "trousers": "leather", "hat": "hood", "hair": "white", "scarf": "teal", "pack": false},
			c0.to_global(Vector3(0.5, Chalet.Y0 + 0.02, 1.2)), c0.rotation.y,
			["So the village still sends people out. Sit. Arvid left me a key and a bad conscience — you take the key. The mine gate, deep in the Nordstern. And this crowbar: they nailed boards over the mouth of the mine.",
			"Whatever cuts down there at night, it is not one of ours.",
			"The army shut the tunnel and then shut themselves in. Fort Nordwacht, north road. They do not open the gate for anyone.",
			"Cross the Eisklamm on foot if you must. Ice pick, and do not look down."],
			{"gift": {"key_mine": 1, "crowbar": 1}, "pose": "sit", "faction": "eisgrund"})
		var jetty: Vector3 = Places.D.get("jetty", pl.gy(Places.SETTLE))
		_add("mikkel", "Mikkel", {"coat": "navy", "trousers": "olive", "hat": "beanie", "hat_col": "orange", "beard": true, "pack": false},
			jetty, atan2(Terrain.LAKE_POS.x - Places.SETTLE.x, Terrain.LAKE_POS.y - Places.SETTLE.y),
			["Boats are tied up, nobody fishes past the floe any more. Tove gave you her crowbar? Good — it opens more doors than a key ever did. Here, rope, for the cliffs.",
			"The tunnel's service door only sticks. And the shelter in the south meadows, B-5. Same trick.",
			"There is a tower on the east shore. From up there you see the whole Senke.",
			"Keep off the dark ice."],
			{"gift": {"rope": 1}, "faction": "eisgrund"})
		_add("annika", "Annika", {"coat": "red", "trousers": "navy", "hat": "beanie", "hat_col": "cream", "scarf": "yellow", "pack": false},
			pl.gy(Places.SETTLE + Vector2(-2.0, 3.0), 0.3), 0.8,
			["Mind the racks, that is a week of fish. Take some, you look thin.",
			"Something white walks on the lake when the lights come. Grandmother says do not wave at it.",
			"The soldiers took the road signs for the station. As if we would forget where it is."],
			{"gift": {"canned_food": 2}, "roam": 6.0, "faction": "eisgrund"})


		# Mirja, your sister: she only turns up once the story brings her back (chapter 5)
		var mirja := _add("mirja", "Mirja", {"coat": "navy", "trousers": "leather", "hat": "beanie", "hat_col": "cream", "hair": "leather", "scarf": "red", "pack": true},
			c0.to_global(Vector3(-0.6, Chalet.Y0 + 0.02, 0.4)), c0.rotation.y + 0.6,
			["You found me. I am sorry — I could not stay away. The lights call, and nobody else seemed to hear them.",
			"It is out on the ice, far from the shore. It does not want to hurt anyone. It wants to go home, and home is under us.",
			"When it is over, decide for both of us. I trust you more than I trust the lake.",
			"Tove says I can stay as long as I like. I think I might."],
			{"pose": "sit", "faction": "eisgrund"})
		_hide(mirja, true)

	# --- Grauwasser and the Vorland, beyond the tunnel
	var fh := SiteSouth.first_house
	if pl and main.village.houses.size() > fh + 2:
		_add("edda", "Dr. Edda Brandt", {"coat": "white", "trousers": "navy", "hat": "none", "hair": "grey", "scarf": "teal", "pack": false},
			_in_house(fh, Vector3(6.3, 0, -1.95)), _house_yaw(fh, 0.0),
			["You came through the tunnel? Then it is open, and the cordon lied to us for two winters. Sit. Take these.",
			"I run the ward from the hotel now. The army camp was abandoned in one night — the triage notes are still out there.",
			"Reiss took the sawmill and every litre of fuel with it. No fuel, no generator. No generator, no ward.",
			"The sick cannot walk out. Remember that when somebody offers you a seat."],
			{"gift": {"bandage": 3, "painkillers": 1}, "pose": "sit", "faction": "grauwasser"})
		_add("ragnar", "Ragnar Halden", {"coat": "black", "trousers": "grey", "hat": "ushanka", "hat_col": "fur_dark", "beard": true, "hair": "grey", "scarf": "red", "pack": false},
			_in_house(fh + 2, Vector3(-4.05, 0, -3.72)), _house_yaw(fh + 2, PI),
			["Mayor, they call me. Of two hundred souls and a siren. Eat something — you will work for it later.",
			"The notice board on the square is how this town runs. Wolves, raiders, deliveries. It pays, and it never runs dry.",
			"Lars up at the Hochfunk has not had the mast alive since the relay burned. One fuse. That is all that stands between us and the world.",
			"When the helicopter flies again I will have to decide who it is for. I would rather somebody else did."],
			{"gift": {"canned_food": 2, "hot_tea": 1}, "pose": "work", "faction": "grauwasser"})
		_add("sigrid", "Sigrid", {"coat": "green", "trousers": "leather", "hat": "beanie", "hat_col": "red", "scarf": "cream", "pack": false},
			_in_house(fh + 1, Vector3(4.15, 0, -2.75)), _house_yaw(fh + 1, 0.0),
			["Kaufhaus Halden, last department store before the end of the world. I buy pelts, tags, and that grey ash nobody admits to carrying.",
			"Wolf pelts keep this town warm. Bring them clean.",
			"The Grey Mother took three of our hunters at the Steinbruch. Nobody has gone back for the rifles.",
			"Mind the step."],
			{"gift": {"hand_warmer": 2}, "pose": "work", "faction": "grauwasser"})
		var lp: Vector3 = Places.D.get("lars", Vector3.ZERO)
		if lp != Vector3.ZERO:
			_add("lars", "Lars", {"coat": "orange", "trousers": "navy", "hat": "beanie", "hat_col": "navy", "beard": true, "scarf": "grey", "pack": false},
				lp, PI * 0.5,
				["Hochfunk Grauwasser, dead air since the relay fuse blew. The army had spares in the field hospital. I am not going down there.",
				"The log on the desk has the frequency. Three, one, eight, six. I say it in my sleep.",
				"A fuse and a can of fuel for the set, and I can raise the coast.",
				"Keep the door shut. The wind takes the heat in a minute."],
				{"gift": {"batteries": 2}, "faction": "grauwasser"})
		var bp: Vector3 = Places.D.get("brandt", Vector3.ZERO)
		if bp != Vector3.ZERO:
			_add("brandt", "Jorun Brandt", {"coat": "leather", "trousers": "olive", "hat": "ushanka", "hat_col": "fur_brown", "scarf": "white", "pack": false},
				bp, 0.0,
				["Flugfeld Grauwasser. One helicopter, no rotor hub, no fuel. My mother runs the ward; I run this museum.",
				"The spare hub went out with a supply sled two winters ago. They found the sled in the Steinbruch. Nobody found the men.",
				"Bring me the hub and two cans and she flies. Six seats. Think about who sits in them.",
				"I sell what the army left in the stores. Kronen only."],
				{"gift": {"fuel_can": 1}, "faction": "grauwasser"})
		var op: Vector3 = Places.D.get("oda", Vector3.ZERO)
		if op != Vector3.ZERO:
			_add("oda", "Oda", {"coat": "fur_brown", "trousers": "leather", "hat": "hood", "hair": "white", "scarf": "green", "pack": false},
				op, 0.6,
				["Einödhof. My husband wrote that he would be back before the snow. That was the first snow.",
				"The wolves come down from the quarry at night. I keep the barn lit and the gun dry.",
				"Take the eggs. Hens do not care who runs the valley.",
				"If you pass the camp by the forest, do not sleep there."],
				{"gift": {"canned_food": 2, "12g": 6}, "roam": 5.0, "weapon": "shotgun", "faction": "grauwasser"})
	if not GameMode.horror():
		_passers()


## Horror mode: what the hidden people say once you find them.
const HORROR_LINES := {
	"henrik": ["Keep the stove burning. Keep the lights on. That is all we can do now.", "It does not like the bell, Aurel says. It does not like anything warm.", "Do not stand with your back to a window."],
	"lena": ["My hands still shake. I wound the carousel once — it turned all by itself afterwards.", "Take the flares. I will not go out there again.", "The numbers... I am glad I painted them big."],
	"aurel": ["Light is a kind of prayer. Keep yours lit.", "The ones who went out on the ice did not come back. Not as themselves.", "Ring the bell in your heart, child, if you cannot ring the real one."],
	"annika": ["I can still hear it breathing when I close my eyes.", "Grandmother said fire, always fire.", "Do not go back into that cabin."],
	"tove": ["The fires will hold it off a while. Not forever.", "The lights under the ice are brighter every night.", "Go to the lake when you are ready. Not before."],
	"edda": ["The siren keeps them out of the square. I do not know for how long.", "They do not bleed. I have looked. There is only ash.", "My daughter is at the airfield. Tell her to stay inside."],
	"ragnar": ["Two hundred souls. I count them every morning now.", "The nest is at the sawmill. Burn it. All of it.", "Do not let the siren stop."],
	"lars": ["Somebody answered on 3186. I wish I had not heard it.", "Keep your light on me. Please.", "The mast hums when they are near."],
	"mirja": ["I was out on the ice so long. I do not remember the cold any more.", "Don't look at me like that. It is me. It is still me.", "Let's go home. Please. Before the fog comes back."],
}
const HORROR_GENERIC := ["Is it gone? Tell me it is gone.", "We hid in the cellar for three nights. Three.", "Don't stay outside after the lamps flicker.", "Shut the door behind you. Please."]


func horror_setup() -> void:
	var h: Node = main.get("horror")
	for n in list:
		n.lines = HORROR_LINES.get(n.id, HORROR_GENERIC)
		if n.id == "annika" and h:
			var spot: Array = h.annika_spot()
			if not spot.is_empty():
				n.roam = 0.0
				n.place(spot[0], spot[1])
		_hide(n, true)


## Horror mode: who has come out of hiding.
func _horror_show(n: Npc, q: Quests) -> bool:
	var h: Node = main.get("horror")
	var f: Dictionary = h.flags if h else {}
	match n.id:
		"henrik":
			return bool(f.get("power", false))
		"lena":
			return bool(f.get("code", false))
		"aurel":
			return bool(f.get("boxes", false))
		"annika":
			return q.status("h_5") != "none"
		"tove":
			return bool(f.get("fires", false))
		"mirja":
			return q.status("h_7") == "done"
	if n.id == "lars":
		return bool(f.get("radio", false))
	if n.faction == "grauwasser":
		return bool(f.get("siren", false))
	return bool(f.get("power", false)) if n.faction == "village" else bool(f.get("fires", false))


func _hide(n: Npc, hidden: bool) -> void:
	n.visible = not hidden
	n.process_mode = Node.PROCESS_MODE_DISABLED if hidden else Node.PROCESS_MODE_INHERIT
	if hidden:
		if not n.has_meta("layer"):
			n.set_meta("layer", n.collision_layer)
		n.collision_layer = 0
	elif n.has_meta("layer"):
		n.collision_layer = int(n.get_meta("layer"))


## People whose presence follows the story.
func update_story(q: Quests) -> void:
	if GameMode.horror():
		for n in list:
			var show := _horror_show(n, q)
			if show != n.visible:
				_hide(n, not show)
		return
	for n in list:
		if n.id == "mirja":
			var show := q.status("main_4") == "done"
			if show != n.visible:
				_hide(n, not show)


func to_dict() -> Dictionary:
	var out := {}
	for n in list:
		out[n.id] = n.talked
	return out


func from_dict(d: Dictionary) -> void:
	for n in list:
		n.talked = int(d.get(n.id, 0))
