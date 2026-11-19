class_name Enemy
extends CharacterBody3D
## Shared base of everything that fights: health, armour, senses, moving over
## the terrain, getting hit and dying. Raider and Wolf add the behaviour.

const GRAVITY := 14.0

var id := ""               # fixed enemies have an id so the save file knows who is dead
var player: Player
var health := 80.0
var max_health := 80.0
var armor := 0.0
var speed := 3.6
var head_y := 1.47         # hits above this height are head shots
var eye_y := 1.6
var view_dist := 45.0
var home := Vector3.ZERO
var state := "idle"        # idle / alert / fight / flee / dead
var loot := {}
var bleeds := true        # machines and things of ice do not
var passive := false       # tests: stands still and does nothing
var body_title := "Body"
var display_name := "Enemy"
var faction := ""          # whose side: killing them moves your standing
var model: Node3D
var last_damage := 0.0
var last_head := false
var factions: Factions     # set by whoever places us; nil = always hostile
var bulk := 0.0            # how far the body reaches from its middle (big things stand closer to a blast than their centre)
var bag_side := 0.7        # how far beside the body the loot bag lands
var provoked := false      # you shot first: no truce protects you now

var _stagger := 0.0
var _aware := 0.0
var _last_seen := Vector3.ZERO
var _lost := 0.0
var _sees := false
var _see_cd := 0.0
var _stuck := 0.0
var _side_t := 0.0
var _side := 1.0
var _phase := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0


func make_body(radius: float, height: float) -> void:
	add_to_group("enemy")
	collision_mask = 3
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4


func _physics_process(delta: float) -> void:
	if state == "dead" or player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > 170.0 and state == "idle":
		return   # too far away to matter
	_stagger = maxf(_stagger - delta, 0.0)
	_see_cd -= delta
	if _see_cd <= 0.0:
		_see_cd = 0.15
		_sees = not passive and not peaceful() and _can_see(dist)
	var want := Vector3.ZERO
	if not passive and _stagger <= 0.0:
		want = _think(delta, dist)
	if _side_t > 0.0:   # walking round something
		_side_t -= delta
		want = want.rotated(Vector3.UP, _side * 1.2)
	velocity.x = move_toward(velocity.x, want.x, 22.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 22.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
	var wl := Vector2(want.x, want.z).length()
	if wl > 1.0 and moved < wl * 0.3:
		_stuck += delta
		if _stuck > 0.45:
			_stuck = 0.0
			_side_t = 0.9
			_side = 1.0 if randf() < 0.5 else -1.0
			if is_on_floor():
				velocity.y = 4.2   # hop over low things
	else:
		_stuck = 0.0
	_phase += _stride(moved) * delta
	_animate(delta, moved)


## How fast the walk cycle turns at this speed (people override it with a real gait).
func _stride(moved: float) -> float:
	return moved * 2.4


## True while this one's faction has no quarrel with you.
func peaceful() -> bool:
	return faction != "" and factions != null and not provoked and not factions.hostile(faction)


## Behaviour; returns the wanted horizontal velocity.
func _think(_delta: float, _dist: float) -> Vector3:
	return Vector3.ZERO


func _animate(_delta: float, _moved: float) -> void:
	pass


func _flat_to(target: Vector3) -> Vector3:
	var d := target - global_position
	d.y = 0.0
	return d


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))


## Slow wandering around the home spot.
func _roam(delta: float, radius: float, pace: float) -> Vector3:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(3.0, 8.0)
		_wander = home + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius)) if randf() < 0.7 else Vector3.INF
	if _wander == Vector3.INF:
		return Vector3.ZERO
	var d := _flat_to(_wander)
	if d.length() < 1.0:
		return Vector3.ZERO
	_face(d, delta)
	return d.normalized() * pace


func _can_see(dist: float) -> bool:
	var storm := player.weather.storm if player.weather else 0.1
	var reach := view_dist * (1.0 - 0.55 * storm) * (0.55 if player.crouching else 1.0) * (1.3 if player.flashlight.visible else 1.0)
	if state == "fight":
		reach *= 1.6
	if dist > reach:
		return false
	var eye := global_position + Vector3(0, eye_y, 0)
	var to := player.camera.global_position - eye
	if state != "fight" and dist > 5.0 and (-global_basis.z).dot(to.normalized()) < 0.25:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, eye + to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == player


## Called by bullets and blades.
func hit(dmg: float, pos: Vector3, dir: Vector3, pen: float, _shooter: Node) -> void:
	if state == "dead":
		return
	if _shooter is Enemy and _shooter != self and faction != "" and (_shooter as Enemy).faction == faction:
		return   # a comrade's stray round: soldiers do not shoot their own
	provoked = true
	last_head = pos.y - global_position.y > head_y
	last_damage = Damage.apply(dmg, armor * (0.3 if last_head else 1.0), pen) * (Damage.HEAD if last_head else 1.0)
	if _shooter is Player:
		last_damage *= Settings.dmg_dealt()
	health -= last_damage
	_stagger = maxf(_stagger, 0.18)
	if model:
		model.rotation.z = randf_range(-0.22, 0.22)   # flinch
	Fx.blood(get_parent(), pos, dir, last_head)
	if bleeds and last_damage > 18.0 and health > 0.0:
		Fx.bleed(self, 2.5, pos.y - global_position.y)
	if health <= 0.0:
		_die(dir)
	elif not passive:
		_last_seen = player.global_position
		_lost = 0.0
		_on_hurt()


func _on_hurt() -> void:
	state = "fight"


func stagger(t: float) -> void:
	_stagger = maxf(_stagger, t)


## A noise at `pos` that carries `reach` metres.
func hear(pos: Vector3, reach: float) -> void:
	if state in ["idle", "alert"] and not passive and global_position.distance_to(pos) < reach:
		state = "alert"
		_last_seen = pos
		_lost = 0.0


func alarm(target: Vector3) -> void:
	if state in ["idle", "alert"] and not passive:
		state = "alert"
		_aware = 0.6
		_last_seen = target
		_lost = 0.0


func scare(_pos: Vector3, _reach: float) -> void:
	pass


func calm() -> void:
	if state != "dead":
		state = "idle"
		_aware = 0.0


## How the body goes down.
func _fall(dir: Vector3) -> void:
	if model:
		var tw := create_tween()
		var back := 1.0 if (-global_basis.z).dot(dir) < 0.0 else -1.0
		tw.tween_property(model, "rotation:x", back * PI * 0.48, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(model, "position:y", 0.14, 0.45)


func _die(dir: Vector3) -> void:
	state = "dead"
	health = 0.0
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	Sfx.play(get_parent(), "thud", global_position, 2.0, 0.7)
	_fall(dir)
	if bleeds:
		Fx.bleed(self, 3.0, 0.9)
		get_tree().create_timer(0.6).timeout.connect(func() -> void: if is_instance_valid(self): Fx.pool(get_parent(), global_position))
	if not loot.is_empty():
		var bag := LootBox.new()
		bag.setup(true)
		bag.title = body_title
		bag.prompt = "Search " + body_title.to_lower()
		bag.items = loot.duplicate()
		get_parent().get_parent().add_child(bag)
		var side := global_basis.x * bag_side
		bag.global_position = global_position + Vector3(side.x, 0.05, side.z)
	if get_parent().has_method("on_died"):
		get_parent().on_died(self)
