class_name Note
extends StaticBody3D
## A document lying around: a letter, a log page, an order. E reads it and files it in the journal.

var id := ""
var title := ""
var text := ""
var read := false
var prompt: String:
	get:
		return "Read: " + title


func setup(kind := "paper") -> void:
	add_to_group("gated")
	add_to_group("note")
	var k := MeshKit.new()
	match kind:
		"folder":
			k.box(Vector3(0, 0.012, 0), Vector3(0.24, 0.024, 0.32), "paint_red_in")
			k.box(Vector3(0.01, 0.027, 0.0), Vector3(0.2, 0.006, 0.28), "paper_in")
		"book":
			k.box(Vector3(0, 0.02, 0), Vector3(0.17, 0.04, 0.24), "leather_in")
			k.box(Vector3(0.005, 0.02, 0), Vector3(0.165, 0.032, 0.225), "paper_in")
		_:
			k.box(Vector3(0, 0.004, 0), Vector3(0.21, 0.008, 0.29), "paper_in")
			for i in 5:
				k.box(Vector3(0, 0.009, -0.09 + i * 0.045), Vector3(0.15, 0.002, 0.008), "grey_in")
	add_child(k.node(false))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.36, 0.2, 0.42)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.08
	add_child(cs)


func interact(who: Node3D) -> void:
	read = true
	var main := who.get_parent()
	if main.get("reader"):
		main.reader.show_note(self)


func get_state() -> bool:
	return read


func set_state(v: bool) -> void:
	read = v
