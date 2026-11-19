class_name LockDoor
extends Door
## A door that needs a key (an item) before it opens. Remembers that it was unlocked.

var id := ""
var key := ""
var locked := true


func setup_steel(width: float, height: float, stripe := "paint_yellow") -> void:
	var k := MeshKit.new()
	k.bbox(Vector3(width * 0.5, height * 0.5, 0), Vector3(width, height, 0.1), 0.02, "steel_in")
	k.box(Vector3(width * 0.5, height * 0.78, 0), Vector3(width * 0.86, 0.14, 0.12), stripe + "_in")
	for y: float in [0.12, 0.5, 0.92]:
		var yy: float = y
		k.box(Vector3(width * 0.5, height * yy, 0), Vector3(width * 0.94, 0.05, 0.13), "metal_in")
	for z: float in [-0.09, 0.09]:
		var zz: float = z
		k.cyl(Vector3(width * 0.84, height * 0.47, zz - 0.02), 0.11, 0.04, "metal_in", 10)
		k.tube(Vector3(width * 0.84, height * 0.47, zz), Vector3(width * 0.84, height * 0.47 - 0.22, zz), 0.018, "metal_in", 5)
	for y: float in [0.2, 0.8]:
		var yy: float = y
		k.box(Vector3(0.04, height * yy, 0), Vector3(0.1, 0.2, 0.16), "metal_in")
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.14)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(width * 0.5, height * 0.5, 0)
	add_child(cs)


func lock(door_id: String, key_item: String) -> void:
	id = door_id
	key = key_item
	locked = true
	prompt = "Locked door"
	add_to_group("gated")


func interact(who: Node3D) -> void:
	if locked:
		if key != "" and who.inv.count(key) > 0:
			locked = false
			who.message.emit("Unlocked with the %s." % Items.name_of(key).to_lower())
			Sfx.play(get_tree().current_scene, "thud", global_position, 0.6, 1.6)
		else:
			who.message.emit("Locked. You need the %s." % Items.name_of(key).to_lower())
			return
	super.interact(who)


func get_state() -> bool:
	return not locked


func set_state(v: bool) -> void:
	locked = not v
	if locked:
		prompt = "Locked door"
		is_open = false
		rotation.y = 0.0
	elif not is_open:
		prompt = "Open door"
