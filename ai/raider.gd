class_name Raider
extends Enemy
## Human enemy. With a gun: keeps its distance, strafes, comes at you from the
## side and shoots real bullets in bursts. With a blade: runs at you and winds
## up blows you can block, parry or dodge.

const DMG_SCALE := 0.45   # enemies hit softer than the player does

var weapon := "pistol"
var bullets: Bullets

var _gun := {}
var _blade := {}
var _mag := 0
var _reload := 0.0
var _shot_cd := 0.0
var _burst := 0
var _aim_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _flank := 1.0
var _windup := 0.0
var _atk_cd := 0.0
var _swing := 0.0
var _rmin := 8.0
var _rmax := 20.0
var _acc := 2.2
var _arm_l: Node3D
var _arm_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _torso: Node3D
var _seed := 0.0
var _look := 0.0
var grenades := 0             # some carry one; Falk carries a bag of them
var _nade_cd := 5.0


func setup(weapon_id: String, rng: RandomNumberGenerator, fixed_look := {}) -> void:
	weapon = weapon_id
	make_body(0.34, 1.8)
	var has_vest := weapon in ["assault_rifle", "marksman_rifle", "sniper_rifle", "shotgun"]
	var looks := [
		{"coat": "olive", "trousers": "black", "hat": "hood", "mask": true, "goggles": true},
		{"coat": "navy", "trousers": "fur_dark", "hat": "beanie", "hat_col": "black", "mask": true},
		{"coat": "camo", "trousers": "camo", "hat": "hood", "mask": true, "goggles": true},
		{"coat": "fur_dark", "trousers": "black", "hat": "helmet", "mask": true, "goggles": true},
		{"coat": "cloth", "trousers": "navy", "hat": "ushanka", "scarf": "black"},
		{"coat": "grey", "trousers": "black", "hat": "beanie", "hat_col": "navy", "scarf": "fur_dark"},
		{"coat": "fur_brown", "trousers": "olive", "hat": "hood"},
		{"coat": "black", "trousers": "camo", "hat": "none", "scarf": "grey"},
	]
	var look: Dictionary = looks[rng.randi() % looks.size()].duplicate()
	look["vest"] = has_vest
	look["pack"] = rng.randf() < 0.6
	if not fixed_look.is_empty():
		look = fixed_look
	var frozen := GameMode.horror() and fixed_look.is_empty()
	if frozen:
		# the Frozen: raiders the cold got into. Grey skin, frost in their hair, eyes like lamps
		look = {"coat": ["black", "fur_dark", "grey", "navy"][rng.randi() % 4], "trousers": "black", "hat": "none",
			"skin": "frost_skin", "hair": "white", "eyes": "glow", "beard": rng.randf() < 0.4, "pack": false, "vest": has_vest}
	if fixed_look.is_empty():
		if not frozen and not bool(look.get("mask", false)):
			look["beard"] = rng.randf() < 0.55
		look = Humanoid.vary(look, rng.randi())
	model = Humanoid.build(look)
	Humanoid.fit(model, look)
	add_child(model)
	_arm_l = model.get_meta("arm_l")
	_arm_r = model.get_meta("arm_r")
	_el_l = model.get_meta("elbow_l")
	_el_r = model.get_meta("elbow_r")
	_torso = model.get_meta("torso")
	_seed = rng.randf() * 10.0
	if frozen:
		var ice := MeshKit.new()
		ice.winter = true  # creatures keep their ice and frost in summer
		for i in 6:
			var a := i * 1.1
			ice.tube(Vector3(sin(a) * 0.16, 0.42, cos(a) * 0.1), Vector3(sin(a) * 0.24, 0.52 + (i % 3) * 0.04, cos(a) * 0.14), 0.03, "ice", 5, 0.0)
		_torso.add_child(ice.node(false))
	# raiders wear a red rag on the left arm
	var band := MeshKit.new()
	band.winter = true  # creatures keep their ice and frost in summer
	band.tube(Vector3(0, -0.12, 0), Vector3(0, -0.18, 0), 0.068, "red_in", 10)
	band.box(Vector3(-0.07, -0.2, 0.02), Vector3(0.012, 0.09, 0.04), "red_in", Basis(Vector3.BACK, 0.3))
	_arm_l.add_child(band.node(false))
	var wm := Weapons.model(weapon, [])
	wm.rotation.x = -PI * 0.5
	(model.get_meta("hand_r") as Node3D).add_child(wm)
	armor = 25.0 if has_vest else 5.0
	max_health = 90.0 if has_vest else 70.0
	health = max_health
	_flank = 1.0 if rng.randf() < 0.5 else -1.0
	grenades = 1 if randf() < 0.3 and weapon in ["assault_rifle", "smg", "shotgun"] else 0
	body_title = "Frozen body" if frozen else "Dead raider"
	display_name = "The Frozen" if frozen else "Raider"
	loot = {weapon: 1}
	if Weapons.is_gun(weapon):
		_gun = Weapons.GUNS[weapon]
		_mag = int(_gun["mag"])
		loot[str(_gun["cal"])] = rng.randi_range(8, 24) if weapon != "sniper_rifle" else rng.randi_range(4, 8)
		match weapon:
			"assault_rifle", "marksman_rifle":
				_rmin = 14.0
				_rmax = 38.0
				_acc = 1.6
			"sniper_rifle":
				_rmin = 30.0
				_rmax = 90.0
				_acc = 0.9
				view_dist = 90.0
			"shotgun":
				_rmin = 5.0
				_rmax = 13.0
	else:
		_blade = Weapons.MELEE[weapon]
		speed = 4.6
	for extra in ["bandage", "canned_food", "scrap", "cloth", "hand_warmer"]:
		if rng.randf() < 0.3:
			loot[extra] = 1


func _on_hurt() -> void:
	if state != "fight":
		_engage()


func _engage() -> void:
	state = "fight"
	_aim_t = 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e is Raider and (e as Raider).global_position.distance_to(global_position) < 40.0:
			(e as Raider).provoked = (e as Raider).provoked or (provoked and (e as Raider).faction == faction)
			(e as Raider).alarm(player.global_position)


func _think(delta: float, dist: float) -> Vector3:
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	match state:
		"idle":
			_aware = clampf(_aware + (delta * lerpf(2.5, 0.5, clampf(dist / view_dist, 0.0, 1.0)) if _sees else -delta * 0.3), 0.0, 1.0)
			if _aware >= 1.0:
				_engage()
			return _roam(delta, 7.0, 1.2)
		"alert":
			if _sees:
				_aware += delta * 3.0
				if _aware >= 1.0:
					_engage()
			_lost += delta
			var d := _flat_to(_last_seen)
			if d.length() > 2.5 and _lost < 14.0:
				_face(d, delta)
				return d.normalized() * speed * 0.8
			_look += delta
			rotation.y += delta * 1.2 * sin(_look * 0.9)   # look around
			if _lost > 20.0:
				state = "idle"
				_aware = 0.0
				_wander = home
				_wander_t = 12.0
			return Vector3.ZERO
	# fight
	if _sees:
		_last_seen = player.global_position
		_lost = 0.0
		_aim_t += delta
	else:
		_lost += delta
		_aim_t = 0.0
		if _lost > 9.0:
			state = "alert"
			return Vector3.ZERO
	var to := _flat_to(_last_seen)
	var d2 := to.length()
	var dir := to.normalized() if d2 > 0.01 else -global_basis.z
	_face(dir, delta)
	# a grenade for someone who hides behind something
	_nade_cd -= delta
	if grenades > 0 and _nade_cd <= 0.0 and d2 > 9.0 and d2 < 32.0 and ((not _sees and _lost > 1.5) or randf() < delta * 0.04):
		throw_grenade(_last_seen, false)
	if _gun.is_empty():
		return _fight_blade(delta, d2, dir)
	var want := Vector3.ZERO
	if not _sees:
		want = dir * speed
	elif d2 > _rmax:
		want = dir.rotated(Vector3.UP, _flank * 0.5) * speed
	elif d2 < _rmin:
		want = -dir * speed * 0.8 + dir.cross(Vector3.UP) * _strafe * speed * 0.4
	else:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(1.2, 3.2)
			_strafe = -_strafe if randf() < 0.7 else 0.0 if randf() < 0.3 else _strafe
			if _strafe == 0.0 and randf() < 0.5:
				_strafe = _flank
		want = dir.cross(Vector3.UP) * _strafe * speed * 0.6
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0:
			_mag = int(_gun["mag"])
		want = want * 1.3 - dir * speed * 0.5   # back off while reloading
	elif _sees and _aim_t > 0.7 and _shot_cd <= 0.0:
		if _burst <= 0:
			_burst = randi_range(2, 5) if bool(_gun["auto"]) else 1
		_shoot(dist)
		_burst -= 1
		_shot_cd = 60.0 / float(_gun["rpm"])
		if _burst <= 0:
			_shot_cd += randf_range(0.7, 1.6) if weapon != "sniper_rifle" else randf_range(2.5, 4.0)
	return want


func throw_grenade(target: Vector3, smoke: bool) -> void:
	if not smoke:
		grenades -= 1
	_nade_cd = randf_range(8.0, 14.0)
	_swing = 0.3
	var from := global_position + Vector3(0, 1.75, 0) - global_basis.z * 0.4
	Grenade.throw(get_parent(), from, target + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), self, smoke)
	if player and global_position.distance_to(player.global_position) < 45.0 and not smoke:
		player.message.emit("Grenade!")


func _shoot(dist: float) -> void:
	var fwd := -global_basis.z
	var from := global_position + Vector3(0, 1.42, 0) + fwd * 0.45
	var target := player.camera.global_position - Vector3(0, 0.4, 0)
	var vel := float(_gun["vel"])
	var t := dist / vel
	target += player.velocity * t * 0.6          # leads a moving target, but not perfectly
	target.y += 0.5 * Bullets.GRAVITY * t * t    # holds over for bullet drop
	var storm := player.weather.storm if player.weather else 0.1
	var pspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var err := deg_to_rad(_acc + 2.5 * pspeed / Player.SPRINT + 2.0 * storm + (1.0 if player.crouching else 0.0))
	var aim := (target - from).normalized()
	var right := aim.cross(Vector3.UP).normalized()
	var up := right.cross(aim)
	var pen := Items.num(str(_gun["cal"]), "pen")
	for i in int(_gun.get("pellets", 1)):
		var sp := err + deg_to_rad(float(_gun["spread"])) * (1.0 if _gun.has("pellets") else 0.3)
		var dir := (aim + right * randfn(0.0, sp * 0.6) + up * randfn(0.0, sp * 0.6)).normalized()
		bullets.fire(from, dir * vel, float(_gun["dmg"]) * DMG_SCALE, pen, self)
	var cal := str(_gun["cal"])
	Sfx.play(get_parent(), "shot_boom" if cal in ["12g", "338", "762"] else ("shot_big" if cal in ["556", "357"] else "shot_small"), from)
	_swing = 0.12
	_mag -= 1
	if _mag <= 0:
		_reload = float(_gun["reload"]) * 1.3


func _fight_blade(delta: float, d: float, dir: Vector3) -> Vector3:
	var reach := float(_blade["reach"])
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_swing = 0.3
			_atk_cd = 1.3
			if d < reach + 0.5 and _sees:
				var res := player.melee_hit(float(_blade["dmg"]) * 0.7, 0.35, self)
				if res == "parried":
					stagger(1.8)
		return Vector3.ZERO
	if d < reach * 0.85:
		if _atk_cd <= 0.0:
			_windup = float(_blade["windup"]) + 0.3
			Sfx.play(get_parent(), "swing", global_position, -4.0, 0.8)
		return dir.cross(Vector3.UP) * _flank * speed * 0.3
	return dir * speed


func _stride(moved: float) -> float:
	return Humanoid.gait(moved).x


func _animate(delta: float, moved: float) -> void:
	var amt := minf(Humanoid.gait(moved).y, 1.3)
	var t := Time.get_ticks_msec() * 0.001 + _seed
	_swing = maxf(_swing - delta, 0.0)
	var armed := state == "fight" or state == "alert"
	var hurt := _stagger > 0.25
	Humanoid.walk(model, _phase, amt, not armed and not hurt)
	if amt < 0.05:
		Humanoid.breathe(model, t)
	model.rotation.z = lerpf(model.rotation.z, 0.0, 0.15)
	var ar := _arm_r.rotation
	var al := _arm_l.rotation
	var er := 0.25
	var el := 0.25
	var lean := clampf((moved - 2.0) * 0.06, 0.0, 0.16)    # running leans into the stride
	if hurt:
		lean = -0.3
		ar = Vector3(-0.7, 0, 0.5)
		al = Vector3(-0.5, 0, -0.6)
		er = 0.9
		el = 0.7
	elif armed and _gun.is_empty():
		# blade: guard, wind up over the shoulder, cut down
		ar = Vector3(1.0, 0, 0.15)
		er = 1.1
		al = Vector3(0.6, -0.3, -0.25)
		el = 1.0
		lean = 0.12
		if _windup > 0.0:
			ar = Vector3(2.9, 0, 0.3)
			er = 0.5
			lean = -0.15
		elif _swing > 0.0:
			ar = Vector3(0.35, 0.5, 0.0)
			er = 0.1
			lean = 0.35
	elif armed:
		var pitch := 0.0
		if state == "fight":
			var to := player.camera.global_position - (global_position + Vector3(0, 1.42, 0))
			pitch = atan2(to.y, Vector2(to.x, to.z).length())
		var long := str(_gun["shape"]) not in ["pistol", "revolver", "flare"]
		if state == "fight" and _reload <= 0.0:
			ar = Vector3(PI * 0.5 + pitch + _swing * 0.5, 0.12 if long else -0.12, 0)
			er = 0.08
			al = Vector3(PI * 0.5 + pitch - 0.12, -0.62 if long else -0.35, 0)
			el = 0.3 if long else 0.12
			lean = 0.1 - pitch * 0.25
		else:   # low ready, or busy with the magazine
			ar = Vector3(0.75, 0.1, 0)
			er = 0.75
			al = Vector3(0.7, -0.5, 0)
			el = 1.0 + (sin(t * 9.0) * 0.25 if _reload > 0.0 else 0.0)
	if armed or hurt:
		_arm_r.rotation = _arm_r.rotation.lerp(ar, 0.3)
		_arm_l.rotation = _arm_l.rotation.lerp(al, 0.3)
		_el_r.rotation.x = lerpf(_el_r.rotation.x, er, 0.3)
		_el_l.rotation.x = lerpf(_el_l.rotation.x, el, 0.3)
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, 0.2) if (armed or hurt or amt >= 0.05) else _torso.rotation.x
