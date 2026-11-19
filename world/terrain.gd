class_name Terrain
extends Node3D
## The Polaris valley: a bowl of hills ringed by mountains, with a lake basin
## and a flat shelf for the Christmas village. Everything comes from noise.

const SIZE := 2048.0     # width of the world, west to east
const HALF := SIZE * 0.5
const DEPTH := 3072.0    # north to south: the Senke, the mountains, then the Vorland
const Z_MAX := -HALF + DEPTH
const CELL := 4.0
const N := 513          # samples west to east (also the length of one row)
const NZ := 769         # rows north to south
const CHUNK := 32       # quads per chunk side

const LAKE_POS := Vector2(-260.0, 220.0)
const LAKE_R := 230.0
const LAKE_LEVEL := 20.0
const VILLAGE_POS := Vector2(260.0, -160.0)
const VILLAGE_R := 150.0
const VILLAGE_H := 34.0
# the second valley, south of the tunnel: an oval basin
const SOUTH_POS := Vector2(0.0, 1400.0)
const SOUTH_RX := 1000.0
const SOUTH_RZ := 640.0
const SOUTH_FROM := 600.0       # nothing north of this line is touched by the second valley
const GORGE_X := 100.0          # the road out of the tunnel runs down a gorge along this line
const GORGE_Z0 := 596.0
const GORGE_Z1 := 1130.0
const GORGE_END_H := 40.0

var heights := PackedFloat32Array()
var natural := PackedFloat32Array()   # the ground before anything was dug or flattened
var roofed := PackedByteArray()       # 1 where a tunnel or cellar lies under the natural ground
var dug := PackedByteArray()          # 1 where a cutting was dug that stays open to the sky
var open_cells := {}                  # cell index -> true: a shaft, no ground over it
var road_mask := PackedByteArray()    # ROAD_N x ROAD_N, 255 on a road
const ROAD_N := 2048
const ROAD_NZ := 3072
var _gorge_top := 60.0
var material: ShaderMaterial

var _n_hills := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_crag := FastNoiseLite.new()
var _n_band := FastNoiseLite.new()


func build(mat: ShaderMaterial) -> void:
	prepare(mat)
	build_mesh()


func _setup_noise() -> void:
	_n_hills.seed = 11
	_n_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_hills.frequency = 1.0 / 520.0
	_n_hills.fractal_octaves = 4
	_n_ridge.seed = 23
	_n_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_ridge.frequency = 1.0 / 420.0
	_n_ridge.fractal_octaves = 5
	_n_detail.seed = 37
	_n_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_n_detail.frequency = 1.0 / 45.0
	_n_detail.fractal_octaves = 3

	_n_crag.seed = 51
	_n_crag.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_n_crag.frequency = 1.0 / 95.0
	_n_crag.fractal_octaves = 2
	_n_band.seed = 67
	_n_band.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n_band.frequency = 1.0 / 300.0
	_gorge_top = _north_height(GORGE_X, 512.0)


## Step 1: the natural ground. After this, places may flatten, cut roads and dig.
func prepare(mat: ShaderMaterial) -> void:
	material = mat
	_setup_noise()
	heights.resize(N * NZ)
	for j in NZ:
		var z := -HALF + j * CELL
		for i in N:
			heights[j * N + i] = _raw_height(-HALF + i * CELL, z)
	natural = heights.duplicate()
	roofed.resize(N * NZ)
	roofed.fill(0)
	dug.resize(N * NZ)
	dug.fill(0)
	road_mask.resize(ROAD_N * ROAD_NZ)
	road_mask.fill(0)
	open_cells.clear()


## Step 2: meshes and collision.
func build_mesh() -> void:
	var img := Image.create_from_data(ROAD_N, ROAD_NZ, false, Image.FORMAT_L8, road_mask)
	material.set_shader_parameter("road_tex", ImageTexture.create_from_image(img))
	ModelLib.terrain_textures(material)
	for cz in (NZ - 1) / CHUNK:
		for cx in (N - 1) / CHUNK:
			_build_chunk(cx, cz)

	_build_lid()

func _raw_height(x: float, z: float) -> float:
	var h := _north_height(x, z)
	if z <= SOUTH_FROM - 8.0:
		return h
	# the Vorland: wherever its basin lies lower than the Senke's mountains, it wins
	h = lerpf(h, minf(h, _south_height(x, z)), smoothstep(SOUTH_FROM, SOUTH_FROM + 100.0, z))
	# the gorge that carries the road from the tunnel's south portal down into it
	if z >= GORGE_Z0 and z < GORGE_Z1:
		var floor_h := lerpf(_gorge_top, GORGE_END_H, smoothstep(GORGE_Z0 + 4.0, GORGE_Z1 - 60.0, z))
		if floor_h < h:
			var w := 1.0 - smoothstep(10.0, 52.0, absf(x - gorge_x(z)))
			w *= 1.0 - smoothstep(GORGE_Z1 - 70.0, GORGE_Z1, z)
			h = lerpf(h, floor_h, w)
	return h


## Where the middle of the gorge lies at a given z: it swings a little from side to side.
static func gorge_x(z: float) -> float:
	return GORGE_X + 26.0 * sin((z - GORGE_Z0) / 110.0) * smoothstep(GORGE_Z0, GORGE_Z0 + 60.0, z)


func _south_height(x: float, z: float) -> float:
	var d := Vector2(x / SOUTH_RX, (z - SOUTH_POS.y) / SOUTH_RZ).length()
	var ring := smoothstep(0.58, 1.0, d)
	var hills := _n_hills.get_noise_2d(x + 3000.0, z) * 22.0 + 38.0
	var ridge := 1.0 - absf(_n_ridge.get_noise_2d(x + 3000.0, z))
	ridge *= ridge
	var h := hills + ring * ridge * 300.0 + ring * ring * 120.0
	h += _n_detail.get_noise_2d(x, z) * 2.2 * (0.35 + ring * 2.0)
	var crag := 1.0 - absf(_n_crag.get_noise_2d(x, z))
	h += ring * (crag * crag * 34.0 - 12.0)
	return h


func _north_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length() / HALF
	var ring := smoothstep(0.42, 0.95, d)
	var hills := _n_hills.get_noise_2d(x, z) * 30.0 + 48.0
	var ridge := 1.0 - absf(_n_ridge.get_noise_2d(x, z))
	ridge *= ridge
	var h := hills + ring * ridge * 310.0 + ring * ring * 110.0
	h += _n_detail.get_noise_2d(x, z) * 2.2 * (0.35 + ring * 2.0)
	# the mountains get sharp side ridges, gullies and bands of cliff with ledges between
	var crag := 1.0 - absf(_n_crag.get_noise_2d(x, z))
	h += ring * (crag * crag * 34.0 - 12.0)
	var step := 46.0
	var hm := (h + _n_band.get_noise_2d(x, z) * 30.0) / step
	var fr := hm - floorf(hm)
	var shelf := (smoothstep(0.18, 0.62, fr) - fr) * step
	h += shelf * ring * 0.62 * smoothstep(-0.25, 0.25, _n_band.get_noise_2d(z + 400.0, x))
	var dl := p.distance_to(LAKE_POS)
	var tl := smoothstep(LAKE_R * 1.5, LAKE_R * 0.75, dl)
	h = lerpf(h, LAKE_LEVEL - 7.0 + (dl / LAKE_R) * 6.0, tl)
	var dv := p.distance_to(VILLAGE_POS)
	var tv := smoothstep(VILLAGE_R * 1.6, VILLAGE_R * 0.9, dv)
	h = lerpf(h, VILLAGE_H, tv)
	return h


## Height for shading: ground that hides a tunnel counts as untouched.
func _hn(i: int, j: int) -> float:
	var key := clampi(j, 0, NZ - 1) * N + clampi(i, 0, N - 1)
	return natural[key] if roofed[key] == 1 else heights[key]


func _h(i: int, j: int) -> float:
	return heights[clampi(j, 0, NZ - 1) * N + clampi(i, 0, N - 1)]


## Height of the ground at a world position (bilinear).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, NZ - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(heights[j * N + i], heights[j * N + i + 1], tx)
	var b := lerpf(heights[(j + 1) * N + i], heights[(j + 1) * N + i + 1], tx)
	return lerpf(a, b, tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e,
			height_at(x, z - e) - height_at(x, z + e)).normalized()


## Ground or lake ice, whichever is on top.
func surface_at(x: float, z: float) -> float:
	return maxf(height_at(x, z), LAKE_LEVEL)


func on_lake(x: float, z: float) -> bool:
	return height_at(x, z) < LAKE_LEVEL


func _build_chunk(cx: int, cz: int) -> void:
	var vc := CHUNK + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tans := PackedFloat32Array()
	var idx := PackedInt32Array()
	verts.resize(vc * vc)
	norms.resize(vc * vc)
	uvs.resize(vc * vc)
	tans.resize(vc * vc * 4)
	idx.resize(CHUNK * CHUNK * 6)
	var k := 0
	for j in vc:
		var gj := cz * CHUNK + j
		for i in vc:
			var gi := cx * CHUNK + i
			var x := -HALF + gi * CELL
			var z := -HALF + gj * CELL
			verts[k] = Vector3(x, heights[gj * N + gi], z)
			norms[k] = Vector3(_hn(gi - 1, gj) - _hn(gi + 1, gj), 2.0 * CELL,
					_hn(gi, gj - 1) - _hn(gi, gj + 1)).normalized()
			uvs[k] = Vector2(x, z) / SIZE
			tans[k * 4] = 1.0
			tans[k * 4 + 1] = 0.0
			tans[k * 4 + 2] = 0.0
			tans[k * 4 + 3] = 1.0
			k += 1
	var faces := PackedVector3Array()
	faces.resize(CHUNK * CHUNK * 6)
	k = 0
	for j in CHUNK:
		for i in CHUNK:
			var a := j * vc + i
			var b := a + 1
			var c := a + vc
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			faces[k] = verts[a]; faces[k + 1] = verts[b]; faces[k + 2] = verts[c]
			faces[k + 3] = verts[b]; faces[k + 4] = verts[d]; faces[k + 5] = verts[c]
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("surface", "snow")
	add_child(body)


# ---------------------------------------------------------------- shaping the ground

func gi(x: float) -> int:
	return clampi(int(round((x + HALF) / CELL)), 0, N - 1)


## Row of the grid for a z position.
func gj(z: float) -> int:
	return clampi(int(round((z + HALF) / CELL)), 0, NZ - 1)


func gx(i: int) -> float:
	return -HALF + i * CELL


## Levels a rectangle (turned by yaw) to height h, with a soft edge of `blend` metres.
func flatten(c: Vector2, half: Vector2, yaw: float, h: float, blend := 10.0) -> void:
	var reach := half.length() + blend
	var ca := cos(yaw)
	var sa := sin(yaw)
	for j in range(gj(c.y - reach), gj(c.y + reach) + 1):
		for i in range(gi(c.x - reach), gi(c.x + reach) + 1):
			var d := Vector2(gx(i), gx(j)) - c
			var l := Vector2(d.x * ca - d.y * sa, d.x * sa + d.y * ca)
			var out := maxf(absf(l.x) - half.x, absf(l.y) - half.y)
			var w := 1.0 - smoothstep(0.0, blend, out)
			if w > 0.0:
				heights[j * N + i] = lerpf(heights[j * N + i], h, w)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


## A road along the points: the ground is evened out along it and marked for the shader.
## Returns the centre line with heights, one point every 4 m.
func road(pts: PackedVector2Array, half_w := 3.6, blend := 7.0) -> PackedVector3Array:
	var line := PackedVector2Array()
	for s in pts.size() - 1:
		var n := maxi(int(pts[s].distance_to(pts[s + 1]) / 4.0), 1)
		for q in n:
			line.append(pts[s].lerp(pts[s + 1], float(q) / n))
	line.append(pts[pts.size() - 1])
	# round the corners, then smooth the grade
	for pass_i in 3:
		var sm := line.duplicate()
		for q in range(1, line.size() - 1):
			sm[q] = (line[q - 1] + line[q] * 2.0 + line[q + 1]) * 0.25
		line = sm
	var hs := PackedFloat32Array()
	for p in line:
		hs.append(height_at(p.x, p.y))
	for pass_i in 10:
		var sm := hs.duplicate()
		for q in range(1, hs.size() - 1):
			sm[q] = (hs[q - 1] + hs[q] * 2.0 + hs[q + 1]) * 0.25
		hs = sm
	var reach := half_w + blend
	var best_d := {}
	var best_h := {}
	for q in line.size() - 1:
		var a := line[q]
		var b := line[q + 1]
		for j in range(gj(minf(a.y, b.y) - reach), gj(maxf(a.y, b.y) + reach) + 1):
			for i in range(gi(minf(a.x, b.x) - reach), gi(maxf(a.x, b.x) + reach) + 1):
				var r := _seg_dist(Vector2(gx(i), gx(j)), a, b)
				var key := j * N + i
				if r.x < reach and r.x < float(best_d.get(key, 1e9)):
					best_d[key] = r.x
					best_h[key] = lerpf(hs[q], hs[q + 1], r.y)
		# the mask is finer than the ground
		var m0 := Vector2(minf(a.x, b.x) - half_w - 2.0, minf(a.y, b.y) - half_w - 2.0)
		var m1 := Vector2(maxf(a.x, b.x) + half_w + 2.0, maxf(a.y, b.y) + half_w + 2.0)
		var sc := ROAD_N / SIZE
		for mj in range(clampi(int((m0.y + HALF) * sc), 0, ROAD_NZ - 1), clampi(int((m1.y + HALF) * sc) + 1, 0, ROAD_NZ - 1) + 1):
			for mi in range(clampi(int((m0.x + HALF) * sc), 0, ROAD_N - 1), clampi(int((m1.x + HALF) * sc) + 1, 0, ROAD_N - 1) + 1):
				var mp := Vector2((mi + 0.5) / sc - HALF, (mj + 0.5) / sc - HALF)
				var md := _seg_dist(mp, a, b).x
				var v := int(255.0 * (1.0 - smoothstep(half_w - 1.0, half_w + 1.2, md)))
				if v > road_mask[mj * ROAD_N + mi]:
					road_mask[mj * ROAD_N + mi] = v
	for key in best_d:
		var w := 1.0 - smoothstep(half_w, reach, float(best_d[key]))
		heights[key] = lerpf(heights[key], float(best_h[key]), w)
	var out := PackedVector3Array()
	for q in line.size():
		out.append(Vector3(line[q].x, hs[q], line[q].y))
	return out


## Marks a round patch as driven-on ground (a square, a yard) without moving any earth.
func pave(c: Vector2, r: float) -> void:
	var sc := ROAD_N / SIZE
	for mj in range(clampi(int((c.y - r - 2.0 + HALF) * sc), 0, ROAD_NZ - 1), clampi(int((c.y + r + 2.0 + HALF) * sc) + 1, 0, ROAD_NZ - 1) + 1):
		for mi in range(clampi(int((c.x - r - 2.0 + HALF) * sc), 0, ROAD_N - 1), clampi(int((c.x + r + 2.0 + HALF) * sc) + 1, 0, ROAD_N - 1) + 1):
			var mp := Vector2((mi + 0.5) / sc - HALF, (mj + 0.5) / sc - HALF)
			var v := int(255.0 * (1.0 - smoothstep(r - 1.0, r + 1.2, mp.distance_to(c))))
			if v > road_mask[mj * ROAD_N + mi]:
				road_mask[mj * ROAD_N + mi] = v


func on_road(x: float, z: float) -> bool:
	var sc := ROAD_N / SIZE
	var mi := clampi(int((x + HALF) * sc), 0, ROAD_N - 1)
	var mj := clampi(int((z + HALF) * sc), 0, ROAD_NZ - 1)
	return road_mask[mj * ROAD_N + mi] > 110


## Cuts a ravine along the points: `depth` metres deep, `half_w` wide at the bottom.
func gorge(pts: PackedVector2Array, half_w: float, depth: float, wall := 9.0) -> void:
	var reach := half_w + wall
	var best := {}
	for q in pts.size() - 1:
		var a := pts[q]
		var b := pts[q + 1]
		for j in range(gj(minf(a.y, b.y) - reach), gj(maxf(a.y, b.y) + reach) + 1):
			for i in range(gi(minf(a.x, b.x) - reach), gi(maxf(a.x, b.x) + reach) + 1):
				var d := _seg_dist(Vector2(gx(i), gx(j)), a, b).x
				var key := j * N + i
				if d < reach and d < float(best.get(key, 1e9)):
					best[key] = d
	for key in best:
		var w := 1.0 - smoothstep(half_w, reach, float(best[key]))
		heights[key] -= depth * w


## Digs a level room or tunnel between grid points (inclusive). Where enough ground
## lies above, the natural surface stays as a lid over it.
## `need` is how much ground must lie above the floor for the roof to stay.
## Returns how many points ended up open to the sky.
func dig(i0: int, j0: int, i1: int, j1: int, floor_h: float, need := 3.3) -> int:
	var open := 0
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var key := j * N + i
			if natural[key] - floor_h > need:
				roofed[key] = 1
			elif roofed[key] == 0:
				dug[key] = 1
				open += 1
			# under a roof the ground lies a little below the built floor, so the two never fight
			var to := floor_h - 0.2 if roofed[key] == 1 else floor_h
			if heights[key] > to:
				heights[key] = to
	return open


## Call after flattening and road building, before digging: this is now "the ground".
func settle() -> void:
	natural = heights.duplicate()


func open_cell(i: int, j: int) -> void:
	open_cells[j * N + i] = true


## True where the natural ground hides something dug out below.
func is_dug(x: float, z: float) -> bool:
	var i := clampi(int((x + HALF) / CELL), 0, N - 2)
	var j := clampi(int((z + HALF) / CELL), 0, NZ - 2)
	var n := 0
	for o in [0, 1, N, N + 1]:
		n += roofed[j * N + i + o] + dug[j * N + i + o]
	return n > 0


## Height of the untouched ground (the lid over tunnels).
func natural_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, NZ - 1.001)
	var i := int(fx)
	var j := int(fz)
	var a := lerpf(natural[j * N + i], natural[j * N + i + 1], fx - i)
	var b := lerpf(natural[(j + 1) * N + i], natural[(j + 1) * N + i + 1], fx - i)
	return lerpf(a, b, fz - j)


func _nat(i: int, j: int) -> float:
	return natural[clampi(j, 0, NZ - 1) * N + clampi(i, 0, N - 1)]


func _build_lid() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for j in NZ - 1:
		for i in N - 1:
			if roofed[j * N + i] + roofed[j * N + i + 1] + roofed[(j + 1) * N + i] + roofed[(j + 1) * N + i + 1] == 0:
				continue
			if open_cells.has(j * N + i):
				continue
			var cut := 0
			for o in [0, 1, N, N + 1]:
				var kk: int = j * N + i + o
				if dug[kk] == 1 and roofed[kk] == 0:
					cut += 1
			if cut > 0:
				continue    # the mouth of a cutting stays open
			var vs: Array[Vector3] = []
			var ns: Array[Vector3] = []
			for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ii: int = i + o.x
				var jj: int = j + o.y
				vs.append(Vector3(gx(ii), natural[jj * N + ii], gx(jj)))
				ns.append(Vector3(_nat(ii - 1, jj) - _nat(ii + 1, jj), 2.0 * CELL, _nat(ii, jj - 1) - _nat(ii, jj + 1)).normalized())
			for q in [0, 1, 2, 1, 3, 2]:
				st.set_normal(ns[q])
				st.set_uv(Vector2(vs[q].x, vs[q].z) / SIZE)
				st.set_tangent(Plane(1, 0, 0, 1))
				st.add_vertex(vs[q])
				faces.append(vs[q])
	if faces.is_empty():
		return
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("surface", "snow")
	add_child(body)
