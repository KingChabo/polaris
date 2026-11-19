class_name JobBoard
extends StaticBody3D
## A notice board on a village square. It always has one job pinned to it; when that one
## is done, the next is already there. What the job is and what it pays is decided by Jobs.

var jobs: Node
var index := 0
var place := ""
var faction := ""
var prompt: String:
	get:
		return jobs.prompt_for(self) if jobs else ""


func setup(title: String) -> void:
	var k := MeshKit.new()
	for sx: float in [-0.95, 0.95]:
		k.box(Vector3(sx, 1.1, 0), Vector3(0.12, 2.4, 0.12), "wood_dark")
	k.box(Vector3(0, 1.45, 0), Vector3(1.9, 1.15, 0.06), "planks_in")
	k.box(Vector3(0, 2.38, -0.05), Vector3(2.4, 0.07, 0.62), "wood_dark", Basis(Vector3.RIGHT, 0.22))
	k.box(Vector3(0, 2.44, -0.05), Vector3(2.46, 0.06, 0.66), "wood_dark" if GameMode.summer() else "snow", Basis(Vector3.RIGHT, 0.22))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)
	for i in 7:
		var p := Vector3(-0.72 + (i % 4) * 0.48 + rng.randf_range(-0.05, 0.05), 1.72 - (i / 4) * 0.5 + rng.randf_range(-0.04, 0.04), -0.036)
		k.box(p, Vector3(0.3, 0.38, 0.004), "white_in" if i % 3 != 1 else "cream_in", Basis(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12)))
		k.box(p + Vector3(0, 0.16, -0.004), Vector3(0.02, 0.02, 0.006), "paint_red")
	add_child(k.node(false))
	var lbl := Label3D.new()
	lbl.text = title
	lbl.font_size = 64
	lbl.pixel_size = 0.0019
	lbl.modulate = Color(0.92, 0.86, 0.7)
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0.1, 0.07, 0.04)
	lbl.position = Vector3(0, 2.14, -0.04)
	lbl.rotation.y = PI
	lbl.double_sided = false
	add_child(lbl)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.9
	lamp.omni_range = 5.0
	lamp.position = Vector3(0, 2.1, -0.7)
	add_child(lamp)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 2.4, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 1.2, 0)
	add_child(cs)


func interact(_who: Node3D) -> void:
	if jobs:
		jobs.use(self)
