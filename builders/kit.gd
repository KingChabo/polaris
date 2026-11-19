class_name MeshKit
extends RefCounted
## Small modelling toolkit: add boxes, cylinders, spheres and quads with named
## materials, then turn the result into one mesh (plus collision).

var xf := Transform3D.IDENTITY
var _tools := {}
var _models := {}          # scanned model meshes placed in this kit: mesh -> Array[Transform3D]
var winter := false        # keep snow and ice even in summer (the lake, the horror valley)
const WINTER_ONLY := ["snow", "ice"]


func _st(mat: String) -> SurfaceTool:
	if not _tools.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat] = st
	return _tools[mat]


func _v(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal((xf.basis * n).normalized())
	st.add_vertex(xf * p)


## Triangle, corners counter-clockwise when seen from outside.
func tri(a: Vector3, b: Vector3, c: Vector3, mat: String) -> void:
	var n := (b - a).cross(c - a).normalized()
	var st := _st(mat)
	_v(st, a, n); _v(st, c, n); _v(st, b, n)


## Quad, corners counter-clockwise when seen from outside.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: String) -> void:
	var n := (b - a).cross(d - a).normalized()
	quad_n(a, b, c, d, n, n, n, n, mat)


func quad_n(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, mat: String) -> void:
	var st := _st(mat)
	_v(st, a, na); _v(st, c, nc); _v(st, b, nb)
	_v(st, a, na); _v(st, d, nd); _v(st, c, nc)


func box(center: Vector3, size: Vector3, mat: String, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var ax: Array[Vector3] = [basis.x, basis.y, basis.z]
	for f in [[0, 1, 1, 2], [0, -1, 2, 1], [1, 1, 2, 0], [1, -1, 0, 2], [2, 1, 0, 1], [2, -1, 1, 0]]:
		var ni: int = f[0]
		var s: float = f[1]
		var ui: int = f[2]
		var vi: int = f[3]
		var n := ax[ni] * s * h[ni]
		var u := ax[ui] * h[ui]
		var v := ax[vi] * h[vi]
		var c := center + n
		quad(c - u - v, c + u - v, c + u + v, c - u + v, mat)


## Vertical cylinder or cone standing on `base`. r1 is the top radius.
func cyl(base: Vector3, r0: float, h: float, mat: String, sides := 10, r1 := -1.0, caps := true) -> void:
	if r1 < 0.0:
		r1 = r0
	var top := base + Vector3.UP * h
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := base + d0 * r0
		var p1 := base + d1 * r0
		var q0 := top + d0 * r1
		var q1 := top + d1 * r1
		quad_n(p1, p0, q0, q1, d1, d0, d0, d1, mat)
		if caps and r1 > 0.001:
			tri(top, q1, q0, mat)
		if caps and r0 > 0.001:
			tri(base, p0, p1, mat)


func sphere(center: Vector3, r: float, mat: String, sides := 10, rings := 6, squash := 1.0) -> void:
	for j in rings:
		var ph0 := PI * j / rings
		var ph1 := PI * (j + 1) / rings
		for i in sides:
			var t0 := TAU * i / sides
			var t1 := TAU * (i + 1) / sides
			var u0 := Vector3(sin(ph0) * cos(t0), cos(ph0), sin(ph0) * sin(t0))
			var u1 := Vector3(sin(ph0) * cos(t1), cos(ph0), sin(ph0) * sin(t1))
			var l0 := Vector3(sin(ph1) * cos(t0), cos(ph1), sin(ph1) * sin(t0))
			var l1 := Vector3(sin(ph1) * cos(t1), cos(ph1), sin(ph1) * sin(t1))
			var sc := Vector3(r, r * squash, r)
			quad_n(center + l1 * sc, center + l0 * sc, center + u0 * sc, center + u1 * sc, l1, l0, u0, u1, mat)


## Round bar from `a` to `b` with smooth sides. r1 is the radius at `b`.
func tube(a: Vector3, b: Vector3, r0: float, mat: String, sides := 10, r1 := -1.0, caps := true) -> void:
	if r1 < 0.0:
		r1 = r0
	var axis := b - a
	var length := axis.length()
	if length < 0.0001:
		return
	var y := axis / length
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	var slope := (r0 - r1) / length
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := x * cos(a0) + z * sin(a0)
		var d1 := x * cos(a1) + z * sin(a1)
		quad_n(a + d1 * r0, a + d0 * r0, b + d0 * r1, b + d1 * r1,
				d1 + y * slope, d0 + y * slope, d0 + y * slope, d1 + y * slope, mat)
		if caps and r1 > 0.001:
			tri(b, b + d1 * r1, b + d0 * r1, mat)
		if caps and r0 > 0.001:
			tri(a, a + d0 * r0, a + d1 * r0, mat)


## Egg shape: a sphere with its own radius on every axis, turned by `basis`.
func ball(center: Vector3, radii: Vector3, mat: String, sides := 12, rings := 7, basis := Basis.IDENTITY) -> void:
	for j in rings:
		var ph0 := PI * j / rings
		var ph1 := PI * (j + 1) / rings
		for i in sides:
			var t0 := TAU * i / sides
			var t1 := TAU * (i + 1) / sides
			var pts: Array[Vector3] = []
			var nrm: Array[Vector3] = []
			for q in [[ph1, t1], [ph1, t0], [ph0, t0], [ph0, t1]]:
				var ph: float = q[0]
				var th: float = q[1]
				var u := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
				pts.append(center + basis * (u * radii))
				nrm.append((basis * (u / radii)).normalized())
			quad_n(pts[0], pts[1], pts[2], pts[3], nrm[0], nrm[1], nrm[2], nrm[3], mat)


## Sausage: a tube with round ends.
func capsule(a: Vector3, b: Vector3, r: float, mat: String, sides := 10, r1 := -1.0) -> void:
	if r1 < 0.0:
		r1 = r
	tube(a, b, r, mat, sides, r1, false)
	ball(a, Vector3.ONE * r, mat, sides, 6)
	ball(b, Vector3.ONE * r1, mat, sides, 6)


## Triangle that faces `out`, whatever order the corners come in. Flat shaded.
func tri_o(a: Vector3, b: Vector3, c: Vector3, out: Vector3, mat: String) -> void:
	if (b - a).cross(c - a).dot(out) < 0.0:
		tri(a, c, b, mat)
	else:
		tri(a, b, c, mat)


func quad_o(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, mat: String) -> void:
	tri_o(a, b, c, out, mat)
	tri_o(a, c, d, out, mat)


## Box with its edges cut off, so it catches the light like a real moulded part.
func bbox(center: Vector3, size: Vector3, bevel: float, mat: String, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var bv := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var ax: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var j := (i + 1) % 3
		var l := (i + 2) % 3
		# two faces, pulled in by the bevel
		for s in [-1.0, 1.0]:
			var sg: float = s
			var n := basis * (ax[i] * sg)
			var c := center + n * h[i]
			var u := basis * ax[j] * (h[j] - bv)
			var v := basis * ax[l] * (h[l] - bv)
			quad_o(c - u - v, c + u - v, c + u + v, c - u + v, n, mat)
		# four cut edges that run along this axis
		for sj in [-1.0, 1.0]:
			for sl in [-1.0, 1.0]:
				var a: float = sj
				var b: float = sl
				var along := basis * ax[i] * (h[i] - bv)
				var p0 := center + basis * (ax[j] * a * h[j] + ax[l] * b * (h[l] - bv))
				var p1 := center + basis * (ax[j] * a * (h[j] - bv) + ax[l] * b * h[l])
				quad_o(p0 - along, p0 + along, p1 + along, p1 - along, basis * (ax[j] * a + ax[l] * b), mat)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var x: float = sx
				var y: float = sy
				var z: float = sz
				tri_o(center + basis * Vector3(x * h.x, y * (h.y - bv), z * (h.z - bv)),
						center + basis * Vector3(x * (h.x - bv), y * h.y, z * (h.z - bv)),
						center + basis * Vector3(x * (h.x - bv), y * (h.y - bv), z * h.z), basis * Vector3(x, y, z), mat)


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var drop := GameMode.summer() and not winter
	for mat in _tools:
		if drop and mat in WINTER_ONLY:
			continue          # summer: no snow piles, no snow on roofs and cars, no icicles
		var st: SurfaceTool = _tools[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat(mat))
	return mesh


## Places a scanned model from Blender (`ModelLib`) at `at` (in the kit's frame), `height` tall.
## Returns false when the model is missing, so the caller can build its own shape instead.
func model(id: String, at: Vector3, height: float, yaw := 0.0, snow := 0.6) -> bool:
	var m := ModelLib.mesh(id, "", height, snow)
	if m == null:
		return false
	if not _models.has(m):
		_models[m] = []
	(_models[m] as Array).append(xf * Transform3D(Basis(Vector3.UP, yaw), at))
	return true


## Finished model as a node. With `collide` it also gets a solid body.
func node(collide := true) -> Node3D:
	var root := Node3D.new()
	var mesh := commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	if collide and mesh.get_surface_count() > 0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		root.add_child(body)
	for m: ArrayMesh in _models:
		var list: Array = _models[m]
		# small cells, each only drawn near the camera (scans are heavy)
		var cells := {}
		for t: Transform3D in list:
			var key := Vector2i(int(floor(t.origin.x / 20.0)), int(floor(t.origin.z / 20.0)))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(t)
		for key in cells:
			var cl: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m
			mm.instance_count = cl.size()
			for i in cl.size():
				mm.set_instance_transform(i, cl[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 75.0
			mmi.visibility_range_end_margin = 5.0
			root.add_child(mmi)
		if collide:
			var bb := m.get_aabb()
			var body := StaticBody3D.new()
			root.add_child(body)
			var shape := BoxShape3D.new()
			shape.size = bb.size * 0.92
			for t: Transform3D in list:
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.transform = t * Transform3D(Basis(), bb.get_center())
				body.add_child(cs)
	return root
