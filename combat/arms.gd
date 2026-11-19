class_name Arms
extends Node3D
## The weapon in the player's hands: shooting, aiming, recoil, reloading, mods,
## ammo types, and melee (light / heavy blows, combos, block, parry, counter, dodge).

const ORDER := ["pistol", "revolver", "smg", "assault_rifle", "shotgun", "marksman_rifle", "sniper_rifle", "flare_gun", "knife", "ice_pick", "axe", "sword"]
const BASE_FOV := 74.0

var player: Player
var held := ""
var state := {}          # weapon id -> {"mods": [], "loaded": int, "ammo": String}
var aim := 0.0           # 0 = hip, 1 = fully aimed
var blocking := false
var reloading := 0.0     # seconds left
var hit_flash := 0.0     # for the HUD hit marker
var scoped := false
var free_input := false  # tests: act without a captured mouse
var last_melee := ""     # result of the last blow taken (tests)

var _model: Node3D
var _g := {}             # stats of the held gun with mods
var _cd := 0.0
var _bloom := 0.0
var _kick := 0.0
var _flash: OmniLight3D
var _fire_was := false
# melee
var _hold := -1.0        # how long the attack button has been held (-1 = not held)
var _atk := 0.0          # seconds until the blow lands
var _atk_len := 0.0
var _atk_mult := 1.0
var _atk_heavy := false
var _recover := 0.0
var _combo := 0
var _combo_t := 0.0
var _block_t := 0.0
var _counter := 0.0
var _dodge_cd := 0.0
var _side := 1.0
var _t := 0.0
var _hand_l: Node3D
var _support := Vector3.ZERO
var _sprint := 0.0
var _draw := 0.0


func _ready() -> void:
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.4)
	_flash.omni_range = 9.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0.1, -0.05, -0.9)
	add_child(_flash)
	# a faint fill light so the weapon in your hands is never just a black shape
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.light_energy = 0.55
	fill.omni_range = 1.3
	fill.omni_attenuation = 0.6
	fill.position = Vector3(-0.1, 0.25, -0.05)
	fill.light_specular = 0.3
	add_child(fill)
	player.inv.changed.connect(_check_held)


# ------------------------------------------------------------ weapons
func weapons() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if player.inv.count(id) > 0:
			out.append(id)
	return out


func st(id: String) -> Dictionary:
	if not state.has(id):
		state[id] = {"mods": [], "loaded": 0, "ammo": str(Weapons.GUNS[id]["cal"]) if Weapons.is_gun(id) else ""}
	return state[id]


func is_gun() -> bool:
	return Weapons.is_gun(held)


func is_melee() -> bool:
	return Weapons.is_melee(held)


func hold(id: String) -> void:
	if id != "" and player.inv.count(id) == 0:
		return
	held = id
	reloading = 0.0
	_atk = 0.0
	_hold = -1.0
	blocking = false
	_rebuild()
	_draw = 1.0
	if id != "":
		Sfx.play(player.get_parent(), "reload", player.global_position, -14.0, 1.4)


func _check_held() -> void:
	if held != "" and player.inv.count(held) == 0:
		hold("")


func _rebuild() -> void:
	if _model:
		_model.queue_free()
		_model = null
	_g = {}
	if held == "":
		return
	var mods: Array = st(held)["mods"]
	_model = Weapons.model(held, mods)
	add_child(_model)
	_hand_l = null
	var sleeve := "olive_in"
	match str(player.inv.equipped.get("body", "")):
		"parka":
			sleeve = "navy_in"
		"expedition_suit":
			sleeve = "orange_in"
	if is_gun():
		_g = Weapons.stats(held, mods)
		_ammo_fx()
		_model.add_child(_hand(Vector3(0.0, -0.045, 0.024), Vector3(0.15, -0.2, 0.44), sleeve, false))
		_support = _model.get_meta("support")
		_hand_l = _hand(Vector3.ZERO, Vector3(-0.27, -0.3, 0.26) if _support.z < -0.1 else Vector3(-0.2, -0.24, 0.34), sleeve, true)
		_hand_l.position = _support
		_model.add_child(_hand_l)
	else:
		_model.add_child(_hand(Vector3.ZERO, Vector3(0.06, -0.34, 0.24), sleeve, false, true))
	for c in _model.get_children():
		for m in c.get_children():
			if m is MeshInstance3D:
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A gloved hand with fingers and thumb, a knitted cuff and the forearm in its sleeve.
func _hand(at: Vector3, elbow: Vector3, sleeve: String, left: bool, upright := false) -> Node3D:
	var k := MeshKit.new()
	var glove := "glove_in"
	var sx := 1.0 if left else -1.0     # which side the thumb is on
	if upright:
		# fist around an upright handle
		k.ball(at, Vector3(0.036, 0.046, 0.04), glove, 10, 6)
		for i in 4:
			k.capsule(at + Vector3(-0.03, 0.03 - i * 0.02, -0.022), at + Vector3(0.028, 0.03 - i * 0.02, -0.03), 0.0105, glove, 6)
		k.capsule(at + Vector3(0.02, 0.04, 0.0), at + Vector3(-0.012, 0.05, -0.028), 0.012, glove, 6)
	elif left and _support.z > -0.1:
		# second hand wrapped round the first on a pistol grip
		k.ball(at + Vector3(-0.012, 0.0, 0.01), Vector3(0.03, 0.046, 0.04), glove, 10, 6)
		for i in 3:
			k.capsule(at + Vector3(-0.03, 0.02 - i * 0.021, -0.022), at + Vector3(0.05, 0.02 - i * 0.021, -0.034), 0.0105, glove, 6)
		k.capsule(at + Vector3(-0.02, 0.045, 0.0), at + Vector3(-0.008, 0.062, -0.05), 0.011, glove, 6)
	elif left:
		# open hand cupping the fore-end from below
		k.ball(at + Vector3(0, -0.028, 0.0), Vector3(0.04, 0.024, 0.05), glove, 10, 6)
		for i in 4:
			k.capsule(at + Vector3(0.03, -0.02, -0.035 + i * 0.022), at + Vector3(0.034, 0.02, -0.035 + i * 0.022), 0.0105, glove, 6)
		k.capsule(at + Vector3(-0.03, -0.02, -0.01), at + Vector3(-0.034, 0.018, -0.03), 0.012, glove, 6)
	else:
		# hand closed round a pistol grip, index finger towards the trigger
		k.ball(at + Vector3(0, 0, 0.012), Vector3(0.034, 0.05, 0.04), glove, 10, 6)
		for i in 3:
			k.capsule(at + Vector3(0.026, -0.005 - i * 0.021, -0.02), at + Vector3(-0.022, -0.005 - i * 0.021, -0.032), 0.0105, glove, 6)
		k.capsule(at + Vector3(0.024, 0.03, -0.01), at + Vector3(0.012, 0.038, -0.06), 0.0098, glove, 6)
		k.capsule(at + Vector3(-0.026, 0.035, 0.0), at + Vector3(-0.024, 0.045, -0.04), 0.0115, glove, 6)
	var dir := elbow.normalized()
	var wrist := at + dir * 0.055
	# glove gauntlet with a strap, knitted cuff, then the padded sleeve with a cuff tab
	k.tube(at + dir * 0.02, wrist + dir * 0.012, 0.034, glove, 12, 0.039)
	k.tube(wrist - dir * 0.006, wrist + dir * 0.006, 0.0405, "kevlar_in", 12)
	k.tube(wrist + dir * 0.012, wrist + dir * 0.05, 0.036, "black_in", 12, 0.04)
	for i in 4:
		k.tube(wrist + dir * (0.014 + i * 0.009), wrist + dir * (0.019 + i * 0.009), 0.0405, "wool_white_in" if i == 1 else "kevlar_in", 12)
	var coat := sleeve.trim_suffix("_in") + "_coat_in"
	k.tube(wrist + dir * 0.045, wrist + dir * 0.062, 0.047, coat, 14, 0.049)
	k.capsule(wrist + dir * 0.055, at + elbow, 0.046, coat, 14, 0.062)
	k.capsule(at + elbow, at + elbow + (dir + Vector3(0, -0.5, 0.6)).normalized() * 0.3, 0.064, coat, 14, 0.075)
	if sx == 0.0:
		return null
	return k.node(false)


func _ammo_fx() -> void:
	var a := Items.get_item(str(st(held)["ammo"]))
	_g["pen"] = float(a.get("pen", 0.0))
	_g["dmg"] = float(Weapons.GUNS[held]["dmg"]) * float(a.get("dmg", 1.0))
	if str(st(held)["ammo"]) == "12g_slug":
		_g["pellets"] = 1
		_g["dmg"] = 75.0
		_g["spread"] = 0.8
	elif Weapons.GUNS[held].has("pellets"):
		_g["pellets"] = int(Weapons.GUNS[held]["pellets"])
		_g["spread"] = float(Weapons.GUNS[held]["spread"])


func cycle(dir: int) -> void:
	var w := weapons()
	if w.is_empty():
		return
	var i := w.find(held)
	hold(w[posmod(i + dir, w.size())] if i >= 0 else w[0])


func slot(n: int) -> void:
	var w := weapons()
	if n < w.size():
		hold("" if held == w[n] else w[n])


## Fits a mod from the inventory to the held gun. Returns a message.
func attach(mod: String) -> String:
	if not is_gun():
		return "Hold a gun first."
	var kind := str(Items.get_item(mod).get("mod", ""))
	if not kind in (Weapons.GUNS[held]["mods"] as Array):
		return "%s does not fit the %s." % [Items.name_of(mod), Items.name_of(held)]
	var mods: Array = st(held)["mods"]
	for old in mods.duplicate():
		if str(Items.get_item(str(old)).get("mod", "")) == kind:
			mods.erase(old)
			player.inv.add(str(old))
	if not player.inv.remove(mod):
		return ""
	mods.append(mod)
	_after_mods()
	return "%s fitted." % Items.name_of(mod)


func detach(mod: String) -> void:
	if held == "":
		return
	var mods: Array = st(held)["mods"]
	if mod in mods:
		mods.erase(mod)
		player.inv.add(mod)
		_after_mods()


func _after_mods() -> void:
	_rebuild()
	var s := st(held)
	var extra := int(s["loaded"]) - int(_g["mag"])
	if extra > 0:   # smaller magazine now: spare rounds go back
		s["loaded"] = int(_g["mag"])
		player.inv.add(str(s["ammo"]), extra)


func ammo_types() -> Array[String]:
	var out: Array[String] = []
	if is_gun():
		var cal := str(Weapons.GUNS[held]["cal"])
		for id in [cal, cal + "_ap", cal + "_slug"]:
			if Items.DB.has(id):
				out.append(id)
	return out


func cycle_ammo() -> void:
	var types := ammo_types()
	if types.size() < 2:
		return
	var s := st(held)
	var i := types.find(str(s["ammo"]))
	for step in range(1, types.size()):
		var next := types[(i + step) % types.size()]
		if player.inv.count(next) > 0:
			if int(s["loaded"]) > 0:
				player.inv.add(str(s["ammo"]), int(s["loaded"]))
			s["loaded"] = 0
			s["ammo"] = next
			_ammo_fx()
			player.message.emit("Loading %s." % Items.name_of(next))
			reload()
			return
	player.message.emit("No other ammunition for this gun.")


func reload() -> void:
	if not is_gun() or reloading > 0.0:
		return
	var s := st(held)
	if int(s["loaded"]) >= int(_g["mag"]):
		return
	if player.inv.count(str(s["ammo"])) == 0:
		player.message.emit("No %s left." % Items.name_of(str(s["ammo"])))
		return
	reloading = float(_g["reload"])
	Sfx.play(player.get_parent(), "reload", player.global_position, -8.0)


func _finish_reload() -> void:
	var s := st(held)
	var want := int(_g["mag"]) - int(s["loaded"])
	var n := mini(want, player.inv.count(str(s["ammo"])))
	if n > 0:
		player.inv.remove(str(s["ammo"]), n)
		s["loaded"] = int(s["loaded"]) + n
	Sfx.play(player.get_parent(), "click", player.global_position, -6.0, 0.7)


func ammo_text() -> String:
	if is_gun():
		var s := st(held)
		return "%d / %d" % [int(s["loaded"]), player.inv.count(str(s["ammo"]))]
	return ""


# ------------------------------------------------------------ shooting
func fire() -> bool:
	if not is_gun() or _cd > 0.0 or reloading > 0.0:
		return false
	var s := st(held)
	if int(s["loaded"]) <= 0:
		Sfx.play(player.get_parent(), "click", player.global_position, -6.0)
		_cd = 0.3
		reload()
		return false
	s["loaded"] = int(s["loaded"]) - 1
	_cd = 60.0 / float(_g["rpm"])
	var cam := player.camera
	var b := cam.global_basis
	var moving := Vector2(player.velocity.x, player.velocity.z).length() / Player.SPRINT
	var spread := deg_to_rad(float(_g["spread"])) * lerpf(1.0, float(_g["ads"]), aim) * (1.0 + _bloom) * (1.0 + moving * 1.5)
	if player.crouching:
		spread *= 0.75
	var flare := held == "flare_gun"
	for i in int(_g.get("pellets", 1)):
		var dir := (-b.z + b.x * randfn(0.0, spread * 0.5) + b.y * randfn(0.0, spread * 0.5)).normalized()
		player.bullets.fire(cam.global_position + dir * 0.3, dir * float(_g["vel"]), float(_g["dmg"]), float(_g["pen"]), player, flare)
	var rec := deg_to_rad(float(_g["recoil"])) * lerpf(1.0, 0.75, aim) * (0.8 if player.crouching else 1.0)
	player.kick(rec, rec * randf_range(-0.35, 0.35))
	player.shake(clampf(float(_g["recoil"]) * 0.22, 0.2, 0.9))
	_bloom = minf(_bloom + 0.3 * float(_g["bloom"]), 2.5)
	_kick = 1.0
	var quiet: bool = not bool(_g["flash"])
	var cal := str(Weapons.GUNS[held]["cal"])
	var snd := "shot_small"
	if quiet:
		snd = "shot_quiet"
	elif cal in ["12g", "338", "762"]:
		snd = "shot_boom"
	elif cal in ["556", "357"]:
		snd = "shot_big"
	Sfx.play(player.get_parent(), snd, cam.global_position, 0.0 if not quiet else -6.0)
	if not quiet:
		_flash.light_energy = 5.0
	get_tree().call_group("enemy", "hear", player.global_position, float(_g["noise"]))
	return true


# ------------------------------------------------------------ melee
func _start_attack(heavy: bool) -> void:
	var m: Dictionary = Weapons.MELEE[held]
	var cost := float(m["stam"]) * (1.8 if heavy else 1.0)
	if not player.stats.use_stamina(cost):
		player.message.emit("Too tired to strike.")
		return
	_atk_heavy = heavy
	_atk_len = float(m["windup"]) * (1.6 if heavy else 1.0)
	_atk_mult = 1.9 if heavy else 1.0
	if _counter > 0.0:   # counter after a parry: fast and hard
		_atk_len *= 0.5
		_atk_mult *= 2.0
		_counter = 0.0
	elif not heavy:
		_combo = _combo + 1 if _combo_t > 0.0 else 1
		if _combo >= 3:   # third blow of a chain
			_atk_mult *= 1.6
			_combo = 0
	_atk = _atk_len
	_side = -_side
	blocking = false
	Sfx.play(player.get_parent(), "swing", player.global_position, -6.0, 0.8 if heavy else 1.1)


func _land_attack() -> void:
	var m: Dictionary = Weapons.MELEE[held]
	var cam := player.camera
	var from := cam.global_position
	var space := get_world_3d().direct_space_state
	var best := {}
	for a in [0.0, -0.18, 0.18, -0.36, 0.36]:
		var ang: float = a
		var dir := (-cam.global_basis.z).rotated(cam.global_basis.y, ang)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * float(m["reach"]))
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var c: Object = hit["collider"]
		if best.is_empty() or c.has_method("hit"):
			best = hit
			if c.has_method("hit"):
				break
	_recover = float(m["cool"]) * (1.5 if _atk_heavy else 1.0)
	_combo_t = _recover + 0.6
	if best.is_empty():
		return
	var col: Object = best["collider"]
	var at: Vector3 = best["position"]
	if col.has_method("hit"):
		col.hit(float(m["dmg"]) * _atk_mult, at, (at - from).normalized(), float(m["pen"]), player)
		if _atk_heavy and col.has_method("stagger"):
			col.stagger(0.8)
		player.landed_hit(col)
		player.shake(0.75 if _atk_heavy or _atk_mult > 1.5 else 0.4)
		if _atk_heavy or _atk_mult > 1.5 or player.hit_kind == "kill":
			Fx.hitstop(get_tree(), 0.08)
		Sfx.play(player.get_parent(), "thud", at)
	else:
		Sfx.play(player.get_parent(), "clank", at, -4.0)
		Fx.sparks(player.get_parent(), at, best["normal"])
		player.shake(0.25)
		_combo = 0


## A blow from an enemy. Returns "dodged", "parried", "blocked" or "hit".
func incoming_melee(dmg: float, bleed: float, attacker: Node3D) -> String:
	last_melee = "hit"
	if player.dodge_t > 0.0:
		last_melee = "dodged"
		return last_melee
	var facing := true
	if attacker:
		var to := attacker.global_position - player.global_position
		facing = (-player.global_basis.z).dot(Vector3(to.x, 0, to.z).normalized()) > 0.2
	if blocking and facing and is_melee():
		if _block_t < 0.3:
			last_melee = "parried"
			_counter = 1.2
			Sfx.play(player.get_parent(), "clank", player.global_position, 0.0, 1.3)
			player.message.emit("Parried! Strike back now.")
			return last_melee
		var keep := float(Weapons.MELEE[held]["keep"])
		if player.stats.use_stamina(dmg * 0.5):
			player.stats.hurt(dmg * keep, 0.0, "wounds")
			Sfx.play(player.get_parent(), "clank", player.global_position, -3.0)
			last_melee = "blocked"
			return last_melee
		player.message.emit("Your guard breaks.")
		blocking = false
	player.stats.hurt(dmg, bleed, "wounds")
	player.hurt_flash = 1.0
	player.rumble(0.6, 1.0, 0.3)
	Sfx.play(player.get_parent(), "thud", player.global_position)
	return last_melee


func dodge() -> void:
	if _dodge_cd > 0.0 or not player.is_on_floor() or not player.stats.use_stamina(15.0):
		return
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if inp == Vector2.ZERO:
		inp = Vector2(0, 1)   # no direction: jump back
	var dir := (player.global_basis * Vector3(inp.x, 0, inp.y)).normalized()
	player.dodge_vel = dir * 9.5
	player.dodge_t = 0.3
	_dodge_cd = 0.8
	Sfx.play(player.get_parent(), "swing", player.global_position, -10.0, 0.7)


# ------------------------------------------------------------ every frame
func _unhandled_input(event: InputEvent) -> void:
	if player.ui_open or player.vehicle != null:
		return
	if event.is_action_pressed("next_weapon"):
		cycle(1)
	elif event.is_action_pressed("prev_weapon"):
		cycle(-1)
	elif event.is_action_pressed("holster"):
		hold("")
	elif event.is_action_pressed("reload"):
		reload()
	elif event.is_action_pressed("ammo_type"):
		cycle_ammo()
	elif event.is_action_pressed("dodge"):
		dodge()
	else:
		for i in 6:
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				slot(i)


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(_cd - delta, 0.0)
	_bloom = maxf(_bloom - delta * 3.0, 0.0)
	_kick = maxf(_kick - delta * 9.0, 0.0)
	_recover = maxf(_recover - delta, 0.0)
	_combo_t = maxf(_combo_t - delta, 0.0)
	_counter = maxf(_counter - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	hit_flash = maxf(hit_flash - delta, 0.0)
	_flash.light_energy = maxf(_flash.light_energy - delta * 60.0, 0.0)
	var can := not player.ui_open and player.vehicle == null and (free_input or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	var fire_down := can and Input.is_action_pressed("fire")
	var aim_down := can and Input.is_action_pressed("aim")
	var pressed := fire_down and not _fire_was
	var released := _fire_was and not fire_down
	_fire_was = fire_down

	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()

	var want_aim := 0.0
	if is_gun():
		if aim_down and reloading <= 0.0:
			want_aim = 1.0
		if fire_down and (pressed or bool(_g["auto"])):
			fire()
		blocking = false
	elif is_melee():
		var was := blocking
		blocking = aim_down and _atk <= 0.0
		_block_t = _block_t + delta if (blocking and was) else 0.0
		if _atk > 0.0:
			_atk -= delta
			if _atk <= 0.0:
				_land_attack()
		elif _recover <= 0.0:
			if pressed:
				_hold = 0.0
			if _hold >= 0.0:
				_hold += delta
				if released or not fire_down:
					_hold = -1.0
					_start_attack(false)
				elif _hold > 0.28:
					_hold = -1.0
					_start_attack(true)
		else:
			_hold = -1.0
	else:
		blocking = false
	aim = move_toward(aim, want_aim, delta * float(_g.get("aim_speed", 5.0)))
	var zoom := float(_g.get("zoom", 1.0))
	player.camera.fov = lerpf(player.base_fov, player.base_fov / zoom, aim * aim)
	player.look_scale = lerpf(1.0, 1.0 / zoom, aim)
	scoped = zoom >= 4.0 and aim > 0.92
	_pose(delta)


func _pose(delta: float) -> void:
	if _model == null:
		return
	var sway := Vector3(cos(_t * 1.1) * 0.003, sin(_t * 1.7) * 0.003, 0)
	var flat := Vector2(player.velocity.x, player.velocity.z).length()
	sway += Vector3(cos(_t * 6.0), absf(sin(_t * 6.0)), 0) * 0.006 * clampf(flat / 4.0, 0.0, 1.5) * (1.0 - aim * 0.8)
	sway.y -= clampf(player.velocity.y * 0.006, -0.03, 0.03)      # the weapon lags behind jumps and landings
	_draw = maxf(_draw - delta * 3.2, 0.0)
	_sprint = move_toward(_sprint, 1.0 if (flat > Player.WALK + 1.2 and aim < 0.1 and reloading <= 0.0) else 0.0, delta * 5.0)
	var lift := Vector3(0, -_draw * _draw * 0.4, 0)
	if is_gun():
		var sight_y := float(_model.get_meta("sight", 0.082))
		var long := _support.z < -0.1
		var hip := Vector3(0.17, -0.17, -0.34) if long else Vector3(0.16, -0.16, -0.44)
		var ads := Vector3(0.0, -sight_y, -0.24 if long else -0.36)
		var e := aim * aim * (3.0 - 2.0 * aim)
		_model.position = hip.lerp(ads, e) + sway + lift + Vector3(0, 0, _kick * 0.05) + Vector3(-0.05, -0.04, 0.06) * _sprint
		var rot := Vector3(_kick * 0.1 - _draw * 0.9, 0.0, 0.0) + Vector3(-0.3, 0.75, 0.15) * _sprint
		var lh := _support
		if reloading > 0.0:
			# tip the gun, pull the magazine down and out, push a new one home
			var p := 1.0 - clampf(reloading / float(_g["reload"]), 0.0, 1.0)
			var tilt := sin(PI * p)
			rot += Vector3(0.28 * tilt, 0.0, 0.55 * tilt)
			_model.position += Vector3(0.02, -0.05, 0.0) * tilt
			var mag: Vector3 = _model.get_meta("mag")
			if p < 0.2:
				lh = _support.lerp(mag, p / 0.2)
			elif p < 0.45:
				lh = mag + Vector3(-0.04, -0.26, 0.08) * ((p - 0.2) / 0.25)
			elif p < 0.7:
				lh = mag + Vector3(-0.04, -0.26, 0.08) * (1.0 - (p - 0.45) / 0.25)
			elif p < 0.8:
				lh = mag + Vector3(0, 0.012, 0)
			else:
				lh = mag.lerp(_support, (p - 0.8) / 0.2)
		_model.rotation = rot
		if _hand_l:
			_hand_l.position = _hand_l.position.lerp(lh, 0.5)
		_model.visible = not scoped
	else:
		_model.visible = true
		var pos := Vector3(0.28, -0.34, -0.5)
		var rot := Vector3(-0.35, 0.3, -0.15)
		if blocking:
			pos = Vector3(0.05, -0.2, -0.42)
			rot = Vector3(-0.1, 0.2, 1.15)
		elif _atk > 0.0:
			var p := 1.0 - _atk / _atk_len        # 0 start .. 1 impact
			var raise := sin(minf(p * 1.6, 1.0) * PI * 0.5)
			var down := clampf((p - 0.6) / 0.4, 0.0, 1.0)
			pos = Vector3(0.28 - 0.2 * down, -0.3 + 0.16 * raise - 0.22 * down, -0.5 - 0.15 * down)
			rot = Vector3(0.7 * raise - 2.0 * down, 0.3, _side * 0.5 * raise)
		elif _recover > 0.0:
			pos = Vector3(0.1, -0.4, -0.6)
			rot = Vector3(-1.3, 0.3, 0.0)
		elif _hold > 0.1:
			pos = Vector3(0.3, -0.24, -0.45)
			rot = Vector3(0.5, 0.3, 0.0)
		_model.position = _model.position.lerp(pos + sway + lift, 0.35)
		_model.rotation = _model.rotation.lerp(rot, 0.35)


# ------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	return {"held": held, "state": state.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	state.clear()
	var s: Dictionary = d.get("state", {})
	for id in s:
		var e: Dictionary = s[id]
		var mods: Array = []
		for m in e.get("mods", []):
			mods.append(str(m))
		state[str(id)] = {"mods": mods, "loaded": int(e.get("loaded", 0)), "ammo": str(e.get("ammo", ""))}
	held = ""
	hold(str(d.get("held", "")))
	if held == "":
		_rebuild()
