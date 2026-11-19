class_name Fx
## Short-lived effects that make hits readable: blood, sparks, stains in the snow,
## and a split-second freeze on a heavy blow.

static var _blood_mesh: SphereMesh
static var _spark_mesh: BoxMesh
static var _stain_mesh: PlaneMesh
static var _stopping := false


static func _setup() -> void:
	if _blood_mesh:
		return
	_blood_mesh = SphereMesh.new()
	_blood_mesh.radius = 0.022
	_blood_mesh.height = 0.044
	_blood_mesh.radial_segments = 5
	_blood_mesh.rings = 3
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.42, 0.02, 0.02)
	bm.roughness = 0.3
	_blood_mesh.material = bm
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.012, 0.012, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.8, 0.4)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.7, 0.3)
	sm.emission_energy_multiplier = 4.0
	_spark_mesh.material = sm
	_stain_mesh = PlaneMesh.new()
	_stain_mesh.size = Vector2(1, 1)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var ang := atan2(y - 15.5, x - 15.5)
			var edge := 0.62 + 0.2 * sin(ang * 5.0) + 0.12 * sin(ang * 11.0 + 1.0)
			img.set_pixel(x, y, Color(0.3, 0.01, 0.01, clampf((edge - d) * 6.0, 0.0, 0.85)))
	var st := StandardMaterial3D.new()
	st.albedo_texture = ImageTexture.create_from_image(img)
	st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.roughness = 0.35
	_stain_mesh.material = st


static func _burst(parent: Node, pos: Vector3, dir: Vector3, mesh: Mesh, amount: int, speed: float, life: float, gravity: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = 38.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


## Blood: a fine mist and heavy drops out of the far side of the hit (stretched as they fly),
## a few out of the entry, a splatter thrown onto the wall behind and onto the ground below.
## The splats are projected decals, so they follow steps, walls and furniture; they dry and
## darken over a couple of minutes.
static var _mist_mesh: QuadMesh
static var _streak_mesh: BoxMesh
static var _splats: Array[Texture2D] = []
static var _orm: Texture2D
static var _decals: Array = []
const MAX_DECALS := 140

static func _setup_blood() -> void:
	if not _splats.is_empty():
		return
	_setup()
	var bm := _blood_mesh.material as StandardMaterial3D
	bm.albedo_color = Color(0.30, 0.012, 0.01)
	bm.roughness = 0.12
	bm.metallic_specular = 0.7
	_mist_mesh = QuadMesh.new()
	_mist_mesh.size = Vector2(0.09, 0.09)
	var mm := StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.vertex_color_use_as_albedo = true
	mm.albedo_texture = _soft_dot()
	_mist_mesh.material = mm
	_streak_mesh = BoxMesh.new()
	_streak_mesh.size = Vector3(0.012, 0.012, 0.11)
	_streak_mesh.material = bm
	for v in 4:
		_splats.append(_make_splat(v))
	var orm := Image.create(4, 4, false, Image.FORMAT_RGB8)
	orm.fill(Color(1.0, 0.18, 0.0))       # occlusion 1, wet and glossy, not metal
	_orm = ImageTexture.create_from_image(orm)


static func _soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


## A splatter: a ragged pool, satellite drops, and streaks thrown along +x (the hit direction).
static func _make_splat(variant: int) -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant * 37
	var noise := FastNoiseLite.new()
	noise.seed = variant * 13 + 5
	noise.frequency = 0.09
	var drops: Array = []
	for i in 26 + variant * 6:
		var a := rng.randf_range(-0.7, 0.7) if rng.randf() < 0.7 else rng.randf() * TAU
		var r := rng.randf_range(0.25, 0.95)
		drops.append([Vector2(cos(a), sin(a)) * r, rng.randf_range(0.012, 0.05) * (1.0 - r * 0.5)])
	var streaks: Array = []
	for i in 7:
		var a := rng.randf_range(-0.45, 0.45)
		streaks.append([a, rng.randf_range(0.5, 0.95), rng.randf_range(0.015, 0.03)])
	for y in n:
		for x in n:
			var p := Vector2(x, y) / n * 2.0 - Vector2.ONE
			var d := p.length()
			var ang := atan2(p.y, p.x)
			# the main pool: ragged edge, pushed a little toward +x
			var edge := 0.34 + 0.12 * noise.get_noise_2d(cos(ang) * 30.0, sin(ang) * 30.0) + 0.08 * cos(ang)
			var a := smoothstep(edge + 0.03, edge - 0.03, (p - Vector2(0.06, 0)).length())
			for dr in drops:
				var c: Vector2 = dr[0]
				var r: float = dr[1]
				a = maxf(a, smoothstep(r + 0.008, r - 0.008, p.distance_to(c)))
			for sk in streaks:
				var sa: float = sk[0]
				var dirv := Vector2(cos(sa), sin(sa))
				var along := p.dot(dirv)
				var off := absf(p.dot(Vector2(-dirv.y, dirv.x)))
				var w: float = float(sk[2]) * (1.0 - clampf(along / float(sk[1]), 0.0, 1.0))
				if along > 0.2 and along < float(sk[1]):
					a = maxf(a, smoothstep(w + 0.006, w - 0.006, off))
			# thick in the middle (darker), thin at the rim (redder)
			var depth := clampf(1.0 - d / maxf(edge, 0.01), 0.0, 1.0)
			var col := Color(0.36, 0.015, 0.012).lerp(Color(0.12, 0.004, 0.004), depth * 0.8)
			col.a = a * 0.95
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _decal(parent: Node, at: Vector3, normal: Vector3, along: Vector3, size: float, big := false) -> Decal:
	var d := Decal.new()
	d.texture_albedo = _splats[randi() % _splats.size()]
	d.texture_orm = _orm
	d.size = Vector3(size, 0.6, size * randf_range(0.8, 1.0))
	d.upper_fade = 0.15
	d.lower_fade = 0.3
	d.normal_fade = 0.35
	d.cull_mask = 1
	parent.add_child(d)
	d.global_position = at + normal * 0.1
	var up := normal.normalized()
	var x := (along - up * along.dot(up))
	if x.length() < 0.01:
		x = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	d.global_basis = Basis(x, up, x.cross(up)).orthonormalized()
	# fresh blood is bright and wet; it dries dark over two minutes, then fades
	d.modulate = Color(1.15, 1.0, 1.0)
	var tw := d.create_tween()
	tw.tween_property(d, "modulate", Color(0.55, 0.42, 0.42), 120.0)
	tw.tween_interval(120.0 if not big else 300.0)
	tw.tween_property(d, "albedo_mix", 0.0, 8.0)
	tw.tween_callback(d.queue_free)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	return d


static func blood(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_setup_blood()
	var out := (dir + Vector3(0, 0.15, 0)).normalized()
	# mist
	var m := CPUParticles3D.new()
	m.mesh = _mist_mesh
	m.amount = 22 if big else 12
	m.lifetime = 0.55
	m.one_shot = true
	m.explosiveness = 1.0
	m.direction = out
	m.spread = 28.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 4.5 if big else 3.0
	m.damping_min = 6.0
	m.damping_max = 9.0
	m.gravity = Vector3(0, -2.0, 0)
	m.scale_amount_min = 1.2
	m.scale_amount_max = 3.5 if big else 2.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.02, 0.02, 0.75))
	ramp.set_color(1, Color(0.25, 0.01, 0.01, 0.0))
	m.color_ramp = ramp
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos
	m.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(m.queue_free)
	# heavy drops and stretched streaks out of the exit, a few out of the entry
	_burst(parent, pos, out, _blood_mesh, 30 if big else 16, 6.0 if big else 4.2, 0.8, 9.8)
	var st := CPUParticles3D.new()
	st.mesh = _streak_mesh
	st.amount = 14 if big else 8
	st.lifetime = 0.5
	st.one_shot = true
	st.explosiveness = 1.0
	st.direction = out
	st.spread = 18.0
	st.initial_velocity_min = 4.0
	st.initial_velocity_max = 8.0
	st.gravity = Vector3(0, -9.8, 0)
	st.particle_flag_align_y = true
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(st)
	st.global_position = pos
	st.emitting = true
	parent.get_tree().create_timer(0.9).timeout.connect(st.queue_free)
	_burst(parent, pos, -dir, _blood_mesh, 6, 1.6, 0.4, 9.8)
	var world := (parent as Node3D).get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	# thrown onto whatever is behind (a wall, a door, a car) within a couple of metres
	var q := PhysicsRayQueryParameters3D.create(pos, pos + out * (3.2 if big else 2.2))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and not (hit["collider"] as Object).has_method("hit"):
		var dist := pos.distance_to(hit["position"])
		_decal(parent, hit["position"], hit["normal"], Vector3.DOWN, lerpf(0.5, 1.3, clampf(dist / 2.5, 0.0, 1.0)) * (1.3 if big else 1.0))
	# and onto the ground below, stretched the way it flew
	q = PhysicsRayQueryParameters3D.create(pos, pos + Vector3(dir.x * 1.2, -3.0, dir.z * 1.2))
	q.collision_mask = 3
	hit = space.intersect_ray(q)
	if hit.is_empty() or (hit["collider"] as Object).has_method("hit"):
		return
	_decal(parent, hit["position"], hit["normal"], Vector3(dir.x, 0, dir.z), randf_range(0.5, 0.95) * (1.5 if big else 1.0), big)


## The pool that spreads under a body over a few seconds.
static func pool(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_setup_blood()
	var world := (parent as Node3D).get_world_3d()
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos + Vector3(0, -2.0, 0))
	q.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var d := _decal(parent, hit["position"], hit["normal"], Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU), 0.3, true)
	var full := randf_range(1.6, 2.3)
	var tw := d.create_tween()
	tw.tween_property(d, "size", Vector3(full, 0.6, full * 0.85), 7.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## A wound that keeps dripping: drops fall from `node` every so often for `secs` seconds.
static func bleed(node: Node3D, secs: float, height := 1.1) -> void:
	if node == null or not node.is_inside_tree():
		return
	_setup_blood()
	var t := node.get_tree()
	var n := int(secs / 0.45)
	for i in n:
		t.create_timer(0.3 + i * 0.45 + randf() * 0.2).timeout.connect(func() -> void:
			if not is_instance_valid(node) or not node.is_inside_tree():
				return
			var p := node.global_position + Vector3(randf_range(-0.12, 0.12), height + randf_range(-0.2, 0.2), randf_range(-0.12, 0.12))
			_burst(node.get_parent(), p, Vector3.DOWN, _blood_mesh, 2, 0.4, 0.6, 9.8)
			if i % 3 == 0:
				var q := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -3, 0))
				q.collision_mask = 1
				var hit := node.get_world_3d().direct_space_state.intersect_ray(q)
				if not hit.is_empty():
					_decal(node.get_parent(), hit["position"], hit["normal"], Vector3.RIGHT, randf_range(0.12, 0.22)))


## Sparks off metal, stone and wood.
static func sparks(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_setup()
	_burst(parent, pos, normal, _spark_mesh, 9, 4.5, 0.3, 6.0)


## A breath of slow motion (a clean headshot kill, a boss changing gear).
static func slowmo(tree: SceneTree, scale: float, seconds: float) -> void:
	if _stopping or tree == null:
		return
	_stopping = true
	Engine.time_scale = scale
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_stopping = false)


## Freeze the game for a moment so a heavy blow has weight.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if _stopping or tree == null:
		return
	_stopping = true
	Engine.time_scale = 0.06
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_stopping = false)
