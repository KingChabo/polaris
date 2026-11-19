class_name LootBox
extends StaticBody3D
## A chest (or a dropped bag) that holds items. Look at it and press E.

var id := ""            # fixed chests have an id so the save file can remember them
var items := {}
var title := "Chest"
var prompt := "Search chest"
var dynamic := false    # true for bags the player dropped


func setup(bag := false) -> void:
	add_to_group("loot")
	dynamic = bag
	var k := MeshKit.new()
	var size := Vector3(0.9, 0.55, 0.55)
	if bag:
		title = "Dropped bag"
		prompt = "Open bag"
		size = Vector3(0.5, 0.3, 0.4)
		k.box(Vector3(0, 0.15, 0), size, "cloth_in")
		k.box(Vector3(0, 0.31, 0), Vector3(0.3, 0.04, 0.42), "wood_dark_in")
	else:
		k.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.55), "wood_in")
		k.box(Vector3(0, 0.47, 0), Vector3(0.94, 0.14, 0.59), "wood_dark_in")
		for sx in [-0.3, 0.3]:
			var x: float = sx
			k.box(Vector3(x, 0.28, 0), Vector3(0.07, 0.56, 0.6), "metal_in")
		k.box(Vector3(0, 0.36, 0.3), Vector3(0.1, 0.12, 0.04), "gold")
	add_child(k.node(false))
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = size.y * 0.5
	add_child(cs)


func interact(who: Object) -> void:
	who.open_container(self)


func take(item: String, n := 1) -> bool:
	var have := int(items.get(item, 0))
	if have < n:
		return false
	if have == n:
		items.erase(item)
	else:
		items[item] = have - n
	return true


func put(item: String, n := 1) -> void:
	items[item] = int(items.get(item, 0)) + n


## A container with no model of its own: the boot of a wreck, a locker, a crate that is already there.
func setup_hidden(size: Vector3, label: String, verb: String) -> void:
	add_to_group("loot")
	title = label
	prompt = verb
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = size.y * 0.5
	add_child(cs)
