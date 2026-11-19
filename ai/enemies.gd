class_name Enemies
extends Node3D
## Places the enemies in the world and remembers who is dead.

var main: Node
var dead: Array[String] = []
var roster := false     # true once the normal enemies have been placed
var _rng := RandomNumberGenerator.new()

# id, weapon, village-local position
const RAIDERS := [
	["raider_1", "pistol", Vector2(74, -92)],
	["raider_2", "shotgun", Vector2(86, -94)],
	["raider_7", "sniper_rifle", Vector2(88, -112)],
]
# who sits at each raider camp out in the wilds
const CAMP_CREWS := [
	["axe", "smg", "pistol"],
	["knife", "assault_rifle", "shotgun", "pistol"],
	["sword", "marksman_rifle", "smg", "sniper_rifle"],
]
# id prefix, centre (world xz), how many
const PACKS := [
	["wolf_a", Vector2(120.0, 90.0), 4],
	["wolf_b", Vector2(20.0, 160.0), 3],
	["wolf_c", Vector2(-395.0, -372.0), 3],
	["wolf_s", Vector2(300.0, 1450.0), 4],
	["wolf_t", Vector2(-300.0, 1650.0), 3],
	["wolf_q", Vector2(452.0, 1622.0), 4],
]


## (Re)creates everyone except those in `dead_ids`.
func spawn_all(dead_ids: Array = []) -> void:
	dead.clear()
	for d in dead_ids:
		dead.append(str(d))
	if not roster and not dead_ids.is_empty():
		return   # test runs without the normal enemies
	for c in get_children():
		c.queue_free()
	_rng.seed = 4711
	roster = true
	for r in RAIDERS:
		var p: Vector2 = r[2]
		for i in 30:   # step away from houses
			if main.village._free(p, 1.5):
				break
			p += Vector2.from_angle(i * 2.4) * 2.0
		var e := raider(str(r[1]), main.village._w(p, 0.3))
		e.id = str(r[0])
		e.rotation.y = _rng.randf() * TAU
		if e.id in dead:
			e.queue_free()
	var camps: Array = main.wilds.camps if main.get("wilds") else []
	for ci in camps.size():
		var crew: Array = CAMP_CREWS[ci % CAMP_CREWS.size()]
		for j in crew.size():
			var a := j * TAU / crew.size() + ci
			var c: Vector3 = camps[ci]
			var q := Vector2(c.x + cos(a) * 3.0, c.z + sin(a) * 3.0)
			var e := raider(str(crew[j]), Vector3(q.x, main.terrain.height_at(q.x, q.y) + 0.3, q.y))
			e.id = "camp_%d_%d" % [ci, j]
			e.rotation.y = _rng.randf() * TAU
			if e.id in dead:
				e.queue_free()
	var guards: Array = main.places.crews if main.get("places") else []
	for g in guards:
		var e := raider(str(g[1]), g[2])
		e.id = str(g[0])
		e.faction = str(g[3]) if g.size() > 3 else "nordwacht"
		if e.faction != "raiders":
			e.loot.erase("bounty_tag")
		e.rotation.y = _rng.randf() * TAU
		if e.id in dead:
			e.queue_free()
	for pk in PACKS:
		var c: Vector2 = pk[1]
		for i in int(pk[2]):
			var q := c + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			var w := wolf(Vector3(q.x, main.terrain.height_at(q.x, q.y) + 0.4, q.y))
			w.id = "%s_%d" % [pk[0], i]
			if w.id in dead:
				w.queue_free()


func _place(e: Enemy, pos: Vector3) -> void:
	e.player = main.player
	e.factions = main.factions if main.get("factions") else null
	add_child(e)
	e.global_position = pos
	e.home = pos


func raider(weapon: String, pos: Vector3) -> Raider:
	var e := Raider.new()
	e.faction = "raiders"
	e.setup(weapon, _rng)
	e.loot["coin"] = 5 + int(Items.num(weapon, "value") / 40.0)
	e.loot["bounty_tag"] = 1
	e.bullets = main.bullets
	_place(e, pos)
	return e


func wolf(pos: Vector3) -> Wolf:
	var e := Wolf.new()
	e.setup(_rng)
	_place(e, pos)
	return e


func on_died(e: Enemy) -> void:
	if e.id != "":
		dead.append(e.id)
	# word gets round: the village likes dead raiders, their friends do not
	var f: Factions = main.factions if main.get("factions") else null
	if f and e.faction != "" and e.state == "dead":
		f.add(e.faction, -4)
		# only the valley's own raiders earn thanks; the ones who drift back in to an
		# emptied camp do not (no endless reputation from the job waves)
		if e.id != "":
			if e.faction == "raiders":
				f.add("village", 2)
			else:
				f.add("eisgrund", 1)


func alive() -> int:
	return get_tree().get_nodes_in_group("enemy").size()
