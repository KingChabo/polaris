class_name Wolf
extends Enemy
## Wolves hunt in a pack: they circle you, then one after the other lunges in
## to bite. They run when badly hurt or when a flare burns near them.

var _legs: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _lunge := false
var _lunge_t := 0.0
var _circle_t := 2.0
var _angle := 0.0
var _turn := 1.0
var _flee_t := 0.0
var _fear := Vector3.ZERO
var _growl_t := 0.0
var bite := 13.0
var bite_reach := 1.7
var furs := ["fur", "fur", "fur_dark", "camo"]
var size_min := 0.95
var size_max := 1.15


func setup(rng: RandomNumberGenerator) -> void:
	make_body(0.36, 0.95)
	model = Humanoid.wolf(furs[rng.randi() % furs.size()])
	var s := rng.randf_range(size_min, size_max)
	model.scale = Vector3.ONE * s
	add_child(model)
	_legs = model.get_meta("legs")
	_head = model.get_meta("head")
	_tail = model.get_meta("tail")
	max_health = 45.0
	health = max_health
	speed = 5.2
	head_y = 99.0
	eye_y = 0.8
	view_dist = 32.0
	body_title = "Dead wolf"
	display_name = "Wolf"
	loot = {"wolf_pelt": 1}
	_angle = rng.randf() * TAU
	_turn = 1.0 if rng.randf() < 0.5 else -1.0
	_circle_t = rng.randf_range(1.0, 4.0)


func _on_hurt() -> void:
	if health < max_health * 0.35:
		scare(player.global_position, 999.0)
	elif state != "fight":
		_attack()


func _attack() -> void:
	state = "fight"
	Sfx.play(get_parent(), "growl", global_position, 2.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Wolf and e != self and (e as Wolf).state == "idle" and (e as Wolf).global_position.distance_to(global_position) < 45.0:
			(e as Wolf).state = "fight"


func scare(pos: Vector3, reach: float) -> void:
	if state != "dead" and global_position.distance_to(pos) < reach:
		state = "flee"
		_fear = pos
		_flee_t = 12.0
		_lunge = false


func hear(_pos: Vector3, _reach: float) -> void:
	pass   # gunshots do not bring wolves


func _think(delta: float, dist: float) -> Vector3:
	match state:
		"idle":
			var smell := 10.0 if not player.crouching else 5.0
			if (_sees and dist < view_dist) or dist < smell:
				_attack()
			return _roam(delta, 18.0, 1.6)
		"flee":
			_flee_t -= delta
			if _flee_t <= 0.0:
				state = "idle"
				_wander = home
				_wander_t = 20.0
				return Vector3.ZERO
			var away := -_flat_to(_fear).normalized()
			_face(away, delta)
			return away * 8.5
		"alert":
			state = "idle"
			return Vector3.ZERO
	# fight
	if dist > 75.0:
		state = "idle"
		return Vector3.ZERO
	_growl_t -= delta
	if _growl_t <= 0.0:
		_growl_t = randf_range(4.0, 9.0)
		Sfx.play(get_parent(), "growl", global_position, 0.0, randf_range(0.85, 1.2))
	var to := _flat_to(player.global_position)
	var d := to.length()
	var dir := to.normalized()
	if _lunge:
		_lunge_t -= delta
		_face(dir, delta)
		if d < bite_reach:
			var res := player.melee_hit(bite, 0.35, self)
			if res == "parried":
				stagger(1.5)
			_lunge = false
			_circle_t = randf_range(2.0, 4.5)
			velocity -= dir * 5.0
		elif _lunge_t <= 0.0:
			_lunge = false
			_circle_t = randf_range(1.5, 3.0)
		return dir * 8.8
	_circle_t -= delta
	if _circle_t <= 0.0:
		_lunge = true
		_lunge_t = 2.6
	_angle += _turn * delta * 0.55
	var spot := player.global_position + Vector3(cos(_angle), 0, sin(_angle)) * 7.5
	var go := _flat_to(spot)
	if go.length() < 1.0:
		_face(dir, delta)
		return Vector3.ZERO
	_face(go, delta)
	return go.normalized() * speed


func _animate(_delta: float, moved: float) -> void:
	var amp := clampf(moved / 4.0, 0.0, 1.0) * 0.75
	for i in 4:
		_legs[i].rotation.x = sin(_phase * 1.6 + (0.0 if i == 0 or i == 3 else PI)) * amp
	_head.rotation.x = lerpf(_head.rotation.x, 0.35 if (_lunge or state == "idle") else 0.0, 0.2) if state != "idle" else sin(_phase * 0.3) * 0.1 - 0.2
	_tail.rotation.x = -0.6 + (0.5 if state == "flee" else 0.0)
	_tail.rotation.y = sin(_phase * 0.8) * 0.3
	model.rotation.x = lerpf(model.rotation.x, 0.25 if _stagger > 0.25 else 0.0, 0.2)
