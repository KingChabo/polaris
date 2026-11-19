class_name Lever
extends StaticBody3D
## A big switch you throw once. Whoever cares listens to `thrown`.

signal thrown

var id := ""
var pulled := false
var label := "Throw the lever"
var done_text := ""
var prompt := ""
var _arm: Node3D


func setup() -> void:
	add_to_group("gated")
	prompt = label
	var k := MeshKit.new()
	k.bbox(Vector3(0, 1.1, 0), Vector3(0.5, 0.7, 0.18), 0.03, "paint_yellow_in")
	k.box(Vector3(0, 1.1, 0.1), Vector3(0.1, 0.5, 0.02), "black_in")
	k.cyl(Vector3(0, 0, 0), 0.05, 0.8, "metal_in", 6)
	add_child(k.node(false))
	var a := MeshKit.new()
	a.tube(Vector3(0, 0, 0), Vector3(0, 0.42, 0.2), 0.022, "steel_in", 6)
	a.sphere(Vector3(0, 0.44, 0.21), 0.055, "red_in", 8, 5)
	_arm = a.node(false)
	_arm.position = Vector3(0, 1.1, 0.1)
	add_child(_arm)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.0, 0.5)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 1.1, 0.1)
	add_child(cs)


func interact(who: Node3D) -> void:
	if pulled:
		return
	set_state(true)
	Sfx.play(get_tree().current_scene, "thud", global_position, 1.5, 0.8)
	if done_text != "":
		who.message.emit(done_text)
	thrown.emit()


func get_state() -> bool:
	return pulled


func set_state(v: bool) -> void:
	pulled = v
	prompt = "" if v else label
	_arm.rotation.x = 2.2 if v else 0.0
