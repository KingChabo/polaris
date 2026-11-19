class_name Interior
extends RefCounted
## Furniture and room layouts for every building, modelled piece by piece.
## Each piece is drawn at a floor point `p`, turned by `yaw`, front towards +Z.

const Y0 := 0.18
const FH := 2.9
const BOOKS: Array[String] = ["cloth_in", "blue_in", "green_in", "leather_in", "cream_in", "teal_in", "yellow_in", "navy_in", "red_in"]
const BOTTLES: Array[String] = ["green_in", "leather_in", "teal_in", "cream_in", "red_in", "yellow_in"]


static var base := Transform3D.IDENTITY     # set by builders that work in a place's own coordinates


static func _at(k: MeshKit, p: Vector3, yaw := 0.0, tilt := Basis.IDENTITY) -> Basis:
	var b := Basis(Vector3.UP, yaw) * tilt
	k.xf = base * Transform3D(b, p)
	return b


static func _done(k: MeshKit) -> void:
	k.xf = base


## Scanned furniture (Poly Haven, CC0, made game-ready in Blender) in the kit's current frame:
## call after _at. False when the model is missing, so the code piece is built instead.
const SCAN_YAW := {}
static func _scan(k: MeshKit, id: String, height: float, at := Vector3.ZERO, yaw := 0.0) -> bool:
	return k.model("furniture/" + id, at, height, yaw + float(SCAN_YAW.get(id, 0.0)), 0.0)


static func _loc(p: Vector3, yaw: float, l: Vector3) -> Vector3:
	return p + Basis(Vector3.UP, yaw) * l


# ------------------------------------------------------------------ pieces

static func chair(k: MeshKit, p: Vector3, yaw: float, mat := "wood_in", fallen := false) -> void:
	_at(k, p + (Vector3(0, 0.2, 0) if fallen else Vector3.ZERO), yaw, Basis(Vector3.RIGHT, -1.5) if fallen else Basis.IDENTITY)
	if _scan(k, "painted_wooden_chair_01", 0.96):
		_done(k)
		return
	k.bbox(Vector3(0, 0.45, 0), Vector3(0.42, 0.04, 0.42), 0.01, "planks_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.18, 0.22, sz * 0.18), Vector3(0.04, 0.44, 0.04), mat)
		k.box(Vector3(sx * 0.18, 0.72, -0.19), Vector3(0.04, 0.52, 0.04), mat)
	k.box(Vector3(0, 0.88, -0.19), Vector3(0.4, 0.12, 0.03), mat)
	k.box(Vector3(0, 0.66, -0.19), Vector3(0.4, 0.05, 0.03), mat)
	k.box(Vector3(0, 0.2, 0.18), Vector3(0.36, 0.03, 0.03), mat)
	_done(k)


static func stool(k: MeshKit, p: Vector3) -> void:
	_at(k, p)
	k.cyl(Vector3(0, 0.0, 0), 0.2, 0.03, "metal_in", 12)
	k.cyl(Vector3(0, 0.03, 0), 0.03, 0.7, "brass", 8)
	k.tube(Vector3(0, 0.26, 0), Vector3(0, 0.28, 0), 0.15, "brass", 12)
	k.cyl(Vector3(0, 0.73, 0), 0.17, 0.07, "leather_in", 12)
	_done(k)


static func table(k: MeshKit, p: Vector3, yaw: float, w: float, d: float, cloth := "") -> void:
	_at(k, p, yaw)
	k.bbox(Vector3(0, 0.74, 0), Vector3(w, 0.05, d), 0.012, "planks_in")
	k.box(Vector3(0, 0.67, 0), Vector3(w - 0.18, 0.09, d - 0.18), "wood_dark_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 - 0.08), 0.36, sz * (d * 0.5 - 0.08)), Vector3(0.07, 0.72, 0.07), "wood_dark_in")
	if cloth != "":
		k.box(Vector3(0, 0.772, 0), Vector3(w + 0.04, 0.012, d + 0.04), cloth)
		for sz in [-1.0, 1.0]:
			k.box(Vector3(0, 0.68, sz * (d * 0.5 + 0.02)), Vector3(w + 0.04, 0.2, 0.012), cloth)
		for sx in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 + 0.02), 0.68, 0), Vector3(0.012, 0.2, d + 0.04), cloth)
	_done(k)


## Plate, cup, knife and fork at `l` on a table whose kit transform is set by the caller.
static func _setting(k: MeshKit, l: Vector3, turn: float) -> void:
	var b := Basis(Vector3.UP, turn)
	k.cyl(l, 0.115, 0.012, "white_in", 14)
	k.cyl(l + Vector3(0, 0.012, 0), 0.08, 0.006, "cream_in", 12)
	k.box(l + b * Vector3(0.16, 0.004, 0), Vector3(0.015, 0.006, 0.18), "steel_in", b)
	k.box(l + b * Vector3(-0.16, 0.004, 0), Vector3(0.018, 0.006, 0.17), "steel_in", b)
	k.cyl(l + b * Vector3(0.14, 0.0, -0.17), 0.03, 0.09, "glass_clear", 8)


## A laid table with chairs round it.
static func dining(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, d: float, cloth: String, lit: bool, messy := false) -> void:
	table(k, p, yaw, w, d, cloth)
	var n := maxi(1, int(w / 0.7))
	_at(k, p, yaw)
	var top := 0.78
	for i in n:
		var x := -w * 0.5 + w * (i + 0.5) / n
		if not messy or rng.randf() < 0.6:
			_setting(k, Vector3(x, top, d * 0.5 - 0.2), 0.0)
		if not messy or rng.randf() < 0.6:
			_setting(k, Vector3(x, top, -d * 0.5 + 0.2), PI)
	k.cyl(Vector3(0.08, top, 0), 0.05, 0.02, "brass", 8)
	k.cyl(Vector3(0.08, top + 0.02, 0), 0.016, 0.15, "cream_in", 6)
	if lit:
		k.ball(Vector3(0.08, top + 0.195, 0), Vector3(0.012, 0.028, 0.012), "candle", 6, 4)
	bottle(k, Vector3(-0.22, top, 0.04), BOTTLES[rng.randi() % BOTTLES.size()])
	_done(k)
	for i in n:
		var x := -w * 0.5 + w * (i + 0.5) / n
		var fall := messy and rng.randf() < 0.25
		chair(k, _loc(p, yaw, Vector3(x, 0, d * 0.5 + 0.28 + (0.3 if fall else 0.0))), yaw + PI + rng.randf_range(-0.2, 0.2), "wood_in", fall)
		chair(k, _loc(p, yaw, Vector3(x, 0, -d * 0.5 - 0.28)), yaw + rng.randf_range(-0.2, 0.2))


static func bottle(k: MeshKit, l: Vector3, mat: String, s := 1.0) -> void:
	k.cyl(l, 0.035 * s, 0.17 * s, mat, 8)
	k.cyl(l + Vector3(0, 0.17 * s, 0), 0.035 * s, 0.05 * s, mat, 8, 0.013 * s)
	k.cyl(l + Vector3(0, 0.22 * s, 0), 0.013 * s, 0.06 * s, mat, 6)
	k.box(l + Vector3(0, 0.09 * s, 0.0), Vector3(0.072 * s, 0.07 * s, 0.072 * s), "paper_in")


static func bed(k: MeshKit, p: Vector3, yaw: float, w: float, blanket: String, made := true) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.22, 0), Vector3(w, 0.24, 2.0), "wood_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 - 0.04), 0.3 if sz > 0 else 0.55, sz * 1.0), Vector3(0.09, 0.6 if sz > 0 else 1.1, 0.09), "wood_dark_in")
	k.box(Vector3(0, 0.75, -1.0), Vector3(w, 0.6, 0.05), "wood_in")
	k.box(Vector3(0, 1.07, -1.0), Vector3(w + 0.06, 0.06, 0.09), "wood_dark_in")
	k.box(Vector3(0, 0.42, 1.0), Vector3(w, 0.3, 0.05), "wood_in")
	k.bbox(Vector3(0, 0.42, 0), Vector3(w - 0.08, 0.18, 1.9), 0.04, "white_in")
	var np := 2 if w > 1.3 else 1
	for i in np:
		var x := 0.0 if np == 1 else (i - 0.5) * w * 0.48
		k.ball(Vector3(x, 0.56, -0.7), Vector3(0.27, 0.08, 0.19), "white_in", 10, 6)
	if made:
		k.bbox(Vector3(0, 0.55, 0.22), Vector3(w + 0.02, 0.12, 1.4), 0.05, blanket)
		k.bbox(Vector3(0, 0.6, -0.42), Vector3(w + 0.02, 0.07, 0.2), 0.03, "white_in")
	else:
		k.bbox(Vector3(w * 0.12, 0.56, 0.4), Vector3(w * 0.8, 0.16, 1.0), 0.07, blanket, Basis(Vector3.UP, 0.35))
		k.bbox(Vector3(-w * 0.3, 0.3, 0.9), Vector3(0.5, 0.5, 0.6), 0.1, blanket, Basis(Vector3(0, 0, 1), 0.5))
	_done(k)


static func nightstand(k: MeshKit, p: Vector3, yaw: float, lit: bool) -> void:
	_at(k, p, yaw)
	var top := 0.585
	if _scan(k, "painted_wooden_nightstand", 0.6):
		top = 0.6
	else:
		k.box(Vector3(0, 0.28, 0), Vector3(0.45, 0.56, 0.4), "wood_in")
		k.box(Vector3(0, 0.57, 0), Vector3(0.5, 0.03, 0.44), "wood_dark_in")
		k.box(Vector3(0, 0.4, 0.2), Vector3(0.38, 0.16, 0.012), "wood_dark_in")
		k.sphere(Vector3(0, 0.4, 0.215), 0.016, "brass", 6, 4)
	k.cyl(Vector3(-0.08, top, 0), 0.06, 0.02, "brass", 8)
	k.cyl(Vector3(-0.08, top + 0.015, 0), 0.012, 0.2, "brass", 6)
	k.cyl(Vector3(-0.08, top + 0.175, 0), 0.11, 0.14, "lamp_glow" if lit else "cream_in", 10, 0.07)
	k.box(Vector3(0.12, top + 0.015, 0.05), Vector3(0.13, 0.03, 0.18), BOOKS[int(absf(p.x * 7.0)) % BOOKS.size()], Basis(Vector3.UP, 0.3))
	_done(k)


static func wardrobe(k: MeshKit, p: Vector3, yaw: float, w: float, open := false) -> void:
	_at(k, p, yaw)
	if not open and (_scan(k, "drawer_cabinet", 1.88 * minf(1.0, w / 1.14)) if w < 1.4 else _scan(k, "vintage_cabinet_01", 2.24 * minf(1.0, w / 2.02))):
		_done(k)
		return
	k.box(Vector3(0, 1.05, 0), Vector3(w, 1.95, 0.58), "wood_in")
	k.box(Vector3(0, 2.05, 0.02), Vector3(w + 0.1, 0.08, 0.66), "wood_dark_in")
	k.box(Vector3(0, 0.05, 0), Vector3(w - 0.06, 0.1, 0.5), "wood_dark_in")
	var n := 2 if w < 1.5 else 3
	for i in n:
		var x := -w * 0.5 + w * (i + 0.5) / n
		var dw := w / n - 0.04
		if open and i == 0:
			k.box(Vector3(x, 1.05, 0.292), Vector3(dw, 1.8, 0.01), "black_in")
			k.box(Vector3(x - dw * 0.5, 1.05, 0.29 + dw * 0.5), Vector3(0.03, 1.8, dw), "wood_in")
			k.bbox(Vector3(x + 0.05, 1.3, 0.24), Vector3(dw * 0.5, 0.9, 0.08), 0.03, "navy_in")
		else:
			k.box(Vector3(x, 1.05, 0.295), Vector3(dw, 1.8, 0.02), "wood_in")
			k.box(Vector3(x, 1.45, 0.308), Vector3(dw - 0.14, 0.8, 0.012), "wood_dark_in")
			k.box(Vector3(x, 0.55, 0.308), Vector3(dw - 0.14, 0.6, 0.012), "wood_dark_in")
			k.sphere(Vector3(x + (dw * 0.5 - 0.06) * (1.0 if i == 0 else -1.0), 1.0, 0.32), 0.02, "brass", 6, 4)
	_done(k)


static func bookshelf(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, h: float, books := true) -> void:
	_at(k, p, yaw)
	var dp := 0.3
	k.box(Vector3(0, h * 0.5, -dp * 0.5 + 0.01), Vector3(w, h, 0.02), "wood_dark_in")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.015), h * 0.5, 0), Vector3(0.03, h, dp), "wood_in")
	k.box(Vector3(0, h + 0.015, 0), Vector3(w + 0.06, 0.04, dp + 0.04), "wood_dark_in")
	var rows := int(h / 0.38)
	for r in rows:
		var y := 0.04 + r * (h - 0.04) / rows
		k.box(Vector3(0, y, 0), Vector3(w - 0.06, 0.025, dp - 0.02), "planks_in")
		var x := -w * 0.5 + 0.05
		while x < w * 0.5 - 0.09:
			var roll := rng.randf()
			if not books:
				# jars, tins and bottles
				if roll < 0.25:
					x += rng.randf_range(0.08, 0.2)
				elif roll < 0.6:
					var r0 := rng.randf_range(0.04, 0.06)
					k.cyl(Vector3(x + r0, y + 0.012, 0), r0, rng.randf_range(0.1, 0.18), ["glass_clear", "cream_in", "red_in", "teal_in"][rng.randi() % 4], 8)
					k.cyl(Vector3(x + r0, y + 0.012 + 0.14, 0), r0 * 0.9, 0.02, "steel_in", 8)
					x += r0 * 2.0 + 0.02
				else:
					bottle(k, Vector3(x + 0.04, y + 0.012, 0), BOTTLES[rng.randi() % BOTTLES.size()])
					x += 0.1
				continue
			if roll < 0.12:
				x += rng.randf_range(0.06, 0.2)
				continue
			var t := rng.randf_range(0.025, 0.055)
			var bh := rng.randf_range(0.2, 0.3)
			if roll > 0.92 and x < w * 0.5 - 0.3:
				# a few books lying flat
				for j in 3:
					k.box(Vector3(x + 0.1, y + 0.03 + j * 0.035, 0), Vector3(0.2, 0.032, 0.15), BOOKS[rng.randi() % BOOKS.size()], Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)))
				x += 0.24
				continue
			var lean := Basis(Vector3(0, 0, 1), -0.25) if roll > 0.85 else Basis.IDENTITY
			var mat := BOOKS[rng.randi() % BOOKS.size()]
			k.box(Vector3(x + t * 0.5 + (0.03 if roll > 0.85 else 0.0), y + 0.012 + bh * 0.5, 0.01), Vector3(t, bh, 0.17), mat, lean)
			if t > 0.04:
				k.box(Vector3(x + t * 0.5, y + 0.012 + bh * 0.75, 0.097), Vector3(t * 0.8, 0.03, 0.004), "brass", lean)
			x += t + (0.05 if roll > 0.85 else 0.004)
	_done(k)


static func armchair(k: MeshKit, p: Vector3, yaw: float, mat: String, wide := 0.0) -> void:
	_at(k, p, yaw)
	if _scan(k, "sofa_02", 0.75) if wide > 0.5 else _scan(k, "modern_arm_chair_01", 0.95):
		_done(k)
		return
	var w := 0.7 + wide
	k.bbox(Vector3(0, 0.3, 0.02), Vector3(w, 0.26, 0.74), 0.06, mat)
	k.bbox(Vector3(0, 0.46, 0.06), Vector3(w - 0.06, 0.12, 0.6), 0.05, mat)
	k.bbox(Vector3(0, 0.72, -0.32), Vector3(w + 0.18, 0.8, 0.2), 0.08, mat, Basis(Vector3.RIGHT, -0.14))
	for sx in [-1.0, 1.0]:
		k.bbox(Vector3(sx * (w * 0.5 + 0.09), 0.42, 0.0), Vector3(0.2, 0.5, 0.78), 0.08, mat)
		for sz in [-1.0, 1.0]:
			k.cyl(Vector3(sx * (w * 0.5 + 0.02), 0.0, sz * 0.3), 0.03, 0.17, "wood_dark_in", 6)
	if wide > 0.5:
		k.bbox(Vector3(-w * 0.28, 0.6, -0.12), Vector3(0.4, 0.4, 0.14), 0.06, "cream_in", Basis(Vector3.RIGHT, -0.3) * Basis(Vector3(0, 0, 1), 0.2))
		k.bbox(Vector3(w * 0.3, 0.6, -0.12), Vector3(0.4, 0.4, 0.14), 0.06, "teal_in", Basis(Vector3.RIGHT, -0.3))
	_done(k)


static func rug(k: MeshKit, p: Vector3, yaw: float, w: float, d: float, mat := "rug_in") -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.012, 0), Vector3(w, 0.016, d), mat)
	k.box(Vector3(0, 0.014, 0), Vector3(w - 0.3, 0.016, d - 0.3), "cream_in")
	k.box(Vector3(0, 0.016, 0), Vector3(w - 0.42, 0.016, d - 0.42), mat)
	for i in int(d / 0.09):
		for sx in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 + 0.04), 0.008, -d * 0.5 + 0.045 + i * 0.09), Vector3(0.08, 0.006, 0.02), "cream_in")
	_done(k)


## Kitchen run: cupboards, sink, cooker, wall cupboards, pans.
static func kitchen(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, lit: bool) -> void:
	_at(k, p, yaw)
	var cook := 0.62
	var run := w - cook
	var cx := -w * 0.5 + run * 0.5
	k.box(Vector3(cx, 0.45, 0), Vector3(run, 0.82, 0.58), "cream_in")
	k.box(Vector3(cx, 0.03, 0.02), Vector3(run, 0.08, 0.5), "black_in")
	k.bbox(Vector3(cx, 0.885, 0.01), Vector3(run + 0.02, 0.05, 0.64), 0.012, "planks_in")
	var n := int(run / 0.5)
	for i in n:
		var x := -w * 0.5 + run * (i + 0.5) / n
		k.box(Vector3(x, 0.4, 0.292), Vector3(run / n - 0.03, 0.6, 0.012), "paint_white_in")
		k.box(Vector3(x, 0.78, 0.292), Vector3(run / n - 0.03, 0.12, 0.012), "paint_white_in")
		k.box(Vector3(x, 0.78, 0.305), Vector3(0.12, 0.016, 0.02), "brass")
		k.box(Vector3(x + run / n * 0.32, 0.5, 0.305), Vector3(0.016, 0.12, 0.02), "brass")
	# sink and tap
	var sx := -w * 0.5 + 0.55
	k.box(Vector3(sx, 0.913, 0.02), Vector3(0.56, 0.006, 0.44), "steel_in")
	k.box(Vector3(sx, 0.905, 0.02), Vector3(0.46, 0.02, 0.34), "metal_in")
	k.tube(Vector3(sx, 0.91, -0.2), Vector3(sx, 1.14, -0.2), 0.014, "steel_in", 6)
	k.tube(Vector3(sx, 1.14, -0.2), Vector3(sx, 1.12, -0.04), 0.012, "steel_in", 6)
	k.cyl(Vector3(sx + 0.42, 0.91, 0.05), 0.11, 0.012, "white_in", 12)
	k.cyl(Vector3(sx + 0.42, 0.922, 0.05), 0.105, 0.012, "white_in", 12)
	k.cyl(Vector3(sx + 0.66, 0.91, -0.08), 0.04, 0.1, "white_in", 8)
	# bread board, loaf, knife block
	var bx := -w * 0.5 + run - 0.5
	k.box(Vector3(bx, 0.92, 0.05), Vector3(0.36, 0.02, 0.24), "wood_in", Basis(Vector3.UP, 0.2))
	k.ball(Vector3(bx, 0.98, 0.05), Vector3(0.13, 0.06, 0.08), "leather_in", 10, 6, Basis(Vector3.UP, 0.2))
	k.box(Vector3(bx - 0.36, 1.0, -0.14), Vector3(0.1, 0.2, 0.14), "wood_dark_in", Basis(Vector3.RIGHT, -0.25))
	for i in 3:
		k.box(Vector3(bx - 0.39 + i * 0.03, 1.12, -0.11), Vector3(0.014, 0.08, 0.02), "black_in", Basis(Vector3.RIGHT, -0.25))
	# cooker
	var ox := w * 0.5 - cook * 0.5
	k.box(Vector3(ox, 0.45, 0), Vector3(cook - 0.02, 0.9, 0.6), "metal_in")
	k.box(Vector3(ox, 0.905, 0), Vector3(cook, 0.02, 0.62), "black_in")
	for ix in [-1.0, 1.0]:
		for iz in [-1.0, 1.0]:
			k.cyl(Vector3(ox + ix * 0.15, 0.915, iz * 0.15), 0.09, 0.012, "metal_in", 12)
	k.box(Vector3(ox, 0.45, 0.302), Vector3(cook - 0.12, 0.42, 0.012), "glass_dark")
	k.tube(Vector3(ox - 0.22, 0.72, 0.33), Vector3(ox + 0.22, 0.72, 0.33), 0.012, "steel_in", 6)
	for i in 4:
		k.tube(Vector3(ox - 0.2 + i * 0.13, 0.82, 0.3), Vector3(ox - 0.2 + i * 0.13, 0.82, 0.325), 0.02, "white_in", 8)
	# pot and kettle
	k.cyl(Vector3(ox - 0.15, 0.927, -0.15), 0.1, 0.13, "steel_in", 12)
	k.cyl(Vector3(ox - 0.15, 1.057, -0.15), 0.105, 0.012, "steel_in", 12)
	k.sphere(Vector3(ox - 0.15, 1.08, -0.15), 0.016, "black_in", 6, 4)
	for s in [-1.0, 1.0]:
		k.box(Vector3(ox - 0.15 + s * 0.12, 1.03, -0.15), Vector3(0.05, 0.012, 0.03), "black_in")
	k.ball(Vector3(ox + 0.15, 0.99, 0.15), Vector3(0.085, 0.075, 0.085), "copper", 10, 6)
	k.tube(Vector3(ox + 0.2, 0.99, 0.15), Vector3(ox + 0.3, 1.05, 0.15), 0.014, "copper", 6, 0.008)
	k.tube(Vector3(ox + 0.09, 1.06, 0.15), Vector3(ox + 0.21, 1.06, 0.15), 0.008, "black_in", 5)
	# extractor / pipe
	k.cyl(Vector3(ox, 0.92, -0.2), 0.07, FH - 0.95, "metal_in", 8)
	# wall cupboards with a shelf of crockery and hanging pans
	k.box(Vector3(cx, 1.85, -0.12), Vector3(run, 0.62, 0.34), "cream_in")
	var m := int(run / 0.5)
	for i in m:
		var x := -w * 0.5 + run * (i + 0.5) / m
		k.box(Vector3(x, 1.85, 0.056), Vector3(run / m - 0.03, 0.56, 0.012), "paint_white_in")
		k.sphere(Vector3(x + run / m * 0.34, 1.68, 0.07), 0.014, "brass", 6, 4)
	k.box(Vector3(cx, 1.42, -0.2), Vector3(run, 0.025, 0.16), "planks_in")
	for i in int(run / 0.22):
		var x := -w * 0.5 + 0.12 + i * 0.22
		if rng.randf() < 0.7:
			k.cyl(Vector3(x, 1.434, -0.2), 0.04, 0.08, ["white_in", "cream_in", "teal_in", "red_in"][rng.randi() % 4], 8)
	k.tube(Vector3(cx - run * 0.3, 1.36, -0.24), Vector3(cx + run * 0.3, 1.36, -0.24), 0.008, "steel_in", 5)
	for i in 3:
		var x := cx - run * 0.22 + i * run * 0.22
		var r := 0.1 + i * 0.015
		k.tube(Vector3(x, 1.36, -0.24), Vector3(x, 1.2, -0.24), 0.008, "black_in", 5)
		k.tube(Vector3(x, 1.2 - r, -0.26), Vector3(x, 1.2 - r, -0.22), r, "copper" if i != 1 else "metal_in", 12)
	if lit:
		k.box(Vector3(ox, 0.3, 0.31), Vector3(0.2, 0.06, 0.008), "candle")
	_done(k)


## Tiled stove with a bench round it, the heart of an alpine room.
static func kachelofen(k: MeshKit, p: Vector3, yaw: float, lit: bool) -> void:
	_at(k, p, yaw)
	if _scan(k, "scandinavian_masonry_heater", 2.0, Vector3(0, 0, 0.05)):
		k.box(Vector3(-0.78, 0.44, 0.12), Vector3(0.36, 0.05, 1.3), "planks_in")
		for q in [Vector3(-0.9, 0.21, -0.4), Vector3(-0.9, 0.21, 0.7), Vector3(-0.66, 0.21, 0.7)]:
			k.box(q, Vector3(0.06, 0.42, 0.06), "wood_dark_in")
		k.cyl(Vector3(0.95, 0.0, 0.3), 0.24, 0.3, "leather_in", 10, 0.28)
		for i in 5:
			k.tube(Vector3(0.85 + (i % 3) * 0.09, 0.12, 0.2 + (i % 2) * 0.16), Vector3(0.87 + (i % 3) * 0.09, 0.58, 0.24 + (i % 2) * 0.14), 0.055, "wood_in", 6)
		_done(k)
		return
	k.box(Vector3(0, 0.06, 0), Vector3(1.3, 0.12, 1.1), "stone_in")
	k.box(Vector3(0, 0.62, 0), Vector3(1.15, 1.0, 0.95), "tile_in")
	k.box(Vector3(0, 1.15, 0), Vector3(1.25, 0.07, 1.05), "cream_in")
	k.box(Vector3(0, 1.6, -0.05), Vector3(0.9, 0.85, 0.75), "tile_in")
	k.box(Vector3(0, 2.06, -0.05), Vector3(1.0, 0.07, 0.85), "cream_in")
	k.cyl(Vector3(0.0, 2.09, -0.1), 0.09, FH - 2.1, "metal_in", 8)
	for i in 4:
		for j in 3:
			k.bbox(Vector3(-0.4 + i * 0.267, 0.3 + j * 0.3, 0.478), Vector3(0.22, 0.24, 0.02), 0.008, "tile_in")
	k.box(Vector3(0, 0.45, 0.49), Vector3(0.36, 0.34, 0.03), "metal_in")
	k.box(Vector3(0, 0.45, 0.508), Vector3(0.22, 0.14, 0.008), "candle" if lit else "black_in")
	k.sphere(Vector3(0.14, 0.58, 0.51), 0.018, "brass", 6, 4)
	# bench
	k.box(Vector3(0, 0.44, 0.68), Vector3(1.5, 0.05, 0.36), "planks_in")
	k.box(Vector3(-0.78, 0.44, 0.12), Vector3(0.36, 0.05, 1.3), "planks_in")
	for q in [Vector3(-0.68, 0.21, 0.78), Vector3(0.68, 0.21, 0.78), Vector3(-0.9, 0.21, -0.4), Vector3(-0.9, 0.21, 0.78)]:
		var qq: Vector3 = q
		k.box(qq, Vector3(0.06, 0.42, 0.06), "wood_dark_in")
	# firewood basket
	k.cyl(Vector3(0.95, 0.0, 0.3), 0.24, 0.3, "leather_in", 10, 0.28)
	for i in 5:
		k.tube(Vector3(0.85 + (i % 3) * 0.09, 0.12, 0.2 + (i % 2) * 0.16), Vector3(0.87 + (i % 3) * 0.09, 0.58, 0.24 + (i % 2) * 0.14), 0.055, "wood_in", 6)
	_done(k)


static func fireplace(k: MeshKit, p: Vector3, yaw: float, lit: bool) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.06, 0.35), Vector3(2.4, 0.12, 0.7), "stone_in")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.82, 0.7, 0), Vector3(0.5, 1.4, 0.6), "stone_in")
	k.box(Vector3(0, 1.22, 0), Vector3(1.2, 0.36, 0.6), "stone_in")
	k.box(Vector3(0, 0.55, -0.2), Vector3(1.2, 1.0, 0.1), "black_in")
	k.box(Vector3(0, 1.44, 0.05), Vector3(2.4, 0.08, 0.78), "wood_dark_in")
	k.box(Vector3(0, FH * 0.5 + 0.74, -0.05), Vector3(1.5, FH - 1.48, 0.45), "stone_in")
	# grate and logs
	for i in 5:
		k.box(Vector3(-0.4 + i * 0.2, 0.2, 0.05), Vector3(0.02, 0.16, 0.4), "black_in")
	k.tube(Vector3(-0.42, 0.32, 0.02), Vector3(0.4, 0.34, 0.0), 0.08, "wood_dark_in", 7)
	k.tube(Vector3(-0.35, 0.33, 0.16), Vector3(0.42, 0.31, 0.2), 0.07, "wood_in", 7)
	k.tube(Vector3(-0.3, 0.46, 0.12), Vector3(0.3, 0.44, 0.06), 0.065, "wood_dark_in", 7)
	if lit:
		for i in 4:
			k.cyl(Vector3(-0.3 + i * 0.2, 0.4, 0.08), 0.07, 0.2 + (i % 2) * 0.12, "candle", 5, 0.0)
		k.box(Vector3(0, 0.24, 0.08), Vector3(0.8, 0.03, 0.3), "candle")
	# mantel: clock, candlesticks, photo
	k.box(Vector3(0, 1.62, 0.1), Vector3(0.22, 0.28, 0.1), "wood_in")
	k.tube(Vector3(0, 1.65, 0.15), Vector3(0, 1.65, 0.156), 0.08, "cream_in", 12)
	for sx in [-1.0, 1.0]:
		k.cyl(Vector3(sx * 0.7, 1.48, 0.12), 0.05, 0.02, "brass", 8)
		k.cyl(Vector3(sx * 0.7, 1.5, 0.12), 0.014, 0.16, "brass", 6)
		k.cyl(Vector3(sx * 0.7, 1.66, 0.12), 0.016, 0.12, "cream_in", 6)
		if lit:
			k.ball(Vector3(sx * 0.7, 1.8, 0.12), Vector3(0.012, 0.028, 0.012), "candle", 6, 4)
	k.box(Vector3(0.38, 1.57, 0.12), Vector3(0.14, 0.18, 0.015), "brass", Basis(Vector3.RIGHT, -0.2))
	# poker stand
	k.cyl(Vector3(1.35, 0.0, 0.3), 0.08, 0.03, "black_in", 8)
	for i in 3:
		k.tube(Vector3(1.32 + i * 0.03, 0.03, 0.3), Vector3(1.28 + i * 0.07, 0.75, 0.3), 0.008, "black_in", 5)
	_done(k)


static func clock(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	if _scan(k, "wall_clock", 0.36, Vector3(0, -0.18, 0.03)):
		_done(k)
		return
	k.tube(Vector3.ZERO, Vector3(0, 0, 0.05), 0.19, "wood_dark_in", 16)
	k.tube(Vector3(0, 0, 0.05), Vector3(0, 0, 0.056), 0.16, "cream_in", 16)
	for i in 12:
		var a := i * TAU / 12.0
		k.box(Vector3(sin(a) * 0.135, cos(a) * 0.135, 0.058), Vector3(0.012, 0.03, 0.004), "black_in", Basis(Vector3(0, 0, 1), -a))
	k.box(Vector3(0.03, 0.035, 0.06), Vector3(0.012, 0.1, 0.004), "black_in", Basis(Vector3(0, 0, 1), -0.7))
	k.box(Vector3(-0.045, 0.04, 0.062), Vector3(0.008, 0.13, 0.004), "black_in", Basis(Vector3(0, 0, 1), 0.85))
	_done(k)


## Grandfather clock.
static func long_clock(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	if _scan(k, "vintage_grandfather_clock_01", 2.15):
		_done(k)
		return
	k.box(Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.3), "wood_dark_in")
	k.box(Vector3(0, 1.05, 0), Vector3(0.36, 1.1, 0.24), "wood_in")
	k.box(Vector3(0, 1.05, 0.122), Vector3(0.2, 0.9, 0.008), "glass_dark")
	k.tube(Vector3(0, 1.4, 0.1), Vector3(0, 0.85, 0.1), 0.008, "brass", 5)
	k.tube(Vector3(0, 0.82, 0.08), Vector3(0, 0.82, 0.12), 0.07, "brass", 12)
	k.box(Vector3(0, 1.85, 0), Vector3(0.5, 0.5, 0.3), "wood_dark_in")
	k.tube(Vector3(0, 1.85, 0.15), Vector3(0, 1.85, 0.158), 0.18, "cream_in", 16)
	k.box(Vector3(0.02, 1.9, 0.16), Vector3(0.012, 0.12, 0.004), "black_in", Basis(Vector3(0, 0, 1), -0.4))
	k.box(Vector3(-0.04, 1.84, 0.162), Vector3(0.01, 0.15, 0.004), "black_in", Basis(Vector3(0, 0, 1), 1.3))
	k.box(Vector3(0, 2.14, 0), Vector3(0.58, 0.08, 0.36), "wood_dark_in")
	_done(k)


static func picture(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float, h: float) -> void:
	_at(k, p, yaw, Basis(Vector3(0, 0, 1), rng.randf_range(-0.05, 0.05)))
	k.box(Vector3(0, 0, 0.015), Vector3(w + 0.1, h + 0.1, 0.03), "brass" if rng.randf() < 0.4 else "wood_dark_in")
	var kind := rng.randi() % 3
	if kind == 0:
		# mountain view
		k.box(Vector3(0, 0, 0.032), Vector3(w, h, 0.004), "blue_in")
		k.tri(Vector3(-w * 0.5, -h * 0.5, 0.036), Vector3(w * 0.1, -h * 0.5, 0.036), Vector3(-w * 0.15, h * 0.3, 0.036), "white_in")
		k.tri(Vector3(-w * 0.1, -h * 0.5, 0.037), Vector3(w * 0.5, -h * 0.5, 0.037), Vector3(w * 0.2, h * 0.15, 0.037), "grey_in")
		k.box(Vector3(0, -h * 0.42, 0.038), Vector3(w, h * 0.16, 0.004), "pine_in")
	elif kind == 1:
		# portrait
		k.box(Vector3(0, 0, 0.032), Vector3(w, h, 0.004), "leather_in")
		k.ball(Vector3(0, h * 0.12, 0.034), Vector3(w * 0.2, h * 0.2, 0.004), "skin_in", 10, 5)
		k.box(Vector3(0, -h * 0.3, 0.036), Vector3(w * 0.6, h * 0.4, 0.004), "navy_in")
	else:
		k.box(Vector3(0, 0, 0.032), Vector3(w, h, 0.004), "cream_in")
		k.box(Vector3(0, -h * 0.2, 0.036), Vector3(w * 0.8, h * 0.3, 0.004), "pine_in")
		k.tube(Vector3(w * 0.2, h * 0.2, 0.034), Vector3(w * 0.2, h * 0.2, 0.038), h * 0.12, "yellow_in", 10)
	_done(k)


static func antlers(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0, 0.015), Vector3(0.3, 0.38, 0.03), "wood_dark_in")
	k.ball(Vector3(0, 0.02, 0.07), Vector3(0.07, 0.09, 0.06), "cream_in", 8, 5)
	for sx in [-1.0, 1.0]:
		var a := Vector3(sx * 0.04, 0.09, 0.08)
		var b := Vector3(sx * 0.3, 0.32, 0.16)
		var c := Vector3(sx * 0.36, 0.62, 0.12)
		k.tube(a, b, 0.022, "cream_in", 6, 0.018)
		k.tube(b, c, 0.018, "cream_in", 6, 0.008)
		k.tube(b, b + Vector3(sx * 0.14, 0.18, 0.08), 0.014, "cream_in", 5, 0.005)
		k.tube(a.lerp(b, 0.5), a.lerp(b, 0.5) + Vector3(sx * -0.02, 0.2, 0.1), 0.014, "cream_in", 5, 0.005)
		k.tube(b.lerp(c, 0.5), b.lerp(c, 0.5) + Vector3(sx * 0.13, 0.1, 0.02), 0.012, "cream_in", 5, 0.004)
	_done(k)


## Coat stand with coats, a hat and boots under it.
static func coat_stand(k: MeshKit, p: Vector3, yaw: float, full := true) -> void:
	_at(k, p, yaw)
	k.cyl(Vector3.ZERO, 0.2, 0.04, "wood_dark_in", 10)
	k.cyl(Vector3(0, 0.04, 0), 0.025, 1.75, "wood_dark_in", 8)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		k.tube(Vector3(0, 1.62, 0), Vector3(cos(a) * 0.16, 1.74, sin(a) * 0.16), 0.012, "wood_dark_in", 5)
	if full:
		k.bbox(Vector3(0.14, 1.2, 0.05), Vector3(0.16, 0.95, 0.44), 0.06, "navy_in")
		k.bbox(Vector3(-0.12, 1.25, -0.08), Vector3(0.14, 0.8, 0.4), 0.05, "leather_in")
		k.ball(Vector3(-0.1, 1.8, 0.12), Vector3(0.1, 0.07, 0.1), "red_in", 8, 5)
		k.tube(Vector3(0.1, 1.7, -0.1), Vector3(0.14, 1.1, -0.16), 0.03, "stripes_red_in", 6)
	for sx in [-1.0, 1.0]:
		k.bbox(Vector3(0.3 + sx * 0.09, 0.14, 0.3), Vector3(0.11, 0.28, 0.14), 0.03, "leather_in")
		k.bbox(Vector3(0.3 + sx * 0.09, 0.05, 0.38), Vector3(0.11, 0.1, 0.26), 0.03, "leather_in")
	_done(k)


static func xmas_tree(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, h: float, lit: bool) -> void:
	if GameMode.summer() and not k.winter:
		plant(k, p, h * 0.75)      # summer: a big potted plant where the Christmas tree stood
		return
	_at(k, p, rng.randf() * TAU)
	k.cyl(Vector3.ZERO, 0.2, 0.22, "red_in", 10, 0.24)
	k.cyl(Vector3(0, 0.2, 0), 0.04, h * 0.3, "wood_dark_in", 6)
	for i in 5:
		var f := i / 5.0
		k.cyl(Vector3(0, h * (0.18 + f * 0.62), 0), h * 0.3 * (1.0 - f * 0.72), h * 0.3, "pine_in", 9, 0.0, false)
	for i in 22:
		var f := rng.randf()
		var r := h * 0.3 * (1.0 - f) * 0.92 + 0.02
		var a := rng.randf() * TAU
		k.sphere(Vector3(cos(a) * r, h * (0.2 + f * 0.72), sin(a) * r), 0.03, ["gold", "red_in", "blue_in", "candle" if lit else "white_in"][i % 4], 6, 4)
	k.sphere(Vector3(0, h * 1.02, 0), 0.05, "gold", 6, 4)
	for i in 4:
		k.box(Vector3(0, h * 1.02, 0), Vector3(0.02, 0.2, 0.02), "gold", Basis(Vector3(0, 0, 1), i * PI / 4.0))
	_done(k)
	for i in 4:
		_at(k, p + Vector3(cos(i * 1.7) * 0.45, 0, sin(i * 1.7) * 0.45), rng.randf() * TAU)
		Props.gift(k, rng)
	_done(k)


static func plant(k: MeshKit, p: Vector3, s := 1.0) -> void:
	_at(k, p, p.x * 3.7)
	if _scan(k, "potted_plant_02", 0.95 * s):
		_done(k)
		return
	k.cyl(Vector3.ZERO, 0.14 * s, 0.26 * s, "leather_in", 10, 0.19 * s)
	k.cyl(Vector3(0, 0.26 * s, 0), 0.02 * s, 0.4 * s, "wood_dark_in", 5)
	for i in 7:
		var a := i * 0.9
		k.ball(Vector3(cos(a) * 0.14 * s, (0.55 + (i % 3) * 0.14) * s, sin(a) * 0.14 * s), Vector3(0.16, 0.06, 0.09) * s, "pine_in", 8, 4, Basis(Vector3.UP, -a) * Basis(Vector3(0, 0, 1), 0.5))
	_done(k)


static func floor_lamp(k: MeshKit, p: Vector3, lit: bool) -> void:
	_at(k, p)
	k.cyl(Vector3.ZERO, 0.16, 0.03, "brass", 12)
	k.cyl(Vector3(0, 0.03, 0), 0.014, 1.45, "brass", 6)
	k.cyl(Vector3(0, 1.4, 0), 0.24, 0.3, "lamp_glow" if lit else "cream_in", 12, 0.13)
	_done(k)


static func radio(k: MeshKit, l: Vector3, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.bbox(l + Vector3(0, 0.13, 0), Vector3(0.42, 0.26, 0.18), 0.03, "wood_in", b)
	k.box(l + b * Vector3(-0.07, 0.13, 0.092), Vector3(0.2, 0.16, 0.004), "cream_in", b)
	k.box(l + b * Vector3(0.12, 0.17, 0.092), Vector3(0.12, 0.05, 0.004), "candle", b)
	for i in 2:
		k.sphere(l + b * Vector3(0.08 + i * 0.08, 0.07, 0.095), 0.02, "brass", 6, 4)


static func piano(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.62, -0.1), Vector3(1.5, 1.24, 0.35), "wood_dark_in")
	k.box(Vector3(0, 1.26, -0.1), Vector3(1.56, 0.04, 0.4), "wood_dark_in")
	k.box(Vector3(0, 0.7, 0.2), Vector3(1.5, 0.08, 0.3), "wood_dark_in")
	k.box(Vector3(0, 0.75, 0.24), Vector3(1.3, 0.02, 0.16), "white_in")
	for i in 30:
		if i % 7 != 2 and i % 7 != 6:
			k.box(Vector3(-0.63 + i * 0.043, 0.768, 0.2), Vector3(0.022, 0.02, 0.09), "black_in")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.7, 0.35, 0.22), Vector3(0.08, 0.7, 0.08), "wood_dark_in")
	k.box(Vector3(0, 0.95, 0.08), Vector3(0.5, 0.3, 0.02), "wood_in", Basis(Vector3.RIGHT, -0.2))
	k.box(Vector3(0, 0.95, 0.093), Vector3(0.36, 0.24, 0.006), "paper_in", Basis(Vector3.RIGHT, -0.2))
	k.box(Vector3(0, 0.24, 0.75), Vector3(0.6, 0.04, 0.32), "leather_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.26, 0.11, 0.75 + sz * 0.12), Vector3(0.04, 0.22, 0.04), "wood_dark_in")
	_done(k)


## Bar: counter with foot rail and taps, back shelf full of bottles, stools.
static func bar(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float) -> void:
	_at(k, p, yaw)
	# back shelf against the wall (wall is at z = 0)
	k.box(Vector3(0, 0.45, 0.22), Vector3(w, 0.9, 0.44), "wood_dark_in")
	k.box(Vector3(0, 0.92, 0.22), Vector3(w + 0.04, 0.04, 0.48), "planks_in")
	k.box(Vector3(0, 1.6, 0.02), Vector3(w * 0.7, 1.0, 0.03), "glass_dark")
	k.box(Vector3(0, 1.6, 0.01), Vector3(w * 0.7 + 0.12, 1.12, 0.03), "wood_dark_in")
	for r in 3:
		var y := 1.2 + r * 0.36
		k.box(Vector3(0, y, 0.12), Vector3(w, 0.025, 0.2), "planks_in")
		var x := -w * 0.5 + 0.1
		while x < w * 0.5 - 0.1:
			if rng.randf() < 0.85:
				bottle(k, Vector3(x, y + 0.012, 0.12), BOTTLES[rng.randi() % BOTTLES.size()], rng.randf_range(0.9, 1.2))
			x += rng.randf_range(0.09, 0.15)
	# counter
	var cz := 1.5
	k.box(Vector3(0, 0.52, cz), Vector3(w, 1.04, 0.55), "wood_in")
	k.bbox(Vector3(0, 1.07, cz + 0.04), Vector3(w + 0.1, 0.06, 0.72), 0.015, "wood_dark_in")
	var n := int(w / 0.7)
	for i in n:
		k.box(Vector3(-w * 0.5 + w * (i + 0.5) / n, 0.55, cz + 0.28), Vector3(w / n - 0.1, 0.8, 0.02), "wood_dark_in")
	k.tube(Vector3(-w * 0.5, 0.18, cz + 0.4), Vector3(w * 0.5, 0.18, cz + 0.4), 0.02, "brass", 6)
	for i in 3:
		var x := -w * 0.5 + w * (i + 0.5) / 3.0
		k.tube(Vector3(x, 0.18, cz + 0.28), Vector3(x, 0.18, cz + 0.4), 0.012, "brass", 5)
	# beer taps
	k.box(Vector3(-w * 0.2, 1.2, cz), Vector3(0.4, 0.2, 0.14), "brass")
	for i in 3:
		var x := -w * 0.2 - 0.13 + i * 0.13
		k.tube(Vector3(x, 1.3, cz), Vector3(x, 1.5, cz + 0.02), 0.012, "black_in", 5)
		k.tube(Vector3(x, 1.22, cz + 0.07), Vector3(x, 1.18, cz + 0.13), 0.01, "brass", 5)
	# glasses, a till, a towel
	for i in 5:
		k.cyl(Vector3(w * 0.1 + i * 0.09, 1.1, cz - 0.1), 0.032, 0.12, "glass_clear", 8)
	k.box(Vector3(w * 0.36, 1.25, cz), Vector3(0.38, 0.3, 0.36), "metal_in")
	k.box(Vector3(w * 0.36, 1.46, cz - 0.08), Vector3(0.34, 0.14, 0.18), "metal_in")
	k.box(Vector3(w * 0.36, 1.3, cz + 0.181), Vector3(0.28, 0.1, 0.004), "cream_in")
	k.box(Vector3(-w * 0.4, 1.105, cz + 0.1), Vector3(0.3, 0.012, 0.2), "stripes_red_in", Basis(Vector3.UP, 0.3))
	_done(k)
	for i in n:
		stool(k, _loc(p, yaw, Vector3(-w * 0.5 + w * (i + 0.5) / n, 0, cz + 0.75)))


static func suitcase(k: MeshKit, p: Vector3, yaw: float, mat: String, flat := false) -> void:
	_at(k, p + Vector3(0, 0.12 if flat else 0.0, 0), yaw, Basis(Vector3.RIGHT, PI * 0.5) if flat else Basis.IDENTITY)
	k.bbox(Vector3(0, 0.24, 0), Vector3(0.7, 0.46, 0.24), 0.04, mat)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.2, 0.24, 0), Vector3(0.04, 0.47, 0.25), "leather_in")
		k.box(Vector3(sx * 0.2, 0.36, 0.126), Vector3(0.05, 0.04, 0.008), "brass")
	k.tube(Vector3(-0.1, 0.47, 0), Vector3(-0.08, 0.53, 0), 0.01, "leather_in", 5)
	k.tube(Vector3(0.1, 0.47, 0), Vector3(0.08, 0.53, 0), 0.01, "leather_in", 5)
	k.tube(Vector3(-0.08, 0.53, 0), Vector3(0.08, 0.53, 0), 0.012, "leather_in", 5)
	_done(k)


static func lockers(k: MeshKit, p: Vector3, yaw: float, n: int) -> void:
	_at(k, p, yaw)
	var w := n * 0.4
	k.box(Vector3(0, 0.95, 0), Vector3(w, 1.9, 0.45), "steel_in")
	for i in n:
		var x := -w * 0.5 + 0.2 + i * 0.4
		var ajar := i == 1
		k.box(Vector3(x + (0.16 if ajar else 0.0), 0.95, 0.232 + (0.1 if ajar else 0.0)), Vector3(0.36, 1.8, 0.012), "paint_blue_in" if i % 3 != 2 else "paint_red_in", Basis(Vector3.UP, 0.9) if ajar else Basis.IDENTITY)
		if ajar:
			k.box(Vector3(x, 0.95, 0.2), Vector3(0.36, 1.8, 0.01), "black_in")
			continue
		for j in 4:
			k.box(Vector3(x, 1.62 - j * 0.04, 0.24), Vector3(0.2, 0.012, 0.004), "black_in")
		k.box(Vector3(x + 0.12, 1.0, 0.242), Vector3(0.03, 0.1, 0.012), "steel_in")
	_done(k)


static func waiting_bench(k: MeshKit, p: Vector3, yaw: float, w: float) -> void:
	_at(k, p, yaw)
	for i in 4:
		k.box(Vector3(0, 0.45, -0.14 + i * 0.1), Vector3(w, 0.03, 0.08), "planks_in")
	for i in 3:
		k.box(Vector3(0, 0.62 + i * 0.13, -0.24 - i * 0.02), Vector3(w, 0.09, 0.03), "planks_in", Basis(Vector3.RIGHT, -0.15))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.12), 0.22, 0), Vector3(0.05, 0.44, 0.44), "metal_in")
		k.box(Vector3(sx * (w * 0.5 - 0.12), 0.7, -0.27), Vector3(0.05, 0.55, 0.05), "metal_in", Basis(Vector3.RIGHT, -0.15))
	_done(k)


static func ski_rack(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 1.3, 0.04), Vector3(1.6, 0.08, 0.08), "wood_dark_in")
	k.box(Vector3(0, 0.05, 0.12), Vector3(1.6, 0.1, 0.24), "wood_dark_in")
	for i in 7:
		if rng.randf() < 0.2:
			continue
		var x := -0.68 + i * 0.22
		var col: String = ["red_in", "blue_in", "yellow_in", "white_in", "green_in"][rng.randi() % 5]
		for s in [-0.04, 0.04]:
			var o: float = s
			k.box(Vector3(x + o, 0.95, 0.1), Vector3(0.07, 1.75, 0.014), col, Basis(Vector3.RIGHT, -0.05))
			k.box(Vector3(x + o, 1.86, 0.17), Vector3(0.07, 0.12, 0.014), col, Basis(Vector3.RIGHT, 0.6))
		k.box(Vector3(x, 0.8, 0.115), Vector3(0.15, 0.1, 0.03), "black_in")
	for i in 2:
		k.tube(Vector3(0.82 + i * 0.05, 0.0, 0.2), Vector3(0.8 + i * 0.05, 1.3, 0.05), 0.009, "steel_in", 5)
		k.tube(Vector3(0.82 + i * 0.05, 0.08, 0.19), Vector3(0.82 + i * 0.05, 0.09, 0.19), 0.05, "black_in", 8)
	_done(k)


## Cable-car control desk with levers, dials and warning lamps.
static func console(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.6), "paint_green_in")
	var slope := Basis(Vector3.RIGHT, -0.5)
	k.box(Vector3(0, 1.02, -0.05), Vector3(1.8, 0.06, 0.62), "metal_in", slope)
	k.box(Vector3(0, 1.3, -0.33), Vector3(1.8, 0.5, 0.06), "paint_green_in")
	for i in 4:
		var x := -0.66 + i * 0.3
		k.tube(Vector3(x, 1.32, -0.3), Vector3(x, 1.32, -0.29), 0.1, "cream_in", 14)
		k.box(Vector3(x + 0.02, 1.35, -0.288), Vector3(0.008, 0.09, 0.004), "red_in", Basis(Vector3(0, 0, 1), -0.5 + i * 0.4))
	for i in 5:
		k.sphere(Vector3(0.48 + (i % 3) * 0.12, 1.4 - (i / 3) * 0.14, -0.3), 0.025, ["red_in", "candle", "green_in"][i % 3], 6, 4)
	for i in 3:
		var x := -0.5 + i * 0.3
		var lean := -0.35 + i * 0.35
		k.box(Vector3(x, 1.03, 0.0), Vector3(0.05, 0.02, 0.2), "black_in", slope)
		k.tube(Vector3(x, 1.03, 0.0), Vector3(x, 1.32, lean * 0.3), 0.012, "steel_in", 6)
		k.sphere(Vector3(x, 1.34, lean * 0.3), 0.035, "red_in" if i == 0 else "black_in", 8, 5)
	k.cyl(Vector3(0.55, 0.98, 0.12), 0.06, 0.04, "red_in", 10)
	k.box(Vector3(0.2, 1.01, 0.05), Vector3(0.3, 0.012, 0.2), "paper_in", slope)
	# telephone
	k.box(Vector3(-0.75, 1.0, 0.12), Vector3(0.18, 0.08, 0.2), "black_in", slope)
	k.tube(Vector3(-0.83, 1.07, 0.06), Vector3(-0.67, 1.07, 0.06), 0.022, "black_in", 6)
	_done(k)


static func workbench(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, yaw: float, w: float) -> void:
	_at(k, p, yaw)
	k.bbox(Vector3(0, 0.86, 0), Vector3(w, 0.08, 0.7), 0.01, "wood_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * (w * 0.5 - 0.08), 0.41, sz * 0.27), Vector3(0.1, 0.82, 0.1), "wood_dark_in")
	k.box(Vector3(0, 0.25, 0), Vector3(w - 0.2, 0.04, 0.6), "planks_in")
	# vice
	k.box(Vector3(-w * 0.5 + 0.25, 0.96, 0.25), Vector3(0.16, 0.12, 0.2), "metal_in")
	k.box(Vector3(-w * 0.5 + 0.25, 1.04, 0.38), Vector3(0.16, 0.1, 0.03), "steel_in")
	k.tube(Vector3(-w * 0.5 + 0.25, 0.98, 0.36), Vector3(-w * 0.5 + 0.25, 0.98, 0.52), 0.014, "steel_in", 6)
	k.tube(Vector3(-w * 0.5 + 0.17, 0.98, 0.5), Vector3(-w * 0.5 + 0.33, 0.98, 0.5), 0.008, "steel_in", 5)
	# pegboard with tools
	k.box(Vector3(0, 1.5, -0.33), Vector3(w, 0.9, 0.03), "planks_in")
	k.box(Vector3(-w * 0.3, 1.55, -0.3), Vector3(0.03, 0.32, 0.03), "wood_in")
	k.box(Vector3(-w * 0.3, 1.72, -0.3), Vector3(0.13, 0.06, 0.05), "metal_in")
	k.box(Vector3(-w * 0.05, 1.5, -0.31), Vector3(0.4, 0.12, 0.008), "steel_in", Basis(Vector3(0, 0, 1), 0.2))
	k.box(Vector3(-w * 0.05 - 0.22, 1.47, -0.3), Vector3(0.12, 0.1, 0.03), "wood_in", Basis(Vector3(0, 0, 1), 0.2))
	for i in 4:
		k.tube(Vector3(w * 0.15 + i * 0.08, 1.4, -0.3), Vector3(w * 0.15 + i * 0.08, 1.62 + (i % 2) * 0.06, -0.3), 0.01, "steel_in", 5)
		k.tube(Vector3(w * 0.15 + i * 0.08, 1.3, -0.3), Vector3(w * 0.15 + i * 0.08, 1.4, -0.3), 0.018, ["red_in", "yellow_in", "blue_in", "wood_in"][i], 6)
	# paint pots and unfinished toys
	for i in 4:
		var x := w * 0.1 + i * 0.13
		k.cyl(Vector3(x, 0.9, -0.2), 0.045, 0.09, "steel_in", 8)
		k.cyl(Vector3(x, 0.985, -0.2), 0.04, 0.006, ["red_in", "blue_in", "yellow_in", "green_in"][i], 8)
	k.tube(Vector3(w * 0.1, 0.99, -0.2), Vector3(w * 0.14, 1.1, -0.12), 0.006, "wood_in", 4)
	Chalet._toys(k, rng, Vector3(0.1, 0.9, 0.1), w * 0.5, 0.3, 5)
	k.box(Vector3(0.3, 0.3, 0.0), Vector3(0.5, 0.06, 0.4), "wood_in")
	_done(k)


static func teddy(k: MeshKit, p: Vector3, yaw: float, s: float) -> void:
	_at(k, p, yaw)
	var fur := "fur_brown_in"
	k.ball(Vector3(0, 0.3 * s, 0), Vector3(0.26, 0.3, 0.22) * s, fur, 12, 7)
	k.ball(Vector3(0, 0.3 * s, 0.12 * s), Vector3(0.16, 0.2, 0.12) * s, "cream_in", 10, 6)
	k.ball(Vector3(0, 0.72 * s, 0.02 * s), Vector3(0.2, 0.19, 0.18) * s, fur, 12, 7)
	k.ball(Vector3(0, 0.67 * s, 0.17 * s), Vector3(0.09, 0.07, 0.08) * s, "cream_in", 8, 5)
	k.sphere(Vector3(0, 0.7 * s, 0.25 * s), 0.025 * s, "black_in", 6, 4)
	for sx in [-1.0, 1.0]:
		k.ball(Vector3(sx * 0.16 * s, 0.89 * s, 0), Vector3(0.07, 0.07, 0.04) * s, fur, 8, 5)
		k.sphere(Vector3(sx * 0.08 * s, 0.77 * s, 0.17 * s), 0.02 * s, "black_in", 6, 4)
		k.capsule(Vector3(sx * 0.24 * s, 0.45 * s, 0.02 * s), Vector3(sx * 0.36 * s, 0.22 * s, 0.14 * s), 0.075 * s, fur, 8)
		k.capsule(Vector3(sx * 0.14 * s, 0.1 * s, 0.1 * s), Vector3(sx * 0.22 * s, 0.09 * s, 0.4 * s), 0.09 * s, fur, 8)
	k.box(Vector3(0, 0.55 * s, 0.15 * s), Vector3(0.2, 0.05, 0.03) * s, "red_in")
	_done(k)


static func dollhouse(k: MeshKit, p: Vector3, yaw: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.4, -0.2), Vector3(0.9, 0.8, 0.02), "paint_white_in")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 0.45, 0.4, 0), Vector3(0.02, 0.8, 0.4), "paint_red_in")
	for y in [0.01, 0.4, 0.8]:
		var yy: float = y
		k.box(Vector3(0, yy, 0), Vector3(0.9, 0.02, 0.4), "planks_in")
	k.box(Vector3(0, 0.4, 0), Vector3(0.02, 0.8, 0.4), "paint_white_in")
	for s in [-1.0, 1.0]:
		var sg: float = s
		k.box(Vector3(sg * 0.25, 0.98, 0), Vector3(0.62, 0.02, 0.46), "paint_blue_in", Basis(Vector3(0, 0, 1), -sg * 0.7))
	k.box(Vector3(-0.25, 0.07, 0), Vector3(0.2, 0.1, 0.12), "red_in")
	k.box(Vector3(0.22, 0.46, 0.0), Vector3(0.16, 0.1, 0.24), "cream_in")
	k.box(Vector3(-0.2, 0.5, -0.1), Vector3(0.14, 0.18, 0.06), "wood_in")
	k.box(Vector3(0.25, 0.1, -0.05), Vector3(0.18, 0.16, 0.1), "teal_in")
	_done(k)


## A small model railway on a table.
static func railway_table(k: MeshKit, p: Vector3, yaw: float) -> void:
	table(k, p, yaw, 1.8, 1.2)
	_at(k, p, yaw)
	k.box(Vector3(0, 0.775, 0), Vector3(1.76, 0.02, 1.16), "green_in")
	for i in 40:
		var a := i * TAU / 40.0
		var q := Vector3(cos(a) * 0.68, 0.79, sin(a) * 0.42)
		k.box(q, Vector3(0.07, 0.008, 0.02), "wood_dark_in", Basis(Vector3.UP, -atan2(sin(a) * 0.68, cos(a) * 0.42)))
	for r in [0.94, 1.06]:
		var rr: float = r
		for i in 40:
			var a0 := i * TAU / 40.0
			var a1 := (i + 1) * TAU / 40.0
			k.tube(Vector3(cos(a0) * 0.68 * rr, 0.798, sin(a0) * 0.42 * rr), Vector3(cos(a1) * 0.68 * rr, 0.798, sin(a1) * 0.42 * rr), 0.004, "steel_in", 4, -1.0, false)
	# engine and two wagons
	for i in 3:
		var a := 0.5 + i * 0.3
		var q := Vector3(cos(a) * 0.68, 0.83, sin(a) * 0.42)
		var b := Basis(Vector3.UP, -atan2(sin(a) * 0.68, cos(a) * 0.42) + PI * 0.5)
		k.box(q, Vector3(0.16, 0.06, 0.07), ["black_in", "red_in", "blue_in"][i], b)
		if i == 0:
			k.cyl(q + Vector3(0, 0.03, 0), 0.015, 0.05, "black_in", 6)
			k.box(q + b * Vector3(-0.05, 0.05, 0), Vector3(0.06, 0.05, 0.07), "red_in", b)
	# hill, tunnel, houses, trees
	k.ball(Vector3(0.1, 0.78, 0.0), Vector3(0.3, 0.18, 0.2), "white_in", 10, 5)
	for i in 3:
		var hp := Vector3(-0.3 + i * 0.16, 0.785, -0.1 + (i % 2) * 0.18)
		k.box(hp + Vector3(0, 0.04, 0), Vector3(0.1, 0.08, 0.08), ["paint_red_in", "cream_in", "paint_yellow_in"][i])
		k.cyl(hp + Vector3(0, 0.08, 0), 0.08, 0.06, "leather_in", 4, 0.0)
	for i in 6:
		k.cyl(Vector3(-0.75 + i * 0.3, 0.785, 0.5 - (i % 2) * 0.98), 0.04, 0.14, "pine_in", 6, 0.0)
	_done(k)


static func ticket_booth(k: MeshKit, p: Vector3, yaw: float, w: float) -> void:
	_at(k, p, yaw)
	k.box(Vector3(0, 0.55, 0), Vector3(w, 1.1, 0.14), "paint_green_in")
	k.box(Vector3(0, 1.12, 0.06), Vector3(w + 0.06, 0.05, 0.4), "wood_dark_in")
	k.box(Vector3(0, 1.75, 0), Vector3(w, 1.2, 0.02), "glass_clear")
	for sx in [-1.0, 0.0, 1.0]:
		k.box(Vector3(sx * (w * 0.5 - 0.04), 1.75, 0), Vector3(0.08, 1.2, 0.1), "wood_dark_in")
	k.box(Vector3(0, 2.38, 0), Vector3(w, 0.1, 0.12), "wood_dark_in")
	k.box(Vector3(-w * 0.25, 1.2, 0), Vector3(0.34, 0.12, 0.03), "black_in")
	# behind the glass: stool, ticket rolls, stamp, lamp
	k.cyl(Vector3(-w * 0.25, 0.0, -0.7), 0.17, 0.6, "metal_in", 8)
	k.cyl(Vector3(-w * 0.25, 0.6, -0.7), 0.2, 0.06, "leather_in", 10)
	k.box(Vector3(0, 0.95, -0.28), Vector3(w - 0.1, 0.05, 0.5), "planks_in")
	for i in 3:
		k.tube(Vector3(-w * 0.1 + i * 0.1, 1.03, -0.36), Vector3(-w * 0.1 + i * 0.1, 1.03, -0.3), 0.05, ["red_in", "yellow_in", "cream_in"][i], 10)
	k.box(Vector3(w * 0.3, 1.02, -0.3), Vector3(0.26, 0.1, 0.2), "metal_in")
	_done(k)


# ------------------------------------------------------------------ rooms

static func furnish(k: MeshKit, rng: RandomNumberGenerator, kind: String, hw: float, hd: float, lit: bool, root: Node3D, st := {}) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	var ix := hw - 0.35
	var iz := hd - 0.35
	var hole := Chalet._hole(st)
	# boarded ceiling with beams (open over the stairs)
	Chalet._holed(k, Vector3(0, Y0 + FH - 0.15, 0), Vector3(ix * 2.0 + 0.3, 0.03, iz * 2.0 + 0.3), hole, "planks_in")
	var nb := int(ix * 2.0 / 1.7)
	for i in nb + 1:
		var bx := -ix + ix * 2.0 * i / nb
		var bz0 := -iz - 0.15
		if not hole.is_empty() and bx > hole[0] - 0.1 and bx < hole[1] + 0.1:
			bz0 = hole[3]
		k.box(Vector3(bx, Y0 + FH - 0.23, (bz0 + iz + 0.15) * 0.5), Vector3(0.14, 0.14, iz + 0.15 - bz0), "wood_dark_in")
	# skirting boards
	for sz in [-1.0, 1.0]:
		k.box(Vector3(0, Y0 + 0.06, sz * (iz + 0.09)) if sz < 0.0 else Vector3(0, Y0 + 2.75, sz * (iz + 0.09)), Vector3(ix * 2.0 + 0.2, 0.12, 0.03), "wood_dark_in")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * (ix + 0.09), Y0 + 0.06, 0), Vector3(0.03, 0.12, iz * 2.0 + 0.2), "wood_dark_in")
		k.box(Vector3(sx * (ix + 0.09), Y0 + 2.75, 0), Vector3(0.03, 0.06, iz * 2.0 + 0.2), "wood_dark_in")
	_ceiling_lamp(k, Vector3(0, Y0, 0), lit)
	# with stairs the rooms start in front of the stair hall
	var old := base
	var rn := root
	if not st.is_empty():
		_hall(k, r, st, hw, lit)
		var sh: float = st.hall * 0.5
		base = old * Transform3D(Basis(), Vector3(0, 0, sh))
		iz -= sh
		rn = Node3D.new()
		rn.position = Vector3(0, 0, sh)
		root.add_child(rn)
		k.xf = base
	match kind:
		"toyshop":
			_toyshop(k, r, ix, iz, lit, rn)
		"restaurant":
			_inn(k, r, ix, iz, lit, rn)
		"hotel":
			_hotel(k, r, ix, iz, lit, rn)
		"station":
			_station(k, r, ix, iz, lit, rn)
		"cabin":
			_cabin(k, r, ix, iz, lit)
		_:
			_home(k, r, ix, iz, lit, not st.is_empty())
	base = old
	_done(k)


## The stair hall behind the partition: boots, skis, boxes, a lamp.
static func _hall(k: MeshKit, rng: RandomNumberGenerator, st: Dictionary, hw: float, lit: bool) -> void:
	var y := Vector3(0, Y0, 0)
	var zm: float = (st.z0 + st.z1) * 0.5
	_flush_lamp(k, Vector3((st.xb + st.xa) * 0.5, Y0 + FH - 0.13, zm), lit)
	var x: float = st.xa + 0.5
	var end := hw - Chalet.T - 0.3
	var i := 0
	while x < end:
		match i % 3:
			0:
				_at(k, y + Vector3(x, 0, st.z0 + 0.3), 0.2)
				k.box(Vector3(0, 0.2, 0), Vector3(0.55, 0.4, 0.4), "wood_in")
				k.box(Vector3(0.05, 0.55, 0), Vector3(0.45, 0.3, 0.35), "cream_in", Basis(Vector3.UP, 0.3))
				_done(k)
			1:
				coat_stand(k, y + Vector3(x, 0, zm), 0.0, lit)
			_:
				for b in 3:
					_at(k, y + Vector3(x - 0.2 + b * 0.18, 0, st.z0 + 0.25), rng.randf() * 0.4)
					k.box(Vector3(0, 0.12, 0.05), Vector3(0.11, 0.24, 0.28), "leather_in")
					_done(k)
		x += 1.3
		i += 1
	# a dark corner under the flight: a few crates
	_at(k, y + Vector3(st.xb - 3.0, 0, zm))
	k.box(Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.6), "wood_in")
	k.box(Vector3(-0.6, 0.2, 0.05), Vector3(0.5, 0.4, 0.5), "wood_dark_in", Basis(Vector3.UP, 0.2))
	_done(k)


## A light set into the ceiling (nothing to bump your head on).
static func _flush_lamp(k: MeshKit, p: Vector3, lit: bool) -> void:
	_at(k, p)
	k.cyl(Vector3(0, -0.05, 0), 0.2, 0.05, "brass", 12)
	k.cyl(Vector3(0, -0.09, 0), 0.17, 0.05, "lamp_glow" if lit else "cream_in", 12, 0.12)
	_done(k)


static func _ceiling_lamp(k: MeshKit, p: Vector3, lit: bool) -> void:
	_at(k, p)
	k.cyl(Vector3(0, FH - 0.2, 0), 0.06, 0.03, "brass", 8)
	k.cyl(Vector3(0, FH - 0.7, 0), 0.008, 0.5, "black_in", 4)
	k.cyl(Vector3(0, FH - 0.92, 0), 0.26, 0.2, "cream_in", 12, 0.1)
	k.sphere(Vector3(0, FH - 0.92, 0), 0.07, "lamp_glow" if lit else "glass_dark", 8, 5)
	_done(k)


static func _label(root: Node3D, text: String, pos: Vector3, yaw: float, size: float, col := Color(0.9, 0.85, 0.7)) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 64
	lab.pixel_size = size / 64.0
	lab.modulate = col
	lab.outline_size = 0
	lab.position = pos
	lab.rotation.y = yaw
	lab.shaded = true
	root.add_child(lab)


static func _fire_light(root: Node3D, pos: Vector3, lit: bool) -> void:
	if not lit:
		return
	var l := Flicker.new()
	l.position = pos
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 1.8
	l.base = 1.8
	l.omni_range = 6.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	root.add_child(l)


## An ordinary home: kitchen, table, tiled stove, bed, a corner to sit in.
static func _home(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool, stair := false) -> void:
	var style := rng.randi() % 3       # 0 family, 1 hunter, 2 old couple
	var blanket: String = ["stripes_red_in", "olive_in", "teal_in"][style]
	var y := Vector3(0, Y0, 0)
	kitchen(k, rng, y + Vector3(-ix + 1.55, 0, -iz + 0.3), 0.0, 2.9, lit)
	kachelofen(k, y + Vector3(ix - 0.62, 0, -iz + 0.52), 0.0, lit)
	if not stair:       # with stairs the wardrobe lives upstairs and the hall door is here
		wardrobe(k, y + Vector3(0.75, 0, -iz + 0.3), 0.0, 1.3, not lit)
	dining(k, rng, y + Vector3(-1.3, 0, 0.35), 0.0, 1.5, 0.85, "check_in" if style != 1 else "", lit, not lit)
	rug(k, y + Vector3(-1.3, 0, 0.35), 0.0, 2.6, 2.3, "rug_in" if style != 1 else "fur_brown_in")
	# bed corner
	bed(k, y + Vector3(ix - 0.6 - (0.25 if style == 2 else 0.0), 0, iz - 1.15), 0.0, 1.5 if style == 2 else 1.0, blanket, lit)
	nightstand(k, y + Vector3(ix - 0.3, 0, iz - 2.55), -PI * 0.5, lit)
	# sitting corner on the left
	armchair(k, y + Vector3(-ix + 0.6, 0, -1.1), PI * 0.5, ["cloth_in", "leather_in", "teal_in"][style])
	floor_lamp(k, y + Vector3(-ix + 0.35, 0, -1.85), lit)
	if not stair:
		bookshelf(k, rng, y + Vector3(2.15, 0, -iz + 0.17), 0.0, 0.9, 1.9)
	coat_stand(k, y + Vector3(1.25, 0, iz - 0.35), 0.4, lit or rng.randf() < 0.5)
	clock(k, y + Vector3(-ix + 0.02, 2.0, 1.4), PI * 0.5)
	picture(k, rng, y + Vector3(ix - 0.02, 1.75, -1.2), -PI * 0.5, 0.5, 0.38)
	picture(k, rng, y + Vector3(ix - 0.02, 1.8, -0.4), -PI * 0.5, 0.3, 0.4)
	match style:
		0:
			xmas_tree(k, rng, y + Vector3(1.6, 0, 1.2), 1.7, lit)
			Chalet._toys(k, rng, y + Vector3(0.6, 0.0, 1.9), 1.2, 0.8, 5)
		1:
			antlers(k, y + Vector3(-ix + 0.02, 2.0, -0.6), PI * 0.5)
			ski_rack(k, rng, y + Vector3(2.4, 0, iz - 0.02), PI)
			# empty gun rack
			_at(k, y + Vector3(ix - 0.03, 1.5, 0.6), -PI * 0.5)
			k.box(Vector3(0, 0, 0.02), Vector3(1.1, 0.5, 0.03), "wood_dark_in")
			for sx in [-1.0, 1.0]:
				for j in 2:
					k.box(Vector3(sx * 0.4, -0.1 + j * 0.2, 0.07), Vector3(0.04, 0.03, 0.1), "wood_in")
			_done(k)
		_:
			_at(k, y + Vector3(-ix + 0.35, 0, 0.1))
			k.box(Vector3(0, 0.3, 0), Vector3(0.4, 0.6, 0.5), "wood_in")
			radio(k, Vector3(0, 0.6, 0), PI * 0.5)
			_done(k)
			long_clock(k, y + Vector3(-ix + 0.17, 0, 2.2), PI * 0.5)
			plant(k, y + Vector3(1.9, 0, 1.6), 1.2)
	if not lit:
		# left in a hurry: papers, a dropped bag, a tipped chair
		_at(k, y)
		for i in 7:
			k.box(Vector3(rng.randf_range(-1.5, 1.5), 0.02, rng.randf_range(1.2, iz - 0.6)), Vector3(0.21, 0.004, 0.3), "paper_in", Basis(Vector3.UP, rng.randf() * TAU))
		_done(k)
		suitcase(k, y + Vector3(0.5, 0, iz - 1.2), rng.randf() * TAU, "leather_in", true)


## A one-room log cabin in the woods.
static func _cabin(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool) -> void:
	var y := Vector3(0, Y0, 0)
	bed(k, y + Vector3(-ix + 0.55, 0, -iz + 1.1), PI, 0.95, "fur_brown_in", lit)
	_at(k, y + Vector3(ix - 0.5, 0, -iz + 0.45))
	k.box(Vector3(0, 0.4, 0), Vector3(0.6, 0.7, 0.5), "metal_in")
	k.cyl(Vector3(0, 0.0, 0), 0.04, 0.1, "black_in", 5)
	k.box(Vector3(0, 0.77, 0), Vector3(0.68, 0.04, 0.58), "black_in")
	k.cyl(Vector3(0.1, 0.79, -0.1), 0.07, FH - 0.8, "metal_in", 8)
	k.box(Vector3(0, 0.4, 0.252), Vector3(0.3, 0.26, 0.01), "candle" if lit else "black_in")
	k.ball(Vector3(-0.12, 0.87, 0.08), Vector3(0.08, 0.07, 0.08), "copper", 10, 6)
	for i in 6:
		k.tube(Vector3(-0.75 - (i % 3) * 0.16, 0.08 + (i / 3) * 0.15, -0.15), Vector3(-0.75 - (i % 3) * 0.16, 0.08 + (i / 3) * 0.15, 0.25), 0.075, "wood_in", 6)
	_done(k)
	table(k, y + Vector3(0.5, 0, 0.5), 0.0, 1.1, 0.7)
	_at(k, y + Vector3(0.5, 0.78, 0.5))
	_setting(k, Vector3(-0.2, 0, 0.1), 0.0)
	k.cyl(Vector3(0.3, 0, -0.1), 0.06, 0.2, "brass", 8)
	k.cyl(Vector3(0.3, 0.2, -0.1), 0.05, 0.12, "lamp_glow" if lit else "glass_clear", 8)
	_done(k)
	chair(k, y + Vector3(0.4, 0, 1.15), PI + 0.2)
	bookshelf(k, rng, y + Vector3(ix - 0.17, 0, 0.9), -PI * 0.5, 1.0, 1.6, false)
	antlers(k, y + Vector3(0, 2.1, -iz + 0.02), 0.0)
	coat_stand(k, y + Vector3(-ix + 0.4, 0, iz - 0.4), 0.0, lit)
	rug(k, y + Vector3(-0.2, 0, 0.3), 0.3, 1.8, 1.2, "fur_brown_in")
	# traps and pelts on the wall
	_at(k, y + Vector3(-ix + 0.02, 1.5, 0.9), PI * 0.5)
	k.box(Vector3(0, 0, 0.012), Vector3(0.7, 0.9, 0.02), "fur_in")
	k.box(Vector3(0, 0.5, 0.012), Vector3(0.3, 0.2, 0.02), "fur_in")
	_done(k)


static func _toyshop(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool, root: Node3D) -> void:
	var y := Vector3(0, Y0, 0)
	_ceiling_lamp(k, y + Vector3(-3.0, 0, 0.5), lit)
	_ceiling_lamp(k, y + Vector3(3.0, 0, 0.5), lit)
	# counter with till and wrapping paper
	Chalet._counter(k, y + Vector3(-1.2, 0, -iz + 1.7), 3.2)
	_at(k, y + Vector3(-1.2, 1.06, -iz + 1.7))
	for i in 4:
		k.tube(Vector3(-1.3 + i * 0.12, 0.05, -0.1), Vector3(-0.6 + i * 0.12, 0.05, -0.1), 0.04, ["stripes_red_in", "stripes_green_in", "gold", "blue_in"][i], 8)
	k.box(Vector3(-0.4, 0.06, 0.1), Vector3(0.3, 0.12, 0.2), "red_in")
	k.box(Vector3(-0.4, 0.06, 0.1), Vector3(0.31, 0.125, 0.03), "gold")
	k.sphere(Vector3(0.2, 0.05, 0.15), 0.05, "brass", 8, 5)
	_done(k)
	stool(k, y + Vector3(-1.2, 0, -iz + 1.0))
	for s in [-1.0, 1.0]:
		var sg: float = s
		Chalet._shelf(k, rng, y + Vector3(sg * (ix + 0.1), 0, -0.9), Vector3(0, 0, 1), 4.2, -sg, true)
	Chalet._shelf(k, rng, y + Vector3(-2.8, 0, -iz - 0.1), Vector3(1, 0, 0), 3.4, 1.0, true)
	workbench(k, rng, y + Vector3(ix - 1.5, 0, -iz + 0.45), 0.0, 2.2)
	stool(k, y + Vector3(ix - 1.5, 0, -iz + 1.25))
	railway_table(k, y + Vector3(2.9, 0, 1.3), 0.0)
	table(k, y + Vector3(-2.7, 0, 1.4), 0.0, 1.6, 1.0, "stripes_green_in")
	Chalet._toys(k, rng, y + Vector3(-2.7, 0.79, 1.4), 1.4, 0.8, 12)
	dollhouse(k, y + Vector3(-ix + 0.6, 0, iz - 2.3), PI * 0.5)
	teddy(k, y + Vector3(ix - 0.7, 0, iz - 0.8), -2.2, 1.5)
	teddy(k, y + Vector3(ix - 1.5, 0, iz - 0.6), -2.8, 0.7)
	xmas_tree(k, rng, y + Vector3(0.9, 0, 2.6), 2.1, lit)
	# rocking horse
	_at(k, y + Vector3(0.2, 0, 0.6), 0.6)
	k.ball(Vector3(0, 0.62, 0), Vector3(0.17, 0.19, 0.42), "white_in", 10, 6)
	k.capsule(Vector3(0, 0.72, 0.34), Vector3(0, 1.05, 0.5), 0.1, "white_in", 8, 0.08)
	k.ball(Vector3(0, 1.08, 0.6), Vector3(0.08, 0.09, 0.17), "white_in", 8, 5, Basis(Vector3.RIGHT, 0.5))
	k.box(Vector3(0, 0.83, -0.02), Vector3(0.36, 0.05, 0.36), "red_in")
	k.box(Vector3(0, 0.95, 0.4), Vector3(0.03, 0.4, 0.2), "leather_in", Basis(Vector3.RIGHT, 0.5))
	k.capsule(Vector3(0, 0.66, -0.4), Vector3(0, 0.45, -0.62), 0.04, "leather_in", 6, 0.02)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.tube(Vector3(sx * 0.12, 0.5, sz * 0.28), Vector3(sx * 0.2, 0.1, sz * 0.4), 0.04, "white_in", 6)
		for i in 8:
			var a0 := -0.6 + i * 0.15
			var a1 := a0 + 0.15
			k.tube(Vector3(sx * 0.2, 1.05 - cos(a0) * 1.0, sin(a0) * 1.3), Vector3(sx * 0.2, 1.05 - cos(a1) * 1.0, sin(a1) * 1.3), 0.03, "red_in", 5)
	_done(k)
	# model planes hanging from the ceiling
	for i in 3:
		_at(k, y + Vector3(-2.5 + i * 2.4, FH - 0.75 - (i % 2) * 0.2, -0.6 + i * 0.5), 0.6 + i * 1.3, Basis(Vector3(0, 0, 1), 0.2))
		var col: String = ["red_in", "yellow_in", "blue_in"][i]
		k.capsule(Vector3(0, 0, -0.25), Vector3(0, 0, 0.25), 0.05, col, 8, 0.03)
		k.box(Vector3(0, 0.02, -0.08), Vector3(0.75, 0.015, 0.14), col)
		k.box(Vector3(0, 0.02, 0.24), Vector3(0.26, 0.012, 0.08), col)
		k.box(Vector3(0, 0.08, 0.24), Vector3(0.012, 0.12, 0.08), col)
		k.box(Vector3(0, 0, -0.31), Vector3(0.2, 0.02, 0.006), "wood_in", Basis(Vector3(0, 0, 1), 0.7))
		k.cyl(Vector3(0, 0.02, 0), 0.003, 0.9, "black_in", 3)
		_done(k)
	# nutcrackers on parade by the door
	for i in 3:
		_at(k, y + Vector3(1.6 + i * 0.5, 0, iz - 0.3), PI)
		var c: String = ["red_in", "blue_in", "green_in"][i]
		k.cyl(Vector3.ZERO, 0.09, 0.05, "black_in", 8)
		k.cyl(Vector3(0, 0.05, 0), 0.05, 0.3, "white_in", 6)
		k.cyl(Vector3(0, 0.35, 0), 0.08, 0.26, c, 8)
		k.sphere(Vector3(0, 0.68, 0), 0.07, "skin_in", 8, 5)
		k.cyl(Vector3(0, 0.72, 0), 0.07, 0.16, "black_in", 8)
		k.box(Vector3(0, 0.63, 0.06), Vector3(0.08, 0.05, 0.04), "white_in")
		_done(k)
	_label(root, "KASSE", y + Vector3(-1.2, 0.72, -iz + 2.02), 0.0, 0.16, Color(0.9, 0.75, 0.3))


static func _inn(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool, root: Node3D) -> void:
	var y := Vector3(0, Y0, 0)
	_ceiling_lamp(k, y + Vector3(-3.6, 0, 1.2), lit)
	_ceiling_lamp(k, y + Vector3(3.6, 0, 1.2), lit)
	# bar along the back wall on the left
	bar(k, rng, y + Vector3(-ix + 2.3, 0, -iz), 0.0, 4.0)
	# kitchen behind a partition on the right
	Chalet._wall(k, y + Vector3(1.2, 0, -1.3), Vector3.RIGHT, ix - 1.2, FH, "plaster_in", [[0.8, 1.9, 0.0, 2.1]])
	Chalet._wall(k, y + Vector3(1.2, 0, -iz), Vector3.BACK, iz - 1.3, FH, "plaster_in", [])
	kitchen(k, rng, y + Vector3(ix - 1.7, 0, -iz + 0.3), 0.0, 3.2, lit)
	_at(k, y + Vector3(2.4, 0, -2.5))
	k.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.7), "steel_in")
	k.box(Vector3(0, 0.2, 0), Vector3(1.5, 0.03, 0.6), "steel_in")
	for i in 3:
		k.cyl(Vector3(-0.5 + i * 0.45, 0.9, 0.0), 0.13 + i * 0.02, 0.2, "steel_in", 12)
	k.cyl(Vector3(-0.4, 0.22, 0), 0.2, 0.3, "copper", 12)
	k.box(Vector3(0.45, 0.93, 0.15), Vector3(0.4, 0.03, 0.26), "wood_in")
	k.box(Vector3(0.5, 0.96, 0.15), Vector3(0.05, 0.02, 0.3), "steel_in", Basis(Vector3.UP, 0.5))
	_done(k)
	_label(root, "KÜCHE", y + Vector3(2.55, 2.35, -1.16), 0.0, 0.14)
	# guest room: tables, the big stove, piano
	kachelofen(k, y + Vector3(ix - 0.65, 0, -0.6), -PI * 0.5, lit)
	for tx in [-4.3, -1.3, 1.9]:
		var txx: float = tx
		dining(k, rng, y + Vector3(txx, 0, 0.9), 0.0, 1.5, 0.85, "check_in", lit, rng.randf() < 0.4)
	for tx in [-3.4, 3.0]:      # the way in from the front door stays clear
		var txx: float = tx
		dining(k, rng, y + Vector3(txx, 0, 3.0), PI * 0.5 if txx < 0.0 else 0.0, 1.5, 0.85, "check_in", lit, true)
	piano(k, y + Vector3(ix - 1.1, 0, iz - 0.2), PI)
	for i in 3:
		antlers(k, y + Vector3(-ix + 0.02, 2.1, -1.5 + i * 2.2), PI * 0.5)
	picture(k, rng, y + Vector3(0.4, 1.9, -iz + 0.03), 0.0, 0.5, 0.4)   # beside the stair door, not in it
	coat_stand(k, y + Vector3(1.4, 0, iz - 0.4), 0.0, true)
	plant(k, y + Vector3(-1.5, 0, iz - 0.4), 1.4)
	# menu board
	_at(k, y + Vector3(0.6, 1.7, -1.16))
	k.box(Vector3(0, 0, 0), Vector3(0.9, 1.1, 0.03), "black_in")
	k.box(Vector3(0, 0, -0.005), Vector3(1.0, 1.2, 0.03), "wood_in")
	_done(k)
	_label(root, "HEUTE\nGulasch  4,-\nKnödel  3,-\nGlühwein  2,-", y + Vector3(0.6, 1.7, -1.13), 0.0, 0.1, Color(0.95, 0.95, 0.9))
	_fire_light(root, y + Vector3(ix - 1.6, 0.8, -0.6), lit)


static func _hotel(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool, root: Node3D) -> void:
	var y := Vector3(0, Y0, 0)
	for x in [-6.5, 6.5]:
		var xx: float = x
		_ceiling_lamp(k, y + Vector3(xx, 0, 0.5), lit)
	# lobby carpet runner from the door to the desk
	rug(k, y + Vector3(0, 0, 1.2), 0.0, 2.2, 7.0)
	# reception
	Chalet._counter(k, y + Vector3(0, 0, -iz + 1.9), 4.6)
	_at(k, y + Vector3(0, 0, -iz))
	k.box(Vector3(0, 1.65, 0.05), Vector3(2.6, 1.2, 0.06), "wood_dark_in")
	for i in 24:
		var kx := -1.05 + (i % 8) * 0.3
		var ky := 2.05 - (i / 8) * 0.34
		k.box(Vector3(kx, ky, 0.09), Vector3(0.22, 0.26, 0.02), "wood_in")
		if i % 5 != 1:
			k.box(Vector3(kx, ky - 0.04, 0.105), Vector3(0.03, 0.1, 0.01), "brass")
			k.sphere(Vector3(kx, ky + 0.06, 0.105), 0.022, "red_in", 6, 4)
	# bell, register book, desk lamp, telephone
	k.cyl(Vector3(-0.6, 1.24, 1.95), 0.07, 0.01, "black_in", 10)
	k.sphere(Vector3(-0.6, 1.25, 1.95), 0.06, "brass", 10, 6, 0.6)
	k.box(Vector3(-1.3, 1.25, 1.95), Vector3(0.5, 0.03, 0.36), "leather_in", Basis(Vector3.UP, 0.15))
	k.box(Vector3(-1.3, 1.27, 1.95), Vector3(0.46, 0.01, 0.32), "paper_in", Basis(Vector3.UP, 0.15))
	k.cyl(Vector3(0.5, 1.24, 1.8), 0.07, 0.02, "brass", 8)
	k.tube(Vector3(0.5, 1.26, 1.8), Vector3(0.5, 1.5, 1.9), 0.01, "brass", 5)
	k.cyl(Vector3(0.5, 1.46, 1.92), 0.12, 0.1, "lamp_glow" if lit else "green_in", 10, 0.06)
	k.box(Vector3(-2.0, 1.28, 1.85), Vector3(0.2, 0.09, 0.24), "black_in")
	k.tube(Vector3(-2.1, 1.36, 1.85), Vector3(-1.9, 1.36, 1.85), 0.024, "black_in", 6)
	_done(k)
	_label(root, "REZEPTION", y + Vector3(0, 2.5, -iz + 0.1), 0.0, 0.2, Color(0.9, 0.75, 0.3))
	stool(k, y + Vector3(0.6, 0, -iz + 1.1))
	# lounge on the right: fireplace, sofas, low table
	fireplace(k, y + Vector3(6.3, 0, -iz + 0.3), 0.0, lit)
	_fire_light(root, y + Vector3(6.3, 0.8, -iz + 1.4), lit)
	rug(k, y + Vector3(6.3, 0, -iz + 2.6), 0.0, 4.2, 3.0)
	armchair(k, y + Vector3(6.3, 0, -iz + 3.7), PI, "leather_in", 0.9)
	armchair(k, y + Vector3(4.4, 0, -iz + 2.3), PI * 0.5, "leather_in")
	armchair(k, y + Vector3(8.2, 0, -iz + 2.3), -PI * 0.5, "leather_in")
	_at(k, y + Vector3(6.3, 0, -iz + 2.4))
	k.bbox(Vector3(0, 0.4, 0), Vector3(1.2, 0.05, 0.6), 0.015, "wood_dark_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.5, 0.19, sz * 0.22), Vector3(0.06, 0.38, 0.06), "wood_dark_in")
	k.box(Vector3(-0.2, 0.435, 0.05), Vector3(0.3, 0.012, 0.42), "paper_in", Basis(Vector3.UP, 0.3))
	bottle(k, Vector3(0.3, 0.425, -0.1), "leather_in")
	k.cyl(Vector3(0.45, 0.425, 0.1), 0.035, 0.08, "glass_clear", 8)
	_done(k)
	long_clock(k, y + Vector3(3.3, 0, -iz + 0.17), 0.0)
	plant(k, y + Vector3(ix - 0.5, 0, -iz + 0.5), 1.6)
	bookshelf(k, rng, y + Vector3(ix - 0.17, 0, 0.6), -PI * 0.5, 1.6, 2.0)
	# luggage left behind, a trolley
	_at(k, y + Vector3(2.4, 0, 2.6), 0.5)
	k.box(Vector3(0, 0.16, 0), Vector3(1.3, 0.05, 0.7), "brass")
	for sx in [-1.0, 1.0]:
		k.tube(Vector3(sx * 0.6, 0.18, -0.3), Vector3(sx * 0.6, 1.6, -0.3), 0.016, "brass", 6)
		for sz in [-1.0, 1.0]:
			k.tube(Vector3(sx * 0.5, 0.07, sz * 0.26 - 0.03), Vector3(sx * 0.5, 0.07, sz * 0.26 + 0.03), 0.07, "black_in", 8)
	k.tube(Vector3(-0.6, 1.6, -0.3), Vector3(0.6, 1.6, -0.3), 0.016, "brass", 6)
	_done(k)
	suitcase(k, y + Vector3(2.5, 0.19, 2.6), 0.5, "leather_in", true)
	suitcase(k, y + Vector3(2.3, 0.43, 2.7), 0.9, "navy_in", true)
	suitcase(k, y + Vector3(1.4, 0, 3.6), 2.0, "cloth_in")
	suitcase(k, y + Vector3(-1.6, 0, 3.2), 0.4, "olive_in", true)
	# left wing: a guest room behind a wall, and the stairs up
	Chalet._wall(k, y + Vector3(-3.6, 0, -iz), Vector3.BACK, iz * 2.0, FH, "plaster_in", [[iz + 0.6, iz + 1.7, 0.0, 2.1]])
	_label(root, "ZIMMER 1", y + Vector3(-3.44, 2.35, 1.15), PI * 0.5, 0.12)
	bed(k, y + Vector3(-ix + 0.9, 0, -iz + 1.15), PI, 1.5, "cloth_in", false)
	nightstand(k, y + Vector3(-ix + 2.0, 0, -iz + 0.3), 0.0, lit)
	wardrobe(k, y + Vector3(-4.6, 0, -iz + 0.3), 0.0, 1.5, true)
	armchair(k, y + Vector3(-ix + 0.6, 0, 2.0), PI * 0.5, "teal_in")
	rug(k, y + Vector3(-6.6, 0, 0.4), 0.0, 3.0, 2.2)
	suitcase(k, y + Vector3(-5.2, 0, 0.8), 1.0, "leather_in", true)
	_at(k, y + Vector3(-4.3, 0, iz - 0.4), PI)
	k.box(Vector3(0, 0.38, 0), Vector3(1.1, 0.76, 0.5), "wood_in")
	k.box(Vector3(0, 1.3, -0.22), Vector3(0.8, 0.9, 0.03), "brass")
	k.box(Vector3(0, 1.3, -0.2), Vector3(0.7, 0.8, 0.012), "glass_dark")
	k.cyl(Vector3(0.3, 0.76, 0.0), 0.13, 0.03, "white_in", 12)
	k.cyl(Vector3(0.3, 0.79, 0.0), 0.06, 0.16, "white_in", 8, 0.03)
	_done(k)
	picture(k, rng, y + Vector3(-ix + 0.02, 1.8, 0.3), PI * 0.5, 0.7, 0.5)
	_ceiling_lamp(k, y + Vector3(-6.6, 0, 0.3), lit)
	coat_stand(k, y + Vector3(1.3, 0, iz - 0.4), 0.0, false)
	plant(k, y + Vector3(-1.4, 0, iz - 0.4), 1.5)


static func _station(k: MeshKit, rng: RandomNumberGenerator, ix: float, iz: float, lit: bool, root: Node3D) -> void:
	var y := Vector3(0, Y0, 0)
	ticket_booth(k, y + Vector3(-ix + 1.6, 0, -iz + 1.6), 0.0, 3.0)
	Chalet._wall(k, y + Vector3(-ix + 3.1, 0, -iz), Vector3.BACK, 1.6, FH, "planks_in", [])
	_label(root, "FAHRKARTEN", y + Vector3(-ix + 1.6, 2.56, -iz + 1.68), 0.0, 0.16, Color(0.9, 0.75, 0.3))
	# timetable
	_at(k, y + Vector3(0.6, 1.8, -iz + 0.03))
	k.box(Vector3.ZERO, Vector3(1.9, 1.2, 0.04), "black_in")
	k.box(Vector3(0, 0, -0.008), Vector3(2.0, 1.3, 0.04), "wood_dark_in")
	_done(k)
	_label(root, "ABFAHRT  BERGSTATION\n08:15   10:15   12:15\n14:15   16:15\n— BETRIEB EINGESTELLT —", y + Vector3(0.6, 1.8, -iz + 0.06), 0.0, 0.11, Color(0.95, 0.9, 0.6))
	console(k, y + Vector3(ix - 1.2, 0, -iz + 0.4), 0.0)
	stool(k, y + Vector3(ix - 1.2, 0, -iz + 1.2))
	lockers(k, y + Vector3(ix - 0.25, 0, 0.9), -PI * 0.5, 6)
	waiting_bench(k, y + Vector3(-0.6, 0, 0.3), 0.0, 2.4)
	waiting_bench(k, y + Vector3(-0.6, 0, 0.9), PI, 2.4)
	ski_rack(k, rng, y + Vector3(2.2, 0, iz - 0.02), PI)
	# valley map on the left wall
	_at(k, y + Vector3(-ix + 0.03, 1.7, 0.9), PI * 0.5)
	k.box(Vector3.ZERO, Vector3(1.6, 1.1, 0.03), "wood_dark_in")
	k.box(Vector3(0, 0, 0.018), Vector3(1.5, 1.0, 0.004), "paper_in")
	k.ball(Vector3(-0.2, -0.1, 0.022), Vector3(0.3, 0.16, 0.002), "blue_in", 12, 4)
	for i in 5:
		k.tri(Vector3(-0.6 + i * 0.28, 0.1, 0.022), Vector3(-0.42 + i * 0.28, 0.1, 0.022), Vector3(-0.51 + i * 0.28, 0.36, 0.022), "grey_in")
	k.box(Vector3(0.3, -0.25, 0.022), Vector3(0.5, 0.012, 0.002), "red_in", Basis(Vector3(0, 0, 1), 0.6))
	_done(k)
	# a stretcher and rescue gear
	_at(k, y + Vector3(1.0, 0, 2.6), 0.2)
	for sx in [-1.0, 1.0]:
		k.tube(Vector3(sx * 0.28, 0.2, -1.0), Vector3(sx * 0.28, 0.2, 1.0), 0.02, "steel_in", 6)
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.28, 0.1, sz * 0.7), Vector3(0.03, 0.2, 0.03), "steel_in")
	k.box(Vector3(0, 0.21, 0), Vector3(0.54, 0.02, 1.7), "orange_in")
	k.bbox(Vector3(0, 0.27, 0.2), Vector3(0.5, 0.1, 1.0), 0.04, "red_in")
	_done(k)
	_at(k, y + Vector3(ix - 0.3, 0, -1.6))
	k.cyl(Vector3.ZERO, 0.3, 0.18, "orange_in", 14)
	k.cyl(Vector3(0, 0.18, 0), 0.3, 0.18, "orange_in", 14)
	k.box(Vector3(-0.6, 0.2, 0.0), Vector3(0.4, 0.4, 0.5), "red_in")
	k.box(Vector3(-0.6, 0.41, 0.0), Vector3(0.2, 0.02, 0.06), "white_in")
	k.box(Vector3(-0.6, 0.41, 0.0), Vector3(0.06, 0.02, 0.2), "white_in")
	_done(k)
	Chalet._stove(k, y + Vector3(-ix + 0.6, 0, 2.6), lit)


## Chapel you can walk into: pews, altar, candles, a little organ.
static func chapel(k: MeshKit, rng: RandomNumberGenerator) -> void:
	var w := 6.0
	var d := 10.0
	var b := k.xf
	# walls instead of a solid block
	for sx in [-1.0, 1.0]:
		var holes: Array = []
		for i in 3:
			var c := d * (i + 0.5) / 3.0
			holes.append([c - 0.4, c + 0.4, 1.6, 3.6])
		_cwall(k, Vector3(sx * (w * 0.5 - 0.15), 0.0, -d * 0.5), Vector3.BACK, d, 4.4, holes)
	_cwall(k, Vector3(-w * 0.5, 0.0, -d * 0.5 + 0.15), Vector3.RIGHT, w, 4.4, [])
	_cwall(k, Vector3(-w * 0.5, 0.0, d * 0.5 - 0.15), Vector3.RIGHT, w, 4.4, [[w * 0.5 - 0.7, w * 0.5 + 0.7, 0.0, 2.4]])
	k.box(Vector3(0, 0.05, 0), Vector3(w - 0.2, 0.1, d - 0.2), "stone_in")
	k.box(Vector3(0, 0.11, 0.3), Vector3(1.1, 0.02, d - 1.6), "cloth_in")
	# pews
	for i in 5:
		for sx in [-1.0, 1.0]:
			var pp := Vector3(sx * 1.55, 0.1, 2.6 - i * 1.15)
			k.box(pp + Vector3(0, 0.42, 0), Vector3(1.7, 0.05, 0.38), "planks_in")
			k.box(pp + Vector3(0, 0.7, -0.2 + 0.4), Vector3(1.7, 0.6, 0.04), "wood_in")
			for e in [-1.0, 1.0]:
				k.box(pp + Vector3(e * 0.83, 0.42, 0.1), Vector3(0.05, 0.84, 0.5), "wood_dark_in")
	# altar on a step
	k.box(Vector3(0, 0.2, -d * 0.5 + 1.4), Vector3(w - 0.6, 0.2, 2.2), "stone_in")
	k.box(Vector3(0, 0.8, -d * 0.5 + 1.0), Vector3(2.0, 1.0, 0.8), "stone_in")
	k.box(Vector3(0, 1.31, -d * 0.5 + 1.0), Vector3(2.3, 0.03, 1.0), "white_in")
	k.box(Vector3(0, 1.1, -d * 0.5 + 1.42), Vector3(0.8, 0.5, 0.01), "red_in")
	k.box(Vector3(0, 2.6, -d * 0.5 + 0.36), Vector3(0.12, 1.8, 0.1), "wood_dark_in")
	k.box(Vector3(0, 3.0, -d * 0.5 + 0.36), Vector3(0.9, 0.12, 0.1), "wood_dark_in")
	for sx in [-1.0, 1.0]:
		k.cyl(Vector3(sx * 0.8, 1.32, -d * 0.5 + 1.0), 0.06, 0.03, "brass", 8)
		k.cyl(Vector3(sx * 0.8, 1.35, -d * 0.5 + 1.0), 0.016, 0.3, "brass", 6)
		k.cyl(Vector3(sx * 0.8, 1.65, -d * 0.5 + 1.0), 0.02, 0.2, "cream_in", 6)
		k.ball(Vector3(sx * 0.8, 1.88, -d * 0.5 + 1.0), Vector3(0.014, 0.03, 0.014), "candle", 6, 4)
		# candle stands with many small candles
		for i in 5:
			k.cyl(Vector3(sx * 2.3, 0.3, -d * 0.5 + 2.2 + i * 0.12), 0.02, 0.9 + (i % 2) * 0.1, "brass", 5)
			k.ball(Vector3(sx * 2.3, 1.24 + (i % 2) * 0.1, -d * 0.5 + 2.2 + i * 0.12), Vector3(0.012, 0.026, 0.012), "candle", 6, 4)
	k.box(Vector3(0, 1.36, -d * 0.5 + 1.1), Vector3(0.4, 0.05, 0.3), "leather_in")
	# harmonium by the door
	k.box(Vector3(-2.2, 0.65, 3.6), Vector3(0.5, 1.1, 1.1), "wood_dark_in")
	k.box(Vector3(-1.92, 0.85, 3.6), Vector3(0.2, 0.04, 0.9), "white_in")
	k.box(Vector3(-1.5, 0.35, 3.6), Vector3(0.3, 0.5, 0.5), "wood_in")
	# hanging lamp
	k.cyl(Vector3(0, 3.2, 0.5), 0.008, 2.6, "black_in", 4)
	k.cyl(Vector3(0, 3.0, 0.5), 0.3, 0.2, "brass", 10, 0.1)
	k.sphere(Vector3(0, 3.0, 0.5), 0.09, "lamp_glow", 8, 5)
	Props.lights.append([b * Vector3(0, 2.6, 0.5), Props.WARM, 1.6, 10.0, true])
	Props.lights.append([b * Vector3(0, 1.9, -d * 0.5 + 1.6), Color(1.0, 0.6, 0.3), 1.0, 5.0, true])
	if rng.randf() < 2.0:
		k.box(Vector3(1.2, 0.14, 1.9), Vector3(0.2, 0.03, 0.14), "leather_in", Basis(Vector3.UP, 0.4))


static func _cwall(k: MeshKit, origin: Vector3, along: Vector3, length: float, height: float, holes: Array) -> void:
	var u := 0.0
	for h in holes:
		var hole: Array = h
		_cpiece(k, origin, along, u, hole[0], 0.0, height)
		_cpiece(k, origin, along, hole[0], hole[1], 0.0, hole[2])
		_cpiece(k, origin, along, hole[0], hole[1], hole[3], height)
		u = hole[1]
	_cpiece(k, origin, along, u, length, 0.0, height)


static func _cpiece(k: MeshKit, origin: Vector3, along: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
	if u1 - u0 < 0.01 or v1 - v0 < 0.01:
		return
	var t := 0.3
	var size := Vector3(absf(along.x) * (u1 - u0) + absf(along.z) * t, v1 - v0, absf(along.z) * (u1 - u0) + absf(along.x) * t)
	k.box(origin + along * (u0 + u1) * 0.5 + Vector3(0, (v0 + v1) * 0.5, 0), size, "plaster")


# ------------------------------------------------------------------ upper floors

## An upper floor: a corridor in front of the stairwell, rooms along the front, each with a doorway.
## `bx` are the window bay edges (x), so room walls never cut a window.
static func upper(k: MeshKit, rng: RandomNumberGenerator, kind: String, f: int, floors: int, hw: float, hd: float, st: Dictionary, bx: Array, lit: bool, root: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi() + f * 977
	var T := Chalet.T
	var yf := Y0 + f * FH + 0.13
	var xi0 := -hw + T
	var xi1 := hw - T
	var zi0 := -hd + T
	var zc: float = st.zc
	var zf := hd - T
	var ch := FH - 0.13               # room height up to the slab above
	# ceiling boards (open where the next flight comes through)
	var top := f == floors - 1
	Chalet._holed(k, Vector3(0, yf + ch - 0.15, (zi0 + zf) * 0.5), Vector3(xi1 - xi0, 0.03, zf - zi0), [] if top else Chalet._hole(st), "planks_in")
	# rooms: groups of window bays, at least 3.3 m wide
	var bw: float = (bx[1] as float) - (bx[0] as float)
	var per := maxi(1, ceili(3.3 / bw))
	var rooms: Array = []
	var i := 0
	var n := bx.size() - 1
	while i < n:
		var j := mini(n, i + per)
		if n - j > 0 and n - j < per:
			j = n
		rooms.append([maxf(bx[i], xi0), minf(bx[j], xi1)])
		i = j
	# corridor wall with a doorway into each room, thin walls between the rooms
	var holes: Array = []
	for rm: Array in rooms:
		holes.append([rm[0] + 0.25 - xi0, rm[0] + 1.25 - xi0, 0.0, 2.05])
	Chalet._skin = Chalet.PT
	Chalet._wall(k, Vector3(xi0, yf, zc), Vector3.RIGHT, xi1 - xi0, ch, "plaster_in", holes)
	for ri in range(1, rooms.size()):
		Chalet._wall(k, Vector3(rooms[ri][0], yf, zc), Vector3.BACK, zf - zc, ch, "plaster_in", [])
	Chalet._skin = T
	for h: Array in holes:
		for e in [h[0], h[1]]:
			k.box(Vector3(xi0 + e, yf + 1.03, zc), Vector3(0.07, 2.06, Chalet.PT + 0.05), "wood_dark_in")
		k.box(Vector3(xi0 + (h[0] + h[1]) * 0.5, yf + 2.08, zc), Vector3(1.07, 0.07, Chalet.PT + 0.05), "wood_dark_in")
	# the corridor: a runner, lights, pictures
	var cz: float = (st.z1 + zc) * 0.5
	rug(k, Vector3(0, yf, cz + 0.05), 0.0, xi1 - xi0 - 1.0, 0.8, "rug_in")
	var nl := maxi(1, int((xi1 - xi0) / 5.0))
	for li in nl:
		_flush_lamp(k, Vector3(xi0 + (xi1 - xi0) * (li + 0.5) / nl, yf + ch - 0.15, cz), lit)
	var roles := _roles(kind, rooms.size(), r)
	for ri in rooms.size():
		var rm: Array = rooms[ri]
		var x0: float = rm[0] + (0.06 if ri > 0 else 0.0)
		var x1: float = rm[1] - (0.06 if ri < rooms.size() - 1 else 0.0)
		var z0 := zc + Chalet.PT * 0.5
		picture(k, r, Vector3((rm[0] + rm[1]) * 0.5 + 0.6, yf + 1.6, zc - Chalet.PT * 0.5 - 0.02), PI, 0.5, 0.4)
		if roles[ri] == "guest":
			_label(root, "ZIMMER %d" % (f * 10 + ri + 1), Vector3(rm[0] + 0.75, yf + 2.25, zc - Chalet.PT * 0.5 - 0.02), PI, 0.1)
		_flush_lamp(k, Vector3((x0 + x1) * 0.5, yf + ch - 0.15, (z0 + zf) * 0.5), lit)
		_room(k, r, roles[ri], x0, x1, z0, zf, yf, lit)


static func _roles(kind: String, n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in n:
		match kind:
			"hotel":
				out.append("guest")
			"restaurant":
				out.append("office" if i == n - 1 else "guest")
			"toyshop":
				out.append(["store", "office", "bed", "bath"][i % 4])
			_:
				if n == 1:
					out.append("bed")
				elif i == 0:
					out.append("bed")
				elif i == n - 1:
					out.append(["kids", "office", "kids"][rng.randi() % 3])
				else:
					out.append("bath")
	return out


## One room, x0..x1 wide, z0 (corridor wall, doorway near x0) to z1 (front wall with the window).
static func _room(k: MeshKit, rng: RandomNumberGenerator, role: String, x0: float, x1: float, z0: float, z1: float, yf: float, lit: bool) -> void:
	var y := Vector3(0, yf, 0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var messy := not lit and rng.randf() < 0.6
	match role:
		"bed", "guest":
			var bw := 1.5 if role == "guest" or rng.randf() < 0.7 else 1.0
			# the doorway is at x0+0.25..x0+1.25: the bed never reaches into that lane
			var lane := x0 + 1.35
			var right := x1 - 0.5
			if right - bw < lane:
				bw = 1.0
			var stand := true
			if right - bw < lane:
				right = x1 - 0.05
				stand = false
			bw = minf(bw, right - lane)
			var bxp := right - bw * 0.5
			bed(k, y + Vector3(bxp, 0, z0 + 1.05), 0.0, bw, ["stripes_red_in", "check_in", "teal_in", "olive_in", "cloth_in"][rng.randi() % 5], not messy)
			if stand:
				nightstand(k, y + Vector3(x1 - 0.25, 0, z0 + 0.25), 0.0, lit)
			wardrobe(k, y + Vector3(x0 + 0.6, 0, z1 - 0.3), PI, 1.0, messy)
			rug(k, y + Vector3(cx, 0, cz + 0.3), 0.0, minf(2.2, x1 - x0 - 0.8), 1.4)
			armchair(k, y + Vector3(x1 - 0.55, 0, z1 - 0.8), -PI * 0.75, ["cloth_in", "leather_in", "teal_in"][rng.randi() % 3])
			picture(k, rng, Vector3(bxp, yf + 1.45, z0 + 0.02), 0.0, 0.7, 0.45)
			if role == "guest" or rng.randf() < 0.4:
				suitcase(k, y + Vector3(cx - 0.2, 0, z1 - 1.5), rng.randf() * TAU, ["leather_in", "navy_in", "olive_in"][rng.randi() % 3], rng.randf() < 0.5)
			if z1 - z0 > 4.5:
				table(k, y + Vector3(x0 + 0.7, 0, cz), 0.0, 0.7, 0.7)
				chair(k, y + Vector3(x0 + 0.7, 0, cz + 0.6), PI + 0.3)
		"kids":
			bed(k, y + Vector3(x1 - 0.7, 0, z0 + 1.05), 0.0, 1.0, ["stripes_red_in", "blue_in", "yellow_in"][rng.randi() % 3], not messy)
			if x1 - 1.75 > x0 + 1.35:
				nightstand(k, y + Vector3(x1 - 1.5, 0, z0 + 0.25), 0.0, lit)
			wardrobe(k, y + Vector3(x0 + 0.6, 0, z1 - 0.3), PI, 1.0, messy)
			rug(k, y + Vector3(cx - 0.3, 0, cz + 0.4), 0.0, 1.6, 1.2, "stripes_green_in")
			Chalet._toys(k, rng, y + Vector3(cx - 0.3, 0, cz + 0.4), 1.2, 0.8, 7)
			teddy(k, y + Vector3(x1 - 0.5, 0, z1 - 0.5), -2.4, 0.8)
			table(k, y + Vector3(x1 - 0.8, 0, z1 - 1.5), 0.0, 0.8, 0.6)
			chair(k, y + Vector3(x1 - 0.8, 0, z1 - 2.0), 0.0)
		"office":
			table(k, y + Vector3(cx, 0, z1 - 0.7), 0.0, 1.4, 0.7)
			chair(k, y + Vector3(cx, 0, z1 - 1.3), 0.0)
			radio(k, y + Vector3(cx + 0.45, 0.78, z1 - 0.75), PI)
			_at(k, y + Vector3(cx - 0.3, 0.78, z1 - 0.7))
			k.box(Vector3(0, 0.01, 0), Vector3(0.42, 0.02, 0.3), "paper_in", Basis(Vector3.UP, 0.2))
			k.box(Vector3(0.1, 0.03, -0.05), Vector3(0.3, 0.02, 0.22), "leather_in", Basis(Vector3.UP, -0.3))
			_done(k)
			bookshelf(k, rng, y + Vector3(x0 + 0.17, 0, cz + 0.4), PI * 0.5, 1.2, 1.9)
			bookshelf(k, rng, y + Vector3(x1 - 0.17, 0, cz), -PI * 0.5, 1.0, 1.9)
			floor_lamp(k, y + Vector3(cx + 0.9, 0, z1 - 0.4), lit)
			rug(k, y + Vector3(cx, 0, cz + 0.3), 0.0, 1.8, 1.4, "rug_in")
			for i in 3:
				_at(k, y + Vector3(x1 - 0.5 - i * 0.05, i * 0.36, z0 + 0.4), rng.randf_range(-0.2, 0.2))
				k.box(Vector3(0, 0.18, 0), Vector3(0.5, 0.36, 0.4), "wood_in" if i % 2 == 0 else "cream_in")
				_done(k)
		"bath":
			_bath(k, y, x0, x1, z0, z1)
		_:   # store room
			bookshelf(k, rng, y + Vector3(x0 + 0.17, 0, cz), PI * 0.5, 1.6, 2.0, false)
			bookshelf(k, rng, y + Vector3(x1 - 0.17, 0, cz), -PI * 0.5, 1.6, 2.0, false)
			for i in 7:
				var q := Vector3(rng.randf_range(x0 + 0.8, x1 - 0.8), 0, rng.randf_range(z0 + 1.4, z1 - 0.6))
				var s := rng.randf_range(0.35, 0.6)
				_at(k, y + q, rng.randf() * 0.6)
				k.box(Vector3(0, s * 0.5, 0), Vector3(s * 1.2, s, s), ["wood_in", "cream_in", "wood_dark_in"][i % 3])
				if i % 2 == 0:
					k.box(Vector3(0.05, s + s * 0.4, 0), Vector3(s * 0.9, s * 0.8, s * 0.8), "cream_in", Basis(Vector3.UP, 0.4))
				_done(k)
			Chalet._toys(k, rng, y + Vector3(cx, 0, z1 - 0.5), 1.4, 0.5, 6)


## A small bathroom: tub, basin with mirror, toilet, towels, tiled walls.
static func _bath(k: MeshKit, y: Vector3, x0: float, x1: float, z0: float, z1: float) -> void:
	var cz := (z0 + z1) * 0.5
	# tiles up to shoulder height
	k.box(y + Vector3(x1 - 0.01, 0.75, cz), Vector3(0.02, 1.5, z1 - z0 - 0.04), "white_in")
	k.box(y + Vector3((x0 + x1) * 0.5 + 0.6, 0.75, z1 - 0.01), Vector3(x1 - x0 - 1.2, 1.5, 0.02), "white_in")
	# tub along the side wall
	_at(k, y + Vector3(x1 - 0.42, 0, z1 - 1.0))
	k.bbox(Vector3(0, 0.28, 0), Vector3(0.8, 0.56, 1.75), 0.06, "white_in")
	k.box(Vector3(0, 0.5, 0), Vector3(0.62, 0.08, 1.55), "steel_in")
	k.tube(Vector3(0.3, 0.6, -0.8), Vector3(0.3, 0.8, -0.86), 0.02, "steel_in", 6)
	k.tube(Vector3(0.3, 0.8, -0.86), Vector3(0.18, 0.84, -0.86), 0.018, "steel_in", 6)
	_done(k)
	# basin and mirror against the corridor wall
	_at(k, y + Vector3(x1 - 1.2, 0, z0 + 0.25))
	k.cyl(Vector3(0, 0, 0), 0.08, 0.78, "white_in", 10, 0.06)
	k.bbox(Vector3(0, 0.82, 0.02), Vector3(0.55, 0.12, 0.42), 0.04, "white_in")
	k.box(Vector3(0, 0.88, 0.02), Vector3(0.42, 0.02, 0.3), "steel_in")
	k.tube(Vector3(0, 0.88, -0.17), Vector3(0, 1.0, -0.12), 0.015, "steel_in", 6)
	k.box(Vector3(0, 1.55, -0.2), Vector3(0.6, 0.75, 0.02), "glass_dark")
	k.box(Vector3(0, 1.55, -0.21), Vector3(0.66, 0.81, 0.02), "wood_dark_in")
	_done(k)
	# toilet
	_at(k, y + Vector3(x0 + 0.5, 0, z1 - 0.35), PI)
	k.cyl(Vector3(0, 0, 0.05), 0.15, 0.38, "white_in", 10, 0.18)
	k.ball(Vector3(0, 0.4, 0.08), Vector3(0.19, 0.04, 0.24), "white_in", 10, 4)
	k.bbox(Vector3(0, 0.62, -0.18), Vector3(0.4, 0.4, 0.17), 0.03, "white_in")
	_done(k)
	# towels on a rail
	_at(k, y + Vector3(x0 + 0.06, 1.2, cz), PI * 0.5)
	k.tube(Vector3(-0.35, 0, 0.06), Vector3(0.35, 0, 0.06), 0.012, "steel_in", 5)
	k.box(Vector3(-0.15, -0.25, 0.07), Vector3(0.3, 0.5, 0.03), "teal_in")
	k.box(Vector3(0.18, -0.2, 0.07), Vector3(0.28, 0.4, 0.03), "cream_in")
	_done(k)
	rug(k, y + Vector3(x1 - 1.0, 0, z1 - 1.0), 0.0, 0.6, 1.0, "teal_in")
