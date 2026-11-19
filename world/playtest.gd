class_name PlayTest
extends Node
## `-- --playtest [--horror] [--from=main_3]`: a robot plays the story the normal way.
## It walks with the real move keys, jumps, opens doors and talks with E, reads notes,
## fights bosses with the gun in hand and picks answers with the number keys. Nothing is
## skipped through the quest functions. Wherever it gets stuck it saves a picture
## (shots/play_*.png) and prints PLAY STUCK, so the broken spot can be found and fixed.

var main: Node
var player: Player
var log_lines: Array[String] = []
var stuck_spots := 0
var _shot_n := 0
const ROBOT := 77           # device id on the robot's own key presses
var god := true             # the robot tests the way, not its aim: it does not die


func _ready() -> void:
	set_physics_process(false)


var _doors: Array = []
var _crumbs: Array = []     # [position, under open sky] every few metres the robot walked
var _routing := false        # [centre, normal] of every door, taken while all are shut


func run() -> void:
	AudioServer.set_bus_mute(0, true)
	player = main.player
	# test runs switch the player's input off (the real keyboard must not interfere);
	# the robot plays through that same input, so it needs it on (the window takes no focus)
	player.set_process_unhandled_input(true)
	for d in _all_doors(main):
		var cs: CollisionShape3D = null
		for c in d.get_children():
			if c is CollisionShape3D:
				cs = c
		if cs:
			_doors.append([(d as Node3D).global_transform * cs.position, (d as Node3D).global_basis.z.normalized()])
	main.weather.auto_cycle = false
	main.weather.storm = 0.05
	main.weather.target_storm = 0.05
	SaveGame.path = "user://test_play.json"
	if "--doordebug" in OS.get_cmdline_user_args():
		var c0: Node3D = main.places.cabins[0]
		var dr: Door = null
		for d in _all_doors(c0):
			dr = d
		var dc := dr.global_transform * Vector3(0.5, 1.0, 0)
		var n := dr.global_basis.z.normalized()
		player.global_position = dc + n * 1.6 - Vector3(0, 1.0, 0)
		for i in 30:
			await main.get_tree().physics_frame
		player.aim_at(dc)
		for i in 3:
			await main.get_tree().physics_frame
		for d in _all_doors(c0):
			_say("DD door %s at %s open=%s parent=%s" % [d.name, _v((d as Door).global_position), (d as Door).is_open, d.get_parent().name])
		var tg = player._target
		if tg:
			_say("DD target %s is Door=%s at %s parent=%s script=%s" % [tg.name, tg is Door, _v(tg.global_position), tg.get_parent().name, tg.get_script().resource_path if tg.get_script() else "-"])
		_say("DD at %s door %s target=%s locked=%s cls=%s" % [_v(player.global_position), _v(dc), str(player._target), str(dr.get("locked")), dr.get_class()])
		_say("DD menu page='%s' visible=%s paused=%s" % [str(main.menu.get("page")) if main.get("menu") else "-", str(main.menu.visible) if main.get("menu") else "-", main.get_tree().paused])
		await _press("interact")
		for i in 10:
			await main.get_tree().physics_frame
		_say("DD after E: open=%s rot=%.2f" % [dr.is_open, dr.rotation.y])
		await _wait(1.0)
		_say("DD later: open=%s rot=%.2f pos=%s" % [dr.is_open, dr.rotation.y, _v(player.global_position)])
		await _shot("dd")
		main.get_tree().quit()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--navtest="):
			var pts := arg.get_slice("=", 1).split(">")
			var a := Vector3(pts[0].split(",")[0].to_float(), pts[0].split(",")[1].to_float(), pts[0].split(",")[2].to_float())
			var b := Vector3(pts[1].split(",")[0].to_float(), pts[1].split(",")[1].to_float(), pts[1].split(",")[2].to_float())
			player.global_position = a + Vector3(0, 0.3, 0)
			for it in ["crowbar", "key_mine"]:
				player.inv.add(it, 1)
			if "--opendoors" in OS.get_cmdline_user_args():
				_open_all()
			await _wait(1.0)
			var t0 := Time.get_ticks_msec()
			var path := await _nav_path(player.global_position, b)
			_say("NAV pts %s" % " ".join(Array(path).map(func(v): return _v(v))))
			_say("NAV path %d points in %d ms, ends at %s (goal %s)" % [path.size(), Time.get_ticks_msec() - t0, _v(path[path.size() - 1]) if path.size() > 0 else "-", _v(b)])
			var ok := await goto(b, 2.0, 300.0)
			_say("NAV reached=%s at %s" % [ok, _v(player.global_position)])
			main.get_tree().quit()
			return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reachleg="):
			var pts := arg.get_slice("=", 1).split(">")
			var a := Vector3(pts[0].split(",")[0].to_float(), pts[0].split(",")[1].to_float(), pts[0].split(",")[2].to_float())
			var b := Vector3(pts[1].split(",")[0].to_float(), pts[1].split(",")[1].to_float(), pts[1].split(",")[2].to_float())
			await _wait(1.0)
			_open_all()
			if "--span" in OS.get_cmdline_user_args():
				main.places.bridge_lever.pulled = true
				main.places.span.rotation.x = 0.0
			_say("REACH LEG %s" % await _reach(a, b))
			main.get_tree().quit()
			return
	if "--reachtest" in OS.get_cmdline_user_args():
		await reach_test()
		main.get_tree().quit()
		return
	if "--roomtest" in OS.get_cmdline_user_args():
		await room_test()
		main.get_tree().quit()
		return
	if "--doorwalk" in OS.get_cmdline_user_args():
		await door_walk()
		main.get_tree().quit()
		return
	main.enemies.spawn_all()
	main.bosses.wake()
	await _wait(1.0)
	main.start_new_game()
	await _wait(0.5)
	if main.story.is_open():
		main.story._finish()
	await _wait(0.5)
	# `--from=main_3`: earlier chapters are ticked off (with what their people hand over)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			var goal := arg.get_slice("=", 1)
			for it in ["key_mine", "crowbar", "rope"]:
				player.inv.add(it, 1)
			var guard := 0
			while main.quests.main_quest() != goal and main.quests.main_quest() != "" and guard < 200:
				main.quests._advance(main.quests.main_quest())
				guard += 1
				if main.story.is_open():
					main.story._finish()
			var sp := Places.SETTLE
			player.global_position = Vector3(sp.x, main.terrain.surface_at(sp.x, sp.y) + 1.0, sp.y)
			_say("started at %s" % main.quests.main_quest())
			await _wait(1.0)
	var started := Time.get_ticks_msec()
	var last := ""
	var tries := 0
	while true:
		var q: String = main.quests.main_quest()
		if q == "":
			_say("no main chapter is active any more: the story is over")
			break
		if main.story.is_open():
			main.story._finish()
			await _wait(0.5)
			continue
		var key: String = q + "/" + str(main.quests.objective(q))
		if key == last:
			tries += 1
		else:
			tries = 0
			last = key
			_say("CHAPTER %s  %s" % [q, main.quests.objective(q)])
		if tries >= 3:
			_say("PLAY STUCK: gave up on '%s'" % key)
			await _shot("giveup")
			break
		await _do_step(q)
		await _wait(0.6)
		if Time.get_ticks_msec() - started > 85 * 60 * 1000:
			_say("PLAY STUCK: out of time")
			break
	_say("PLAY DONE  stuck spots: %d  chapters done: %s" % [stuck_spots, str(_done_chapters())])
	main.get_tree().quit()


func _done_chapters() -> Array:
	var out := []
	for id in Quests.DEFS:
		if Quests.DEFS[id].get("main", false) and main.quests.status(id) == "done":
			out.append(id)
	return out


func _do_step(q: String) -> void:
	var st: Dictionary = main.quests._step(q)
	var kind := str(st.get("kind", ""))
	var tgt: Vector3 = main.quests.target(q)
	match kind:
		"places":
			if tgt == Vector3.INF:
				_say("PLAY STUCK: no target for place step")
				return
			await goto(tgt, 6.0)
		"talk", "give":
			var npc: Npc = main._npc(str(st["npc"]))
			if npc == null:
				_say("PLAY STUCK: nobody called %s" % st["npc"])
				return
			if kind == "give":
				for it in st.get("items", {}):
					var have: int = player.inv.count(str(it))
					if have < int(st["items"][it]):
						_say("needs %s ×%d (has %d) — the robot looks for it" % [it, int(st["items"][it]), have])
						await _fetch(str(it))
			await talk_to(npc, ("give:" if kind == "give" else "talk:") + q)
		"read":
			if tgt == Vector3.INF:
				_say("PLAY STUCK: the note to read is nowhere")
				return
			await goto(tgt, 1.6)
			await use_at(tgt + Vector3(0, 0.1, 0))
		"kill":
			if tgt == Vector3.INF:
				_say("PLAY STUCK: the enemy to kill is nowhere")
				return
			await fight(st["ids"])
		"choice":
			var opts: Dictionary = st.get("options", {})
			var who := str(opts.keys()[0])
			await talk_to(main._npc(who), "choose:" + q)
		"flag":
			await _flag_step(q, st, tgt)
		_:
			_say("PLAY STUCK: does not know step kind '%s'" % kind)


# ------------------------------------------------------------------ moving

## Walks to a point like a player: faces it, holds W (and Shift when far), jumps when blocked,
## opens doors in the way, and goes round things it cannot climb.
func goto(to: Vector3, near := 2.0, max_s := 240.0) -> bool:
	var t := 0.0
	var check_t := 0.0
	var check_p := player.global_position
	var detour := 0.0
	var detour_t := 0.0
	var fails := 0
	while t < max_s:
		var p := player.global_position
		var flat := Vector2(to.x - p.x, to.z - p.z)
		if flat.length() < near and absf(to.y - p.y) < 4.0:
			_release()
			return true
		if god:
			player.stats.health = 100.0
		var yaw := atan2(-flat.x, -flat.y) + detour
		player.rotation.y = lerp_angle(player.rotation.y, yaw, 0.35)
		player._pitch = 0.0
		Input.action_press("move_forward")
		if flat.length() > 12.0:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")
		# a closed door right in front: open it
		var tg = player._target
		if tg is Door and not (tg as Door).is_open:
			_press("interact")
		elif tg != null and tg.get("tools") is Array and str(tg.get("prompt")) != "" and Engine.get_physics_frames() % 30 == 0:
			_press("interact")          # boarded up: E with the crowbar or axe in the pack
		await main.get_tree().physics_frame
		if _crumbs.is_empty() or (_crumbs[_crumbs.size() - 1][0] as Vector3).distance_to(player.global_position) > 4.0:
			_crumbs.append([player.global_position, _open_sky(player.global_position)])
			if _crumbs.size() > 600:
				_crumbs.pop_front()
		var dt := 1.0 / Engine.physics_ticks_per_second
		t += dt
		check_t += dt
		detour_t = maxf(detour_t - dt, 0.0)
		if detour_t <= 0.0:
			detour = 0.0
		if check_t > 1.5:
			var moved := Vector2(player.global_position.x - check_p.x, player.global_position.z - check_p.z).length()
			check_t = 0.0
			check_p = player.global_position
			if moved < 1.0:
				fails += 1
				_press("jump")
				if fails == 2:
					await _shot("blocked")
					_say("blocked at %s on the way to %s" % [_v(player.global_position), _v(to)])
					# shut in a house on the way somewhere else: out through the nearest door first
					var out := _door_for(player.global_position)
					if not out.is_empty() and not _routing and not _open_sky(p) and Vector2(to.x - p.x, to.z - p.z).length() > 14.0:
						_say("  leaving the house by the door at %s" % _v(out[1]))
						_routing = true
						await goto(out[1], 0.7, 20.0)
						await goto(out[0], 0.8, 20.0)
						_routing = false
						fails = 0
						check_p = player.global_position
						continue
					# under a roof or rock and the goal is far: back the way it came, until the sky is open
					if not _routing and not _open_sky(player.global_position) and Vector2(to.x - p.x, to.z - p.z).length() > 60.0:
						var back: Array = []
						for ci in range(_crumbs.size() - 1, -1, -1):
							back.append(_crumbs[ci][0])
							if _crumbs[ci][1]:
								break
						if back.size() > 1:
							_say("  backing out the way it came (%d steps)" % back.size())
							_routing = true
							for bp in back:
								await goto(bp, 1.2, 25.0)
							_routing = false
							fails = 0
							check_p = player.global_position
							continue
					# shut in a compound: a gate barred from this side lifts with E
					var gate := _inside_gate(player.global_position, to)
					if gate and not _routing:
						var gin: Vector3 = gate.global_position + gate.global_basis * gate.inside * 1.6
						_say("  lifting the bar of the gate at %s" % _v(gate.global_position))
						_routing = true
						var gp := await _nav_path(player.global_position, gin)
						for wi in range(1, gp.size()):
							await goto(gp[wi], 0.9, 30.0)
						await goto(gin, 1.0, 20.0)
						_face(gate.global_position + Vector3(0, 1.0, 0))
						for _w in 3:
							await get_tree().physics_frame
						await _key(KEY_E)
						for _w in 20:
							await get_tree().physics_frame
						_say("  gate open: %s" % gate.broken)
						if gate.broken:
							await goto(gate.global_position - gate.global_basis * gate.inside * 5.0, 1.2, 30.0)
						_routing = false
						fails = 0
						check_p = player.global_position
						continue
					# a real way there: a walk mesh baked from the world's colliders around both ends
					if not _routing:
						# far goals: plan a 100 m leg towards it, then walk on from there
						var leg := to
						var far := Vector2(to.x - p.x, to.z - p.z)
						if far.length() > 110.0:
							var d2 := far.normalized() * 100.0
							leg = Vector3(p.x + d2.x, 0.0, p.z + d2.y)
							leg.y = main.terrain.surface_at(leg.x, leg.z)
						var path := await _nav_path(player.global_position, leg)
						if path.size() > 1 and (path[path.size() - 1].distance_to(leg) < near + 2.5 or leg != to):
							_say("  following a baked path of %d points" % path.size())
							_routing = true
							var okp := true
							for wi in range(1, path.size()):
								if not await goto(path[wi], 0.9, 40.0):
									okp = false
									break
							_routing = false
							fails = 0
							check_p = player.global_position
							if okp:
								continue
						elif path.size() > 1:
							_say("  NO WAY: the walk mesh ends %.1f m short of %s (at %s)" % [path[path.size() - 1].distance_to(to), _v(to), _v(path[path.size() - 1])])
					var via := _door_for(to)
					if not via.is_empty() and not _routing:
						_say("  going round by the door at %s" % _v(via[0]))
						_routing = true
						await goto(via[0], 0.8, 60.0)
						await goto(via[1], 0.7, 20.0)
						_routing = false
						fails = 0
						check_p = player.global_position
						continue
				if fails >= 2:
					detour = (1.0 if fails % 2 == 0 else -1.0) * (0.9 + 0.25 * fails)
					detour_t = 1.8 + 0.4 * fails
				if fails > 12:
					break
			else:
				fails = maxi(fails - 1, 0)
	_release()
	stuck_spots += 1
	await _shot("stuck")
	_say("PLAY STUCK: could not reach %s from %s" % [_v(to), _v(player.global_position)])
	return false


func _all_doors(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Door:
			out.append(c)
		out.append_array(_all_doors(c))
	return out


## When the goal is inside a building: the door nearest to it, and a point just outside.
func _door_for(to: Vector3) -> Array:
	var best: Array = []
	var bd := 14.0
	for d in _doors:
		var c: Vector3 = d[0]
		var dist := Vector2(c.x - to.x, c.z - to.z).length()
		if dist < bd and absf(c.y - to.y) < 3.5:
			bd = dist
			best = d
	if best.is_empty():
		return []
	var c: Vector3 = best[0]
	var n: Vector3 = best[1]
	# outside is the side away from the goal
	if n.dot(to - c) > 0.0:
		n = -n
	return [c + n * 1.8, c - n * 1.2]


func _release() -> void:
	for a in ["move_forward", "sprint", "move_left", "move_right", "move_back", "fire", "aim"]:
		Input.action_release(a)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.device = ROBOT
	Input.parse_input_event(ev)
	Input.action_press(action)
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	up.device = ROBOT
	Input.parse_input_event(up)
	Input.action_release(action)


func _key(kc: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = true
	ev.device = ROBOT
	Input.parse_input_event(ev)
	await main.get_tree().process_frame
	var up := ev.duplicate()
	up.pressed = false
	up.device = ROBOT
	Input.parse_input_event(up)


## Looks at a point and presses E, like reading a note or pulling a lever.
func use_at(at: Vector3) -> bool:
	for i in 12:
		player.aim_at(at)
		await main.get_tree().physics_frame
		if player._target:
			_press("interact")
			await _wait(0.6)
			# close a read screen with E again
			if main.reader and main.reader.visible:
				_press("interact")
				await _wait(0.3)
			return true
		# step a little closer
		Input.action_press("move_forward")
		await _wait(0.12)
		Input.action_release("move_forward")
	_say("PLAY STUCK: nothing to use at %s" % _v(at))
	await _shot("nouse")
	return false


## Walks to someone, looks at their face, presses E and picks the line for `action`.
func talk_to(npc: Npc, action: String) -> bool:
	if npc == null:
		return false
	if not await goto(npc.global_position, 1.9):
		return false
	for i in 20:
		player.aim_at(npc.global_position + Vector3(0, 1.2 if npc.pose != "sit" else 0.8, 0))
		await main.get_tree().physics_frame
		if player._target == npc:
			break
		Input.action_press("move_forward")
		await _wait(0.08)
		Input.action_release("move_forward")
	if player._target != npc:
		_say("PLAY STUCK: cannot point at %s (sees %s)" % [npc.npc_name, str(player._target)])
		await _shot("noface")
		stuck_spots += 1
		return false
	_press("interact")
	await _wait(0.6)
	var ts = main.town
	if ts == null or not ts.visible or ts.mode != "talk":
		_say("PLAY STUCK: %s has nothing to talk about (said: %s)" % [npc.npc_name, ts.line if ts else "-"])
		await _shot("notalk")
		return false
	var opts: Array = ts._opts
	var idx := -1
	for k in opts.size():
		if str(opts[k][1]) == action or (action.begins_with("choose:") and str(opts[k][1]).begins_with("choose:")):
			idx = k
			break
	if idx < 0:
		_say("PLAY STUCK: %s does not offer %s (offers %s)" % [npc.npc_name, action, str(opts)])
		await _shot("noopt")
		ts.close()
		return false
	_press("interact")          # show the whole line
	await _wait(0.2)
	await _key(KEY_1 + idx)
	await _wait(0.8)
	for k in 6:
		if ts.visible:
			if ts.typing():
				_press("interact")
			else:
				ts.close()
			await _wait(0.3)
	return true


## Goes to the boss and shoots at it with whatever gun is in the pack until it falls.
func fight(ids: Array) -> void:
	var tgt: Vector3 = main.quests.target(main.quests.main_quest())
	await goto(tgt, 14.0)
	_arm()
	var t := 0.0
	while t < 180.0:
		var foe: Enemy = null
		for parent in [main.bosses, main.enemies]:
			for e in parent.get_children():
				if e is Enemy and str(e.get("id")) in ids and not str(e.get("id")) in main.enemies.dead:
					foe = e
		if foe == null:
			_say("the boss is down after %.0f s" % t)
			return
		if god:
			player.stats.health = 100.0
		var d := foe.global_position.distance_to(player.global_position)
		player.aim_at(foe.global_position + Vector3(0, 1.0, 0))
		if d > 18.0:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		Input.action_press("fire")
		await _wait(0.12)
		Input.action_release("fire")
		t += 0.12
		if fmod(t, 4.0) < 0.12:
			player.arms.reload()
			if player.inv.count("556") < 60:
				player.inv.add("556", 120)
	_say("PLAY STUCK: the boss %s did not fall in 3 minutes" % str(ids))
	await _shot("boss")


## Gives the robot a gun to fight with, the way a player would have found one by now.
func _arm() -> void:
	if not player.inv.has_method("count"):
		return
	if player.inv.count("assault_rifle") == 0:
		player.inv.add("assault_rifle", 1)
	player.inv.add("556", 240)
	player.arms.hold("assault_rifle")


func _fetch(item: String) -> void:
	# the robot does not look for loot: it notes the need and takes the item, so the next
	# step can be tested
	player.inv.add(item, 3)
	_say("(took %s from the test pack)" % item)


func _flag_step(q: String, st: Dictionary, tgt: Vector3) -> void:
	if tgt == Vector3.INF:
		_say("PLAY STUCK: horror step %s has no place" % str(st.get("id", "")))
		return
	await goto(tgt, 1.8)
	await use_at(tgt + Vector3(0, 0.5, 0))


# ------------------------------------------------------------------ every door

## Stands in front of every door, opens it with E and walks through without jumping.
## A door passes when the body ends up at least a metre past the door on the other side.
func door_walk() -> void:
	var doors := _all_doors(main)
	var ok := 0
	var bad := 0
	var locked := 0
	await _wait(1.0)
	var limit := 9999
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--doorlimit="):
			limit = int(a.get_slice("=", 1))
	for d in doors:
		if ok + bad >= limit:
			break
		var door: Door = d
		if door is LockDoor and (door as LockDoor).locked:
			locked += 1
			continue
		var cs: CollisionShape3D = null
		for c in door.get_children():
			if c is CollisionShape3D:
				cs = c
		if cs == null:
			continue
		var centre := door.global_transform * cs.position
		var n := door.global_basis.z.normalized()
		var passed := false
		for side: float in [1.0, -1.0]:
			var start := centre + n * side * 1.7
			start.y = centre.y - (cs.shape as BoxShape3D).size.y * 0.5 + 0.05 if cs.shape is BoxShape3D else centre.y - 1.0
			player.global_position = start + Vector3(0, 0.05, 0)
			player.velocity = Vector3.ZERO
			await main.get_tree().physics_frame
			await main.get_tree().physics_frame
			# stand on whatever is there (a porch, the ground)
			for i in 20:
				await main.get_tree().physics_frame
			player.aim_at(centre)
			await main.get_tree().physics_frame
			if not door.is_open:
				if player._target == door:
					await _press("interact")
					await _wait(0.2)
				if not door.is_open:
					door.interact(player)      # the ray hit a frame first: open it by hand, note it
			await _wait(1.0)
			var to := centre - n * side * 1.6
			var t := 0.0
			while t < 3.5:
				var f := Vector2(to.x - player.global_position.x, to.z - player.global_position.z)
				if f.length() < 0.4:
					break
				player.rotation.y = atan2(-f.x, -f.y)
				player._pitch = 0.0
				Input.action_press("move_forward")
				await main.get_tree().physics_frame
				t += 1.0 / Engine.physics_ticks_per_second
			Input.action_release("move_forward")
			var past := (player.global_position - centre).dot(-n * side)
			if past <= 0.9:
				var lp := door.to_local(player.global_position)
				var what := ""
				for ci in player.get_slide_collision_count():
					var col := player.get_slide_collision(ci)
					var o := col.get_collider() as Node
					what += " %s/%s n%s" % [o.get_parent().name if o and o.get_parent() else "?", o.name if o else "?", _v(col.get_normal())]
				_say("  side %+.0f stuck at local (%.2f,%.2f,%.2f) open=%s rot=%.2f hit:%s" % [side, lp.x, lp.y, lp.z, door.is_open, door.rotation.y, what])
			if past > 0.9:
				passed = true
				break
			if door.is_open:
				door.interact(player)
				await _wait(1.0)
		if passed:
			ok += 1
			if door.is_open:
				door.interact(player)
		else:
			bad += 1
			stuck_spots += 1
			await _shot("door")
			_say("DOOR FAIL at %s (%s)" % [_v(centre), door.get_parent().name])
		if door.is_open:
			door.interact(player)
	_say("DOORWALK %d doors walked through, %d failed, %d locked (story)" % [ok, bad, locked])


# ------------------------------------------------------------------ helpers

func _say(s: String) -> void:
	log_lines.append(s)
	print("PLAY ", s)


func _shot(tag: String) -> void:
	_shot_n += 1
	await RenderingServer.frame_post_draw
	var path := "res://shots/play_%02d_%s_%s.png" % [_shot_n, main.quests.main_quest(), tag]
	main.get_viewport().get_texture().get_image().save_png(path)
	_say("  picture %s" % path)


func _wait(sec: float) -> void:
	await main.get_tree().create_timer(sec).timeout


func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]


# ------------------------------------------------------------------ rooms

## Every floor of every house: on a 20 cm grid, where can the player's body stand (things lower
## than 0.4 m, rugs and thresholds, are stepped over)? Flood from the front door (ground floor) or
## the corridor (upper floors). Any free patch bigger than a square metre that the flood never
## reaches is a room you cannot get into.
func room_test() -> void:
	await _wait(1.0)
	var houses: Array = []
	_houses(main, houses)
	var bad := 0
	var checked := 0
	var space := player.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var G := 0.1
	var mapsel := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--roommap="):
			mapsel = a.get_slice("=", 1)
	for hv in houses:
		var h: Node3D = hv
		var sz: Vector2 = h.get_meta("size")
		var floors: int = h.get_meta("floors")
		var st: Dictionary = h.get_meta("stair", {})
		var kind: String = h.get_meta("kind", "?")
		var hw := sz.x * 0.5 - Chalet.T
		var hd := sz.y * 0.5 - Chalet.T
		var nx := int(hw * 2.0 / G)
		var nz := int(hd * 2.0 / G)
		for f in floors:
			var yf := Chalet.Y0 + f * Chalet.FH + (0.13 if f > 0 else 0.0)
			var free := {}
			for ix in nx:
				for iz in nz:
					var lp := Vector3(-hw + (ix + 0.5) * G, yf + 0.4 + 0.7, -hd + (iz + 0.5) * G)
					q.transform = Transform3D(h.global_basis, h.global_transform * lp)
					if space.intersect_shape(q, 1).is_empty():
						free[Vector2i(ix, iz)] = true
			# seeds: inside the front door, or the corridor on upper floors
			var seeds: Array = []
			for c in free.keys():
				var cv: Vector2i = c
				var x := -hw + (cv.x + 0.5) * G
				var z := -hd + (cv.y + 0.5) * G
				if f == 0 and absf(x) < 0.5 and z > hd - 0.9:
					seeds.append(cv)
				elif f > 0 and not st.is_empty() and z > float(st.z1) and z < float(st.zc) - 0.2:
					seeds.append(cv)
			var seen := {}
			var stack: Array = seeds.duplicate()
			for sd in seeds:
				seen[sd] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = c + dlt
					if free.has(nb) and not seen.has(nb):
						seen[nb] = true
						stack.append(nb)
			checked += 1
			if mapsel == "%s:%d" % [kind, f] and Vector2(h.global_position.x, h.global_position.z).distance_to(Terrain.VILLAGE_POS) < 150.0:
				for iz in nz:
					var line := ""
					for ix in nx:
						var c := Vector2i(ix, iz)
						line += ("o" if seen.has(c) else "#") if free.has(c) else "."
					print("MAP ", line)
				print("MAP st ", st, " hw ", hw, " hd ", hd)
				mapsel = "done"
			if seeds.is_empty():
				bad += 1
				_say("ROOM FAIL %s at %s floor %d: no free space at the %s" % [kind, _v(h.global_position), f, "door" if f == 0 else "corridor"])
				continue
			# the foot of the stairs must be reachable from the door
			if f == 0 and not st.is_empty():
				var fx := (float(st.xb) + float(st.xa)) * 0.5
				var fz := (float(st.z0) + float(st.z1)) * 0.5
				var fc := Vector2i(int((fx + hw) / G), int((fz + hd) / G))
				var near := false
				for dx in range(-3, 4):
					for dz in range(-3, 4):
						if seen.has(fc + Vector2i(dx, dz)):
							near = true
				if not near:
					bad += 1
					_say("ROOM FAIL %s at %s: the foot of the stairs (local %.1f, %.1f) cannot be reached" % [kind, _v(h.global_position), fx, fz])
					player.global_position = h.global_transform * Vector3(fx, Chalet.Y0, fz + 1.5) + Vector3(0, 0.1, 0)
					player.rotation.y = h.global_rotation.y + PI * 0.5
					await _wait(0.6)
					await _shot("stairs")
			# free patches the flood did not reach
			var left := {}
			for c in free.keys():
				if not seen.has(c):
					left[c] = true
			while not left.is_empty():
				var first: Vector2i = left.keys()[0]
				var comp: Array = [first]
				left.erase(first)
				var i := 0
				while i < comp.size():
					var c: Vector2i = comp[i]
					i += 1
					for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nb: Vector2i = c + dlt
						if left.has(nb):
							left.erase(nb)
							comp.append(nb)
				if comp.size() * G * G < 3.0:
					continue
				var mid := Vector2.ZERO
				for c in comp:
					mid += Vector2(c)
				mid /= comp.size()
				var lp := Vector3(-hw + (mid.x + 0.5) * G, yf, -hd + (mid.y + 0.5) * G)
				bad += 1
				_say("ROOM FAIL %s at %s floor %d: %.1f m2 cut off around local (%.1f, %.1f) world %s" % [kind, _v(h.global_position), f, comp.size() * G * G, lp.x, lp.z, _v(h.global_transform * lp)])
				if bad <= 14:
					player.global_position = h.global_transform * lp + Vector3(0, 0.1, 0)
					player.rotation.y = h.global_rotation.y
					await _wait(0.6)
					await _shot("room")
	_say("ROOMTEST %d floors checked, %d cut-off places" % [checked, bad])


func _houses(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Node3D and c.has_meta("floors") and c.has_meta("size"):
			out.append(c)
		else:
			_houses(c, out)



## Only the robot plays: any other event (a pad that drifts, a key pressed in another window)
## is dropped before the player sees it.
func _input(event: InputEvent) -> void:
	if event.device != ROBOT:
		get_viewport().set_input_as_handled()


## A walkable path from `a` to `b`, baked on the spot from the static colliders in a box round
## both points (agent: the player's capsule, steps up to 0.45 m, slopes up to 45°).
func _nav_path(a: Vector3, b: Vector3, slope := 45.0) -> PackedVector3Array:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3(30, 25, 30)
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3(30, 25, 30)
	if (hi - lo).x > 260.0 or (hi - lo).z > 260.0:
		return PackedVector3Array()      # too far for one bake: walk closer first
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 3
	nm.filter_baking_aabb = AABB(lo, hi - lo)
	nm.cell_size = 0.2
	nm.cell_height = 0.1
	nm.agent_radius = 0.3
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = slope
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, main)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	if nm.get_polygon_count() == 0:
		_say("  (the walk mesh is empty)")
		return PackedVector3Array()
	# a region node on the world's own navigation map (the plain server map never synced here)
	var map := player.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	await main.get_tree().physics_frame
	var it0 := NavigationServer3D.map_get_iteration_id(map)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	main.add_child(region)
	for i in 30:
		await main.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > it0 + 1:
			break
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	for i in 60:
		if path.size() > 1:
			break
		await main.get_tree().physics_frame
		path = NavigationServer3D.map_get_path(map, a, b, true)
	if "--navdebug" in OS.get_cmdline_user_args():
		var vs := nm.get_vertices()
		_say("  navdebug server active=%s maps=%d regions_on_map=%d iter=%d first vert=%s" % [str(NavigationServer3D.get_process_info(NavigationServer3D.INFO_ACTIVE_MAPS)), NavigationServer3D.get_maps().size(), NavigationServer3D.map_get_regions(map).size(), NavigationServer3D.map_get_iteration_id(map), str(vs[0]) if vs.size() > 0 else "-"])
	if "--navdebug" in OS.get_cmdline_user_args():
		_say("  navdebug polys=%d closest a=%s b=%s path=%d" % [nm.get_polygon_count(), _v(NavigationServer3D.map_get_closest_point(map, a)), _v(NavigationServer3D.map_get_closest_point(map, b)), path.size()])
	main.remove_child(region)
	region.free()
	await main.get_tree().physics_frame
	return path


func _open_sky(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.8, 0), at + Vector3(0, 60.0, 0))
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _face(at: Vector3) -> void:
	var f := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
	player.rotation.y = atan2(-f.x, -f.y)
	player._pitch = 0.0


## A closed gate within reach that is barred from the side the robot stands on.
func _inside_gate(p: Vector3, to: Vector3) -> Node3D:
	for n in get_tree().get_nodes_in_group("gated"):
		if not (n is Breakable) or n.broken or n.inside == Vector3.ZERO:
			continue
		var g: Vector3 = n.global_position
		if Vector2(g.x - p.x, g.z - p.z).length() > 75.0:
			continue
		var side: Vector3 = n.global_basis * n.inside
		if (p - g).dot(side) > 0.0 and (to - g).dot(side) < 0.0:
			return n
	return null


# ------------------------------------------------------------------ reach test

## Fast check of the whole story without playing it: for every step of every chapter, can a
## player get from where the last step ended to this step's goal? Paths come from walk meshes
## baked from the world's colliders (doors and barriers counted as open: keys and tools are the
## story test's job). A leg that fails on foot is tried again with steep ground climbable.
func reach_test() -> void:
	main.enemies.spawn_all()
	main.bosses.wake()
	await _wait(1.0)
	main.start_new_game()
	await _wait(1.0)
	if main.get("story"):
		main.story.set_process(false)
		if main.story.visible:
			main.story.visible = false
	if main.quests.status(Quests.first_chapter()) != "active":
		main.quests.accept(Quests.first_chapter())
	_open_all()
	var at: Vector3 = player.global_position
	var bad := 0
	var legs := 0
	var t0 := Time.get_ticks_msec()
	# a range of chapters (for running several in parallel): --reachfrom=main_4 --reachto=main_5
	var from := ""
	var upto := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reachfrom="):
			from = arg.get_slice("=", 1)
		if arg.begins_with("--reachto="):
			upto = arg.get_slice("=", 1)
	var live := from == ""
	_cache_load()
	for guard in 200:
		var q := ""
		for id in Quests.DEFS:
			if Quests.DEFS[id].get("main", false) and Quests.in_mode(id) and main.quests.status(id) == "active":
				q = id
				break
		if q == "":
			break
		var st: Dictionary = main.quests._step(q)
		var kind := str(st.get("kind", ""))
		var tgt: Vector3 = main.quests.target(q)
		if tgt == Vector3.INF and kind == "choice":
			var who := str((st.get("options", {}) as Dictionary).keys()[0])
			var np: Npc = main._npc(who)
			tgt = np.global_position if np else Vector3.INF
		if tgt == Vector3.INF and kind == "talk":
			# hidden talk steps (h_5: follow the crying) have no map marker on purpose
			var np2: Npc = main._npc(str(st.get("npc", "")))
			tgt = np2.global_position if np2 else Vector3.INF
		if tgt == Vector3.INF and kind == "flag" and main.get("horror"):
			tgt = main.horror.target_of(str(st.get("id", "")))
		var label := "%s %s %s" % [q, kind, str(st.get("text", "")).left(60)]
		if q == from:
			live = true
		if upto != "" and live and _chapter_after(q, upto):
			break
		if tgt == Vector3.INF:
			if live:
				_say("REACH ??   %s: no goal in the world" % label)
				bad += 1
		else:
			if live:
				legs += 1
				var key := "%s|%d|%s>%s" % [q, int((main.quests.state[q] as Dictionary).get("step", 0)), _v(at), _v(tgt)]
				var how: String = _cache.get(key, "")
				var cached := how != ""
				if not cached:
					# doors swing shut and story gates appear later: a player opens them
					for n in get_tree().get_nodes_in_group("gated") + _all_doors(main):
						if n is CollisionObject3D:
							(n as CollisionObject3D).collision_layer = 0
					how = await _reach(at, tgt)
					_cache[key] = how
					_cache_save()
				_say("REACH %s %s  (%s -> %s)%s" % [how, label, _v(at), _v(tgt), "  [unchanged code, from yesterday's run]" if cached else ""])
				if how == "NO  ":
					bad += 1
			at = tgt
			# standing at the station side of the Eisklamm: lower the emergency span, as a
			# player would for the way back (the lever hut is next to the station)
			var lv: Lever = main.places.bridge_lever
			if lv and not lv.pulled and lv.global_position.distance_to(tgt) < 120.0:
				lv.pulled = true
				main.places.span.rotation.x = 0.0
				if live:
					_say("REACH      (pulled the emergency span lever on the station side)")
			player.global_position = tgt + Vector3(0, 0.5, 0)
			player.velocity = Vector3.ZERO
		# finish the step the way the game would
		if kind == "places":
			for i in st["ids"]:
				if not str(i) in main.places.found:
					main.places.found.append(str(i))
		elif kind == "read":
			for i in st["ids"]:
				if not str(i) in main.reader.found:
					main.reader.found.append(str(i))
		elif kind == "kill":
			for i in st["ids"]:
				if not str(i) in main.enemies.dead:
					main.enemies.dead.append(str(i))
		elif kind == "choice":
			main.player.inv.add(str(st["item"]), 1)
		var before: int = int((main.quests.state[q] as Dictionary).get("step", 0))
		main.quests._advance(q)
		await get_tree().physics_frame
		if main.quests.status(q) == "active" and int((main.quests.state[q] as Dictionary).get("step", 0)) == before:
			_say("REACH ??   %s: the step does not advance" % label)
			bad += 1
			break
	_say("REACH DONE%s: %d legs, %d problems, %d s" % ["" if from == "" else " " + from + ".." + upto, legs, bad, (Time.get_ticks_msec() - t0) / 1000])


var _cache := {}
var _cache_file := ""


## Leg results are kept per chapter range, together with a fingerprint of every game script:
## change any of them and the old results are thrown away, so a resumed run is as good as new.
func _cache_load() -> void:
	var tag := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reachfrom="):
			tag = arg.get_slice("=", 1)
	_cache_file = "user://reach_cache_%s_%s.json" % ["horror" if GameMode.horror() else GameMode.season, tag]
	var sig := _code_sig()
	_cache = {}
	if FileAccess.file_exists(_cache_file):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_cache_file))
		if typeof(d) == TYPE_DICTIONARY and str((d as Dictionary).get("sig", "")) == sig:
			_cache = (d as Dictionary).get("legs", {})
	_cache["__sig"] = sig


func _cache_save() -> void:
	var legs := _cache.duplicate()
	var sig: String = legs["__sig"]
	legs.erase("__sig")
	var f := FileAccess.open(_cache_file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sig": sig, "legs": legs}))


static func _code_sig() -> String:
	var acc := ""
	for dir in ["res://world", "res://builders", "res://ai", "res://core", "res://player", "res://assets/models"]:
		acc += _dir_sig(dir)
	return str(acc.hash())


static func _dir_sig(dir: String) -> String:
	var acc := ""
	var da := DirAccess.open(dir)
	if da == null:
		return ""
	for f in da.get_files():
		if f.ends_with(".gd") or f.ends_with(".glb") or f.ends_with(".gdshader"):
			acc += "%s%d" % [f, FileAccess.get_modified_time(dir + "/" + f)]
	for sub in da.get_directories():
		acc += _dir_sig(dir + "/" + sub)
	return acc


## True when chapter q comes after chapter upto in the story chain.
func _chapter_after(q: String, upto: String) -> bool:
	var c := Quests.first_chapter()
	var passed := false
	for i in 30:
		if c == q:
			return passed
		if c == upto:
			passed = true
		c = str(Quests.DEFS.get(c, {}).get("next", ""))
		if c == "":
			return false
	return false


## "walk", "climb" or "NO  ": whether a player gets from a to b. Inside a house the leg runs
## from its front door (the room test proves every room reaches its front door).
func _reach(a: Vector3, b: Vector3) -> String:
	# out to the White One's floe in summer: by the fishers' pier, like a player
	var pier: Array = main.lake.pier if main.get("lake") else []
	if not pier.is_empty() and GameMode.summer():
		var on_a := Lake.hole(Vector2(a.x, a.z)) > 0.0 and a.y < Terrain.LAKE_LEVEL + 2.0
		var on_b := Lake.hole(Vector2(b.x, b.z)) > 0.0 and b.y < Terrain.LAKE_LEVEL + 2.0
		if on_a != on_b:
			var x: Vector3 = pier[1]
			var y: Vector3 = pier[0]
			var r1 := await _reach_plain(b if on_a else a, x)
			var r2 := await _reach_plain(y, a if on_a else b)
			if r1 != "NO  " and r2 != "NO  ":
				return "climb" if "climb" in [r1, r2] else "walk"
	return await _reach_plain(a, b)


func _reach_plain(a: Vector3, b: Vector3) -> String:
	# the plain way first; the stand-ins (a free spot by a person, a front door) only when
	# that fails — same answer, far fewer bakes
	if await _reach_once(a, b, 45.0):
		return "walk"
	var starts := [a]
	var goals := [b]
	for pair in [[a, starts], [b, goals]]:
		var fr := await _free_spot(pair[0])
		if fr != Vector3.INF:
			pair[1].append(fr)
		# every door close by, not only the nearest (a back door may open on a closed yard)
		for d in _doors:
			var c: Vector3 = d[0]
			var pp: Vector3 = pair[0]
			if Vector2(c.x - pp.x, c.z - pp.z).length() < 14.0 and absf(c.y - pp.y) < 3.5:
				var n: Vector3 = d[1]
				if n.dot(pp - c) > 0.0:
					n = -n
				pair[1].append(c + n * 1.8)
	for slope: float in [45.0, 80.0]:
		for s0 in starts:
			for g0 in goals:
				if slope < 50.0 and s0 == a and g0 == b:
					continue
				if await _reach_once(s0, g0, slope):
					return "walk" if slope < 50.0 else "climb"
	return "NO  "


## A point a few metres off that the walk mesh really connects to p (people stand among
## props and stalls, where the mesh is broken into scraps that a walker steps over).
func _free_spot(p: Vector3) -> Vector3:
	for r: float in [4.0, 7.0]:
		for q in 8:
			var a := q * TAU / 8.0
			var t := p + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var sp := player.get_world_3d().direct_space_state
			var ray := PhysicsRayQueryParameters3D.create(t + Vector3(0, 3.0, 0), t - Vector3(0, 4.0, 0))
			ray.collision_mask = 1
			var hit := sp.intersect_ray(ray)
			if hit.is_empty():
				continue
			t = hit["position"]
			var path := await _nav_path(t, t + (p - t).normalized() * 0.5, 45.0)
			if path.size() > 1 and (path[path.size() - 1] as Vector3).distance_to(t) > 0.2:
				# connected around t, and the mesh there is more than a scrap: walk it toward p
				var back := await _nav_path(t, p, 45.0)
				if back.size() > 1 and (back[back.size() - 1] as Vector3).distance_to(p) < 3.0:
					return t
	return Vector3.INF


func _reach_once(a: Vector3, b: Vector3, slope: float) -> bool:
	var cur := a
	var seen := {}
	var prog := 1e9
	var stall := 0
	for leg in 30:
		var flat := Vector2(b.x - cur.x, b.z - cur.z)
		if flat.length() <= 110.0:
			var path := await _nav_path(cur, b, slope)
			if path.size() > 1:
				var e: Vector3 = path[path.size() - 1]
				if Vector2(e.x - b.x, e.z - b.z).length() < 4.0 and absf(e.y - b.y) < 3.0:
					return true
		# a 100 m leg towards the goal; if that gets nowhere, the same leg turned aside (round
		# a ridge, a lake, a fence) — keep whichever end comes closest to the goal
		var best := Vector3.INF
		var best_d := 1e9
		for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
			var d2 := flat.normalized().rotated(turn) * minf(100.0, flat.length())
			var goal := Vector3(cur.x + d2.x, 0.0, cur.z + d2.y)
			goal.y = main.terrain.surface_at(goal.x, goal.z)
			var path := await _nav_path(cur, goal, slope)
			if path.size() < 2:
				continue
			var end: Vector3 = path[path.size() - 1]
			var key := "%d,%d" % [int(end.x / 12.0), int(end.z / 12.0)]
			if end.distance_to(cur) < 15.0 or seen.has(key):
				continue
			var dd := Vector2(b.x - end.x, b.z - end.z).length()
			if dd < best_d:
				best_d = dd
				best = end
			if turn == 0.0 and dd < flat.length() - 30.0:
				break      # straight on works well enough
		if "--reachdebug" in OS.get_cmdline_user_args():
			_say("   leg %d slope %d from %s best %s (%.0f m to go)" % [leg, int(slope), _v(cur), _v(best) if best != Vector3.INF else "-", best_d])
		if best == Vector3.INF:
			return false
		# going round in circles (a ravine without the bridge in the mesh): give up early
		if best_d < prog - 10.0:
			prog = best_d
			stall = 0
		else:
			stall += 1
			if stall >= 3 and slope < 50.0:
				return false
		seen["%d,%d" % [int(best.x / 12.0), int(best.z / 12.0)]] = true
		cur = best
	return false


func _open_all() -> void:
	for n in get_tree().get_nodes_in_group("gated"):
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0
	for d in _all_doors(main):
		(d as CollisionObject3D).collision_layer = 0
	var near := []
	for d in _all_doors(main):
		if (d as Node3D).global_position.distance_to(player.global_position) < 15.0:
			near.append("%s %s" % [(d as Node).get_class(), _v((d as Node3D).global_position)])
	_say("  opened all; doors near start: %s" % ", ".join(near))
	if "--floorprobe" in OS.get_cmdline_user_args():
		var c := player.global_position
		var sp := player.get_world_3d().direct_space_state
		for zi in range(-16, 17):
			var row := ""
			for xi in range(-16, 17):
				var x := c.x + xi * 0.5
				var z := c.z + zi * 0.5
				var q := PhysicsRayQueryParameters3D.create(Vector3(x, c.y + 2.5, z), Vector3(x, c.y - 6.0, z))
				q.collision_mask = 1
				var r := sp.intersect_ray(q)
				if r.is_empty():
					row += " ."
				else:
					var dh: float = (r["position"] as Vector3).y - c.y
					row += "%2d" % clampi(int(round(dh * 4.0)), -9, 99) if dh < 2.4 else " #"
			_say("  P %s" % row)
