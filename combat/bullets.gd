class_name Bullets
extends Node3D
## Every bullet is a real projectile: it has speed, loses some to drag and
## falls with gravity. Each physics step it ray-casts along its path.

const GRAVITY := 9.81

var last_impact := Vector3.ZERO    # for tests
var last_hit: Object = null
var _list: Array[Dictionary] = []
var _tracer: BoxMesh
var _puff: SphereMesh


func _ready() -> void:
	_tracer = BoxMesh.new()
	_tracer.size = Vector3(0.012, 0.012, 1.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.4)
	m.emission_energy_multiplier = 3.0
	_tracer.material = m
	_puff = SphereMesh.new()
	_puff.radius = 0.09
	_puff.height = 0.18
	_puff.radial_segments = 6
	_puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.9, 0.93, 1.0)
	_puff.material = pm


func fire(pos: Vector3, vel: Vector3, dmg: float, pen: float, shooter: Node, flare := false) -> void:
	var t := MeshInstance3D.new()
	t.mesh = _tracer
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.visible = false
	add_child(t)
	var light: OmniLight3D = null
	if flare:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.25, 0.15)
		light.light_energy = 6.0
		light.omni_range = 30.0
		t.add_child(light)
	_list.append({"pos": pos, "vel": vel, "v0": vel.length(), "dmg": dmg, "pen": pen, "shooter": shooter,
		"life": 6.0, "node": t, "flare": flare, "from": pos})


func _physics_process(delta: float) -> void:
	if _list.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var i := _list.size() - 1
	while i >= 0:
		var b := _list[i]
		var vel: Vector3 = b["vel"]
		var pos: Vector3 = b["pos"]
		vel.y -= GRAVITY * delta
		vel *= 1.0 - 0.12 * delta   # air drag
		var to := pos + vel * delta
		var q := PhysicsRayQueryParameters3D.create(pos, to)
		var shooter: Node = b["shooter"]
		if is_instance_valid(shooter) and shooter is CollisionObject3D:
			q.exclude = [(shooter as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		var node: MeshInstance3D = b["node"]
		b["life"] = float(b["life"]) - delta
		if hit:
			_impact(b, hit, vel)
			node.queue_free()
			_list.remove_at(i)
		elif float(b["life"]) <= 0.0:
			node.queue_free()
			_list.remove_at(i)
		else:
			if not b.has("whiz") and _player() and shooter != _player_ref:
				var head := _player_ref.camera.global_position
				var seg := to - pos
				var t := clampf((head - pos).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
				var close := pos + seg * t
				var miss := close.distance_to(head)
				if miss < 2.4 and t > 0.0 and t < 1.0:
					b["whiz"] = true
					_near_miss(close, miss)
			b["pos"] = to
			b["vel"] = vel
			node.visible = to.distance_to(b["from"]) > 3.0 or bool(b["flare"])
			node.look_at_from_position(to, to + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)
		i -= 1


var _player_ref: Player


func _player() -> bool:
	if _player_ref == null:
		_player_ref = get_parent().get("player") as Player
	return _player_ref != null and _player_ref.camera != null


## A round that cracks past your head: you hear it snap by, flinch, and the edges of
## the picture close in for a moment. Being shot at should feel like being shot at.
func _near_miss(at: Vector3, miss: float) -> void:
	var k := 1.0 - miss / 2.4
	Sfx.play(self, "whiz", at, 2.0 + 6.0 * k, randf_range(0.85, 1.2))
	_player_ref.shake(0.2 + 0.55 * k)
	_player_ref.rumble(0.25 * k, 0.1, 0.12)
	var post: Node = get_parent().get("post")
	if post:
		post.suppress = minf(float(post.suppress) + 0.3 + 0.45 * k, 1.0)


func _impact(b: Dictionary, hit: Dictionary, vel: Vector3) -> void:
	var pos: Vector3 = hit["position"]
	var col: Object = hit["collider"]
	last_impact = pos
	last_hit = col
	var shooter: Node = b["shooter"] if is_instance_valid(b["shooter"]) else null
	if col.has_method("hit"):
		var falloff := clampf(vel.length() / float(b["v0"]), 0.4, 1.0)
		col.hit(float(b["dmg"]) * falloff, pos, vel.normalized(), float(b["pen"]), shooter)
		if shooter and shooter.has_method("landed_hit"):
			shooter.landed_hit(col)
	else:
		if not (col is Node and ((col as Node).get_parent() is Terrain or (col as Node).has_meta("surface"))):
			Fx.sparks(self, pos, hit["normal"])
			Sfx.play(self, "clank", pos, -12.0, 1.6)
		var p := MeshInstance3D.new()
		p.mesh = _puff
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		p.global_position = pos
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector3.ONE * 2.6, 0.25)
		tw.parallel().tween_property(p, "position:y", pos.y + 0.3, 0.25)
		tw.tween_property(p, "scale", Vector3.ZERO, 0.2)
		tw.tween_callback(p.queue_free)
	if bool(b["flare"]):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.15)
		l.light_energy = 8.0
		l.omni_range = 38.0
		add_child(l)
		l.global_position = pos + Vector3(0, 0.4, 0)
		var tw2 := l.create_tween()
		tw2.tween_interval(16.0)
		tw2.tween_property(l, "light_energy", 0.0, 4.0)
		tw2.tween_callback(l.queue_free)
		get_tree().call_group("enemy", "scare", pos, 22.0)
		get_tree().call_group("hollow", "scare", pos, 22.0)
