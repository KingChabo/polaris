class_name Player
extends CharacterBody3D
## First-person walking: sprint, crouch, jump, head bob, flashlight, footsteps.

signal stepped(pos: Vector3, yaw: float, left: bool)
signal message(text: String)

const WALK := 4.0
const SPRINT := 7.2
const CROUCH := 2.0
const JUMP := 4.6
const GRAVITY := 14.0

var mouse_sens := 0.0022
var pad_look_speed := 2.6
var invert_y := false
var deadzone := 0.15
var base_fov := 74.0
var camera: Camera3D
var head: Node3D
var flashlight: SpotLight3D
var lake: Lake
var prompt := ""
var head_under_water := false
var swimming := false
var _target: Object
var stats: Stats
var inv: Inventory
var village: Village
var weather: Weather
var screen: InvScreen
var ui_open := false
var spawn := Vector3.ZERO
var arms: Arms
var bullets: Bullets
var look_scale := 1.0      # smaller while zoomed in
var crouching := false
var dodge_t := 0.0         # seconds of dodge left (you cannot be hit by blows)
var dodge_vel := Vector3.ZERO
var hurt_flash := 0.0
var vehicle: Vehicle       # the one you are driving
var chase: Camera3D
var third_person := true
var climbing := false
var hud_target: Node3D     # whoever you hit last, for the bar at the top of the screen
var hud_target_t := 0.0
var hit_kind := "hit"      # hit / head / kill / headkill: colours the hit marker
var hurt_marks: Array = [] # [where it came from, seconds left]: red wedges on the HUD

var _pitch := 0.0
var _stride := 0.0
var _left := false
var _bob := 0.0
var _crouch := 0.0
var _capsule: CapsuleShape3D
var _cs: CollisionShape3D
var _veh_yaw := 0.0
var _orbit := 0.0
var _shake := 0.0
var _climb_cd := 0.0
var _climb_told := false
var _step_lag := 0.0       # metres the view still trails behind a step just taken


func _init() -> void:
	inv = Inventory.new()
	for id in ["light_jacket", "jeans", "boots"]:
		inv.add(id)
		inv.equip(id)
	inv.add("bandage")
	inv.add("canned_food")
	inv.add("knife")
	stats = Stats.new()
	stats.inv = inv


func _ready() -> void:
	add_child(stats)
	stats.note.connect(func(t: String) -> void: message.emit(t))
	stats.died.connect(_on_died)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = 1.8
	_cs = CollisionShape3D.new()
	_cs.shape = _capsule
	_cs.position.y = 0.9
	add_child(_cs)
	collision_mask = 3
	chase = Camera3D.new()
	chase.top_level = true
	chase.fov = 70.0
	chase.near = 0.1
	chase.far = 5000.0
	add_child(chase)
	floor_max_angle = deg_to_rad(47.0)
	floor_snap_length = 0.4

	head = Node3D.new()
	head.position.y = 1.68
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 74.0
	camera.near = 0.08
	camera.far = 5000.0
	head.add_child(camera)
	camera.make_current()      # the chase camera came first and would otherwise be the one you look through

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 45.0
	flashlight.spot_angle = 26.0
	flashlight.light_energy = 6.0
	flashlight.light_color = Color(1.0, 0.93, 0.8)
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 2.0
	flashlight.position = Vector3(0.25, -0.2, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)
	arms = Arms.new()
	arms.player = self
	camera.add_child(arms)


## Controller vibration, if the player wants it.
func rumble(weak: float, strong: float, secs: float) -> void:
	if bool(Settings.get_v("vibration")) and not Input.get_connected_joypads().is_empty():
		Input.start_joy_vibration(0, weak, strong, secs)


## Recoil: throws the view up and a little sideways.
func kick(up: float, side: float) -> void:
	_pitch = clampf(_pitch + up, -1.5, 1.5)
	rotation.y += side


func aim_at(point: Vector3) -> void:
	var d := point - camera.global_position
	rotation.y = atan2(-d.x, -d.z)
	_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	head.rotation.x = _pitch


## Turns the view smoothly towards a point (someone you are talking to).
func face_toward(point: Vector3, delta: float, rate := 4.0) -> void:
	var d := point - camera.global_position
	var k := minf(delta * rate, 1.0)
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), k)
	_pitch = lerpf(_pitch, atan2(d.y, Vector2(d.x, d.z).length()), k)
	head.rotation.x = _pitch


## Ground and air movement with momentum:
## - sprinting straight ahead builds up to MOMENTUM_MAX extra speed; sharp turns bleed it off
## - a sprint jump carries that speed through the air (air control steers, never brakes)
## - land and jump again within BHOP_WINDOW and you keep it (no landing friction)
## - Ctrl while sprinting: a slide that keeps the speed and ducks under things
## - jump in the air next to a wall: kick off it (two kicks, then touch the ground)
## - coyote time and a jump buffer, so the jump comes when you mean it
const MOMENTUM_MAX := 0.32       # +32 % on top of sprint
const BHOP_WINDOW := 0.16
const COYOTE := 0.12
const BUFFER := 0.14
const WALL_KICKS := 2
var momentum := 0.0              # 0..1
var sliding := 0.0               # seconds of slide left
var _air_t := 0.0
var _land_t := 9.0
var _jump_buf := 0.0
var _kicks := 0
var _last_yaw := 0.0
var _slide_dir := Vector3.ZERO

func _move_tick(delta: float, target: Vector3, speed: float, sprinting: bool, inp: Vector2) -> void:
	var grounded := is_on_floor()
	if Input.is_action_just_pressed("jump") and not ui_open:
		_jump_buf = BUFFER
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	var turn := absf(angle_difference(_last_yaw, rotation.y)) / maxf(delta, 0.001)
	_last_yaw = rotation.y
	if grounded:
		if _air_t > 0.0:
			_land_t = 0.0
		_air_t = 0.0
		_kicks = 0
		_land_t += delta
	else:
		_air_t += delta
	# momentum: builds while sprinting straight, fades when you stop, turn hard or slow down
	if sprinting and grounded and inp.y < -0.5 and turn < 2.5:
		momentum = minf(momentum + delta * 0.45, 1.0)
	elif grounded and _land_t > BHOP_WINDOW and sliding <= 0.0:
		momentum = maxf(momentum - delta * (2.2 if not sprinting else 0.9), 0.0)
	if turn > 4.0:
		momentum = maxf(momentum - delta * turn * 0.12, 0.0)
	var boost := 1.0 + MOMENTUM_MAX * momentum
	# slide: Ctrl while sprinting fast
	if grounded and Input.is_action_just_pressed("crouch") and sliding <= 0.0 and Vector2(velocity.x, velocity.z).length() > SPRINT * 0.85:
		sliding = 0.85
		_slide_dir = Vector3(velocity.x, 0, velocity.z).normalized()
		var sp := Vector2(velocity.x, velocity.z).length() + 1.6
		velocity.x = _slide_dir.x * sp
		velocity.z = _slide_dir.z * sp
		shake(0.25)
	if sliding > 0.0:
		sliding -= delta
		var sp2 := Vector2(velocity.x, velocity.z).length()
		sp2 = move_toward(sp2, 0.0, delta * (4.0 - get_floor_normal().dot(Vector3.UP) * 1.5 if grounded else 1.0))
		velocity.x = _slide_dir.x * sp2
		velocity.z = _slide_dir.z * sp2
		if not grounded:
			velocity.y -= GRAVITY * delta
		if _jump_buf > 0.0 and (grounded or _air_t < COYOTE) and stats.use_stamina(8.0):
			sliding = 0.0
			_do_jump(1.0 + momentum * 0.15)
		if not Input.is_action_pressed("crouch") or sp2 < 2.0:
			sliding = minf(sliding, 0.0)
		return
	if grounded:
		var want := target * boost
		var accel := 11.0
		# right after landing a jump the ground does not brake you yet
		if _land_t < BHOP_WINDOW and Vector2(velocity.x, velocity.z).length() > want.length():
			pass
		else:
			velocity.x = move_toward(velocity.x, want.x, accel * delta * speed)
			velocity.z = move_toward(velocity.z, want.z, accel * delta * speed)
	else:
		# air control: steer toward where you push, but never brake below the speed you carry
		var hv := Vector2(velocity.x, velocity.z)
		var keep := hv.length()
		var steer := Vector2(target.x, target.z)
		if steer.length() > 0.1:
			hv = hv.move_toward(steer.normalized() * maxf(keep, steer.length()), 5.0 * delta)
			if hv.length() > keep and keep > steer.length():
				hv = hv.normalized() * keep
		velocity.x = hv.x
		velocity.z = hv.y
		velocity.y -= GRAVITY * delta
	if _jump_buf > 0.0:
		if (grounded or _air_t < COYOTE) and velocity.y <= 0.5:
			if stats.use_stamina(8.0):
				var chained := _land_t < BHOP_WINDOW
				_do_jump(1.0 + (0.08 if sprinting else 0.0))
				if sprinting:
					# a sprint jump: a little shove forward, more when chained
					var f := -global_basis.z
					velocity.x += f.x * (0.6 + (0.5 if chained else 0.0))
					velocity.z += f.z * (0.6 + (0.5 if chained else 0.0))
					if chained:
						momentum = minf(momentum + 0.15, 1.0)
		elif not grounded and _kicks < WALL_KICKS:
			_wall_kick()


func _do_jump(mult: float) -> void:
	velocity.y = JUMP * mult
	_jump_buf = 0.0
	_air_t = COYOTE + 0.01


## In the air beside or in front of a wall: push off it, up and away.
func _wall_kick() -> void:
	var space := get_world_3d().direct_space_state
	var best := {}
	for a in 8:
		var d := Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0))
		var from := global_position + Vector3(0, 0.9, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 0.75)
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var r := space.intersect_ray(q)
		if not r.is_empty() and absf((r["normal"] as Vector3).y) < 0.35:
			if best.is_empty() or from.distance_to(r["position"]) < from.distance_to(best["position"]):
				best = r
	if best.is_empty() or not stats.use_stamina(10.0):
		return
	var n: Vector3 = best["normal"]
	n.y = 0.0
	n = n.normalized()
	# away from the wall, keeping some of the run along it
	var along := Vector3(velocity.x, 0, velocity.z)
	along -= n * along.dot(n)
	var out := n * 5.2 + along * 0.85
	velocity.x = out.x
	velocity.z = out.z
	velocity.y = JUMP * 1.05
	_kicks += 1
	_jump_buf = 0.0
	momentum = minf(momentum + 0.1, 1.0)
	shake(0.15)
	Sfx.play(get_parent(), "thud", global_position, -8.0, 1.6)


## Walks up a step (door sill, porch, kerb) up to STEP high instead of stopping against it,
## the way a real foot does. Tries: lift, move on, set down on something flat.
const STEP := 0.48
func _step_up(vel: Vector3, delta: float) -> void:
	var blocked := false
	for i in get_slide_collision_count():
		# walls, but also the bevelled nose of a step or a threshold (about 45°)
		if get_slide_collision(i).get_normal().y < 0.78:
			blocked = true
	if not blocked:
		return
	var h := Vector3(vel.x, 0, vel.z)
	if h.length() < 0.1:
		return
	# look a little further ahead than one frame, so the foot lands on the tread
	h = h.normalized() * maxf(h.length() * delta, 0.12)
	var xf := global_transform
	var up := Vector3(0, STEP, 0)
	if test_move(xf, up):
		return
	xf.origin += up
	if test_move(xf, h):
		return
	xf.origin += h
	var col := KinematicCollision3D.new()
	if not test_move(xf, Vector3(0, -STEP - 0.05, 0), col):
		return
	if col.get_normal().y < 0.75:
		return
	xf.origin += col.get_travel()
	if xf.origin.y - global_position.y < 0.04:
		return
	# the camera does not jump up with the body: it follows smoothly
	_step_lag -= xf.origin.y - global_position.y
	global_transform = xf
	velocity.x = vel.x
	velocity.z = vel.z
	velocity.y = 0.0


## A bullet hit you.
func hit(dmg: float, _pos: Vector3, dir: Vector3, pen: float, shooter: Node) -> void:
	stats.hurt(dmg, 0.25, "gunshot wounds", pen)
	hurt_flash = 1.0
	shake(0.9)
	rumble(0.5, 0.8, 0.25)
	var from := global_position - dir * 20.0
	if shooter is Node3D and is_instance_valid(shooter):
		from = (shooter as Node3D).global_position
	hurt_marks.append([from, 1.6])
	Sfx.play(get_parent(), "thud", global_position, -2.0, 1.3)


## Jolts the view: recoil, blows, crashes.
func shake(amount: float) -> void:
	_shake = minf(maxf(_shake, amount), 1.6)


## A blow from an enemy; blocking, parrying and dodging are decided here.
func melee_hit(dmg: float, bleed: float, attacker: Node3D) -> String:
	var res := arms.incoming_melee(dmg, bleed, attacker)
	if res == "hit":
		shake(1.2)
		hurt_marks.append([attacker.global_position, 1.6])
	elif res == "blocked":
		shake(0.5)
	elif res == "parried":
		shake(0.35)
		Fx.sparks(get_parent(), camera.global_position - camera.global_basis.z * 0.6, camera.global_basis.z)
		Fx.hitstop(get_tree(), 0.09)
	return res


func landed_hit(target_hit: Object) -> void:
	arms.hit_flash = 0.25
	hit_kind = "hit"
	if target_hit is Enemy:
		var e := target_hit as Enemy
		hud_target = e
		hud_target_t = 3.5
		if e.state == "dead":
			hit_kind = "kill"
			arms.hit_flash = 0.45
			Sfx.play(get_parent(), "clank", camera.global_position, -9.0, 1.9)
			Sfx.play(get_parent(), "thud", camera.global_position, -6.0, 0.7)
			if e.last_head:
				hit_kind = "headkill"
				arms.hit_flash = 0.6
				Fx.slowmo(get_tree(), 0.3, 0.3)
			shake(0.35)
		elif e.last_head:
			hit_kind = "head"
	elif target_hit is Node3D and (target_hit as Node3D).has_method("hit"):
		hud_target = null


func enter_vehicle(v: Vehicle) -> void:
	if vehicle or v.driver:
		return
	vehicle = v
	v.driver = self
	v._apply_upgrades()
	_cs.disabled = true
	velocity = Vector3.ZERO
	arms.visible = false
	_veh_yaw = v.global_rotation.y
	rotation.y = _veh_yaw
	_pitch = 0.0
	_orbit = 0.0
	_target = null
	prompt = ""
	_set_view()
	chase.global_position = v.global_position + Vector3(0, 4, 0) + v.global_basis.z * 8.0
	message.emit("[W/S] drive  ·  [A/D] steer  ·  [Space] handbrake  ·  [F] lights  ·  [G] winch  ·  [V] view  ·  [E] get out")


func exit_vehicle(force := false) -> bool:
	if vehicle == null:
		return false
	var v := vehicle
	if not force and not v.sunk and v.linear_velocity.length() > 3.0:
		message.emit("Stop first — you are still rolling.")
		return false
	var out := v.global_position
	if v.sunk:
		out = lake.edge_of_break(v.global_position)
		message.emit("You drag yourself out onto the ice, soaked to the skin.")
	else:
		var e: Vector3 = v.cfg["exit"]
		var space := get_world_3d().direct_space_state
		for side in [1.0, -1.0]:
			var s: float = side
			out = v.to_global(Vector3(e.x * s, 0.3, e.z))
			out.y = maxf(out.y, v.world.terrain.surface_at(out.x, out.z) + 0.2)
			var q := PhysicsRayQueryParameters3D.create(v.global_position + Vector3(0, 1.0, 0), out + Vector3(0, 1.0, 0))
			q.exclude = [v.get_rid(), get_rid()]
			q.collision_mask = 3
			if space.intersect_ray(q).is_empty():
				break
	vehicle = null
	v.driver = null
	_cs.disabled = false
	arms.visible = true
	global_position = out
	velocity = Vector3.ZERO
	_set_view()
	return true


func _set_view() -> void:
	if vehicle and third_person:
		chase.make_current()
	else:
		camera.make_current()


## While driving: sit in the seat, look around, and move the outside camera.
func _drive_tick(delta: float) -> void:
	var v := vehicle
	hurt_flash = maxf(hurt_flash - delta * 1.5, 0.0)
	_target = null
	prompt = ""
	var yaw := v.global_rotation.y
	rotation.y += angle_difference(_veh_yaw, yaw)
	_veh_yaw = yaw
	var eye: Vector3 = v.to_global(v.cfg["seat"])
	global_position = eye - Vector3(0, 1.68, 0)
	head.position = Vector3(0, 1.68, 0)
	head.rotation.x = _pitch
	swimming = false
	head_under_water = v.sunk and eye.y < Terrain.LAKE_LEVEL
	var shelter := 1 if bool(v.cfg["cabin"]) and not v.sunk else 0
	stats.tick(delta, false, false, head_under_water, shelter, weather.storm if weather else 0.1)
	if vehicle == null:
		return    # died at the wheel
	if third_person:
		var size: Vector3 = v.cfg["size"]
		var dist := size.z * 1.2 + 3.2
		if v.linear_velocity.length() > 3.0:
			_orbit = lerp_angle(_orbit, 0.0, delta * 0.8)
		var ang := yaw + _orbit
		var tilt := clampf(0.3 - _pitch, 0.05, 1.2)
		var want := v.global_position + Vector3(0, 1.3, 0) \
				+ Vector3(sin(ang), 0, cos(ang)) * dist * cos(tilt) + Vector3.UP * dist * sin(tilt)
		want.y = maxf(want.y, v.world.terrain.surface_at(want.x, want.z) + 0.6)
		chase.global_position = chase.global_position.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
		chase.look_at(v.global_position + Vector3(0, 1.3, 0))


## Climbing steep rock and ice: push into the face and hold jump to grab on.
## An ice pick makes it faster and cheaper; a rope catches you when your arms give out.
func _climb_tick(delta: float, inp: Vector2) -> bool:
	_climb_cd = maxf(_climb_cd - delta, 0.0)
	var fwd := -global_basis.z
	var wall := {}
	if _climb_cd <= 0.0 and not ui_open:
		var space := get_world_3d().direct_space_state
		for h in [1.2, 0.45]:
			var hh: float = h
			var from := global_position + Vector3(0, hh, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 0.95)
			q.exclude = [get_rid()]
			q.collision_mask = 1
			var r := space.intersect_ray(q)
			if r.is_empty():
				continue
			var n: Vector3 = r["normal"]
			var col: Node = r["collider"]
			if n.y < 0.8 and n.y > -0.3 and (col.get_parent() is Terrain or col.has_meta("climb")):
				wall = r
				break
	if not climbing:
		if wall.is_empty() or inp.y > -0.1 or not Input.is_action_pressed("jump"):
			return false
		if stats.stamina < 10.0:
			return false
		climbing = true
		arms.visible = false
		if not _climb_told:
			_climb_told = true
			message.emit("Climbing:  [W/S] up and down  ·  [A/D] sideways  ·  [Ctrl] let go")
	if wall.is_empty():
		# over the edge: pull yourself up
		climbing = false
		arms.visible = true
		velocity = fwd * 2.6 + Vector3.UP * 4.6
		_climb_cd = 0.5
		return false
	if Input.is_action_just_pressed("crouch"):
		climbing = false
		arms.visible = true
		_climb_cd = 0.7
		return false
	var normal: Vector3 = wall["normal"]
	var pick := inv.count("ice_pick") > 0
	var rope := inv.count("rope") > 0
	var along := normal.cross(Vector3.UP).normalized()
	if along.dot(global_basis.x) < 0.0:
		along = -along
	var up := along.cross(normal).normalized()
	if up.y < 0.0:
		up = -up
	var moving := inp != Vector2.ZERO
	var down := inp.y > 0.1
	var cost := (3.0 if pick else 6.0) * (1.0 + maxf(stats.load_ratio() - 0.5, 0.0))
	if rope and down:
		cost = 0.0      # abseiling
	if rope and not moving:
		stats.stamina = minf(stats.stamina + 9.0 * delta, 100.0)     # resting in the rope
	else:
		stats.stamina = maxf(stats.stamina - cost * delta * (1.0 if moving else 0.3), 0.0)
	stats._rest = 0.0
	var speed := 2.0 if pick else 1.3
	if rope and down:
		speed = 3.4
	velocity = (up * -inp.y + along * inp.x) * speed - normal * 1.2
	if stats.stamina <= 0.0:
		if rope:
			velocity = -up * 1.2 - normal * 1.0      # hanging in the rope, sliding down slowly
		else:
			climbing = false
			arms.visible = true
			_climb_cd = 1.2
			message.emit("Your grip gives out!")
			return false
	move_and_slide()
	if is_on_floor() and down:
		climbing = false
		arms.visible = true
		_climb_cd = 0.3
	head.position.y = 1.68
	head.position.x = sin(Time.get_ticks_msec() * 0.006) * 0.025 * (1.0 if moving else 0.0)
	head.rotation.x = _pitch
	stats.tick(delta, false, moving, false, 0, weather.storm if weather else 0.1)
	return true


func _on_died(cause: String) -> void:
	climbing = false
	arms.visible = true
	exit_vehicle(true)
	# a boss you fell against gets its strength back: no wearing it down by dying
	var main := get_parent()
	var near_boss := false
	if main.get("bosses"):
		for b in main.bosses.get_children():
			if b is Enemy and (b as Enemy).state != "dead":
				if (b as Node3D).global_position.distance_to(global_position) < 90.0:
					near_boss = true
				(b as Enemy).health = (b as Enemy).max_health
	# dying costs a tenth of your Kronen (at most 50)
	var lost := mini(int(inv.count("coin") * 0.1), 50) if not GameMode.creator() else 0
	if lost > 0:
		inv.remove("coin", lost)
	# wake at the nearest place you have found, out of a boss's reach; else the village
	var wake := spawn
	if main.get("places") and not GameMode.horror():
		var best := global_position.distance_to(spawn)
		for s in main.places.spots:
			if not str(s["id"]) in main.places.found:
				continue
			var sp: Vector3 = s["pos"]
			var safe := true
			if main.get("bosses"):
				for b in main.bosses.get_children():
					if b is Enemy and (b as Enemy).state != "dead" and (b as Node3D).global_position.distance_to(sp) < 70.0:
						safe = false
			if safe and sp.distance_to(global_position) < best and not Places.underground(sp):
				best = sp.distance_to(global_position)
				wake = Vector3(sp.x, main.terrain.surface_at(sp.x, sp.z) + 1.0, sp.z) if main.get("terrain") else sp + Vector3(0, 1.0, 0)
	message.emit("You died of %s.%s%s" % [cause, (" You lost %d Kronen." % lost) if lost > 0 else "", " The enemy has recovered." if near_boss else ""])
	global_position = wake
	velocity = Vector3.ZERO
	stats.revive()
	get_tree().call_group("enemy", "calm")


func open_container(box: LootBox) -> void:
	if screen:
		screen.open(box)


## Puts a dropped item into a bag at your feet.
func drop_item(id: String) -> void:
	var bag: LootBox = null
	for n in get_tree().get_nodes_in_group("loot"):
		var b: LootBox = n
		if b.dynamic and b.global_position.distance_to(global_position) < 2.0:
			bag = b
			break
	if bag == null:
		bag = LootBox.new()
		bag.setup(true)
		get_parent().add_child(bag)
		var fwd := -global_basis.z
		bag.global_position = global_position + Vector3(fwd.x, 0.0, fwd.z) * 0.9
	bag.put(id)


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event.is_action_pressed("inventory") and screen:
		screen.open(null)
		return
	if event.is_action_pressed("quicksave"):
		message.emit("Game saved." if SaveGame.save(get_parent()) else "Saving failed.")
		return
	if event.is_action_pressed("quickload"):
		message.emit("Game loaded." if SaveGame.load_game(get_parent()) else "No saved game.")
		return
	if vehicle:
		if event.is_action_pressed("interact"):
			exit_vehicle()
			return
		if event.is_action_pressed("flashlight"):
			vehicle.toggle_lights()
			return
		if event.is_action_pressed("winch"):
			vehicle.toggle_winch()
			return
		if event.is_action_pressed("camera"):
			third_person = not third_person
			_set_view()
			return
		if third_person and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_orbit -= event.relative.x * mouse_sens
			_pitch = clampf(_pitch - event.relative.y * mouse_sens * (-1.0 if invert_y else 1.0), -0.9, 0.25)
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sens * look_scale
		_pitch = clampf(_pitch - event.relative.y * mouse_sens * look_scale * (-1.0 if invert_y else 1.0), -1.5, 1.5)
	elif event.is_action_pressed("pause"):
		var m = get_parent().get("menu")
		if m:
			m.open_pause()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("map") and get_parent().get("map"):
		get_parent().map.open()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("interact") and _target:
		_target.interact(self)


func _update_interact() -> void:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 3.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_target = null
	prompt = ""
	if hit and hit.collider.has_method("interact"):
		_target = hit.collider
		prompt = str(hit.collider.get("prompt"))


func _physics_process(delta: float) -> void:
	# right stick look
	var lx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ly := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if ui_open:
		lx = 0.0
		ly = 0.0
	if absf(lx) > deadzone:
		rotation.y -= signf(lx) * (absf(lx) - deadzone) / (1.0 - deadzone) * pad_look_speed * delta * look_scale
	if absf(ly) > deadzone:
		_pitch = clampf(_pitch - signf(ly) * (absf(ly) - deadzone) / (1.0 - deadzone) * pad_look_speed * delta * look_scale * (-1.0 if invert_y else 1.0), -1.5, 1.5)

	hud_target_t = maxf(hud_target_t - delta, 0.0)
	for m in hurt_marks:
		m[1] = float(m[1]) - delta
	hurt_marks = hurt_marks.filter(func(m: Array) -> bool: return float(m[1]) > 0.0)
	_shake = maxf(_shake - delta * 3.2, 0.0)
	camera.rotation = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-0.6, 0.6)) * _shake * _shake * 0.03
	if vehicle:
		_drive_tick(delta)
		return
	# over a hole that a vehicle broke, the ice does not carry you
	collision_mask = 1 if lake != null and lake.in_break(global_position) else 3
	crouching = Input.is_action_pressed("crouch") and not ui_open
	hurt_flash = maxf(hurt_flash - delta * 1.5, 0.0)
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 6.0)
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if ui_open:
		inp = Vector2.ZERO
	var sprinting := false
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var speed := WALK
	if crouching:
		speed = CROUCH
	elif Input.is_action_pressed("sprint") and inp.y < 0.0 and stats.can_sprint() and arms.aim < 0.1 and not arms.blocking:
		speed = SPRINT
		sprinting = true
	speed *= stats.speed_mult() * lerpf(1.0, 0.6, arms.aim) * (0.5 if arms.blocking else 1.0)
	var target := dir * speed
	_update_interact()

	swimming = lake != null and lake.in_water(global_position) and global_position.y < Terrain.LAKE_LEVEL - 0.7
	head_under_water = lake != null and lake.in_water(camera.global_position - Vector3(0, 0.1, 0))
	var shelter := village.shelter_at(global_position) if village else 0
	stats.tick(delta, sprinting, inp != Vector2.ZERO, swimming or head_under_water, shelter, weather.storm if weather else 0.1)
	if swimming:
		# float with the head just above the water; jump to climb out onto the ice
		var want := Terrain.LAKE_LEVEL - 1.5
		velocity.y = move_toward(velocity.y, clampf((want - global_position.y) * 3.0, -2.0, 2.0), 12.0 * delta)
		velocity.x = move_toward(velocity.x, dir.x * 2.2, 6.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * 2.2, 6.0 * delta)
		if Input.is_action_just_pressed("jump") and global_position.y > want - 0.4:
			velocity.y = 7.0
		move_and_slide()
		head.position.y = 1.68 + sin(Time.get_ticks_msec() * 0.002) * 0.04
		head.rotation.x = _pitch
		return

	if _climb_tick(delta, inp):
		return
	if dodge_t > 0.0:
		dodge_t -= delta
		velocity.x = dodge_vel.x
		velocity.z = dodge_vel.z
		velocity.y -= GRAVITY * delta
	else:
		_move_tick(delta, target, speed, sprinting, inp)
	var fall_v := -velocity.y
	var was_on_floor := is_on_floor()
	var pre_vel := velocity
	move_and_slide()
	if was_on_floor and Vector2(target.x, target.z).length() > 0.5:
		_step_up(pre_vel, delta)
	if is_on_floor() and not was_on_floor:
		stats.fall(fall_v)

	var flat := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat > 0.5:
		_stride += flat * delta
		_bob += flat * delta * 1.9
		var step_len := 0.75 if flat < 5.0 else 1.1
		if _stride > step_len:
			_stride = 0.0
			_left = not _left
			stepped.emit(global_position, rotation.y, _left)
	var bob_amt := clampf(flat / SPRINT, 0.0, 1.0)
	_step_lag = move_toward(_step_lag, 0.0, delta * 3.0)
	head.position.y = lerpf(1.68, 1.05, _crouch) + sin(_bob * 2.0) * 0.035 * bob_amt + _step_lag
	head.position.x = cos(_bob) * 0.02 * bob_amt
	head.rotation.x = _pitch
