class_name VehicleMesh
extends RefCounted
## Vehicle bodies and wheels, built from boxes. Front is -Z, the ground is y = 0.


static func body(type: String) -> Node3D:
	var k := MeshKit.new()
	match type:
		"snowmobile":
			_snowmobile(k)
		"pickup":
			_pickup(k)
		"offroader":
			_offroader(k)
		"tracked":
			_tracked(k)
	return k.node(false)


## A wheel with its axle along X. Snowmobiles have none you can see.
static func wheel(type: String, r: float, side: float) -> Node3D:
	if type == "snowmobile":
		return null
	var k := MeshKit.new()
	var w := 0.3 if type != "tracked" else 0.34
	_wheel(k, Vector3.ZERO, r, w, side)
	return k.node(false)


static func _wheel(k: MeshKit, at: Vector3, r: float, w: float, side: float) -> void:
	var old := k.xf
	k.xf = old * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), at)
	k.cyl(Vector3(0, -w * 0.5, 0), r * 0.9, w * 0.14, "black_in", 18, r)
	k.cyl(Vector3(0, -w * 0.36, 0), r, w * 0.72, "black_in", 18)
	k.cyl(Vector3(0, w * 0.36, 0), r, w * 0.14, "black_in", 18, r * 0.9)
	# rim, spokes, hub and nuts on both faces
	k.cyl(Vector3(0, -w * 0.5 - 0.012, 0), r * 0.6, w + 0.024, "steel_in", 14)
	k.cyl(Vector3(0, -w * 0.5 - 0.02, 0), r * 0.5, w + 0.04, "metal_in", 12)
	for f in [-1.0, 1.0]:
		var face: float = f
		var y := face * (w * 0.5 + 0.024)
		for i in 5:
			var a := TAU * i / 5.0
			k.box(Vector3(cos(a) * r * 0.3, y, sin(a) * r * 0.3), Vector3(r * 0.5, 0.02, 0.07), "steel_in", Basis(Vector3.UP, -a))
			k.cyl(Vector3(cos(a + 0.6) * r * 0.16, y - 0.008, sin(a + 0.6) * r * 0.16), 0.014, 0.03, "black_in", 5)
		k.cyl(Vector3(0, y - 0.015, 0), r * 0.13, 0.05, "steel_in", 8)
	# tread blocks, so you can see it turn
	for i in 16:
		var a := TAU * i / 16.0
		for row in [-0.3, 0.0, 0.3]:
			var rw: float = row
			k.box(Vector3(cos(a + rw) * (r + 0.008), rw * w, sin(a + rw) * (r + 0.008)), Vector3(0.035, w * 0.26, 0.09), "black_in", Basis(Vector3.UP, -(a + rw)))
	k.xf = old
	if side == 0.0:
		return


## Small things every road vehicle has: door gaps and handles, wipers, number
## plates, exhaust, aerial, mud flaps, lamp glass, snow lying on the flat parts.
static func _trim(k: MeshKit, hw: float, belt: float, door_z0: float, door_z1: float, screen: Vector3, z_front: float, z_back: float, roof: Vector3, roof_size: Vector2) -> void:
	for s in [-1.0, 1.0]:
		var sx: float = s
		for z in [door_z0, door_z1]:
			var zz: float = z
			k.box(Vector3(sx * (hw + 0.004), belt - 0.22, zz), Vector3(0.012, 0.62, 0.02), "black_in")
		k.box(Vector3(sx * (hw + 0.004), belt - 0.52, (door_z0 + door_z1) * 0.5), Vector3(0.012, 0.02, door_z1 - door_z0), "black_in")
		k.bbox(Vector3(sx * (hw + 0.02), belt - 0.03, door_z1 - 0.2), Vector3(0.03, 0.035, 0.16), 0.01, "steel_in")
		# mud flaps
		k.box(Vector3(sx * (hw - 0.14), 0.36, z_back - 0.55), Vector3(0.26, 0.3, 0.02), "black_in")
		k.box(Vector3(sx * (hw - 0.14), 0.36, z_front + 1.55), Vector3(0.26, 0.3, 0.02), "black_in")
		# wiper
		k.tube(Vector3(sx * 0.12, screen.y - 0.2, screen.z), Vector3(sx * 0.62, screen.y - 0.02, screen.z - 0.012), 0.012, "black_in", 4)
	for z in [z_front - 0.012, z_back + 0.012]:
		var zz: float = z
		k.box(Vector3(0, 0.52, zz), Vector3(0.46, 0.12, 0.012), "paint_white_in")
		k.box(Vector3(0, 0.52, zz + signf(zz) * 0.004), Vector3(0.36, 0.05, 0.012), "black_in")
	# exhaust, tow hook, aerial
	k.tube(Vector3(-hw + 0.3, 0.36, z_back - 0.5), Vector3(-hw + 0.3, 0.36, z_back + 0.12), 0.04, "steel_in", 8)
	k.tube(Vector3(-hw + 0.3, 0.36, z_back + 0.08), Vector3(-hw + 0.3, 0.36, z_back + 0.125), 0.03, "black_in", 8)
	k.box(Vector3(0.4, 0.4, z_front - 0.1), Vector3(0.06, 0.1, 0.12), "red_in")
	k.cyl(Vector3(hw - 0.15, belt + 0.0, screen.z - 0.2), 0.006, 1.1, "black_in", 4)
	# snow that has settled on the roof and bonnet
	k.bbox(roof + Vector3(0, 0.06, 0), Vector3(roof_size.x, 0.1, roof_size.y), 0.045, "snow")
	k.bbox(Vector3(0, belt + 0.12, z_front + 0.75), Vector3(hw * 1.5, 0.05, 0.9), 0.022, "snow")


## Dashboard with a steering wheel, seen from the driver's seat.
static func _dash(k: MeshKit, at: Vector3, width: float, wheel_x: float) -> void:
	k.box(at, Vector3(width, 0.16, 0.3), "black_in")
	k.box(at + Vector3(wheel_x, 0.02, 0.24), Vector3(0.05, 0.05, 0.2), "metal_in")
	var tilt := Basis(Vector3.RIGHT, -0.35)
	for bar in [[Vector3(0, 0.17, 0), Vector3(0.36, 0.035, 0.035)], [Vector3(0, -0.17, 0), Vector3(0.36, 0.035, 0.035)],
			[Vector3(0.17, 0, 0), Vector3(0.035, 0.36, 0.035)], [Vector3(-0.17, 0, 0), Vector3(0.035, 0.36, 0.035)],
			[Vector3(0, 0, 0), Vector3(0.3, 0.04, 0.03)]]:
		var o: Vector3 = bar[0]
		k.box(at + Vector3(wheel_x, 0.06, 0.35) + tilt * o, bar[1], "black_in", tilt)


static func _lamps(k: MeshKit, x: float, y: float, z_front: float, z_back: float) -> void:
	for s in [-1.0, 1.0]:
		var sx: float = s
		k.box(Vector3(sx * x, y, z_front), Vector3(0.3, 0.16, 0.05), "white_in")
		k.box(Vector3(sx * x, y, z_back), Vector3(0.22, 0.14, 0.05), "red_in")


static func _pickup(k: MeshKit) -> void:
	var p := "car_red"
	k.bbox(Vector3(0, 0.66, 0), Vector3(1.9, 0.5, 5.0), 0.06, p)
	k.bbox(Vector3(0, 0.98, -1.8), Vector3(1.8, 0.22, 1.35), 0.06, p)
	# cab
	k.bbox(Vector3(0, 1.05, -0.35), Vector3(1.88, 0.36, 1.7), 0.06, p)
	k.box(Vector3(0, 1.45, -0.35), Vector3(1.72, 0.46, 1.58), "glass_dark")
	k.bbox(Vector3(0, 1.72, -0.35), Vector3(1.82, 0.09, 1.7), 0.06, p)
	for sx in [-0.88, 0.88]:
		for sz in [-1.16, 0.46]:
			var x: float = sx
			var z: float = sz
			k.bbox(Vector3(x, 1.45, z), Vector3(0.09, 0.48, 0.09), 0.06, p)
	_dash(k, Vector3(0, 1.18, -1.05), 1.68, -0.42)
	# bed
	for sx in [-0.91, 0.91]:
		var x: float = sx
		k.bbox(Vector3(x, 1.06, 1.52), Vector3(0.08, 0.36, 1.95), 0.06, p)
	k.bbox(Vector3(0, 1.06, 2.46), Vector3(1.9, 0.36, 0.08), 0.06, p)
	k.box(Vector3(0, 0.93, 1.5), Vector3(1.74, 0.05, 1.9), "metal")
	# bumpers, grille, lamps, mirrors
	k.box(Vector3(0, 0.5, -2.56), Vector3(1.96, 0.2, 0.16), "metal")
	k.box(Vector3(0, 0.5, 2.56), Vector3(1.96, 0.2, 0.16), "metal")
	k.box(Vector3(0, 0.82, -2.51), Vector3(0.9, 0.24, 0.04), "black_in")
	_lamps(k, 0.72, 0.84, -2.52, 2.52)
	for sx in [-1.02, 1.02]:
		var x: float = sx
		k.box(Vector3(x, 1.3, -1.05), Vector3(0.16, 0.14, 0.06), "black_in")
	# wheel arches
	for sx in [-0.96, 0.96]:
		for sz in [-1.55, 1.55]:
			var x: float = sx
			var z: float = sz
			k.box(Vector3(x, 0.86, z), Vector3(0.06, 0.1, 1.1), "black_in")
	_trim(k, 0.95, 1.22, -1.1, 0.4, Vector3(0, 1.5, -1.16), -2.64, 2.64, Vector3(0, 1.77, -0.35), Vector2(1.7, 1.55))
	# things in the bed: a spare wheel, a jerry can, a tarp, a shovel
	var old := k.xf
	k.xf = old * Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5), Vector3(-0.35, 1.1, 2.0))
	_wheel(k, Vector3.ZERO, 0.38, 0.24, 0.0)
	k.xf = old
	k.bbox(Vector3(0.55, 1.14, 2.1), Vector3(0.2, 0.36, 0.42), 0.03, "red")
	k.bbox(Vector3(0.3, 1.04, 1.0), Vector3(1.1, 0.2, 0.8), 0.07, "olive")
	k.tube(Vector3(-0.7, 1.0, 0.7), Vector3(-0.7, 1.05, 2.2), 0.018, "wood", 5)
	k.box(Vector3(-0.7, 1.0, 0.62), Vector3(0.2, 0.02, 0.26), "steel")


static func _offroader(k: MeshKit) -> void:
	var p := "car_olive"
	k.bbox(Vector3(0, 0.8, 0), Vector3(1.85, 0.55, 4.1), 0.06, p)
	k.bbox(Vector3(0, 1.16, -1.45), Vector3(1.72, 0.2, 1.2), 0.06, p)
	k.bbox(Vector3(0, 1.2, 0.5), Vector3(1.84, 0.3, 2.9), 0.06, p)
	k.box(Vector3(0, 1.58, 0.5), Vector3(1.7, 0.48, 2.78), "glass_dark")
	k.bbox(Vector3(0, 1.86, 0.5), Vector3(1.8, 0.1, 2.9), 0.06, p)
	for sx in [-0.86, 0.86]:
		for sz in [-0.9, 0.3, 1.9]:
			var x: float = sx
			var z: float = sz
			k.bbox(Vector3(x, 1.58, z), Vector3(0.1, 0.5, 0.1), 0.06, p)
	_dash(k, Vector3(0, 1.3, -0.8), 1.66, -0.42)
	# roof rack with a box and a spare can
	for sz in [-0.6, 0.5, 1.6]:
		var z: float = sz
		k.box(Vector3(0, 1.98, z), Vector3(1.7, 0.04, 0.05), "metal")
	for sx in [-0.85, 0.85]:
		var x: float = sx
		k.box(Vector3(x, 1.98, 0.5), Vector3(0.05, 0.04, 2.3), "metal")
	k.box(Vector3(-0.3, 2.14, 1.1), Vector3(0.8, 0.28, 0.6), "wood")
	k.box(Vector3(0.5, 2.16, 0.0), Vector3(0.22, 0.32, 0.4), "red")
	# bull bar, winch, bumpers, lamps, spare wheel
	k.box(Vector3(0, 0.62, -2.14), Vector3(1.9, 0.22, 0.18), "metal")
	k.box(Vector3(0, 0.62, 2.12), Vector3(1.9, 0.22, 0.16), "metal")
	for sx in [-0.5, 0.5]:
		var x: float = sx
		k.box(Vector3(x, 0.95, -2.18), Vector3(0.06, 0.6, 0.06), "metal")
	k.box(Vector3(0, 1.22, -2.18), Vector3(1.1, 0.06, 0.06), "metal")
	k.box(Vector3(0, 0.78, -2.2), Vector3(0.42, 0.2, 0.22), "steel")
	_lamps(k, 0.68, 1.0, -2.07, 2.07)
	_trim(k, 0.925, 1.34, -0.85, 0.3, Vector3(0, 1.62, -0.9), -2.24, 2.2, Vector3(0, 1.91, -0.7), Vector2(1.6, 0.9))
	# snorkel and extra lamps on the bull bar
	k.tube(Vector3(0.9, 1.25, -1.5), Vector3(0.9, 2.0, -0.95), 0.045, "black_in", 8)
	k.cyl(Vector3(0.9, 2.0, -0.95), 0.06, 0.1, "black_in", 8)
	for sx in [-0.3, 0.3]:
		var x: float = sx
		k.tube(Vector3(x, 1.34, -2.2), Vector3(x, 1.34, -2.12), 0.09, "black_in", 12)
		k.tube(Vector3(x, 1.34, -2.21), Vector3(x, 1.34, -2.2), 0.075, "white_in", 12)
	var old := k.xf
	k.xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 1.25, 2.2))
	_wheel(k, Vector3.ZERO, 0.42, 0.26, 0.0)
	k.xf = old


static func _snowmobile(k: MeshKit) -> void:
	var p := "car_yellow"
	k.bbox(Vector3(0, 0.5, -0.15), Vector3(0.62, 0.36, 2.1), 0.06, p)
	k.box(Vector3(0, 0.66, -0.95), Vector3(0.56, 0.3, 0.75), p, Basis(Vector3.RIGHT, 0.32))
	k.box(Vector3(0, 0.78, 0.5), Vector3(0.4, 0.16, 1.15), "black_in")
	k.box(Vector3(0, 0.98, 1.12), Vector3(0.44, 0.3, 0.08), "black_in")
	k.box(Vector3(0, 1.0, -0.62), Vector3(0.5, 0.36, 0.04), "glass_dark", Basis(Vector3.RIGHT, -0.5))
	k.box(Vector3(0, 0.86, -0.38), Vector3(0.05, 0.3, 0.05), "metal")
	k.box(Vector3(0, 1.0, -0.36), Vector3(0.72, 0.045, 0.045), "black_in")
	k.box(Vector3(0, 0.74, -1.32), Vector3(0.26, 0.12, 0.05), "white_in")
	k.box(Vector3(0, 0.6, 1.26), Vector3(0.3, 0.08, 0.05), "red_in")
	# skis on struts
	for sx in [-0.47, 0.47]:
		var x: float = sx
		k.box(Vector3(x, 0.035, -0.95), Vector3(0.14, 0.05, 1.25), "steel")
		k.box(Vector3(x, 0.09, -1.6), Vector3(0.14, 0.05, 0.22), "steel", Basis(Vector3.RIGHT, 0.5))
		k.box(Vector3(x * 0.72, 0.24, -0.95), Vector3(0.05, 0.42, 0.06), "metal", Basis(Vector3(0, 0, 1), -0.45 * signf(x)))
	# track
	k.box(Vector3(0, 0.2, 0.7), Vector3(0.44, 0.38, 1.4), "black_in")
	for i in 7:
		k.box(Vector3(0, 0.02, 0.1 + i * 0.2), Vector3(0.46, 0.04, 0.06), "metal")
	k.box(Vector3(0, 0.44, 1.2), Vector3(0.5, 0.04, 0.5), "metal")


static func _tracked(k: MeshKit) -> void:
	var p := "car_orange"
	k.bbox(Vector3(0, 1.0, 0), Vector3(2.0, 0.7, 5.6), 0.06, p)
	# cab
	k.bbox(Vector3(0, 1.55, -1.6), Vector3(2.3, 0.45, 2.15), 0.06, p)
	k.box(Vector3(0, 2.02, -1.6), Vector3(2.18, 0.5, 2.02), "glass_dark")
	k.bbox(Vector3(0, 2.32, -1.6), Vector3(2.34, 0.1, 2.2), 0.06, p)
	for sx in [-1.1, 1.1]:
		for sz in [-2.6, -0.6]:
			var x: float = sx
			var z: float = sz
			k.bbox(Vector3(x, 2.02, z), Vector3(0.12, 0.52, 0.12), 0.06, p)
	_dash(k, Vector3(0, 1.74, -2.4), 2.1, -0.55)
	# cargo deck with rails
	k.box(Vector3(0, 1.38, 1.25), Vector3(2.3, 0.08, 3.1), "metal")
	for sx in [-1.13, 1.13]:
		var x: float = sx
		k.bbox(Vector3(x, 1.62, 1.25), Vector3(0.06, 0.45, 3.1), 0.06, p)
	k.bbox(Vector3(0, 1.62, 2.78), Vector3(2.3, 0.45, 0.06), 0.06, p)
	k.box(Vector3(0.5, 1.68, 0.6), Vector3(0.9, 0.5, 0.7), "wood")
	# tracks: a belt around the road wheels on each side
	for sx in [-1.05, 1.05]:
		var x: float = sx
		k.box(Vector3(x, 0.86, 0), Vector3(0.5, 0.07, 5.0), "black_in")
		k.box(Vector3(x, 0.035, 0), Vector3(0.5, 0.07, 4.8), "black_in")
		for sz in [-2.5, 2.5]:
			var z: float = sz
			k.box(Vector3(x, 0.45, z), Vector3(0.5, 0.07, 0.86), "black_in", Basis(Vector3.RIGHT, PI * 0.5 - 0.22 * signf(z)))
		for i in 15:
			k.box(Vector3(x, 0.9, -2.3 + i * 0.33), Vector3(0.52, 0.04, 0.08), "metal")
		k.bbox(Vector3(x * 1.14, 0.98, 0), Vector3(0.36, 0.05, 5.3), 0.06, p)
	# winch, lamps, roof light bar
	k.box(Vector3(0, 0.95, -2.9), Vector3(0.6, 0.3, 0.3), "steel")
	_lamps(k, 0.8, 1.2, -2.82, 2.82)
	k.box(Vector3(0, 2.44, -2.3), Vector3(1.4, 0.12, 0.1), "metal")
	for i in 4:
		k.box(Vector3(-0.52 + i * 0.35, 2.44, -2.36), Vector3(0.2, 0.14, 0.04), "white_in")
