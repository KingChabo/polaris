class_name Garage
extends Node3D
## Puts the vehicles into the world and remembers them for the save file.

# id, type, village-local position (x east, y south), heading (0 = north), fuel share, engine %, cargo
const SPAWNS := [
	["snowmobile_1", "snowmobile", Vector2(7.5, 129.0), 0.3, 0.35, 100.0, {"fuel_can": 1}],
	["pickup_1", "pickup", Vector2(-9.0, 122.0), -0.25, 0.0, 55.0, {"scrap": 3, "winch_kit": 1}],
	["offroader_1", "offroader", Vector2(64.0, -84.0), 2.2, 0.3, 35.0, {"aux_tank": 1, "fuel_can": 1}],
	["tracked_1", "tracked", Vector2(-108.0, 34.0), 1.2, 0.08, 70.0, {"armor_plates": 1, "scrap": 2}],
]

# the Vorland: id, type, world position, heading, fuel share, engine %, cargo
const SOUTH := [
	["snowmobile_2", "snowmobile", Vector2(-108.0, 1425.8), 1.5, 0.5, 90.0, {"fuel_can": 1}],
	["offroader_2", "offroader", Vector2(-140.0, 1693.0), 0.4, 0.2, 60.0, {"snow_chains": 1}],
	["pickup_2", "pickup", Vector2(92.0, 1162.0), 2.9, 0.15, 45.0, {"scrap": 4, "fuel_can": 1}],
]

var main: Node
var list: Array[Vehicle] = []


func spawn_all() -> void:
	for s in SPAWNS:
		var lp: Vector2 = s[2]
		var p := Terrain.VILLAGE_POS + lp
		var v := add_vehicle(s[0], s[1], Vector3(p.x, main.terrain.height_at(p.x, p.y) + 0.4, p.y), s[3])
		v.fuel = v.tank() * float(s[4])
		v.health = s[5]
		v.cargo.items = (s[6] as Dictionary).duplicate()
		v._apply_upgrades()
	if "--drivetest" in OS.get_cmdline_user_args():
		return
	for s in SOUTH:
		var p: Vector2 = s[2]
		var v := add_vehicle(s[0], s[1], Vector3(p.x, main.terrain.height_at(p.x, p.y) + 0.4, p.y), s[3])
		v.fuel = v.tank() * float(s[4])
		v.health = s[5]
		v.cargo.items = (s[6] as Dictionary).duplicate()
		v._apply_upgrades()


func add_vehicle(id: String, type: String, pos: Vector3, yaw: float) -> Vehicle:
	var v := Vehicle.new()
	v.setup(id, type, main)
	add_child(v)
	v.place(Transform3D(Basis(Vector3.UP, yaw), pos))
	list.append(v)
	return v


func by_id(id: String) -> Vehicle:
	for v in list:
		if v.id == id:
			return v
	return null


func to_dict() -> Dictionary:
	var out := {}
	for v in list:
		out[v.id] = v.to_dict()
	return out


func from_dict(d: Dictionary) -> void:
	for id in d:
		var v := by_id(str(id))
		if v:
			v.from_dict(d[id])
