class_name Grass
extends Node3D
## Summer only: tufts of grass and meadow flowers in square patches around the camera.
## Patches are made when the camera comes near and dropped when it leaves, so only a few
## hundred thousand blades exist at any time. No grass on roads, water, steep ground,
## house plots, cleared sites, or above the alpine turf.

const CELL := 12.0
const RADIUS := 3             # patches in each direction (about 40 m)
const PER_CELL := 520         # tufts in a full patch
const FLOWERS_PER_CELL := 170
const MAKE_PER_FRAME := 2

var terrain: Terrain
var village: Village
var noise_tex: Texture2D

var _cells := {}              # Vector2i -> Node3D
var _tuft: ArrayMesh
var _flower: ArrayMesh
var _grass_mat: ShaderMaterial
var _flower_mat: ShaderMaterial
var _mask := FastNoiseLite.new()
var _plots: Array = []        # [inverse transform, half size] of every house, a metre bigger


func _ready() -> void:
	_mask.seed = 911
	_mask.frequency = 1.0 / 38.0
	_mask.fractal_octaves = 2
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = load("res://world/grass.gdshader")
	_grass_mat.set_shader_parameter("noise_tex", noise_tex)
	_flower_mat = _grass_mat.duplicate()
	_flower_mat.set_shader_parameter("flower", true)
	_tuft = _make_tuft()
	_tuft.surface_set_material(0, _grass_mat)
	_flower = _make_flower()
	_flower.surface_set_material(0, _flower_mat)
	if village:
		for h in village.houses:
			var s: Vector2 = h.get_meta("size")
			_plots.append([(h as Node3D).global_transform.affine_inverse(), s * 0.5 + Vector2(1.2, 1.2)])


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var cc := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	# drop patches that fell behind
	for key in _cells.keys():
		var k: Vector2i = key
		if absi(k.x - cc.x) > RADIUS + 1 or absi(k.y - cc.y) > RADIUS + 1:
			(_cells[k] as Node3D).queue_free()
			_cells.erase(k)
	# make the missing ones, nearest first, a few per frame
	var made := 0
	for ring in RADIUS + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var k := cc + Vector2i(dx, dz)
				if _cells.has(k):
					continue
				_cells[k] = _make_cell(k)
				made += 1
				if made >= MAKE_PER_FRAME:
					return


## Fills the whole circle at once (picture runs, teleports).
func fill_now() -> void:
	for i in 40:
		_process(0.0)


func _make_cell(k: Vector2i) -> Node3D:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var o := Vector2(k.x * CELL, k.y * CELL)
	var tufts: Array = []
	var flowers: Array = []
	for i in PER_CELL + FLOWERS_PER_CELL:
		var x := o.x + rng.randf() * CELL
		var z := o.y + rng.randf() * CELL
		var is_flower := i >= PER_CELL
		var dens := _density(x, z)
		var m := _mask.get_noise_2d(x, z)
		if is_flower:
			dens *= smoothstep(-0.1, 0.35, m) * 1.8   # flowers grow in drifts
		if rng.randf() > dens:
			continue
		var h := terrain.height_at(x, z)
		var s := rng.randf_range(0.7, 1.25) * lerpf(0.75, 1.15, clampf(m * 0.5 + 0.5, 0.0, 1.0))
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, h - 0.04, z))
		if is_flower:
			var cols := [Color(0.95, 0.95, 0.92), Color(0.98, 0.82, 0.12), Color(0.55, 0.32, 0.78), Color(0.30, 0.45, 0.95), Color(0.92, 0.45, 0.62)]
			var c: Color = cols[rng.randi() % cols.size()] if rng.randf() < 0.85 else cols[0]
			c.a = rng.randf()
			flowers.append([t, c])
		else:
			var v := rng.randf_range(0.85, 1.15)
			var dry := smoothstep(0.3, 0.9, m) * rng.randf() * 0.35
			tufts.append([t, Color(v * (1.0 + dry * 0.6), v, v * (1.0 - dry), rng.randf())])
	_multi(node, _tuft, tufts)
	_multi(node, _flower, flowers)
	if OS.get_cmdline_user_args().has("--grassdebug"):
		print("grass cell %s: %d tufts %d flowers %.1f ms" % [k, tufts.size(), flowers.size(), (Time.get_ticks_usec() - t0) / 1000.0])
	return node


func _multi(node: Node3D, mesh: Mesh, list: Array) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_custom_data(i, list[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)


## 0..1: how thick the grass grows here.
func _density(x: float, z: float) -> float:
	var h := terrain.height_at(x, z)
	if h < Terrain.LAKE_LEVEL + 0.4 or h > 175.0:
		return 0.0
	if terrain.normal_at(x, z).y < 0.82 or terrain.on_road(x, z):
		return 0.0
	if Places.cleared(x, z) or Wilds.cleared(x, z):
		return 0.0
	var wp := Vector3(x, h, z)
	for pl in _plots:
		var l: Vector3 = (pl[0] as Transform3D) * wp
		var hs: Vector2 = pl[1]
		if absf(l.x) < hs.x and absf(l.z) < hs.y:
			return 0.0
	var d := 0.55 + 0.45 * _mask.get_noise_2d(x * 1.7, z * 1.7)
	return d * (1.0 - smoothstep(130.0, 175.0, h) * 0.8)


## One tuft: a dozen tapered, curved blades leaning out from the middle.
func _make_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 18:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var base := out * rng.randf_range(0.0, 0.16)
		var hgt := rng.randf_range(0.16, 0.46)
		var lean := rng.randf_range(0.05, 0.2)
		var w := rng.randf_range(0.005, 0.01)
		var pts: Array[Vector3] = []
		var segs := 3
		for s in segs + 1:
			var f := float(s) / segs
			pts.append(base + out * lean * f * f + Vector3(0, hgt * f, 0))
		for s in segs:
			var f0 := float(s) / segs
			var f1 := float(s + 1) / segs
			var w0 := w * (1.0 - f0 * 0.85)
			var w1 := w * (1.0 - f1 * 0.85) if s < segs - 1 else 0.0
			var nrm := (out * -0.4 + Vector3.UP).normalized()
			var a0 := pts[s] - side * w0
			var b0 := pts[s] + side * w0
			var a1 := pts[s + 1] - side * w1
			var b1 := pts[s + 1] + side * w1
			_v(st, a0, nrm, f0, 0.0); _v(st, b0, nrm, f0, 0.0); _v(st, b1, nrm, f1, 0.0)
			if w1 > 0.0:
				_v(st, a0, nrm, f0, 0.0); _v(st, b1, nrm, f1, 0.0); _v(st, a1, nrm, f1, 0.0)
	return st.commit()


## One meadow flower: a thin stalk, two leaves, five petals round a small heart.
func _make_flower() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.03, 0.42, 0.0)
	var up := Vector3.UP
	for i in 3:
		var a := TAU * i / 3.0
		var o := Vector3(cos(a), 0, sin(a)) * 0.006
		var o2 := Vector3(cos(a + TAU / 3.0), 0, sin(a + TAU / 3.0)) * 0.006
		_v(st, o, up, 0.0, 0.0); _v(st, o2, up, 0.0, 0.0); _v(st, top + o2, up, 0.9, 0.0)
		_v(st, o, up, 0.0, 0.0); _v(st, top + o2, up, 0.9, 0.0); _v(st, top + o, up, 0.9, 0.0)
	for side in [-1.0, 1.0]:
		var l0 := Vector3(0.004, 0.06 if side < 0.0 else 0.12, 0)
		_v(st, l0, up, 0.3, 0.0); _v(st, l0 + Vector3(side * 0.06, 0.05, 0.008), up, 0.6, 0.0); _v(st, l0 + Vector3(side * 0.012, 0.03, -0.004), up, 0.6, 0.0)
	# the head: eight rounded petals, a little tilted to the light, and a yellow heart
	var tilt := Basis(Vector3(0, 0, 1), 0.35)
	var petals := 8
	for i in petals:
		var a := TAU * i / petals
		var d := Vector3(cos(a), 0.1, sin(a))
		var sd := Vector3(-sin(a), 0, cos(a))
		var c := top + Vector3(0, 0.004, 0)
		var p1 := c + tilt * (d * 0.022 - sd * 0.012)
		var p2 := c + tilt * (d * 0.045 - sd * 0.012)
		var p3 := c + tilt * (d * 0.055)
		var p4 := c + tilt * (d * 0.045 + sd * 0.012)
		var p5 := c + tilt * (d * 0.022 + sd * 0.012)
		for tri in [[c, p1, p5], [p1, p2, p4], [p1, p4, p5], [p2, p3, p4]]:
			for q in tri:
				_v(st, q, up, 1.0, 1.0)
	for i in 5:
		var a := TAU * i / 5.0
		var a2 := TAU * (i + 1) / 5.0
		var c := top + Vector3(0, 0.01, 0)
		_v(st, c, up, 1.0, 0.3); _v(st, c + tilt * Vector3(cos(a), 0, sin(a)) * 0.012, up, 1.0, 0.3); _v(st, c + tilt * Vector3(cos(a2), 0, sin(a2)) * 0.012, up, 1.0, 0.3)
	return st.commit()


func _v(st: SurfaceTool, p: Vector3, n: Vector3, height: float, petal: float) -> void:
	st.set_color(Color(petal, 0.0, 0.0, height))
	st.set_normal(n)
	st.add_vertex(p)
