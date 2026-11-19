class_name Village
extends Node3D
## The abandoned Christmas mountain village: square with the big tree and
## market, hotel, toy shop, inn, chapel, streets of chalets, cable car,
## fairy lights, old machines that still move, and loudspeakers that still play.

var terrain: Terrain
var forest: Forest
var rng := RandomNumberGenerator.new()
var k: MeshKit       # solid props
var soft: MeshKit    # things you can walk through (snow drifts, small stuff)
var _blocked: Array = []   # [Vector2 centre, radius] of buildings
var houses: Array[Node3D] = []


func build(t: Terrain, f: Forest) -> void:
	terrain = t
	forest = f
	rng.seed = 1224
	k = MeshKit.new()
	soft = MeshKit.new()
	Props.bulbs.clear()
	Props.lights.clear()
	_buildings()
	_plaza()
	_streets()
	_cable_car()
	_scatter()
	k.xf = Transform3D.IDENTITY
	add_child(k.node(true))
	add_child(soft.node(false))
	_make_bulbs()
	_make_lights()
	_speakers()
	print("Village: %d bulbs, %d lamps" % [Props.bulbs.size(), Props.lights.size()])


## Streets, the square and the trodden paths to every door, drawn into the ground before it is meshed.
static func plan(t: Terrain) -> void:
	var o := Terrain.VILLAGE_POS
	var streets := [
		[[Vector2(0, 134), Vector2(0, 24)], 4.0],
		[[Vector2(-114, 0), Vector2(-24, 0)], 3.8],
		[[Vector2(24, 0), Vector2(114, 0)], 3.8],
		[[Vector2(0, -24), Vector2(0, -42)], 4.0],
		[[Vector2(20, -18), Vector2(44, -52), Vector2(62, -86), Vector2(75, -93)], 3.0],
		[[Vector2(-21, -19), Vector2(-28, -25)], 1.6],
		[[Vector2(21, -19), Vector2(31, -24)], 1.6],
		[[Vector2(-27, 18), Vector2(-36, 23)], 1.6],
	]
	for i in 4:
		var z := 44.0 + i * 21.0
		streets.append([[Vector2(-11.5, z), Vector2(-3, z)], 0.9])
		streets.append([[Vector2(11.5, z), Vector2(3, z)], 0.9])
		# a parking bay beside each path
		streets.append([[Vector2(-9.5, z + 4.6), Vector2(-3, z + 4.6)], 1.3])
		streets.append([[Vector2(9.5, z - 4.6), Vector2(3, z - 4.6)], 1.3])
	for i in 3:
		var x := 60.0 + i * 22.0
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				streets.append([[Vector2(sx * x, sz * 13.5), Vector2(sx * x, sz * 3.0)], 0.9])
				streets.append([[Vector2(sx * x + 4.6, sz * 9.5), Vector2(sx * x + 4.6, sz * 3.0)], 1.3])
	for s in streets:
		var pts := PackedVector2Array()
		for p: Vector2 in s[0]:
			pts.append(o + p)
		t.road(pts, float(s[1]), 2.5)
	t.pave(o, 26.0)
	t.pave(o + Vector2(0, -42), 9.0)
	t.pave(o + Vector2(76, -92), 8.0)


## Village-local map position (x east, y south) to world space on the ground.
func _w(p: Vector2, lift := 0.0) -> Vector3:
	var x := Terrain.VILLAGE_POS.x + p.x
	var z := Terrain.VILLAGE_POS.y + p.y
	return Vector3(x, terrain.height_at(x, z) + lift, z)


func _at(kit: MeshKit, p: Vector2, yaw := 0.0, lift := 0.0) -> void:
	kit.xf = Transform3D(Basis(Vector3.UP, yaw), _w(p, lift))


func _free(p: Vector2, margin := 1.0) -> bool:
	for b in _blocked:
		var c: Vector2 = b[0]
		var r: float = b[1]
		if p.distance_to(c) < r + margin:
			return false
	return true


func _house(kind: String, p: Vector2, face: Vector2, lit: bool) -> Node3D:
	var n := Chalet.build(kind, rng, lit)
	n.position = _w(p)
	n.rotation.y = atan2(face.x, face.y)
	add_child(n)
	var size: Vector2 = n.get_meta("size")
	_blocked.append([p, size.length() * 0.5 + 1.2])
	n.set_meta("lit", lit)
	# a chest in the front left corner
	var chest := LootBox.new()
	chest.setup()
	chest.id = "village_%d" % houses.size()
	chest.items = Items.roll(kind, rng)
	chest.position = Vector3(-size.x * 0.5 + 1.0, Chalet.Y0, size.y * 0.5 - 0.95)
	chest.rotation.y = PI * 0.5
	n.add_child(chest)
	match houses.size():
		0:
			chest.items["medkit"] = 1
			chest.items["large_pack"] = 1
		3:
			chest.items["kevlar_vest"] = 1
		4:
			chest.items["parka"] = 1
			chest.items["wool_hat"] = 1
			chest.items["pistol"] = 1
			chest.items["9mm"] = 45
	match kind:
		"hotel":
			chest.items["revolver"] = 1
			chest.items["357"] = 18
			chest.items["sword"] = 1
		"station":
			chest.items["assault_rifle"] = 1
			chest.items["556"] = 60
			chest.items["red_dot"] = 1
			chest.items["grip"] = 1
			chest.items["snow_chains"] = 1
			chest.items["fuel_can"] = 2
			chest.items["scrap"] = 4
		"restaurant":
			chest.items["shotgun"] = 1
			chest.items["12g"] = 14
			chest.items["12g_slug"] = 6
			chest.items["axe"] = 1
			chest.items["fuel_can"] = 1
		"toyshop":
			chest.items["flare_gun"] = 1
			chest.items["flare"] = 4
			chest.items["ice_pick"] = 1
	houses.append(n)
	return n


## A house anywhere in the world (the Vorland's town and farm), given by its world position.
func house_world(kind: String, wp: Vector2, face: Vector2, lit: bool) -> Node3D:
	return _house(kind, wp - Terrain.VILLAGE_POS, face, lit)


## 0 = outside, 1 = inside a cold building, 2 = inside a heated one.
func shelter_at(pos: Vector3) -> int:
	for h in houses:
		var l := h.to_local(pos)
		var s: Vector2 = h.get_meta("size")
		if absf(l.x) < s.x * 0.5 and absf(l.z) < s.y * 0.5 and l.y > -0.5 and l.y < 9.0:
			return 2 if h.get_meta("lit") else 1
	return Places.shelter_at(pos)


func _buildings() -> void:
	_house("hotel", Vector2(0, -50), Vector2(0, 1), true)
	_house("toyshop", Vector2(-33, -30), Vector2(1, 1).normalized(), true)
	_house("restaurant", Vector2(36, -29), Vector2(-1, 1).normalized(), true)
	_house("station", Vector2(80, -100), Vector2(-0.6, 0.8), false)
	for i in 4:
		var z := 44.0 + i * 21.0
		_house("house", Vector2(-15, z), Vector2(1, 0), rng.randf() < 0.35)
		_house("house", Vector2(15, z), Vector2(-1, 0), rng.randf() < 0.35)
	for i in 3:
		var x := 60.0 + i * 22.0
		_house("house", Vector2(x, -17), Vector2(0, 1), rng.randf() < 0.3)
		_house("house", Vector2(x, 17), Vector2(0, -1), rng.randf() < 0.3)
		_house("house", Vector2(-x, -17), Vector2(0, 1), rng.randf() < 0.3)
		_house("house", Vector2(-x, 17), Vector2(0, -1), rng.randf() < 0.3)
	_at(k, Vector2(62, -66), atan2(-1.0, 1.0))
	Props.chapel(k, rng)
	_blocked.append([Vector2(62, -66), 8.0])
	Props.lights.append([_w(Vector2(62, -66), 3.0) + Vector3(-3.5, 0, 3.5), Props.WARM, 1.2, 9.0, true])


func _plaza() -> void:
	# the big tree
	var tree := MeshInstance3D.new()
	tree.mesh = forest.tree_mesh(2)
	var scale := 1.3
	tree.scale = Vector3.ONE * scale
	tree.position = _w(Vector2.ZERO, -0.3)
	add_child(tree)
	var base := tree.position
	var h := 15.0 * scale
	k.xf = Transform3D(Basis.IDENTITY, base)
	k.cyl(Vector3.ZERO, 0.45, 3.0, "wood_dark", 8)
	k.xf = Transform3D.IDENTITY
	for i in 280:
		var f := i / 280.0
		var r := lerpf(h * 0.25, 0.25, pow(f, 0.85))
		var y := lerpf(h * 0.13, h * 0.95, f) - r * 0.32
		var a := i * 0.61
		var col := Props.BULB_COLS[i % 5]
		if rng.randf() < 0.12:
			col = Props.DEAD
		Props.bulbs.append([base + Vector3(cos(a) * r, y, sin(a) * r), col])
	# star
	var top := base + Vector3(0, h + 0.3, 0)
	k.sphere(top, 0.28, "gold", 8, 5)
	for i in 6:
		k.box(top, Vector3(0.1, 1.5, 0.1), "gold", Basis(Vector3(0, 0, 1), PI * i / 6.0))
	Props.lights.append([base + Vector3(0, 9.0, 0), Color(1.0, 0.78, 0.5), 2.6, 34.0, false])
	Props.lights.append([top, Color(1.0, 0.8, 0.35), 3.0, 12.0, false])
	_blocked.append([Vector2.ZERO, 5.0])
	# presents under it
	for i in 14:
		var a := rng.randf() * TAU
		_at(soft, Vector2(cos(a), sin(a)) * rng.randf_range(3.2, 5.5), rng.randf() * TAU)
		Props.gift(soft, rng)

	# toy train round the tree
	_at(k, Vector2.ZERO)
	Props.train_track(k, 7.5)
	var train := Spinner.new()
	train.mode = "stutter"
	train.speed = -0.3
	train.position = _w(Vector2.ZERO)
	train.add_child(Props.train(7.5).node(false))
	add_child(train)

	# market stalls in a ring, light strings from the tree out to lamps
	for i in 8:
		var a := deg_to_rad(22.5 + 45.0 * i)
		var dir := Vector2(cos(a), sin(a))
		var p := dir * 18.5
		var yaw := atan2(-dir.x, -dir.y)
		if i == 5:
			# this one has been knocked over
			k.xf = Transform3D(Basis(Vector3.UP, yaw + 0.5) * Basis(Vector3.RIGHT, -1.35), _w(p, 1.0))
			Props.stall(k, rng, false)
		else:
			_at(k, p, yaw)
			Props.stall(k, rng, i % 3 != 1)
		_blocked.append([p, 2.4])
	for i in 8:
		var a0 := deg_to_rad(22.5 + 45.0 * i)
		var a1 := deg_to_rad(22.5 + 45.0 * (i + 1))
		if i == 5 or i == 4:
			continue
		var p0 := _w(Vector2(cos(a0), sin(a0)) * 17.0, 2.75)
		var p1 := _w(Vector2(cos(a1), sin(a1)) * 17.0, 2.75)
		Props.chain(k, rng, p0, p1, 0.9 if i % 2 == 1 else 0.4, 1 if i == 2 else 0, true)
	for i in 8:
		var a := deg_to_rad(45.0 * i + (12.0 if i % 2 == 0 else -12.0))
		var p := Vector2(cos(a), sin(a)) * 24.0
		var lit := i != 3 and i != 6
		_at(k, p)
		Props.lamp(k, lit, i == 1)
		var state := 0
		if i == 3:
			state = 2
		elif i == 6 or i == 1:
			state = 1
		Props.chain(k, rng, base + Vector3(cos(a) * 1.6, h * 0.6, sin(a) * 1.6), _w(p, 4.35), 2.4, state)

	# machines that still run
	_at(k, Vector2(10.5, -9.5))
	Props.pyramid(k)
	_spinner(Props.pyramid_rotor(), Vector2(10.5, -9.5), "stutter", 0.7)
	_blocked.append([Vector2(10.5, -9.5), 2.8])
	_at(k, Vector2(-39, 26))
	Props.carousel(k)
	_spinner(Props.carousel_rotor(rng), Vector2(-39, 26), "stutter", 0.28)
	_blocked.append([Vector2(-39, 26), 5.0])
	Props.lights.append([_w(Vector2(-39, 26), 3.4) + Vector3(2.5, 0, 0), Props.WARM, 1.6, 9.0, true])
	for sx in [-1.0, 1.0]:
		var sg: float = sx
		_at(k, Vector2(sg * 5.0, 27.0))
		Props.nutcracker(k)
		_blocked.append([Vector2(sg * 5.0, 27.0), 1.0])

	# hotel front: light string along the balcony
	var hp := _w(Vector2(0, -50))
	Props.chain(k, rng, hp + Vector3(-8.6, 4.1, 7.3), hp + Vector3(8.6, 4.1, 7.3), 0.35, 0, true)
	Props.chain(k, rng, hp + Vector3(-8.6, 7.0, 7.3), hp + Vector3(8.6, 7.0, 7.3), 0.35, 1, true)


func _spinner(rotor: MeshKit, p: Vector2, mode: String, speed: float) -> Spinner:
	var s := Spinner.new()
	s.mode = mode
	s.speed = speed
	s.position = _w(p)
	s.add_child(rotor.node(false))
	add_child(s)
	return s


func _streets() -> void:
	var sr := RandomNumberGenerator.new()
	sr.seed = 90210
	# --- main street, running south from the square
	for i in 5:
		var z := 33.0 + i * 21.0
		var sx := -1.0 if i % 2 == 0 else 1.0
		_at(k, Vector2(sx * 5.4, z), PI * 0.5 * sx)
		Props.street_light(k, i != 2, i == 3)
		var zz := 40.0 + i * 16.0
		Props.chain(k, rng, _w(Vector2(-11.0, zz), 5.3), _w(Vector2(11.0, zz), 5.3), 1.3, [0, 1, 0, 2, 1][i])
	var tops: Array[Vector3] = []
	for i in 5:
		var p := Vector2(6.3, [34.0, 50.0, 70.0, 92.0, 113.0][i])
		_at(k, p, 0.0)
		tops.append(Props.utility_pole(k, i == 2))
		_blocked.append([p, 0.6])
	_wires(tops, Vector3(1, 0, 0))
	for i in 4:
		var z := 44.0 + i * 21.0
		for sx: float in [-1.0, 1.0]:
			# service line to the gable, a car in the bay, banks left by the plough
			Props.rope(k, tops[i + 1] + Vector3(0, -0.5, 0), _w(Vector2(sx * 11.3, z), 5.6), 0.5, 8, 0.02, "black")
			if sr.randf() < 0.7:
				_at(k, Vector2(sx * 7.6, z - sx * 4.6), PI * 0.5 * sx + sr.randf_range(-0.06, 0.06))
				Props.car(k, sr, sr.randf() < 0.75)
				_blocked.append([Vector2(sx * 7.6, z - sx * 4.6), 2.6])
	for sx: float in [-1.0, 1.0]:
		var z := 27.0
		while z < 130.0:
			var len := sr.randf_range(5.0, 9.0)
			var zc := z + len * 0.5
			var open := false
			for i in 4:
				var hz := 44.0 + i * 21.0
				if (zc + len * 0.5 > hz - 1.6 and zc - len * 0.5 < hz + 1.6) or (zc + len * 0.5 > hz - sx * 4.6 - 1.9 and zc - len * 0.5 < hz - sx * 4.6 + 1.9):
					open = true
			if not open:
				_at(soft, Vector2(sx * 5.0, zc), sr.randf_range(-0.08, 0.08), -0.1)
				_bank(sr, len, false)
				z += len
			else:
				z += 1.2
	# --- the cross street, east and west of the square
	for side in [-1.0, 1.0]:
		var sg: float = side
		var wt: Array[Vector3] = []
		for i in 4:
			var x := sg * (34.0 + i * 20.0)
			var sz := -1.0 if i % 2 == 0 else 1.0
			_at(k, Vector2(x, sz * 5.2), PI if sz < 0.0 else 0.0)
			Props.street_light(k, (i + int(sg)) % 3 != 0, i == 2)
			if i > 0:
				var xx := sg * (52.0 + (i - 1) * 22.0)
				Props.chain(k, rng, _w(Vector2(xx, -12.8), 5.3), _w(Vector2(xx, 12.8), 5.3), 1.4, [1, 0, 2][i - 1])
		for i in 4:
			var p := Vector2([30.0, 50.0, 71.0, 97.0][i] if sg > 0.0 else [-30.0, -50.0, -71.0, -90.0][i], 6.2)
			_at(k, p, PI * 0.5)
			wt.append(Props.utility_pole(k, i == 1))
			_blocked.append([p, 0.6])
		_wires(wt, Vector3(0, 0, 1))
		for i in 3:
			var x := sg * (60.0 + i * 22.0)
			for sz: float in [-1.0, 1.0]:
				if sr.randf() < 0.65:
					_at(k, Vector2(x + 4.6, sz * 7.4), (0.0 if sz > 0.0 else PI) + sr.randf_range(-0.06, 0.06))
					Props.car(k, sr, sr.randf() < 0.75)
					_blocked.append([Vector2(x + 4.6, sz * 7.4), 2.6])
		for sz: float in [-1.0, 1.0]:
			var x := 28.0
			while x < 112.0:
				var len := sr.randf_range(5.0, 9.0)
				var xc := x + len * 0.5
				var open := false
				for i in 3:
					var hx := 60.0 + i * 22.0
					if sg < 0.0:
						hx = -hx
					var wx := sg * xc
					if (wx + len * 0.5 > hx - 1.6 and wx - len * 0.5 < hx + 6.6):
						open = true
				if not open:
					_at(soft, Vector2(sg * xc, sz * 4.8), PI * 0.5 + sr.randf_range(-0.08, 0.08), -0.1)
					_bank(sr, len, false)
					x += len
				else:
					x += 1.2
	for i in 3:
		_at(k, Vector2(4.0 * (i - 1), -36.0 - absf(i - 1.0)))
		Props.lamp(k, i != 1, false)
	# --- what a town has at its kerbs
	_at(k, Vector2(5.2, 128.0), 0.0)
	Props.road_sign(k, "town")
	var name := Label3D.new()
	name.text = "POLARIS"
	name.font_size = 64
	name.pixel_size = 0.0042
	name.modulate = Color(0.05, 0.05, 0.05)
	name.outline_size = 0
	name.position = _w(Vector2(5.2, 128.06), 1.95)
	add_child(name)
	_at(k, Vector2(-5.2, 116.0), 0.0)
	Props.road_sign(k, "speed")
	var lim := Label3D.new()
	lim.text = "30"
	lim.font_size = 64
	lim.pixel_size = 0.0045
	lim.modulate = Color(0.05, 0.05, 0.05)
	lim.outline_size = 0
	lim.position = _w(Vector2(-5.2, 116.08), 2.3)
	add_child(lim)
	_at(k, Vector2(5.0, 29.0), 0.0)
	Props.road_sign(k, "yield")
	_at(k, Vector2(-29.0, 5.0), -PI * 0.5)
	Props.road_sign(k, "yield")
	_at(k, Vector2(29.0, -5.0), PI * 0.5)
	Props.road_sign(k, "yield")
	_at(k, Vector2(-5.4, 12.0 + 84.0), PI * 0.5)
	Props.road_sign(k, "bus")
	_at(k, Vector2(-7.2, 99.5), PI * 0.5)
	Props.bus_shelter(k, true)
	_blocked.append([Vector2(-7.2, 99.5), 2.4])
	Props.lights.append([_w(Vector2(-7.0, 99.5), 2.2), Color(0.8, 0.9, 1.0), 1.0, 7.0, true])
	_at(k, Vector2(5.9, 54.5), -PI * 0.5)
	Props.mailboxes(k, 6)
	_at(k, Vector2(41.0, 5.9), PI)
	Props.mailboxes(k, 5)
	_at(k, Vector2(-47.0, -5.9), 0.0)
	Props.mailboxes(k, 4)
	for p: Vector2 in [Vector2(5.6, 31.5), Vector2(-27.0, 5.6), Vector2(27.5, -5.6), Vector2(-4.8, -30.0), Vector2(-5.6, 95.0)]:
		_at(k, p, sr.randf() * TAU)
		Props.litter_bin(k)
	_at(k, Vector2(-5.5, 60.0), 0.0)
	Props.hydrant(k)
	_at(k, Vector2(52.0, -5.4), 0.0)
	Props.hydrant(k)
	# the plough's big heaps at the corners of the square
	for p: Vector2 in [Vector2(9.5, 30.0), Vector2(-9.0, 31.0), Vector2(30.0, 9.0), Vector2(-31.0, -9.5), Vector2(31.0, -9.0)]:
		_at(soft, p, sr.randf() * TAU, -0.1)
		soft.ball(Vector3.ZERO, Vector3(sr.randf_range(2.2, 3.2), sr.randf_range(1.1, 1.7), sr.randf_range(1.8, 2.6)), "snow", 10, 6)
		soft.ball(Vector3(1.4, 0.0, 0.8), Vector3(1.6, 0.8, 1.5), "snow", 9, 5)


## A plough bank along local Z: a long low ridge with lumps thrown on it.
func _bank(sr: RandomNumberGenerator, len: float, _big: bool) -> void:
	soft.ball(Vector3.ZERO, Vector3(sr.randf_range(1.0, 1.4), sr.randf_range(0.4, 0.6), len * 0.62), "snow", 14, 7)
	var n := int(len / 1.3)
	for i in n:
		var z := -len * 0.5 + len * (i + sr.randf()) / n
		var r := sr.randf_range(0.45, 0.95)
		soft.ball(Vector3(sr.randf_range(-0.5, 0.5), sr.randf_range(0.1, 0.35), z), Vector3(r, r * sr.randf_range(0.5, 0.8), r * sr.randf_range(1.0, 1.7)), "snow", 10, 6, Basis(Vector3.UP, sr.randf() * TAU))


## Three conductors from pole to pole. `arm` is the direction of the cross-arms.
func _wires(tops: Array[Vector3], arm: Vector3) -> void:
	for i in tops.size() - 1:
		for o: float in [-0.75, 0.0, 0.75]:
			Props.rope(k, tops[i] + arm * o, tops[i + 1] + arm * o, 0.7, 10, 0.02, "black")


func _cable_car() -> void:
	var s := Vector2(80, -100)
	var dir := Vector2(0.6, -0.8)
	var yaw := atan2(dir.x, dir.y)
	var arm := Vector3(cos(yaw), 0, -sin(yaw))
	var tops: Array[Vector3] = []
	for i in 6:
		var p := s + dir * (9.0 + 62.0 * i)
		var h := 9.0 if i == 0 else 17.0
		_at(k, p, yaw)
		Props.cable_tower(k, h)
		tops.append(_w(p, h + 0.5))
		_blocked.append([p, 2.5])
	# boarding platform behind the station
	_at(k, s + dir * 9.0, yaw)
	k.box(Vector3(0, 0.15, -1.0), Vector3(9.0, 0.5, 8.0), "concrete")
	k.box(Vector3(0, 6.2, -2.0), Vector3(9.5, 0.25, 7.0), "steel")
	for sx in [-1.0, 1.0]:
		for z in [-5.0, 1.0]:
			k.box(Vector3(sx * 4.4, 3.2, z), Vector3(0.25, 6.0, 0.25), "steel")
	for i in 5:
		for side in [-1.0, 1.0]:
			var sg: float = side
			var a := tops[i] + arm * sg * 2.6
			var b := tops[i + 1] + arm * sg * 2.6
			var pts := Props.rope(k, a, b, 3.0, 12, 0.07, "black")
			if (i == 0 and sg > 0.0) or (i == 3 and sg < 0.0):
				var g := Spinner.new()
				g.mode = "rock"
				g.axis = Vector3(0, 0, 1)
				g.speed = 0.8
				g.amp = 0.1 if i == 0 else 0.04
				g.position = pts[4]
				g.rotation.y = yaw
				var gk := MeshKit.new()
				Props.gondola(gk, "paint_red" if i == 0 else "paint_yellow")
				g.add_child(gk.node(false))
				add_child(g)
	# one gondola came down
	var fp := s + dir * 110.0 + Vector2(6, 3)
	k.xf = Transform3D(Basis(Vector3.UP, yaw + 0.6) * Basis(Vector3(0, 0, 1), 1.32), _w(fp, 1.5))
	Props.gondola(k, "paint_blue")


func _scatter() -> void:
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector2(cos(a), sin(a)) * 12.0
		_at(k, p, atan2(-p.x, -p.y))
		Props.bench(k)
	var made := 0
	while made < 5:
		var p := Vector2(rng.randf_range(-45, 45), rng.randf_range(-35, 110))
		if not _free(p, 1.5):
			continue
		made += 1
		_at(k, p, rng.randf() * TAU)
		Props.snowman(k, rng)
	for i in 30:
		var p := Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		if not _free(p, 0.8) or p.length() < 8.5:
			continue
		_at(k, p, rng.randf() * TAU)
		match i % 4:
			0:
				Props.crate(k, rng.randf_range(0.5, 0.9))
			1:
				Props.barrel(k)
			2:
				_at(soft, p, rng.randf() * TAU)
				Props.sled(soft)
			_:
				_at(soft, p, rng.randf() * TAU)
				if GameMode.summer():
					Props.barrel(soft)       # no Christmas parcels lying about in summer
					for _r in 3:
						rng.randf()          # keep the rest of the town where it was
					rng.randi()
				else:
					Props.gift(soft, rng)
	for i in 90:
		var p := Vector2(rng.randf_range(-125, 125), rng.randf_range(-70, 125))
		var yaw := rng.randf() * TAU
		var r := rng.randf_range(0.8, 2.6)
		# not inside a house, and not on a street the plough has cleared
		if not _free(p, r) or absf(p.x) < 5.5 + r or absf(p.y) < 5.5 + r or p.length() < 27.0 + r:
			rng.randf()
			continue
		_at(soft, p, yaw)
		Props.drift(soft, rng, r)


func _make_bulbs() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/bulb.gdshader")
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = Props.bulbs.size()
	for i in Props.bulbs.size():
		var b: Array = Props.bulbs[i]
		var pos: Vector3 = b[0]
		var col: Color = b[1]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		mm.set_instance_color(i, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _make_lights() -> void:
	add_lights_from(0)


## Turns the collected lamp entries from index `start` on into light nodes.
func add_lights_from(start: int) -> void:
	for li in range(start, Props.lights.size()):
		var d: Array = Props.lights[li]
		var flick: bool = d[4]
		var light: OmniLight3D = Flicker.new() if flick else OmniLight3D.new()
		var pos: Vector3 = d[0]
		var col: Color = d[1]
		var energy: float = d[2]
		var rng_m: float = d[3]
		light.position = pos
		light.light_color = col
		light.light_energy = energy
		if flick:
			(light as Flicker).base = energy
		light.omni_range = rng_m
		light.omni_attenuation = 1.3
		light.distance_fade_enabled = true
		light.distance_fade_begin = 120.0
		light.distance_fade_length = 25.0
		add_child(light)


func _speakers() -> void:
	var spots: Array[Vector2] = [Vector2(19, 19), Vector2(-19, -19), Vector2(6.5, 82), Vector2(84, 6.5), Vector2(-84, -6.5)]
	for i in spots.size():
		_blocked.append([spots[i], 0.6])
		var kit := MeshKit.new()
		Props.speaker(kit)
		var n := kit.node(true)
		n.position = _w(spots[i])
		n.rotation.y = i * 1.1
		add_child(n)
		var music := AudioStreamPlayer3D.new()
		music.stream = Synth.music()
		music.position = n.position + Vector3(0, 5.2, 0)
		music.unit_size = 9.0
		music.max_distance = 130.0
		music.pitch_scale = [1.0, 0.965, 1.02, 0.94, 0.985][i]
		add_child(music)
		music.play(rng.randf() * 40.0)
		if i == 1 or i == 3:
			var voice := AudioStreamPlayer3D.new()
			voice.stream = Synth.announcement()
			voice.position = music.position
			voice.unit_size = 11.0
			voice.max_distance = 130.0
			add_child(voice)
			voice.play(rng.randf() * 20.0)
