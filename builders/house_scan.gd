class_name HouseScan
extends RefCounted
## Summer houses built in Blender. The model is the
## outside shell: walls with real openings (plaster on the room side), windows, roof, chimney,
## gutters. Chalet still builds floors, stairs, rooms, the door, porch, sign and lights, so the
## model must keep the code's sizes, door and window places. Colours come from the house palette.

const DIR := "houses/"
## model -> [width, depth, floors]; Chalet uses these sizes when the model is there
const SIZES := {
	"house": [9.0, 7.8, 2], "house_small": [8.4, 7.2, 1], "hotel": [20.0, 12.0, 3],
	"restaurant": [14.0, 10.0, 2], "toyshop": [12.0, 9.0, 2], "station": [10.0, 9.0, 1], "cabin": [6.0, 5.3, 1],
}
static var _mats := {}


## The model for a house kind and storey count, or "" (then the code builds the house).
static func model_for(kind: String, floors: int) -> String:
	if not GameMode.summer():
		return ""
	var id := kind
	if kind == "house":
		id = "house" if floors > 1 else "house_small"
	return id if SIZES.has(id) and ModelLib.has(DIR + id) else ""


## Puts the shell into a house root, painted with the palette, with a solid body.
static func attach(root: Node3D, id: String, clad: String, roof: String, door: String, trim: String) -> void:
	var scene := ModelLib.spawn(DIR + id)
	if scene == null:
		return
	scene.name = "Shell"
	root.add_child(scene)
	var body := StaticBody3D.new()
	body.name = "ShellBody"
	root.add_child(body)
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.visibility_range_end = 450.0
		for si in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(si)
			var m := _material(src.resource_name if src else "", id, clad, roof, door, trim)
			if m:
				mi.set_surface_override_material(si, m)
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		cs.transform = root.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _rel(mi, root)
		body.add_child(cs)


static func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c is Node3D:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func _col(name: String, fallback: Color) -> Color:
	var d: Array = Mats.DEFS.get(name, [0, fallback])
	return d[1]


static func _material(name: String, id: String, clad: String, roof: String, door: String, trim: String) -> Material:
	var base := name.get_slice(".", 0)
	var key := "%s|%s|%s|%s|%s|%s" % [base, id == "hotel", clad, roof, door, trim]
	if _mats.has(key):
		return _mats[key]
	var m: Material = null
	match base:
		"wall":
			m = _pbr("plaster_paint" if id == "hotel" else "siding_paint", _col(clad, Color(0.5, 0.2, 0.15)).lightened(0.06), 0.0)
		"roof":
			m = _pbr("metal_sheet_paint", _col(roof, Color(0.2, 0.2, 0.2)).lightened(0.08), 0.12)
		"trim":
			m = _pbr("siding_paint", _col(trim, Color(0.86, 0.85, 0.8)), 0.0)
		"door":
			m = _pbr("boards_paint", _col(door, Color(0.2, 0.3, 0.2)), 0.0)
		"wall_in":
			m = Mats.get_mat("wall_in")
		"logs", "roof_boards", "deck":
			m = _pbr("boards", Color(1, 1, 1), 0.0)
		"trim_dark":
			m = _pbr("boards", Color(0.55, 0.5, 0.48), 0.0)
		"concrete":
			m = _pbr("concrete_floor_02", Color(1, 1, 1), 0.0)
		"brick":
			m = _pbr("red_brick_03", Color(1, 1, 1), 0.0)
		"glass":
			m = Mats.get_mat("glass_clear")
	_mats[key] = m
	return m


static func _pbr(tex: String, col: Color, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = ModelLib.tex(tex, "diff")
	var n := ModelLib.tex(tex, "nor")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.9
	var r := ModelLib.tex(tex, "rough")
	if r:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
