class_name SiteSouth
## The Vorland: the second valley, south of the Polaris tunnel. A gorge road leads from the
## tunnel's far portal down to the army cordon, the town of Grauwasser, the sawmill the Red
## Flags hold, a field hospital, the Hochfunk radio mast, an airstrip, a quarry and a farm.

const CON := "concrete_in"
const F := 0.07

const CHECK := Vector2(74.0, 1150.0)
const JUNC := Vector2(40.0, 1275.0)
const TOWN := Vector2(-120.0, 1420.0)
const MILL := Vector2(380.0, 1340.0)
const CAMP := Vector2(240.0, 1560.0)
const MAST := Vector2(-500.0, 1210.0)
const STRIP := Vector2(-160.0, 1700.0)
const QUARRY := Vector2(440.0, 1640.0)
const FARM := Vector2(-400.0, 1545.0)
const RAID_CAMPS: Array[Vector2] = [Vector2(-330.0, 1335.0), Vector2(150.0, 1745.0)]

static var H := {}                 # ground height of each site
static var first_house := 0        # index of Grauwasser's first house in Village.houses
static var fire_drums: Array = []  # world positions of the four oil drums round the sawmill (horror)
static var board_spots: Array = [] # where the notice boards stand: [position, yaw]
static var siren_pos := Vector3.ZERO
static var radio_pos := Vector3.ZERO
static var gen_pos := Vector3.ZERO


## Shapes the ground of the Vorland. Called from Places.plan, before the ground settles.
static func plan(t: Terrain) -> void:
	H = {}
	var pads: Array = Places.pads
	# the apron in front of the south portal lies level with the tunnel floor
	var ft := t.height_at(100.0, 510.0)
	t.flatten(Vector2(100.0, 612.0), Vector2(9.0, 12.0), 0.0, ft, 6.0)
	for site: Array in [["check", CHECK, Vector2(30, 24)], ["town", TOWN, Vector2(128, 112)], ["mill", MILL, Vector2(40, 32)],
			["camp", CAMP, Vector2(34, 26)], ["mast", MAST, Vector2(20, 18)], ["strip", STRIP, Vector2(130, 26)], ["farm", FARM, Vector2(30, 26)]]:
		var c: Vector2 = site[1]
		var half: Vector2 = site[2]
		var h := t.height_at(c.x, c.y)
		H[site[0]] = h
		t.flatten(c, half, 0.0, h, 22.0)
		pads.append([c, half + Vector2(4, 4)])
	# the quarry: a pit cut eleven metres into the hillside
	var qh := t.height_at(QUARRY.x, QUARRY.y) - 11.0
	H["quarry"] = qh
	t.flatten(QUARRY, Vector2(34, 26), 0.3, qh, 9.0)
	pads.append([QUARRY, Vector2(46, 38)])
	for c: Vector2 in RAID_CAMPS:
		t.flatten(c, Vector2(9, 9), 0.0, t.height_at(c.x, c.y), 8.0)
		pads.append([c, Vector2(13, 13)])
	# --- roads
	var exit := PackedVector2Array()
	var z := 600.0
	while z < 1100.0:
		exit.append(Vector2(Terrain.gorge_x(z), z))
		z += 40.0
	exit.append(CHECK + Vector2(0, -20))
	exit.append(CHECK + Vector2(0, 26))
	exit.append(JUNC)
	var defs := {
		"exit": exit,
		"town": [JUNC, Vector2(10, 1370), TOWN + Vector2(118, 0)],
		"mill": [JUNC, Vector2(170, 1300), MILL + Vector2(-44, 4)],
		"camp": [JUNC, Vector2(120, 1420), CAMP + Vector2(-30, -20), CAMP + Vector2(40, 30), QUARRY + Vector2(-52, -10)],
		"mast": [TOWN + Vector2(-118, 0), Vector2(-340, 1330), MAST + Vector2(24, 16)],
		"strip": [TOWN + Vector2(0, 104), Vector2(-130, 1600), STRIP + Vector2(-20, -30)],
		"farm": [TOWN + Vector2(-118, 0), Vector2(-300, 1470), FARM + Vector2(30, -8)],
	}
	for name in defs:
		Places.roads[name] = t.road(PackedVector2Array(defs[name]))
	# town streets and the runway
	t.road(PackedVector2Array([TOWN + Vector2(-118, 0), TOWN + Vector2(118, 0)]), 4.0, 3.0)
	t.road(PackedVector2Array([TOWN + Vector2(0, -60), TOWN + Vector2(0, 104)]), 4.0, 3.0)
	t.pave(TOWN, 20.0)
	t.road(PackedVector2Array([STRIP + Vector2(-120, 0), STRIP + Vector2(120, 0)]), 9.0, 4.0)
	t.pave(CHECK, 16.0)
	t.pave(MILL, 22.0)


static func _o(site: String, c: Vector2) -> Vector3:
	return Vector3(c.x, float(H[site]), c.y)


## A plain hut in the current place's coordinates: four walls, a flat roof with snow, windows
## in the north wall, and a working door in the south wall at `door_x`.
static func _hut(pl: Places, o: Vector3, x0: float, z0: float, x1: float, z1: float, h: float, wall: String, floor_mat: String,
		door_x: float, warm: bool, wins: Array = [], extra := {}) -> void:
	var gaps := {"s": [[door_x, 1.1, 2.1]], "n": []}
	for w: float in wins:
		(gaps["n"] as Array).append([w, 1.4, 2.0, 1.0])
	for side in extra:
		if not gaps.has(side):
			gaps[side] = []
		(gaps[side] as Array).append_array(extra[side])
	Struct.room(pl.k, x0, z0, x1, z1, F, h, wall, floor_mat, wall + ("" if wall.ends_with("_in") else "_in"), gaps, 0.3)
	pl.k.box(Vector3((x0 + x1) * 0.5, h + F + 0.4, (z0 + z1) * 0.5), Vector3(x1 - x0 + 1.0, 0.22, z1 - z0 + 1.0), wall)
	pl.k.box(Vector3((x0 + x1) * 0.5, h + F + 0.62, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.7, 0.24, z1 - z0 + 0.7), "snow")
	pl.roofed(x0, z0, x1, z1, h + 0.1, warm)
	for w: float in wins:
		SiteBase._glass(pl.kd, Vector3(w, 1.57, z0 - 0.15), true, 1.4, warm)
	pl.door(o + Vector3(door_x - 0.55, F, z1 + 0.15), 0.0, 1.1, 2.08)
	# a step and a mat so the threshold reads as a way in
	pl.kd.box(Vector3(door_x, 0.03, z1 + 0.75), Vector3(1.5, 0.06, 0.8), "planks")


static func _tent(k: MeshKit, at: Vector3, yaw: float, cloth: String) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), at)
	var a := Vector3(-1.6, 0, 2.2)
	var b := Vector3(1.6, 0, 2.2)
	var c := Vector3(0, 2.0, 2.2)
	var a2 := Vector3(-1.6, 0, -2.2)
	var b2 := Vector3(1.6, 0, -2.2)
	var c2 := Vector3(0, 2.0, -2.2)
	k.quad_o(a, a2, c2, c, Vector3(-1, 1, 0), cloth)
	k.quad_o(a, a2, c2, c, Vector3(1, -1, 0), cloth + "_in")
	k.quad_o(b, b2, c2, c, Vector3(1, 1, 0), cloth)
	k.quad_o(b, b2, c2, c, Vector3(-1, -1, 0), cloth + "_in")
	k.tri_o(a2, b2, c2, Vector3(0, 0, -1), cloth)
	k.tri_o(a2, b2, c2, Vector3(0, 0, 1), cloth + "_in")
	for zz: float in [-2.2, 2.2]:
		k.cyl(Vector3(0, 0, zz), 0.035, 2.1, "wood_dark", 5)
	k.bbox(Vector3(-0.7, 0.25, -0.6), Vector3(0.8, 0.12, 2.0), 0.04, "white_in")
	k.bbox(Vector3(0.7, 0.25, -0.6), Vector3(0.8, 0.12, 2.0), 0.04, "white_in")
	for sx: float in [-1.0, 1.0]:
		for q in 4:
			k.cyl(Vector3(sx * 0.7 + (q % 2 - 0.5) * 0.7, 0.0, -0.6 + (q / 2 - 0.5) * 1.8), 0.02, 0.22, "metal_in", 4)
	k.ball(Vector3(0.0, 2.05, 0.0), Vector3(1.5, 0.12, 2.2), "snow", 8, 3)
	k.xf = xf


static func _log_pile(k: MeshKit, p: Vector3, yaw: float, n: int, len := 5.0) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), p)
	var row := n
	var y := 0.28
	while row > 0:
		for i in row:
			var x := (i - (row - 1) * 0.5) * 0.58
			k.tube(Vector3(x, y, -len * 0.5), Vector3(x, y, len * 0.5), 0.28, "wood", 8)
		row -= 1
		y += 0.5
	k.ball(Vector3(0, y - 0.1, 0), Vector3(n * 0.2, 0.14, len * 0.5), "snow", 8, 3)
	k.xf = xf


static func _street_light(pl: Places, p: Vector3, yaw: float, lit: bool) -> void:
	pl.at(p, yaw)
	Props.street_light(pl.k, lit)
	if lit:
		pl.lamp(p + Basis(Vector3.UP, yaw) * Vector3(0, 5.4, -1.2), Props.SODIUM, 2.2, 17.0)


static func build(pl: Places) -> void:
	fire_drums.clear()
	board_spots.clear()
	_gorge(pl)
	pl.flush()
	_cordon(pl)
	pl.flush()
	_town(pl)
	pl.flush()
	_mill(pl)
	pl.flush()
	_camp(pl)
	pl.flush()
	_mast(pl)
	pl.flush()
	_strip(pl)
	pl.flush()
	_quarry(pl)
	_farm(pl)
	pl.flush()
	_raid_camps(pl)
	pl.flush()


# ---------------------------------------------------------------- the gorge road

static func _gorge(pl: Places) -> void:
	var t := pl.terrain
	var k := pl.k
	var kd := pl.kd
	pl.at(Vector3.ZERO)
	var f: float = Places.D["tunnel_floor"]
	# the far portal: apron, kerbs, a rusted barrier nobody manned
	k.box(Vector3(100.0, f - 0.12, 606.0), Vector3(16.0, 0.2, 20.0), "tar")
	for x: float in [96.0, 104.0]:
		k.box(Vector3(x, f + 0.45, 618.0), Vector3(2.6, 0.9, 0.7), "concrete")
		kd.box(Vector3(x, f + 0.5, 618.37), Vector3(2.4, 0.3, 0.02), "hazard")
	var sp := Struct.sign(k, Vector3(108.5, f, 622.0), 0.0, 3.0, 1.3, "paint_red", 2.6)
	pl.label("QUARANTÄNEZONE SENKE\nDurchfahrt verboten\nSperre Süd 550 m", sp, 0.0, 0.004, Color(0.95, 0.93, 0.85))
	pl.spot("gorge", "Talausfahrt Gorge", Vector3(100.0, f, 612.0), 16.0)
	# what the last convoy left on the way down
	pl._wreck("exit", 0.2, "offroader", 3.4, 0.6, 0.2, {"556": 30, "bandage": 2, "canned_food": 2})
	pl._wreck("exit", 0.42, "pickup", -3.2, 2.6, 0.0, {"fuel_can": 1, "scrap": 3})
	pl._wreck("exit", 0.6, "tracked", 3.0, 0.2, 0.0, {"762": 30, "helmet": 1, "medkit": 1})
	pl._wreck("town", 0.5, "pickup", -3.4, 1.2, 0.3, {"12g": 12, "cloth": 2})
	pl._wreck("camp", 0.3, "offroader", 3.2, -0.5, 0.0, {"painkillers": 2, "bandage": 3})
	pl._wreck("mast", 0.55, "snowmobile", -2.8, 0.9, 0.5)
	pl._wreck("strip", 0.5, "pickup", 3.0, 2.2, 0.0, {"fuel_can": 1, "batteries": 2})
	pl.at(Vector3.ZERO)
	# rock that came down from the walls
	for q in 7:
		var z := 660.0 + q * 62.0
		var x := Terrain.gorge_x(z) + (11.0 if q % 2 == 0 else -11.0)
		Struct.rubble(k, pl.rng, Vector3(x, t.height_at(x, z), z), 3.0, 7, "rock", 1.6)
	pl._signpost(JUNC + Vector2(7, 5), [["GRAUWASSER 2 km", "paint_blue"], ["SÄGEWERK · STEINBRUCH", "paint_yellow"], ["POLARISTUNNEL · GESPERRT", "paint_red"]], 0.6)
	pl._signpost(TOWN + Vector2(-124, 7), [["HOCHFUNK", "paint_blue"], ["HOF LINDGREN", "paint_green"]], 1.2)
	pl._signpost(TOWN + Vector2(7, 110), [["FLUGFELD", "paint_blue"]], 0.2)


# ---------------------------------------------------------------- Sperre Süd

static func _cordon(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var o := _o("check", CHECK)
	pl.at(o)
	# guard house
	_hut(pl, o, -20.0, -8.0, -12.0, -2.0, 2.6, "olive", "planks_in", -16.0, true, [-17.5])
	Interior.table(k, Vector3(-18.6, F, -6.8), 0.0, 1.6, 0.8)
	Interior.chair(k, Vector3(-18.6, F, -5.9), PI)
	Struct.bunk(k, Vector3(-13.0, F, -6.6), 0.0)
	Interior.lockers(k, Vector3(-13.4, F, -2.5), PI, 2)
	pl.note("n_cordon_order", o + Vector3(-18.3, F + 0.78, -6.8), 0.3, "folder")
	pl.chest(o + Vector3(-19.3, F, -2.8), PI * 0.5, "cordon_hut", {"556": 60, "medkit": 1, "canned_food": 3, "hand_warmer": 2, "flare": 4, "fuel_can": 1}, "Duty chest")
	pl.lamp(o + Vector3(-16.0, 2.2, -5.0), Props.WARM, 1.6, 9.0, false, true)
	# the barrier across the road, sandbags, a tower, containers
	for sx: float in [-1.0, 1.0]:
		k.cyl(Vector3(sx * 5.2, -0.2, 6.0), 0.12, 1.4, "paint_red", 8)
	k.box(Vector3(0.0, 1.05, 6.0), Vector3(10.2, 0.14, 0.14), "paint_white", Basis(Vector3(0, 0, 1), 0.5) * Basis.IDENTITY)
	for i in 5:
		kd.box(Vector3(-4.0 + i * 2.0, 1.05 + (i - 2) * 0.96, 6.0), Vector3(0.6, 0.15, 0.15), "paint_red", Basis(Vector3(0, 0, 1), 0.5))
	Struct.sandbags(k, Vector3(-7.5, 0, 9.0), 0.0, 6)
	Struct.sandbags(k, Vector3(7.5, 0, 9.0), 0.0, 6)
	Struct.sandbags(k, Vector3(8.5, 0, -6.0), PI * 0.5, 5)
	Struct.tower(k, Vector3(16.0, 0, 8.0), PI, 6.0)
	Struct.container(k, Vector3(18.0, 0, -8.0), PI * 0.5, "olive", true)
	pl.cargo_doors(o + Vector3(18.0, 0, -8.0), PI * 0.5, "olive")
	pl.chest(o + Vector3(15.6, 0.07, -8.0), PI * 0.5, "cordon_box", {"12g": 16, "kevlar_vest": 1, "scrap": 4, "batteries": 3, "762": 30}, "Supply crate")
	Struct.container(k, Vector3(18.0, 0, -12.0), PI * 0.5, "navy")
	var lp := Struct.floodlight(k, Vector3(-8.0, 0, 2.0), 0.6, true, 6.0)
	pl.lamp(k.xf * lp, Color(0.9, 0.95, 1.0), 2.6, 24.0, true, true)
	Struct.truck(k, Vector3(-9.0, 0, -14.0), 0.4, false, 0.2)
	for i in 5:
		Struct.fence(k, Vector3(-28.0, 0, -22.0 + i * 9.0), Vector3(-28.0, 0, -13.0 + i * 9.0))
		Struct.fence(k, Vector3(28.0, 0, -22.0 + i * 9.0), Vector3(28.0, 0, -13.0 + i * 9.0))
	var sg := Struct.sign(k, Vector3(7.0, 0, -18.0), PI, 2.6, 1.2, "paint_red", 2.6)
	pl.label("SPERRE SÜD\nHalt! Ausweis bereithalten", o + sg, PI, 0.0038, Color(0.95, 0.93, 0.85))
	pl.crews.append(["cordon_0", "assault_rifle", o + Vector3(-4.0, 0.3, 10.0), "nordwacht"])
	pl.crews.append(["cordon_1", "shotgun", o + Vector3(5.0, 0.3, 11.0), "nordwacht"])
	pl.crews.append(["cordon_2", "marksman_rifle", o + Vector3(12.0, 0.3, -3.0), "nordwacht"])
	pl.spot("cordon", "Sperre Süd (army cordon)", o, 36.0)


# ---------------------------------------------------------------- Grauwasser

static func _town(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var v := pl.village
	var rng := pl.rng
	var o := _o("town", TOWN)
	first_house = v.houses.size()
	# 0 Gasthof (the doctor's surgery), 1 Kaufhaus, 2 the mayor's inn, then homes
	v.house_world("hotel", TOWN + Vector2(0, -52), Vector2(0, 1), true)
	v.house_world("toyshop", TOWN + Vector2(-36, -30), Vector2(1, 1).normalized(), true)
	v.house_world("restaurant", TOWN + Vector2(36, -30), Vector2(-1, 1).normalized(), true)
	v.house_world("station", TOWN + Vector2(86, 62), Vector2(-1, 0), false)
	for i in 3:
		var x := 54.0 + i * 22.0
		v.house_world("house", TOWN + Vector2(x, -17), Vector2(0, 1), rng.randf() < 0.45)
		v.house_world("house", TOWN + Vector2(-x, -17), Vector2(0, 1), rng.randf() < 0.45)
		v.house_world("house", TOWN + Vector2(-x, 17), Vector2(0, -1), rng.randf() < 0.45)
		if i < 2:
			v.house_world("house", TOWN + Vector2(x, 17), Vector2(0, -1), rng.randf() < 0.45)
	for i in 3:
		var z := 42.0 + i * 21.0
		v.house_world("house", TOWN + Vector2(-16, z), Vector2(1, 0), rng.randf() < 0.45)
		v.house_world("house", TOWN + Vector2(16, z), Vector2(-1, 0), rng.randf() < 0.45)
	for i in 2:
		v.house_world("cabin", TOWN + Vector2(-92 + i * 40.0, 58), Vector2(0, -1), i == 0)
	# the chapel, north-east of the square
	pl.at(o + Vector3(64.0, pl.terrain.height_at(TOWN.x + 64.0, TOWN.y - 62.0) - o.y, -62.0), atan2(-1.0, 1.0))
	Props.chapel(k, rng)
	pl.lamp(o + Vector3(60.0, 3.0, -58.0), Props.WARM, 1.2, 9.0, true)
	# the square: a war memorial, the siren mast, benches, the notice board
	pl.at(o)
	k.cyl(Vector3(0, -0.2, 0), 2.4, 0.5, "concrete", 12)
	k.cyl(Vector3(0, 0.3, 0), 1.5, 0.4, "concrete", 12)
	k.box(Vector3(0, 2.1, 0), Vector3(0.9, 3.2, 0.9), "rock")
	k.ball(Vector3(0, 3.8, 0), Vector3(0.75, 0.2, 0.75), "stone" if GameMode.summer() else "snow", 8, 3)
	kd.box(Vector3(0, 1.5, -0.46), Vector3(0.6, 0.9, 0.02), "brass")
	pl.label("GRAUWASSER\n1914 · 1939\nUNSEREN TOTEN", o + Vector3(0, 1.5, -0.48), PI, 0.0028, Color(0.15, 0.12, 0.08))
	k.cyl(Vector3(13.0, -0.3, -9.0), 0.11, 9.5, "steel", 8)
	for q in 4:
		var a := q * TAU / 4.0
		k.tube(Vector3(13.0, 9.0, -9.0), Vector3(13.0 + cos(a) * 0.7, 9.0, -9.0 + sin(a) * 0.7), 0.16, "paint_red", 8, 0.3)
	siren_pos = o + Vector3(13.0, 1.2, -9.0)
	k.bbox(Vector3(13.0, 1.2, -8.82), Vector3(0.34, 0.5, 0.2), 0.02, "grey")
	kd.box(Vector3(13.0, 1.3, -8.71), Vector3(0.08, 0.08, 0.02), "led_red")
	for b in [[-9.0, 9.0, 0.6], [9.0, 9.0, -0.6], [-9.5, -8.0, 2.4]]:
		k.xf = Transform3D(Basis(Vector3.UP, float(b[2])), o + Vector3(float(b[0]), 0, float(b[1])))
		Props.bench(k)
	pl.at(o)
	board_spots.append([o + Vector3(-13.0, 0, 6.0), 0.9])
	pl.note("n_gw_notice", o + Vector3(-12.2, 1.45, 6.9), 0.9 + PI)
	# lights along both streets, poles, a bus shelter, cars left where they stopped
	var n := 0
	for x: float in [-100.0, -64.0, -30.0, 30.0, 64.0, 100.0]:
		_street_light(pl, Vector3(TOWN.x + x, pl.terrain.height_at(TOWN.x + x, TOWN.y - 6.4), TOWN.y - 6.4), 0.0, n % 3 != 1)
		n += 1
	for z: float in [34.0, 70.0, 100.0]:
		_street_light(pl, Vector3(TOWN.x + 6.4, pl.terrain.height_at(TOWN.x + 6.4, TOWN.y + z), TOWN.y + z), PI * 0.5, n % 2 == 0)
		n += 1
	for c in [[-44.0, 5.6, 0.1], [22.0, -5.4, PI], [78.0, 5.4, 0.2], [-5.2, 52.0, PI * 0.5], [5.4, 84.0, -PI * 0.5], [-88.0, -5.6, PI + 0.3]]:
		var cp := Vector3(TOWN.x + float(c[0]), 0, TOWN.y + float(c[1]))
		cp.y = pl.terrain.height_at(cp.x, cp.z)
		pl.at(cp, float(c[2]))
		Props.car(k, rng, not GameMode.summer())
	pl.at(Vector3(TOWN.x - 22.0, pl.terrain.height_at(TOWN.x - 22.0, TOWN.y + 8.0), TOWN.y + 8.0), PI)
	Props.bus_shelter(k, true)
	pl.lamp(Vector3(TOWN.x - 22.0, o.y + 2.2, TOWN.y + 8.0), Props.WARM, 1.0, 7.0)
	for i in 7:
		var px := TOWN.x - 112.0 + i * 37.0
		pl.at(Vector3(px, pl.terrain.height_at(px, TOWN.y + 7.6), TOWN.y + 7.6), PI * 0.5)
		Props.utility_pole(k, i % 3 == 1)
	for hy in [[-58.0, -6.2], [48.0, 6.2], [5.8, 60.0]]:
		pl.at(Vector3(TOWN.x + float(hy[0]), pl.terrain.height_at(TOWN.x + float(hy[0]), TOWN.y + float(hy[1])), TOWN.y + float(hy[1])))
		Props.hydrant(k)
	pl.at(o)
	# the generator in the Gasthof yard that drives the siren (and the town's pumps)
	gen_pos = o + Vector3(15.0, 0.0, -58.0)
	_hut(pl, o, 12.0, -62.0, 18.0, -56.0, 2.4, "planks", CON, 15.0, false)
	Struct.generator(k, Vector3(16.4, F, -60.0), 0.0)
	pl.chest(o + Vector3(12.8, F, -61.2), PI * 0.5, "gw_gen", {"fuel_can": 1, "scrap": 3, "batteries": 2}, "Tool box")
	_town_life(pl, o)
	pl.spot("grauwasser", "Grauwasser", o, 120.0)


## A lived-in town: street trees, hedges, flower tubs, bins, crates and bikes. Only where the
## ground is free (village._free) so nothing lands in a house or on the road.
static func _town_life(pl: Places, o: Vector3) -> void:
	var k := pl.k
	var kd := pl.kd
	var v := pl.village
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var summer := GameMode.summer()
	# trees along both sides of the main street and the side street
	var spots: Array = []
	for x in range(-120, 121, 15):
		if absi(x) > 8:
			spots.append(Vector2(x, -9.2))
			spots.append(Vector2(x + 7, 9.2))
	for z in range(26, 120, 14):
		spots.append(Vector2(-8.6, z))
		spots.append(Vector2(8.6, z + 7))
	# a ring of trees round the square
	for q in 8:
		var a := q * TAU / 8.0 + 0.3
		spots.append(Vector2(cos(a) * 17.0, sin(a) * 17.0))
	# things already standing by the streets: poles, the bus shelter, hydrants, lights, cars
	var taken: Array[Vector2] = [Vector2(-22, 8), Vector2(-58, -6.2), Vector2(48, 6.2), Vector2(5.8, 60), Vector2(13, -9)]
	for i in 7:
		taken.append(Vector2(-112.0 + i * 37.0, 7.6))
	for x: float in [-100.0, -64.0, -30.0, 30.0, 64.0, 100.0]:
		taken.append(Vector2(x, -6.4))
	for z: float in [34.0, 70.0, 100.0]:
		taken.append(Vector2(6.4, z))
	for c in [[-44.0, 5.6], [22.0, -5.4], [78.0, 5.4], [-5.2, 52.0], [5.4, 84.0], [-88.0, -5.6]]:
		taken.append(Vector2(float(c[0]), float(c[1])))
	for b in [[-9.0, 9.0], [9.0, 9.0], [-9.5, -8.0], [-13.0, 6.0]]:
		taken.append(Vector2(float(b[0]), float(b[1])))
	var placed := 0
	for sp in spots:
		var wp: Vector2 = Vector2(TOWN.x, TOWN.y) + sp
		if not v._free(wp - Terrain.VILLAGE_POS, 2.2):
			continue
		var clash := false
		for tk in taken:
			if (sp as Vector2).distance_to(tk) < 3.2:
				clash = true
		if clash:
			continue
		var h := pl.terrain.height_at(wp.x, wp.y)
		pl.at(Vector3(wp.x, h, wp.y), rng.randf() * TAU)
		_street_tree(k, kd, rng, summer)
		placed += 1
	# flower tubs, hedges, bins, crates, bikes, mailboxes on the free ground near the square
	for i in 70:
		var wp := Vector2(TOWN.x + rng.randf_range(-115, 115), TOWN.y + rng.randf_range(-45, 110))
		if absf(wp.y - TOWN.y) < 6.8 or absf(wp.x - TOWN.x) < 6.8:
			continue      # the streets stay clear
		if not v._free(wp - Terrain.VILLAGE_POS, 3.5):
			continue      # well clear of every house, so no hedge stands in a doorway
		var near := false
		for tk in taken:
			if (wp - Vector2(TOWN.x, TOWN.y)).distance_to(tk) < 2.5:
				near = true
		if near:
			continue
		var h := pl.terrain.height_at(wp.x, wp.y)
		pl.at(Vector3(wp.x, h, wp.y), rng.randf() * TAU)
		match i % 7:
			0, 1:
				k.box(Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 0.6), "concrete")
				kd.ball(Vector3(0, 0.75, 0), Vector3(0.7, 0.3, 0.3), "green" if summer else "snow", 8, 4)
				if summer:
					for f in 6:
						kd.ball(Vector3(rng.randf_range(-0.55, 0.55), 0.95, rng.randf_range(-0.2, 0.2)), Vector3(0.07, 0.07, 0.07), ["red", "yellow", "white", "paint_blue"][f % 4], 5, 3)
			2:
				for hq in 4:
					k.ball(Vector3(hq * 0.9 - 1.35, 0.55, 0), Vector3(0.6, 0.6, 0.45), "pine" if summer else "snow", 7, 4)
			3:
				Props.litter_bin(k)
			4:
				Props.crate(k, rng.randf_range(0.5, 0.8))
				if rng.randf() < 0.5:
					Props.barrel(k)
			5:
				Props.mailboxes(k, 2 + rng.randi() % 3)
			6:
				_bike(kd)
	pl.at(o)
	print("Grauwasser: %d street trees" % placed)


static func _street_tree(k: MeshKit, kd: MeshKit, rng: RandomNumberGenerator, summer: bool) -> void:
	var h := rng.randf_range(3.6, 5.2)
	k.cyl(Vector3.ZERO, 0.14, h * 0.72, "bark", 7, 0.1)
	kd.tube(Vector3(0, h * 0.45, 0), Vector3(0.5, h * 0.7, 0.2), 0.06, "bark", 5)
	kd.tube(Vector3(0, h * 0.5, 0), Vector3(-0.4, h * 0.75, -0.3), 0.06, "bark", 5)
	if not summer:
		return     # bare in winter
	var leaf := "pine" if rng.randf() < 0.5 else "green"
	kd.ball(Vector3(0, h * 0.78, 0), Vector3(1.5, 1.2, 1.5), leaf, 9, 6)
	for q in 4:
		var a := q * TAU / 4.0 + rng.randf()
		kd.ball(Vector3(cos(a) * 0.8, h * 0.68 + rng.randf() * 0.5, sin(a) * 0.8), Vector3(0.9, 0.75, 0.9), leaf, 8, 5)
	# a ring of low iron round the bed
	kd.cyl(Vector3(0, 0.02, 0), 0.6, 0.04, "gravel", 10)


static func _bike(kd: MeshKit) -> void:
	for sx: float in [-0.52, 0.52]:
		kd.tube(Vector3(sx, 0.34, -0.02), Vector3(sx, 0.34, 0.02), 0.33, "black", 12)
	kd.tube(Vector3(-0.52, 0.34, 0), Vector3(0.05, 0.62, 0), 0.025, "paint_red", 5)
	kd.tube(Vector3(0.05, 0.62, 0), Vector3(0.52, 0.34, 0), 0.025, "paint_red", 5)
	kd.tube(Vector3(0.0, 0.34, 0), Vector3(0.05, 0.75, 0), 0.025, "paint_red", 5)
	kd.tube(Vector3(0.45, 0.6, 0), Vector3(0.45, 0.9, 0), 0.02, "steel", 5)
	kd.box(Vector3(0.05, 0.78, 0), Vector3(0.22, 0.05, 0.1), "black")


# ---------------------------------------------------------------- the sawmill

static func _mill(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("mill", MILL)
	pl.at(o)
	# the saw shed: two wide doorways for the logs, a small door, an office at the east end
	Struct.room(k, -14.0, -9.0, 8.0, 3.0, F, 5.0, "planks", "planks_in", "", {"w": [[-3.0, 4.4, 3.6]], "s": [[-8.0, 4.4, 3.6], [3.0, 1.1, 2.1]],
		"n": [[-9.0, 1.6, 3.4, 1.8], [-3.0, 1.6, 3.4, 1.8], [3.0, 1.6, 3.4, 1.8]]}, 0.3)
	pl.door(o + Vector3(2.45, F, 3.15), 0.0, 1.1, 2.08)
	for sx: float in [-1.0, 1.0]:      # a pitched roof with snow
		k.box(Vector3(-3.0, 6.6, -3.0 + sx * 3.4), Vector3(23.6, 0.2, 7.6), "tin", Basis(Vector3.RIGHT, sx * 0.42))
		k.box(Vector3(-3.0, 6.82, -3.0 + sx * 3.4), Vector3(23.2, 0.22, 7.2), "snow", Basis(Vector3.RIGHT, sx * 0.42))
	for x: float in [-14.15, 8.15]:
		for q in 6:
			var hw := 6.3 - q * 1.05
			k.box(Vector3(x, 5.4 + q * 0.5, -3.0), Vector3(0.3, 0.5, hw * 2.0), "planks")
	pl.roofed(-14.0, -9.0, 8.0, 3.0, 5.2)
	# saw bench with its blade, the log carriage on rails, sawdust, stacks of boards
	k.box(Vector3(-6.0, 0.55, -3.0), Vector3(9.0, 0.2, 1.4), "metal_in")
	for i in 5:
		k.box(Vector3(-10.0 + i * 2.0, 0.25, -3.0), Vector3(0.2, 0.5, 1.2), "metal_in")
	k.tube(Vector3(-6.0, 0.85, -3.78), Vector3(-6.0, 0.85, -3.72), 0.75, "steel_clean_in", 20)
	k.tube(Vector3(-9.6, 1.0, -3.0), Vector3(-3.0, 1.0, -3.0), 0.3, "wood_in", 9)
	Struct.rails(k, Vector3(-13.5, F, -1.2), Vector3(7.5, F, -1.2))
	for i in 4:
		k.box(Vector3(-11.0 + i * 3.4, 0.4 + (i % 2) * 0.15, -7.6), Vector3(2.8, 0.7 + (i % 2) * 0.3, 1.1), "planks_in")
	kd.ball(Vector3(-6.0, 0.08, -4.6), Vector3(2.6, 0.12, 1.2), "khaki_in", 9, 3)
	Interior.workbench(k, rng, Vector3(-1.0, F, 2.3), PI, 2.4)
	pl.lamp(o + Vector3(-6.0, 4.2, -3.0), Props.WARM, 2.0, 15.0, true, true)
	# office behind a partition
	Struct.wall(k, Vector3(3.8, F, -9.0), Vector3.BACK, 12.0, 3.0, "planks_in", [[5.4, 6.5, 0.0, 2.1]], 0.2)
	pl.door(o + Vector3(3.8, F, -3.6), -PI * 0.5, 1.1, 2.08)
	Interior.table(k, Vector3(6.4, F, -7.6), 0.0, 1.8, 0.9)
	Interior.chair(k, Vector3(6.4, F, -6.7), PI)
	Struct.shelf(k, rng, Vector3(7.6, F, -1.0), -PI * 0.5, 2.6)
	Struct.bunk(k, Vector3(4.6, F, 1.2), 0.0, "red_in")
	pl.note("n_mill_ledger", o + Vector3(6.6, F + 0.78, -7.6), 0.2, "book")
	pl.chest(o + Vector3(7.2, F, -8.3), 0.0, "mill_office", {"coin": 180, "medkit": 2, "painkillers": 3, "762_ap": 30, "scope": 1, "fuel_can": 2}, "Reiss's strongbox")
	pl.lamp(o + Vector3(6.0, 2.5, -4.0), Color(1.0, 0.75, 0.45), 1.3, 8.0, true)
	# the yard: log piles, a loader lorry, containers, a wooden tower, fire drums at the corners
	_log_pile(k, Vector3(-24.0, 0, -4.0), 0.1, 5, 6.0)
	_log_pile(k, Vector3(-24.0, 0, 8.0), -0.1, 4, 6.0)
	_log_pile(k, Vector3(16.0, 0, 12.0), PI * 0.5, 5, 5.0)
	_log_pile(k, Vector3(-6.0, 0, 16.0), PI * 0.5 + 0.1, 3, 7.0)
	Struct.truck(k, Vector3(-16.0, 0, 14.0), 1.2, false, 0.1)
	Struct.container(k, Vector3(22.0, 0, -12.0), 0.0, "paint_red", true)
	pl.cargo_doors(o + Vector3(22.0, 0, -12.0), 0.0, "paint_red")
	pl.chest(o + Vector3(22.0, 0.07, -14.4), 0.0, "mill_box", {"12g": 20, "12g_slug": 8, "axe": 1, "scrap": 6, "rope": 1, "bounty_tag": 2}, "Loot crate")
	Struct.tower(k, Vector3(26.0, 0, 10.0), -PI * 0.5, 6.0, true)
	Struct.sandbags(k, Vector3(-30.0, 0, 2.0), PI * 0.5, 6)
	Struct.sandbags(k, Vector3(2.0, 0, 22.0), 0.0, 6)
	for d: Vector2 in [Vector2(-17.5, -12.5), Vector2(11.5, -12.5), Vector2(11.5, 6.5), Vector2(-17.5, 6.5)]:
		k.xf = Transform3D(Basis.IDENTITY, o + Vector3(d.x, 0, d.y))
		Props.barrel(k)
		fire_drums.append(o + Vector3(d.x, 0.0, d.y))
	pl.at(o)
	var fl := Struct.floodlight(k, Vector3(-10.0, 0, 9.0), 2.6, true, 6.0)
	pl.lamp(k.xf * fl, Color(1.0, 0.8, 0.6), 2.4, 24.0, true, true)
	# red rags on poles: you know whose yard this is
	for i in 4:
		var fp := Vector3(-34.0 + i * 22.0, 0, 26.0)
		k.cyl(fp - Vector3(0, 0.3, 0), 0.04, 4.6, "wood_dark", 5)
		kd.box(fp + Vector3(0.5, 3.8, 0), Vector3(1.0, 0.6, 0.02), "red", Basis(Vector3(0, 0, 1), -0.12))
	var crew := [["mill_0", "assault_rifle", Vector3(-22.0, 0.3, 14.0)], ["mill_1", "shotgun", Vector3(-8.0, 0.3, 8.0)], ["mill_2", "smg", Vector3(12.0, 0.3, 16.0)],
		["mill_3", "sniper_rifle", Vector3(24.0, 0.3, 4.0)], ["mill_4", "axe", Vector3(-12.0, 0.3, -1.0)], ["mill_5", "marksman_rifle", Vector3(-30.0, 0.3, -8.0)]]
	for c: Array in crew:
		pl.crews.append([c[0], c[1], o + (c[2] as Vector3), "raiders"])
	Places.D["reiss"] = o + Vector3(2.0, 0.4, 10.0)
	Places.D["reiss_cover"] = [o + Vector3(-24.0, 0.1, -8.0), o + Vector3(-24.0, 0.1, 12.0), o + Vector3(16.0, 0.1, 15.5), o + Vector3(-6.0, 0.1, 19.0),
		o + Vector3(-16.0, 0.1, 17.5), o + Vector3(22.0, 0.1, -8.0), o + Vector3(-30.0, 0.1, 5.0), o + Vector3(2.0, 0.1, 23.5), o + Vector3(9.5, 0.1, 5.0)]
	Places.D["reiss_rally"] = [o + Vector3(-36.0, 0.4, -18.0), o + Vector3(34.0, 0.4, -16.0), o + Vector3(34.0, 0.4, 24.0), o + Vector3(-36.0, 0.4, 26.0)]
	pl.spot("mill", "Sägewerk Grauwasser", o, 44.0)


# ---------------------------------------------------------------- the field hospital

static func _camp(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("camp", CAMP)
	pl.at(o)
	for i in 6:
		_tent(k, Vector3(-22.0 + (i % 3) * 8.0, 0, -12.0 + (i / 3) * 12.0), (i % 2) * 0.12 - 0.06, "olive" if i != 4 else "white")
	# the surgery: a prefab ward with beds, a bench, the surgeon's case
	_hut(pl, o, 6.0, -12.0, 20.0, -4.0, 2.7, "panel", "white_in", 13.0, false, [9.0, 17.0])
	for i in 4:
		Struct.bunk(k, Vector3(7.0 + i * 1.7, F, -10.8), 0.0, "white_in")
	Struct.lab_bench(k, rng, Vector3(17.0, F, -5.0), PI, 4.0)
	Interior.table(k, Vector3(8.0, F, -5.2), 0.0, 1.6, 0.8)
	pl.note("n_camp_triage", o + Vector3(8.2, F + 0.78, -5.2), 0.4, "book")
	pl.chest(o + Vector3(19.2, F, -10.8), -PI * 0.5, "camp_case", {"relay_fuse": 1, "medkit": 3, "painkillers": 4, "bandage": 6, "splint": 2}, "Surgeon's case")
	pl.lamp(o + Vector3(13.0, 2.3, -8.0), Color(0.85, 0.95, 1.0), 1.4, 10.0, true, true)
	kd.box(Vector3(13.0, 2.4, -3.52), Vector3(2.4, 0.6, 0.03), "white")
	kd.box(Vector3(13.0, 2.4, -3.5), Vector3(0.5, 0.16, 0.02), "paint_red")
	kd.box(Vector3(13.0, 2.4, -3.5), Vector3(0.16, 0.5, 0.02), "paint_red")
	# the helicopter that never flew the wounded out, crates, a generator, stretchers in the snow
	Struct.heli(k, Vector3(-4.0, 0, 16.0), 0.7)
	kd.ball(Vector3(-4.0, 0.2, 18.0), Vector3(3.4, 0.5, 4.6), "snow", 9, 4)
	Struct.generator(k, Vector3(22.0, 0, 2.0), 0.3)
	for i in 6:
		k.xf = Transform3D(Basis(Vector3.UP, i * 0.7), o + Vector3(2.0 + (i % 3) * 1.1, 0, 2.0 + (i / 3) * 1.1))
		Props.crate(k, 0.7)
	pl.at(o)
	for i in 4:
		kd.box(Vector3(-12.0 + i * 3.2, 0.12, 4.0 + (i % 2) * 1.4), Vector3(0.6, 0.05, 2.0), "olive_in", Basis(Vector3.UP, i * 0.4))
		kd.ball(Vector3(-12.0 + i * 3.2, 0.2, 4.0 + (i % 2) * 1.4), Vector3(0.3, 0.12, 0.85), "snow", 7, 3, Basis(Vector3.UP, i * 0.4))
	Struct.floodlight(k, Vector3(0.0, 0, -18.0), 0.0, false, 6.0)
	pl.chest(o + Vector3(-22.0, 0.1, 6.0), 0.4, "camp_tent", {"canned_food": 4, "hot_tea": 2, "hand_warmer": 4, "cloth": 4, "batteries": 2}, "Ration box")
	pl.spot("camp", "Feldlazarett 3 (field hospital)", o, 40.0)


# ---------------------------------------------------------------- Hochfunk

static func _mast(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("mast", MAST)
	pl.at(o)
	var top := Struct.mast(k, Vector3(-8.0, 0, -6.0), 38.0)
	pl.lamp(k.xf * top, Color(1.0, 0.1, 0.05), 2.4, 30.0)
	for q in 3:
		var a := q * TAU / 3.0 + 1.0
		k.tube(Vector3(-8.0, 26.0, -6.0), Vector3(-8.0 + cos(a) * 15.0, 0.0, -6.0 + sin(a) * 15.0), 0.03, "steel", 4)
		k.box(Vector3(-8.0 + cos(a) * 15.0, 0.2, -6.0 + sin(a) * 15.0), Vector3(0.9, 0.5, 0.9), "concrete")
	_hut(pl, o, 2.0, -6.0, 10.0, 0.0, 2.6, "panel", "planks_in", 6.0, true, [4.0, 8.0])
	Interior.console(k, Vector3(4.0, F, -5.2), 0.0)
	Struct.rack(k, rng, Vector3(9.4, F, -3.0), -PI * 0.5, false)
	Struct.rack(k, rng, Vector3(9.4, F, -4.0), -PI * 0.5, false)
	Struct.bunk(k, Vector3(2.9, F, -1.4), 0.0, "navy_in")
	Interior.chair(k, Vector3(4.0, F, -4.2), PI)
	pl.note("n_mast_log", o + Vector3(5.2, F + 0.92, -5.2), -0.3, "paper")
	radio_pos = o + Vector3(4.0, F + 1.0, -5.0)
	Places.D["lars"] = o + Vector3(6.4, F + 0.02, -2.6)
	pl.chest(o + Vector3(9.2, F, -0.8), -PI * 0.5, "mast_hut", {"batteries": 6, "hot_tea": 2, "flare": 4, "338": 10, "red_dot": 1}, "Kit box")
	pl.lamp(o + Vector3(6.0, 2.2, -3.0), Color(0.7, 1.0, 0.85), 1.4, 9.0, true, true)
	Struct.dish(k, Vector3(6.0, 3.4, -3.0), 0.6, 1.3)
	Struct.generator(k, Vector3(13.0, 0, -3.0), 0.0)
	for i in 4:
		Struct.fence(k, Vector3(-18.0 + i * 9.0, 0, -16.0), Vector3(-9.0 + i * 9.0, 0, -16.0))
	pl.label("HOCHFUNK", o + Vector3(6.0, 2.35, 0.34), 0.0, 0.006, Color(0.97, 0.95, 0.9))
	pl.spot("mast", "Hochfunk radio mast", o, 30.0, "view")


# ---------------------------------------------------------------- the airstrip

static func _strip(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("strip", STRIP)
	pl.at(o)
	# runway markings and edge lights
	for i in 12:
		kd.box(Vector3(-110.0 + i * 20.0, 0.03, 0.0), Vector3(8.0, 0.02, 0.5), "paint_white_in")
	for i in 9:
		for sz: float in [-1.0, 1.0]:
			k.cyl(Vector3(-120.0 + i * 30.0, -0.1, sz * 10.4), 0.07, 0.45, "steel", 6)
			kd.sphere(Vector3(-120.0 + i * 30.0, 0.4, sz * 10.4), 0.09, "led_red" if i == 0 or i == 8 else "candle", 6, 4)
	# the hangar: its whole south front stands open, a side door in the same wall
	Struct.room(k, -16.0, -24.0, 6.0, -12.0, F, 6.2, "tin", CON, "", {"s": [[-7.0, 13.0, 5.2], [3.6, 1.1, 2.1]]}, 0.3)
	pl.door(o + Vector3(3.05, F, -11.85), 0.0, 1.1, 2.08, true)
	for i in 8:          # an arched roof
		var a0 := PI * i / 8.0
		var a1 := PI * (i + 1) / 8.0
		var p0 := Vector3(0, 6.3 + sin(a0) * 2.4, -18.0 - cos(a0) * 6.3)
		var p1 := Vector3(0, 6.3 + sin(a1) * 2.4, -18.0 - cos(a1) * 6.3)
		var mid := (p0 + p1) * 0.5 + Vector3(-5.0, 0, 0)
		var tilt := atan2(p1.y - p0.y, p1.z - p0.z)
		k.box(mid, Vector3(22.6, 0.14, p0.distance_to(p1) + 0.06), "tin", Basis(Vector3.RIGHT, -tilt))
		if i > 1 and i < 6:
			k.box(mid + Vector3(0, 0.16, 0), Vector3(22.2, 0.18, p0.distance_to(p1)), "snow", Basis(Vector3.RIGHT, -tilt))
	for x: float in [-16.15, 6.15]:
		for q in 5:
			var hw := sqrt(maxf(1.0 - pow((q + 0.5) / 5.0, 2.0), 0.0)) * 6.3
			k.box(Vector3(x, 6.5 + q * 0.48, -18.0), Vector3(0.3, 0.5, hw * 2.0), "tin")
	pl.roofed(-16.0, -24.0, 6.0, -12.0, 6.4)
	# 'Grete' on her skids with the rotor head stripped, a tool bench, drums, the chalk board
	var hk := MeshKit.new()
	Struct.heli(hk, Vector3.ZERO, 0.0)
	var heli := hk.node(true)
	heli.transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3(0, 0, 1), -0.22), o + Vector3(-8.0, 0.25, -18.0))
	pl.add_child(heli)
	Interior.workbench(k, rng, Vector3(2.0, F, -23.2), 0.0, 3.0)
	Struct.shelf(k, rng, Vector3(5.4, F, -19.0), -PI * 0.5, 3.0)
	for i in 4:
		k.xf = Transform3D(Basis.IDENTITY, o + Vector3(-15.0 + (i % 2) * 0.8, F, -23.0 + (i / 2) * 0.8))
		Props.barrel(k)
	pl.at(o)
	kd.box(Vector3(5.82, 1.6, -15.0), Vector3(0.03, 1.2, 2.2), "black_in")
	pl.note("n_strip_manifest", o + Vector3(5.7, 1.3, -15.0), -PI * 0.5)
	pl.chest(o + Vector3(4.8, F, -22.6), -PI * 0.5, "strip_hangar", {"fuel_can": 1, "scrap": 6, "flare": 6, "ext_mag": 1, "556_ap": 30}, "Flight locker")
	pl.lamp(o + Vector3(-6.0, 5.4, -18.0), Color(0.9, 0.95, 1.0), 2.2, 18.0, true, true)
	Places.D["brandt"] = o + Vector3(0.6, F + 0.02, -21.6)
	# the control hut on stilts, a wind sock, fuel tanks
	_hut(pl, o, 16.0, -20.0, 22.0, -14.0, 2.5, "paint_white", "planks_in", 19.0, false, [17.6, 20.4])
	Interior.console(k, Vector3(17.6, F, -19.2), 0.0)
	pl.chest(o + Vector3(21.2, F, -15.0), -PI * 0.5, "strip_tower", {"batteries": 3, "hot_tea": 2, "9mm_ap": 30}, "Locker")
	k.cyl(Vector3(30.0, -0.3, -10.0), 0.05, 6.4, "steel", 6)
	k.tube(Vector3(30.0, 5.9, -10.0), Vector3(31.8, 5.6, -10.4), 0.22, "orange", 8, 0.1)
	Struct.tank(k, Vector3(-28.0, 0, -18.0), 0.0, 5.0, 1.1)
	Struct.tank(k, Vector3(-31.4, 0, -18.0), 0.0, 5.0, 1.1)
	pl.label("FLUGFELD GRAUWASSER", o + Vector3(-5.0, 5.7, -11.66), 0.0, 0.012, Color(0.97, 0.95, 0.9))
	pl.spot("strip", "Flugfeld Grauwasser (airstrip)", o, 60.0)


# ---------------------------------------------------------------- the quarry

static func _quarry(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("quarry", QUARRY)
	pl.at(o)
	# cut blocks, a derrick, the sled that went over the lip
	for i in 9:
		var p := Vector3(-22.0 + (i % 5) * 9.0, 0.6, -14.0 + (i / 5) * 22.0 + (i % 2) * 3.0)
		k.box(p, Vector3(2.4 + (i % 3) * 0.6, 1.2 + (i % 2) * 0.5, 1.8), "rock", Basis(Vector3.UP, i * 0.6))
		k.ball(p + Vector3(0, 0.75 + (i % 2) * 0.25, 0), Vector3(1.3, 0.14, 1.0), "snow", 8, 3)
	k.tube(Vector3(-6.0, -0.3, -18.0), Vector3(-1.0, 11.0, -12.0), 0.16, "rust", 6)
	k.tube(Vector3(4.0, -0.3, -18.0), Vector3(-1.0, 11.0, -12.0), 0.16, "rust", 6)
	k.tube(Vector3(-1.0, 11.0, -12.0), Vector3(-1.0, 4.0, -12.0), 0.03, "steel", 4)
	k.box(Vector3(-1.0, 3.6, -12.0), Vector3(1.6, 0.9, 1.2), "rock")
	Struct.rubble(k, rng, Vector3(14.0, 0, 10.0), 7.0, 22, "rock", 1.8)
	Struct.rubble(k, rng, Vector3(-18.0, 0, 12.0), 5.0, 14, "rock", 1.4)
	# the den: bones, and ice that grew where the Grey Mother sleeps
	for i in 14:
		var a := i * 0.83
		kd.cyl(Vector3(18.0 + cos(a) * (1.0 + i * 0.3), 0.0, -8.0 + sin(a) * (0.8 + i * 0.26)), 0.14 + (i % 3) * 0.06, 0.5 + (i % 4) * 0.4, "ice", 5, 0.0)
	for i in 8:
		kd.tube(Vector3(12.0 + i * 0.9, 0.08, -3.0 + sin(i * 2.0)), Vector3(12.6 + i * 0.9, 0.12, -2.6 + sin(i * 2.0)), 0.035, "bone", 5)
	kd.ball(Vector3(15.0, 0.16, -4.6), Vector3(0.16, 0.13, 0.2), "bone", 8, 5)
	pl.lamp(o + Vector3(18.0, 1.2, -8.0), Color(0.3, 0.8, 1.0), 1.4, 10.0)
	pl.at(o + Vector3(6.0, 0.1, 14.0), 0.9)
	k.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.14, 3.6), "planks", Basis(Vector3(0, 0, 1), 0.5))
	for sx: float in [-1.0, 1.0]:
		k.tube(Vector3(sx * 0.7, 0.05, -2.0), Vector3(sx * 0.7, 0.05, 2.0), 0.04, "steel", 5)
	pl.at(o)
	pl.note("n_quarry_den", o + Vector3(7.2, 0.08, 12.4), 0.5)
	pl.chest(o + Vector3(8.4, 0.05, 15.0), 0.9, "quarry_sled", {"556": 60, "762": 40, "medkit": 1, "canned_food": 4, "fuel_can": 1}, "Supply crate")
	Places.D["mother"] = o + Vector3(17.0, 0.5, -6.0)
	pl.spot("quarry", "Steinbruch (quarry)", o, 40.0)


# ---------------------------------------------------------------- Hof Lindgren

static func _farm(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var o := _o("farm", FARM)
	var house := pl.village.house_world("house", FARM + Vector2(-10, -6), Vector2(1, 0), true)
	Places.D["farm_house"] = house
	pl.at(o)
	# the barn: a big door for the tractor that is gone, a small one beside it, a hayloft
	Struct.room(k, 4.0, -12.0, 18.0, -2.0, F, 4.2, "paint_red", "planks_in", "", {"s": [[9.0, 3.6, 3.2], [15.6, 1.1, 2.1]]}, 0.3)
	pl.door(o + Vector3(15.05, F, -1.85), 0.0, 1.1, 2.08)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(11.0, 5.6, -7.0 + sx * 2.9), Vector3(15.4, 0.2, 6.6), "planks", Basis(Vector3.RIGHT, sx * 0.5))
		k.box(Vector3(11.0, 5.82, -7.0 + sx * 2.9), Vector3(15.0, 0.22, 6.2), "snow", Basis(Vector3.RIGHT, sx * 0.5))
	for x: float in [3.85, 18.15]:
		for q in 6:
			k.box(Vector3(x, 4.5 + q * 0.5, -7.0), Vector3(0.3, 0.5, (5.3 - q * 0.9) * 2.0), "paint_red")
	pl.roofed(4.0, -12.0, 18.0, -2.0, 4.4)
	k.box(Vector3(14.0, 2.6, -9.5), Vector3(7.6, 0.14, 4.6), "planks_in")
	for i in 6:
		k.bbox(Vector3(11.0 + (i % 3) * 1.5, 0.45 + (i / 3) * 0.8, -10.6), Vector3(1.3, 0.75, 0.9), 0.06, "khaki_in")
		k.bbox(Vector3(11.6 + (i % 3) * 1.5, 3.05, -10.4 + (i / 3) * 1.0), Vector3(1.3, 0.75, 0.9), 0.06, "khaki_in")
	Interior.workbench(k, rng, Vector3(6.0, F, -11.3), 0.0, 2.2)
	pl.chest(o + Vector3(17.2, F, -10.8), -PI * 0.5, "farm_barn", {"marksman_rifle": 1, "762": 40, "rope": 1, "fuel_can": 1, "firewood": 4, "canned_food": 3}, "Grandfather's trunk")
	pl.lamp(o + Vector3(11.0, 3.6, -6.0), Props.WARM, 1.4, 11.0, true, true)
	pl.note("n_farm_letter", o + Vector3(13.0, 0.12, 2.0), 0.6)
	# fence posts, a trough, a sledge, firewood
	for i in 10:
		var fx := -26.0 + i * 5.6
		k.cyl(Vector3(fx, -0.2, 16.0), 0.07, 1.4, "wood_dark", 5)
		if i < 9:
			kd.box(Vector3(fx + 2.8, 0.8, 16.0), Vector3(5.6, 0.1, 0.05), "wood")
			kd.box(Vector3(fx + 2.8, 0.4, 16.0), Vector3(5.6, 0.1, 0.05), "wood")
	k.box(Vector3(0.0, 0.3, 8.0), Vector3(2.4, 0.5, 0.7), "wood_dark")
	_log_pile(k, Vector3(22.0, 0, 4.0), 0.0, 4, 2.4)
	Places.D["oda"] = o + Vector3(8.0, 0.3, 4.0)
	pl.spot("farm", "Hof Lindgren (farm)", o, 34.0)


# ---------------------------------------------------------------- raider camps

static func _raid_camps(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	for ci in RAID_CAMPS.size():
		var c := RAID_CAMPS[ci]
		var o := pl.gy(c)
		pl.at(o)
		for i in 3:
			var a := i * TAU / 3.0 + ci
			_tent(k, Vector3(cos(a) * 5.4, 0, sin(a) * 5.4), a + PI * 0.5, "red" if i == 0 else "fur_dark")
		k.cyl(Vector3(0, -0.1, 0), 0.4, 0.8, "rust", 9)
		kd.ball(Vector3(0, 0.75, 0), Vector3(0.3, 0.2, 0.3), "candle", 7, 4)
		pl.lamp(o + Vector3(0, 1.3, 0), Color(1.0, 0.5, 0.2), 2.0, 13.0, true, true)
		k.cyl(Vector3(3.0, -0.3, -2.0), 0.04, 4.4, "wood_dark", 5)
		kd.box(Vector3(3.5, 3.6, -2.0), Vector3(1.0, 0.6, 0.02), "red", Basis(Vector3(0, 0, 1), -0.1))
		Struct.sandbags(k, Vector3(-3.0, 0, 7.5), 0.3, 5)
		pl.chest(o + Vector3(-2.0, 0.05, -2.6), 0.5, "raidcamp_%d" % ci, {"coin": 60, "9mm": 40, "556": 30, "canned_food": 3, "bounty_tag": 2, "bandage": 2}, "Loot crate")
		var kit: Array = [["pistol", "shotgun", "smg", "axe"], ["assault_rifle", "marksman_rifle", "smg", "sword", "shotgun"]][ci]
		for j in kit.size():
			var a: float = j * TAU / kit.size() + 0.5
			pl.crews.append(["southcamp_%d_%d" % [ci, j], kit[j], o + Vector3(cos(a) * 3.2, 0.3, sin(a) * 3.2), "raiders"])
		pl.spot("southcamp_%d" % ci, "Red Flag camp", o, 22.0)
