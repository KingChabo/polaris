class_name Props
extends RefCounted
## Village props, all modelled in code. Each function draws into a MeshKit at
## the kit's current transform (kit.xf). Fairy-light bulbs and lamp lights are
## collected in lists; the village turns them into nodes afterwards.

static var bulbs: Array = []    # [world position, colour]
static var lights: Array = []   # [world position, colour, energy, range, flickers]

const WARM := Color(1.0, 0.72, 0.42)
const BULB_COLS: Array[Color] = [Color(1.0, 0.12, 0.08), Color(0.12, 1.0, 0.22), Color(0.15, 0.35, 1.0), Color(1.0, 0.75, 0.15), Color(1.0, 0.85, 0.6)]
const DEAD := Color(0.025, 0.025, 0.03)


static func lamp(k: MeshKit, lit: bool, flicker := false) -> void:
	k.cyl(Vector3.ZERO, 0.17, 0.45, "metal", 8, 0.1)
	k.cyl(Vector3(0, 0.45, 0), 0.07, 3.2, "metal", 8, 0.05)
	k.box(Vector3(0, 3.67, 0), Vector3(0.36, 0.04, 0.36), "metal")
	k.box(Vector3(0, 3.9, 0), Vector3(0.3, 0.42, 0.3), "lamp_glow" if lit else "glass_dark")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.16, 3.9, sz * 0.16), Vector3(0.03, 0.44, 0.03), "metal")
	k.cyl(Vector3(0, 4.11, 0), 0.34, 0.26, "metal", 4, 0.04)
	k.sphere(Vector3(0, 4.3, 0), 0.2, "snow", 8, 4, 0.6)
	if lit:
		lights.append([k.xf * Vector3(0, 3.9, 0), WARM, 2.6, 15.0, flicker])


static func stall(k: MeshKit, rng: RandomNumberGenerator, lit: bool) -> void:
	# a Christmas-market hut: board walls with battens, a front hatch propped up as an awning,
	# zig-zag fascia, a fir garland with lights, and goods you can tell apart
	var w := 3.2
	var d := 2.2
	var trim: String = ["paint_red", "paint_green", "wood_dark"][rng.randi() % 3]
	k.box(Vector3(0, 0.06, 0), Vector3(w + 0.1, 0.12, d + 0.1), "wood_dark")
	k.box(Vector3(0, 0.14, 0), Vector3(w - 0.1, 0.04, d - 0.1), "planks_in")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.bbox(Vector3(sx * (w * 0.5 - 0.06), 1.3, sz * (d * 0.5 - 0.06)), Vector3(0.14, 2.4, 0.14), 0.02, "wood_dark")
	# back and side walls, battens over the joints
	k.box(Vector3(0, 1.3, -d * 0.5 + 0.03), Vector3(w - 0.1, 2.3, 0.06), "planks")
	for i in 7:
		k.box(Vector3(-w * 0.5 + 0.3 + i * (w - 0.6) / 6.0, 1.3, -d * 0.5 - 0.01), Vector3(0.06, 2.3, 0.03), "wood_dark")
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.03), 1.3, 0), Vector3(0.06, 2.3, d - 0.1), "planks")
		for i in 4:
			k.box(Vector3(sx * (w * 0.5 + 0.005), 1.3, -d * 0.5 + 0.35 + i * (d - 0.7) / 3.0), Vector3(0.03, 2.3, 0.06), "wood_dark")
	# front: lower wall, counter with a lip, upper hatch swung up on two struts
	k.box(Vector3(0, 0.55, d * 0.5 - 0.05), Vector3(w - 0.1, 0.9, 0.06), "planks")
	k.bbox(Vector3(0, 1.03, d * 0.5 + 0.08), Vector3(w + 0.05, 0.07, 0.5), 0.02, "wood")
	k.box(Vector3(0, 0.98, d * 0.5 + 0.3), Vector3(w + 0.05, 0.1, 0.05), trim)
	var hinge := Vector3(0, 2.42, d * 0.5)
	var open := Basis(Vector3.RIGHT, -1.15)
	k.box(hinge + open * Vector3(0, -0.58, 0.03), Vector3(w + 0.05, 1.16, 0.06), "planks", open)
	k.box(hinge + open * Vector3(0, -1.13, 0.07), Vector3(w + 0.05, 0.08, 0.04), trim, open)
	for sx: float in [-1.0, 1.0]:
		k.tube(Vector3(sx * (w * 0.5 - 0.1), 1.05, d * 0.5 + 0.25), hinge + open * Vector3(sx * (w * 0.5 - 0.1), -0.95, 0.06), 0.025, "wood_dark", 6)
	# roof: two pitches with overhang, snow on top with a soft rounded edge
	var pitch := 0.5
	var hdp := d * 0.5 + 0.45
	var ridge := 2.45 + tan(pitch) * hdp
	var slab := hdp / cos(pitch)
	for sg: float in [-1.0, 1.0]:
		var rb := Basis(Vector3.RIGHT, pitch * sg)
		var mid := Vector3(0, ridge - tan(pitch) * hdp * 0.5, sg * hdp * 0.5)
		k.box(mid, Vector3(w + 0.7, 0.06, slab), "roof", rb)
		k.box(mid + rb * Vector3(0, 0.12, 0), Vector3(w + 0.6, 0.18, slab - 0.05), "snow", rb)
		k.tube(mid + rb * Vector3(-(w + 0.6) * 0.5, 0.1, sg * slab * 0.5), mid + rb * Vector3((w + 0.6) * 0.5, 0.1, sg * slab * 0.5), 0.1, "snow", 8)
	for sx: float in [-1.0, 1.0]:
		var gx: float = sx * (w * 0.5 - 0.02)
		k.tri(Vector3(gx, 2.45, -d * 0.5), Vector3(gx, 2.45, d * 0.5), Vector3(gx, ridge - 0.05, 0), "planks")
		k.tri(Vector3(gx, 2.45, d * 0.5), Vector3(gx, 2.45, -d * 0.5), Vector3(gx, ridge - 0.05, 0), "planks")
	# fascia with a zig-zag edge, fir garland and a string of bulbs along the front
	var fz := hdp - 0.02
	var fy := ridge - tan(pitch) * hdp - 0.12
	k.box(Vector3(0, fy, fz), Vector3(w + 0.7, 0.26, 0.04), trim)
	for i in 16:
		var x0 := -(w + 0.7) * 0.5 + i * (w + 0.7) / 16.0
		var x1 := x0 + (w + 0.7) / 16.0
		k.tri(Vector3(x0, fy - 0.13, fz + 0.021), Vector3((x0 + x1) * 0.5, fy - 0.25, fz + 0.021), Vector3(x1, fy - 0.13, fz + 0.021), trim)
	for i in 14:
		var t := i / 13.0
		var x := lerpf(-w * 0.5 - 0.3, w * 0.5 + 0.3, t)
		var sag := sin(t * PI * 3.0) * 0.06
		k.ball(Vector3(x, fy - 0.2 - absf(sag), fz + 0.08), Vector3(0.17, 0.1, 0.1), "pine", 7, 4)
		if i % 2 == 1:
			k.sphere(Vector3(x, fy - 0.3 - absf(sag), fz + 0.14), 0.035, ["red", "brass", "white"][i % 3], 6, 4)
	if lit:
		for i in 11:
			var x := lerpf(-w * 0.5, w * 0.5, i / 10.0)
			k.sphere(Vector3(x, fy - 0.36, fz + 0.12), 0.03, "lamp_glow", 6, 4)
	# name board on the ridge
	var sign_col: String = ["paint_white", "cream", "paint_yellow"][rng.randi() % 3]
	k.bbox(Vector3(0, ridge + 0.32, hdp * 0.35), Vector3(1.5, 0.42, 0.05), 0.02, sign_col, Basis(Vector3.RIGHT, -0.1))
	k.box(Vector3(0, ridge + 0.32, hdp * 0.35 + 0.03), Vector3(1.1, 0.06, 0.01), trim, Basis(Vector3.RIGHT, -0.1))
	# back shelf and goods
	k.box(Vector3(0, 1.6, -d * 0.5 + 0.22), Vector3(w - 0.3, 0.04, 0.32), "planks_in")
	var kind := rng.randi() % 3
	for i in 14:
		var on_shelf := i >= 8
		var q := Vector3(lerpf(-w * 0.4, w * 0.4, (i % 8) / 7.0 if not on_shelf else (i - 8) / 5.0), 1.62 if on_shelf else 1.07, (-d * 0.5 + 0.22) if on_shelf else (d * 0.5 + 0.1))
		match (kind + i) % 4:
			0:   # gingerbread heart with icing
				var hb := Basis(Vector3.RIGHT, -0.25 if not on_shelf else -1.3)
				k.ball(q + Vector3(-0.045, 0.1, 0), Vector3(0.07, 0.07, 0.015), "leather", 8, 4, hb)
				k.ball(q + Vector3(0.045, 0.1, 0), Vector3(0.07, 0.07, 0.015), "leather", 8, 4, hb)
				k.ball(q + Vector3(0, 0.05, 0), Vector3(0.08, 0.07, 0.015), "leather", 8, 4, hb)
				k.box(q + Vector3(0, 0.12, 0.02), Vector3(0.1, 0.012, 0.005), "white", hb)
			1:   # mugs of Glühwein
				k.cyl(q, 0.045, 0.1, ["red_in", "blue_in", "white_in"][i % 3], 10)
				k.tube(q + Vector3(0.05, 0.03, 0), q + Vector3(0.05, 0.08, 0), 0.02, "white_in", 6)
			2:   # candles
				k.cyl(q, 0.035, 0.16 + (i % 3) * 0.05, ["cream_in", "red_in"][i % 2], 8)
			_:   # wooden toy: a little horse or a car
				k.bbox(q + Vector3(0, 0.06, 0), Vector3(0.16, 0.08, 0.07), 0.015, ["red_in", "green_in", "blue_in", "yellow_in"][i % 4])
				for wx: float in [-0.05, 0.05]:
					k.tube(q + Vector3(wx, 0.025, -0.04), q + Vector3(wx, 0.025, 0.04), 0.025, "wood_dark", 8)
	if lit:
		k.sphere(Vector3(0, 2.3, 0.1), 0.08, "lamp_glow", 8, 5)
		lights.append([k.xf * Vector3(0, 2.0, 0.7), WARM, 1.6, 7.0, rng.randf() < 0.3])


static func bench(k: MeshKit) -> void:
	if k.model("painted_wooden_bench", Vector3.ZERO, 0.85):
		return
	for i in 3:
		k.box(Vector3(0, 0.45, -0.14 + i * 0.14), Vector3(1.7, 0.04, 0.12), "planks")
	for i in 2:
		k.box(Vector3(0, 0.7 + i * 0.16, -0.24), Vector3(1.7, 0.12, 0.04), "planks")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.75, 0.22, 0), Vector3(0.06, 0.45, 0.4), "metal")
		k.box(Vector3(sx * 0.75, 0.65, -0.24), Vector3(0.06, 0.5, 0.05), "metal")


static func crate(k: MeshKit, s := 0.7) -> void:
	if k.model("wooden_crate_01", Vector3.ZERO, s):
		return
	k.box(Vector3(0, s * 0.5, 0), Vector3(s, s, s), "planks")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * s * 0.5, s * 0.5, 0), Vector3(0.04, s * 1.02, s * 1.02), "wood_dark")


static func barrel(k: MeshKit) -> void:
	if k.model("Barrel_01", Vector3.ZERO, 0.9, 0.0, 0.4):
		return
	k.cyl(Vector3.ZERO, 0.3, 0.45, "wood", 10, 0.36)
	k.cyl(Vector3(0, 0.45, 0), 0.36, 0.45, "wood", 10, 0.3)
	k.cyl(Vector3(0, 0.2, 0), 0.34, 0.05, "metal", 10, 0.345, false)
	k.cyl(Vector3(0, 0.65, 0), 0.345, 0.05, "metal", 10, 0.335, false)


static func snowman(k: MeshKit, rng: RandomNumberGenerator) -> void:
	if GameMode.summer() and not k.winter:
		rng.randf()          # keep the dice the same, so the rest of the town stays where it was
		return
	k.sphere(Vector3(0, 0.45, 0), 0.55, "snow", 10, 7, 0.9)
	k.sphere(Vector3(0, 1.15, 0), 0.4, "snow", 10, 7, 0.9)
	k.sphere(Vector3(0, 1.7, 0), 0.28, "snow", 10, 7)
	k.cyl(Vector3(0, 1.7, 0.26), 0.05, 0.25, "orange", 6, 0.0)
	for sx in [-1.0, 1.0]:
		k.sphere(Vector3(sx * 0.1, 1.8, 0.24), 0.03, "black", 5, 3)
		k.box(Vector3(sx * 0.6, 1.3, 0), Vector3(0.6, 0.03, 0.03), "wood_dark", Basis(Vector3(0, 0, 1), sx * 0.5))
	for i in 3:
		k.sphere(Vector3(0, 0.95 + i * 0.18, 0.38 - i * 0.02), 0.03, "black", 5, 3)
	if rng.randf() < 0.6:
		k.cyl(Vector3(0, 1.92, 0), 0.3, 0.03, "black", 10)
		k.cyl(Vector3(0, 1.93, 0), 0.2, 0.3, "black", 10)


static func gift(k: MeshKit, rng: RandomNumberGenerator) -> void:
	var s := Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.2, 0.45), rng.randf_range(0.25, 0.6))
	var col: String = ["red", "green", "blue", "white", "yellow"][rng.randi() % 5]
	k.box(Vector3(0, s.y * 0.5, 0), s, col)
	k.box(Vector3(0, s.y * 0.5, 0), Vector3(s.x * 1.02, s.y * 1.02, s.z * 0.16), "gold")
	k.box(Vector3(0, s.y * 0.5, 0), Vector3(s.x * 0.16, s.y * 1.02, s.z * 1.02), "gold")


static func sled(k: MeshKit) -> void:
	if GameMode.summer() and not k.winter:
		return
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.2, 0.03, 0), Vector3(0.04, 0.04, 1.2), "metal")
		for z in [-0.35, 0.35]:
			k.box(Vector3(sx * 0.2, 0.14, z), Vector3(0.04, 0.2, 0.04), "wood")
	for i in 4:
		k.box(Vector3(-0.18 + i * 0.12, 0.25, 0), Vector3(0.09, 0.03, 1.0), "planks")


static func drift(k: MeshKit, rng: RandomNumberGenerator, r: float) -> void:
	k.sphere(Vector3(0, -r * 0.08, 0), r, "snow", 10, 6, rng.randf_range(0.22, 0.4))


## Sagging rope or cable from a to b (world space). Returns the points along it.
static func rope(k: MeshKit, a: Vector3, b: Vector3, sag: float, parts: int, thick: float, mat: String) -> Array[Vector3]:
	k.xf = Transform3D.IDENTITY
	var pts: Array[Vector3] = []
	for i in parts + 1:
		var t := float(i) / parts
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	for i in parts:
		var p := pts[i]
		var q := pts[i + 1]
		var z := (q - p).normalized()
		var x := Vector3.UP.cross(z).normalized()
		var y := z.cross(x)
		k.box((p + q) * 0.5, Vector3(thick, thick, p.distance_to(q) + 0.01), mat, Basis(x, y, z))
	return pts


## String of fairy lights. state: 0 working, 1 partly dead and flickering, 2 dead.
static func chain(k: MeshKit, rng: RandomNumberGenerator, a: Vector3, b: Vector3, sag: float, state: int, one_colour := false) -> void:
	var count := maxi(4, int(a.distance_to(b) / 0.5))
	var pts := rope(k, a, b, sag, count, 0.018, "black")
	var dead_from := rng.randi_range(0, count)
	for i in range(1, count):
		var col := BULB_COLS[4] if one_colour else BULB_COLS[(i + rng.randi() % 2) % 4]
		if state == 2 or (state == 1 and (i > dead_from or rng.randf() < 0.3)):
			col = DEAD
		elif rng.randf() < 0.08:
			col = DEAD
		bulbs.append([pts[i] - Vector3(0, 0.05, 0), col])
		# frozen: little icicles hang from the cable
		if rng.randf() < 0.35:
			var l := rng.randf_range(0.06, 0.28)
			k.cyl(pts[i] + Vector3(0.12, -l, 0), 0.0, l, "ice", 4, 0.015, false)


static func nutcracker(k: MeshKit) -> void:
	# a 3.8 m painted wooden soldier on a round plinth, like the Erzgebirge ones
	k.cyl(Vector3(0, 0, 0), 0.8, 0.16, "wood_dark", 18)
	k.cyl(Vector3(0, 0.16, 0), 0.72, 0.1, "paint_green", 18)
	k.cyl(Vector3(0, 0.26, 0), 0.74, 0.03, "brass", 18)
	for sx: float in [-1.0, 1.0]:
		# boots with rounded toes and a turned-down top
		k.capsule(Vector3(sx * 0.21, 0.42, 0), Vector3(sx * 0.21, 0.95, 0), 0.15, "black", 12)
		k.ball(Vector3(sx * 0.21, 0.38, 0.13), Vector3(0.15, 0.11, 0.24), "black", 12, 6)
		k.tube(Vector3(sx * 0.21, 0.92, 0), Vector3(sx * 0.21, 1.02, 0), 0.175, "black", 14)
		# white breeches with a red side stripe
		k.capsule(Vector3(sx * 0.2, 1.02, 0), Vector3(sx * 0.19, 1.55, 0), 0.155, "white", 12)
		k.box(Vector3(sx * 0.345, 1.28, 0), Vector3(0.02, 0.5, 0.05), "red")
	# coat: flared skirt, waist, chest, collar
	k.tube(Vector3(0, 1.45, 0), Vector3(0, 1.8, 0), 0.47, "red", 20, 0.4, false)
	k.tube(Vector3(0, 1.8, 0), Vector3(0, 2.45, 0), 0.4, "red", 20, 0.43, false)
	k.ball(Vector3(0, 2.46, 0), Vector3(0.43, 0.14, 0.4), "red", 20, 6)
	k.tube(Vector3(0, 1.78, 0), Vector3(0, 1.92, 0), 0.415, "black", 20)
	k.bbox(Vector3(0, 1.85, 0.41), Vector3(0.2, 0.17, 0.05), 0.02, "brass")
	k.tube(Vector3(0, 2.52, 0), Vector3(0, 2.62, 0), 0.22, "paint_yellow", 16)
	# front frogging: brass buttons and gold cords across the chest
	for i in 4:
		var y := 2.0 + i * 0.12
		k.sphere(Vector3(0, y, 0.425), 0.035, "brass", 8, 4)
		for sx: float in [-1.0, 1.0]:
			k.tube(Vector3(sx * 0.03, y, 0.42), Vector3(sx * 0.2, y + 0.02, 0.38), 0.012, "paint_yellow", 5)
	# epaulettes with fringes
	for sx: float in [-1.0, 1.0]:
		k.ball(Vector3(sx * 0.4, 2.48, 0), Vector3(0.14, 0.05, 0.14), "paint_yellow", 12, 5)
		for f in 7:
			var ang := (f - 3) * 0.32
			var p := Vector3(sx * (0.46 + 0.02 * absf(f - 3)), 2.46, sin(ang) * 0.12)
			k.tube(p, p + Vector3(sx * 0.03, -0.12, 0), 0.012, "paint_yellow", 4)
	# arms: sleeve, white cuff, gloved hand; right hand holds a sceptre
	for sx: float in [-1.0, 1.0]:
		var sh := Vector3(sx * 0.5, 2.38, 0)
		var el := Vector3(sx * 0.6, 1.92, 0.12)
		var wr := Vector3(sx * 0.52, 1.58, 0.32) if sx > 0.0 else Vector3(sx * 0.64, 1.55, 0.05)
		k.capsule(sh, el, 0.13, "red", 12)
		k.capsule(el, wr, 0.115, "red", 12)
		k.tube(wr + (el - wr).normalized() * 0.04, wr - (el - wr).normalized() * 0.04, 0.125, "white", 12)
		k.ball(wr - (el - wr).normalized() * 0.1, Vector3(0.1, 0.1, 0.1), "white", 10, 6)
	var hand := Vector3(0.52, 1.48, 0.42)
	k.tube(hand + Vector3(0, -0.55, 0.02), hand + Vector3(0, 1.0, -0.05), 0.03, "brass", 8)
	k.sphere(hand + Vector3(0, 1.05, -0.05), 0.08, "brass", 10, 6)
	k.ball(hand + Vector3(0, 1.22, -0.05), Vector3(0.05, 0.12, 0.05), "red", 8, 5)
	# head: rounded jaw, big nose, painted eyes, white beard and hair, black moustache
	k.capsule(Vector3(0, 2.68, 0), Vector3(0, 3.08, 0), 0.29, "skin", 16)
	k.ball(Vector3(0, 2.82, 0.2), Vector3(0.24, 0.2, 0.14), "white", 14, 6)
	k.ball(Vector3(0, 2.66, 0.13), Vector3(0.2, 0.2, 0.17), "white", 14, 6)
	k.box(Vector3(0, 2.86, 0.32), Vector3(0.2, 0.06, 0.04), "red")
	k.ball(Vector3(0, 2.97, 0.33), Vector3(0.24, 0.05, 0.05), "black", 10, 4)
	k.ball(Vector3(0, 3.05, 0.32), Vector3(0.06, 0.09, 0.08), "skin", 10, 6)
	for sx: float in [-1.0, 1.0]:
		k.ball(Vector3(sx * 0.11, 3.14, 0.25), Vector3(0.06, 0.045, 0.03), "white", 10, 5)
		k.sphere(Vector3(sx * 0.11, 3.14, 0.276), 0.026, "black", 8, 4)
		k.box(Vector3(sx * 0.11, 3.21, 0.26), Vector3(0.11, 0.025, 0.03), "black")
		k.ball(Vector3(sx * 0.17, 3.0, 0.24), Vector3(0.05, 0.04, 0.02), "red", 8, 4)
		k.ball(Vector3(sx * 0.27, 2.95, -0.04), Vector3(0.07, 0.32, 0.16), "white", 10, 6)
	# tall busby: black fur cylinder, brass badge and band, red plume
	k.tube(Vector3(0, 3.2, 0), Vector3(0, 3.82, 0), 0.32, "black", 20, 0.35)
	k.ball(Vector3(0, 3.82, 0), Vector3(0.35, 0.08, 0.35), "black", 20, 6)
	k.tube(Vector3(0, 3.24, 0), Vector3(0, 3.31, 0), 0.325, "brass", 20)
	k.ball(Vector3(0, 3.55, 0.33), Vector3(0.11, 0.13, 0.03), "brass", 12, 6)
	k.ball(Vector3(0, 3.55, 0.35), Vector3(0.05, 0.06, 0.02), "red", 10, 5)
	k.capsule(Vector3(0.2, 3.78, 0.15), Vector3(0.24, 4.18, 0.12), 0.06, "red", 10, 0.03)
	k.ball(Vector3(0, 3.14, 0.06), Vector3(0.26, 0.08, 0.26), "white", 14, 5)


static func speaker(k: MeshKit) -> void:
	k.cyl(Vector3.ZERO, 0.11, 5.6, "wood_dark", 7, 0.08)
	k.box(Vector3(0, 5.2, 0), Vector3(0.9, 0.08, 0.08), "metal")
	var keep := k.xf
	for s in [-1.0, 1.0]:
		var sg: float = s
		k.xf = keep * Transform3D(Basis(Vector3(0, 0, 1), -sg * 1.35), Vector3(sg * 0.3, 5.2, 0))
		k.cyl(Vector3.ZERO, 0.06, 0.2, "steel", 8)
		k.cyl(Vector3(0, 0.2, 0), 0.07, 0.42, "steel", 10, 0.27)
		k.cyl(Vector3(0, 0.2, 0), 0.06, 0.3, "black", 8, 0.2)
	k.xf = keep


static func chapel(k: MeshKit, rng: RandomNumberGenerator) -> void:
	var w := 6.0
	var d := 10.0
	k.box(Vector3(0, -0.6, 0), Vector3(w + 0.4, 1.6, d + 0.4), "stone")
	Interior.chapel(k, rng)
	var pitch := 0.95
	var ridge := 4.4 + tan(pitch) * w * 0.5
	for sz in [-1.0, 1.0]:
		var gz: float = sz * d * 0.5
		k.tri(Vector3(-w * 0.5, 4.4, gz), Vector3(w * 0.5, 4.4, gz), Vector3(0, ridge, gz), "plaster")
		k.tri(Vector3(w * 0.5, 4.4, gz), Vector3(-w * 0.5, 4.4, gz), Vector3(0, ridge, gz), "plaster")
	var slab := (w * 0.5 + 0.5) / cos(pitch)
	for s in [-1.0, 1.0]:
		var sg: float = s
		var mid := Vector3(sg * (w * 0.5 + 0.5) * 0.5, ridge - tan(pitch) * (w * 0.5 + 0.5) * 0.5, 0)
		k.box(mid, Vector3(slab, 0.2, d + 1.0), "roof", Basis(Vector3(0, 0, 1), -pitch * sg))
		for i in 3:
			var z := -d * 0.5 + d * (i + 0.5) / 3.0
			k.box(Vector3(sg * w * 0.5, 2.6, z), Vector3(0.06, 2.0, 0.8), "glass_lit" if i == 1 else "glass_dark")
			k.box(Vector3(sg * w * 0.5, 2.6, z), Vector3(0.1, 2.0, 0.06), "stone")
	# tower with spire and cross
	k.box(Vector3(0, 7.2, d * 0.5 - 1.6), Vector3(3.0, 7.6, 3.0), "plaster")
	k.box(Vector3(0, 3.3, d * 0.5 - 1.6), Vector3(3.0, 0.2, 3.0), "wood_dark")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.35, 1.7, d * 0.5 - 2.95), Vector3(0.28, 3.2, 0.28), "wood_dark")
	k.box(Vector3(0, 9.6, d * 0.5 - 1.6), Vector3(3.1, 1.4, 1.2), "black")
	k.box(Vector3(0, 9.6, d * 0.5 - 1.6), Vector3(1.2, 1.4, 3.1), "black")
	k.cyl(Vector3(0, 11.0, d * 0.5 - 1.6), 2.4, 6.5, "roof", 4, 0.0)
	k.box(Vector3(0, 18.1, d * 0.5 - 1.6), Vector3(0.1, 1.3, 0.1), "gold")
	k.box(Vector3(0, 18.3, d * 0.5 - 1.6), Vector3(0.7, 0.1, 0.1), "gold")
	k.box(Vector3(-0.72, 1.2, d * 0.5 + 0.55), Vector3(0.08, 2.35, 1.3), "wood_dark", Basis(Vector3.UP, -0.25))
	k.box(Vector3(0, 2.5, d * 0.5 + 0.02), Vector3(1.7, 0.2, 0.36), "wood_dark")
	k.box(Vector3(0, 0.02, d * 0.5 + 0.8), Vector3(2.4, 0.2, 1.6), "stone")
	# graves beside it
	for i in 7:
		var gp := Vector3(-w * 0.5 - 2.0 - (i % 2) * 1.8, 0, -3.0 + (i / 2) * 2.2)
		if rng.randf() < 0.5:
			k.box(gp + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.14), "stone", Basis(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12)))
		else:
			k.box(gp + Vector3(0, 0.6, 0), Vector3(0.08, 1.2, 0.08), "wood_dark")
			k.box(gp + Vector3(0, 0.85, 0), Vector3(0.6, 0.08, 0.08), "wood_dark")


# ---------------------------------------------------------- mechanical things

## Christmas pyramid: the frame. The turning part comes from pyramid_rotor().
static func pyramid(k: MeshKit) -> void:
	var tiers: Array = [[0.0, 2.0], [2.2, 1.5], [4.0, 1.05]]
	k.cyl(Vector3.ZERO, 2.3, 0.5, "planks", 8)
	for t in tiers.size():
		var y: float = tiers[t][0] + 0.5
		var r: float = tiers[t][1]
		var h := 2.2 if t == 0 else 1.8
		for i in 8:
			var a := TAU * i / 8.0
			var p := Vector3(cos(a) * r, y, sin(a) * r)
			k.cyl(p, 0.06, h, "paint_white", 6)
			k.cyl(p + Vector3(0, 0.9, 0) * 0.0 + Vector3(cos(a), 0, sin(a)) * 0.22, 0.03, 0.22, "white", 5)
			k.sphere(p + Vector3(cos(a), 0, sin(a)) * 0.22 + Vector3(0, 0.27, 0), 0.04, "candle", 5, 3)
		k.cyl(Vector3(0, y + h - 0.02, 0), r + 0.25, 0.1, "paint_red", 8)
		k.cyl(Vector3(0, y + h + 0.08, 0), r + 0.1, 0.12, "snow", 8)
	k.cyl(Vector3(0, 0.5, 0), 0.07, 7.4, "wood_dark", 6)


static func pyramid_rotor() -> MeshKit:
	var k := MeshKit.new()
	var tiers: Array = [[0.62, 1.3, 6], [2.82, 0.95, 5], [4.62, 0.6, 4]]
	var coats: Array[String] = ["red", "green", "blue", "white", "yellow"]
	for t in tiers:
		var y: float = t[0]
		var r: float = t[1]
		var n: int = t[2]
		k.cyl(Vector3(0, y, 0), r + 0.35, 0.06, "planks", 10)
		for i in n:
			var a := TAU * i / n
			var p := Vector3(cos(a) * r, y + 0.06, sin(a) * r)
			k.cyl(p, 0.14, 0.5, coats[i % coats.size()], 7, 0.09)
			k.sphere(p + Vector3(0, 0.6, 0), 0.1, "skin", 6, 4)
			k.cyl(p + Vector3(0, 0.66, 0), 0.1, 0.2, coats[(i + 2) % coats.size()], 6, 0.0)
	# fan on top
	for i in 10:
		var a := TAU * i / 10.0
		var dir := Vector3(cos(a), 0, sin(a))
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.5)
		k.box(Vector3(0, 7.7, 0) + dir * 1.5, Vector3(2.4, 0.03, 0.55), "planks", b)
	k.sphere(Vector3(0, 7.9, 0), 0.16, "gold", 8, 5)
	return k


static func carousel(k: MeshKit) -> void:
	k.cyl(Vector3.ZERO, 4.4, 0.3, "planks", 16)
	k.cyl(Vector3(0, 0.3, 0), 0.7, 4.0, "paint_red", 10)
	k.cyl(Vector3(0, 1.8, 0), 0.74, 0.2, "gold", 10)


static func carousel_rotor(rng: RandomNumberGenerator) -> MeshKit:
	var k := MeshKit.new()
	k.cyl(Vector3(0, 0.3, 0), 4.1, 0.06, "paint_white", 16)
	k.cyl(Vector3(0, 4.2, 0), 4.7, 1.7, "stripes_red", 16, 0.4)
	k.cyl(Vector3(0, 3.85, 0), 4.7, 0.36, "stripes_green", 16, 4.7, false)
	k.sphere(Vector3(0, 6.05, 0), 0.25, "gold", 8, 5)
	var cols: Array[String] = ["white", "black", "paint_white", "orange"]
	for i in 8:
		var a := TAU * i / 8.0
		var b := Basis(Vector3.UP, -a)
		var c := Vector3(cos(a), 0, sin(a)) * 3.2
		var up := 1.05 + 0.25 * sin(i * 2.4)
		k.cyl(c + Vector3(0, 0.3, 0), 0.03, 3.6, "gold", 5)
		if i == 5:
			continue  # one horse is missing
		var col := cols[rng.randi() % cols.size()]
		k.box(c + Vector3(0, up, 0), Vector3(0.34, 0.42, 1.1), col, b)
		k.box(c + Vector3(0, up + 0.42, 0) + b * Vector3(0, 0, 0.5), Vector3(0.22, 0.6, 0.26), col, b * Basis(Vector3.RIGHT, 0.5))
		k.box(c + Vector3(0, up + 0.72, 0) + b * Vector3(0, 0, 0.78), Vector3(0.2, 0.22, 0.46), col, b)
		k.box(c + Vector3(0, up + 0.24, 0), Vector3(0.38, 0.08, 0.42), "red", b)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.box(c + b * Vector3(sx * 0.12, up - 0.5, sz * 0.4), Vector3(0.09, 0.6, 0.09), col, b)
	return k


## Toy train that circles the big tree on a ring of track (radius r).
static func train_track(k: MeshKit, r: float) -> void:
	var n := 72
	for i in n:
		var a := TAU * i / n
		var b := Basis(Vector3.UP, -a)
		var c := Vector3(cos(a), 0, sin(a)) * r
		k.box(c + Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.14), "wood_dark", b)
		for s in [-1.0, 1.0]:
			var sg: float = s
			k.box(Vector3(cos(a), 0, sin(a)) * (r + sg * 0.3) + Vector3(0, 0.09, 0), Vector3(0.05, 0.06, TAU * r / n + 0.03), "steel", b)


static func train(r: float) -> MeshKit:
	var k := MeshKit.new()
	var cols: Array[String] = ["black", "red", "green", "blue"]
	for i in 4:
		var a := -i * (1.75 / r)
		var b := Basis(Vector3.UP, -a)
		var c := Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 0.12, 0)
		k.box(c + Vector3(0, 0.12, 0), Vector3(0.6, 0.12, 1.5), "black", b)
		if i == 0:
			k.xf = Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0.5, 0) + b * Vector3(0, 0, -0.2))
			k.cyl(Vector3.ZERO, 0.28, 0.95, "paint_green", 10)
			k.xf = Transform3D.IDENTITY
			k.box(c + Vector3(0, 0.62, 0) + b * Vector3(0, 0, -0.5), Vector3(0.62, 0.9, 0.5), "paint_red", b)
			k.cyl(c + Vector3(0, 0.75, 0) + b * Vector3(0, 0, 0.5), 0.08, 0.35, "black", 8, 0.12)
			k.sphere(c + Vector3(0, 0.5, 0) + b * Vector3(0, 0, 0.78), 0.09, "lamp_glow", 6, 4)
		else:
			k.box(c + Vector3(0, 0.45, 0), Vector3(0.58, 0.55, 1.4), "paint_" + ["red", "green", "blue", "yellow"][i], b)
			k.box(c + Vector3(0, 0.76, 0), Vector3(0.5, 0.12, 1.3), "snow", b)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.xf = Transform3D(b * Basis(Vector3(0, 0, 1), PI * 0.5), c + b * Vector3(sx * 0.3 + 0.03, 0.02, sz * 0.45))
				k.cyl(Vector3.ZERO, 0.13, 0.06, cols[0], 8)
				k.xf = Transform3D.IDENTITY
	return k


# ------------------------------------------------------------------ cable car

static func cable_tower(k: MeshKit, h: float) -> void:
	k.box(Vector3(0, -0.6, 0), Vector3(3.2, 1.6, 3.2), "concrete")
	k.cyl(Vector3(0, 0.2, 0), 1.0, h - 0.2, "steel", 4, 0.4, false)
	for i in int(h / 2.5):
		var y := 1.5 + i * 2.5
		var r := lerpf(1.0, 0.4, y / h) + 0.03
		k.cyl(Vector3(0, y, 0), r, 0.12, "metal", 4, r - 0.02, false)
	k.box(Vector3(0, h, 0), Vector3(6.0, 0.35, 0.5), "steel")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 2.6, h + 0.3, 0), Vector3(0.3, 0.3, 1.6), "metal")
	k.sphere(Vector3(0, h + 0.3, 0), 0.5, "snow", 8, 4, 0.5)


## Gondola hanging from the origin (the cable clamp).
static func gondola(k: MeshKit, col: String) -> void:
	k.box(Vector3(0, -0.05, 0), Vector3(0.3, 0.25, 0.9), "metal")
	k.box(Vector3(0, -1.0, 0), Vector3(0.12, 1.9, 0.12), "metal")
	k.box(Vector3(0, -1.95, 0), Vector3(1.9, 0.12, 2.5), "steel")
	k.box(Vector3(0, -2.05, 0), Vector3(1.7, 0.2, 2.3), "snow")
	k.box(Vector3(0, -3.6, 0), Vector3(1.8, 1.1, 2.6), col)
	k.box(Vector3(0, -4.2, 0), Vector3(1.6, 0.12, 2.4), "metal")
	k.box(Vector3(0, -2.6, 0), Vector3(1.74, 0.9, 2.54), "glass_dark")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.87, -2.6, sz * 1.27), Vector3(0.08, 0.95, 0.08), col)


# ------------------------------------------------------------------ town streets

const SODIUM := Color(1.0, 0.62, 0.30)


## Modern street light: tapered steel mast, bent arm over the road (local -Z), flat lamp head.
static func street_light(k: MeshKit, lit: bool, flicker := false) -> void:
	k.cyl(Vector3(0, -0.2, 0), 0.16, 0.5, "concrete", 8)
	k.cyl(Vector3(0, 0.3, 0), 0.085, 6.6, "steel", 8, 0.05)
	k.box(Vector3(0.0, 1.1, 0.09), Vector3(0.12, 0.3, 0.02), "metal")
	var prev := Vector3(0, 6.9, 0)
	for i in 5:
		var a := (i + 1) / 5.0 * PI * 0.5
		var q := Vector3(0, 6.9 + sin(a) * 0.7, -(1.0 - cos(a)) * 1.2)
		k.tube(prev, q, 0.045, "steel", 6)
		prev = q
	k.tube(prev, prev + Vector3(0, 0, -0.5), 0.04, "steel", 6)
	var head := prev + Vector3(0, -0.02, -0.75)
	k.bbox(head, Vector3(0.3, 0.12, 0.72), 0.04, "metal")
	k.box(head + Vector3(0, -0.065, 0), Vector3(0.22, 0.02, 0.56), "lamp_sodium" if lit else "glass_dark")
	k.ball(head + Vector3(0, 0.1, 0), Vector3(0.17, 0.07, 0.36), "snow", 8, 4)
	if lit:
		lights.append([k.xf * (head + Vector3(0, -0.5, 0)), SODIUM, 3.4, 21.0, flicker])


## Wooden pole with a cross-arm along local X. Returns the world point where the middle wire sits.
static func utility_pole(k: MeshKit, transformer := false) -> Vector3:
	k.cyl(Vector3(0, -0.5, 0), 0.15, 9.2, "wood_dark", 8, 0.1)
	k.box(Vector3(0, 8.2, 0), Vector3(2.0, 0.11, 0.11), "wood_dark")
	k.tube(Vector3(-0.55, 7.6, 0), Vector3(0, 8.15, 0), 0.02, "steel", 4)
	k.tube(Vector3(0.55, 7.6, 0), Vector3(0, 8.15, 0), 0.02, "steel", 4)
	for x: float in [-0.75, 0.0, 0.75]:
		k.cyl(Vector3(x, 8.25, 0), 0.04, 0.16, "white", 6, 0.03)
	k.box(Vector3(0, 8.3, 0), Vector3(2.0, 0.07, 0.14), "snow")
	if transformer:
		k.cyl(Vector3(0.0, 6.3, 0.34), 0.26, 0.8, "grey", 10)
		k.cyl(Vector3(0.0, 7.1, 0.34), 0.27, 0.05, "metal", 10)
		k.box(Vector3(0, 6.7, 0.14), Vector3(0.12, 0.5, 0.2), "metal")
		k.ball(Vector3(0.0, 7.2, 0.34), Vector3(0.24, 0.07, 0.24), "snow", 8, 4)
	# a reflector band and an old notice at eye height
	k.cyl(Vector3(0, 1.5, 0), 0.142, 0.1, "hazard", 8)
	return k.xf * Vector3(0, 8.42, 0)


## Road sign facing local +Z. kinds: town, speed, yield, bus.
static func road_sign(k: MeshKit, kind: String) -> void:
	match kind:
		"town":
			for x: float in [-0.5, 0.5]:
				k.cyl(Vector3(x, -0.3, 0), 0.03, 2.7, "steel", 6)
			k.box(Vector3(0, 1.95, 0.035), Vector3(1.5, 0.9, 0.03), "sign_yellow")
			k.box(Vector3(0, 1.95, 0.03), Vector3(1.56, 0.96, 0.02), "black")
			k.box(Vector3(0, 2.44, 0.03), Vector3(1.5, 0.08, 0.1), "snow")
		"speed":
			k.cyl(Vector3(0, -0.3, 0), 0.03, 3.0, "steel", 6)
			k.tube(Vector3(0, 2.3, 0.03), Vector3(0, 2.3, 0.045), 0.36, "sign_red", 20)
			k.tube(Vector3(0, 2.3, 0.04), Vector3(0, 2.3, 0.052), 0.28, "white", 20)
			k.ball(Vector3(0, 2.66, 0.03), Vector3(0.2, 0.05, 0.05), "snow", 8, 4)
		"yield":
			k.cyl(Vector3(0, -0.3, 0), 0.03, 2.9, "steel", 6)
			var c := Vector3(0, 2.3, 0.035)
			k.tri(c + Vector3(-0.42, 0.3, 0), c + Vector3(0, -0.42, 0), c + Vector3(0.42, 0.3, 0), "sign_red")
			k.tri(c + Vector3(0.42, 0.3, 0), c + Vector3(0, -0.42, 0), c + Vector3(-0.42, 0.3, 0), "grey")
			var d := Vector3(0, 2.3, 0.045)
			k.tri(d + Vector3(-0.27, 0.215, 0), d + Vector3(0, -0.25, 0), d + Vector3(0.27, 0.215, 0), "white")
		_:
			k.cyl(Vector3(0, -0.3, 0), 0.03, 3.0, "steel", 6)
			k.tube(Vector3(0, 2.4, 0.03), Vector3(0, 2.4, 0.045), 0.3, "plastic_green", 20)
			k.tube(Vector3(0, 2.4, 0.04), Vector3(0, 2.4, 0.052), 0.25, "sign_yellow", 20)
			k.box(Vector3(-0.08, 2.4, 0.056), Vector3(0.045, 0.26, 0.006), "plastic_green")
			k.box(Vector3(0.08, 2.4, 0.056), Vector3(0.045, 0.26, 0.006), "plastic_green")
			k.box(Vector3(0, 2.4, 0.056), Vector3(0.16, 0.045, 0.006), "plastic_green")
			k.box(Vector3(0, 1.95, 0.03), Vector3(0.4, 0.3, 0.02), "white")


## Bus shelter, open towards local +Z: steel frame, glass back and ends, bench, lit poster case.
static func bus_shelter(k: MeshKit, lit: bool) -> void:
	var w := 3.4
	var d := 1.5
	for sx: float in [-1.0, 1.0]:
		for z: float in [-d * 0.5, d * 0.5]:
			k.box(Vector3(sx * w * 0.5, 1.2, z), Vector3(0.07, 2.4, 0.07), "metal")
	k.box(Vector3(0, 2.45, 0.1), Vector3(w + 0.3, 0.07, d + 0.5), "metal", Basis(Vector3.RIGHT, -0.06))
	k.box(Vector3(0, 2.6, 0.1), Vector3(w + 0.2, 0.22, d + 0.4), "snow", Basis(Vector3.RIGHT, -0.06))
	k.box(Vector3(0, 1.3, -d * 0.5), Vector3(w - 0.08, 1.9, 0.02), "glass_clear")
	k.box(Vector3(-w * 0.5, 1.3, 0), Vector3(0.02, 1.9, d - 0.08), "glass_clear")
	k.box(Vector3(0, 0.3, -d * 0.5), Vector3(w, 0.06, 0.05), "metal")
	k.box(Vector3(0, 2.28, -d * 0.5), Vector3(w, 0.06, 0.05), "metal")
	# poster case at the other end
	k.box(Vector3(w * 0.5, 1.3, 0), Vector3(0.14, 1.9, d - 0.2), "metal")
	k.box(Vector3(w * 0.5 - 0.08, 1.3, 0), Vector3(0.02, 1.7, d - 0.4), "glass_cold" if lit else "glass_dark")
	# bench
	k.box(Vector3(-0.3, 0.48, -d * 0.5 + 0.3), Vector3(2.2, 0.05, 0.36), "planks")
	for x: float in [-1.2, 0.6]:
		k.box(Vector3(x, 0.24, -d * 0.5 + 0.3), Vector3(0.05, 0.46, 0.3), "metal")
	k.box(Vector3(0, 0.03, 0.1), Vector3(w + 0.4, 0.1, d + 0.7), "concrete")


## A row of post boxes on a rail, facing local +Z.
static func mailboxes(k: MeshKit, n: int) -> void:
	var w := n * 0.42
	for x: float in [-w * 0.5 + 0.1, w * 0.5 - 0.1]:
		k.box(Vector3(x, 0.45, 0), Vector3(0.07, 1.3, 0.07), "wood_dark")
	k.box(Vector3(0, 1.0, 0), Vector3(w, 0.07, 0.09), "wood_dark")
	var cols: Array[String] = ["plastic_green", "trim_dark", "sign_red", "grey", "plastic_green", "sign_blue"]
	for i in n:
		var x := -w * 0.5 + 0.21 + i * 0.42
		k.bbox(Vector3(x, 1.24, 0.04), Vector3(0.34, 0.4, 0.26), 0.03, cols[i % cols.size()])
		k.box(Vector3(x, 1.33, 0.175), Vector3(0.26, 0.03, 0.01), "black")
		k.ball(Vector3(x, 1.46, 0.04), Vector3(0.17, 0.06, 0.14), "snow", 7, 4)


static func litter_bin(k: MeshKit) -> void:
	if k.model("metal_trash_can", Vector3.ZERO, 0.95, 0.0, 0.5):
		if randf() < 0.5:
			k.model("trashbag", Vector3(0.6, 0, 0.2), 0.5, randf() * TAU, 0.3)
		return
	k.cyl(Vector3(0.22, -0.2, 0), 0.03, 1.3, "steel", 6)
	k.cyl(Vector3(0, 0.45, 0), 0.19, 0.55, "plastic_green", 10, 0.22)
	k.cyl(Vector3(0, 1.0, 0), 0.24, 0.05, "plastic_green", 10)
	k.ball(Vector3(0, 1.07, 0), Vector3(0.22, 0.07, 0.22), "snow", 8, 4)


## Fire hydrant with the tall marker that shows where it is under the snow.
static func hydrant(k: MeshKit) -> void:
	if k.model("fire_hydrant", Vector3.ZERO, 0.8, 0.0, 0.5):
		# keep the tall marker that shows where it is under the snow
		k.cyl(Vector3(0.3, -0.2, 0), 0.02, 2.4, "sign_red", 5)
		k.box(Vector3(0.3, 2.25, 0), Vector3(0.22, 0.22, 0.02), "sign_red")
		k.box(Vector3(0.3, 2.25, 0.012), Vector3(0.12, 0.12, 0.01), "white")
		return
	k.cyl(Vector3(0, -0.1, 0), 0.11, 0.75, "sign_red", 8)
	k.ball(Vector3(0, 0.68, 0), Vector3(0.13, 0.1, 0.13), "sign_red", 8, 4)
	k.tube(Vector3(-0.18, 0.45, 0), Vector3(0.18, 0.45, 0), 0.055, "sign_red", 6)
	k.cyl(Vector3(0.3, -0.2, 0), 0.02, 2.4, "sign_red", 5)
	k.box(Vector3(0.3, 2.25, 0), Vector3(0.22, 0.22, 0.02), "sign_red")
	k.box(Vector3(0.3, 2.25, 0.012), Vector3(0.12, 0.12, 0.01), "white")


## Parked car, nose towards local -Z. With `snowy` it has stood there for days.
static func car(k: MeshKit, sr: RandomNumberGenerator, snowy: bool) -> void:
	var cols: Array[String] = ["car_red", "car_blue", "car_silver", "car_white", "car_black", "car_silver", "car_olive", "car_white"]
	var col := cols[sr.randi() % cols.size()]
	var estate := sr.randf() < 0.5
	var cl := 2.9 if estate else 2.15       # cabin length
	var cz := 0.62 if estate else 0.3
	k.bbox(Vector3(0, 0.62, 0), Vector3(1.78, 0.56, 4.35), 0.12, col)
	k.bbox(Vector3(0, 1.17, cz), Vector3(1.6, 0.6, cl), 0.16, col)
	# glass all round
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.795, 1.2, cz), Vector3(0.02, 0.36, cl - 0.55), "glass_dark")
		k.box(Vector3(sx * 0.8, 1.2, cz - 0.15), Vector3(0.022, 0.4, 0.06), col)
	k.box(Vector3(0, 1.2, cz - cl * 0.5 + 0.04), Vector3(1.36, 0.36, 0.1), "glass_dark", Basis(Vector3.RIGHT, -0.5))
	k.box(Vector3(0, 1.2, cz + cl * 0.5 - 0.04), Vector3(1.36, 0.36, 0.1), "glass_dark", Basis(Vector3.RIGHT, 0.45))
	# bumpers, lamps, plates, mirrors
	k.bbox(Vector3(0, 0.45, -2.16), Vector3(1.8, 0.24, 0.16), 0.05, "plastic_grey")
	k.bbox(Vector3(0, 0.45, 2.16), Vector3(1.8, 0.24, 0.16), 0.05, "plastic_grey")
	k.box(Vector3(0, 0.66, -2.18), Vector3(0.9, 0.12, 0.02), "black")
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.64, 0.72, -2.165), Vector3(0.36, 0.13, 0.03), "white")
		k.box(Vector3(sx * 0.66, 0.74, 2.165), Vector3(0.32, 0.14, 0.03), "tail_red")
		k.box(Vector3(sx * 0.95, 1.0, cz - cl * 0.5 + 0.35), Vector3(0.16, 0.1, 0.08), col)
	k.box(Vector3(0, 0.47, -2.245), Vector3(0.5, 0.11, 0.01), "white")
	k.box(Vector3(0, 0.47, 2.245), Vector3(0.5, 0.11, 0.01), "white")
	for sx: float in [-1.0, 1.0]:
		for z: float in [-1.38, 1.36]:
			k.tube(Vector3(sx * 0.68, 0.32, z), Vector3(sx * 0.9, 0.32, z), 0.32, "black", 12)
			k.tube(Vector3(sx * 0.9, 0.32, z), Vector3(sx * 0.91, 0.32, z), 0.17, "grey", 8)
	k.box(Vector3(0, 0.3, 0), Vector3(1.5, 0.2, 3.6), "black")
	if snowy:
		k.ball(Vector3(0, 1.5, cz), Vector3(0.78, sr.randf_range(0.12, 0.2), cl * 0.5), "snow", 16, 6)
		k.ball(Vector3(0, 0.93, -1.5), Vector3(0.84, sr.randf_range(0.08, 0.14), 0.75), "snow", 16, 6)
		if not estate:
			k.ball(Vector3(0, 0.93, 1.75), Vector3(0.84, 0.1, 0.5), "snow", 9, 5)
		k.ball(Vector3(0, 1.22, cz - cl * 0.5 - 0.02), Vector3(0.7, 0.2, 0.2), "snow", 8, 4, Basis(Vector3.RIGHT, -0.5))
		for sx: float in [-1.0, 1.0]:
			k.ball(Vector3(sx * 0.95, -0.02, 0.1), Vector3(0.3, 0.2, 1.9), "snow", 12, 5)
	else:
		k.ball(Vector3(0, 1.48, cz), Vector3(0.74, 0.035, cl * 0.46), "snow", 8, 4)
