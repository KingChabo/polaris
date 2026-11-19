class_name SaveGame
## Saves and loads the game as JSON. F5 saves to the current slot, F9 loads the newest of that
## slot and the autosave. Three slots per mode plus one autosave (chapter changes, every 5 min).
## Files are written to .tmp and then swapped in, with the old file kept as .bak, so a crash
## while saving never costs the game.

const VERSION := 2
const SLOTS := 3

static var path := "user://polaris_save.json"   # slot 1 of the mode being played
static var slot := 1


## The file of a slot (1..3) or of the autosave (0) for the current mode.
static func slot_path(n: int) -> String:
	var base := path
	if n == 0:
		return base.replace(".json", "_auto.json")
	return base if n == 1 else base.replace(".json", "_%d.json" % n)


static func exists() -> bool:
	return FileAccess.file_exists(_current()) or FileAccess.file_exists(slot_path(0))


static func _current() -> String:
	return path if slot == 1 else slot_path(slot)


## Short description of a slot for the menu: "Slot 2 — Chapter 3 · 18.11. 21:40" or "empty".
static func describe(n: int) -> String:
	var p := slot_path(n)
	var name := "Autosave" if n == 0 else "Slot %d" % n
	if not FileAccess.file_exists(p):
		return name + "  —  empty"
	var t := Time.get_datetime_dict_from_unix_time(int(FileAccess.get_modified_time(p)) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	var ch := ""
	if typeof(d) == TYPE_DICTIONARY:
		ch = str((d as Dictionary).get("chapter", ""))
	return "%s  —  %s%02d.%02d. %02d:%02d" % [name, (ch + "  ·  ") if ch != "" else "", t["day"], t["month"], t["hour"], t["minute"]]


static func autosave(main: Node) -> bool:
	var keep := slot
	var keep_path := path
	path = slot_path(0)
	slot = 1
	var ok := save(main)
	path = keep_path
	slot = keep
	return ok


## Saves into slot n (1..3) of the mode being played.
static func save_slot(main: Node, n: int) -> bool:
	slot = n
	return save(main)


static func load_slot(main: Node, n: int) -> bool:
	if not FileAccess.file_exists(slot_path(n)):
		return false
	var data := _read(slot_path(n))
	if data.is_empty():
		return false
	if n > 0:
		slot = n
	return _apply(main, data)


static func save(main: Node) -> bool:
	var p: Player = main.player
	var chests := {}
	var bags := []
	for n in main.get_tree().get_nodes_in_group("loot"):
		var box: LootBox = n
		if box.dynamic:
			if not box.items.is_empty():
				var g := box.global_position
				bags.append({"pos": [g.x, g.y, g.z], "items": box.items})
		elif box.id != "":
			chests[box.id] = box.items
	var data := {
		"version": VERSION,
		"chapter": _chapter(main),
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z],
		"yaw": p.rotation.y,
		"stats": p.stats.to_dict(),
		"inventory": p.inv.to_dict(),
		"arms": p.arms.to_dict(),
		"dead": main.enemies.dead,
		"vehicles": main.garage.to_dict(),
		"driving": p.vehicle.id if p.vehicle else "",
		"ice_breaks": main.lake.breaks_list(),
		"chests": chests,
		"bags": bags,
		"storm": main.weather.target_storm,
		"people": main.people.to_dict(),
		"places": main.places.to_dict(),
		"factions": main.factions.to_dict(),
		"trade": main.trade.to_dict(),
		"quests": main.quests.to_dict(),
		"mode": GameMode.mode,
		"jobs": main.jobs.to_dict() if main.get("jobs") else {},
		"horror": main.horror.to_dict() if main.get("horror") else {},
	}
	return _write(_current(), JSON.stringify(data, "\t"))


static func _chapter(main: Node) -> String:
	if not main.get("quests"):
		return ""
	var id: String = main.quests.main_quest()
	if id == "":
		return ""
	return "Chapter %d" % int(id.trim_prefix("main_").trim_prefix("h_"))


## Writes next to the old file first, keeps the old one as .bak, then swaps.
static func _write(p: String, text: String) -> bool:
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	# read it back: only a file that parses replaces the old one
	if typeof(JSON.parse_string(FileAccess.get_file_as_string(tmp))) != TYPE_DICTIONARY:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var gp := ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(gp + ".bak")
		DirAccess.rename_absolute(gp, gp + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), gp) == OK


## The save at p, or its .bak if the file is broken. Old versions are brought up to date.
static func _read(p: String) -> Dictionary:
	for cand in [p, p + ".bak"]:
		if not FileAccess.file_exists(cand):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cand))
		if typeof(parsed) == TYPE_DICTIONARY:
			var d: Dictionary = parsed
			if cand != p:
				push_warning("Save %s was damaged, loaded the backup" % p)
			return _migrate(d)
	return {}


static func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v > VERSION:
		push_warning("Save is from a newer version (%d), loading what we know" % v)
	# v1 -> v2: nothing was renamed, the new fields have defaults
	d["version"] = VERSION
	return d


## Loads the newest of the current slot and the autosave.
static func load_game(main: Node) -> bool:
	var best := ""
	var bt := -1
	for cand in [_current(), slot_path(0)]:
		if FileAccess.file_exists(cand) and int(FileAccess.get_modified_time(cand)) > bt:
			bt = int(FileAccess.get_modified_time(cand))
			best = cand
	if best == "":
		return false
	var data := _read(best)
	if data.is_empty() and best != _current():
		data = _read(_current())
	if data.is_empty():
		return false
	return _apply(main, data)


static func _apply(main: Node, data: Dictionary) -> bool:
	var p: Player = main.player
	p.exit_vehicle(true)
	var pos: Array = data.get("pos", [])
	if pos.size() == 3:
		p.global_position = Vector3(pos[0], pos[1], pos[2])
		p.velocity = Vector3.ZERO
	p.rotation.y = float(data.get("yaw", 0.0))
	p.stats.from_dict(data.get("stats", {}))
	p.inv.from_dict(data.get("inventory", {}))
	p.arms.from_dict(data.get("arms", {}))
	main.enemies.spawn_all(data.get("dead", []))
	if main.get("bosses"):
		main.bosses.spawn_all(data.get("dead", []))
	var chests: Dictionary = data.get("chests", {})
	for n in main.get_tree().get_nodes_in_group("loot"):
		var box: LootBox = n
		if box.dynamic:
			box.remove_from_group("loot")
			box.queue_free()
		elif chests.has(box.id):
			box.items = _counts(chests[box.id])
	for b in data.get("bags", []):
		var bd: Dictionary = b
		var bp: Array = bd.get("pos", [0, 0, 0])
		var bag := LootBox.new()
		bag.setup(true)
		bag.items = _counts(bd.get("items", {}))
		main.add_child(bag)
		bag.global_position = Vector3(bp[0], bp[1], bp[2])
	main.lake.set_breaks(data.get("ice_breaks", []))
	main.garage.from_dict(data.get("vehicles", {}))
	var driving: Vehicle = main.garage.by_id(str(data.get("driving", "")))
	if driving:
		p.enter_vehicle(driving)
	main.weather.target_storm = float(data.get("storm", 0.15))
	main.people.from_dict(data.get("people", {}))
	main.places.from_dict(data.get("places", {}))
	main.factions.from_dict(data.get("factions", {}))
	main.trade.from_dict(data.get("trade", {}))
	main.quests.from_dict(data.get("quests", {}))
	if main.get("horror"):
		main.horror.from_dict(data.get("horror", {}))
	if main.get("jobs"):
		main.jobs.from_dict(data.get("jobs", {}))
	return true


static func _counts(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = int(d[k])
	return out
