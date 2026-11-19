class_name IceSpike
extends Node3D
## A spear of ice that bursts out of the ground. First the ice glows blue where it will come
## up (that is your warning), then the spike shoots up, then it slowly sinks away.

var player: Player
var _t := 0.0
var _delay := 0.5
var _warn: MeshInstance3D
var _wmat: StandardMaterial3D
var _spike: Node3D
var _up := false


static func spawn(parent: Node, pos: Vector3, delay: float, p: Player) -> IceSpike:
	var s := IceSpike.new()
	s.player = p
	s._delay = delay
	parent.add_child(s)
	s.global_position = pos
	return s


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.03
	disc.radial_segments = 16
	_wmat = StandardMaterial3D.new()
	_wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wmat.albedo_color = Color(0.45, 0.85, 1.0, 0.0)
	disc.material = _wmat
	_warn = MeshInstance3D.new()
	_warn.mesh = disc
	_warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warn.position.y = 0.05
	add_child(_warn)
	var k := MeshKit.new()
	var r := RandomNumberGenerator.new()
	r.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
	k.tube(Vector3(0, -0.2, 0), Vector3(r.randf_range(-0.2, 0.2), 2.6, r.randf_range(-0.2, 0.2)), 0.36, "ice", 7, 0.0)
	for i in 4:
		var a := i * TAU / 4.0 + r.randf() * 0.8
		var base := Vector3(cos(a) * 0.4, -0.2, sin(a) * 0.4)
		k.tube(base, base + Vector3(cos(a) * 0.6, r.randf_range(0.9, 1.6), sin(a) * 0.6), 0.2, "ice", 6, 0.0)
	_spike = k.node(false)
	_spike.scale = Vector3(1, 0.02, 1)
	_spike.visible = false
	add_child(_spike)


func _process(delta: float) -> void:
	_t += delta
	if _t < _delay:
		_wmat.albedo_color.a = 0.15 + 0.45 * (0.5 + 0.5 * sin(_t * 30.0)) * (_t / _delay)
		return
	if not _up:
		_up = true
		_spike.visible = true
		_warn.visible = false
		var tw := create_tween()
		tw.tween_property(_spike, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play(get_parent(), "clank", global_position, -2.0, 0.5)
		if player:
			var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
			if d < 1.4 and absf(player.global_position.y - global_position.y) < 2.5:
				player.stats.hurt(20.0, 0.4, "ice spikes", 10.0)
				player.velocity += Vector3(0, 7.5, 0)
				player.shake(1.3)
				player.rumble(0.8, 1.0, 0.35)
	if _t > _delay + 3.5:
		_spike.scale.y = maxf(_spike.scale.y - delta * 0.8, 0.0)
		_spike.position.y -= delta * 0.6
		if _spike.scale.y <= 0.0:
			queue_free()
