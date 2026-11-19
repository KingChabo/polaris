class_name ModelLib
extends RefCounted
## Models and textures made in Blender (scanned CC0 assets from Poly Haven, cleaned up,
## reduced and exported for Godot). Everything here is optional: when a file is missing
## the game falls back to the shapes it builds in code.

const MODELS := "res://assets/models/"
const TEX := "res://assets/textures/"

static var _scenes := {}
static var _meshes := {}
static var _tex := {}
static var enabled := true
static var skip := {}       # ids left out (for measuring)


static func has(id: String) -> bool:
	return enabled and not skip.has(id) and ResourceLoader.exists(MODELS + id + ".glb")


## A fresh copy of a model, or null.
static func spawn(id: String) -> Node3D:
	if not has(id):
		return null
	if not _scenes.has(id):
		_scenes[id] = load(MODELS + id + ".glb")
	var ps: PackedScene = _scenes[id]
	return ps.instantiate() as Node3D if ps else null


## All meshes of a model merged into one ArrayMesh (one surface per material), with the
## transform baked in. For MultiMesh (trees, rocks) and for merging into MeshKit nodes.
static func mesh(id: String, lod := "", height := 0.0, snow := 0.0, foliage := 0.0) -> ArrayMesh:
	if GameMode.summer():
		snow = 0.0
	var key := "%s%s_%.2f_%.2f" % [id, lod, height, snow]
	if _meshes.has(key):
		return _meshes[key]
	var file := id + lod
	if not (enabled and not skip.has(id) and ResourceLoader.exists(MODELS + file + ".glb")):
		return null
	var root := (load(MODELS + file + ".glb") as PackedScene).instantiate() as Node3D
	var out := ArrayMesh.new()
	_collect(root, Transform3D.IDENTITY, out)
	root.free()
	if height > 0.0:
		# stand it on y = 0 and make it `height` tall
		var bb := out.get_aabb()
		var k := height / maxf(bb.size.y, 0.001)
		var c := bb.get_center()
		out = _scaled(out, Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-c.x * k, -bb.position.y * k, -c.z * k)))
	if snow > 0.0 or foliage > 0.0:
		for si in out.get_surface_count():
			out.surface_set_material(si, snowy(out.surface_get_material(si), snow, foliage))
	_meshes[key] = out
	return out


static func _scaled(m: ArrayMesh, xf: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in m.get_surface_count():
		var arr := m.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			v[i] = xf * v[i]
		arr[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, m.surface_get_material(si))
	return out


static var _snowy := {}


## The same textures in a material that lets snow settle on top (outdoor scans).
static func snowy(src: Material, snow: float, foliage := 0.0) -> Material:
	if not src is BaseMaterial3D:
		return src
	var key := "%d_%.2f_%.2f" % [src.get_instance_id(), snow, foliage]
	if _snowy.has(key):
		return _snowy[key]
	var b := src as BaseMaterial3D
	var m := ShaderMaterial.new()
	m.shader = load("res://world/scan.gdshader")
	m.set_shader_parameter("albedo_col", b.albedo_color)
	if b.albedo_texture:
		m.set_shader_parameter("albedo_tex", b.albedo_texture)
		m.set_shader_parameter("has_albedo", true)
	if b.normal_enabled and b.normal_texture:
		m.set_shader_parameter("normal_tex", b.normal_texture)
		m.set_shader_parameter("has_normal", true)
	if b.roughness_texture:
		m.set_shader_parameter("rough_tex", b.roughness_texture)
		m.set_shader_parameter("has_rough", true)
	m.set_shader_parameter("roughness", b.roughness)
	m.set_shader_parameter("metallic", b.metallic)
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.set_shader_parameter("alpha_cut", maxf(b.alpha_scissor_threshold, 0.4))
	m.set_shader_parameter("snow", snow)
	m.set_shader_parameter("foliage", foliage)
	m.set_shader_parameter("noise_tex", Mats.noise_tex)
	_snowy[key] = m
	return m


static func _collect(n: Node, xf: Transform3D, out: ArrayMesh) -> void:
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(m, si)
			var arr := st.commit_to_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = here * verts[i]
			arr[Mesh.ARRAY_VERTEX] = verts
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in nr.size():
					nr[i] = (here.basis * nr[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = nr
			arr[Mesh.ARRAY_TANGENT] = null
			var st2 := SurfaceTool.new()
			st2.create_from_arrays(arr)
			if arr[Mesh.ARRAY_TEX_UV] != null:
				st2.generate_tangents()
			st2.commit(out)
			var mat: Material = (n as MeshInstance3D).get_active_material(si)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	for c in n.get_children():
		_collect(c, here, out)


## Size of a model's bounding box (for fitting it to the space the code shape used).
static func aabb(id: String) -> AABB:
	var m := mesh(id)
	return m.get_aabb() if m else AABB()


static func tex(id: String, map: String) -> Texture2D:
	var key := id + "/" + map
	if _tex.has(key):
		return _tex[key]
	var path := TEX + key + ".jpg"
	var t: Texture2D = load(path) if enabled and ResourceLoader.exists(path) else null
	_tex[key] = t
	return t


static func terrain_textures(m: ShaderMaterial) -> void:
	if skip.has("terrain"):
		return
	if tex("snow_02", "diff") == null:
		return
	m.set_shader_parameter("snow_alb", tex("snow_02", "diff"))
	m.set_shader_parameter("snow_nrm", tex("snow_02", "nor"))
	m.set_shader_parameter("rock_alb", tex("rock_face_03", "diff"))
	m.set_shader_parameter("rock_nrm", tex("rock_face_03", "nor"))
	m.set_shader_parameter("rock_rgh", tex("rock_face_03", "rough"))
	m.set_shader_parameter("road_alb", tex("asphalt_snow", "diff"))
	m.set_shader_parameter("road_nrm", tex("asphalt_snow", "nor"))
	m.set_shader_parameter("pbr", true)
	if GameMode.summer() and tex("grass_leafy", "diff") != null:
		m.set_shader_parameter("summer", true)
		m.set_shader_parameter("grass_alb", tex("grass_leafy", "diff"))
		m.set_shader_parameter("grass_nrm", tex("grass_leafy", "nor"))
		m.set_shader_parameter("ground_alb", tex("forrest_ground_01", "diff"))
		m.set_shader_parameter("alpine_alb", tex("aerial_grass_rock", "diff"))
		m.set_shader_parameter("asphalt_alb", tex("asphalt_02", "diff"))
		m.set_shader_parameter("asphalt_nrm", tex("asphalt_02", "nor"))
