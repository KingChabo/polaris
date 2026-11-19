class_name Wilds
extends Node3D
## Everything outside the village: log cabins in the forest, raider camps,
## the ice fisher's spot on the lake and a marked climbing route.

static var sites: Array = []       # {kind, pos: Vector2}
static var climb := {}             # {base: Vector3, top: Vector3, dir: Vector3}

var terrain: Terrain
var village: Village
var cabins: Array[Node3D] = []
var camps: Array[Vector3] = []
var fisher_spot := Vector3.ZERO
var rng := RandomNumberGenerator.new()


## Chooses the places before the forest grows, so trees can leave them free.
static func plan(t: Terrain) -> void:
	sites.clear()
	var mask := FastNoiseLite.new()
	mask.seed = 5
	mask.frequency = 1.0 / 260.0
	mask.fractal_octaves = 3
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var want := ["cabin", "camp", "cabin", "camp", "cabin", "cabin", "camp", "cabin", "cabin"]
	var tries := 0
	while sites.size() < want.size() and tries < 60000:
		tries += 1
		var kind: String = want[sites.size()]
		var p := Vector2(r.randf_range(-720, 720), r.randf_range(-720, 720))
		var dv := p.distance_to(Terrain.VILLAGE_POS)
		if kind == "camp":
			if dv < 230.0 or dv > 430.0:
				continue
		elif dv < 210.0 or mask.get_noise_2d(p.x, p.y) < 0.06:
			continue
		if p.distance_to(Terrain.LAKE_POS) < Terrain.LAKE_R + 40.0 or Places.near(p, 45.0):
			continue
		var h := t.height_at(p.x, p.y)
		if h < Terrain.LAKE_LEVEL + 3.0 or h > 105.0:
			continue
		if t.normal_at(p.x, p.y).y < 0.975:
			continue
		var flat := true
		for o in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
			var q: Vector2 = p + o
			if absf(t.height_at(q.x, q.y) - h) > 0.7:
				flat = false
		if not flat:
			continue
		var near := false
		for s in sites:
			if (s["pos"] as Vector2).distance_to(p) < 140.0:
				near = true
		if near:
			continue
		sites.append({"kind": kind, "pos": p})
	_plan_climb(t)


## Finds the nearest rock wall worth climbing: a steep face with flat ground below and above.
static func _plan_climb(t: Terrain) -> void:
	climb = {}
	var best := 1e9
	var x := -900.0
	while x <= 900.0:
		var z := -900.0
		while z <= 900.0:
			var n := t.normal_at(x, z)
			var dv := Vector2(x, z).distance_to(Terrain.VILLAGE_POS)
			if n.y < 0.6 and dv < best and dv > 180.0 and not Places.near(Vector2(x, z), 40.0):
				var up := Vector2(-n.x, -n.z).normalized()
				var base := Vector2(x, z)
				var top := Vector2(x, z)
				var ok_b := false
				var ok_t := false
				for i in 30:
					base -= up * 2.0
					if t.normal_at(base.x, base.y).y > 0.9:
						ok_b = true
						break
				for i in 45:
					top += up * 2.0
					if t.normal_at(top.x, top.y).y > 0.9:
						ok_t = true
						break
				var hb := t.height_at(base.x, base.y)
				var ht := t.height_at(top.x, top.y)
				if ok_b and ok_t and ht - hb > 18.0 and hb > Terrain.LAKE_LEVEL + 2.0:
					best = dv
					climb = {"base": Vector3(base.x, hb, base.y), "top": Vector3(top.x, ht, top.y), "dir": Vector3(up.x, 0, up.y)}
			z += 12.0
		x += 12.0


static func cleared(x: float, z: float) -> bool:
	for s in sites:
		var p: Vector2 = s["pos"]
		if absf(p.x - x) < 13.0 and absf(p.y - z) < 13.0 and p.distance_to(Vector2(x, z)) < 12.0:
			return true
	return false


func _ground(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.y) + lift, p.y)


func build(t: Terrain, v: Village) -> void:
	terrain = t
	village = v
	rng.seed = 404
	var k := MeshKit.new()
	var n_cabin := 0
	var n_camp := 0
	for s in sites:
		var p: Vector2 = s["pos"]
		if s["kind"] == "cabin":
			_cabin(k, p, n_cabin)
			n_cabin += 1
		else:
			_camp(k, p, n_camp)
			n_camp += 1
	_fisher(k)
	_climb_route(k)
	k.xf = Transform3D.IDENTITY
	add_child(k.node(true))
	print("Wilds: %d cabins, %d camps, climb %s" % [n_cabin, n_camp, "yes" if not climb.is_empty() else "none"])


func _chest(parent: Node3D, pos: Vector3, yaw: float, cid: String, items: Dictionary, title := "Chest") -> void:
	var chest := LootBox.new()
	chest.setup()
	chest.id = cid
	chest.title = title
	chest.items = items
	parent.add_child(chest)
	chest.position = pos
	chest.rotation.y = yaw


func _cabin(k: MeshKit, p: Vector2, i: int) -> void:
	var lit := i % 2 == 0
	var n := Chalet.build("cabin", rng, lit)
	var yaw := atan2(Terrain.VILLAGE_POS.x - p.x, Terrain.VILLAGE_POS.y - p.y) + rng.randf_range(-0.5, 0.5)
	n.position = _ground(p, 0.05)
	n.rotation.y = yaw
	add_child(n)
	Chalet.seat(n, terrain)
	n.set_meta("lit", lit)
	n.set_meta("index", i)
	cabins.append(n)
	village.houses.append(n)     # so it shelters you like any house
	var size: Vector2 = n.get_meta("size")
	var items := Items.roll("house", rng)
	match i:
		0:
			items["rope"] = 1
			items["ice_pick"] = 1
		1:
			items["marksman_rifle"] = 1
			items["762"] = 20
			items["scope"] = 1
		2:
			items["fur_hood"] = 1
			items["fur_boots"] = 1
		3:
			items["aux_tank"] = 1
			items["fuel_can"] = 1
		_:
			items["medkit"] = 1
			items["canned_food"] = 3
	_chest(n, Vector3(-size.x * 0.5 + 0.85, Chalet.Y0, size.y * 0.5 - 0.8), PI * 0.5, "cabin_%d" % i, items, "Cabin chest")
	# outside: wood pile under a lean-to, chopping block with an axe, a sled, a path lantern
	var b := Basis(Vector3.UP, yaw)
	k.xf = Transform3D(b, n.position)
	var hx := size.x * 0.5
	for row in 4:
		for j in 7:
			k.tube(Vector3(hx + 0.35, 0.12 + row * 0.2, -1.2 + j * 0.21 + (row % 2) * 0.1), Vector3(hx + 0.95, 0.12 + row * 0.2, -1.2 + j * 0.21 + (row % 2) * 0.1), 0.1, "wood", 6)
	k.box(Vector3(hx + 0.7, 1.15, -0.55), Vector3(1.0, 0.06, 1.9), "planks", Basis(Vector3(0, 0, 1), -0.25))
	k.box(Vector3(hx + 0.75, 1.3, -0.55), Vector3(1.0, 0.14, 1.9), "snow", Basis(Vector3(0, 0, 1), -0.25))
	for z in [-1.4, 0.3]:
		var zz: float = z
		k.box(Vector3(hx + 1.1, 0.5, zz), Vector3(0.08, 1.1, 0.08), "wood_dark")
	k.cyl(Vector3(hx + 1.6, 0.0, 1.8), 0.28, 0.45, "wood", 9)
	k.tube(Vector3(hx + 1.55, 0.45, 1.8), Vector3(hx + 1.2, 1.05, 1.75), 0.022, "wood_dark", 6)
	k.box(Vector3(hx + 1.57, 0.5, 1.8), Vector3(0.05, 0.2, 0.16), "steel", Basis(Vector3(0, 0, 1), 0.5))
	for j in 3:
		k.tube(Vector3(hx + 2.0 + j * 0.2, 0.08, 1.4 + j * 0.3), Vector3(hx + 2.3 + j * 0.15, 0.08, 1.7 + j * 0.2), 0.09, "wood", 6)
	k.xf = Transform3D(b, n.position + b * Vector3(-hx - 1.2, 0.05, 1.5))
	Props.sled(k)
	# snow shoes by the door, a lantern on a post
	k.xf = Transform3D(b, n.position)
	var hz := size.y * 0.5
	k.box(Vector3(1.6, 0.9, hz + 0.6), Vector3(0.09, 1.9, 0.09), "wood_dark")
	k.box(Vector3(1.45, 1.75, hz + 0.6), Vector3(0.4, 0.05, 0.05), "wood_dark")
	k.box(Vector3(1.3, 1.55, hz + 0.6), Vector3(0.16, 0.24, 0.16), "lamp_glow" if lit else "glass_dark")
	k.cyl(Vector3(1.3, 1.67, hz + 0.6), 0.13, 0.08, "metal", 4, 0.02)
	if lit:
		var l := Flicker.new()
		l.position = n.position + b * Vector3(1.3, 1.6, hz + 0.75)
		l.light_color = Props.WARM
		l.light_energy = 1.6
		l.base = 1.6
		l.omni_range = 10.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 80.0
		l.distance_fade_length = 20.0
		add_child(l)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(-1.5 + sx * 0.14, 0.6, hz + 0.2), Vector3(0.22, 0.9, 0.03), "wood", Basis(Vector3.RIGHT, -0.2))


func _tent(k: MeshKit, at: Vector3, yaw: float, cloth: String) -> void:
	k.xf = Transform3D(Basis(Vector3.UP, yaw), at)
	var a := Vector3(-1.3, 0, 1.5)
	var b := Vector3(1.3, 0, 1.5)
	var c := Vector3(0, 1.7, 1.5)
	var a2 := Vector3(-1.3, 0, -1.5)
	var b2 := Vector3(1.3, 0, -1.5)
	var c2 := Vector3(0, 1.7, -1.5)
	k.quad_o(a, a2, c2, c, Vector3(-1, 1, 0), cloth)
	k.quad_o(a, a2, c2, c, Vector3(1, -1, 0), cloth + "_in")
	k.quad_o(b, b2, c2, c, Vector3(1, 1, 0), cloth)
	k.quad_o(b, b2, c2, c, Vector3(-1, -1, 0), cloth + "_in")
	k.tri_o(a2, b2, c2, Vector3(0, 0, -1), cloth)
	k.tri_o(a2, b2, c2, Vector3(0, 0, 1), cloth + "_in")
	# half-open front flap, poles, guy ropes, bedroll inside
	k.tri_o(a, Vector3(-0.25, 0, 1.52), c, Vector3(0, 0, 1), cloth)
	k.tri_o(b, Vector3(0.5, 0, 1.9), c, Vector3(0, 0, 1), cloth)
	for z in [-1.5, 1.5]:
		var zz: float = z
		k.cyl(Vector3(0, 0, zz), 0.03, 1.8, "wood_dark", 5)
		for sx in [-1.0, 1.0]:
			k.tube(Vector3(0, 1.7, zz), Vector3(sx * 2.1, 0.02, zz + signf(zz) * 0.6), 0.008, "black", 4)
			k.cyl(Vector3(sx * 2.1, 0, zz + signf(zz) * 0.6), 0.02, 0.18, "wood", 4)
	k.bbox(Vector3(-0.5, 0.1, -0.3), Vector3(0.7, 0.16, 1.9), 0.06, "olive_in")
	k.ball(Vector3(-0.5, 0.2, -1.1), Vector3(0.22, 0.09, 0.15), "cream_in", 8, 5)
	k.box(Vector3(0.6, 0.2, -0.8), Vector3(0.5, 0.4, 0.5), "wood_in")


func _camp(k: MeshKit, p: Vector2, i: int) -> void:
	var c := _ground(p)
	camps.append(c)
	for j in 3:
		var a := j * TAU / 3.0 + i
		var q := p + Vector2(cos(a), sin(a)) * 5.2
		_tent(k, _ground(q), atan2(-cos(a), -sin(a)), ["olive", "camo", "fur_dark"][(i + j) % 3])
	# fire ring with a pot on a tripod, log seats
	k.xf = Transform3D(Basis.IDENTITY, c)
	for j in 9:
		var a := j * TAU / 9.0
		k.ball(Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6), Vector3(0.16, 0.12, 0.14), "stone", 7, 4)
	for j in 4:
		var a := j * 0.8
		k.tube(Vector3(cos(a) * 0.4, 0.1, sin(a) * 0.4), Vector3(-cos(a) * 0.35, 0.22, -sin(a) * 0.35), 0.07, "wood_dark", 6)
	for j in 5:
		k.cyl(Vector3(cos(j * 1.3) * 0.18, 0.15, sin(j * 1.3) * 0.18), 0.09, 0.35 + (j % 2) * 0.2, "candle", 5, 0.0)
	for j in 3:
		var a := j * TAU / 3.0
		k.tube(Vector3(cos(a) * 0.8, 0, sin(a) * 0.8), Vector3(0, 1.6, 0), 0.025, "metal", 5)
	k.cyl(Vector3(0, 0.75, 0), 0.006, 0.85, "black", 4)
	k.cyl(Vector3(0, 0.55, 0), 0.17, 0.2, "metal", 10)
	for j in 3:
		var a := j * TAU / 3.0 + 0.5
		var lp := Vector3(cos(a) * 1.9, 0.2, sin(a) * 1.9)
		k.tube(lp + Vector3(-sin(a), 0, cos(a)) * 0.8, lp - Vector3(-sin(a), 0, cos(a)) * 0.8, 0.2, "wood", 8)
	# crates, barrels, a red flag on a pole, spiked barricades towards the village
	k.xf = Transform3D(Basis(Vector3.UP, i * 1.1), c + Vector3(3.2, 0, -2.6))
	Props.crate(k, 0.8)
	k.xf = Transform3D(Basis(Vector3.UP, i * 0.7), c + Vector3(3.9, 0, -1.9))
	Props.barrel(k)
	k.xf = Transform3D(Basis.IDENTITY, c + Vector3(-2.8, 0, -3.0))
	k.cyl(Vector3.ZERO, 0.05, 5.0, "wood_dark", 6)
	k.box(Vector3(0.6, 4.5, 0), Vector3(1.2, 0.7, 0.02), "red")
	k.box(Vector3(0.6, 4.5, 0.012), Vector3(0.25, 0.25, 0.01), "black")
	var to_v := (Terrain.VILLAGE_POS - p).normalized()
	for j in 4:
		var side := Vector2(-to_v.y, to_v.x)
		var q := p + to_v * 9.5 + side * (j - 1.5) * 2.6
		k.xf = Transform3D(Basis(Vector3.UP, atan2(to_v.x, to_v.y)), _ground(q))
		k.tube(Vector3(-1.1, 0.5, 0), Vector3(1.1, 0.5, 0), 0.07, "wood_dark", 6)
		for m in 5:
			var x := -0.9 + m * 0.45
			k.tube(Vector3(x, 0.0, -0.45), Vector3(x, 1.05, 0.5), 0.045, "wood", 5, 0.008)
			k.tube(Vector3(x + 0.2, 0.0, 0.45), Vector3(x + 0.2, 0.8, -0.35), 0.045, "wood", 5)
	var l := Flicker.new()
	l.position = c + Vector3(0, 0.9, 0)
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 3.2
	l.base = 3.2
	l.omni_range = 16.0
	l.shadow_enabled = true
	l.distance_fade_enabled = true
	l.distance_fade_begin = 110.0
	l.distance_fade_length = 30.0
	l.distance_fade_shadow = 40.0
	add_child(l)
	var loot := [
		{"smg": 1, "9mm": 60, "bandage": 2, "scrap": 3, "canned_food": 2},
		{"kevlar_vest": 1, "556": 60, "556_ap": 20, "medkit": 1, "armor_plates": 1},
		{"sniper_rifle": 1, "338": 12, "silencer": 1, "painkillers": 2, "winch_kit": 1},
	]
	var lp := p + Vector2(cos(i + 1.0), sin(i + 1.0)) * 3.4
	_chest(self, _ground(lp), rng.randf() * TAU, "camp_%d" % i, loot[i % 3], "Raider stash")


func _fisher(k: MeshKit) -> void:
	# a spot on thick ice, on the village side of the lake
	var dir := (Terrain.VILLAGE_POS - Terrain.LAKE_POS).normalized()
	var p := Terrain.LAKE_POS + dir * (Terrain.LAKE_R * 0.62)
	fisher_spot = Vector3(p.x, Terrain.LAKE_LEVEL, p.y)
	k.xf = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), fisher_spot)
	k.cyl(Vector3(0, 0.005, -1.0), 0.32, 0.01, "black", 14)
	for j in 10:
		var a := j * TAU / 10.0
		k.ball(Vector3(cos(a) * 0.4, 0.04, -1.0 + sin(a) * 0.4), Vector3(0.1, 0.06, 0.09), "snow", 6, 4)
	# folding stool, rod on a rest, bucket with fish, auger, sled with a box, lantern
	k.box(Vector3(0, 0.42, 0), Vector3(0.38, 0.04, 0.34), "cloth")
	for sx in [-1.0, 1.0]:
		k.tube(Vector3(sx * 0.17, 0.0, -0.15), Vector3(sx * 0.17, 0.42, 0.15), 0.014, "steel", 5)
		k.tube(Vector3(sx * 0.17, 0.0, 0.15), Vector3(sx * 0.17, 0.42, -0.15), 0.014, "steel", 5)
	k.tube(Vector3(0.3, 0.35, -0.2), Vector3(0.1, 0.8, -1.0), 0.008, "wood_dark", 5)
	k.cyl(Vector3(0.1, 0.02, -1.0), 0.002, 0.78, "black", 3)
	k.cyl(Vector3(0.3, 0.0, -0.2), 0.012, 0.36, "wood", 4)
	k.cyl(Vector3(-0.6, 0.0, -0.5), 0.16, 0.3, "steel", 10, 0.19)
	for j in 3:
		k.ball(Vector3(-0.6 + j * 0.05, 0.3, -0.5 + j * 0.03), Vector3(0.04, 0.03, 0.14), "grey", 6, 4, Basis(Vector3.UP, j * 0.9))
	k.cyl(Vector3(0.8, 0.0, -0.6), 0.012, 1.2, "steel", 5)
	for j in 6:
		k.box(Vector3(0.8, 0.08 + j * 0.06, -0.6), Vector3(0.22, 0.012, 0.06), "steel", Basis(Vector3.UP, j * 1.05))
	k.box(Vector3(0.8, 1.2, -0.6), Vector3(0.3, 0.03, 0.03), "red")
	k.xf = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y) + 0.6), fisher_spot + Vector3(1.6, 0, 1.2))
	Props.sled(k)
	k.box(Vector3(0, 0.4, 0), Vector3(0.4, 0.3, 0.6), "wood")
	k.xf = Transform3D(Basis.IDENTITY, fisher_spot + Vector3(-0.9, 0, 0.5))
	k.cyl(Vector3.ZERO, 0.08, 0.04, "metal", 8)
	k.cyl(Vector3(0, 0.04, 0), 0.06, 0.16, "lamp_glow", 8)
	k.cyl(Vector3(0, 0.2, 0), 0.08, 0.05, "metal", 8, 0.02)
	var l := Flicker.new()
	l.position = fisher_spot + Vector3(-0.9, 0.5, 0.5)
	l.light_color = Props.WARM
	l.light_energy = 1.4
	l.base = 1.4
	l.omni_range = 8.0
	add_child(l)


func _climb_route(k: MeshKit) -> void:
	if climb.is_empty():
		return
	var base: Vector3 = climb["base"]
	var top: Vector3 = climb["top"]
	var dir: Vector3 = climb["dir"]
	var yaw := atan2(dir.x, dir.z)
	# at the foot: a signpost, a cairn, a climbers' cache
	k.xf = Transform3D(Basis(Vector3.UP, yaw), base - dir * 2.0)
	k.cyl(Vector3(1.6, 0, 0), 0.06, 2.3, "wood_dark", 6)
	k.box(Vector3(1.6, 2.0, 0), Vector3(1.1, 0.3, 0.05), "paint_yellow")
	k.box(Vector3(1.6, 1.62, 0), Vector3(0.9, 0.24, 0.05), "paint_red")
	for j in 6:
		k.ball(Vector3(-1.6 + (j % 2) * 0.15, 0.15 + j * 0.2, 0.0), Vector3(0.4 - j * 0.05, 0.14, 0.36 - j * 0.045), "stone", 7, 4)
	var lab := Label3D.new()
	lab.text = "KLETTERSTEIG\nGIPFELBLICK"
	lab.font_size = 48
	lab.pixel_size = 0.0035
	lab.modulate = Color(0.1, 0.08, 0.05)
	lab.outline_size = 0
	lab.position = base - dir * 2.06 + Basis(Vector3.UP, yaw) * Vector3(1.6, 1.84, 0.0)
	lab.rotation.y = yaw + PI
	add_child(lab)
	_chest(self, base - dir * 3.0 + Basis(Vector3.UP, yaw) * Vector3(-0.2, 0, 0), yaw, "climb_base", {"rope": 1, "ice_pick": 1, "hand_warmer": 2, "hot_tea": 1}, "Climbers' cache")
	# red marks and iron pegs up the face
	var steps := int(Vector2(top.x - base.x, top.z - base.z).length() / 2.5)
	for j in steps:
		var q := base.lerp(top, (j + 0.5) / steps)
		var h := terrain.height_at(q.x, q.z)
		var n := terrain.normal_at(q.x, q.z)
		k.xf = Transform3D(Basis(Quaternion(Vector3.UP, n)), Vector3(q.x, h, q.z))
		k.cyl(Vector3.ZERO, 0.025, 0.3, "steel", 5)
		k.box(Vector3(0.5, 0.03, 0), Vector3(0.4, 0.02, 0.4), "red")
	# on top: a summit cross, a bench, a chest
	k.xf = Transform3D(Basis(Vector3.UP, yaw), top + dir * 3.0)
	k.box(Vector3(0, 1.6, 0), Vector3(0.16, 3.2, 0.16), "wood_dark")
	k.box(Vector3(0, 2.5, 0), Vector3(1.5, 0.16, 0.16), "wood_dark")
	k.box(Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), "stone")
	k.xf = Transform3D(Basis(Vector3.UP, yaw + PI), top + dir * 1.2 + Basis(Vector3.UP, yaw) * Vector3(2.4, 0, 0))
	Props.bench(k)
	_chest(self, top + dir * 3.0 + Basis(Vector3.UP, yaw) * Vector3(-2.0, 0, 0.5), yaw + PI, "climb_top", {"expedition_suit": 1, "scope": 1, "338": 10, "medkit": 1, "flare": 3}, "Summit box")
