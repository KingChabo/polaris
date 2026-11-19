class_name Jobs
extends Node
## The game that never ends: notice boards in Polaris, Eisgrund and Grauwasser always have
## one more job, and the wilds fill up again. Every few minutes the raider camps and wolf
## dens that you emptied are taken over by a new, slightly stronger crew.

const WAVE_SECS := 420.0
const SUPPLY := ["firewood", "canned_food", "scrap", "bandage", "batteries", "cloth"]
const BONUS := [{"9mm": 30}, {"bandage": 3}, {"12g": 12}, {"556": 40}, {"medkit": 1}, {"762": 24}, {"flare": 4}, {"338": 8}, {"painkillers": 2}, {"556_ap": 30}]
const TIERS := [["pistol", "knife", "axe", "shotgun"], ["smg", "shotgun", "pistol", "assault_rifle", "sword"],
	["assault_rifle", "marksman_rifle", "smg", "shotgun", "sniper_rifle"]]

var main: Node
var boards: Array[JobBoard] = []
var current := {}          # the job you have taken, or empty
var done := 0              # board jobs finished
var wave := 0              # how often the wilds have filled up again
var _wave_t := 0.0
var _check_t := 0.0


var _quit_ask := 0


func build(m: Node) -> void:
	main = m
	if GameMode.horror() or GameMode.creator():
		return      # the horror night is only the horror story: no notice boards, no odd jobs
	var v: Village = main.village
	var local := Vector2(-13.0, 9.0)
	for i in 60:
		if v._free(local, 1.6):
			break
		local += Vector2.from_angle(i * 2.4) * 1.5
	var pv: Vector3 = v._w(local, 0.0)
	_board("Polaris", "village", pv, atan2(pv.x - Terrain.VILLAGE_POS.x, pv.z - Terrain.VILLAGE_POS.y))
	var pl: Places = main.places
	var es := Places.SETTLE + Vector2(-7.0, -6.0)
	for i in 60:
		var ok: bool = not main.terrain.on_lake(es.x, es.y)
		for cab in pl.cabins:
			var cs: Vector2 = cab.get_meta("size")
			if Vector2(cab.global_position.x, cab.global_position.z).distance_to(es) < cs.length() * 0.5 + 2.5:
				ok = false
		if ok:
			break
		es += Vector2.from_angle(i * 2.4) * 1.5
	_board("Eisgrund", "eisgrund", pl.gy(es), atan2(es.x - Places.SETTLE.x, es.y - Places.SETTLE.y))
	for b in SiteSouth.board_spots:
		_board("Grauwasser", "grauwasser", b[0], float(b[1]))


func _board(place: String, faction: String, pos: Vector3, yaw: float) -> void:
	var b := JobBoard.new()
	b.jobs = self
	b.index = boards.size()
	b.place = place
	b.faction = faction
	b.setup("ARBEIT  ·  " + place.to_upper())
	add_child(b)
	b.global_position = pos
	b.rotation.y = yaw
	boards.append(b)


func level() -> int:
	return mini(done / 2 + wave / 2, 14)


# ---------------------------------------------------------------- where enemies live

## Every camp and den: [name, position, "raider" / "wolf"].
func sites() -> Array:
	var out := []
	var camps: Array = main.wilds.camps if main.get("wilds") else []
	for c in camps:
		out.append(["raider camp", c, "raider"])
	for c: Vector2 in SiteSouth.RAID_CAMPS:
		out.append(["Red Flag camp", Vector3(c.x, main.terrain.height_at(c.x, c.y), c.y), "raider"])
	for pk in Enemies.PACKS:
		var c: Vector2 = pk[1]
		out.append(["wolf den", Vector3(c.x, main.terrain.height_at(c.x, c.y), c.y), "wolf"])
	return out


func living_near(pos: Vector3, reach: float, kind := "") -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Boss or e is Commander or e is GreyMother or (e as Enemy).state == "dead":
			continue
		if kind == "raider" and not (e is Raider and (e as Enemy).faction == "raiders"):
			continue
		if kind == "wolf" and not e is Wolf:
			continue
		if (e as Node3D).global_position.distance_to(pos) < reach:
			n += 1
	return n


## Puts a fresh crew or pack on a site.
func fill(site: Array) -> int:
	var c: Vector3 = site[1]
	var lv := level()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := 0
	if str(site[2]) == "wolf":
		n = clampi(3 + lv / 3, 3, 7)
		for i in n:
			var q := Vector2(c.x + rng.randf_range(-10, 10), c.z + rng.randf_range(-10, 10))
			var w: Wolf = main.enemies.wolf(Vector3(q.x, main.terrain.height_at(q.x, q.y) + 0.4, q.y))
			w.max_health *= 1.0 + lv * 0.07
			w.health = w.max_health
			w.bite += lv * 0.8
	else:
		n = clampi(2 + lv / 2, 2, 7)
		var tier: Array = TIERS[clampi(lv / 4, 0, TIERS.size() - 1)]
		for i in n:
			var a := i * TAU / n + rng.randf()
			var q := Vector2(c.x + cos(a) * 3.4, c.z + sin(a) * 3.4)
			var e: Raider = main.enemies.raider(str(tier[rng.randi() % tier.size()]), Vector3(q.x, main.terrain.height_at(q.x, q.y) + 0.3, q.y))
			e.max_health *= 1.0 + lv * 0.08
			e.health = e.max_health
			e.armor += lv * 2.0
			e.loot["coin"] = int(e.loot.get("coin", 0)) + lv * 3
			e.rotation.y = rng.randf() * TAU
	return n


func _repopulate(force := false) -> int:
	var p: Vector3 = main.player.global_position
	var filled := 0
	for s in sites():
		var c: Vector3 = s[1]
		if not force and c.distance_to(p) < 120.0:
			continue
		if living_near(c, 45.0) > 0:
			continue
		fill(s)
		filled += 1
	return filled


func _process(delta: float) -> void:
	if main == null or main.get("player") == null or get_tree().paused:
		return
	if main.enemies.roster:
		_wave_t += delta
		if _wave_t >= WAVE_SECS:
			_wave_t = 0.0
			wave += 1
			if _repopulate() > 0:
				main.player.message.emit("Word on the road: the camps are filling up again.")
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		if current.get("kind", "") == "clear" and not current.get("ready", false):
			var s: Array = sites()[int(current["site"])]
			if living_near(s[1], 48.0, str(s[2])) == 0:
				current["ready"] = true
				main.player.message.emit("Job done: report back to a notice board.")


# ---------------------------------------------------------------- the jobs

func _dir(from: Vector3, to: Vector3) -> String:
	var d := to - from
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := atan2(d.x, -d.z)
	return "%d m %s" % [int(round(Vector2(d.x, d.z).length() / 10.0) * 10.0), names[int(round(a / (TAU / 8.0)) + 8) % 8]]


## The job pinned to a board right now.
func offer(b: JobBoard) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = done * 7919 + b.index * 131 + 17
	var lv := level()
	var kinds := ["tags", "pelts", "supply", "clear", "courier", "clear", "supply"]
	var kind: String = kinds[rng.randi() % kinds.size()]
	var pay := 50 + lv * 22 + rng.randi_range(0, 30)
	var job := {"kind": kind, "board": b.index}
	match kind:
		"tags":
			job["item"] = "bounty_tag"
			job["n"] = 3 + lv / 2
			job["title"] = "Bounty: %d Red Flag tags" % int(job["n"])
			pay += int(job["n"]) * 14
		"pelts":
			job["item"] = "wolf_pelt"
			job["n"] = 2 + lv / 3
			job["title"] = "Wanted: %d wolf pelts" % int(job["n"])
			pay += int(job["n"]) * 18
		"supply":
			job["item"] = SUPPLY[rng.randi() % SUPPLY.size()]
			job["n"] = 3 + lv / 2
			job["title"] = "Supplies: %d × %s" % [int(job["n"]), Items.name_of(str(job["item"]))]
			pay += int(job["n"]) * int(Items.num(str(job["item"]), "value")) / 2
		"clear":
			var all := sites()
			var near := []
			for i in all.size():
				if (all[i][1] as Vector3).distance_to(b.global_position) < 950.0:
					near.append(i)
			if near.is_empty():
				near.append(0)
			var si: int = near[rng.randi() % near.size()]
			job["site"] = si
			job["title"] = "Clear the %s, %s" % [str(all[si][0]), _dir(b.global_position, all[si][1])]
			pay += 90 + lv * 12
		"courier":
			job["to"] = (b.index + 1 + rng.randi() % maxi(boards.size() - 1, 1)) % boards.size()
			if int(job["to"]) == b.index:
				job["to"] = (b.index + 1) % boards.size()
			job["title"] = "Courier: a supply crate to %s" % boards[int(job["to"])].place
			pay += 70 + int(b.global_position.distance_to(boards[int(job["to"])].global_position) / 12.0)
	job["pay"] = pay
	if done % 3 == 2:
		job["bonus"] = BONUS[(done / 3) % BONUS.size()]
	return job


func objective() -> String:
	if current.is_empty():
		return ""
	var inv: Inventory = main.player.inv
	match str(current["kind"]):
		"clear":
			if current.get("ready", false):
				return "Report back to any notice board"
			var s: Array = sites()[int(current["site"])]
			return "%s  (%d left, %s)" % [str(current["title"]), living_near(s[1], 48.0, str(s[2])), _dir(main.player.global_position, s[1])]
		"courier":
			return "Carry the supply crate to the board in %s" % boards[int(current["to"])].place
	return "%s  (%d/%d) — hand in at any notice board" % [str(current["title"]), mini(inv.count(str(current["item"])), int(current["n"])), int(current["n"])]


func _can_finish(b: JobBoard) -> bool:
	match str(current.get("kind", "")):
		"clear":
			return bool(current.get("ready", false))
		"courier":
			return b.index == int(current["to"]) and main.player.inv.count("supply_crate") > 0
		"":
			return false
	return main.player.inv.count(str(current["item"])) >= int(current["n"])


func prompt_for(b: JobBoard) -> String:
	if current.is_empty():
		var o := offer(b)
		return "Take job:  %s  (%d Kronen)" % [str(o["title"]), int(o["pay"])]
	if _can_finish(b):
		return "Collect %d Kronen:  %s" % [int(current["pay"]), str(current["title"])]
	return "Your job:  " + objective()


func use(b: JobBoard) -> void:
	var pl: Player = main.player
	if current.is_empty():
		current = offer(b)
		if str(current["kind"]) == "courier":
			pl.inv.add("supply_crate", 1)
		elif str(current["kind"]) == "clear":
			var s: Array = sites()[int(current["site"])]
			if living_near(s[1], 48.0, str(s[2])) == 0:
				fill(s)
		Sfx.play(main, "click", b.global_position + Vector3(0, 1.5, 0), 0.0, 1.3)
		main.hud.banner("BOARD JOB", str(current["title"]))
		return
	if not _can_finish(b):
		# a second press soon after gives the job up (a lost crate or an unreachable camp
		# must not block the board for good); it costs a little standing with the board
		if Time.get_ticks_msec() - _quit_ask < 4000:
			_quit_ask = 0
			if str(current.get("kind", "")) == "courier":
				pl.inv.remove("supply_crate", pl.inv.count("supply_crate"))
			if main.get("factions"):
				main.factions.add(b.faction, -2)
			pl.message.emit("You take your notice down. The board gives you a look.")
			current = {}
			return
		_quit_ask = Time.get_ticks_msec()
		pl.message.emit(objective() + "   ·   [E] again to give the job up")
		return
	match str(current["kind"]):
		"courier":
			pl.inv.remove("supply_crate", 1)
		"clear":
			pass
		_:
			pl.inv.remove(str(current["item"]), int(current["n"]))
	pl.inv.add("coin", int(current["pay"]))
	var got: Array[String] = ["%d Kronen" % int(current["pay"])]
	var bonus: Dictionary = current.get("bonus", {})
	for i in bonus:
		pl.inv.add(str(i), int(bonus[i]))
		got.append("%d %s" % [int(bonus[i]), Items.name_of(str(i))])
	pl.message.emit("Received: " + ", ".join(got))
	if main.get("factions"):
		main.factions.add(b.faction, 3)
	done += 1
	main.hud.banner("JOB DONE", "%s  ·  %d finished" % [str(current["title"]), done])
	Sfx.play(main, "chime", b.global_position + Vector3(0, 1.5, 0), 0.0, 1.2)
	current = {}


func to_dict() -> Dictionary:
	return {"done": done, "wave": wave, "t": _wave_t, "current": current.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	done = int(d.get("done", 0))
	wave = int(d.get("wave", 0))
	_wave_t = float(d.get("t", 0.0))
	current = {}
	var c: Dictionary = d.get("current", {})
	for k in c:
		current[str(k)] = c[k]
	for k in ["n", "pay", "site", "to", "board"]:
		if current.has(k):
			current[k] = int(current[k])
	if current.has("bonus"):
		var bonus := {}
		for i in current["bonus"]:
			bonus[str(i)] = int(current["bonus"][i])
		current["bonus"] = bonus
	# the wilds a loaded game finds are as full as the wave says — but never a camp
	# within sight of where you load (no clearing a camp, saving and loading to refill it)
	if wave > 0 and main.enemies.roster:
		_repopulate(false)
