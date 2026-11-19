class_name MineDrone
extends StaticBody3D
## K-9's little helpers: a steel ball on a tread that rolls after you, beeping faster the
## closer it gets, and goes off when it reaches you. Shoot it first — one good hit does it.

var player: Player
var floor_y := 0.0
var speed := 4.6
var _t := 0.0
var _beep := 0.0
var _ball: Node3D
var _led: MeshInstance3D
var _gone := false


static func launch(parent: Node, from: Vector3, p: Player, fy: float) -> MineDrone:
	var m := MineDrone.new()
	m.player = p
	m.floor_y = fy
	parent.add_child(m)
	m.global_position = Vector3(from.x, fy, from.z)
	return m


func _ready() -> void:
	add_to_group("drone")
	var k := MeshKit.new()
	k.ball(Vector3(0, 0.32, 0), Vector3(0.3, 0.28, 0.3), "steel_in", 12, 8)
	k.tube(Vector3(-0.3, 0.32, 0), Vector3(0.3, 0.32, 0), 0.22, "hazard_in", 12, 0.22, false)
	for i in 6:
		var a := i * TAU / 6.0
		k.box(Vector3(cos(a) * 0.29, 0.32 + sin(a) * 0.29, 0), Vector3(0.06, 0.04, 0.12), "black_in", Basis(Vector3.FORWARD, a))
	_ball = k.node(false)
	add_child(_ball)
	var lm := SphereMesh.new()
	lm.radius = 0.045
	lm.height = 0.09
	_led = MeshInstance3D.new()
	_led.mesh = lm
	_led.material_override = Mats.get_mat("led_red")
	_led.position = Vector3(0, 0.62, 0)
	add_child(_led)
	var shape := SphereShape3D.new()
	shape.radius = 0.36
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.32
	add_child(cs)
	collision_layer = 4
	collision_mask = 0


func _physics_process(delta: float) -> void:
	if _gone or player == null:
		return
	_t += delta
	var to := Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z)
	var d := to.length()
	if d > 0.1:
		var step := to.normalized() * speed * delta
		global_position += step
		global_position.y = floor_y
		rotation.y = atan2(-to.x, -to.z)
		_ball.rotation.x -= step.length() / 0.3
	_beep -= delta
	if _beep <= 0.0:
		_beep = clampf(d / 14.0, 0.08, 0.6)
		_led.visible = not _led.visible
		if _led.visible:
			Sfx.play(get_parent(), "beep", global_position, -4.0, 1.6)
	if d < 1.5 or _t > 9.0:
		boom()


func boom() -> void:
	if _gone:
		return
	_gone = true
	var pos := global_position + Vector3(0, 0.3, 0)
	Sfx.play(get_parent(), "shot_boom", pos, 8.0, 0.7)
	for i in 4:
		Fx.sparks(get_parent(), pos, Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)).normalized())
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 10.0
	l.omni_range = 10.0
	get_parent().add_child(l)
	l.global_position = pos + Vector3(0, 0.5, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	Blast.hurt_all(get_tree(), pos, 4.2, 26.0, self, "a mine drone")
	queue_free()


func hit(_dmg: float, _pos: Vector3, _dir: Vector3, _pen: float, _shooter: Node) -> void:
	boom()
