class_name Npc
extends CharacterBody3D
## A friendly person: stands, sits or wanders near home, turns to you when you
## come close, talks when you press E, and takes cover when shots are fired.

var id := ""
var player: Player
var npc_name := "Villager"
var lines: Array = []
var gift := {}              # handed over the first time you talk
var home := Vector3.ZERO
var roam := 0.0             # how far they wander; 0 = stay put
var pose := "stand"         # stand / sit / work
var talked := 0
var faction := "village"
var town: TownScreen
var factions: Factions
var model: Node3D
var prompt: String:
	get:
		return "Talk to " + npc_name

var _phase := 0.0
var _t := 0.0
var _wander := Vector3.INF
var _wander_t := 0.0
var _scared := 0.0
var _scan := 0.0
var _yaw0 := 0.0
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _arm_l: Node3D
var _arm_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _head: Node3D
var _torso: Node3D
var _speed := 0.0            # current walking speed along the facing
var _stroll := 1.25          # their own walking pace
var _yaw_rate := 0.0
var _stuck_t := 0.0
var _facing := false         # turning round to face you
var _talk_t := 0.0           # talking: the hands move, the head nods
var _gesture := ""
var _gesture_t := 0.0
var _glance := 0.0
var _glance_t := 0.0
var _attend := true
# townsfolk can be killed; the valley fills up again after a while
var health := 70.0
var dead := false
var weapon_id := ""
var respawn_t := 0.0           # seconds until this person (or a new one) is back
var _home_yaw := 0.0
const RESPAWN := 360.0         # six minutes, plus a little luck: not fast enough to farm
const POCKETS := ["canned_food", "bandage", "hot_tea", "cloth", "batteries", "painkillers", "hand_warmer", "firewood", "scrap"]


func setup(look: Dictionary, weapon := "") -> void:
	add_to_group("npc")
	collision_mask = 3
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.4
	look = Humanoid.vary(look, hash(str(look)))
	model = Humanoid.build(look)
	Humanoid.fit(model, look)
	add_child(model)
	_legs = [model.get_meta("leg_l"), model.get_meta("leg_r")]
	_knees = [model.get_meta("knee_l"), model.get_meta("knee_r")]
	_arm_l = model.get_meta("arm_l")
	_arm_r = model.get_meta("arm_r")
	_el_l = model.get_meta("elbow_l")
	_el_r = model.get_meta("elbow_r")
	_head = model.get_meta("head")
	_torso = model.get_meta("torso")
	_t = randf() * 10.0
	# old people walk slower, everyone a little differently
	_stroll = (0.95 if str(look.get("hair", "")) in ["white", "grey"] else 1.25) * randf_range(0.9, 1.1)
	_gesture_t = randf_range(0.5, 6.0)
	weapon_id = weapon
	if weapon != "":
		var wm := Weapons.model(weapon, [])
		wm.rotation.x = -PI * 0.5
		(model.get_meta("hand_r") as Node3D).add_child(wm)


func place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	home = pos
	rotation.y = yaw
	_yaw0 = yaw
	_home_yaw = yaw


func interact(who: Node3D) -> void:
	if dead or lines.is_empty():
		return
	if factions and faction != "" and factions.hostile(faction):
		who.message.emit("%s:  I have nothing to say to you. Go." % npc_name.to_upper())
		return
	var text := str(lines[mini(talked, lines.size() - 1)]) if talked < lines.size() else str(lines[lines.size() - 1 - (talked % 2)])
	if talked == 0 and not gift.is_empty():
		var names: Array[String] = []
		for g in gift:
			who.inv.add(str(g), int(gift[g]))
			names.append(Items.name_of(str(g)) + (" ×%d" % int(gift[g]) if int(gift[g]) > 1 else ""))
		text += "   (+ " + ", ".join(names) + ")"
	talked += 1
	_talk_t = 2.5 + text.length() * 0.045
	Sfx.play(get_parent(), "click", global_position, -10.0, 1.4)
	if town and who == player and town.has_business(self):
		town.open_talk(self, text)
		return
	who.message.emit("%s:  %s" % [npc_name.to_upper(), text])


## People do not fight back: they duck and run home.
func hit(dmg: float, pos: Vector3, dir: Vector3, pen: float, shooter: Node) -> void:
	if dead:
		return
	_scared = 14.0
	var head := pos.y - global_position.y > 1.5
	health -= Damage.apply(dmg, 0.0, pen) * (Damage.HEAD if head else 1.0)
	Fx.blood(get_parent(), pos, dir, head)
	if model:
		model.rotation.z = randf_range(-0.25, 0.25)   # flinch
	if shooter == player and player:
		if factions and faction != "":
			factions.add(faction, -12)
		if health > 0.0:
			player.message.emit("%s:  Stop it! Are you out of your mind?" % npc_name.to_upper())
	if health <= 0.0:
		_die(dir, shooter)


## Down for good (for now): the body falls, and whatever was in the pockets can be searched.
func _die(dir: Vector3, shooter: Node) -> void:
	dead = true
	health = 0.0
	set_meta("alive_layer", collision_layer)
	collision_layer = 0
	velocity = Vector3.ZERO
	_talk_t = 0.0
	respawn_t = RESPAWN + randf_range(0.0, 180.0)
	Sfx.play(get_parent(), "thud", global_position, 2.0, 0.75)
	Fx.bleed(self, 3.0, 0.9)
	get_tree().create_timer(0.6).timeout.connect(func() -> void: if is_instance_valid(self): Fx.pool(get_parent(), global_position))
	if model:
		var tw := create_tween()
		var back := 1.0 if (-global_basis.z).dot(dir) < 0.0 else -1.0
		tw.tween_property(model, "rotation:x", back * PI * 0.48, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(model, "position:y", 0.14, 0.5)
	# what they carried: a little money and everyday things; a gun only if they had one
	var bag := LootBox.new()
	bag.setup(true)
	bag.title = npc_name
	bag.prompt = "Search " + npc_name
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	bag.items["coin"] = rng.randi_range(3, 18)
	for i in rng.randi_range(1, 3):
		var it: String = POCKETS[rng.randi() % POCKETS.size()]
		bag.items[it] = int(bag.items.get(it, 0)) + 1
	if weapon_id != "":
		bag.items[weapon_id] = 1
		if Weapons.is_gun(weapon_id):
			bag.items[str(Weapons.GUNS[weapon_id]["cal"])] = rng.randi_range(6, 14)
	get_parent().get_parent().add_child(bag)
	var side := global_basis.x * 0.7
	bag.global_position = global_position + Vector3(side.x, 0.05, side.z)
	if shooter == player and player:
		player.message.emit("%s is dead. The village will not forget this." % npc_name)
		if factions:
			factions.add("village", -20)
			if faction != "village":
				factions.add(faction, -20)
	# the rest of the village runs
	for n in get_tree().get_nodes_in_group("npc"):
		var o := n as Npc
		if o and o != self and o.global_position.distance_to(global_position) < 40.0:
			o._scared = maxf(o._scared, 20.0)


## Back on their feet at home: called by People when nobody is looking.
func revive() -> void:
	dead = false
	health = 70.0
	_scared = 0.0
	collision_layer = int(get_meta("alive_layer", 1))
	if model:
		model.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = home
	rotation.y = _home_yaw
	_yaw0 = _home_yaw


func hear(_pos: Vector3, _reach: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if dead:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > 70.0:
		return
	_t += delta
	_scared = maxf(_scared - delta, 0.0)
	_talk_t = maxf(_talk_t - delta, 0.0)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		for n in get_tree().get_nodes_in_group("enemy"):
			var e: Node3D = n
			if str(e.get("state")) == "fight" and e.global_position.distance_to(global_position) < 45.0:
				_scared = maxf(_scared, 6.0)
	var speed := 0.0          # how fast they want to go, along where they face
	var seated := pose == "sit" and _scared <= 0.0
	var yaw_before := rotation.y
	if _scared > 0.0:
		var d := home - global_position
		d.y = 0.0
		if d.length() > 1.2:
			speed = _steer(d, 4.0, 5.0, delta) * clampf(d.length() / 1.5, 0.35, 1.0)
	elif roam > 0.0 and dist > 3.2 and _talk_t <= 0.0:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(5.0, 14.0)
			_wander = home + Vector3(randf_range(-roam, roam), 0, randf_range(-roam, roam)) if randf() < 0.6 else Vector3.INF
			_stuck_t = 0.0
		if _wander != Vector3.INF:
			var d := _wander - global_position
			d.y = 0.0
			if d.length() > 0.6:
				# a stroll: they ease in, and slow down as they arrive
				speed = _steer(d, _stroll, 2.4, delta) * clampf(d.length() / 1.4, 0.3, 1.0)
			else:
				_wander = Vector3.INF
	elif not seated and pose != "work" and (dist < 4.5 or _talk_t > 0.0):
		# the eyes and head follow you; the body only turns when you get round to their side
		var to := player.global_position - global_position
		var off := absf(wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI))
		if off > 0.75 or _facing:
			_facing = off > 0.12
			_steer(to, 0.0, 2.2, delta)
	elif not seated and roam <= 0.0:
		var off := wrapf(_yaw0 - rotation.y, -PI, PI)
		if absf(off) > 0.05:
			rotation.y += clampf(off, -1.4 * delta, 1.4 * delta)
	# feet on the ground: speed builds up over a few steps and runs out the same way
	var accel := 2.2 if speed > _speed else 3.2
	if _scared > 0.0:
		accel *= 2.5
	_speed = move_toward(_speed, speed, accel * delta)
	var fwd := -global_basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	_yaw_rate = lerpf(_yaw_rate, absf(wrapf(rotation.y - yaw_before, -PI, PI)) / maxf(delta, 0.001), minf(delta * 10.0, 1.0))
	if not seated:
		if not is_on_floor():
			velocity.y -= 14.0 * delta
		var before := global_position
		move_and_slide()
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
		# walking into a wall: give up on that spot
		if speed > 0.3 and moved < 0.15:
			_stuck_t += delta
			if _stuck_t > 1.2:
				_wander = Vector3.INF
				_wander_t = randf_range(1.5, 3.0)
				_stuck_t = 0.0
		else:
			_stuck_t = 0.0
		var g := Humanoid.gait(moved)
		# turning on the spot is a few small steps, not a glide
		if moved < 0.3 and _yaw_rate > 0.4:
			g = Vector2(minf(_yaw_rate, 2.5) * 2.2, 0.16)
		_phase += g.x * delta
		_animate(delta, moved, g.y, dist)
	else:
		_animate(delta, 0.0, 0.0, dist)


## Turns towards dir at most `rate` rad/s, easing in near the end. Returns the speed that
## fits how well they face it: a person turns first and then walks, never sideways.
func _steer(dir: Vector3, speed: float, rate: float, delta: float) -> float:
	if dir.length_squared() < 0.0001:
		return 0.0
	var diff := wrapf(atan2(-dir.x, -dir.z) - rotation.y, -PI, PI)
	var step := rate * delta * clampf(absf(diff) / 0.6, 0.3, 1.0)
	rotation.y += clampf(diff, -step, step)
	return speed * clampf(1.0 - (absf(diff) - 0.35) / 1.0, 0.0, 1.0)


func _turn(dir: Vector3, delta: float) -> void:
	_steer(dir, 0.0, 3.0, delta)


func _animate(delta: float, moved: float, amt: float, dist: float) -> void:
	var k := minf(delta * 8.0, 1.0)
	var soft := minf(delta * 3.0, 1.0)
	# where they look: you, while you are close (now and then they look away), else a glance around
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(1.5, 5.0)
		_glance = randf_range(-0.8, 0.8) if randf() < 0.45 else 0.0
		_attend = randf() < 0.75
	var look := _glance * (1.0 if amt < 0.05 else 0.35)
	var pitch := 0.0
	if (dist < 3.5 or _talk_t > 0.0) or (dist < 7.0 and _attend):
		var to := to_local(player.global_position)
		look = atan2(-to.x, -to.z)
		pitch = atan2(player.global_position.y + 1.6 - (global_position.y + 1.62), Vector2(to.x, to.z).length())
	# the neck takes up to 65 degrees, the shoulders turn for the rest
	var neck := clampf(look, -1.15, 1.15)
	_head.rotation.y = lerp_angle(_head.rotation.y, neck, soft * 1.6)
	_head.rotation.x = lerpf(_head.rotation.x, clampf(pitch, -0.45, 0.35) + (sin(_t * 5.2) * 0.04 if _talk_t > 0.0 else 0.0), soft)
	var twist := clampf((look - neck) * 0.6, -0.45, 0.45) if absf(look) < 2.4 else 0.0
	if pose == "sit" and _scared <= 0.0:
		model.position.y = lerpf(model.position.y, -0.4, k)
		for i in 2:
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, 1.5, k)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -1.5, k)
		var talk := _talk_t > 0.0
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(0.75 + sin(_t * 2.7) * 0.15, 0.25, 0.1) if talk else Vector3(0.55, 0, 0.1), k)
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(0.55 + sin(_t * 0.7) * 0.04, 0, -0.1), k)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, 1.3 + sin(_t * 3.4) * 0.2 if talk else 0.9, k)
		_el_l.rotation.x = lerpf(_el_l.rotation.x, 0.9, k)
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.06 + sin(_t * 1.3) * 0.015, k)
		_torso.rotation.y = lerpf(_torso.rotation.y, twist, soft)
		return
	model.position.y = lerpf(model.position.y, -0.22 if (_scared > 0.0 and amt < 0.1) else 0.0, k)
	if _scared > 0.0 and amt < 0.1:
		# crouch with the arms over the head
		for i in 2:
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, 1.0, k)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -1.8, k)
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(2.6, 0, 0.5), k)
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(2.6, 0, -0.5), k)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, 1.6, k)
		_el_l.rotation.x = lerpf(_el_l.rotation.x, 1.6, k)
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.5, k)
		return
	var idle := amt < 0.05
	var busy := pose == "work" and idle
	Humanoid.walk(model, _phase, amt, not busy and not (idle and _gesture != ""))
	if idle:
		Humanoid.breathe(model, _t)
		_torso.rotation.y = lerpf(_torso.rotation.y, twist, soft)
	else:
		# lean into the walk, more when running
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.03 + clampf((moved - 1.8) * 0.06, 0.0, 0.17), k)
		_gesture = ""
	if busy:
		# busy hands
		_arm_r.rotation = _arm_r.rotation.lerp(Vector3(1.0 + sin(_t * 3.1) * 0.12, 0, 0.1), k)
		_arm_l.rotation = _arm_l.rotation.lerp(Vector3(0.95 + sin(_t * 2.3 + 1.0) * 0.1, 0, -0.1), k)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, 0.8 + sin(_t * 3.1) * 0.2, k)
		_el_l.rotation.x = lerpf(_el_l.rotation.x, 0.9, k)
		_torso.rotation.x = lerpf(_torso.rotation.x, 0.12, k)
		return
	if idle:
		_idle(delta, soft)


## Standing about in the cold: talking with the hands, arms folded, rubbing the hands
## warm, stamping the feet, resting the weight on one leg.
func _idle(delta: float, soft: float) -> void:
	_gesture_t -= delta
	if _talk_t > 0.0:
		_gesture = "talk"
	elif _gesture_t <= 0.0 or _gesture == "talk":
		_gesture_t = randf_range(3.0, 8.0)
		_gesture = ["", "", "fold", "rub", "stamp", "hip", "fold"][randi() % 7]
	var ar := Vector3(0.0, 0.0, 0.07)
	var al := Vector3(0.0, 0.0, -0.07)
	var er := 0.25
	var el := 0.25
	match _gesture:
		"talk":
			# one hand explains, now and then both
			var both := sin(_t * 0.9) > 0.3
			ar = Vector3(0.55 + sin(_t * 2.6) * 0.18, 0.3, 0.05)
			er = 1.15 + sin(_t * 3.7 + 0.5) * 0.25
			if both:
				al = Vector3(0.45 + sin(_t * 2.2 + 1.3) * 0.12, -0.3, -0.05)
				el = 1.0 + sin(_t * 3.1) * 0.2
		"fold":
			ar = Vector3(0.38, 0.75, 0.0)
			al = Vector3(0.42, -0.75, 0.0)
			er = 1.75
			el = 1.85
		"rub":
			var r := sin(_t * 11.0) * 0.06
			ar = Vector3(0.62 + r, 0.55, 0.0)
			al = Vector3(0.62 - r, -0.55, 0.0)
			er = 1.35
			el = 1.35
		"stamp":
			var i := int(_t * 2.6) % 2
			var lift := maxf(sin(_t * 2.6 * PI), 0.0) * 0.35
			_legs[i].rotation.x = lerpf(_legs[i].rotation.x, lift, soft * 3.0)
			_knees[i].rotation.x = lerpf(_knees[i].rotation.x, -lift * 1.6, soft * 3.0)
			ar = Vector3(0.3, 0.6, 0.0)
			al = Vector3(0.3, -0.6, 0.0)
			er = 1.6
			el = 1.6
		"hip":
			# weight on the left leg, the right knee loose
			_knees[1].rotation.x = lerpf(_knees[1].rotation.x, -0.22, soft)
			_legs[1].rotation.x = lerpf(_legs[1].rotation.x, 0.08, soft)
			model.rotation.z = lerpf(model.rotation.z, 0.025, soft)
	if _gesture != "hip":
		model.rotation.z = lerpf(model.rotation.z, 0.0, soft)
	_arm_r.rotation = _arm_r.rotation.lerp(ar, soft)
	_arm_l.rotation = _arm_l.rotation.lerp(al, soft)
	_el_r.rotation.x = lerpf(_el_r.rotation.x, er, soft)
	_el_l.rotation.x = lerpf(_el_l.rotation.x, el, soft)
