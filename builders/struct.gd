class_name Struct
extends RefCounted
## Building blocks for the places of the valley: concrete rooms, fences, towers,
## huts, masts, mine timber, wrecks. Everything goes into a MeshKit at its transform.


## A straight wall from `origin` (floor level) along `along` (X or Z axis).
## holes: [from, to, bottom, top] measured along the wall.
static func wall(k: MeshKit, origin: Vector3, along: Vector3, length: float, height: float, mat: String, holes: Array = [], t := 0.4) -> void:
	var u := 0.0
	var hs := holes.duplicate()
	hs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for h in hs:
		var hole: Array = h
		_piece(k, origin, along, u, hole[0], 0.0, height, mat, t)
		_piece(k, origin, along, hole[0], hole[1], 0.0, hole[2], mat, t)
		_piece(k, origin, along, hole[0], hole[1], hole[3], height, mat, t)
		u = hole[1]
	_piece(k, origin, along, u, length, 0.0, height, mat, t)


static func _piece(k: MeshKit, origin: Vector3, along: Vector3, u0: float, u1: float, v0: float, v1: float, mat: String, t: float) -> void:
	if u1 - u0 < 0.01 or v1 - v0 < 0.01:
		return
	var size := Vector3(absf(along.x) * (u1 - u0) + absf(along.z) * t, v1 - v0, absf(along.z) * (u1 - u0) + absf(along.x) * t)
	k.box(origin + along * (u0 + u1) * 0.5 + Vector3(0, (v0 + v1) * 0.5, 0), size, mat)


## A box room with the inner size x0..x1, z0..z1. Walls sit outside that.
## gaps: {"n": [[centre, width, top, bottom]], "s": .., "w": .., "e": ..} — n is the wall at z0,
## s at z1, w at x0, e at x1; centre is the x (or z) coordinate of the opening.
static func room(k: MeshKit, x0: float, z0: float, x1: float, z1: float, y: float, h: float, wall_mat: String, floor_mat: String, ceil_mat: String, gaps := {}, t := 0.4) -> void:
	if floor_mat != "":
		k.box(Vector3((x0 + x1) * 0.5, y - 0.1, (z0 + z1) * 0.5), Vector3(x1 - x0 + t * 2.0, 0.2, z1 - z0 + t * 2.0), floor_mat)
	if ceil_mat != "":
		k.box(Vector3((x0 + x1) * 0.5, y + h + 0.15, (z0 + z1) * 0.5), Vector3(x1 - x0 + t * 2.0, 0.3, z1 - z0 + t * 2.0), ceil_mat)
	for side in ["n", "s", "w", "e"]:
		var holes := []
		var start := (x0 if side in ["n", "s"] else z0) - t
		for g in gaps.get(side, []):
			var gg: Array = g
			var c: float = gg[0]
			var w: float = gg[1]
			holes.append([c - w * 0.5 - start, c + w * 0.5 - start, float(gg[3]) if gg.size() > 3 else 0.0, gg[2]])
		match side:
			"n":
				wall(k, Vector3(x0 - t, y, z0 - t * 0.5), Vector3.RIGHT, x1 - x0 + t * 2.0, h, wall_mat, holes, t)
			"s":
				wall(k, Vector3(x0 - t, y, z1 + t * 0.5), Vector3.RIGHT, x1 - x0 + t * 2.0, h, wall_mat, holes, t)
			"w":
				wall(k, Vector3(x0 - t * 0.5, y, z0 - t), Vector3.BACK, z1 - z0 + t * 2.0, h, wall_mat, holes, t)
			"e":
				wall(k, Vector3(x1 + t * 0.5, y, z0 - t), Vector3.BACK, z1 - z0 + t * 2.0, h, wall_mat, holes, t)


static var deco: MeshKit      # where small things go that must not trip anyone up


## A ramp you can walk, with ribs across it so it reads as steps. a = foot, b = head (centre line).
static func ramp(k: MeshKit, a: Vector3, b: Vector3, w: float, mat: String, rib := "metal_in", rails := false) -> void:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var yaw := atan2(flat.x, flat.z)
	var pitch := -atan2(d.y, flat.length())
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	k.box((a + b) * 0.5 - bs.y * 0.08, Vector3(w, 0.16, d.length()), mat, bs)
	if deco:
		var old := deco.xf
		deco.xf = k.xf
		var n := int(d.length() / 0.34)
		for i in n:
			deco.box(a.lerp(b, (i + 0.5) / n) + bs.y * 0.012, Vector3(w * 0.96, 0.03, 0.07), rib, bs)
		deco.xf = old
	if rails:
		for sx: float in [-1.0, 1.0]:
			var side := bs.x * (w * 0.5 - 0.03) * sx
			k.tube(a + side + Vector3(0, 1.0, 0), b + side + Vector3(0, 1.0, 0), 0.025, "steel", 5)
			for i in 4:
				var q := a.lerp(b, i / 3.0) + side
				k.tube(q, q + Vector3(0, 1.0, 0), 0.02, "steel", 4)


## Chain-link fence from a to b with posts, top rail and barbed wire.
static func fence(k: MeshKit, a: Vector3, b: Vector3, h := 2.6) -> void:
	var d := b - a
	var n := maxi(int(d.length() / 3.5), 1)
	var bs := Basis(Vector3.UP, atan2(d.x, d.z))
	k.box((a + b) * 0.5 + Vector3(0, h * 0.5, 0), Vector3(0.02, h, d.length()), "chainlink", bs)
	k.tube(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.025, "steel", 5)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		k.cyl(p - Vector3(0, 0.3, 0), 0.05, h + 0.35, "steel", 6)
		k.tube(p + Vector3(0, h, 0), p + Vector3(0, h + 0.4, 0) + bs.x * 0.25, 0.025, "steel", 4)
	for w in 3:
		var o := Vector3(0, h + 0.14 + w * 0.12, 0) + bs.x * (0.08 + w * 0.08)
		k.tube(a + o, b + o, 0.008, "metal", 3, -1.0, false)


static func sandbags(k: MeshKit, p: Vector3, yaw: float, n: int, rows := 3) -> void:
	var bs := Basis(Vector3.UP, yaw)
	for r in rows:
		for i in n - (r % 2):
			var l := Vector3((i - (n - 1) * 0.5 + (r % 2) * 0.5) * 0.62, 0.11 + r * 0.2, 0.0)
			k.ball(p + bs * l, Vector3(0.33, 0.12, 0.2), "cream", 8, 4, bs)


## 6 m shipping container. Open ones have a doorway at +Z.
static func container(k: MeshKit, p: Vector3, yaw: float, mat: String, open := false) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), p)
	if not open:
		k.box(Vector3(0, 1.3, 0), Vector3(2.44, 2.6, 6.06), mat)
		# the cargo doors of a sealed one: two leaves and four locking bars
		for sx: float in [-1.0, 1.0]:
			k.bbox(Vector3(sx * 0.58, 1.3, 3.04), Vector3(1.1, 2.4, 0.05), 0.01, mat)
			for q: float in [0.3, 0.8]:
				k.tube(Vector3(sx * q, 0.12, 3.08), Vector3(sx * q, 2.48, 3.08), 0.022, "metal", 6)
				k.box(Vector3(sx * q, 1.25, 3.09), Vector3(0.2, 0.035, 0.03), "metal")
	else:
		# walk-in: the doorway is the whole end; the two door leaves are real doors (Places.cargo_doors)
		room(k, -1.1, -2.9, 1.1, 2.9, 0.07, 2.3, mat, "planks_in", mat, {"s": [[0.0, 2.2, 2.3]]}, 0.12)
	for i in 14:
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 1.24, 1.3, -2.8 + i * 0.43), Vector3(0.05, 2.4, 0.16), mat)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 1.2, 1.3, sz * 3.0), Vector3(0.12, 2.62, 0.12), "metal")
	k.box(Vector3(0, 2.68, 0), Vector3(2.5, 0.14, 6.1), "snow")
	k.xf = xf


## Watchtower: four legs, a cabin on top, a zig-zag of ramps up. p = ground centre.
static func tower(k: MeshKit, p: Vector3, yaw: float, h := 7.0, wood := false) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), p)
	var leg := "wood_dark" if wood else "steel"
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.tube(Vector3(sx * 2.0, -0.4, sz * 2.0), Vector3(sx * 1.6, h, sz * 1.6), 0.09, leg, 6)
	for lv in 3:
		var y0 := h * lv / 3.0
		var y1 := h * (lv + 1) / 3.0
		for q in 4:
			var a := Basis(Vector3.UP, q * PI * 0.5)
			var s0 := 2.0 - 0.4 * lv / 3.0
			var s1 := 2.0 - 0.4 * (lv + 1) / 3.0
			k.tube(a * Vector3(-s0, y0, s0), a * Vector3(s1, y1, s1), 0.04, leg, 5)
			k.tube(a * Vector3(-s1, y1, s1), a * Vector3(s1, y1, s1), 0.04, leg, 5)
	var plank := "planks" if wood else "steel"
	var cm := "planks" if wood else "olive"
	k.box(Vector3(0, h, 0), Vector3(4.4, 0.14, 4.4), plank)
	# two flights along the +X side, side by side, then a landing onto the platform
	ramp(k, Vector3(2.8, 0.0, -5.6), Vector3(2.8, h * 0.5, 3.4), 1.0, plank, leg, true)
	k.box(Vector3(3.4, h * 0.5 - 0.07, 4.1), Vector3(2.3, 0.14, 1.4), plank)
	ramp(k, Vector3(4.0, h * 0.5, 3.4), Vector3(4.0, h, -3.0), 1.0, plank, leg, true)
	# the head landing starts where the flight ends, then a strip leads back to the cabin gap
	k.box(Vector3(2.75, h - 0.07, -3.7), Vector3(3.6, 0.14, 1.4), plank)
	k.box(Vector3(2.15, h - 0.07, -2.6), Vector3(2.4, 0.14, 0.8), plank)
	for sv: Vector3 in [Vector3(2.3, h * 0.5, 4.7), Vector3(4.5, h * 0.5, 4.7), Vector3(4.5, h * 0.5, 3.5), Vector3(4.5, h, -4.3), Vector3(4.5, h, -3.1), Vector3(1.0, h, -4.3), Vector3(4.5, h * 0.75, 0.2)]:
		k.cyl(Vector3(sv.x, -0.3, sv.z), 0.06, sv.y + 0.25, leg, 5)
	for sv: Vector3 in [Vector3(4.5, h, -3.7), Vector3(2.75, h, -4.37)]:
		k.box(sv + Vector3(0, 0.55, 0), Vector3(0.06, 1.1, 1.4) if sv.x > 4.0 else Vector3(3.5, 1.1, 0.06), cm)
	k.box(Vector3(0.98, h + 0.55, -3.3), Vector3(0.06, 1.1, 2.2), cm)
	# cabin: half walls with a gap where the landing arrives, corner posts, roof
	k.box(Vector3(0, h + 0.6, 2.17), Vector3(4.4, 1.1, 0.08), cm)
	k.box(Vector3(-2.17, h + 0.6, 0), Vector3(0.08, 1.1, 4.4), cm)
	k.box(Vector3(2.17, h + 0.6, 0), Vector3(0.08, 1.1, 4.4), cm)
	k.box(Vector3(-0.65, h + 0.6, -2.17), Vector3(3.1, 1.1, 0.08), cm)
	for q in 4:
		var a := Basis(Vector3.UP, q * PI * 0.5)
		k.box(a * Vector3(2.12, h + 1.3, 2.12), Vector3(0.12, 2.6, 0.12), leg)
	k.box(Vector3(0, h + 2.7, 0), Vector3(5.0, 0.12, 5.0), cm, Basis(Vector3.RIGHT, 0.06))
	k.box(Vector3(0, h + 2.86, 0), Vector3(5.0, 0.2, 5.0), "snow", Basis(Vector3.RIGHT, 0.06))
	k.xf = xf


static func floodlight(k: MeshKit, p: Vector3, yaw: float, lit: bool, h := 6.5) -> Vector3:
	var bs := Basis(Vector3.UP, yaw)
	k.cyl(p - Vector3(0, 0.3, 0), 0.09, h + 0.3, "steel", 7, 0.06)
	k.box(p + Vector3(0, h, 0), Vector3(1.3, 0.08, 0.08), "steel", bs)
	for sx: float in [-0.45, 0.45]:
		var c := p + bs * Vector3(sx, h - 0.05, 0.12)
		k.box(c, Vector3(0.36, 0.3, 0.2), "metal", bs * Basis(Vector3.RIGHT, 0.5))
		k.box(c + bs * Vector3(0, -0.05, 0.1), Vector3(0.3, 0.24, 0.03), "lamp_glow" if lit else "glass_dark", bs * Basis(Vector3.RIGHT, 0.5))
	return p + bs * Vector3(0, h - 0.5, 1.2)


## Half-barrel hut of corrugated steel, door at +Z. Inner width 5.2, you can walk in.
static func quonset(k: MeshKit, p: Vector3, yaw: float, length: float, mat := "olive") -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), p)
	var r := 3.0
	var seg := 9
	var hl := length * 0.5
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		var mid := (p0 + p1) * 0.5
		var out := Vector3(mid.x, mid.y, 0).normalized()
		var bs := Basis(Vector3(-out.y, out.x, 0), out, Vector3(0, 0, 1))
		k.box(mid, Vector3(p0.distance_to(p1) + 0.04, 0.1, length), mat, bs)
		if i > 1 and i < seg - 2:
			k.box(mid + out * 0.1, Vector3(p0.distance_to(p1), 0.14, length), "snow", bs)
	for i in int(length / 1.2) + 1:
		for q in seg:
			var a0 := PI * q / seg
			var a1 := PI * (q + 1) / seg
			k.tube(Vector3(cos(a0) * 3.06, sin(a0) * 3.06, -hl + i * 1.2), Vector3(cos(a1) * 3.06, sin(a1) * 3.06, -hl + i * 1.2), 0.03, "metal", 4, -1.0, false)
	k.box(Vector3(0, 0.03, 0), Vector3(5.9, 0.1, length), "planks_in")
	# end walls: back closed, front with a doorway
	for i in 7:
		var x := -2.6 + i * 0.866
		var top := sqrt(maxf(r * r - x * x, 0.0)) - 0.05
		k.box(Vector3(x, top * 0.5, -hl), Vector3(0.88, top, 0.1), mat)
		if absf(x) > 0.7:
			k.box(Vector3(x, top * 0.5, hl), Vector3(0.88, top, 0.1), mat)
		else:
			k.box(Vector3(x, 2.15 + (top - 2.15) * 0.5, hl), Vector3(0.88, top - 2.15, 0.1), mat)
	k.xf = xf


static func tank(k: MeshKit, p: Vector3, yaw: float, length := 5.0, r := 1.1, mat := "paint_white") -> void:
	var bs := Basis(Vector3.UP, yaw)
	var a := p + bs * Vector3(0, r + 0.5, -length * 0.5)
	var b := p + bs * Vector3(0, r + 0.5, length * 0.5)
	k.tube(a, b, r, mat, 14)
	k.ball(a, Vector3(r, r, 0.4), mat, 14, 5, bs)
	k.ball(b, Vector3(r, r, 0.4), mat, 14, 5, bs)
	for z: float in [-0.3, 0.3]:
		var zz: float = z
		k.box(p + bs * Vector3(0, 0.3, length * zz), Vector3(r * 1.7, 0.6, 0.3), "concrete", bs)
	k.box(p + bs * Vector3(0, r * 2.0 + 0.52, 0), Vector3(r * 0.9, 0.12, length * 0.9), "snow", bs)
	k.cyl(p + bs * Vector3(0, r * 2.0 + 0.45, length * 0.2), 0.14, 0.3, "metal", 8)
	k.box(p + bs * Vector3(r * 0.2, r + 0.5, length * 0.5 + 0.38), Vector3(0.5, 0.36, 0.03), "hazard", bs)


## Lattice mast with guy wires and a warning lamp. Returns the lamp position.
static func mast(k: MeshKit, p: Vector3, h: float) -> Vector3:
	var s := 0.5
	for q in 3:
		var a := q * TAU / 3.0
		k.tube(p + Vector3(cos(a) * s, -0.3, sin(a) * s), p + Vector3(cos(a) * 0.12, h, sin(a) * 0.12), 0.035, "steel", 5)
	var n := int(h / 1.6)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		for q in 3:
			var a := q * TAU / 3.0
			var b := (q + 1) * TAU / 3.0
			var r0 := lerpf(s, 0.12, t0)
			var r1 := lerpf(s, 0.12, t1)
			k.tube(p + Vector3(cos(a) * r0, h * t0, sin(a) * r0), p + Vector3(cos(b) * r1, h * t1, sin(b) * r1), 0.018, "paint_red" if i % 2 == 0 else "paint_white", 4, -1.0, false)
	for q in 3:
		var a := q * TAU / 3.0 + 0.5
		k.tube(p + Vector3(0, h * 0.85, 0), p + Vector3(cos(a) * h * 0.5, 0, sin(a) * h * 0.5), 0.012, "metal", 3, -1.0, false)
		k.box(p + Vector3(cos(a) * h * 0.5, 0.1, sin(a) * h * 0.5), Vector3(0.5, 0.3, 0.5), "concrete")
	for i in 3:
		k.tube(p + Vector3(-0.9, h * (0.7 + i * 0.08), 0), p + Vector3(0.9, h * (0.7 + i * 0.08), 0), 0.015, "steel", 4)
	k.sphere(p + Vector3(0, h + 0.1, 0), 0.12, "led_red", 8, 5)
	return p + Vector3(0, h + 0.1, 0)


static func dish(k: MeshKit, p: Vector3, yaw: float, r := 1.5) -> void:
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.7)
	k.cyl(p - Vector3(0, 0.2, 0), 0.12, 1.6, "steel", 8)
	k.box(p + Vector3(0, 0.1, 0), Vector3(0.9, 0.2, 0.9), "concrete")
	var c := p + Vector3(0, 1.7, 0)
	k.ball(c, Vector3(r, r, r * 0.22), "paint_white", 16, 5, bs)
	k.tube(c, c + bs.z * r * 0.75, 0.025, "steel", 5)
	k.sphere(c + bs.z * r * 0.75, 0.1, "metal", 8, 5)


## White radar dome on a ring wall.
static func radome(k: MeshKit, p: Vector3, r := 3.6) -> void:
	k.cyl(p - Vector3(0, 0.3, 0), r * 0.82, 1.9, "concrete", 16)
	k.sphere(p + Vector3(0, 1.6 + r * 0.72, 0), r, "paint_white", 18, 10)
	for i in 9:
		var a := i * TAU / 9.0
		k.tube(p + Vector3(cos(a) * r * 0.83, 1.6, sin(a) * r * 0.83), p + Vector3(cos(a + 0.7) * r * 0.5, 1.6 + r * 1.6, sin(a + 0.7) * r * 0.5), 0.03, "grey", 4, -1.0, false)
	k.box(p + Vector3(0, 0.9, r * 0.84), Vector3(0.9, 1.8, 0.1), "steel")


## Narrow-gauge track between two points.
static func rails(k: MeshKit, a: Vector3, b: Vector3, sfx := "") -> void:
	var d := b - a
	var bs := Basis(Vector3.UP, atan2(d.x, d.z))
	for sx: float in [-0.4, 0.4]:
		k.box((a + b) * 0.5 + bs * Vector3(sx, 0.07, 0), Vector3(0.06, 0.1, d.length()), "rust" + sfx, bs)
	var n := int(d.length() / 0.8)
	for i in n:
		k.box(a.lerp(b, (i + 0.5) / n) + Vector3(0, 0.02, 0), Vector3(1.3, 0.08, 0.18), "wood_dark" + sfx, bs)


static func cart(k: MeshKit, p: Vector3, yaw: float, ore := true, sfx := "") -> void:
	var bs := Basis(Vector3.UP, yaw)
	k.box(p + Vector3(0, 0.35, 0), Vector3(0.95, 0.1, 1.5), "rust" + sfx, bs)
	for sx: float in [-1.0, 1.0]:
		k.box(p + bs * Vector3(sx * 0.55, 0.75, 0), Vector3(0.06, 0.8, 1.5), "rust" + sfx, bs * Basis(Vector3(0, 0, 1), -sx * 0.2))
		for sz: float in [-0.5, 0.5]:
			k.tube(p + bs * Vector3(sx * 0.36, 0.22, sz), p + bs * Vector3(sx * 0.46, 0.22, sz), 0.2, "metal" + sfx, 10)
	for sz: float in [-1.0, 1.0]:
		k.box(p + bs * Vector3(0, 0.75, sz * 0.75), Vector3(1.1, 0.8, 0.06), "rust" + sfx, bs)
	if ore:
		for i in 7:
			k.ball(p + bs * Vector3(sin(i * 2.1) * 0.3, 1.0 + (i % 2) * 0.12, cos(i * 1.7) * 0.5), Vector3(0.24, 0.18, 0.22), "rock" + sfx, 6, 4)


## One timber frame across a mine drift: two posts and a cap. The drift runs along `axis`.
static func timber(k: MeshKit, p: Vector3, along_x: bool, w: float, h: float) -> void:
	var side := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	for s: float in [-1.0, 1.0]:
		k.tube(p + side * (w * 0.5 - 0.14) * s, p + side * (w * 0.5 - 0.2) * s + Vector3(0, h - 0.2, 0), 0.11, "wood_in", 7)
	k.tube(p + side * (-w * 0.5) + Vector3(0, h - 0.14, 0), p + side * (w * 0.5) + Vector3(0, h - 0.14, 0), 0.12, "wood_in", 7)


static func rubble(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, r: float, n: int, mat := "rock", big := 1.0) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var s := rng.randf_range(0.25, 0.9) * big * (1.3 - d / r)
		k.ball(p + Vector3(cos(a) * d, s * 0.35, sin(a) * d), Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.7, 1.1)), mat, 7, 4, Basis(Vector3.UP, rng.randf() * TAU))


## Two-level bunk bed along Z.
static func bunk(k: MeshKit, p: Vector3, yaw: float, blanket := "olive_in") -> void:
	var bs := Basis(Vector3.UP, yaw)
	for sx: float in [-0.45, 0.45]:
		for sz: float in [-1.0, 1.0]:
			k.box(p + bs * Vector3(sx, 0.95, sz), Vector3(0.05, 1.9, 0.05), "metal_in")
	for y: float in [0.4, 1.35]:
		var yy: float = y
		k.box(p + bs * Vector3(0, yy, 0), Vector3(0.9, 0.05, 2.0), "metal_in", bs)
		k.bbox(p + bs * Vector3(0, yy + 0.1, 0), Vector3(0.84, 0.14, 1.9), 0.04, "cream_in", bs)
		k.bbox(p + bs * Vector3(0, yy + 0.16, 0.25), Vector3(0.86, 0.08, 1.3), 0.03, blanket, bs)
		k.ball(p + bs * Vector3(0, yy + 0.22, -0.75), Vector3(0.26, 0.07, 0.15), "white_in", 8, 4, bs)


## Server rack with blinking lights. Front faces +Z.
static func rack(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, alive: bool) -> void:
	var bs := Basis(Vector3.UP, yaw)
	k.bbox(p + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.8), 0.02, "metal_in", bs)
	for i in 9:
		k.box(p + bs * Vector3(0, 0.25 + i * 0.19, 0.41), Vector3(0.6, 0.15, 0.02), "black_in", bs)
		if alive:
			for j in 3:
				if rng.randf() < 0.6:
					k.box(p + bs * Vector3(-0.22 + j * 0.06, 0.25 + i * 0.19, 0.425), Vector3(0.025, 0.025, 0.01), "led_green" if rng.randf() < 0.75 else "led_red", bs)


## Lab bench with glassware, a microscope and a dead (or glowing) screen.
static func lab_bench(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, screen := false) -> void:
	var bs := Basis(Vector3.UP, yaw)
	k.box(p + Vector3(0, 0.88, 0), Vector3(w, 0.06, 0.8), "white_in", bs)
	k.box(p + bs * Vector3(0, 0.42, -0.05), Vector3(w - 0.1, 0.84, 0.6), "grey_in", bs)
	for i in int(w / 0.6):
		var x := -w * 0.5 + 0.3 + i * 0.6
		k.box(p + bs * Vector3(x, 0.5, 0.26), Vector3(0.54, 0.6, 0.02), "panel_in", bs)
		k.box(p + bs * Vector3(x, 0.72, 0.28), Vector3(0.16, 0.02, 0.02), "steel_in", bs)
	var x := -w * 0.5 + 0.3
	while x < w * 0.5 - 0.2:
		var kind := rng.randi() % 5
		var q := p + bs * Vector3(x, 0.91, rng.randf_range(-0.2, 0.15))
		match kind:
			0:
				k.cyl(q, 0.05, 0.12, "glass_clear", 8, 0.02)
				k.cyl(q + Vector3(0, 0.12, 0), 0.02, 0.08, "glass_clear", 6)
			1:
				for j in 4:
					k.cyl(q + bs * Vector3(j * 0.045 - 0.07, 0.02, 0), 0.014, 0.14, "specimen", 5)
				k.box(q + Vector3(0, 0.05, 0), Vector3(0.24, 0.02, 0.06), "wood_in", bs)
			2:
				k.box(q + Vector3(0, 0.02, 0), Vector3(0.16, 0.04, 0.2), "black_in", bs)
				k.tube(q + Vector3(0, 0.04, 0) + bs * Vector3(0, 0, -0.06), q + Vector3(0, 0.3, 0) + bs * Vector3(0, 0, 0.02), 0.022, "black_in", 6)
				k.cyl(q + Vector3(0, 0.3, 0) + bs * Vector3(0, 0, 0.02), 0.03, 0.08, "steel_in", 6)
			3:
				k.box(q + Vector3(0, 0.01, 0), Vector3(0.22, 0.012, 0.3), "paper_in", bs * Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)))
			_:
				k.cyl(q, 0.04, 0.09, "white_in", 8)
		x += rng.randf_range(0.35, 0.6)
	if screen:
		var q := p + bs * Vector3(w * 0.3, 0.91, -0.2)
		k.box(q + Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.16), "grey_in", bs)
		k.bbox(q + Vector3(0, 0.3, 0), Vector3(0.5, 0.36, 0.05), 0.01, "grey_in", bs)
		k.box(q + Vector3(0, 0.3, 0) + bs * Vector3(0, 0, 0.03), Vector3(0.44, 0.3, 0.005), "screen_on", bs)


## Glass cylinder with something frozen in it.
static func specimen(k: MeshKit, p: Vector3, h := 2.0) -> void:
	k.cyl(p, 0.42, 0.25, "metal_in", 12)
	k.cyl(p + Vector3(0, 0.25, 0), 0.36, h, "specimen", 12)
	k.cyl(p + Vector3(0, 0.25 + h, 0), 0.42, 0.2, "metal_in", 12)
	k.ball(p + Vector3(0, 0.25 + h * 0.5, 0), Vector3(0.16, h * 0.34, 0.14), "ice", 8, 6)
	k.tube(p + Vector3(0.3, 0.25 + h + 0.2, 0), p + Vector3(0.3, 2.8, 0), 0.03, "black_in", 5)


## Steel shelf with boxes and cans.
static func shelf(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, h := 1.9) -> void:
	var bs := Basis(Vector3.UP, yaw)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.2, 0.2]:
			k.box(p + bs * Vector3(sx * w * 0.5, h * 0.5, sz), Vector3(0.04, h, 0.04), "steel_in")
	for i in 4:
		var y := 0.15 + i * (h - 0.25) / 3.0
		k.box(p + bs * Vector3(0, y, 0), Vector3(w, 0.03, 0.45), "steel_in", bs)
		var x := -w * 0.5 + 0.2
		while x < w * 0.5 - 0.2 and i < 3:
			var s := rng.randf_range(0.18, 0.36)
			if rng.randf() < 0.75:
				if rng.randf() < 0.5:
					k.box(p + bs * Vector3(x, y + s * 0.5 + 0.02, 0), Vector3(s, s, 0.34), ["wood_in", "olive_in", "cream_in", "grey_in"][rng.randi() % 4], bs)
				else:
					k.cyl(p + bs * Vector3(x, y + 0.02, 0), s * 0.35, s * 0.9, ["steel_in", "red_in", "olive_in", "blue_in"][rng.randi() % 4], 8)
			x += s + rng.randf_range(0.08, 0.3)


static func generator(k: MeshKit, p: Vector3, yaw: float) -> void:
	var bs := Basis(Vector3.UP, yaw)
	k.bbox(p + Vector3(0, 0.6, 0), Vector3(1.0, 0.9, 1.9), 0.04, "paint_yellow_in", bs)
	k.box(p + Vector3(0, 0.1, 0), Vector3(1.1, 0.2, 2.1), "metal_in", bs)
	k.box(p + bs * Vector3(0.51, 0.65, 0.3), Vector3(0.02, 0.5, 0.9), "black_in", bs)
	k.cyl(p + bs * Vector3(0.2, 1.05, -0.6), 0.06, 0.9, "metal_in", 6)
	k.cyl(p + bs * Vector3(-0.2, 1.05, 0.5), 0.14, 0.12, "red_in", 8)
	k.box(p + bs * Vector3(0.51, 0.75, -0.6), Vector3(0.02, 0.2, 0.3), "grey_in", bs)


## A sign board on one or two posts. Returns where the text goes (world space) for a Label3D.
static func sign(k: MeshKit, p: Vector3, yaw: float, w: float, h: float, mat := "paint_yellow", post_h := 2.4) -> Vector3:
	var bs := Basis(Vector3.UP, yaw)
	if w > 1.4:
		for sx: float in [-1.0, 1.0]:
			k.cyl(p + bs * Vector3(sx * (w * 0.5 - 0.1), -0.3, -0.05), 0.045, post_h + 0.3, "steel", 6)
	else:
		k.cyl(p + bs * Vector3(0, -0.3, -0.05), 0.045, post_h + 0.3, "steel", 6)
	k.box(p + Vector3(0, post_h - h * 0.5, 0), Vector3(w, h, 0.04), mat, bs)
	k.box(p + Vector3(0, post_h + 0.03, 0), Vector3(w, 0.07, 0.1), "snow", bs)
	return k.xf * (p + bs * Vector3(0, post_h - h * 0.5, 0.03))


## Rusting bus on its belly.
static func bus(k: MeshKit, p: Vector3, yaw: float, roll := 0.0, snowy := true) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), roll), p)
	k.bbox(Vector3(0, 1.0, 0), Vector3(2.5, 1.2, 9.6), 0.12, "car_yellow")
	k.bbox(Vector3(0, 2.25, 0), Vector3(2.4, 1.3, 9.4), 0.2, "car_yellow")
	k.box(Vector3(0, 2.95, 0), Vector3(2.3, 0.14, 9.2), "snow")
	for i in 7:
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 1.21, 2.2, -3.6 + i * 1.2), Vector3(0.03, 0.75, 0.95), "glass_dark" if (i + int(sx)) % 3 != 0 else "black")
	k.box(Vector3(0, 2.15, -4.71), Vector3(2.1, 0.9, 0.03), "glass_dark")
	k.box(Vector3(0, 1.2, -4.82), Vector3(2.3, 0.5, 0.06), "black")
	k.box(Vector3(0, 0.55, -4.9), Vector3(2.5, 0.25, 0.2), "metal")
	for sz: float in [-3.0, 2.8]:
		for sx: float in [-1.0, 1.0]:
			k.tube(Vector3(sx * 0.95, 0.5, sz), Vector3(sx * 1.25, 0.5, sz), 0.5, "black", 12)
	k.box(Vector3(1.27, 1.5, -3.9), Vector3(0.05, 2.0, 0.9), "rust", Basis(Vector3.UP, 0.9))
	if snowy:
		k.ball(Vector3(-1.5, 0.3, 1.0), Vector3(1.0, 0.5, 4.0), "snow", 10, 5)
	k.xf = xf


## Tanker or box truck, jack-knifed.
static func truck(k: MeshKit, p: Vector3, yaw: float, tanker: bool, fold := 0.5) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw), p)
	k.bbox(Vector3(0, 1.5, -0.2), Vector3(2.4, 2.1, 2.2), 0.14, "car_red")
	k.box(Vector3(0, 2.0, -1.32), Vector3(2.1, 0.8, 0.03), "glass_dark")
	k.box(Vector3(0, 0.85, -1.35), Vector3(2.3, 0.6, 0.1), "metal")
	k.box(Vector3(0, 2.62, -0.2), Vector3(2.3, 0.14, 2.1), "snow")
	for sx: float in [-1.0, 1.0]:
		k.tube(Vector3(sx * 0.95, 0.55, -0.4), Vector3(sx * 1.25, 0.55, -0.4), 0.55, "black", 12)
		k.cyl(Vector3(sx * 1.1, 2.5, 0.7), 0.07, 1.0, "steel", 6)
	k.xf = k.xf * Transform3D(Basis(Vector3.UP, fold), Vector3(0, 0, 1.2))
	k.box(Vector3(0, 0.95, 4.0), Vector3(2.2, 0.25, 8.6), "metal")
	if tanker:
		k.tube(Vector3(0, 2.2, 0.2), Vector3(0, 2.2, 8.0), 1.2, "steel", 14)
		k.ball(Vector3(0, 2.2, 0.2), Vector3(1.2, 1.2, 0.4), "steel", 14, 5)
		k.ball(Vector3(0, 2.2, 8.0), Vector3(1.2, 1.2, 0.4), "steel", 14, 5)
		k.box(Vector3(0, 2.2, 4.0), Vector3(2.44, 0.5, 2.4), "hazard")
		k.box(Vector3(0, 3.42, 4.0), Vector3(1.2, 0.14, 7.4), "snow")
	else:
		k.box(Vector3(0, 2.4, 4.0), Vector3(2.5, 2.7, 8.4), "paint_white")
		k.box(Vector3(0, 3.82, 4.0), Vector3(2.5, 0.16, 8.4), "snow")
		k.box(Vector3(1.26, 2.4, 4.0), Vector3(0.02, 0.9, 5.0), "paint_blue")
	for sz: float in [5.6, 6.9]:
		for sx: float in [-1.0, 1.0]:
			k.tube(Vector3(sx * 0.9, 0.55, sz), Vector3(sx * 1.25, 0.55, sz), 0.55, "black", 12)
	k.xf = xf


## Crashed helicopter: bubble cabin, broken tail, bent blades.
static func heli(k: MeshKit, p: Vector3, yaw: float) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), 0.22), p)
	k.ball(Vector3(0, 1.3, 0), Vector3(1.25, 1.2, 2.4), "olive", 14, 8)
	k.ball(Vector3(0, 1.45, -1.3), Vector3(1.0, 0.85, 1.2), "glass_dark", 12, 7)
	k.tube(Vector3(0, 1.6, 2.0), Vector3(0.3, 1.5, 6.4), 0.4, "olive", 9, 0.16)
	k.box(Vector3(0.9, 1.9, 7.2), Vector3(0.1, 1.6, 0.8), "olive", Basis(Vector3(0, 0, 1), 1.1))
	k.cyl(Vector3(0, 2.4, 0.2), 0.14, 0.6, "metal", 8)
	for i in 4:
		var a := i * PI * 0.5 + 0.3
		k.box(Vector3(cos(a) * 2.4, 2.95 - (i % 2) * 0.5, 0.2 + sin(a) * 2.4), Vector3(4.6, 0.04, 0.3), "metal", Basis(Vector3.UP, -a) * Basis(Vector3(0, 0, 1), -0.12 - (i % 2) * 0.2))
	for sx: float in [-1.0, 1.0]:
		k.tube(Vector3(sx * 1.1, 0.12, -1.6), Vector3(sx * 1.1, 0.12, 1.8), 0.05, "steel", 6)
		for z: float in [-0.9, 1.0]:
			var zz: float = z
			k.tube(Vector3(sx * 1.1, 0.12, zz), Vector3(sx * 0.7, 0.6, zz), 0.04, "steel", 5)
	k.box(Vector3(-1.24, 1.3, 0.3), Vector3(0.04, 0.5, 0.5), "white")
	k.ball(Vector3(0.6, 0.2, 3.5), Vector3(1.6, 0.4, 2.6), "snow", 10, 5)
	k.xf = xf


## Concrete face of a tunnel mouth, stepped to follow the hill above it.
## The wall stands at `fixed` on one axis and runs from `from` to `to` on the other.
static func headwall(k: MeshKit, t: Terrain, floor_y: float, along_x: bool, fixed: float, from: float, to: float, hole0: float, hole1: float, hole_h: float, thick := 0.7) -> void:
	var c := from + 1.0
	while c < to:
		var nat := t.natural_at(c, fixed) if along_x else t.natural_at(fixed, c)
		var top := maxf(nat - floor_y + 0.7, 0.6)
		var bottom := 0.0
		if c > hole0 and c < hole1:
			bottom = hole_h
			top = maxf(top, hole_h + 1.4)
		var mid := Vector3(c, floor_y + (top + bottom) * 0.5, fixed) if along_x else Vector3(fixed, floor_y + (top + bottom) * 0.5, c)
		k.box(mid, Vector3(2.0, top - bottom, thick) if along_x else Vector3(thick, top - bottom, 2.0), "concrete")
		c += 2.0


## Road-side things: orange snow pole.
static func snow_pole(k: MeshKit, p: Vector3) -> void:
	k.cyl(p - Vector3(0, 0.3, 0), 0.03, 2.5, "orange", 5)
	k.cyl(p + Vector3(0, 1.75, 0), 0.034, 0.22, "black", 5)


static func guard_rail(k: MeshKit, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var bs := Basis(Vector3.UP, atan2(d.x, d.z))
	k.box((a + b) * 0.5 + Vector3(0, 0.62, 0), Vector3(0.06, 0.3, d.length()), "steel", bs)
	var n := maxi(int(d.length() / 2.0), 1)
	for i in n + 1:
		k.box(a.lerp(b, float(i) / n) + Vector3(0, 0.25, 0), Vector3(0.1, 0.9, 0.1), "metal")
