class_name Vehicle
extends VehicleBody3D
## One drivable vehicle. Grip and drag depend on the ground under it, it burns
## fuel, takes damage, carries cargo, and heavy ones break through thin ice.
## The front of every vehicle points to -Z.

const TYPES := {
	"snowmobile": {
		"name": "Snowmobile", "mass": 280.0, "accel": 8.5, "top": 27.0, "tank": 28.0, "use": 0.030,
		"size": Vector3(1.1, 0.75, 2.8), "wheel_r": 0.2, "track": 0.95, "base": 1.9, "steer": 0.5,
		"grip": {"ice": 0.5, "snow": 1.0, "packed": 0.9, "rock": 0.45},
		"drag": {"ice": 0.2, "snow": 0.3, "packed": 0.4, "rock": 3.0},
		"cabin": false, "winch": false, "armor": 0.0,
		"seat": Vector3(0, 1.45, 0.25), "exit": Vector3(-1.3, 0, 0.2),
	},
	"pickup": {
		"name": "Pickup truck", "mass": 2100.0, "accel": 4.6, "top": 30.0, "tank": 70.0, "use": 0.050,
		"size": Vector3(1.9, 0.85, 5.0), "wheel_r": 0.4, "track": 1.65, "base": 3.1, "steer": 0.55,
		"grip": {"ice": 0.25, "snow": 0.5, "packed": 1.0, "rock": 0.9},
		"drag": {"ice": 0.2, "snow": 2.4, "packed": 0.3, "rock": 0.8},
		"cabin": true, "winch": false, "armor": 0.2,
		"seat": Vector3(-0.42, 1.42, -0.3), "exit": Vector3(-1.9, 0, -0.3),
	},
	"offroader": {
		"name": "Off-roader", "mass": 1750.0, "accel": 5.2, "top": 26.0, "tank": 60.0, "use": 0.055,
		"size": Vector3(1.85, 0.95, 4.1), "wheel_r": 0.46, "track": 1.6, "base": 2.5, "steer": 0.6,
		"grip": {"ice": 0.35, "snow": 0.8, "packed": 1.0, "rock": 1.15},
		"drag": {"ice": 0.2, "snow": 1.6, "packed": 0.3, "rock": 0.5},
		"cabin": true, "winch": true, "armor": 0.25,
		"seat": Vector3(-0.42, 1.55, -0.1), "exit": Vector3(-1.9, 0, -0.1),
	},
	"tracked": {
		"name": "Tracked carrier", "mass": 4800.0, "accel": 3.4, "top": 12.5, "tank": 140.0, "use": 0.11,
		"size": Vector3(2.5, 1.1, 5.6), "wheel_r": 0.42, "track": 2.1, "base": 3.8, "steer": 0.5,
		"grip": {"ice": 0.7, "snow": 1.1, "packed": 1.0, "rock": 1.1},
		"drag": {"ice": 0.3, "snow": 0.5, "packed": 0.5, "rock": 0.6},
		"cabin": true, "winch": true, "armor": 0.5,
		"seat": Vector3(-0.55, 1.98, -1.5), "exit": Vector3(-2.3, 0, -1.6),
	},
}
## What the upgrades change. Each has a price: weight or speed.
const UPGRADES := {
	"snow_chains": "Snow chains",
	"armor_plates": "Armour plates",
	"aux_tank": "Extra fuel tank",
	"winch_kit": "Winch",
}
const SURFACE_NAMES := {"ice": "Ice", "snow": "Deep snow", "packed": "Packed snow", "rock": "Rock", "air": "—", "water": "Under water"}
const FRICTION := 0.5        # wheel friction at grip 1.0 (sideways grip in g; forwards it is twice that)
const CAN_LITRES := 20.0
const SCRAP_REPAIR := 25.0
const ZONE_LAYER := 4        # doors, bonnet and cargo box: seen by the look ray only

var id := ""
var type := "pickup"
var cfg: Dictionary
var world: Node              # main scene: terrain, lake, player
var fuel := 20.0
var health := 100.0
var upgrades: Array[String] = []
var lights_on := false
var sunk := false
var driver: Player
var surface := "packed"
var cargo: LootBox
var wheels: Array[VehicleWheel3D] = []

var scripted := false        # tests drive with `test_input`
var test_input := Vector3.ZERO   # x throttle, y steer (+ = right), z handbrake
var last_crash := 0.0

var _lamps: Array[SpotLight3D] = []
var _prev_vel := Vector3.ZERO
var _grace := 1.5
var _ice_t := 0.0
var _warn_cd := 0.0
var _ram_cd := 0.0
var _smoke: CPUParticles3D
var _anchor := Vector3.ZERO
var _anchor_body: Vehicle
var _winching := false
var _rope: MeshInstance3D
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _rpm := 0.0
var _thr := 0.0


func setup(vehicle_id: String, vehicle_type: String, main: Node) -> void:
	id = vehicle_id
	type = vehicle_type
	cfg = TYPES[type]
	world = main
	fuel = float(cfg["tank"]) * 0.3
	add_to_group("vehicle")
	collision_layer = 1
	collision_mask = 3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	var size: Vector3 = cfg["size"]
	var r: float = cfg["wheel_r"]
	center_of_mass = Vector3(0, r + 0.12, 0)
	angular_damp = 0.4
	add_child(VehicleMesh.body(type))

	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = r * 0.9 + size.y * 0.5
	add_child(cs)

	# wheels (hidden under skis and tracks where the model has none)
	var track: float = cfg["track"]
	var base: float = cfg["base"]
	var rows: Array[float] = [-base * 0.5, base * 0.5]
	if type == "tracked":
		rows = [-base * 0.5, 0.0, base * 0.5]
	for z in rows:
		for side in [-1.0, 1.0]:
			var w := VehicleWheel3D.new()
			var sx: float = side
			var wide := track
			if type == "snowmobile" and z > 0.0:
				wide = track * 0.55
			w.position = Vector3(sx * wide * 0.5, r + 0.26, z)
			w.wheel_radius = r
			w.wheel_rest_length = 0.26
			w.suspension_travel = 0.22
			w.suspension_stiffness = 45.0
			w.suspension_max_force = float(cfg["mass"]) * 9.8 * 2.0
			w.damping_compression = 2.2
			w.damping_relaxation = 3.2
			w.wheel_roll_influence = 0.15
			w.wheel_friction_slip = FRICTION
			w.use_as_traction = true
			w.use_as_steering = z < 0.0 or (type == "tracked" and z > 0.0)
			w.set_meta("rear", z > 0.0)
			var mesh := VehicleMesh.wheel(type, r, sx)
			if mesh:
				w.add_child(mesh)
			add_child(w)
			wheels.append(w)

	# things you can look at and use with E
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var mid_y := r + size.y * 0.5 + 0.2
	var seat: Vector3 = cfg["seat"]
	_zone("door", Vector3(-hx - 0.06, mid_y + 0.2, seat.z), Vector3(0.22, 1.3, 1.5))
	_zone("door", Vector3(hx + 0.06, mid_y + 0.2, seat.z), Vector3(0.22, 1.3, 1.5))
	_zone("service", Vector3(0, mid_y, -hz - 0.06), Vector3(size.x, 1.2, 0.22))
	cargo = LootBox.new()
	cargo.id = "cargo_" + id
	cargo.title = "%s — cargo" % cfg["name"]
	cargo.prompt = "Open cargo"
	cargo.add_to_group("loot")
	cargo.collision_layer = ZONE_LAYER
	cargo.collision_mask = 0
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(size.x, 1.2, 0.22)
	var ccs := CollisionShape3D.new()
	ccs.shape = cshape
	cargo.add_child(ccs)
	cargo.position = Vector3(0, mid_y, hz + 0.06)
	add_child(cargo)

	for sx in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		var s: float = sx
		lamp.position = Vector3(s * (hx - 0.3), r + size.y * 0.55, -hz - 0.05)
		if type == "snowmobile":
			lamp.position.x = s * 0.12
		lamp.spot_range = 70.0
		lamp.spot_angle = 34.0
		lamp.light_energy = 9.0
		lamp.light_color = Color(1.0, 0.95, 0.82)
		lamp.light_volumetric_fog_energy = 1.5
		lamp.shadow_enabled = sx < 0.0
		lamp.rotation.x = -0.06
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)

	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(0, r + size.y + 0.1, -hz * 0.7)
	_smoke.amount = 24
	_smoke.lifetime = 2.2
	_smoke.direction = Vector3.UP
	_smoke.spread = 18.0
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.4
	_smoke.gravity = Vector3(0.4, 0.6, 0.2)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.22
	puff.height = 0.44
	puff.radial_segments = 6
	puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.12, 0.12, 0.13, 0.5)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = pm
	_smoke.mesh = puff
	_smoke.emitting = false
	add_child(_smoke)

	var rope_mesh := BoxMesh.new()
	rope_mesh.size = Vector3(0.035, 0.035, 1.0)
	rope_mesh.material = Mats.get_mat("black")
	_rope = MeshInstance3D.new()
	_rope.mesh = rope_mesh
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 11025.0
	gen.buffer_length = 0.2
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = gen
	_audio.volume_db = -6.0
	_audio.unit_size = 9.0
	_audio.position = Vector3(0, 1.0, -hz * 0.6)
	add_child(_audio)
	_apply_upgrades()


func _zone(kind: String, pos: Vector3, size: Vector3) -> void:
	var z := VehicleZone.new()
	z.vehicle = self
	z.kind = kind
	z.collision_layer = ZONE_LAYER
	z.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	z.add_child(cs)
	z.position = pos
	add_child(z)


# ------------------------------------------------------------ numbers
func has_upgrade(u: String) -> bool:
	return upgrades.has(u)


func tank() -> float:
	return float(cfg["tank"]) + (40.0 if has_upgrade("aux_tank") else 0.0)


func armor() -> float:
	return minf(float(cfg["armor"]) + (0.3 if has_upgrade("armor_plates") else 0.0), 0.85)


func has_winch() -> bool:
	return bool(cfg["winch"]) or has_upgrade("winch_kit")


func top_speed() -> float:
	var t: float = cfg["top"]
	if has_upgrade("snow_chains"):
		t *= 0.88
	if has_upgrade("armor_plates"):
		t *= 0.92
	return t


func grip(on: String) -> float:
	var g := float((cfg["grip"] as Dictionary).get(on, 1.0))
	if has_upgrade("snow_chains"):
		if on == "ice":
			g *= 2.2
		elif on == "snow":
			g *= 1.35
	return g


func drag(on: String) -> float:
	var d := float((cfg["drag"] as Dictionary).get(on, 0.3))
	if has_upgrade("snow_chains") and on == "snow":
		d *= 0.7
	return d


func cargo_weight() -> float:
	var w := 0.0
	for item in cargo.items:
		w += Items.num(str(item), "w") * int(cargo.items[item])
	return w


## Everything the ice has to carry.
func total_mass() -> float:
	return mass + (80.0 if driver else 0.0)


func _apply_upgrades() -> void:
	mass = float(cfg["mass"]) + cargo_weight() \
			+ (380.0 if has_upgrade("armor_plates") else 0.0) \
			+ (25.0 if has_upgrade("snow_chains") else 0.0) \
			+ (35.0 if has_upgrade("aux_tank") else 0.0) \
			+ (60.0 if has_upgrade("winch_kit") else 0.0)
	fuel = minf(fuel, tank())


func engine_ok() -> bool:
	return health > 0.0 and fuel > 0.0 and not sunk


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func upside_down() -> bool:
	return global_basis.y.y < 0.35


# ------------------------------------------------------------ using it
func door_prompt() -> String:
	if upside_down():
		return "Turn the %s upright" % str(cfg["name"]).to_lower()
	return "Drive the %s" % str(cfg["name"]).to_lower()


func use_door(who: Player) -> void:
	if upside_down():
		if linear_velocity.length() > 1.0:
			return
		var yaw := global_rotation.y
		place(Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 0.8, 0)))
		who.message.emit("You heave it back onto its feet.")
		return
	who.enter_vehicle(self)


## What the bonnet does for you right now: [action, text].
func service_action(who: Player) -> Array:
	if who == null:
		return ["", ""]
	if health < 100.0 and who.inv.count("scrap") > 0:
		return ["repair", "Repair with scrap — engine %d %%" % int(health)]
	if fuel < tank() - 1.0 and who.inv.count("fuel_can") > 0:
		return ["refuel", "Pour in a fuel can — %d / %d l" % [int(fuel), int(tank())]]
	for u in UPGRADES:
		if not has_upgrade(u) and who.inv.count(u) > 0 and can_fit(u):
			return ["fit:" + u, "Fit %s" % str(UPGRADES[u]).to_lower()]
	var need := ""
	if health < 100.0:
		need = "  (needs scrap)"
	elif fuel < tank() * 0.2:
		need = "  (needs a fuel can)"
	return ["", "Engine %d %%   ·   fuel %d / %d l%s" % [int(health), int(fuel), int(tank()), need]]


func can_fit(u: String) -> bool:
	if type == "snowmobile":
		return u == "aux_tank"
	if type == "tracked" and u == "snow_chains":
		return false
	if u == "winch_kit" and bool(cfg["winch"]):
		return false
	return true


func service(who: Player) -> void:
	var act: String = service_action(who)[0]
	if act == "repair":
		who.inv.remove("scrap")
		health = minf(health + SCRAP_REPAIR, 100.0)
		Sfx.play(world, "clank", global_position, -4.0)
		who.message.emit("Repaired: engine at %d %%." % int(health))
	elif act == "refuel":
		who.inv.remove("fuel_can")
		fuel = minf(fuel + CAN_LITRES, tank())
		who.message.emit("Refuelled: %d of %d litres." % [int(fuel), int(tank())])
	elif act.begins_with("fit:"):
		var u := act.trim_prefix("fit:")
		who.inv.remove(u)
		upgrades.append(u)
		_apply_upgrades()
		Sfx.play(world, "clank", global_position, -4.0)
		who.message.emit("%s fitted." % UPGRADES[u])


func toggle_lights() -> void:
	lights_on = not lights_on
	for l in _lamps:
		l.visible = lights_on


## Bullets and blades.
func hit(dmg: float, _pos: Vector3, _dir: Vector3, pen: float, _shooter: Node) -> void:
	var a := armor() * clampf(1.0 - pen / 120.0, 0.3, 1.0)
	health = maxf(health - dmg * 0.3 * (1.0 - a), 0.0)
	if driver and randf() < (0.5 if not bool(cfg["cabin"]) else 0.12 * (1.0 - a)):
		driver.stats.hurt(dmg * 0.6, 0.2, "gunshot wounds", pen)
		driver.hurt_flash = 1.0


# ------------------------------------------------------------ winch
func toggle_winch() -> void:
	if not has_winch():
		_say("This vehicle has no winch.")
		return
	if _winching:
		_release("Winch let go.")
		return
	var from := hook()
	var q := PhysicsRayQueryParameters3D.create(from, from - global_basis.z * 32.0)
	q.exclude = [get_rid()]
	q.collision_mask = 3
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		_say("Nothing in front to hook the winch on (32 m).")
		return
	var at: Vector3 = res["position"]
	var col: Object = res["collider"]
	_anchor = at
	_anchor_body = col as Vehicle
	_winching = true
	_rope.visible = true
	Sfx.play(world, "clank", from, -6.0, 1.3)
	_say("Winch hooked at %d m — it pulls on its own. [G] lets go." % int(from.distance_to(at)))


func hook() -> Vector3:
	var size: Vector3 = cfg["size"]
	return to_global(Vector3(0, float(cfg["wheel_r"]) + 0.35, -size.z * 0.5 - 0.1))


func winching() -> bool:
	return _winching


func _release(text: String) -> void:
	_winching = false
	_anchor_body = null
	_rope.visible = false
	if text != "":
		_say(text)


func _winch_tick() -> void:
	var from := hook()
	if _anchor_body:
		if not is_instance_valid(_anchor_body):
			_release("")
			return
		_anchor = _anchor_body.global_position + Vector3(0, 0.8, 0)
	var d := _anchor - from
	var dist := d.length()
	if dist < 3.0:
		_release("Winch reeled in.")
		return
	if dist > 45.0:
		_release("The winch cable snapped loose.")
		return
	var n := d / dist
	if _anchor_body:
		# pull the other vehicle towards us; we stand on the brake
		var other := _anchor_body
		if other.linear_velocity.dot(-n) < 2.2:
			other.apply_central_force(-n * other.mass * 9.8 * 1.5 + Vector3.UP * other.mass * (6.0 if other.sunk else 0.0))
	elif linear_velocity.dot(n) < 2.4:
		apply_force(n * mass * 9.8 * 1.4, from - global_position)


func _say(text: String) -> void:
	if driver:
		driver.message.emit(text)


# ------------------------------------------------------------ every tick
func _surface() -> String:
	if sunk:
		return "water"
	var contact := false
	for w in wheels:
		if w.is_in_contact():
			contact = true
			break
	if not contact:
		return "air"
	var p := global_position
	var terrain: Terrain = world.terrain
	if terrain.on_lake(p.x, p.z) and p.y < Terrain.LAKE_LEVEL + 1.5:
		return "ice"
	if Vector2(p.x, p.z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 0.85 or terrain.on_road(p.x, p.z):
		return "packed"
	if terrain.normal_at(p.x, p.z).y < 0.84 or p.y > 150.0:
		return "rock"
	return "snow"


func _physics_process(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	_warn_cd = maxf(_warn_cd - delta, 0.0)
	_ram_cd = maxf(_ram_cd - delta, 0.0)
	# a sleeping body ignores its engine, so only empty parked vehicles may fall asleep
	can_sleep = driver == null and not scripted and not _winching
	if not can_sleep:
		sleeping = false
	surface = _surface()
	var fwd := -global_basis.z
	var v_f := linear_velocity.dot(fwd)

	# --- input
	var thr := 0.0
	var steer_in := 0.0
	var handbrake := false
	if scripted:
		thr = test_input.x
		steer_in = test_input.y
		handbrake = test_input.z > 0.5
	elif driver and not driver.ui_open:
		thr = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		thr += Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		thr = clampf(thr, -1.0, 1.0)
		steer_in = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		handbrake = Input.is_action_pressed("jump")
	elif driver == null:
		handbrake = true
	if _winching and _anchor_body:
		handbrake = true
	_thr = thr

	# --- engine and brakes
	var top := top_speed()
	var power := mass * float(cfg["accel"])
	if health < 50.0:
		power *= lerpf(0.45, 1.0, health / 50.0)
	var force := 0.0
	var brake_f := 0.0
	var brake_max := mass * 0.11
	if absf(thr) > 0.05 and engine_ok():
		if thr > 0.0 and v_f < -1.0 or thr < 0.0 and v_f > 1.0:
			brake_f = brake_max * absf(thr)
		elif thr > 0.0:
			force = power * thr * clampf(1.0 - pow(maxf(v_f, 0.0) / top, 2.0), 0.0, 1.0)
		else:
			force = power * thr * 0.6 * clampf(1.0 - pow(maxf(-v_f, 0.0) / (top * 0.3), 2.0), 0.0, 1.0)
		fuel = maxf(fuel - float(cfg["use"]) * absf(thr) * delta, 0.0)
		if fuel <= 0.0:
			_say("The engine dies: out of fuel.")
	elif absf(thr) > 0.05:
		# dead engine: the pedals only brake
		if thr > 0.0 and v_f < -0.5 or thr < 0.0 and v_f > 0.5:
			brake_f = brake_max
	else:
		brake_f = brake_max * 0.04
	if handbrake:
		brake_f = brake_max
	var friction := FRICTION * grip(surface if surface != "air" and surface != "water" else "packed")
	var steer_t := -steer_in * float(cfg["steer"]) * lerpf(1.0, 0.22, clampf(absf(v_f) / (top * 0.7), 0.0, 1.0))
	steering = move_toward(steering, steer_t, delta * 2.2)
	for w in wheels:
		w.wheel_friction_slip = friction
		w.engine_force = -force / wheels.size()    # Godot's vehicles count +Z as forward, ours face -Z
		w.brake = brake_f / wheels.size()
		if type == "tracked":
			# tracks: the two ends steer against each other, and the sides pull unevenly
			var rear: bool = w.get_meta("rear")
			w.steering = -steering if rear else steering
			if w.position.z == 0.0:
				w.steering = 0.0
			if engine_ok() and absf(steer_in) > 0.1 and absf(v_f) < 3.0:
				w.engine_force -= signf(w.position.x) * steer_in * power * 0.18
	if type != "tracked":
		for w in wheels:
			if w.use_as_steering:
				w.steering = steering

	# --- deep snow, rock and water hold the vehicle back
	var flat := Vector3(linear_velocity.x, 0, linear_velocity.z)
	if surface != "air" and surface != "water" and flat.length() > 0.3:
		apply_central_force(-flat.normalized() * mass * drag(surface) * minf(flat.length(), 1.0))
	# stay roughly upright on bumps
	if surface != "air" and not sunk:
		var tilt := global_basis.y.cross(Vector3.UP)
		apply_torque(tilt * mass * 6.0)

	_ice_tick(delta)
	if _winching:
		_winch_tick()

	# --- crashes
	var dv := (linear_velocity - _prev_vel).length()
	_prev_vel = linear_velocity
	if _grace <= 0.0 and not sunk and dv > 4.0:
		last_crash = dv
		health = maxf(health - (dv - 4.0) * 5.0 * (1.0 - armor() * 0.6), 0.0)
		Sfx.play(world, "thud", global_position, 2.0, 0.6)
		if driver and dv > 6.5:
			driver.stats.hurt((dv - 6.5) * (5.0 if not bool(cfg["cabin"]) else 3.0), 0.0, "a crash")
			driver.hurt_flash = 1.0
	# --- running things over
	if _ram_cd <= 0.0 and v_f > 5.0:
		var size: Vector3 = cfg["size"]
		for n in get_tree().get_nodes_in_group("gated"):
			if n is Breakable and (n as Breakable).ram_mass > 0.0 and not (n as Breakable).broken:
				var gl := to_local((n as Node3D).global_position)
				if absf(gl.x) < size.x * 0.5 + 3.6 and gl.z < 0.0 and gl.z > -size.z * 0.5 - 2.2 and absf(gl.y) < 3.0:
					if (n as Breakable).rammed(v_f, mass):
						_ram_cd = 0.5
						linear_velocity *= 0.6
		for n in get_tree().get_nodes_in_group("enemy"):
			var e: Node3D = n
			var local := to_local(e.global_position)
			if absf(local.x) < size.x * 0.5 + 0.5 and local.z < -size.z * 0.5 + 0.6 and local.z > -size.z * 0.5 - 1.6 and absf(local.y) < 2.0:
				if e.has_method("hit") and float(e.get("health")) > 0.0:
					e.call("hit", v_f * 7.0, e.global_position + Vector3(0, 0.8, 0), fwd, 60.0, driver)
					_ram_cd = 0.5
					linear_velocity *= 0.85


## Thin ice groans, then breaks, under more weight than it can carry.
func _ice_tick(delta: float) -> void:
	var p := Vector2(global_position.x, global_position.z)
	if sunk:
		# towed or driven up the lake bed and out again
		if not world.terrain.on_lake(p.x, p.y):
			sunk = false
			collision_mask = 3
			gravity_scale = 1.0
			linear_damp = 0.0
			angular_damp = 0.4
			health = minf(health, 20.0)
			_say("The %s is out of the water. The engine is flooded and needs repair." % str(cfg["name"]).to_lower())
		return
	if surface != "ice":
		_ice_t = 0.0
		return
	var cap := Lake.capacity(p)
	var weight := total_mass()
	if weight > cap:
		_ice_t += delta
		if _ice_t > 0.5:
			_break_through()
	else:
		_ice_t = 0.0
		if weight > cap * 0.65 and _warn_cd <= 0.0:
			_warn_cd = 4.0
			Sfx.play(world, "clank", global_position, 0.0, 0.35)
			_say("The ice groans under the weight (%d cm thick here)." % int(Lake.thickness(p) * 100.0))


func _break_through() -> void:
	var lake: Lake = world.lake
	var size: Vector3 = cfg["size"]
	lake.break_ice(Vector2(global_position.x, global_position.z), size.z * 0.5 + 1.6)
	sunk = true
	collision_mask = 1
	gravity_scale = 0.3
	linear_damp = 2.5
	angular_damp = 3.0
	lights_on = true
	toggle_lights()
	_release("")
	Sfx.play(world, "boom", global_position, 3.0, 0.5)
	_say("The ice breaks! The %s is going down — get out with [E]." % str(cfg["name"]).to_lower())


func _process(delta: float) -> void:
	_smoke.emitting = health < 45.0 and (driver != null or health <= 0.0) and not sunk
	if _winching:
		var a := hook()
		var mid := (a + _anchor) * 0.5
		var dist := a.distance_to(_anchor)
		if dist > 0.1:
			_rope.global_transform = Transform3D(Basis.looking_at(_anchor - a, Vector3.UP), mid).scaled_local(Vector3(1, 1, dist))
	# engine sound
	var on := driver != null and engine_ok()
	if on and not _audio.playing:
		_audio.play()
		_playback = _audio.get_stream_playback()
	elif not on and _audio.playing:
		_audio.stop()
		_playback = null
	if _playback:
		var want := clampf(linear_velocity.length() / float(cfg["top"]) * 0.75 + absf(_thr) * 0.25, 0.0, 1.0)
		_rpm = move_toward(_rpm, want, delta * 1.5)
		var base_hz := 55.0 if type == "snowmobile" else (24.0 if type == "tracked" else 34.0)
		var hz := base_hz * (1.0 + _rpm * 2.6)
		var step := hz / 11025.0
		for i in _playback.get_frames_available():
			_phase = fmod(_phase + step, 1.0)
			var s := (_phase * 2.0 - 1.0) * 0.5 + sin(_phase * TAU * 2.0) * 0.3 + (randf() - 0.5) * 0.25
			s *= 0.35 + 0.3 * _rpm
			_playback.push_frame(Vector2(s, s))


# ------------------------------------------------------------ saving
func to_dict() -> Dictionary:
	var q := global_basis.get_rotation_quaternion()
	var p := global_position
	return {"type": type, "pos": [p.x, p.y, p.z], "rot": [q.x, q.y, q.z, q.w], "fuel": fuel, "health": health,
		"upgrades": upgrades, "lights": lights_on, "sunk": sunk}


func from_dict(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	var r: Array = d.get("rot", [0, 0, 0, 1])
	if p.size() == 3:
		place(Transform3D(Basis(Quaternion(r[0], r[1], r[2], r[3])), Vector3(p[0], p[1], p[2])))
	upgrades.clear()
	for u in d.get("upgrades", []):
		upgrades.append(str(u))
	fuel = float(d.get("fuel", fuel))
	health = float(d.get("health", health))
	sunk = bool(d.get("sunk", false))
	collision_mask = 1 if sunk else 3
	gravity_scale = 0.3 if sunk else 1.0
	linear_damp = 2.5 if sunk else 0.0
	angular_damp = 3.0 if sunk else 0.4
	if lights_on != bool(d.get("lights", false)):
		toggle_lights()
	_release("")
	_apply_upgrades()


## Put the vehicle somewhere without it counting as a crash.
func place(t: Transform3D) -> void:
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# tell the physics engine directly, or a moving body snaps back
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_prev_vel = Vector3.ZERO
	_grace = 1.5
