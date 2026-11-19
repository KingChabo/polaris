class_name Hollow
extends StaticBody3D
## Horror mode's stalker: a tall, faceless thing that only moves while you are not looking at it.
## Light drives it off: hold the flashlight on it, fire a flare near it, or stand by a lit fire.
## Bullets and blades can put it down too, but it takes a lot of them; what is left is cold ash.
## If it reaches you it screams in your face, strikes, and is gone — for now.

signal gone(how: String)

const SKIN := "hollow_skin"
const FACE := "hollow_face"
const RAG := "hollow_rag"

var main: Node
var player: Player
var state := "stalk"          # stalk / attack / banish
var seen := false
var burn := 0.0               # seconds the flashlight has been on it
var hp := 260.0
var haste := 1.0            # later chapters: it is faster
var dist := 99.0
var _t := 0.0
var _state_t := 0.0
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _model: Node3D
var _twitch := 0.0
var _seen_t := 0.0
var _seed := 0.0
var _hiss: AudioStreamPlayer3D


func setup(m: Node) -> void:
	main = m
	player = m.player
	add_to_group("hollow")
	_seed = randf() * 10.0
	_model = Node3D.new()
	add_child(_model)
	var k := MeshKit.new()
	k.winter = true  # creatures keep their ice and frost in summer
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# long thin legs, knees bent forward as if it were about to fold up
	for sx in [-1.0, 1.0]:
		var x: float = sx
		var knee := Vector3(x * 0.14, 0.72, -0.16)
		k.tube(Vector3(x * 0.1, 1.3, 0.02), knee, 0.06, SKIN, 8, 0.042)
		k.ball(knee, Vector3(0.05, 0.06, 0.055), SKIN, 8, 5)
		k.tube(knee, Vector3(x * 0.13, 0.08, 0.06), 0.042, SKIN, 8, 0.026)
		k.ball(Vector3(x * 0.13, 0.035, -0.06), Vector3(0.04, 0.028, 0.16), SKIN, 8, 4)
		for t in 3:
			k.tube(Vector3(x * 0.13 + (t - 1) * 0.025, 0.03, -0.18), Vector3(x * 0.13 + (t - 1) * 0.04, 0.012, -0.27), 0.009, SKIN, 4, 0.003)
	k.ball(Vector3(0, 1.34, 0.02), Vector3(0.15, 0.1, 0.1), SKIN, 10, 6)
	# a long, hunched body: the spine bends forward and the head hangs low in front of it
	k.tube(Vector3(0, 1.34, 0.02), Vector3(0, 1.72, -0.06), 0.085, SKIN, 10, 0.13)
	k.tube(Vector3(0, 1.72, -0.06), Vector3(0, 2.02, -0.24), 0.135, SKIN, 10, 0.1)
	for i in 6:
		var y := 1.56 + i * 0.07
		var z := 0.05 - i * 0.045
		for sx in [-1.0, 1.0]:
			var x: float = sx
			k.tube(Vector3(x * 0.02, y, z + 0.06), Vector3(x * 0.13, y - 0.05, z - 0.07), 0.012, SKIN, 5)
	# the spine shows through the back
	for i in 7:
		var t := i / 6.0
		k.ball(Vector3(0, 1.4 + t * 0.6, 0.1 - t * t * 0.28), Vector3(0.022, 0.026, 0.03), SKIN, 6, 4)
	k.ball(Vector3(0, 2.0, -0.24), Vector3(0.27, 0.07, 0.11), SKIN, 10, 5)
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.ball(Vector3(x * 0.25, 2.03, -0.24), Vector3(0.06, 0.065, 0.06), SKIN, 8, 5)     # bony shoulders
	k.tube(Vector3(0, 2.02, -0.26), Vector3(0, 2.12, -0.42), 0.036, SKIN, 8, 0.03)
	# what was a long coat once: it hangs off the shoulders and ends in torn strips
	k.tube(Vector3(0, 2.0, -0.22), Vector3(0, 1.3, -0.04), 0.24, RAG, 12, 0.3, false)
	k.tube(Vector3(0, 1.3, -0.04), Vector3(0, 1.08, 0.0), 0.3, RAG, 12, 0.33, false)
	for i in 14:
		var a := i * TAU / 14.0 + rng.randf_range(-0.12, 0.12)
		var top := Vector3(sin(a) * 0.31, 1.12, cos(a) * 0.3)
		var bot := Vector3(sin(a) * rng.randf_range(0.33, 0.4), 1.12 - rng.randf_range(0.2, 0.6), cos(a) * rng.randf_range(0.31, 0.38))
		k.tube(top, bot, 0.075, RAG, 3, 0.01)
	_model.add_child(k.node(false))
	# the head hangs forward: long, grey, no eyes at all, and a mouth that goes too far round
	var h := MeshKit.new()
	h.winter = true  # creatures keep their ice and frost in summer
	h.ball(Vector3(0, 0.0, -0.06), Vector3(0.092, 0.17, 0.11), FACE, 14, 10)
	h.ball(Vector3(0, -0.12, -0.075), Vector3(0.072, 0.085, 0.085), FACE, 12, 8)
	h.ball(Vector3(0, 0.07, 0.01), Vector3(0.088, 0.12, 0.1), SKIN, 10, 6)            # dark scalp at the back
	for sx in [-1.0, 1.0]:
		var x: float = sx
		h.ball(Vector3(x * 0.04, 0.04, -0.16), Vector3(0.028, 0.012, 0.008), "hollow_skin", 8, 4)   # faint dents where eyes would be
		h.tube(Vector3(x * 0.012, -0.02, -0.17), Vector3(x * 0.012, -0.045, -0.172), 0.004, "black_in", 4)   # nostril slits
	# the mouth: a wide dark gash from cheek to cheek, lined with thin teeth
	for i in 9:
		var f := (i - 4) / 4.0
		var a := f * 1.15
		var c := Vector3(sin(a) * 0.075, -0.115 - f * f * 0.025, -0.075 - cos(a) * 0.085)
		h.ball(c, Vector3(0.016, 0.017, 0.012), "black_in", 6, 4)
		h.tube(c + Vector3(0, 0.014, -0.006), c + Vector3(0, -0.004, -0.008), 0.0035, "hollow_teeth", 4, 0.0)
		h.tube(c + Vector3(0.006, -0.014, -0.006), c + Vector3(0.006, 0.003, -0.008), 0.003, "hollow_teeth", 4, 0.0)
	_head = h.node(false)
	_head.position = Vector3(0, 2.13, -0.47)
	_head.rotation.x = 0.35
	_model.add_child(_head)
	# arms that hang to its knees, with long fingers
	_arm_l = _arm(-1.0)
	_arm_r = _arm(1.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 2.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.25
	add_child(cs)
	collision_layer = 4        # bullets and rays find it, people walk through it
	collision_mask = 0
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = Sfx.stream("whisper").duplicate()
	(_hiss.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(_hiss.stream as AudioStreamWAV).loop_end = (_hiss.stream as AudioStreamWAV).data.size() / 2
	_hiss.volume_db = -6.0
	_hiss.unit_size = 4.0
	_hiss.max_distance = 26.0
	_hiss.pitch_scale = 0.7
	_hiss.position = Vector3(0, 2.2, 0)
	_hiss.autoplay = true
	add_child(_hiss)


func _arm(sx: float) -> Node3D:
	var a := MeshKit.new()
	a.winter = true  # creatures keep their ice and frost in summer
	# long arms that hang past the knees, elbows turned out, fingers like twigs
	var el := Vector3(sx * 0.1, -0.66, 0.06)
	var wr := Vector3(sx * 0.04, -1.3, -0.12)
	a.tube(Vector3.ZERO, el, 0.042, SKIN, 8, 0.03)
	a.ball(el, Vector3(0.036, 0.042, 0.036), SKIN, 6, 4)
	a.tube(el, wr, 0.03, SKIN, 8, 0.02)
	a.ball(wr + Vector3(0, -0.05, 0), Vector3(0.032, 0.065, 0.045), SKIN, 6, 4)
	for f in 4:
		var spread := (f - 1.5) * 0.024
		var knuckle := wr + Vector3(spread, -0.11, -0.01)
		var tip := wr + Vector3(spread * 2.4, -0.42 + absf(f - 1.5) * 0.04, -0.09 - f * 0.012)
		a.tube(knuckle, knuckle.lerp(tip, 0.5) + Vector3(0, 0, -0.03), 0.008, SKIN, 5, 0.006)
		a.tube(knuckle.lerp(tip, 0.5) + Vector3(0, 0, -0.03), tip, 0.006, SKIN, 5, 0.002)
	a.tube(wr + Vector3(-sx * 0.03, -0.08, -0.02), wr + Vector3(-sx * 0.09, -0.26, -0.1), 0.008, SKIN, 5, 0.003)   # thumb
	var n := a.node(false)
	n.position = Vector3(sx * 0.27, 2.0, -0.24)
	_model.add_child(n)
	return n


## Puts it on the ground at `pos`, turned towards the player.
func place(pos: Vector3) -> void:
	global_position = Vector3(pos.x, main.terrain.height_at(pos.x, pos.z), pos.z)
	_face(1.0)


func _face(k: float) -> void:
	var d := player.global_position - global_position
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, k)


## True when the player could see it now: in the picture and nothing in between.
func _visible() -> bool:
	var cam := player.camera
	var head_pos := global_position + Vector3(0, 2.1, 0)
	if not cam.is_position_in_frustum(head_pos) and not cam.is_position_in_frustum(global_position + Vector3(0, 1.0, 0)):
		return false
	if head_pos.distance_to(cam.global_position) > 75.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, head_pos)
	q.exclude = [get_rid(), player.get_rid()]
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	_state_t += delta
	var flat := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z)
	dist = flat.length()
	match state:
		"stalk":
			_stalk(delta)
		"attack":
			# its face, right in front of yours
			var cam := player.camera
			var fwd := -cam.global_basis.z
			fwd.y = 0.0
			global_position = cam.global_position + fwd.normalized() * 1.25 - Vector3(0, 2.12, 0)
			_face(1.0)
			_head.rotation = Vector3(0.25, 0, sin(_t * 40.0) * 0.12)
			if _state_t > 0.85:
				_vanish("struck")
		"banish":
			var f := clampf(_state_t / 1.1, 0.0, 1.0)
			_model.scale = Vector3(1.0 - f * 0.6, 1.0 + f * 0.25, 1.0 - f * 0.6)
			_model.position.y = -f * 2.6
			_head.rotation.z = sin(_t * 35.0) * 0.5
			if _state_t > 1.15:
				gone.emit(str(get_meta("how", "light")))
				queue_free()


func _stalk(delta: float) -> void:
	seen = _visible()
	if dist > 150.0:
		_vanish("lost")
		return
	if has_meta("glimpse"):
		# only a shape far off in the fog: it watches, and is gone the moment you see it
		_face(1.0)
		_seen_t = _seen_t + delta if seen else 0.0
		if _seen_t > 0.45:
			Sfx.play_flat(main, "sting", -6.0, randf_range(0.9, 1.1))
			_vanish("glimpse")
		elif _state_t > 14.0 and not seen:
			_vanish("glimpse")
		return
	var horror: Node = main.get("horror")
	var safe: bool = horror != null and horror.safe_at(player.global_position)
	if not seen:
		var speed := (3.6 if dist > 18.0 else 5.4) * haste
		if safe and dist < 12.0:
			speed = 0.0
		if player.vehicle and player.vehicle.speed_kmh() > 35.0:
			speed = 0.0
		var dir := Vector3(-global_position.x + player.global_position.x, 0, -global_position.z + player.global_position.z).normalized()
		_walk(dir, speed * delta)
		_face(1.0)
		_head.rotation = Vector3(0.1, 0, 0.35)
		_arm_l.rotation.x = 0.0
		_arm_r.rotation.x = 0.0
	else:
		# frozen in place — but very close, it still edges forward
		if dist < 7.0 and not safe:
			var dir := Vector3(-global_position.x + player.global_position.x, 0, -global_position.z + player.global_position.z).normalized()
			_walk(dir, 0.5 * delta)
		_twitch -= delta
		if _twitch <= 0.0:
			_twitch = randf_range(0.6, 2.2)
			_head.rotation = Vector3(randf_range(-0.2, 0.35), randf_range(-0.4, 0.4), randf_range(-0.9, 0.9))
		_arm_l.rotation.x = sin(_t * 0.9 + _seed) * 0.05
		_arm_r.rotation.x = sin(_t * 0.8 + _seed * 2.0) * 0.05
		# the flashlight burns it
		var cam := player.camera
		var to_me := (global_position + Vector3(0, 1.6, 0) - cam.global_position).normalized()
		var lit := player.flashlight.visible and dist < 34.0 and (-cam.global_basis.z).angle_to(to_me) < deg_to_rad(12.0)
		burn = burn + delta if lit else maxf(burn - delta * 0.5, 0.0)
		if lit:
			_model.position.x = sin(_t * 60.0) * 0.02 * burn
		if burn > 1.6:
			banish("light")
			return
	if horror and horror.fire_near(global_position, 9.0):
		banish("fire")
		return
	# it strikes only what it can touch: same floor, nothing solid in between
	if dist < 1.9 and absf(global_position.y + 1.0 - player.global_position.y) < 2.5 and _clear(global_position + Vector3(0, 1.2, 0), player.global_position + Vector3(0, 0.6, 0)):
		_attack()


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [get_rid(), player.get_rid()]
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Steps along the ground; walls and closed doors stop it, so it slides round them.
func _walk(dir: Vector3, step: float) -> void:
	if step <= 0.0:
		return
	for turn: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var d := dir.rotated(Vector3.UP, turn)
		var p := global_position + d * step
		var chest := global_position + Vector3(0, 1.1, 0)
		if _clear(chest, chest + d * (step + 0.45)):
			global_position = Vector3(p.x, main.terrain.height_at(p.x, p.z), p.z)
			return


func _attack() -> void:
	state = "attack"
	_state_t = 0.0
	collision_layer = 0
	player.stats.hurt(34.0, 0.35, "the Hollow")
	player.hurt_flash = 1.0
	player.shake(1.6)
	player.rumble(1.0, 1.0, 0.7)
	Sfx.play_flat(main, "scream", 3.0, randf_range(0.9, 1.05))
	if main.get("post"):
		main.post.flash(Color(0.95, 0.92, 0.9), 0.85)


func banish(how: String) -> void:
	if state != "stalk":
		return
	state = "banish"
	_state_t = 0.0
	set_meta("how", how)
	collision_layer = 0
	Sfx.play(main, "shriek", global_position + Vector3(0, 2, 0), 4.0, randf_range(0.85, 1.05))


func _vanish(how: String) -> void:
	gone.emit(how)
	queue_free()


## A flare burning close by drives it off.
func scare(pos: Vector3, reach: float) -> void:
	if pos.distance_to(global_position) < reach:
		banish("flare")


## Bullets: it flinches and hisses, and only a lot of them make it go.
func hit(dmg: float, _pos: Vector3, _dir: Vector3, _pen: float, _shooter: Node) -> void:
	if state != "stalk":
		return
	hp -= dmg
	_head.rotation = Vector3(-0.4, 0, randf_range(-1.0, 1.0))
	Sfx.play(main, "groan", global_position + Vector3(0, 2, 0), 0.0, 1.6)
	if hp <= 0.0:
		var bag := LootBox.new()
		bag.setup(true)
		bag.title = "Hollow remains"
		bag.prompt = "Search the ash"
		bag.items = {"hollow_ash": 1 + randi() % 2}
		main.add_child(bag)
		bag.global_position = global_position + Vector3(0, 0.05, 0)
		banish("shot")
