class_name Grenade
extends Node3D
## A thrown grenade: it flies in an arc, bounces, blinks red faster and faster while the fuse
## burns, then goes off. Cover cuts the blast. A smoke grenade pours out a grey wall instead.

const GRAVITY := 9.8
const SMOKE_SHADER := preload("res://combat/smoke.gdshader")

var vel := Vector3.ZERO
var fuse := 2.3
var smoke := false
var thrower: Node
var _t := 0.0
var _rest := false
var _led: MeshInstance3D
var _blink := 0.0
var _spin := Vector3.ZERO


static func throw(parent: Node, from: Vector3, target: Vector3, by: Node, is_smoke := false) -> Grenade:
	var g := Grenade.new()
	g.thrower = by
	g.smoke = is_smoke
	g.fuse = 2.6 if not is_smoke else 1.2
	parent.add_child(g)
	g.global_position = from
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	var t := clampf(flat.length() / 15.0, 0.55, 1.9)
	g.vel = flat / t
	g.vel.y = (target.y - from.y) / t + 0.5 * GRAVITY * t
	g._spin = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	Sfx.play(parent, "swing", from, -2.0, 1.4)
	return g


func _ready() -> void:
	var k := MeshKit.new()
	if smoke:
		k.cyl(Vector3(0, -0.07, 0), 0.04, 0.14, "grey_in", 10)
		k.cyl(Vector3(0, 0.07, 0), 0.025, 0.03, "steel_in", 8)
		k.box(Vector3(0, -0.01, -0.041), Vector3(0.05, 0.05, 0.004), "white_in")
	else:
		k.ball(Vector3.ZERO, Vector3(0.045, 0.055, 0.045), "olive_in", 10, 7)
		k.cyl(Vector3(0, 0.05, 0), 0.018, 0.03, "steel_in", 8)
		k.box(Vector3(0.025, 0.04, 0), Vector3(0.012, 0.06, 0.02), "steel_in", Basis(Vector3.BACK, -0.3))
	add_child(k.node(false))
	var lm := SphereMesh.new()
	lm.radius = 0.012
	lm.height = 0.024
	_led = MeshInstance3D.new()
	_led.mesh = lm
	_led.material_override = Mats.get_mat("led_red")
	_led.position = Vector3(0, 0.075, 0)
	_led.visible = not smoke
	add_child(_led)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _rest:
		vel.y -= GRAVITY * delta
		var next := global_position + vel * delta
		var q := PhysicsRayQueryParameters3D.create(global_position, next + vel.normalized() * 0.06)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			global_position = (hit["position"] as Vector3) + n * 0.06
			vel = vel.bounce(n) * 0.35
			Sfx.play(get_parent(), "click", global_position, -6.0, 0.6)
			if vel.length() < 1.8:
				_rest = true
		else:
			global_position = next
			rotation += _spin * delta
	# the blink speeds up as the fuse burns down
	if not smoke:
		_blink -= delta
		if _blink <= 0.0:
			var left := fuse - _t
			_blink = clampf(left * 0.18, 0.06, 0.35)
			_led.visible = not _led.visible
			if _led.visible:
				Sfx.play(get_parent(), "beep", global_position, -10.0, 1.3)
	if _t >= fuse:
		if smoke:
			_smoke()
		else:
			_explode()


func _explode() -> void:
	var pos := global_position
	var parent := get_parent()
	Sfx.play(parent, "shot_boom", pos, 12.0, 0.55)
	Sfx.play(parent, "crack", pos, 4.0, 1.2)
	for i in 6:
		Fx.sparks(parent, pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)), Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1)).normalized())
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 14.0
	l.omni_range = 16.0
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.65, 0.3, 0.7)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.material = mat
	ball.mesh = sm
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ball)
	ball.global_position = pos + Vector3(0, 0.4, 0)
	ball.scale = Vector3.ONE * 0.3
	var tb := ball.create_tween()
	tb.tween_property(ball, "scale", Vector3.ONE * 3.4, 0.18)
	tb.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tb.tween_callback(ball.queue_free)
	Blast.hurt_all(get_tree(), pos, 7.0, 58.0, thrower, "a grenade")
	queue_free()


func _smoke() -> void:
	var p := CPUParticles3D.new()
	p.amount = 110
	p.set_meta("smoke", true)
	p.lifetime = 9.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0.35, 0.12, 0.18)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.3, 0.9))
	sc.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := ShaderMaterial.new()
	m.shader = SMOKE_SHADER
	m.set_shader_parameter("tint", Color(0.38, 0.4, 0.44, 0.6))     # night smoke: grey, not glowing white
	q.material = m
	p.mesh = q
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.5, 0)
	Sfx.play(get_parent(), "steam", global_position, 4.0, 0.8)
	var tw := p.create_tween()
	tw.tween_interval(9.0)
	tw.tween_callback(func() -> void: p.emitting = false)
	tw.tween_interval(9.5)
	tw.tween_callback(p.queue_free)
	queue_free()
