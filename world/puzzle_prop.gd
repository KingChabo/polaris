class_name PuzzleProp
extends StaticBody3D
## The things horror mode asks you to find and fix: a dead fuse box, a keypad lock,
## music boxes on doorsteps, fire baskets, and boards with numbers painted on them.
## What happens when you use one is decided by the Horror node.

var kind := ""        # fusebox / keypad / musicbox / brazier / board
var id := ""
var value := ""       # musicbox: its figure / board: what is painted on it
var done := false
var horror: Node
var prompt: String:
	get:
		return horror.prompt_for(self) if horror else ""

var _led: MeshInstance3D
var _fire: Node3D
var _light: OmniLight3D
var _candle: OmniLight3D
var _t := 0.0


func setup(k_kind: String, k_id: String, k_value := "") -> void:
	kind = k_kind
	id = k_id
	value = k_value
	add_to_group("puzzle")
	var k := MeshKit.new()
	var box := Vector3(0.6, 0.6, 0.6)
	var at := Vector3(0, 0.3, 0)
	match kind:
		"fusebox":
			k.cyl(Vector3(0, 0, 0), 0.06, 1.25, "steel_in", 8)
			k.bbox(Vector3(0, 1.55, 0), Vector3(0.62, 0.8, 0.24), 0.02, "metal_in")
			k.bbox(Vector3(0, 1.55, -0.125), Vector3(0.56, 0.72, 0.03), 0.01, "steel_in")
			k.box(Vector3(0.16, 1.82, -0.145), Vector3(0.12, 0.1, 0.006), "hazard_in")
			k.box(Vector3(0, 1.2, 0), Vector3(0.1, 0.4, 0.08), "black_in")              # conduit
			for i in 3:
				k.cyl(Vector3(-0.16 + i * 0.16, 1.38, -0.15), 0.035, 0.02, "black_in", 8)
			k.box(Vector3(-0.2, 1.88, -0.145), Vector3(0.08, 0.05, 0.01), "white_in")
			# a caged work lamp on a bracket above it, the only light here
			k.tube(Vector3(0, 1.95, 0.0), Vector3(0, 2.2, -0.25), 0.015, "steel_in", 5)
			k.sphere(Vector3(0, 2.13, -0.28), 0.045, "lamp_white", 8, 5)
			for i in 4:
				var a := i * TAU / 4.0
				k.tube(Vector3(sin(a) * 0.06, 2.2, -0.28 + cos(a) * 0.06), Vector3(sin(a) * 0.06, 2.07, -0.28 + cos(a) * 0.06), 0.004, "steel_in", 4)
			_candle = OmniLight3D.new()
			_candle.light_color = Color(0.85, 0.9, 1.0)
			_candle.light_energy = 0.9
			_candle.omni_range = 5.5
			_candle.position = Vector3(0, 2.05, -0.32)
			add_child(_candle)
			box = Vector3(0.7, 1.0, 0.4)
			at = Vector3(0, 1.5, 0)
		"keypad":
			k.cyl(Vector3(0, 0, 0), 0.05, 1.15, "steel_in", 8)
			k.bbox(Vector3(0, 1.3, 0), Vector3(0.2, 0.3, 0.07), 0.015, "steel_in")
			for r in 4:
				for c in 3:
					k.bbox(Vector3(-0.055 + c * 0.055, 1.38 - r * 0.05, -0.04), Vector3(0.04, 0.035, 0.015), 0.005, "black_in")
			box = Vector3(0.35, 0.5, 0.3)
			at = Vector3(0, 1.25, 0)
		"generator":
			# the filler neck of the tank, with a funnel and a gauge
			k.bbox(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.5), 0.03, "metal_in")
			k.cyl(Vector3(0.15, 0.9, 0), 0.06, 0.12, "steel_in", 10)
			k.cyl(Vector3(0.15, 1.02, 0), 0.05, 0.22, "paint_red", 10, 0.17, false)
			k.cyl(Vector3(-0.18, 0.72, -0.26), 0.09, 0.02, "white_in", 12)
			k.box(Vector3(-0.18, 0.74, -0.275), Vector3(0.01, 0.07, 0.006), "paint_red")
			box = Vector3(0.8, 1.2, 0.6)
			at = Vector3(0, 0.6, 0)
		"musicbox":
			# a crate to stand on, then the box with its crank and figure
			k.bbox(Vector3(0, 0.3, 0), Vector3(0.55, 0.6, 0.45), 0.03, "wood_dark")
			k.bbox(Vector3(0, 0.67, 0), Vector3(0.3, 0.14, 0.2), 0.012, "wood_in")
			k.box(Vector3(0, 0.745, 0), Vector3(0.28, 0.01, 0.18), "brass")
			k.box(Vector3(0, 0.82, 0.1), Vector3(0.3, 0.16, 0.012), "wood_in", Basis(Vector3.RIGHT, -0.3))   # open lid
			k.box(Vector3(0, 0.82, 0.092), Vector3(0.24, 0.12, 0.004), "glass_dark", Basis(Vector3.RIGHT, -0.3))  # mirror
			k.tube(Vector3(0.15, 0.67, 0), Vector3(0.21, 0.67, 0), 0.008, "brass", 5)
			k.tube(Vector3(0.21, 0.67, 0), Vector3(0.21, 0.62, 0), 0.007, "brass", 5)
			k.cyl(Vector3(0, 0.75, -0.02), 0.035, 0.02, "brass", 10)
			# a child's candle stuck to the crate, burning low
			k.cyl(Vector3(-0.2, 0.6, -0.12), 0.022, 0.09, "white_in", 8)
			k.cyl(Vector3(-0.2, 0.69, -0.12), 0.007, 0.03, "flame_core", 6, 0.0)
			_candle = OmniLight3D.new()
			_candle.light_color = Color(1.0, 0.62, 0.3)
			_candle.light_energy = 0.55
			_candle.omni_range = 3.2
			_candle.position = Vector3(-0.2, 0.8, -0.12)
			add_child(_candle)
			match value:
				"swan":
					k.ball(Vector3(0, 0.81, -0.02), Vector3(0.05, 0.03, 0.07), "white_in", 10, 6)
					k.tube(Vector3(0, 0.82, -0.06), Vector3(0, 0.9, -0.07), 0.01, "white_in", 6)
					k.ball(Vector3(0, 0.905, -0.085), Vector3(0.014, 0.012, 0.024), "white_in", 6, 4)
					k.ball(Vector3(0, 0.903, -0.105), Vector3(0.006, 0.005, 0.01), "orange_in", 4, 3)
				"bear":
					k.ball(Vector3(0, 0.81, -0.02), Vector3(0.04, 0.045, 0.035), "fur_brown_in", 10, 6)
					k.sphere(Vector3(0, 0.88, -0.025), 0.03, "fur_brown_in", 10, 6)
					for sx in [-1.0, 1.0]:
						var x: float = sx
						k.sphere(Vector3(x * 0.022, 0.905, -0.025), 0.011, "fur_brown_in", 6, 4)
					k.sphere(Vector3(0, 0.875, -0.054), 0.01, "black_in", 6, 4)
				_:
					k.tube(Vector3(0, 0.76, -0.02), Vector3(0, 0.83, -0.02), 0.005, "brass", 4)
					for i in 5:
						var a := i * TAU / 5.0
						k.tube(Vector3(0, 0.87, -0.02), Vector3(sin(a) * 0.045, 0.87 + cos(a) * 0.045, -0.02), 0.012, "brass", 4, 0.002)
			box = Vector3(0.6, 0.95, 0.5)
			at = Vector3(0, 0.47, 0)
		"brazier":
			for i in 3:
				var a := i * TAU / 3.0
				k.tube(Vector3(sin(a) * 0.36, 0.0, cos(a) * 0.36), Vector3(sin(a) * 0.2, 0.7, cos(a) * 0.2), 0.022, "metal_in", 6)
			k.cyl(Vector3(0, 0.66, 0), 0.3, 0.22, "metal_in", 14, 0.4, false)
			k.cyl(Vector3(0, 0.62, 0), 0.3, 0.05, "black_in", 14)
			for i in 8:
				var a := i * TAU / 8.0
				k.tube(Vector3(sin(a) * 0.3, 0.66, cos(a) * 0.3), Vector3(sin(a) * 0.4, 0.9, cos(a) * 0.4), 0.012, "metal_in", 4)
			k.tube(Vector3(-0.2, 0.72, -0.05), Vector3(0.22, 0.76, 0.06), 0.05, "wood_dark", 7)
			k.tube(Vector3(-0.1, 0.74, 0.18), Vector3(0.08, 0.78, -0.2), 0.045, "wood_dark", 7)
			k.tube(Vector3(0.16, 0.73, 0.15), Vector3(-0.15, 0.8, -0.12), 0.04, "wood_in", 7)
			box = Vector3(0.9, 1.0, 0.9)
			at = Vector3(0, 0.5, 0)
			_fire = Node3D.new()
			_fire.position = Vector3(0, 0.78, 0)
			_fire.visible = false
			add_child(_fire)
			var f := MeshKit.new()
			for i in 6:
				var a := i * TAU / 6.0
				f.cyl(Vector3(sin(a) * 0.12, -0.02, cos(a) * 0.12), 0.1, 0.38 + (i % 3) * 0.14, "flame", 7, 0.0)
			f.cyl(Vector3(0, -0.02, 0), 0.17, 0.62, "flame", 8, 0.0)
			f.cyl(Vector3(0, -0.02, 0), 0.1, 0.4, "flame_core", 8, 0.0)
			f.ball(Vector3(0, 0.0, 0), Vector3(0.24, 0.06, 0.24), "flame_core", 10, 4)       # the glowing bed of embers
			var fn := f.node(false)
			for c in fn.get_children():
				if c is GeometryInstance3D:
					(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fire.add_child(fn)
			_light = OmniLight3D.new()
			_light.light_color = Color(1.0, 0.55, 0.22)
			_light.light_energy = 0.0
			_light.omni_range = 13.0
			_light.shadow_enabled = true
			_light.position = Vector3(0, 1.3, 0)
			add_child(_light)
		"board":
			# a plank board leaning on a post with a number daubed on it in red
			k.box(Vector3(0, 0.75, 0), Vector3(0.7, 0.9, 0.04), "planks_in", Basis(Vector3.RIGHT, 0.12))
			k.tube(Vector3(0, 0, 0.2), Vector3(0, 1.3, 0.12), 0.04, "wood_dark", 6)
			var lbl := Label3D.new()
			lbl.text = value
			lbl.font_size = 96
			lbl.pixel_size = 0.0034
			lbl.modulate = Color(0.55, 0.03, 0.02)
			lbl.outline_size = 0
			lbl.position = Vector3(0, 0.76, -0.035)
			lbl.rotation = Vector3(0.12, PI, 0)
			lbl.shaded = true
			lbl.double_sided = false
			add_child(lbl)
			box = Vector3(0.75, 1.0, 0.25)
			at = Vector3(0, 0.75, 0)
	add_child(k.node(false))
	if kind in ["fusebox", "keypad", "generator"]:
		var lm := SphereMesh.new()
		lm.radius = 0.018
		lm.height = 0.036
		_led = MeshInstance3D.new()
		_led.mesh = lm
		_led.material_override = Mats.get_mat("led_red")
		_led.position = Vector3(0.2, 1.88, -0.14) if kind == "fusebox" else (Vector3(0.2, 0.74, -0.26) if kind == "generator" else Vector3(0.06, 1.42, -0.04))
		add_child(_led)
	var shape := BoxShape3D.new()
	shape.size = box
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at
	add_child(cs)


func interact(who: Node3D) -> void:
	if horror:
		horror.use(self, who)


## Shows the prop as solved (the light goes green, the fire burns).
func set_done(v: bool) -> void:
	done = v
	if _led:
		_led.material_override = Mats.get_mat("led_green" if v else "led_red")
	if _fire:
		_fire.visible = v
		_light.light_energy = 2.6 if v else 0.0


func _process(delta: float) -> void:
	_t += delta
	if _candle:
		_candle.light_energy = (0.5 + sin(_t * 9.0 + position.x) * 0.06 + sin(_t * 23.0) * 0.04) * (1.6 if kind == "fusebox" else 1.0)
		if kind == "fusebox" and not done and fmod(_t * 0.7 + position.z, 3.0) > 2.75:
			_candle.light_energy = 0.0
	if _fire and done:
		_fire.scale = Vector3(1.0 + sin(_t * 9.0) * 0.08, 1.0 + sin(_t * 13.0) * 0.18 + sin(_t * 5.1) * 0.1, 1.0 + cos(_t * 8.0) * 0.08)
		_fire.rotation.y += delta * 0.8
		_light.light_energy = 2.4 + sin(_t * 11.0) * 0.3 + sin(_t * 23.0) * 0.2
