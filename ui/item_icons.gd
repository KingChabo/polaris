class_name ItemIcons
extends Node
## Photographs every item once: its 3D model (ItemMesh) under studio light, on a clear
## background. The backpack, the trader and the HUD draw these pictures.
## Pictures are made one per frame after start; until one is ready, `tex` has no entry for it.

const SIZE := 224

static var tex := {}          # item id -> ImageTexture
static var figure_tex: ImageTexture      # the player as dressed right now
static var figure_key := ""
const FIG := Vector2i(300, 580)

var done := false
var _busy := false
var _want := ""
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	# a plain bright "studio" sky, only so that metal has something to mirror
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.95, 0.97, 1.0)
	sm.sky_horizon_color = Color(0.55, 0.6, 0.68)
	sm.ground_horizon_color = Color(0.3, 0.32, 0.36)
	sm.ground_bottom_color = Color(0.1, 0.11, 0.13)
	sm.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.environment = env
	_cam.near = 0.05
	_cam.far = 30.0
	_vp.add_child(_cam)
	# key from the upper left, a cool fill from the right, a rim from behind
	for l: Array in [[Vector3(-0.9, 0.9, 0.3), Color(1.0, 0.93, 0.82), 2.6], [Vector3(0.6, 0.15, -0.5), Color(0.6, 0.75, 1.0), 0.7], [Vector3(0.9, 1.0, -2.6), Color(0.8, 0.9, 1.0), 1.6]]:
		var d := DirectionalLight3D.new()
		d.light_color = l[1]
		d.light_energy = l[2]
		d.shadow_enabled = false
		_vp.add_child(d)
		d.look_at_from_position(Vector3.ZERO, -(l[0] as Vector3), Vector3.UP)
		d.rotate_y(0.0)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_shoot_all.call_deferred()


func _shoot_all() -> void:
	_busy = true
	for id: String in Items.DB:
		if tex.has(id) or not (Items.DB[id] as Dictionary).has("name"):
			continue
		var m := ItemMesh.build(id)
		_stage.add_child(m)
		_frame(m)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.generate_mipmaps()
		tex[id] = ImageTexture.create_from_image(img)
		_stage.remove_child(m)
		m.free()
	done = true
	_busy = false


## Photographs the player's figure in the clothes of `look` (a Humanoid look); `key` names the outfit.
func shoot_figure(look: Dictionary, key: String) -> void:
	if key == figure_key or key == _want:
		return
	_want = key
	while _busy:
		await get_tree().process_frame
	if _want != key:
		return
	_busy = true
	var m := Humanoid.build(look)
	m.rotation.y = PI - 0.35
	_stage.add_child(m)
	(m.get_meta("arm_l") as Node3D).rotation.z = -0.1
	(m.get_meta("arm_r") as Node3D).rotation.z = 0.1
	_vp.size = FIG
	_frame(m, float(FIG.x) / FIG.y, 1.04)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.generate_mipmaps()
	figure_tex = ImageTexture.create_from_image(img)
	figure_key = key
	_stage.remove_child(m)
	m.free()
	_vp.size = Vector2i(SIZE, SIZE)
	_busy = false


func _boxes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var bb := mi.mesh.get_aabb()
		for i in 8:
			out.append(mi.global_transform * bb.get_endpoint(i))
	for c in n.get_children():
		_boxes(c, out)


## Points the camera at the model from the front, a little above and to the right, and
## zooms so that the whole model fills the picture.
func _frame(m: Node3D, aspect := 1.0, margin := 1.1) -> void:
	var pts: Array = []
	_boxes(m, pts)
	if pts.is_empty():
		return
	var dir := Vector3(0.32, 0.42, 1.0).normalized()
	var b := Basis.looking_at(-dir, Vector3.UP)
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for p: Vector3 in pts:
		var q := b.inverse() * p
		lo = lo.min(q)
		hi = hi.max(q)
	var c := b * ((lo + hi) * 0.5)
	_cam.global_transform = Transform3D(b, c + dir * 8.0)
	_cam.size = maxf((hi.x - lo.x) / aspect, hi.y - lo.y) * margin + 0.01


## All pictures on one sheet, for checking them (tools: `-- --iconsheet`).
static func sheet(path: String) -> void:
	var ids: Array = tex.keys()
	var cols := 10
	var rows := int(ceil(ids.size() / float(cols)))
	var img := Image.create(cols * SIZE, rows * SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.09, 0.13))
	for i in ids.size():
		var t: ImageTexture = tex[ids[i]]
		var im := t.get_image()
		im.clear_mipmaps()
		im.convert(Image.FORMAT_RGBA8)
		img.blend_rect(im, Rect2i(0, 0, SIZE, SIZE), Vector2i((i % cols) * SIZE, (i / cols) * SIZE))
	img.save_png(path)
