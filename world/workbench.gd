class_name Workbench
extends StaticBody3D
## A bench with a vice and tools. E opens the crafting list.

var town: TownScreen
var prompt := "Use workbench"


func setup() -> void:
	var k := MeshKit.new()
	k.box(Vector3(0, 0.86, 0), Vector3(1.9, 0.08, 0.75), "planks")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.85, 0.41, sz * 0.3), Vector3(0.09, 0.82, 0.09), "wood_dark")
	k.box(Vector3(0, 0.25, 0), Vector3(1.7, 0.04, 0.6), "planks")
	k.box(Vector3(0, 1.5, -0.36), Vector3(1.9, 1.2, 0.04), "wood_dark")
	# vice, hammer, saw, tins, a crate of scrap below
	k.box(Vector3(-0.6, 0.98, 0.2), Vector3(0.16, 0.16, 0.3), "metal")
	k.box(Vector3(-0.6, 1.04, 0.38), Vector3(0.2, 0.2, 0.04), "steel")
	k.tube(Vector3(-0.78, 0.98, 0.42), Vector3(-0.42, 0.98, 0.42), 0.015, "steel", 5)
	k.box(Vector3(0.2, 0.93, 0.1), Vector3(0.3, 0.03, 0.03), "wood", Basis(Vector3.UP, 0.4))
	k.box(Vector3(0.33, 0.94, 0.05), Vector3(0.05, 0.05, 0.12), "metal", Basis(Vector3.UP, 0.4))
	for i in 3:
		k.cyl(Vector3(0.55 + i * 0.14, 0.9, -0.2), 0.05, 0.12 + i * 0.03, ["paint_red", "paint_blue", "steel"][i], 8)
	k.box(Vector3(-0.3, 1.5, -0.33), Vector3(0.5, 0.14, 0.01), "steel")
	k.box(Vector3(-0.62, 1.5, -0.33), Vector3(0.16, 0.1, 0.03), "wood")
	for i in 4:
		k.box(Vector3(0.2 + i * 0.16, 1.55, -0.33), Vector3(0.03, 0.3 - i * 0.04, 0.02), "steel")
	k.box(Vector3(0.45, 0.42, 0.0), Vector3(0.6, 0.3, 0.45), "wood")
	k.box(Vector3(0.45, 0.6, 0.0), Vector3(0.5, 0.08, 0.36), "rust")
	k.box(Vector3(0, 2.14, -0.2), Vector3(2.1, 0.06, 0.6), "corrugated", Basis(Vector3.RIGHT, 0.2))
	k.box(Vector3(0, 2.22, -0.2), Vector3(2.0, 0.12, 0.5), "snow", Basis(Vector3.RIGHT, 0.2))
	add_child(k.node(false))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 2.0, 0.8)
	cs.shape = shape
	cs.position.y = 1.0
	add_child(cs)


func interact(_who: Node3D) -> void:
	if town:
		town.open_craft()
