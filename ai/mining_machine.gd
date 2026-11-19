class_name MiningMachine
extends Boss


func _init() -> void:
	bleeds = false
## K-9, the continuous miner in the lower chamber. Nobody switched it off.
## Phase 1: it grinds after you with the cutter drum; the hull shrugs bullets off.
##          The two power cells on its flanks do not.
## Phase 2: one cell gone — it starts throwing rivets and bringing the roof down.
## Phase 3: both gone — the core lies open at the back, it rams, and it has to stop and vent.
## The red barrels in the chamber hurt it more than any rifle.

const LANE := Rect2(589.0, 134.0, 13.0, 12.0)   # where it can drive (world x, z)

var bullets: Bullets
var mode := "sleep"            # sleep / grind / back / rivets / rocks / vent / ram / magnet / drones
var drones_made := 0
var _t := 0.0
var _boom: Node3D
var _drum: Node3D
var _boom_want := 0.0
var _bite_cd := 0.0
var _shot_cd := 0.0
var _burst := 0
var _step := 0
var _ram_hit := false
var _lamps: Array[Node3D] = []
var _hatch: Node3D
var _steam := 0.0
var rocks_made := 0


func setup() -> void:
	add_to_group("enemy")
	collision_mask = 3
	for b: Array in [[Vector3(3.8, 2.3, 6.0), Vector3(0, 1.15, 0.3)], [Vector3(1.3, 1.0, 1.6), Vector3(-0.6, 2.75, 1.2)]]:
		var sh := BoxShape3D.new()
		sh.size = b[0]
		var cs := CollisionShape3D.new()
		cs.shape = sh
		cs.position = b[1]
		add_child(cs)
	floor_snap_length = 0.4
	boss_name = "K-9"
	boss_sub = "The hull is too thick. Shoot the green power cells."
	display_name = "K-9"
	body_title = "Wreck of K-9"
	bag_side = 3.0
	bulk = 2.6
	max_health = 900.0
	health = max_health
	armor = 88.0
	head_y = 99.0
	eye_y = 2.3
	view_dist = 40.0
	model = _build()
	add_child(model)


func _build() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new()
	k.winter = true  # creatures keep their ice and frost in summer
	for sx: float in [-1.0, 1.0]:
		k.bbox(Vector3(sx * 1.5, 0.5, 0.3), Vector3(0.8, 1.0, 6.0), 0.2, "black_in")
		for i in 12:
			k.box(Vector3(sx * 1.5, 1.02, -2.4 + i * 0.5), Vector3(0.82, 0.05, 0.14), "metal_in")
		k.box(Vector3(sx * 1.92, 0.9, -0.6), Vector3(0.06, 0.7, 1.6), "hazard_in")
	k.bbox(Vector3(0, 1.5, 0.6), Vector3(2.6, 1.5, 4.8), 0.12, "paint_yellow_in")
	k.bbox(Vector3(-0.6, 2.7, 1.2), Vector3(1.3, 1.0, 1.6), 0.1, "paint_yellow_in")
	k.box(Vector3(-0.6, 2.75, 0.39), Vector3(1.1, 0.6, 0.02), "glass_dark")
	k.tube(Vector3(0.6, 0.5, 3.0), Vector3(0.9, 1.6, 6.5), 0.4, "metal_in", 6)      # conveyor tail
	k.cyl(Vector3(0.9, 2.25, 2.0), 0.08, 0.9, "metal_in", 6)                        # exhaust
	# rivet gun on the right shoulder
	k.box(Vector3(1.0, 2.4, -1.4), Vector3(0.5, 0.3, 0.7), "metal_in")
	k.tube(Vector3(1.0, 2.4, -1.7), Vector3(1.0, 2.4, -2.5), 0.07, "steel_in", 6)
	root.add_child(k.node(false))
	# the core behind its grille
	var core := MeshKit.new()
	core.winter = true  # creatures keep their ice and frost in summer
	core.box(Vector3(0, 1.5, 2.96), Vector3(2.0, 1.0, 0.1), "black_in")
	core.sphere(Vector3(0, 1.5, 3.0), 0.42, "led_red", 10, 6)
	root.add_child(core.node(false))
	var hk := MeshKit.new()
	hk.winter = true  # creatures keep their ice and frost in summer
	hk.box(Vector3(0, 1.5, 3.04), Vector3(2.2, 1.1, 0.05), "metal_in")
	for i in 7:
		hk.box(Vector3(0, 1.05 + i * 0.15, 3.08), Vector3(2.1, 0.04, 0.05), "steel_in", Basis(Vector3.RIGHT, 0.5))
	_hatch = hk.node(false)
	root.add_child(_hatch)
	# boom and cutter drum
	_boom = Node3D.new()
	_boom.position = Vector3(0, 1.8, -1.6)
	root.add_child(_boom)
	var bk := MeshKit.new()
	bk.winter = true  # creatures keep their ice and frost in summer
	bk.tube(Vector3.ZERO, Vector3(0, 0.8, -3.0), 0.34, "paint_yellow_in", 8)
	for sx: float in [-0.5, 0.5]:
		bk.tube(Vector3(sx, -0.6, -0.1), Vector3(sx * 0.8, 0.4, -2.2), 0.07, "steel_in", 6)
	_boom.add_child(bk.node(false))
	_drum = Node3D.new()
	_drum.position = Vector3(0, 0.8, -3.3)
	_boom.add_child(_drum)
	var dk := MeshKit.new()
	dk.winter = true  # creatures keep their ice and frost in summer
	dk.tube(Vector3(-1.9, 0, 0), Vector3(1.9, 0, 0), 0.75, "rust_in", 14)
	for i in 40:
		var a := i * 0.83
		dk.cyl(Vector3(-1.8 + (i % 13) * 0.3, sin(a) * 0.72, cos(a) * 0.72), 0.06, 0.2, "steel_in", 4, 0.0)
	_drum.add_child(dk.node(false))
	# parts you can shoot off: two power cells and the sensor head
	for sx: float in [-1.0, 1.0]:
		var ck := MeshKit.new()
		ck.winter = true  # creatures keep their ice and frost in summer
		ck.bbox(Vector3(sx * 2.0, 1.55, 1.6), Vector3(0.28, 0.8, 1.2), 0.05, "metal_in")
		ck.box(Vector3(sx * 2.15, 1.55, 1.6), Vector3(0.03, 0.55, 0.9), "led_green")
		for z: float in [1.2, 2.0]:
			ck.tube(Vector3(sx * 2.0, 1.95, z), Vector3(sx * 1.3, 2.3, z), 0.04, "black_in", 5)
		var cell := ck.node(false)
		root.add_child(cell)
		add_part("cell_l" if sx < 0.0 else "cell_r", 150.0, cell, "left power cell" if sx < 0.0 else "right power cell")
	var sk := MeshKit.new()
	sk.winter = true  # creatures keep their ice and frost in summer
	sk.bbox(Vector3(0, 2.0, -1.9), Vector3(1.0, 0.45, 0.5), 0.06, "metal_in")
	sk.sphere(Vector3(0, 2.0, -2.16), 0.17, "led_red", 10, 6)
	for sx: float in [-0.8, 0.8]:
		sk.sphere(Vector3(sx, 2.05, -1.8), 0.16, "lamp_glow", 8, 5)
	var sensor := sk.node(false)
	root.add_child(sensor)
	add_part("sensor", 70.0, sensor, "sensor head")
	var lab := Label3D.new()
	lab.text = "K-9"
	lab.font_size = 96
	lab.pixel_size = 0.008
	lab.modulate = Color(0.06, 0.06, 0.06)
	lab.position = Vector3(1.32, 1.5, -0.4)
	lab.rotation.y = PI * 0.5
	root.add_child(lab)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.5)
	lamp.light_energy = 2.0
	lamp.omni_range = 14.0
	lamp.position = Vector3(0, 2.3, -3.0)
	root.add_child(lamp)
	_lamps.append(lamp)
	return root


func _in_chamber(p: Vector3) -> bool:
	return p.x > 577.5 and p.x < 607.0 and p.z > 121.0 and p.z < 159.0 and absf(p.y - home.y) < 6.0


func hear(_pos: Vector3, _reach: float) -> void:
	pass


func hit(dmg: float, pos: Vector3, dir: Vector3, pen: float, _shooter: Node) -> void:
	if state == "dead":
		return
	var l := to_local(pos)
	var blast := pen > 500.0
	var got := 0.0
	var region := ""
	if absf(l.x) > 1.4 and l.z > 0.7 and l.z < 2.5 and l.y > 0.8:
		region = "cell_l" if l.x < 0.0 else "cell_r"
	elif l.z < -1.9 and l.y > 1.5 and absf(l.x) < 0.8:
		region = "sensor"
	if blast:
		# an explosion: the whole machine takes it, and whatever is still bolted on
		got = dmg
		for p in ["cell_l", "cell_r", "sensor"]:
			hurt_part(p, dmg * 0.45, global_position + global_basis * Vector3(0, 1.5, 0))
	elif region != "" and part_alive(region):
		hurt_part(region, dmg, pos)
		got = dmg * 0.25
	elif phase >= 3 and l.z > 2.6:
		got = Damage.apply(dmg, 15.0, pen) * 2.4      # the open core
	else:
		got = Damage.apply(dmg, armor, pen)
	if state == "dead":
		return
	if mode == "vent":
		got *= 1.6
	Fx.sparks(get_parent(), pos, -dir)
	last_head = false
	last_damage = got
	health -= got
	if health <= 0.0:
		_die(dir)
	elif not passive and state != "fight":
		_wake()


func _part_broke(pname: String) -> void:
	if pname == "sensor":
		return
	health -= 150.0
	var cells := (1 if part_alive("cell_l") else 0) + (1 if part_alive("cell_r") else 0)
	phase = 3 - cells
	armor = 88.0 - 14.0 * (2 - cells)
	if phase == 2:
		boss_sub = "One cell down. Keep a pillar between you and the rivets."
	else:
		boss_sub = "The core is open at the back. It must stop to vent."
		_hatch.visible = false
	if health <= 0.0 and state != "dead":
		_die(Vector3.FORWARD)
	elif state != "dead":
		mode = "back"
		_t = 1.5


func _wake() -> void:
	state = "fight"
	mode = "grind"
	_t = 6.0
	Sfx.play(get_parent(), "clank", global_position, 8.0, 0.4)
	Sfx.play(get_parent(), "growl", global_position, 6.0, 0.3)
	if player:
		player.message.emit("Something in the dark turns over. K-9 is still running.")


func _next() -> void:
	_step += 1
	var plan: Array
	match phase:
		1:
			plan = [["grind", 6.0], ["back", 2.2]]
		2:
			plan = [["grind", 5.0], ["rivets", 3.6], ["magnet", 2.8], ["back", 1.8], ["drones", 1.4], ["rocks", 1.6]]
		_:
			plan = [["ram", 2.6], ["drones", 1.4], ["rivets", 3.0], ["magnet", 2.6], ["rocks", 1.6], ["vent", 3.4], ["grind", 3.5]]
	var pick: Array = plan[_step % plan.size()]
	mode = str(pick[0])
	_t = float(pick[1])
	_ram_hit = false
	_burst = 0
	if mode == "vent":
		Sfx.play(get_parent(), "growl", global_position, 4.0, 1.8)
		_steam_blast()
		if player:
			player.message.emit("K-9 overheats and vents. Now.")
	elif mode == "magnet":
		Sfx.play(get_parent(), "magnet", global_position, 8.0, 1.0)
		if player:
			player.message.emit("The drum's magnet hums. It is pulling you in — run!")
	elif mode == "drones":
		Sfx.play(get_parent(), "clank", global_position, 6.0, 1.3)
	elif mode == "ram":
		Sfx.play(get_parent(), "clank", global_position, 6.0, 0.5)


func _turn(dir: Vector3, delta: float, rate: float) -> float:
	var want := atan2(-dir.x, -dir.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -rate * delta, rate * delta)
	return absf(diff)


func _think(delta: float, dist: float) -> Vector3:
	_bite_cd -= delta
	_shot_cd -= delta
	if state != "fight":
		_boom_want = 0.0
		if _in_chamber(player.global_position) and (dist < 15.0 or (_sees and dist < 26.0)):
			_wake()
		return Vector3.ZERO
	if not _in_chamber(player.global_position):
		# you left: it settles down again and the breakers reset a little
		_steam += delta
		if _steam > 8.0:
			_steam = 0.0
			state = "idle"
			mode = "sleep"
			health = minf(max_health, health + 60.0)
		_boom_want = 0.0
		return Vector3.ZERO
	_steam = 0.0
	var to := _flat_to(player.global_position)
	var dir := to.normalized() if to.length() > 0.01 else -global_basis.z
	var fwd := -global_basis.z
	var blind := not part_alive("sensor")
	var rate := (0.75 + 0.2 * phase) * (0.6 if blind else 1.0)
	_t -= delta
	_bite(to.length())
	match mode:
		"grind":
			_boom_want = -0.48
			var off := _turn(dir, delta, rate)
			if _t <= 0.0:
				_next()
			return fwd * (2.2 + 0.7 * phase) if off < 0.6 else Vector3.ZERO
		"back":
			_boom_want = 0.0
			_turn(dir, delta, rate)
			if _t <= 0.0:
				_next()
			var c := Vector3(LANE.get_center().x, global_position.y, LANE.get_center().y)
			var home_dir := _flat_to(c)
			return home_dir.normalized() * 2.4 if home_dir.length() > 1.0 else Vector3.ZERO
		"rivets":
			_boom_want = 0.15
			var off2 := _turn(dir, delta, rate * 1.3)
			if off2 < 0.5 and _shot_cd <= 0.0 and _sees:
				_rivet(blind)
				_burst += 1
				_shot_cd = 0.14 if _burst % 6 != 0 else 0.9
			if _t <= 0.0:
				_next()
			return Vector3.ZERO
		"rocks":
			_boom_want = 0.62
			if randf() < delta * 14.0:
				Fx.sparks(get_parent(), _drum.global_position + Vector3(randf_range(-1.5, 1.5), 0.7, 0), Vector3.DOWN)
			if _t <= 0.0:
				_rocks()
				_next()
			return Vector3.ZERO
		"vent":
			_boom_want = -0.2
			if randf() < delta * 10.0:
				Fx.sparks(get_parent(), global_position + global_basis * Vector3(randf_range(-1.0, 1.0), 2.4, 2.6), Vector3.UP)
			if _t <= 0.0:
				_next()
			return Vector3.ZERO
		"magnet":
			# the drum comes down and its magnet drags you towards the teeth
			_boom_want = -0.48
			_turn(dir, delta, rate * 0.6)
			var dp := _drum.global_position
			var pull := Vector3(dp.x - player.global_position.x, 0, dp.z - player.global_position.z)
			if pull.length() < 24.0 and pull.length() > 1.2:
				player.move_and_collide(pull.normalized() * (3.4 + 0.5 * phase) * delta)
				if randf() < delta * 12.0:
					Fx.sparks(get_parent(), player.global_position + Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)), -pull.normalized())
				player.shake(0.15)
			if _t <= 0.0:
				_next()
			return Vector3.ZERO
		"drones":
			_boom_want = 0.3
			if _t <= 0.0:
				var n := 2 if phase == 2 else 3
				for i in n:
					var side := global_basis.x * (i - (n - 1) * 0.5) * 1.6
					MineDrone.launch(get_parent(), global_position - global_basis.z * 3.2 + side, player, global_position.y)
					drones_made += 1
				if player:
					player.message.emit("K-9 drops mine drones. Shoot them before they reach you.")
				_next()
			return Vector3.ZERO
		"ram":
			_boom_want = -0.3
			if _t > 1.7:      # winding up: it lines up on you
				_turn(dir, delta, rate * 1.6)
				return -fwd * 0.8
			if not _ram_hit and to.length() < 4.6 and fwd.dot(dir) > 0.6:
				_ram_hit = true
				player.stats.hurt(30.0, 0.5, "K-9", 25.0)
				player.velocity += fwd * 10.0 + Vector3(0, 4.0, 0)
				player.shake(2.0)
				player.hurt_marks.append([global_position, 1.6])
				Sfx.play(get_parent(), "thud", player.global_position, 6.0, 0.6)
			if _t <= 0.0:
				_next()
			return fwd * 8.5
	return Vector3.ZERO


## Overheating: a blast of steam out of every vent that throws you back.
func _steam_blast() -> void:
	Sfx.play(get_parent(), "steam", global_position + Vector3(0, 2, 0), 10.0, 0.7)
	for i in 10:
		Fx.sparks(get_parent(), global_position + global_basis * Vector3(randf_range(-1.5, 1.5), 2.2, randf_range(-2.5, 2.5)), Vector3.UP)
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() < 7.5:
		var k := 1.0 - to.length() / 7.5
		player.stats.hurt(14.0 * k + 4.0, 0.0, "K-9's steam")
		player.velocity += to.normalized() * 11.0 * k + Vector3(0, 3.0, 0)
		player.shake(1.4)
		player.rumble(0.8, 0.6, 0.4)
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.get("post") and to.length() < 14.0:
		main_node.post.flash(Color(0.9, 0.93, 0.95), 0.5)


## The drum: stand in it and it eats you.
func _bite(_d: float) -> void:
	if _bite_cd > 0.0 or _boom.rotation.x > -0.2:
		return
	var dp := _drum.global_position
	var pp := player.global_position + Vector3(0, 0.9, 0)
	var local := global_basis.inverse() * (pp - dp)
	if absf(local.x) < 2.1 and Vector2(local.y, local.z).length() < 1.5:
		_bite_cd = 0.4
		player.stats.hurt(15.0, 0.5, "the cutter drum", 30.0)
		player.velocity += -global_basis.z * 4.0 + Vector3(0, 2.0, 0)
		player.shake(1.4)
		player.hurt_marks.append([dp, 1.6])
		Sfx.play(get_parent(), "clank", dp, 2.0, 1.4)


func _rivet(blind: bool) -> void:
	if bullets == null:
		return
	var from := global_position + global_basis * Vector3(1.0, 2.4, -2.7)
	var target := player.camera.global_position - Vector3(0, 0.35, 0)
	var err := deg_to_rad(5.5 if blind else 2.4)
	var aim := (target - from).normalized()
	var right := aim.cross(Vector3.UP).normalized()
	var up := right.cross(aim)
	var dir := (aim + right * randfn(0.0, err) + up * randfn(0.0, err)).normalized()
	bullets.fire(from, dir * 140.0, 8.0, 15.0, self)
	Sfx.play(get_parent(), "shot_small", from, 2.0, 0.7)


## The drum bites into the roof and pieces of it come down where you stand.
func _rocks() -> void:
	Sfx.play(get_parent(), "shot_boom", _drum.global_position, 4.0, 0.4)
	player.shake(0.8)
	var n := 3 + phase
	for i in n:
		var p := player.global_position
		if i > 0:
			p += Vector3(randf_range(-6.0, 6.0), 0, randf_range(-6.0, 6.0))
		p.x = clampf(p.x, 579.0, 605.5)
		p.z = clampf(p.z, 123.0, 157.0)
		p.y = home.y
		var r := Rockfall.new()
		r.player = player
		get_parent().add_child(r)
		r.global_position = p
		rocks_made += 1


func _physics_process(delta: float) -> void:
	if state == "dead" or player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > 120.0 and state == "idle":
		return
	_see_cd -= delta
	if _see_cd <= 0.0:
		_see_cd = 0.15
		_sees = not passive and _can_see(dist)
	var want := Vector3.ZERO
	if not passive:
		want = _think(delta, dist)
	velocity.x = move_toward(velocity.x, want.x, 9.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 9.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# tracks, not legs: it stays in its lane
	global_position.x = clampf(global_position.x, LANE.position.x, LANE.end.x)
	global_position.z = clampf(global_position.z, LANE.position.y, LANE.end.y)
	_boom.rotation.x = move_toward(_boom.rotation.x, _boom_want, delta * 0.9)
	if state == "fight":
		_drum.rotation.x -= delta * (9.0 if mode in ["grind", "rocks", "ram"] else 3.0)


func _fall(_dir: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(_boom, "rotation:x", -0.62, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model, "rotation:z", 0.05, 0.8)
	_dark()


func _dark() -> void:
	for l in _lamps:
		l.visible = false
	_hatch.visible = false


func _die(dir: Vector3) -> void:
	var at := global_position + Vector3(0, 1.6, 0)
	super._die(dir)
	collision_layer = 1      # the wreck stays where it is
	Sfx.play(get_parent(), "shot_boom", at, 8.0, 0.45)
	for i in 12:
		Fx.sparks(get_parent(), at + Vector3(randf_range(-1.8, 1.8), randf_range(-0.5, 1.2), randf_range(-2.5, 2.5)), Vector3.UP)


func make_dead() -> void:
	super.make_dead()
	collision_layer = 1


func _lie_dead() -> void:
	_boom.rotation.x = -0.62
	model.rotation.z = 0.05
	_dark()
	for p in parts:
		var n: Node3D = parts[p]["node"]
		n.visible = false
		parts[p]["hp"] = 0.0
