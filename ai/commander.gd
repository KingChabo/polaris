class_name Commander
extends Raider
## Oberst Falk, who kept Fort Nordwacht shut when the valley needed it open.
## He fights like a soldier: a rifle at range, a carbine in the yard, a shotgun when you
## come close; he goes behind cover to reload, and twice he calls men to him.

const KIT := ["marksman_rifle", "assault_rifle", "shotgun"]

var boss_name := "Oberst Falk"
var boss_sub := "He reloads behind cover. Push him then."
var phase := 1
var reward := {}
var main: Node
var cover_points: Array = []      # world positions next to walls, sandbags, containers
var rally_points: Array = []      # where reinforcements come from
var swaps := 0
var calls := 0
var voice := "Falk"
var cry := "Für Nordwacht!"
var call_line := "Wache! Zu mir!"
var men_name := "Garrison soldier"
var in_cover := false

var _mags := {}
var _swap_cd := 0.0
var _cover := Vector3.INF
var _cover_t := 0.0
var _cover_cd := 0.0
var _hurt_since := 0.0
var _last_health := 0.0
var last_stand := false


func setup_boss(rng: RandomNumberGenerator, look := {}) -> void:
	if look.is_empty():
		look = {"coat": "navy", "trousers": "black", "hat": "ushanka", "hat_col": "fur_dark", "beard": true,
			"hair": "grey", "scarf": "red", "vest": true, "pack": false}
	setup("marksman_rifle", rng, look)
	model.scale = Vector3.ONE * 1.08
	display_name = boss_name
	body_title = boss_name
	max_health = 420.0
	health = max_health
	_last_health = health
	armor = 45.0
	speed = 4.0
	view_dist = 70.0
	faction = "nordwacht"
	for w in KIT:
		_mags[w] = int(Weapons.GUNS[w]["mag"])
	grenades = 99
	_nade_cd = 8.0


func _arm(id: String) -> void:
	if id == weapon:
		return
	_mags[weapon] = _mag
	var hand: Node3D = model.get_meta("hand_r")
	if hand.get_child_count() > 0:
		hand.get_child(hand.get_child_count() - 1).queue_free()
	var wm := Weapons.model(id, [])
	wm.rotation.x = -PI * 0.5
	hand.add_child(wm)
	weapon = id
	_gun = Weapons.GUNS[id]
	_mag = int(_mags[id])
	_burst = 0
	_shot_cd = 0.7
	match id:
		"marksman_rifle":
			_rmin = 22.0
			_rmax = 60.0
			_acc = 1.3
		"assault_rifle":
			_rmin = 8.0
			_rmax = 28.0
			_acc = 1.8
		_:
			_rmin = 4.0
			_rmax = 11.0
			_acc = 2.2
	swaps += 1
	Sfx.play(get_parent(), "click", global_position, 2.0, 0.8)


func _best(dist: float) -> String:
	var want := "marksman_rifle" if dist > 30.0 else ("assault_rifle" if dist > 12.0 else "shotgun")
	if int(_mags[want]) > 0 or want == weapon:
		return want
	for w: String in KIT:
		if int(_mags[w]) > 0:
			return w
	return want


func bar() -> Dictionary:
	return {"name": boss_name, "sub": boss_sub, "frac": clampf(health / max_health, 0.0, 1.0), "pips": [], "phase": phase}


func _think(delta: float, dist: float) -> Vector3:
	# a quarter left: no more cover, no more waiting
	if not last_stand and health < max_health * 0.25:
		_last_stand()
		if state != "fight":
			_engage()
	if state != "fight":
		return super._think(delta, dist)
	_mags[weapon] = _mag
	_swap_cd -= delta
	_cover_cd -= delta
	_hurt_since += _last_health - health
	_last_health = health
	# twice he calls for help
	var third := 2 if health < max_health * 0.33 else (1 if health < max_health * 0.66 else 0)
	if third > calls:
		calls = third
		phase = calls + 1
		_call_men()
	# out of rounds in this one: take another gun instead of reloading in the open
	if _reload > 0.0 and not in_cover and _cover_t <= 0.0:
		var other := _best(dist)
		if other != weapon and int(_mags[other]) > 0:
			_reload = 0.0
			_arm(other)
			_swap_cd = 2.5
		elif _cover_cd <= 0.0 and not last_stand:
			_seek_cover()
	if _hurt_since > 80.0 and _cover_cd <= 0.0 and _cover_t <= 0.0 and not last_stand:
		_seek_cover()
	# grenades: whenever you dig in, and now and then anyway
	_nade_cd -= delta
	if _nade_cd <= 0.0 and dist > 8.0 and dist < 34.0 and ((not _sees and _lost > 1.0) or randf() < delta * (0.12 if last_stand else 0.05)):
		throw_grenade(_last_seen if not _sees else player.global_position, false)
		_nade_cd = randf_range(5.0, 8.0) if last_stand else randf_range(9.0, 13.0)
	if _cover_t > 0.0:
		return _hold_cover(delta)
	if _swap_cd <= 0.0 and _reload <= 0.0 and _sees:
		var b := _best(dist)
		if b != weapon:
			_arm(b)
			_swap_cd = 1.6
	return super._think(delta, dist)


## The nearest spot the player cannot see from where they stand.
func _seek_cover() -> void:
	var best := Vector3.INF
	var best_d := 1e9
	var space := get_world_3d().direct_space_state
	var eye := player.camera.global_position
	for c in cover_points:
		var p: Vector3 = c
		var d := p.distance_to(global_position)
		if d > 40.0 or d >= best_d or p.distance_to(player.global_position) < 7.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.75, 0), eye)
		q.exclude = [get_rid(), player.get_rid()]
		if not space.intersect_ray(q).is_empty():
			best = p
			best_d = d
	_hurt_since = 0.0
	if best == Vector3.INF:
		_cover_cd = 3.0
		return
	_cover = best
	_cover_t = 4.2 + best_d / (speed * 1.45)
	_cover_cd = 11.0
	# from the second phase on he covers his run with smoke
	if phase >= 2 and global_position.distance_to(player.global_position) > 6.0:
		throw_grenade(global_position.lerp(player.global_position, 0.4), true)


func _hold_cover(delta: float) -> Vector3:
	_cover_t -= delta
	var to := _flat_to(_cover)
	if to.length() > 0.8:
		in_cover = false
		_face(to, delta)
		return to.normalized() * speed * 1.45
	# down behind it: fill every magazine, then come up again
	in_cover = true
	_face(_flat_to(player.global_position), delta)
	if _cover_t <= 3.2:
		for w in KIT:
			_mags[w] = int(Weapons.GUNS[w]["mag"])
		_mag = int(_mags[weapon])
		_reload = 0.0
	if _cover_t <= 0.0:
		in_cover = false
		_aim_t = 0.4
	return Vector3.ZERO


func _last_stand() -> void:
	last_stand = true
	_cover_t = 0.0
	in_cover = false
	speed *= 1.4
	_acc *= 0.65
	boss_sub = "Last stand: he will not hide again. Keep moving."
	Sfx.play(get_parent(), "growl", global_position, 6.0, 1.2)
	if player:
		player.message.emit("%s: \"%s\"  —  he charges." % [voice, cry])
	Fx.hitstop(get_tree(), 0.25)
	var scene := get_tree().current_scene
	if scene and scene.get("post"):
		scene.post.flash(Color(0.6, 0.05, 0.03), 0.35)


func _call_men() -> void:
	Sfx.play(get_parent(), "growl", global_position, 4.0, 1.5)
	player.message.emit("%s: \"%s\"  —  reinforcements are coming." % [voice, call_line])
	if main == null or rally_points.is_empty():
		return
	var kinds := ["assault_rifle", "smg"] if calls == 1 else ["shotgun", "assault_rifle"]
	for i in kinds.size():
		var p: Vector3 = rally_points[(i + calls) % rally_points.size()]
		var e: Raider = main.enemies.raider(kinds[i], p)
		e.faction = faction
		if faction != "raiders":
			e.loot.erase("bounty_tag")
		e.display_name = men_name
		e.provoked = true
		e.state = "alert"
		e._aware = 0.8
		e._last_seen = player.global_position


func _animate(delta: float, moved: float) -> void:
	super._animate(delta, moved)
	model.position.y = lerpf(model.position.y, -0.55 if in_cover and state == "fight" else 0.0, 0.2)


func _die(dir: Vector3) -> void:
	in_cover = false
	model.position.y = 0.0
	for id in reward:
		loot[id] = int(loot.get(id, 0)) + int(reward[id])
	super._die(dir)


func make_dead() -> void:
	state = "dead"
	health = 0.0
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	model.rotation.x = PI * 0.48
	model.position.y = 0.14
