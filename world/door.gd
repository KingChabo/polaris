class_name Door
extends StaticBody3D
## A door you can open and close with the interact key. The hinge is at the node's origin.

var prompt := "Open door"
var is_open := false
var swing := 0.0          # not 0: always opens this way (cargo doors open outwards)
var _tween: Tween


## style: "house" (panelled, with a small window), "plank" (ledged boards), "steel" (light sheet door),
## "container" (corrugated cargo door with locking bars).
func setup(width: float, height: float, mat: String, style := "house") -> void:
	set_meta("style", style)
	var k := MeshKit.new()
	var w := width
	var h := height
	var m := mat
	match style:
		"plank":
			var n := int(maxf(round(w / 0.16), 3.0))
			for i in n:
				var bw := w / n
				k.bbox(Vector3(bw * (i + 0.5), h * 0.5, 0), Vector3(bw - 0.008, h, 0.04 + (i % 2) * 0.006), 0.006, m)
			for y: float in [0.16, 0.5, 0.84]:
				for z: float in [-0.032, 0.032]:
					k.bbox(Vector3(w * 0.5, h * y, z), Vector3(w * 0.94, 0.11, 0.028), 0.006, "wood_dark_in")
			for z: float in [-0.032, 0.032]:
				k.box(Vector3(w * 0.5, h * 0.33, z), Vector3(w * 1.02, 0.09, 0.024), "wood_dark_in", Basis(Vector3(0, 0, 1), atan2(h * 0.34, w * 0.9)))
			for y: float in [0.16, 0.84]:
				k.box(Vector3(w * 0.22, h * y, 0), Vector3(w * 0.44, 0.045, 0.1), "black_in")
		"steel":
			k.bbox(Vector3(w * 0.5, h * 0.5, 0), Vector3(w, h, 0.05), 0.008, m)
			for y: float in [0.27, 0.73]:
				k.bbox(Vector3(w * 0.5, h * y, 0), Vector3(w * 0.78, h * 0.34, 0.066), 0.012, m)
			k.box(Vector3(w * 0.5, h * 0.035, 0), Vector3(w * 0.98, h * 0.07, 0.062), "metal_in")
			k.box(Vector3(w * 0.5, h * 0.73, 0), Vector3(w * 0.3, 0.2, 0.072), "glass_dark")
		"container":
			var oz := -1.0 if swing > 0.0 else 1.0       # the outside face, where the locking bars are
			k.bbox(Vector3(w * 0.5, h * 0.5, 0), Vector3(w, h, 0.05), 0.006, m)
			for i in 5:
				k.bbox(Vector3(w * 0.5, h * (0.12 + i * 0.19), 0), Vector3(w * 0.9, h * 0.11, 0.085), 0.02, m)
			for x: float in [0.3, 0.72]:
				k.tube(Vector3(w * x, 0.03, oz * 0.06), Vector3(w * x, h - 0.03, oz * 0.06), 0.022, "worn_in", 6)
				for y: float in [0.06, 0.94]:
					k.box(Vector3(w * x, h * y, oz * 0.05), Vector3(0.09, 0.07, 0.07), "worn_in")
				k.box(Vector3(w * x - 0.09, h * 0.47, oz * 0.075), Vector3(0.24, 0.035, 0.03), "worn_in")
				k.box(Vector3(w * x - 0.2, h * 0.47, oz * 0.07), Vector3(0.05, 0.1, 0.05), "worn_in")
		_:
			# stiles and rails round two fields: a window above, a raised panel below
			var st := 0.12
			for x: float in [st * 0.5, w - st * 0.5]:
				k.bbox(Vector3(x, h * 0.5, 0), Vector3(st, h, 0.055), 0.008, m)
			k.bbox(Vector3(w * 0.5, h - 0.07, 0), Vector3(w - st * 2.0, 0.14, 0.055), 0.008, m)
			k.bbox(Vector3(w * 0.5, h * 0.52, 0), Vector3(w - st * 2.0, 0.16, 0.055), 0.008, m)
			k.bbox(Vector3(w * 0.5, 0.12, 0), Vector3(w - st * 2.0, 0.24, 0.055), 0.008, m)
			var y0 := 0.24
			var y1 := h * 0.52 - 0.08
			k.box(Vector3(w * 0.5, (y0 + y1) * 0.5, 0), Vector3(w - st * 2.0, y1 - y0, 0.024), m)
			k.bbox(Vector3(w * 0.5, (y0 + y1) * 0.5, 0), Vector3(w - st * 2.0 - 0.14, y1 - y0 - 0.14, 0.046), 0.014, m)
			var g0 := h * 0.52 + 0.08
			var g1 := h - 0.14
			k.box(Vector3(w * 0.5, (g0 + g1) * 0.5, 0), Vector3(w - st * 2.0, g1 - g0, 0.012), "glass_dark")
			k.box(Vector3(w * 0.5, (g0 + g1) * 0.5, 0), Vector3(0.028, g1 - g0, 0.03), m)
			k.box(Vector3(w * 0.5, (g0 + g1) * 0.5, 0), Vector3(w - st * 2.0, 0.028, 0.03), m)
			# drip rail outside, kick plate
			k.box(Vector3(w * 0.5, 0.05, 0.034), Vector3(w * 0.96, 0.05, 0.03), "metal_in", Basis(Vector3(1, 0, 0), 0.5))
	# hinges
	if style != "container":
		for y: float in [0.1, 0.5, 0.9]:
			k.cyl(Vector3(0.0, h * y - 0.05, 0.0), 0.014, 0.1, "metal_in", 6)
		# lock plate with a lever handle on both sides
		var hx := w - 0.07
		var hy := h * 0.47
		for z: float in [-1.0, 1.0]:
			k.bbox(Vector3(hx, hy - 0.03, z * 0.031), Vector3(0.04, 0.2, 0.008), 0.003, "metal_in")
			k.tube(Vector3(hx, hy, z * 0.03), Vector3(hx, hy, z * 0.075), 0.01, "metal_in", 6)
			k.capsule(Vector3(hx, hy, z * 0.072), Vector3(hx - 0.12, hy - 0.004, z * 0.072), 0.009, "metal_in", 6)
			k.cyl(Vector3(hx, hy - 0.1, z * 0.034), 0.008, 0.012, "black_in", 6)
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(width * 0.5, height * 0.5, 0)
	add_child(cs)


func interact(who: Node3D) -> void:
	is_open = not is_open
	prompt = "Close door" if is_open else "Open door"
	var target := 0.0
	if is_open:
		# swing away from whoever opens it
		var local: Vector3 = get_parent().to_local(who.global_position) - position
		target = 1.85 if local.z > 0.0 else -1.85
		if swing != 0.0:
			target = swing
	var scene := get_tree().current_scene
	Sfx.play(scene, "click", global_position, 1.2, 0.7 if is_open else 0.55)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", target, 0.9).set_trans(Tween.TRANS_SINE)
	if not is_open:
		_tween.tween_callback(func() -> void: Sfx.play(scene, "thud", global_position, 0.5, 1.5))
