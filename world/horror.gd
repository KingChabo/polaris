class_name Horror
extends Node
## Horror mode: the same valley, but the lights are failing, the people have hidden, and
## something tall walks in the fog that only moves while you look away.
## This node darkens the world, plays the sound bed, sends the Hollow after you, stages
## small scares, and owns the puzzles that bring the hidden people back.

const CODE := "4719"
const RADIO_CODE := "3186"
const BOX_ORDER := ["star", "swan", "bear"]
const BOX_PITCH := {"star": 1.5, "swan": 1.0, "bear": 0.62}

const NOTES := {
	"h_note_square": ["Pinned to the tree", "To whoever came back on the bus —\n\nWe are not dead. We are hiding.\n\nIt came out of the fog the night the tunnel fell. Tall. No face. It does not walk when you watch it. Do not look away from it. Do not turn your back.\n\nLIGHT hurts it. A torch held on it, a flare, a fire. Keep your light on it until it goes.\n\nThe power is out. The fuse box is behind the hotel; the fuses are gone — somebody took them to the station, the chapel and the west street. If the lights come back on, we can come out.\n\n— H."],
	"h_note_toys": ["Lena's note, in the hotel", "I locked myself into the back room of the shop. The door has a number lock, my father's idea.\n\nI never remember numbers, so I painted them where I would see them every day: by the loudspeakers, the ones that still sing. The Roman number says which one comes first.\n\nIf you find this, come and get me. Please. It stands outside the window at night.\n\n— Lena"],
	"h_note_boxes": ["Nailed to the chapel door", "Father Aurel has barred himself in. He says the bell must not ring until the music is right.\n\nThree music boxes stand in the street, on the doorsteps where the children left them.\n\nFirst the star that showed the way,\nthen the swan that sang upon the lake,\nand last the bear that sleeps in snow.\n\nWind them in that order. Wind them wrong and it will hear you."],
	"h_note_south": ["Nailed to the cordon barrier", "THE FOG CAME THROUGH THE TUNNEL WITH YOU.\n\nGrauwasser went dark two nights ago. We heard the siren run down like a toy.\n\nThey do not come near the siren when it sounds. The generator is in the plank hut north of the square, behind the hotel. It wants fuel — three cans. We had one.\n\nWe are not opening this barrier again."],
	"h_note_mast": ["Taped to a post at the Hochfunk", "It is in the wires. Every set in the valley whispers now.\n\nThe old emergency tone drives it out of the air. Key the regional frequency into the lock on the set and hold on.\n\nThe frequency is written in the radio log on the desk in here. I cannot remember it. I cannot remember my name.\n\n— L."],
	"h_note_mill": ["Nailed up at the sawmill", "THIS IS WHERE THEY SLEEP.\n\nThe tall ones go in at dawn and stand between the stacks, forty, fifty of them, facing the wall.\n\nFour fire baskets stand by the oil drums round the big shed. Light all four and the whole nest goes up.\n\nBring firewood. Bring every flare you have. They will wake."],
}

var main: Node
var flags := {}             # puzzle progress, saved
var fear := 0.0
var audio: HorrorAudio
var keypad: KeypadScreen
var props: Array[PuzzleProp] = []
var cry: AudioStreamPlayer3D
var _lights: Array = []     # [light, base energy, seed, kind] kind: "village" / "wild"
var _hollows: Array = []       # Hollows walking now (may hold freed ones until the next frame)
var _spawn_t := 70.0
var _event_t := 35.0
var _out_t := 0.0           # lights blacked out for this long
var _seq: Array[String] = []
var _groan_t := 6.0
var _t := 0.0
var _pad := "code"          # which lock the number pad is open for
var _siren: AudioStreamPlayer3D
var _dead_t := 0.0          # the flashlight is dead for this long
var _steps_t := 0.0         # footsteps behind you for this long
var _step_cd := 0.0
var _beat_t := 0.0          # heartbeat when it is close
var _watchers: Array = []   # [figure, seconds left, kind] — things that stand and look at you
var _writings: Array = []
const WRITING := ["TURN AROUND", "IT SEES YOU", "WHY DID YOU COME BACK", "DONT LOOK AT IT", "IT IS IN THE HOUSE",
	"WE HEAR IT UNDER THE FLOOR", "MIRJA IS NOT MIRJA", "KEEP THE LIGHT ON", "IT WEARS THEIR FACES", "HELP US"]


func build(m: Node) -> void:
	main = m
	_atmosphere()
	_collect_lights()
	_place_props()
	_place_south()
	audio = HorrorAudio.new()
	add_child(audio)
	keypad = KeypadScreen.new()
	keypad.player = main.player
	keypad.entered.connect(_on_code)
	add_child(keypad)
	_apply_flags()
	main.player.flashlight.visible = true     # you will want it


# ---------------------------------------------------------------- the dark valley

func _atmosphere() -> void:
	var env: Environment = main.env
	env.ambient_light_color = Color(0.11, 0.13, 0.19)
	env.ambient_light_energy = 0.42
	env.tonemap_exposure = 1.18
	env.fog_light_color = Color(0.035, 0.04, 0.055)
	env.volumetric_fog_albedo = Color(0.62, 0.64, 0.68)
	env.volumetric_fog_length = 150.0
	env.glow_intensity = 0.85
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.08
	var sky_mat := env.sky.sky_material as ShaderMaterial
	sky_mat.set_shader_parameter("horror", 1.0)
	sky_mat.set_shader_parameter("aurora_strength", 0.7)
	if main.get("sun"):
		main.sun.light_energy = 0.38
		main.sun.light_color = Color(0.55, 0.58, 0.72)
	if main.get("aurora_light"):
		main.aurora_light.light_color = Color(0.9, 0.2, 0.15)
		main.aurora_light.light_energy = 0.05
	var w: Weather = main.weather
	w.fog_add = 0.026
	w.haze_add = 0.003
	w.calm_glow = Color(0.008, 0.009, 0.013)
	w.storm_floor = 0.2
	w.target_storm = 0.3
	# lit windows and street lamps burn low
	_window_glow(0.22)
	# the loudspeakers play the carol slow and low, like a tape running down
	for c in main.village.get_children():
		if c is AudioStreamPlayer3D:
			var a := c as AudioStreamPlayer3D
			a.pitch_scale *= 0.7 if a.stream == Synth.music() else 0.6
			a.volume_db -= 2.0
	_bulbs(0.12, 0.6)


func _window_glow(k: float) -> void:
	for n in ["glass_lit", "glass_lit2", "lamp_sodium", "lamp_glow", "lamp_white"]:
		var m := Mats.get_mat(n) as StandardMaterial3D
		if m:
			if not m.has_meta("base"):
				m.set_meta("base", m.emission_energy_multiplier)
			m.emission_energy_multiplier = float(m.get_meta("base")) * k


func _bulbs(dim: float, broken: float) -> void:
	for c in main.village.get_children():
		if c is MultiMeshInstance3D:
			var mm := (c as MultiMeshInstance3D).multimesh
			if mm and mm.mesh and mm.mesh.surface_get_material(0) is ShaderMaterial:
				var sm := mm.mesh.surface_get_material(0) as ShaderMaterial
				sm.set_shader_parameter("dim", dim)
				sm.set_shader_parameter("broken", broken)


func _collect_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	for owner_node: Node in [main.village, main.places, main.wilds]:
		for l in owner_node.find_children("*", "Light3D", true, false):
			var light := l as Light3D
			_lights.append([light, light.light_energy, rng.randf() * 100.0, "village" if owner_node == main.village else "wild", rng.randf()])
	_set_power(false)


## Before the fuse box is fixed most lamps are dead and the rest stutter; after, most come back.
func _set_power(on: bool) -> void:
	for e in _lights:
		var light: Light3D = e[0]
		if not is_instance_valid(light):
			continue
		var r: float = e[4]
		if str(e[3]) == "village":
			light.visible = r < (0.75 if on else 0.3)
		else:
			light.visible = r < 0.45
	_window_glow(0.85 if on else 0.22)
	_bulbs(0.55 if on else 0.12, 0.3 if on else 0.6)


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_t += delta
	_flicker(delta)
	var p: Vector3 = main.player.global_position
	# fear: how close the nearest Hollow is, whether you can see it, and any fight going on
	var want := 0.08
	for hv in get_tree().get_nodes_in_group("hollow"):
		var h := hv as Hollow
		if h.state == "stalk":
			var f := clampf(1.0 - (h.dist - 2.0) / 42.0, 0.0, 1.0)
			if h.seen:
				f = minf(f + 0.25, 1.0)
			want = maxf(want, f)
	if main.get("mood"):
		want = maxf(want, main.mood.level * 0.45)
	fear = move_toward(fear, want, delta * (0.9 if want > fear else 0.18))
	audio.fear = fear
	if main.get("post"):
		main.post.fear = fear * 0.85
	# your own heart, loud in your ears when it is close
	_beat_t -= delta
	if fear > 0.4 and _beat_t <= 0.0:
		_beat_t = lerpf(1.05, 0.42, clampf((fear - 0.4) / 0.6, 0.0, 1.0))
		Sfx.play_flat(main, "heartbeat", lerpf(-14.0, -2.0, fear), 1.0)
	_watch(delta)
	if not _story_running():
		return
	_spawn_t -= delta
	_event_t -= delta
	_hollows = _hollows.filter(func(h: Variant) -> bool: return is_instance_valid(h))
	var late: bool = main.quests.status("h_7") == "done"
	var limit := 3 if late else (2 if main.quests.status("h_3") == "done" else 1)
	if _spawn_t <= 0.0 and _hollows.size() < limit and _can_spawn(p):
		var first := spawn_hollow(false)
		# later on they come in pairs: one where you look, one where you do not
		if first and late and _hollows.size() < limit and randf() < 0.6:
			var keep := _spawn_t
			spawn_hollow(false, PI)
			_spawn_t = keep
	if _event_t <= 0.0:
		_event_t = randf_range(8.0, 20.0) if late else randf_range(11.0, 28.0)
		_scare_event()
	# the torch dies for a few seconds: you hear it click and nothing happens
	if _dead_t > 0.0:
		_dead_t -= delta
		main.player.flashlight.light_energy = 0.0 if fmod(_dead_t * 7.0, 1.0) < 0.82 else 2.0
		if _dead_t <= 0.0:
			main.player.flashlight.light_energy = 6.0
			Sfx.play_flat(main, "click", -4.0, 1.3)
	# steps in the snow behind you that stop when you stop
	if _steps_t > 0.0:
		_steps_t -= delta
		_step_cd -= delta
		var moving: bool = main.player.velocity.length() > 1.0
		if _step_cd <= 0.0 and moving:
			_step_cd = 0.46
			var behind: Vector3 = main.player.camera.global_basis.z
			Sfx.play(main, "thud", p + Vector3(behind.x, 0, behind.z).normalized() * 4.5, -3.0, randf_range(1.5, 1.8))
	# the Frozen groan when they are near
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(4.0, 9.0)
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Raider and (e as Raider).state != "dead" and (e as Node3D).global_position.distance_to(p) < 35.0:
				Sfx.play(main, "groan", (e as Node3D).global_position + Vector3(0, 1.6, 0), -2.0, randf_range(0.8, 1.1))
				break


func _story_running() -> bool:
	return main.quests.main_quest() != "" and not main.player.ui_open


func _can_spawn(p: Vector3) -> bool:
	if Places.underground(p) or fire_near(p, 14.0):
		return false
	if main.player.vehicle != null:
		return false
	return true


func _flicker(delta: float) -> void:
	_out_t = maxf(_out_t - delta, 0.0)
	var p: Vector3 = main.player.global_position
	for e in _lights:
		var light: Light3D = e[0]
		if not is_instance_valid(light) or not light.visible:
			continue
		if light.global_position.distance_squared_to(p) > 120.0 * 120.0:
			continue
		var base: float = e[1]
		var sd: float = e[2]
		var slow := sin(_t * 0.6 + sd) * sin(_t * 0.19 + sd * 2.0)
		var k := 1.0
		if slow > 0.25:
			k = 0.2 + 0.8 * float(fmod(_t * 19.0 + sd, 1.0) > 0.45)
		if slow > 0.75:
			k = 0.03
		if _out_t > 0.0 and light.global_position.distance_to(p) < 45.0:
			k = 0.0
		light.light_energy = base * k


## True where the Hollow will not come close: by a burning fire basket, or indoors once the power is back.
func safe_at(pos: Vector3) -> bool:
	if fire_near(pos, 9.0):
		return true
	if bool(flags.get("siren", false)) and Vector2(pos.x - SiteSouth.TOWN.x, pos.z - SiteSouth.TOWN.y).length() < 75.0:
		return true      # the siren keeps them out of the square
	return bool(flags.get("power", false)) and main.village.shelter_at(pos) > 0 and Vector2(pos.x - Terrain.VILLAGE_POS.x, pos.z - Terrain.VILLAGE_POS.y).length() < 160.0


func fire_near(pos: Vector3, reach: float) -> bool:
	for pr in props:
		if pr.kind == "brazier" and pr.done and pr.global_position.distance_to(pos) < reach:
			return true
	return false


# ---------------------------------------------------------------- the Hollow

## Puts a Hollow behind you in the fog. A glimpse only stands and watches, then is gone.
func spawn_hollow(glimpse: bool, turn := 0.0) -> Hollow:
	var pl: Player = main.player
	var fwd := -pl.camera.global_basis.z
	var back := Vector2(-fwd.x, -fwd.z).normalized()
	if back == Vector2.ZERO:
		back = Vector2(0, 1)
	var best := Vector3.INF
	for i in 10:
		var a := randf_range(-0.9, 0.9) + turn if not glimpse else randf_range(-0.5, 0.5) + PI
		var r := randf_range(34.0, 46.0) if not glimpse else randf_range(38.0, 52.0)
		var d := back.rotated(a) * r
		var c := Vector3(pl.global_position.x + d.x, 0, pl.global_position.z + d.y)
		if main.village.shelter_at(c) > 0 or absf(c.x) > Terrain.HALF - 20.0 or c.z < -Terrain.HALF + 20.0 or c.z > Terrain.Z_MAX - 20.0:
			continue
		best = c
		break
	if best == Vector3.INF:
		_spawn_t = 10.0
		return null
	var h := Hollow.new()
	h.setup(main)
	if main.quests.status("h_7") == "done":
		h.haste = 1.25
		h.hp = 320.0
	main.add_child(h)
	h.place(best)
	if glimpse:
		h.set_meta("glimpse", true)
	h.gone.connect(_on_gone.bind(h))
	_hollows.append(h)
	_spawn_t = randf_range(50.0, 90.0)
	return h


func _on_gone(how: String, h: Variant) -> void:
	_hollows.erase(h)
	match how:
		"struck":
			_spawn_t = maxf(_spawn_t, randf_range(55.0, 85.0))
		"light", "flare", "fire", "shot":
			_spawn_t = maxf(_spawn_t, randf_range(35.0, 65.0))
			main.player.message.emit("It is gone. For now.")
		_:
			_spawn_t = maxf(_spawn_t, 20.0)


## Something small and wrong: whispers behind you, knocking, the lamps dying, a shape far off.
func _scare_event() -> void:
	var pl: Player = main.player
	var p := pl.global_position
	var back := pl.camera.global_basis.z
	match randi() % 15:
		9:
			_figure_far()
		10:
			_blood_writing()
		11:
			_behind_you()
		12:
			_slam_door()
		13:
			Sfx.play(main, "static", p + back * 3.0 + Vector3(0, 1.2, 0), 3.0, randf_range(0.8, 1.0))
			pl.message.emit("... a radio somewhere behind you. A voice that says your name.")
		14:
			_blood_trail()
		5:
			# the torch gives out
			if pl.flashlight.visible and _dead_t <= 0.0:
				_dead_t = randf_range(2.2, 4.5)
				Sfx.play_flat(main, "click", -2.0, 0.6)
				Sfx.play(main, "whisper", p + back * 1.5 + Vector3(0, 1.6, 0), 4.0, 0.7)
		6:
			# a door near you opens by itself
			var doors: Array = []
			_doors(main, doors)
			var best: Door = null
			var bd := 16.0
			for dv in doors:
				var d := dv as Door
				var dd := d.global_position.distance_to(p)
				if dd < bd and dd > 2.5 and not (d is LockDoor and (d as LockDoor).locked):
					bd = dd
					best = d
			if best:
				best.interact(pl)
				Sfx.play(main, "knock", best.global_position + Vector3(0, 1.4, 0), 3.0, 0.7)
			else:
				Sfx.play(main, "knock", p + back * 6.0 + Vector3(0, 1.5, 0), 4.0, 0.8)
		7:
			_steps_t = randf_range(8.0, 14.0)
		8:
			# every lamp dies at once, and something breathes
			_out_t = 5.0
			Sfx.play(main, "groan", p + back * 3.0 + Vector3(0, 1.8, 0), 3.0, 0.55)
			if main.get("post"):
				main.post.flash(Color(0.0, 0.0, 0.0), 0.5)
		0:
			Sfx.play(main, "whisper", p + back * 2.5 + Vector3(0, 1.6, 0), 2.0, randf_range(0.8, 1.1))
		1:
			Sfx.play(main, "knock", p + back.rotated(Vector3.UP, randf_range(-1.0, 1.0)) * 9.0 + Vector3(0, 1.5, 0), 4.0, randf_range(0.85, 1.0))
		2:
			_out_t = 2.5
			Sfx.play(main, "buzz", p + Vector3(0, 3, 0), -4.0, 0.7)
		3:
			if _hollows.is_empty():
				var h := spawn_hollow(true)
				if h:
					_spawn_t = randf_range(30.0, 50.0)
		4:
			Sfx.play(main, "scream", p + back.rotated(Vector3.UP, randf_range(-2.0, 2.0)) * 70.0 + Vector3(0, 4, 0), -2.0, randf_range(0.5, 0.65))


## A tall dark shape that stands and watches: at the end of a street, between trees, in a
## doorway. It is gone the moment you look straight at it.
func _make_figure() -> Node3D:
	var look := {"coat": "black", "trousers": "black", "hat": "none", "hair": "black", "skin": "frost_skin", "pack": false, "tall": 1.18}
	var f: Node3D = Humanoid.build(look)
	f.scale = Vector3(0.95, 1.18, 0.95)
	# arms hang too long, head tilted
	var head: Node3D = f.get_meta("head")
	head.rotation.z = 0.35
	for side in ["arm_l", "arm_r"]:
		var arm: Node3D = f.get_meta(side)
		arm.scale = Vector3(1, 1.35, 1)
	# two pale points where eyes should be
	for x in [-0.035, 0.035]:
		var e := OmniLight3D.new()
		e.light_color = Color(0.9, 0.95, 1.0)
		e.light_energy = 0.4
		e.omni_range = 0.25
		head.add_child(e)
		e.position = Vector3(x, 0.13, -0.09)
	main.add_child(f)
	return f


func _figure_far() -> void:
	var pl: Player = main.player
	var fwd := -pl.camera.global_basis.z
	fwd.y = 0.0
	# off to one side of where you look, far enough to be unsure
	var dir := fwd.normalized().rotated(Vector3.UP, randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0))
	var at := pl.global_position + dir * randf_range(16.0, 30.0)
	at.y = main.terrain.surface_at(at.x, at.z)
	var f := _make_figure()
	f.global_position = at
	f.look_at(Vector3(pl.global_position.x, at.y, pl.global_position.z), Vector3.UP)
	f.rotate_y(PI)
	_watchers.append([f, 14.0, "far"])


## Right behind you. If you turn round in time you see it — once, and very close.
func _behind_you() -> void:
	var pl: Player = main.player
	var back := pl.camera.global_basis.z
	back.y = 0.0
	var at := pl.global_position + back.normalized() * 1.6
	at.y = main.terrain.surface_at(at.x, at.z) if not main.village or main.village.shelter_at(pl.global_position) == 0 else pl.global_position.y
	var f := _make_figure()
	f.global_position = at
	f.look_at(Vector3(pl.global_position.x, at.y, pl.global_position.z), Vector3.UP)
	f.rotate_y(PI)
	_watchers.append([f, 4.0, "behind"])
	Sfx.play(main, "whisper", at + Vector3(0, 1.7, 0), 6.0, 0.6)


func _watch(delta: float) -> void:
	var pl: Player = main.player
	var keep: Array = []
	for w in _watchers:
		var f: Node3D = w[0]
		if not is_instance_valid(f):
			continue
		w[1] = float(w[1]) - delta
		var to := (f.global_position + Vector3(0, 1.7, 0)) - pl.camera.global_position
		var looking := (-pl.camera.global_basis.z).dot(to.normalized())
		var seen := looking > (0.985 if w[2] == "far" else 0.6)
		if seen and w[2] == "behind":
			# the scare: a scream in your face, the screen goes red, then nothing is there
			Sfx.play_flat(main, "scream", 4.0, randf_range(0.75, 0.9))
			Sfx.play_flat(main, "sting", 0.0, 0.8)
			if main.get("post"):
				main.post.flash(Color(0.6, 0.0, 0.0), 0.9)
			pl.shake(1.2)
			fear = 1.0
			f.queue_free()
			continue
		if seen or float(w[1]) <= 0.0:
			if seen:
				Sfx.play_flat(main, "sting", -6.0, randf_range(0.9, 1.1))
			f.queue_free()
			continue
		keep.append(w)
	_watchers = keep


## Letters smeared on the nearest wall beside or behind you, still wet.
func _blood_writing() -> void:
	var pl: Player = main.player
	var space := pl.get_world_3d().direct_space_state
	var from := pl.camera.global_position
	var base := pl.camera.global_basis
	for dir in [base.z, base.x, -base.x, base.z.rotated(Vector3.UP, 0.6), base.z.rotated(Vector3.UP, -0.6)]:
		var d: Vector3 = dir
		d.y = 0.0
		var q := PhysicsRayQueryParameters3D.create(from, from + d.normalized() * 7.0)
		q.collision_mask = 1
		q.exclude = [pl.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var l := Label3D.new()
		l.text = WRITING[randi() % WRITING.size()]
		l.font_size = 140
		l.pixel_size = 0.0028
		l.modulate = Color(0.38, 0.0, 0.0, 0.92)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		main.add_child(l)
		var n: Vector3 = hit["normal"]
		l.global_position = (hit["position"] as Vector3) + n * 0.015 + Vector3(0, randf_range(-0.3, 0.4), 0)
		l.look_at(l.global_position - n, Vector3.UP)
		l.rotate_object_local(Vector3.FORWARD, randf_range(-0.12, 0.12))
		# drips running down from the letters
		Fx.blood(main, l.global_position + n * 0.3, -n, false)
		Sfx.play(main, "drip", l.global_position, 0.0, 1.0)
		_writings.append(l)
		if _writings.size() > 12:
			var old: Label3D = _writings.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		return


## An open door near you is thrown shut by nobody.
func _slam_door() -> void:
	var pl: Player = main.player
	var doors: Array = []
	_doors(main, doors)
	for dv in doors:
		var d := dv as Door
		if d.is_open and d.global_position.distance_to(pl.global_position) < 14.0:
			d.interact(pl)
			Sfx.play(main, "slam", d.global_position + Vector3(0, 1.2, 0), 8.0, 0.85)
			pl.shake(0.5)
			return
	Sfx.play(main, "slam", pl.global_position + pl.camera.global_basis.z * 8.0 + Vector3(0, 1.2, 0), 4.0, 0.8)


## A trail of blood across the ground, from where you stand to somewhere you do not want to go.
func _blood_trail() -> void:
	var pl: Player = main.player
	var p := pl.global_position
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	for i in 14:
		var at := p + dir * (2.0 + i * 1.4) + Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3))
		Fx.blood(main, at, dir + Vector3(0, -1.5, 0), i % 4 == 0)


func _doors(n: Node, out: Array) -> void:
	if n is Door:
		out.append(n)
	for c in n.get_children():
		if not (c is Enemy):
			_doors(c, out)


# ---------------------------------------------------------------- puzzles

func _free_near(local: Vector2, toward: Vector2, margin := 1.4) -> Vector2:
	var v: Village = main.village
	var dir := (toward - local).normalized()
	var p := local
	for i in 80:
		if v._free(p, margin):
			return p + dir * 0.6
		p += dir * 1.0
	return p


func _add_prop(kind: String, pid: String, pos: Vector3, yaw: float, value := "") -> PuzzleProp:
	var pr := PuzzleProp.new()
	pr.horror = self
	pr.setup(kind, pid, value)
	add_child(pr)
	pr.global_position = pos
	pr.rotation.y = yaw
	props.append(pr)
	return pr


func _yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(from.x - to.x, from.z - to.z)


func _note(nid: String, pos: Vector3, yaw: float) -> void:
	var n := Note.new()
	n.id = nid
	n.add_to_group("h_note")
	n.title = str(NOTES[nid][0])
	n.text = str(NOTES[nid][1])
	n.setup("paper")
	add_child(n)
	n.global_position = pos
	n.rotation.y = yaw


func _place_props() -> void:
	var v: Village = main.village
	# chapter 1: the note at the tree
	var sq := v._w(_free_near(Vector2(5.5, 7.0), Vector2(14, 16), 0.8), 0.0)
	var crate := MeshKit.new()
	crate.bbox(Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.55), 0.03, "wood_dark")
	var cn := crate.node(true)
	add_child(cn)
	cn.global_position = sq
	_note("h_note_square", sq + Vector3(0, 0.71, 0), 0.3)
	# chapter 2: the fuse box behind the hotel, and the three fuses
	var fb := _free_near(Vector2(0, -50), Vector2(0, -20), 0.9)
	var fbp := v._w(fb)
	_add_prop("fusebox", "fusebox", fbp, _yaw_to(fbp, v._w(Vector2(0, 0))))
	var fuse_spots := [[Vector2(72, -90), Vector2(40, -70), "Station toolbox"], [Vector2(54, -58), Vector2(30, -30), "Chapel offering box"], [Vector2(-60, 26), Vector2(-60, 0), "Toolbox"]]
	for i in fuse_spots.size():
		var fs: Array = fuse_spots[i]
		var at := v._w(_free_near(fs[0], fs[1], 1.0), 0.0)
		var box := LootBox.new()
		box.setup()
		box.id = "h_fuse_%d" % i
		box.title = str(fs[2])
		box.prompt = "Search: " + str(fs[2]).to_lower()
		box.items = {"fuse": 1, "batteries": 1} if i == 0 else {"fuse": 1}
		add_child(box)
		box.global_position = at
		box.rotation.y = randf() * TAU
	# Lena's note waits inside the hotel lobby (it appears once the power is back)
	var hotel := v.houses[0] as Node3D
	_note("h_note_toys", hotel.to_global(Chalet.room(hotel, Vector3(4.6, Chalet.Y0 + 0.02, -1.2))), hotel.rotation.y)
	# chapter 3: the keypad at the toyshop, and the four boards by the loudspeakers
	var kp := v._w(_free_near(Vector2(-33, -30), Vector2(0, 0), 0.6))
	_add_prop("keypad", "keypad", kp, _yaw_to(kp, v._w(Vector2(-33, -30))) + PI)
	var boards := [[Vector2(84, 6.5), "I : 4"], [Vector2(-19, -19), "II : 7"], [Vector2(6.5, 82), "III : 1"], [Vector2(19, 19), "IV : 9"]]
	for b in boards:
		var bp: Vector2 = b[0]
		var at := v._w(bp + (Vector2.ZERO - bp).normalized() * 1.6 if bp.length() > 1.0 else bp)
		_add_prop("board", "board", at, _yaw_to(at, v._w(Vector2.ZERO)), str(b[1]))
	# chapter 4: the chapel note and three music boxes on doorsteps
	var cp := v._w(_free_near(Vector2(62, -66), Vector2(40, -44), 0.5), 0.0)
	var post := MeshKit.new()
	post.tube(Vector3.ZERO, Vector3(0, 1.0, 0), 0.06, "wood_dark", 6)
	post.box(Vector3(0, 0.95, 0), Vector3(0.4, 0.04, 0.4), "wood_dark")
	var pn := post.node(true)
	add_child(pn)
	pn.global_position = cp
	_note("h_note_boxes", cp + Vector3(0, 0.98, 0), 0.0)
	var boxes := [[Vector2(-8, 54), "bear"], [Vector2(8, 72), "star"], [Vector2(-8, 96), "swan"]]
	for b in boxes:
		var at := v._w(_free_near(b[0], Vector2(0, b[0].y), 0.5))
		_add_prop("musicbox", "box_" + str(b[1]), at, _yaw_to(at, v._w(Vector2(0, (b[0] as Vector2).y))), str(b[1]))
	# chapter 6: three fire baskets in Eisgrund, and a woodpile
	var pl: Places = main.places
	var placed: Array[Vector3] = []
	for i in 60:
		if placed.size() >= 3:
			break
		var a := i * 2.399
		var r := 9.0 + (i % 5) * 2.0
		var c := Places.SETTLE + Vector2(cos(a), sin(a)) * r
		if main.terrain.on_lake(c.x, c.y):
			continue
		var ok := true
		for cab in pl.cabins:
			var cs: Vector2 = cab.get_meta("size")
			if Vector2(cab.global_position.x, cab.global_position.z).distance_to(c) < cs.length() * 0.5 + 2.5:
				ok = false
		for q in placed:
			if Vector2(q.x, q.z).distance_to(c) < 7.0:
				ok = false
		if ok:
			placed.append(pl.gy(c))
	for i in placed.size():
		_add_prop("brazier", "brazier_%d" % i, placed[i], randf() * TAU)
	var wood := LootBox.new()
	wood.setup()
	wood.id = "h_woodpile"
	wood.title = "Woodpile"
	wood.prompt = "Search: woodpile"
	wood.items = {"firewood": 3}
	add_child(wood)
	wood.global_position = pl.gy(Places.SETTLE + Vector2(4.0, -3.0))
	# chapter 5: Annika cries in a dark cabin in the forest
	var cab := _cry_cabin()
	if cab:
		cry = AudioStreamPlayer3D.new()
		cry.stream = Sfx.stream("cry")
		cry.volume_db = 2.0
		cry.unit_size = 10.0
		cry.max_distance = 140.0
		add_child(cry)
		cry.global_position = cab.to_global(Vector3(0.5, Chalet.Y0 + 1.2, 1.2))


## The dark forest cabin closest to Eisgrund: where Annika hides.
func _cry_cabin() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for c in main.wilds.cabins:
		if bool(c.get_meta("lit")):
			continue
		var d := Vector2(c.global_position.x, c.global_position.z).distance_to(Places.SETTLE)
		if d < bd:
			bd = d
			best = c
	return best


func annika_spot() -> Array:
	var cab := _cry_cabin()
	if cab == null:
		return []
	return [cab.to_global(Vector3(0.5, Chalet.Y0 + 0.02, 1.2)), cab.rotation.y]


func _lit(prefix: String) -> int:
	var n := 0
	for q in props:
		if q.id.begins_with(prefix) and q.done:
			n += 1
	return n


## A post in the snow with a paper nailed to it.
func _post_note(nid: String, at: Vector2, yaw: float) -> void:
	var pos: Vector3 = main.places.gy(at)
	var post := MeshKit.new()
	post.tube(Vector3.ZERO, Vector3(0, 1.45, 0), 0.05, "wood_dark", 6)
	post.box(Vector3(0, 1.25, -0.06), Vector3(0.42, 0.34, 0.03), "planks_in")
	var pn := post.node(true)
	add_child(pn)
	pn.global_position = pos
	pn.rotation.y = yaw
	_note(nid, pos + Basis(Vector3.UP, yaw) * Vector3(0, 1.25, -0.085), yaw)
	var n := get_child(get_child_count() - 1) as Node3D
	n.rotation.x = PI * 0.5


## The second valley: the siren generator, the radio lock and the four fires at the sawmill.
func _place_south() -> void:
	_post_note("h_note_south", SiteSouth.CHECK + Vector2(3.5, -7.0), 0.0)
	_post_note("h_note_mast", SiteSouth.MAST + Vector2(7.6, 1.6), 0.0)
	_post_note("h_note_mill", SiteSouth.MILL + Vector2(-2.0, 27.0), PI)
	_add_prop("generator", "generator", SiteSouth.gen_pos + Vector3(-1.4, 0.08, -0.9), PI * 0.5)
	_add_prop("keypad", "radio", SiteSouth.radio_pos + Vector3(-1.1, -1.0, 0.7), PI)
	for i in SiteSouth.fire_drums.size():
		var d: Vector3 = SiteSouth.fire_drums[i]
		var out := Vector3(d.x - SiteSouth.MILL.x, 0, d.z - SiteSouth.MILL.y).normalized() * 1.6
		_add_prop("brazier", "drum_%d" % i, main.places.gy(Vector2(d.x + out.x, d.z + out.z)), i * 1.3)
	for b: Array in [["h_wood_mill", SiteSouth.MILL + Vector2(4.0, 24.0), {"firewood": 4, "flare": 2}], ["h_fuel_cordon", SiteSouth.CHECK + Vector2(-6.0, 3.0), {"fuel_can": 1, "flare": 2}],
			["h_fuel_camp", SiteSouth.CAMP + Vector2(3.0, 5.0), {"fuel_can": 1, "batteries": 2}]]:
		var box := LootBox.new()
		box.setup()
		box.id = str(b[0])
		box.title = "Abandoned pack"
		box.prompt = "Search: abandoned pack"
		box.items = b[2]
		add_child(box)
		box.global_position = main.places.gy(b[1])


func _drum_lit(_pr: PuzzleProp) -> void:
	var lit := _lit("drum_")
	if lit >= 4:
		flags["nest"] = true
		_out_t = 0.0
		Sfx.play_flat(main, "shriek", 4.0, 0.6)
		if main.get("post"):
			main.post.flash(Color(1.0, 0.55, 0.2), 1.2)
		for hv in _hollows:
			if is_instance_valid(hv):
				(hv as Hollow).banish("fire")
		main.hud.banner("THE NEST BURNS", "Nothing comes out of the smoke")
		_apply_flags()
		return
	main.player.message.emit("%d of 4 fires burning. Something wakes inside the shed." % lit)
	Sfx.play_flat(main, "scream", 0.0, 0.7)
	_out_t = 2.0
	# every fire wakes more of them
	for i in lit:
		get_tree().create_timer(2.0 + i * 3.5).timeout.connect(func() -> void:
			if not flags.get("nest", false):
				var keep := _spawn_t
				spawn_hollow(false, i * 2.1)
				_spawn_t = keep)


func _siren_on(on: bool) -> void:
	if on and _siren == null:
		_siren = Sfx.loop(main, "buzz", SiteSouth.siren_pos + Vector3(0, 8.0, 0), 2.0, 170.0)
		_siren.pitch_scale = 0.42
	elif not on and _siren:
		_siren.queue_free()
		_siren = null


func prop(pid: String) -> PuzzleProp:
	for pr in props:
		if pr.id == pid:
			return pr
	return null


func prompt_for(pr: PuzzleProp) -> String:
	match pr.kind:
		"fusebox":
			return "" if flags.get("power", false) else "Repair the fuse box (%d/3 fuses)" % int(flags.get("fuses", 0))
		"keypad":
			if pr.id == "radio":
				return "" if flags.get("radio", false) else "Key in the frequency"
			return "" if flags.get("code", false) else "Use the number lock"
		"generator":
			return "" if flags.get("siren", false) else "Fill the generator (%d/3 fuel cans)" % int(flags.get("fuel", 0))
		"musicbox":
			return "Wind the music box (%s)" % pr.value
		"brazier":
			return "" if pr.done else "Light the fire basket (firewood)"
		"board":
			return "Look at the board"
	return ""


func use(pr: PuzzleProp, who: Node3D) -> void:
	var pl: Player = main.player
	match pr.kind:
		"fusebox":
			if flags.get("power", false):
				return
			var have := pl.inv.count("fuse")
			if have <= 0:
				Sfx.play(main, "buzz", pr.global_position + Vector3(0, 1.5, 0), -6.0, 0.5)
				pl.message.emit("Three empty fuse holders. The fuses must be somewhere in town.")
				return
			pl.inv.remove("fuse", have)
			flags["fuses"] = int(flags.get("fuses", 0)) + have
			Sfx.play(main, "click", pr.global_position + Vector3(0, 1.5, 0), 0.0, 0.8)
			if int(flags["fuses"]) >= 3:
				flags["power"] = true
				pr.set_done(true)
				Sfx.play(main, "buzz", pr.global_position + Vector3(0, 1.5, 0), 4.0, 1.0)
				Sfx.play(main, "clank", pr.global_position + Vector3(0, 1.5, 0), 2.0, 0.6)
				_set_power(true)
				main.hud.banner("THE LIGHTS ARE BACK", "Somebody is moving inside the hotel")
				_apply_flags()
			else:
				pl.message.emit("%d of 3 fuses in place." % int(flags["fuses"]))
		"keypad":
			if pr.id == "radio":
				if not flags.get("radio", false):
					_pad = "radio"
					keypad.open()
			elif not flags.get("code", false):
				_pad = "code"
				keypad.open()
		"generator":
			if flags.get("siren", false):
				return
			var cans := pl.inv.count("fuel_can")
			if cans <= 0:
				Sfx.play(main, "click", pr.global_position + Vector3(0, 1.0, 0), 0.0, 0.5)
				pl.message.emit("The tank is bone dry. It wants three cans of fuel.")
				return
			var take := mini(cans, 3 - int(flags.get("fuel", 0)))
			pl.inv.remove("fuel_can", take)
			flags["fuel"] = int(flags.get("fuel", 0)) + take
			Sfx.play(main, "steam", pr.global_position + Vector3(0, 1.0, 0), 0.0, 0.8)
			if int(flags["fuel"]) >= 3:
				flags["siren"] = true
				Sfx.play(main, "clank", pr.global_position + Vector3(0, 1.0, 0), 4.0, 0.5)
				for hv in _hollows:
					if is_instance_valid(hv):
						(hv as Hollow).banish("light")
				main.hud.banner("THE SIREN", "Doors open round the square")
				_apply_flags()
			else:
				pl.message.emit("%d of 3 cans in the tank." % int(flags["fuel"]))
		"board":
			pl.message.emit("Painted on the board in red: " + pr.value)
		"musicbox":
			_wind(pr)
		"brazier":
			if pr.done:
				return
			if pl.inv.count("firewood") <= 0:
				pl.message.emit("The basket is cold and empty. It needs firewood.")
				return
			pl.inv.remove("firewood", 1)
			flags[pr.id] = true
			pr.set_done(true)
			Sfx.play(main, "ignite", pr.global_position + Vector3(0, 1, 0), 2.0, 1.0)
			var lit := 0
			if pr.id.begins_with("drum_"):
				_drum_lit(pr)
				return
			for q in props:
				if q.id.begins_with("brazier_") and q.done:
					lit += 1
			if lit >= 3:
				flags["fires"] = true
				main.hud.banner("THREE FIRES", "A door opens in Eisgrund")
				_apply_flags()
			else:
				pl.message.emit("%d of 3 fires burning." % lit)


func _on_code(code: String) -> void:
	if _pad == "radio":
		if code == RADIO_CODE:
			flags["radio"] = true
			keypad.result(true)
			Sfx.play_flat(main, "beep", 0.0, 0.5)
			Sfx.play_flat(main, "shriek", -4.0, 1.4)
			for hv in _hollows:
				if is_instance_valid(hv):
					(hv as Hollow).banish("light")
			main.hud.banner("THE EMERGENCY TONE", "The whispering stops. Somebody unlocks the bunk room")
			_apply_flags()
		else:
			keypad.result(false)
			Sfx.play(main, "whisper", main.player.global_position + main.player.camera.global_basis.z * 1.2 + Vector3(0, 1.6, 0), 6.0, 0.6)
			_dead_t = 2.5
		return
	if code == CODE:
		flags["code"] = true
		keypad.result(true)
		prop("keypad").set_done(true)
		Sfx.play(main, "clank", main.player.global_position, 0.0, 1.2)
		main.hud.banner("THE LOCK OPENS", "Lena comes out of the back room")
		_apply_flags()
	else:
		keypad.result(false)
		Sfx.play(main, "fail", main.player.global_position, -2.0, 1.0)
		if randf() < 0.35:
			Sfx.play(main, "knock", main.player.global_position - main.player.camera.global_basis.z * 2.0 + Vector3(0, 1.5, 0), 6.0, 0.8)


func _wind(pr: PuzzleProp) -> void:
	var pitch: float = BOX_PITCH.get(pr.value, 1.0)
	for i in 3:
		get_tree().create_timer(i * 0.42).timeout.connect(func() -> void:
			Sfx.play(main, "chime", pr.global_position + Vector3(0, 0.8, 0), 0.0, pitch * [1.0, 1.19, 0.94][i]))
	if flags.get("boxes", false):
		return
	_seq.append(pr.value)
	for i in _seq.size():
		if _seq[i] != BOX_ORDER[i]:
			_seq.clear()
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				Sfx.play_flat(main, "sting", -2.0)
				_out_t = 3.0
				main.player.message.emit("The music stops. Somewhere close, something laughs.")
				if _hollows.is_empty():
					spawn_hollow(false))
			return
	if _seq.size() == BOX_ORDER.size():
		flags["boxes"] = true
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			for k in 4:
				get_tree().create_timer(k * 1.6).timeout.connect(func() -> void:
					Sfx.play_flat(main, "chime", -3.0, 0.33))
			main.hud.banner("THE CHAPEL BELL", "Father Aurel unbars the door")
			_apply_flags())
	else:
		main.player.message.emit("The tune hangs in the air, waiting for the next one.")


## Brings the world in line with the flags (after a puzzle, and after loading).
func _apply_flags() -> void:
	_set_power(bool(flags.get("power", false)))
	var fb := prop("fusebox")
	if fb:
		fb.set_done(bool(flags.get("power", false)))
	var kp := prop("keypad")
	if kp:
		kp.set_done(bool(flags.get("code", false)))
	for pr in props:
		if pr.kind == "brazier":
			pr.set_done(bool(flags.get(pr.id, false)))
	var gp := prop("generator")
	if gp:
		gp.set_done(bool(flags.get("siren", false)))
	var rp := prop("radio")
	if rp:
		rp.set_done(bool(flags.get("radio", false)))
	_siren_on(bool(flags.get("siren", false)))
	# Lena's note only appears once there is light to read it by
	for n in get_children():
		if n is Note and (n as Note).id == "h_note_toys":
			(n as Note).visible = bool(flags.get("power", false))
			(n as Note).collision_layer = 1 if bool(flags.get("power", false)) else 0
	update_story()
	if main.get("people"):
		main.people.update_story(main.quests)


## Called every second by the quests: the crying only sounds while chapter 5 runs.
func update_story() -> void:
	if cry == null or not main.get("quests"):
		return
	var on: bool = main.quests.status("h_5") == "active"
	if on != cry.playing:
		if on:
			cry.play()
		else:
			cry.stop()


## Objective progress for a flag step.
func progress(flag: String) -> String:
	match flag:
		"power":
			return "  (%d/3)" % mini(int(flags.get("fuses", 0)) + main.player.inv.count("fuse"), 3)
		"fires":
			return "  (%d/3)" % _lit("brazier_")
		"siren":
			return "  (%d/3)" % mini(int(flags.get("fuel", 0)) + main.player.inv.count("fuel_can"), 3)
		"nest":
			return "  (%d/4)" % _lit("drum_")
	return ""


## Where the map points for a flag step (only where finding it is not the puzzle).
func target_of(flag: String) -> Vector3:
	match flag:
		"power":
			var fb := prop("fusebox")
			return fb.global_position if fb else Vector3.INF
		"code":
			var kp := prop("keypad")
			return kp.global_position if kp else Vector3.INF
		"fires":
			for q in props:
				if q.id.begins_with("brazier_") and not q.done:
					return q.global_position
		"nest":
			for q in props:
				if q.id.begins_with("drum_") and not q.done:
					return q.global_position
		"siren":
			var g := prop("generator")
			return g.global_position if g else Vector3.INF
		"radio":
			var r := prop("radio")
			return r.global_position if r else Vector3.INF
		"boxes":
			# a box not wound in this try (it shows where they are, not the order)
			for q in props:
				if q.id.begins_with("box_") and not q.value in _seq:
					return q.global_position
	return Vector3.INF


func to_dict() -> Dictionary:
	return flags.duplicate()


func from_dict(d: Dictionary) -> void:
	flags = d.duplicate()
	_seq.clear()
	_apply_flags()
