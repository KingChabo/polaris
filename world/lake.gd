class_name Lake
extends Node3D
## The frozen lake: ice sheet, a hole of open water with slush and floes,
## and collision that really has the hole in it, so you can fall in.

const HOLE_C := Vector2(-190.0, 170.0)
const HOLE_R := 48.0
const GRID := 8.0
# summer: the White One keeps a floe of ice frozen around it, the rest of the lake is open
const FLOE_C := Vector2(-300.0, 250.0)
const FLOE_R := 100.0

var water_mat: ShaderMaterial
var breaks: Array = []      # holes that vehicles broke: [centre, radius]
var pier: Array = []        # summer: [floe end, shore end] of the plank pier


## Below 0 inside the open water, above 0 on the ice. Same formula as in the shaders.
static func hole(p: Vector2) -> float:
	if GameMode.summer():
		# summer: open water everywhere except the White One's floe (positive on the floe)
		var f := p - FLOE_C
		var fa := atan2(f.y, f.x)
		return FLOE_R * (1.0 + 0.16 * sin(fa * 3.0 + 0.5) + 0.09 * sin(fa * 7.0 + 1.3)) - f.length()
	var q := p - HOLE_C
	var ang := atan2(q.y, q.x)
	var r := HOLE_R * (1.0 + 0.16 * sin(ang * 3.0 + 0.5) + 0.09 * sin(ang * 7.0 + 1.3))
	return q.length() - r


## Ice thickness in metres: thin near the open water and in dark patches.
## Same formula as in ice.gdshader, so you can see the thin ice.
static func thickness(p: Vector2) -> float:
	var t := 0.10 + 0.50 * smoothstep(0.0, 70.0, hole(p))
	var patch := smoothstep(0.6, 0.9, sin(p.x * 0.031 + 1.3) * sin(p.y * 0.027 + 0.4))
	return t * (1.0 - 0.5 * patch)


## Weight in kg the ice carries at this spot.
static func capacity(p: Vector2) -> float:
	var cm := thickness(p) * 100.0
	return 3.5 * cm * cm


func in_break(pos: Vector3) -> bool:
	for b in breaks:
		var c: Vector2 = b[0]
		if c.distance_to(Vector2(pos.x, pos.z)) < float(b[1]) * 0.85:
			return true
	return false


func in_water(pos: Vector3) -> bool:
	return pos.y < Terrain.LAKE_LEVEL and (hole(Vector2(pos.x, pos.z)) < 0.5 or in_break(pos))


## A vehicle went through here: open water with broken ice around it.
func break_ice(c: Vector2, r: float) -> void:
	breaks.append([c, r])
	var level := Terrain.LAKE_LEVEL
	var k := MeshKit.new()
	k.winter = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 13.0 + c.y * 7.0)
	var sides := 13
	var pts: Array[Vector3] = []
	for s in sides:
		var ang := TAU * s / sides
		var rr := r * rng.randf_range(0.8, 1.1)
		pts.append(Vector3(cos(ang) * rr, 0.03, sin(ang) * rr))
	for s in sides:
		k.tri(Vector3(0, 0.03, 0), pts[(s + 1) % sides], pts[s], "glass_dark")
		var m := (pts[s] + pts[(s + 1) % sides]) * 0.5
		var out := Vector3(m.x, 0, m.z).normalized()
		k.box(m + out * 0.5 + Vector3(0, 0.1, 0), Vector3(rng.randf_range(0.8, 1.6), 0.22, rng.randf_range(0.7, 1.3)), "ice",
				Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))))
	for i in 5:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.7) * r
		k.box(Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(rng.randf_range(0.6, 1.3), 0.16, rng.randf_range(0.5, 1.0)), "ice",
				Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0.0)))
	var n := k.node(false)
	n.position = Vector3(c.x, level, c.y)
	n.set_meta("ice_break", true)
	add_child(n)


## A dry spot on the ice next to the break around `pos`.
func edge_of_break(pos: Vector3) -> Vector3:
	var p := Vector2(pos.x, pos.z)
	for b in breaks:
		var c: Vector2 = b[0]
		if c.distance_to(p) < float(b[1]) * 1.5:
			var dir := (c - HOLE_C).normalized()
			var e := c + dir * (float(b[1]) + 1.2)
			return Vector3(e.x, Terrain.LAKE_LEVEL + 0.3, e.y)
	return Vector3(pos.x, Terrain.LAKE_LEVEL + 0.3, pos.z)


func breaks_list() -> Array:
	var out := []
	for b in breaks:
		var c: Vector2 = b[0]
		out.append([c.x, c.y, b[1]])
	return out


func set_breaks(list: Array) -> void:
	for n in get_children():
		if n.has_meta("ice_break"):
			n.queue_free()
	breaks.clear()
	for b in list:
		var a: Array = b
		break_ice(Vector2(a[0], a[1]), a[2])


func build(noise_tex: Texture2D, normal_tex: Texture2D) -> void:
	var level := Terrain.LAKE_LEVEL
	var c := Terrain.LAKE_POS
	var size := Terrain.LAKE_R * 3.2
	if GameMode.summer():
		_build_summer(noise_tex, normal_tex, level, c, size)
		return
	var ice := ShaderMaterial.new()
	ice.shader = load("res://world/ice.gdshader")
	ice.set_shader_parameter("noise_tex", noise_tex)
	ice.set_shader_parameter("normal_tex", normal_tex)
	ice.set_shader_parameter("hole_c", HOLE_C)
	ice.set_shader_parameter("hole_r", HOLE_R)
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.material = ice
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(c.x, level, c.y)
	add_child(mi)

	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://world/water.gdshader")
	water_mat.set_shader_parameter("noise_tex", noise_tex)
	water_mat.set_shader_parameter("normal_tex", normal_tex)
	water_mat.set_shader_parameter("hole_c", HOLE_C)
	water_mat.set_shader_parameter("hole_r", HOLE_R)
	var wm := PlaneMesh.new()
	wm.size = Vector2(HOLE_R * 2.8, HOLE_R * 2.8)
	wm.subdivide_width = 40
	wm.subdivide_depth = 40
	wm.material = water_mat
	var wi := MeshInstance3D.new()
	wi.mesh = wm
	wi.position = Vector3(HOLE_C.x, level - 0.14, HOLE_C.y)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)

	# collision: coarse grid, fine grid around the hole, nothing over open water
	var faces := PackedVector3Array()
	var o := c - Vector2(size, size) * 0.5
	var n := int(size / GRID)
	var fine_lo := Vector2(floorf((HOLE_C.x - 72.0 - o.x) / GRID), floorf((HOLE_C.y - 72.0 - o.y) / GRID))
	var fine_hi := Vector2(ceilf((HOLE_C.x + 72.0 - o.x) / GRID), ceilf((HOLE_C.y + 72.0 - o.y) / GRID))
	for j in n:
		for i in n:
			if i >= fine_lo.x and i < fine_hi.x and j >= fine_lo.y and j < fine_hi.y:
				continue
			_cell(faces, o + Vector2(i, j) * GRID, GRID, level)
	var step := 2.0
	var fx := int((fine_hi.x - fine_lo.x) * GRID / step)
	var fz := int((fine_hi.y - fine_lo.y) * GRID / step)
	var fo := o + fine_lo * GRID
	for j in fz:
		for i in fx:
			var p := fo + Vector2(i, j) * step
			if hole(p + Vector2(step, step) * 0.5) < 0.6:
				continue
			_cell(faces, p, step, level)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.set_meta("surface", "ice")
	body.collision_layer = 2    # so that something which broke through can ignore the ice
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

	# thick broken edge of the ice, and floes drifting in the water
	var k := MeshKit.new()
	var segs := 160
	for i in segs:
		var p0 := _rim(TAU * i / segs)
		var p1 := _rim(TAU * (i + 1) / segs)
		var a := Vector3(p0.x, level, p0.y)
		var b := Vector3(p1.x, level, p1.y)
		var d := Vector3(0, 0.7, 0)
		k.quad(a, b, b - d, a - d, "ice")
		k.quad(b, a, a - d, b - d, "ice")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var made := 0
	while made < 16:
		var p := HOLE_C + Vector2(rng.randf_range(-55, 55), rng.randf_range(-55, 55))
		var e := hole(p)
		if e > -5.0:
			continue
		made += 1
		var r := rng.randf_range(1.2, minf(4.5, -e * 0.6))
		var pts: Array[Vector3] = []
		var sides := 7
		for s in sides:
			var ang := TAU * s / sides + rng.randf_range(-0.25, 0.25)
			var rr := r * rng.randf_range(0.7, 1.15)
			pts.append(Vector3(p.x + cos(ang) * rr, level - 0.06, p.y + sin(ang) * rr))
		var mid := Vector3(p.x, level - 0.04, p.y)
		for s in sides:
			var a := pts[s]
			var b := pts[(s + 1) % sides]
			k.tri(mid, b, a, "snow")
			k.quad(a, b, b - Vector3(0, 0.4, 0), a - Vector3(0, 0.4, 0), "ice")
	add_child(k.node(false))


func _rim(ang: float) -> Vector2:
	var r := HOLE_R * (1.0 + 0.16 * sin(ang * 3.0 + 0.5) + 0.09 * sin(ang * 7.0 + 1.3))
	return HOLE_C + Vector2(cos(ang), sin(ang)) * r


func _cell(faces: PackedVector3Array, p: Vector2, s: float, y: float) -> void:
	var a := Vector3(p.x, y, p.y)
	var b := Vector3(p.x + s, y, p.y)
	var c := Vector3(p.x + s, y, p.y + s)
	var d := Vector3(p.x, y, p.y + s)
	faces.append_array([a, b, c, a, c, d])


## Summer: no ice at all, one sheet of open water over the whole lake.
func _build_summer(noise_tex: Texture2D, normal_tex: Texture2D, level: float, c: Vector2, size: float) -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://world/water.gdshader")
	water_mat.set_shader_parameter("noise_tex", noise_tex)
	water_mat.set_shader_parameter("normal_tex", normal_tex)
	water_mat.set_shader_parameter("hole_c", c)
	water_mat.set_shader_parameter("hole_r", size * 4.0)
	var wm := PlaneMesh.new()
	wm.size = Vector2(size, size)
	wm.subdivide_width = 96
	wm.subdivide_depth = 96
	wm.material = water_mat
	var wi := MeshInstance3D.new()
	wi.mesh = wm
	wi.position = Vector3(c.x, level - 0.14, c.y)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)
	_build_floe(noise_tex, normal_tex, level)
	_build_pier(level)


## Summer: an old fishing pier of planks on floats from the nearest shore out to the floe, so
## the White One can be reached on foot (swimming works too, but nobody would guess it).
func _build_pier(level: float) -> void:
	var t: Terrain = get_parent().get("terrain")
	if t == null:
		return
	var best := []
	var best_len := 1e9
	for q in 120:
		var a := TAU * q / 120.0
		var d := Vector2(cos(a), sin(a))
		var start := Vector2.INF
		for r in range(int(FLOE_R * 0.6), 520):
			var p := FLOE_C + d * r
			if start == Vector2.INF:
				if hole(p) < 0.6:
					start = p - d * 3.0
				continue
			if t.height_at(p.x, p.y) > level + 0.35:
				# short, but above all near Eisgrund, where people come down to the water
				var ln := start.distance_to(p) + 0.5 * p.distance_to(Places.SETTLE)
				if ln < best_len:
					best_len = ln
					best = [start, p + d * 3.0]
				break
	if best.is_empty():
		return
	var a0: Vector2 = best[0]
	var a1: Vector2 = best[1]
	var dir := (a1 - a0).normalized()
	var yaw := atan2(dir.x, dir.y)
	var k := MeshKit.new()
	var bs := Basis(Vector3.UP, yaw)
	var n := int(a0.distance_to(a1) / 1.2) + 1
	for i in n:
		var p := a0.lerp(a1, float(i) / maxf(n - 1, 1))
		var y := maxf(level + 0.28, t.height_at(p.x, p.y) + 0.12)
		k.box(Vector3(p.x, y - 0.08, p.y), Vector3(2.0, 0.16, 1.3), "planks", bs)
		if i % 4 == 0:
			for sx: float in [-1.0, 1.0]:
				var side := Vector3(p.x, 0, p.y) + bs * Vector3(sx * 1.05, 0, 0)
				k.cyl(Vector3(side.x, level - 1.5, side.z), 0.12, y - level + 2.4, "wood_dark", 6)
				k.box(Vector3(side.x, y - 0.35, side.z), Vector3(0.5, 0.4, 0.9), "rust", bs)
	# a post with a sign where the pier leaves the shore
	var sp := Vector3(a1.x, t.height_at(a1.x, a1.y), a1.y) + bs * Vector3(1.6, 0, 0)
	k.cyl(sp, 0.07, 2.2, "wood_dark", 6)
	k.box(sp + Vector3(0, 1.9, 0), Vector3(0.05, 0.45, 1.1), "planks", bs)
	var lbl := Label3D.new()
	lbl.text = "FISCHERSTEG\nzur Scholle"
	lbl.font_size = 48
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.95, 0.92, 0.85)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.1, 0.07, 0.04)
	lbl.position = sp + Vector3(0, 1.9, 0) + bs * Vector3(0.04, 0, 0)
	lbl.rotation.y = yaw + PI * 0.5
	add_child(lbl)
	add_child(k.node(true))
	pier = [Vector3(a0.x, level + 0.3, a0.y), Vector3(a1.x, t.height_at(a1.x, a1.y), a1.y)]
	print("Lake: summer pier to the floe, %.0f m, floe end %s, shore end %s" % [a0.distance_to(a1), pier[0], pier[1]])


## Summer: the floe the White One keeps frozen. Same ice, collision and broken rim as in winter.
func _build_floe(noise_tex: Texture2D, normal_tex: Texture2D, level: float) -> void:
	var ice := ShaderMaterial.new()
	ice.shader = load("res://world/ice.gdshader")
	ice.set_shader_parameter("noise_tex", noise_tex)
	ice.set_shader_parameter("normal_tex", normal_tex)
	ice.set_shader_parameter("hole_c", FLOE_C)
	ice.set_shader_parameter("hole_r", FLOE_R)
	ice.set_shader_parameter("hole_sign", -1.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(FLOE_R * 2.8, FLOE_R * 2.8)
	pm.material = ice
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(FLOE_C.x, level, FLOE_C.y)
	add_child(mi)
	var faces := PackedVector3Array()
	var step := 2.0
	var n := int(FLOE_R * 2.8 / step)
	var o := FLOE_C - Vector2(FLOE_R, FLOE_R) * 1.4
	for j in n:
		for i in n:
			var p := o + Vector2(i, j) * step
			if hole(p + Vector2(step, step) * 0.5) < 0.6:
				continue
			_cell(faces, p, step, level)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.set_meta("surface", "ice")
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	# the thick broken edge
	var k := MeshKit.new()
	k.winter = true
	var segs := 200
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var r0 := FLOE_R * (1.0 + 0.16 * sin(a0 * 3.0 + 0.5) + 0.09 * sin(a0 * 7.0 + 1.3))
		var r1 := FLOE_R * (1.0 + 0.16 * sin(a1 * 3.0 + 0.5) + 0.09 * sin(a1 * 7.0 + 1.3))
		var a := Vector3(FLOE_C.x + cos(a0) * r0, level, FLOE_C.y + sin(a0) * r0)
		var b := Vector3(FLOE_C.x + cos(a1) * r1, level, FLOE_C.y + sin(a1) * r1)
		var d := Vector3(0, 0.7, 0)
		k.quad(a, b, b - d, a - d, "ice")
		k.quad(b, a, a - d, b - d, "ice")
	add_child(k.node(false))

