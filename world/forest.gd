class_name Forest
extends Node3D
## Snow-covered conifer forest. Trees are built in code: near ones have single
## drooping boughs, far ones switch to a cheap cone shape. Drawn with MultiMesh.

const CELL := 128.0
const VARIANTS := 4      # 0-2 spruce (2 is the big one on the plaza), 3 pine
const LOD_DIST := 110.0

var noise_tex: Texture2D
var _meshes: Array[ArrayMesh] = []
var _lods: Array[ArrayMesh] = []
var _scans: Array = []            # scanned near tree per variant, or null
const SCAN_DIST := 42.0           # scanned (heavy) models only this close
var _fringe := false  # true while building boughs: their edges get a ragged needle outline


func tree_mesh(variant: int) -> ArrayMesh:
	return _meshes[variant]


func build(terrain: Terrain) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/tree.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("summer", GameMode.summer())
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for v in VARIANTS:
		var m := _make_tree(rng, v)
		m.surface_set_material(0, mat)
		var l := _make_lod(rng, v)
		l.surface_set_material(0, mat)
		# scanned trees from Blender, when they are there
		# (near trees only: far away the light code-built LOD stays, the scan is ~21k triangles)
		var scan := "pine_tree_01" if v == 3 and ModelLib.has("pine_tree_01") else "fir_tree_01"
		var h := 10.0 + v * 2.2
		# the Poly Haven fir and sapling scans lost their needle cards on export (bare twigs and
		# torn quads even in Blender), so the full code tree is used at every distance
		_scans.append(ModelLib.mesh(scan, "", h, 0.55, 1.0) if scan == "pine_tree_01" else null)
		_meshes.append(m)
		_lods.append(l)

	var mask := FastNoiseLite.new()
	mask.seed = 5
	mask.frequency = 1.0 / 260.0
	mask.fractal_octaves = 3

	var buckets := {}  # "cellx_cellz_variant" -> Array[Transform3D]
	var body := StaticBody3D.new()
	add_child(body)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 5.0

	for n in 52000:
		var x := rng.randf_range(-Terrain.HALF + 20.0, Terrain.HALF - 20.0)
		var z := rng.randf_range(-Terrain.HALF + 20.0, Terrain.HALF - 20.0)
		var dense := mask.get_noise_2d(x, z)
		if dense < 0.02 and rng.randf() > 0.035:
			continue
		var h := terrain.height_at(x, z)
		if h < Terrain.LAKE_LEVEL + 1.2 or h > 165.0:
			continue
		if Vector2(x, z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 1.02:
			continue
		if terrain.normal_at(x, z).y < 0.86:
			continue
		if (Wilds.cleared(x, z) or Places.cleared(x, z)):
			continue
		# trees get smaller and rarer near the tree line
		var alt := clampf((h - 90.0) / 75.0, 0.0, 1.0)
		if rng.randf() < alt:
			continue
		var s := rng.randf_range(0.7, 1.45) * (1.0 - alt * 0.45)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		var t := Transform3D(basis, Vector3(x, h - 0.25, z))
		var key := "%d_%d_%d" % [int(floor(x / CELL)), int(floor(z / CELL)), rng.randi() % VARIANTS]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(t)
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 2.2, z)
		body.add_child(cs)

	# the Vorland south of the mountains: its own dice, so the Senke's trees stay where they are
	var rs := RandomNumberGenerator.new()
	rs.seed = 7781
	for n in 40000:
		var x := rs.randf_range(-Terrain.HALF + 20.0, Terrain.HALF - 20.0)
		var z := rs.randf_range(Terrain.SOUTH_FROM, Terrain.Z_MAX - 20.0)
		var dense := mask.get_noise_2d(x, z)
		if dense < 0.0 and rs.randf() > 0.05:
			continue
		var h := terrain.height_at(x, z)
		if h > 160.0 or terrain.normal_at(x, z).y < 0.86 or Places.cleared(x, z):
			continue
		var alt := clampf((h - 85.0) / 75.0, 0.0, 1.0)
		if rs.randf() < alt:
			continue
		var s := rs.randf_range(0.7, 1.5) * (1.0 - alt * 0.45)
		var basis := Basis(Vector3.UP, rs.randf() * TAU).scaled(Vector3(s, s * rs.randf_range(0.9, 1.15), s))
		var key := "%d_%d_%d" % [int(floor(x / CELL)), int(floor(z / CELL)), [0, 1, 3, 3][rs.randi() % 4]]
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(Transform3D(basis, Vector3(x, h - 0.25, z)))
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 2.2, z)
		body.add_child(cs)

	var total := 0
	var per_variant := {}
	for key in buckets:
		var v := int(key.get_slice("_", 2))
		if not per_variant.has(v):
			per_variant[v] = []
		(per_variant[v] as Array).append_array(buckets[key])
	for v in per_variant:
		var list: Array = per_variant[v]
		if _scans[v]:
			# three steps: the scanned tree close by, the code tree, the light far shape
			spread(list, [[_scans[v], 0.0, SCAN_DIST, 24.0, true], [_meshes[v], SCAN_DIST, LOD_DIST, 64.0, true], [_lods[v], LOD_DIST, 0.0, CELL, true]])
		else:
			spread(list, [[_meshes[v], 0.0, LOD_DIST, 64.0, true], [_lods[v], LOD_DIST, 0.0, CELL, true]])
		total += list.size()
	print("Forest: %d trees" % total)
	_ground_cover(terrain, rng, mask, -Terrain.HALF, Terrain.HALF, 1.0)
	_ground_cover(terrain, rs, mask, Terrain.SOUTH_FROM, Terrain.Z_MAX, 0.75)


## Puts copies of meshes on the map in square cells, each step of detail only in its own
## distance band. tiers: [mesh, from, to (0 = no end), cell size, casts shadows].
## (Godot measures the distance to the middle of a cell, so the near steps use small cells.)
func spread(list: Array, tiers: Array) -> void:
	for tier: Array in tiers:
		var cell: float = tier[3]
		var cells := {}
		for t: Transform3D in list:
			var key := Vector2i(int(floor(t.origin.x / cell)), int(floor(t.origin.z / cell)))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(t)
		for key in cells:
			var l: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = tier[0]
			mm.instance_count = l.size()
			for i in l.size():
				mm.set_instance_transform(i, l[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			var from: float = tier[1]
			var to: float = tier[2]
			if from > 0.0:
				mmi.visibility_range_begin = from
				mmi.visibility_range_begin_margin = 4.0
			if to > 0.0:
				mmi.visibility_range_end = to
				mmi.visibility_range_end_margin = 4.0
			if not tier[4]:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)


## Boulders, crags on the mountain sides, fallen logs, stumps and young firs.
func _ground_cover(terrain: Terrain, rng: RandomNumberGenerator, mask: FastNoiseLite, z0: float, z1: float, amount: float) -> void:
	var rock_mat := Mats.get_mat("rock")
	var rocks: Array[ArrayMesh] = []
	var rock_scans: Array = []
	var scans := ["boulder_01", "rock_moss_set_01", "boulder_01"]
	for i in 3:
		var m := _rock_mesh(31 + i * 7)
		m.surface_set_material(0, rock_mat)
		rock_scans.append(ModelLib.mesh(scans[i], "", 1.5, 0.8))
		rocks.append(m)
	var lists: Array = [[], [], []]
	var body := StaticBody3D.new()
	body.set_meta("climb", true)
	add_child(body)
	var placed := 0
	var tries := 0
	while placed < int(1500 * amount) and tries < 60000:
		tries += 1
		var x := rng.randf_range(-Terrain.HALF + 30.0, Terrain.HALF - 30.0)
		var z := rng.randf_range(z0 + 30.0, z1 - 30.0)
		var h := terrain.height_at(x, z)
		if h < Terrain.LAKE_LEVEL + 0.6:
			continue
		if Vector2(x, z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 1.05 or (Wilds.cleared(x, z) or Places.cleared(x, z)):
			continue
		var ny := terrain.normal_at(x, z).y
		var crag := ny < 0.86 and h > 70.0
		if not crag and rng.randf() > 0.3:
			continue
		var s := rng.randf_range(2.5, 8.0) if crag else rng.randf_range(0.35, 1.9) * (2.2 if rng.randf() < 0.06 else 1.0)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		basis = basis.scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.6, 1.5 if crag else 1.0), s * rng.randf_range(0.8, 1.3)))
		# sunk well in, also on the downhill side of a slope (no floating boulders)
		var pos := Vector3(x, h - s * (0.42 + (1.0 - ny) * 1.5), z)
		(lists[rng.randi() % 3] as Array).append(Transform3D(basis, pos))
		if s > 0.9:
			var sh := SphereShape3D.new()
			sh.radius = s * 0.8
			var cs := CollisionShape3D.new()
			cs.shape = sh
			cs.position = pos
			body.add_child(cs)
		placed += 1
	for i in 3:
		if rock_scans[i]:
			spread(lists[i], [[rock_scans[i], 0.0, SCAN_DIST, 24.0, true], [rocks[i], SCAN_DIST, 0.0, CELL, true]])
		else:
			spread(lists[i], [[rocks[i], 0.0, 0.0, CELL, true]])
	# young firs between the big trees: the far-tree shape, scaled down
	var young: Array = []
	for n in int(5000 * amount):
		var x := rng.randf_range(-Terrain.HALF + 20.0, Terrain.HALF - 20.0)
		var z := rng.randf_range(z0 + 20.0, z1 - 20.0)
		if mask.get_noise_2d(x, z) < -0.05:
			continue
		var h := terrain.height_at(x, z)
		if h < Terrain.LAKE_LEVEL + 1.0 or h > 150.0 or terrain.normal_at(x, z).y < 0.88:
			continue
		if Vector2(x, z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 1.02 or (Wilds.cleared(x, z) or Places.cleared(x, z)):
			continue
		var s := rng.randf_range(0.1, 0.32)
		young.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.25, s, s * 1.25)), Vector3(x, h - 0.1, z)))
	spread(young, [[_meshes[0], 0.0, 40.0, 24.0, false], [_lods[0], 40.0, 300.0, 64.0, false]])
	# fallen logs, stumps and snags (scanned stumps and trunks when they are there)
	var k := MeshKit.new()
	var stump := ModelLib.mesh("tree_stump_01", "", 1.1, 0.7)
	var trunk := ModelLib.mesh("dead_tree_trunk", "", 1.0, 0.7)
	var scan_lists: Array = [[], []]
	var logs := 0
	for n in 4000:
		if logs >= int(260 * amount):
			break
		var x := rng.randf_range(-Terrain.HALF + 30.0, Terrain.HALF - 30.0)
		var z := rng.randf_range(z0 + 30.0, z1 - 30.0)
		if mask.get_noise_2d(x, z) < 0.02:
			continue
		var h := terrain.height_at(x, z)
		if h < Terrain.LAKE_LEVEL + 1.2 or h > 140.0 or terrain.normal_at(x, z).y < 0.9:
			continue
		if Vector2(x, z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 1.05 or (Wilds.cleared(x, z) or Places.cleared(x, z)):
			continue
		logs += 1
		var yaw := rng.randf() * TAU
		k.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, h, z))
		if stump and trunk and logs % 3 != 2:
			var sc := rng.randf_range(0.8, 1.4)
			(scan_lists[logs % 3] as Array).append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(x, h - 0.08, z)))
			continue
		match logs % 3:
			0:   # fallen trunk with its root plate and a few broken branches
				var len := rng.randf_range(4.0, 9.0)
				k.tube(Vector3(0, 0.3, 0), Vector3(len, 0.22, 0), 0.3, "wood", 8, 0.12)
				k.cyl(Vector3(-0.1, -0.1, 0), 0.9, 0.2, "wood_dark", 7, 0.5)
				for i in 5:
					var bx := len * (0.3 + i * 0.13)
					k.tube(Vector3(bx, 0.3, 0), Vector3(bx + 0.3, 0.9 + (i % 2) * 0.5, (i % 2 - 0.5) * 1.4), 0.04, "wood_dark", 4, 0.01)
			1:   # stump with a split top
				k.cyl(Vector3(0, -0.2, 0), 0.5, 0.5, "wood", 8, 0.36)
				k.cyl(Vector3(0, 0.3, 0), 0.36, rng.randf_range(0.3, 0.8), "wood", 8, 0.3)
				k.tube(Vector3(0.1, 0.5, 0.0), Vector3(0.22, 1.5, 0.05), 0.1, "wood_dark", 4, 0.0)
			_:   # dead standing snag
				var sh := rng.randf_range(4.0, 8.0)
				k.cyl(Vector3(0, -0.2, 0), 0.34, sh, "wood_dark", 7, 0.1)
				for i in 5:
					var a := i * 2.1
					var by := sh * (0.35 + i * 0.12)
					k.tube(Vector3(0, by, 0), Vector3(cos(a) * 1.1, by + 0.3, sin(a) * 1.1), 0.05, "wood_dark", 4, 0.01)
	k.xf = Transform3D.IDENTITY
	add_child(k.node(true))
	for i in 2:
		var list: Array = scan_lists[i]
		if list.is_empty():
			continue
		spread(list, [[trunk if i == 0 else stump, 0.0, 70.0, 32.0, true]])
		var lb := StaticBody3D.new()
		add_child(lb)
		for t: Transform3D in list:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.45 * t.basis.get_scale().x
			cyl.height = 1.0
			cs.shape = cyl
			cs.position = t.origin + Vector3(0, 0.5, 0)
			lb.add_child(cs)
	print("Ground cover: %d rocks, %d young firs, %d logs" % [placed, young.size(), logs])


## A boulder: a ball pushed in and out by noise, with flat facets.
func _rock_mesh(seed_i: int) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.seed = seed_i
	n.frequency = 0.85
	n.fractal_octaves = 2
	var rings := 6
	var sides := 9
	var pts: Array = []
	for j in rings + 1:
		var lat := PI * j / rings
		var row: Array[Vector3] = []
		for i in sides:
			var lon := TAU * i / sides + j * 0.35
			var d := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			var r := 1.0 + n.get_noise_3dv(d * 1.4) * 0.55
			r = round(r * 5.0) / 5.0 * 0.6 + r * 0.4      # chunky ledges
			row.append(Vector3(d.x * r, d.y * r * 0.78, d.z * r))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings:
		for i in sides:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % sides]
			var c: Vector3 = pts[j + 1][(i + 1) % sides]
			var d: Vector3 = pts[j + 1][i]
			for t in [[a, b, c], [a, c, d]]:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var nr := (p1 - p0).cross(p2 - p0)
				if nr.length_squared() < 1e-8:
					continue
				var mid := (p0 + p1 + p2) / 3.0
				if nr.dot(mid) > 0.0:     # Godot wants clockwise fronts: the cross product must point inwards
					var tmp := p1
					p1 = p2
					p2 = tmp
				var out := mid.normalized().lerp(-(p1 - p0).cross(p2 - p0).normalized(), 0.8).normalized()
				st.set_normal(out); st.add_vertex(p0)
				st.set_normal(out); st.add_vertex(p1)
				st.set_normal(out); st.add_vertex(p2)
	return st.commit()


## Near tree: flared trunk, dead stubs low down, whorls of drooping boughs with
## side twigs and a slab of snow lying on each. Variant 3 is a pine: bare trunk, crown on top.
## Vertex alpha says how much snow can lie there (ridges of the boughs).
func _make_tree(rng: RandomNumberGenerator, variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pine := variant == 3
	var height := 11.0 + variant * 2.0 if not pine else 14.0
	var bark := Color(0.16, 0.10, 0.07, 0.0) if not pine else Color(0.26, 0.13, 0.07, 0.0)
	var bark_d := bark.darkened(0.35)
	bark_d.a = 0.0
	# trunk: root flare, then a long taper
	_cone(st, rng, -0.3, 0.9, 0.42, 0.3, 8, bark_d, bark, 0.1)
	_cone(st, rng, 0.9, height * 0.94, 0.3, 0.035, 8, bark, bark, 0.0)
	var crown0 := 0.16 if not pine else 0.56
	# dead stubs and bare twigs below the crown
	for i in (7 if not pine else 12):
		var y := rng.randf_range(1.2, height * crown0)
		var a := rng.randf() * TAU
		var len := rng.randf_range(0.35, 1.3)
		var o := Vector3(cos(a) * 0.2, y, sin(a) * 0.2)
		var tip := o + Vector3(cos(a), rng.randf_range(-0.25, 0.1), sin(a)) * len
		var sd := Vector3(-sin(a), 0, cos(a)) * 0.035
		_tri(st, o - sd + Vector3(0, 0.04, 0), tip, o + sd + Vector3(0, 0.04, 0), bark_d, bark_d, bark_d)
		_tri(st, o + Vector3(0, -0.05, 0), tip, o + Vector3(0, 0.05, 0), bark_d, bark_d, bark_d)
	if not pine:
		var core := Color(0.012, 0.035, 0.025, 0.0)
		_cone(st, rng, height * 0.2, height * 0.99, height * 0.075, 0.0, 6, core, core, 0.0)
	var whorls := (11 + variant * 2) if not pine else 7
	for w in whorls:
		var f := float(w) / float(whorls - 1)
		var y := lerpf(height * crown0, height * 0.95, f)
		var length: float
		var droop: float
		if pine:
			length = height * 0.2 * sin(lerpf(0.5, PI * 0.93, f)) * rng.randf_range(0.8, 1.15)
			droop = lerpf(0.12, -0.25, f)
		else:
			length = lerpf(height * 0.28, height * 0.035, pow(f, 0.82)) * rng.randf_range(0.82, 1.1)
			droop = lerpf(0.55, 0.1, f)
		var count := (rng.randi_range(6, 8) if f < 0.5 else rng.randi_range(4, 6)) if not pine else rng.randi_range(4, 6)
		var off := rng.randf() * TAU
		for b in count:
			if rng.randf() < 0.07:
				continue     # a gap where a bough broke off
			var a := off + TAU * b / count + rng.randf_range(-0.25, 0.25)
			_bough(st, rng, y + rng.randf_range(-0.2, 0.2), a, length * rng.randf_range(0.72, 1.14), droop * rng.randf_range(0.8, 1.2), f)
	# the leader shoot at the very top
	var top := Vector3(0, height * 0.93, 0)
	var needle := Color(0.04, 0.11, 0.07, 0.6)
	for i in 3:
		var a := i * TAU / 3.0
		var sd := Vector3(cos(a), 0, sin(a)) * 0.16
		_tri(st, top - sd, top + Vector3(0, height * 0.09, 0), top + sd, needle, needle, needle)
	st.generate_normals()
	return st.commit()


func _bough(st: SurfaceTool, rng: RandomNumberGenerator, y: float, a: float, length: float, droop: float, f: float) -> void:
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a))
	var o := Vector3(0, y, 0)
	# spine: sags under the snow, the tip lifts again
	var p: Array[Vector3] = [
		o + dir * 0.08,
		o + dir * length * 0.38 - Vector3(0, length * droop * 0.38, 0),
		o + dir * length * 0.74 - Vector3(0, length * droop * 0.86, 0),
		o + dir * length - Vector3(0, length * droop * 0.92, 0),
	]
	var w: Array[float] = [length * 0.1, length * 0.3, length * 0.23, 0.0]
	var c_in := Color(0.02, 0.06, 0.04, 0.8)
	var c_ridge := Color(0.035, 0.10, 0.065, 1.0)
	var c_edge := Color(0.05, 0.13, 0.08, 0.0)
	var c_tip := Color(0.05, 0.13, 0.08, 0.45)
	_fringe = true
	for i in 3:
		var l0 := p[i] - side * w[i] - Vector3(0, w[i] * 0.42, 0)
		var r0 := p[i] + side * w[i] - Vector3(0, w[i] * 0.42, 0)
		var ca := c_in if i == 0 else c_ridge
		if i < 2:
			var l1 := p[i + 1] - side * w[i + 1] - Vector3(0, w[i + 1] * 0.42, 0)
			var r1 := p[i + 1] + side * w[i + 1] - Vector3(0, w[i + 1] * 0.42, 0)
			_quad(st, p[i], p[i + 1], l1, l0, ca, c_ridge, c_edge, c_edge)
			_quad(st, p[i], r0, r1, p[i + 1], ca, c_edge, c_edge, c_ridge)
			# side twigs reaching out and forward
			if i == 0 or f < 0.8:
				for sgn in [-1.0, 1.0]:
					var sg: float = sgn
					var e0 := (l0 if sg < 0.0 else r0).lerp(l1 if sg < 0.0 else r1, 0.35)
					var e1 := (l0 if sg < 0.0 else r0).lerp(l1 if sg < 0.0 else r1, 0.95)
					var tip := e0.lerp(e1, 0.6) + side * sg * length * rng.randf_range(0.14, 0.24) + dir * length * 0.12 - Vector3(0, length * 0.07, 0)
					if sg < 0.0:
						_tri(st, e0, e1, tip, c_edge, c_edge, c_tip)
					else:
						_tri(st, e0, tip, e1, c_edge, c_tip, c_edge)
		else:
			_tri(st, p[i], p[i + 1], l0, c_ridge, c_tip, c_edge)
			_tri(st, p[i], r0, p[i + 1], c_ridge, c_edge, c_tip)
	_fringe = false
	# the snow load: a ridge of snow heaped along the bough, ragged at the rim
	if length > 0.9:
		var top := Color(0.05, 0.12, 0.08, 1.0)
		var rim := Color(0.05, 0.12, 0.08, 0.55)
		var lift := Vector3(0, 0.04 + length * 0.05, 0)
		var c0 := p[0].lerp(p[1], 0.3) + lift * 0.6
		var c1 := p[1] + lift
		var c2 := p[2] + lift * 0.8
		var c3 := p[2].lerp(p[3], 0.55) + lift * 0.3
		var s0 := side * w[1] * 0.25
		var s1 := side * w[1] * 0.5
		var s2 := side * w[2] * 0.5
		var dn := Vector3(0, length * 0.075, 0)
		_fringe = true
		for sgn in [-1.0, 1.0]:
			var sg: float = sgn
			if sg < 0.0:
				_quad(st, c0, c1, c1 + s1 * sg - dn, c0 + s0 * sg - dn, top, top, rim, rim)
				_quad(st, c1, c2, c2 + s2 * sg - dn, c1 + s1 * sg - dn, top, top, rim, rim)
				_tri(st, c2, c3, c2 + s2 * sg - dn, top, rim, rim)
			else:
				_quad(st, c0, c0 + s0 * sg - dn, c1 + s1 * sg - dn, c1, top, rim, rim, top)
				_quad(st, c1, c1 + s1 * sg - dn, c2 + s2 * sg - dn, c2, top, rim, rim, top)
				_tri(st, c2, c2 + s2 * sg - dn, c3, top, rim, rim)
		_fringe = false


## Far tree: stacked skirts.
func _make_lod(rng: RandomNumberGenerator, variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := 11.0 + variant * 2.0
	var bark := Color(0.13, 0.085, 0.06, 0.0)
	_cone(st, rng, 0.0, height * 0.5, 0.3, 0.12, 5, bark, bark, 0.0)
	var tiers := 5 + variant
	var low := Color(0.03, 0.085, 0.055, 0.0)
	var high := Color(0.04, 0.11, 0.07, 1.0)
	if variant == 3:
		height = 14.0
		_cone(st, rng, height * 0.4, height * 0.9, 0.2, 0.05, 5, bark, bark, 0.0)
		for t in 3:
			var f := t / 3.0
			var y0 := lerpf(height * 0.56, height * 0.84, f)
			_cone(st, rng, y0, y0 + height * 0.16, height * 0.2 * sin(lerpf(0.9, 2.6, f)), 0.0, 8, low, high, 0.25)
		st.generate_normals()
		return st.commit()
	for t in tiers:
		var f := float(t) / float(tiers)
		var y0 := lerpf(height * 0.10, height * 0.82, f)
		var y1 := y0 + height * lerpf(0.30, 0.18, f)
		var r := lerpf(height * 0.25, height * 0.06, f) * rng.randf_range(0.9, 1.1)
		_cone(st, rng, y0, y1, r, 0.0, 8, low, high, 0.22)
	st.generate_normals()
	return st.commit()


## A skirt from radius r0 at y0 up to radius r1 at y1, with a ragged lower rim.
func _cone(st: SurfaceTool, rng: RandomNumberGenerator, y0: float, y1: float, r0: float,
		r1: float, sides: int, col_low: Color, col_high: Color, jitter: float) -> void:
	var rim: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var rr := r0 * (1.0 + rng.randf_range(-jitter, jitter))
		rim.append(Vector3(cos(a) * rr, y0 - rng.randf() * jitter * r0, sin(a) * rr))
	for i in sides:
		var j := (i + 1) % sides
		var a0 := TAU * i / sides
		var a1 := TAU * j / sides
		var t0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var m0 := rim[i].lerp(t0, 0.45)
		var m1 := rim[j].lerp(t1, 0.45)
		var mc := col_low.lerp(col_high, 0.75)
		_quad(st, rim[i], rim[j], m1, m0, col_low, col_low, mc, mc)
		_quad(st, m0, m1, t1, t0, mc, mc, col_high, col_high)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	st.set_uv(Vector2(1.0 - ca.a if _fringe else 0.0, 0)); st.set_color(ca); st.add_vertex(a)
	st.set_uv(Vector2(1.0 - cc.a if _fringe else 0.0, 0)); st.set_color(cc); st.add_vertex(c)
	st.set_uv(Vector2(1.0 - cb.a if _fringe else 0.0, 0)); st.set_color(cb); st.add_vertex(b)
	st.set_uv(Vector2(1.0 - ca.a if _fringe else 0.0, 0)); st.set_color(ca); st.add_vertex(a)
	st.set_uv(Vector2(1.0 - cd.a if _fringe else 0.0, 0)); st.set_color(cd); st.add_vertex(d)
	st.set_uv(Vector2(1.0 - cc.a if _fringe else 0.0, 0)); st.set_color(cc); st.add_vertex(c)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_uv(Vector2(1.0 - ca.a if _fringe else 0.0, 0)); st.set_color(ca); st.add_vertex(a)
	st.set_uv(Vector2(1.0 - cc.a if _fringe else 0.0, 0)); st.set_color(cc); st.add_vertex(c)
	st.set_uv(Vector2(1.0 - cb.a if _fringe else 0.0, 0)); st.set_color(cb); st.add_vertex(b)
