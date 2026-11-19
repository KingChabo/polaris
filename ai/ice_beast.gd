class_name IceBeast
extends Boss


func _init() -> void:
	bleeds = false
## The white thing on the lake: a bear-sized beast grown over with plates of ice.
## Bullets glance off the plates until they are shot away; the rump has none.
## It charges in a straight line and cannot stop on the ice — that is your opening.
## Twice it breaks off and runs across the lake, and you have to go after it.

const WALK := 3.6
const CHARGE := 13.5

var lake: Lake
var mode := "stalk"            # stalk / windup / charge / skid / swipe / slam / run / breath / spikes / howl
var _t := 0.0
var _dir := Vector3.FORWARD
var _hit_done := false
var _slam_cd := 9.0
var _runs := 0
var _run_to := Vector3.ZERO
var _legs: Array[Node3D] = []
var _head: Node3D
var _roar := 0.0
var _breath_cd := 6.0
var _spike_cd := 4.0
var _howl_cd := 0.0
var _mist: CPUParticles3D
var _howled := false


func setup() -> void:
	make_body(1.15, 2.3)
	boss_name = "The White One"
	boss_sub = "Shoot the ice plates off. The rump is bare."
	display_name = boss_name
	max_health = 900.0
	health = max_health
	armor = 20.0
	speed = WALK
	head_y = 99.0
	eye_y = 1.9
	view_dist = 70.0
	body_title = "The White One"
	bag_side = 2.0
	bulk = 1.2
	model = _build()
	add_child(model)


func _build() -> Node3D:
	var root := Node3D.new()
	var k := MeshKit.new()
	k.winter = true  # creatures keep their ice and frost in summer
	var fur := "camo_in"
	k.ball(Vector3(0, 1.45, 0.3), Vector3(0.95, 0.85, 1.7), fur, 16, 9)            # barrel
	k.ball(Vector3(0, 1.75, -0.9), Vector3(0.9, 0.85, 0.9), fur, 16, 9)            # shoulders, humped
	k.ball(Vector3(0, 1.4, 1.5), Vector3(0.85, 0.8, 0.8), fur, 14, 8)              # rump
	k.ball(Vector3(0, 1.05, 0.3), Vector3(0.7, 0.4, 1.4), "fur_in", 12, 6)         # belly
	k.tube(Vector3(0, 1.7, -1.4), Vector3(0, 1.5, -2.2), 0.62, fur, 12, 0.45, false)   # neck
	for i in 9:   # ragged mane of frozen fur
		var a := PI * i / 8.0
		k.ball(Vector3(cos(a) * 0.7, 1.9 + sin(a) * 0.55, -1.1), Vector3(0.2, 0.22, 0.34), "fur_in", 6, 4)
	k.tube(Vector3(0, 1.4, 2.2), Vector3(0, 1.2, 2.6), 0.2, fur, 8, 0.08)          # stub tail
	root.add_child(k.node(false))
	# head
	var h := MeshKit.new()
	h.winter = true  # creatures keep their ice and frost in summer
	h.ball(Vector3(0, 0, 0), Vector3(0.48, 0.42, 0.52), fur, 14, 8)
	h.tube(Vector3(0, -0.08, -0.35), Vector3(0, -0.16, -0.95), 0.3, fur, 12, 0.19)
	h.ball(Vector3(0, -0.14, -0.97), Vector3(0.1, 0.08, 0.07), "black_in", 8, 5)
	h.tube(Vector3(0, -0.3, -0.25), Vector3(0, -0.34, -0.85), 0.2, "fur_dark_in", 10, 0.13)
	for sx: float in [-1.0, 1.0]:
		h.ball(Vector3(sx * 0.36, 0.36, 0.08), Vector3(0.12, 0.13, 0.07), fur, 8, 5)
		h.ball(Vector3(sx * 0.22, 0.1, -0.42), Vector3(0.045, 0.035, 0.03), "specimen", 8, 5)   # pale blue eyes
		h.cyl(Vector3(sx * 0.13, -0.42, -0.78), 0.0, 0.2, "white_in", 5, 0.04)
		h.cyl(Vector3(sx * 0.16, -0.38, -0.6), 0.0, 0.14, "white_in", 5, 0.03)
	_head = h.node(false)
	_head.position = Vector3(0, 1.6, -2.3)
	root.add_child(_head)
	# legs
	for p: Vector3 in [Vector3(-0.6, 1.2, -1.0), Vector3(0.6, 1.2, -1.0), Vector3(-0.6, 1.2, 1.4), Vector3(0.6, 1.2, 1.4)]:
		var l := MeshKit.new()
		l.winter = true  # creatures keep their ice and frost in summer
		l.tube(Vector3.ZERO, Vector3(0, -0.75, 0.05), 0.36, fur, 10, 0.27, false)
		l.tube(Vector3(0, -0.75, 0.05), Vector3(0, -1.12, -0.05), 0.27, fur, 10, 0.3, false)
		l.ball(Vector3(0, -1.12, -0.16), Vector3(0.33, 0.14, 0.42), "fur_in", 10, 5)
		for c: float in [-0.18, 0.0, 0.18]:
			l.cyl(Vector3(c, -1.2, -0.62), 0.0, 0.12, "black_in", 4, 0.035)
		var leg := l.node(false)
		leg.position = p
		root.add_child(leg)
		_legs.append(leg)
	# plates of ice: head, both flanks. Each is made of curved scales that follow the body,
	# overlapping like roof tiles, with crystal spikes growing out along the spine.
	var ph := MeshKit.new()
	ph.winter = true  # creatures keep their ice and frost in summer
	for i in 5:
		var z := 0.25 - i * 0.22
		var y := 0.38 - i * 0.05
		_scale(ph, Vector3(0, y, z), Vector3(0, 1, -0.25 - i * 0.12).normalized(), Vector3(0.36 - i * 0.03, 0.05, 0.22))
	for sx: float in [-1.0, 1.0]:
		_scale(ph, Vector3(sx * 0.3, 0.22, -0.15), Vector3(sx, 0.7, -0.3).normalized(), Vector3(0.22, 0.04, 0.3))
		_shard(ph, Vector3(sx * 0.3, 0.38, 0.12), Vector3(sx * 0.35, 0.9, 0.5).normalized(), 0.62, 0.09)
		_shard(ph, Vector3(sx * 0.2, 0.42, 0.0), Vector3(sx * 0.2, 1.0, 0.3).normalized(), 0.32, 0.05)
	var head_plate := ph.node(false)
	_head.add_child(head_plate)
	add_part("head", 150.0, head_plate, "head plate")
	for sx: float in [-1.0, 1.0]:
		var pf := MeshKit.new()
		pf.winter = true  # creatures keep their ice and frost in summer
		for row in 3:
			var e := deg_to_rad(18.0 + row * 24.0)
			for i in 8:
				var z := -1.65 + i * 0.36 + (row % 2) * 0.18
				var hump := 1.0 + 0.22 * clampf(1.0 - absf(z + 0.9) / 0.8, 0.0, 1.0)
				var f := sqrt(maxf(1.0 - pow((z - 0.3) / 1.85, 2.0), 0.15)) * hump
				var p := Vector3(sx * cos(e) * 0.98 * f, 1.47 + sin(e) * 0.86 * f, z)
				var n := Vector3(p.x / 0.9, (p.y - 1.45) / 0.72, (z - 0.3) / 2.9).normalized()
				var w := 0.3 - row * 0.03 + 0.03 * sin(i * 2.3 + sx)
				_scale(pf, p + n * 0.03, n, Vector3(w, 0.06, 0.27 + 0.03 * cos(i * 1.9)))
		# crystals along the spine, tallest over the shoulders
		for i in 7:
			var z := -1.4 + i * 0.36
			var tall := 0.55 + 0.35 * clampf(1.0 - absf(z + 0.8) / 1.2, 0.0, 1.0) + 0.08 * sin(i * 3.1)
			var base := Vector3(sx * 0.22, 2.2 - absf(z + 0.8) * 0.18, z)
			_shard(pf, base, Vector3(sx * 0.45, 1.0, 0.15 * sin(i * 1.3)).normalized(), tall, 0.1)
			_shard(pf, base + Vector3(sx * 0.12, -0.06, 0.12), Vector3(sx * 0.9, 0.7, 0.2).normalized(), tall * 0.45, 0.06)
		var flank := pf.node(false)
		root.add_child(flank)
		add_part("left" if sx < 0.0 else "right", 170.0, flank, "left flank plate" if sx < 0.0 else "right flank plate")
	return root


## One ice scale: a flattened lens lying on the body, its thin axis along `n`.
static func _scale(k: MeshKit, at: Vector3, n: Vector3, radii: Vector3) -> void:
	var side := n.cross(Vector3.FORWARD)
	if side.length() < 0.1:
		side = n.cross(Vector3.RIGHT)
	side = side.normalized()
	var fwd := side.cross(n).normalized()
	k.ball(at, radii, "ice", 10, 5, Basis(side, n, fwd))


## A six-sided crystal growing from `base` towards `dir`.
static func _shard(k: MeshKit, base: Vector3, dir: Vector3, length: float, r: float) -> void:
	k.tube(base, base + dir * length * 0.78, r, "ice", 6, r * 0.8, false)
	k.tube(base + dir * length * 0.78, base + dir * length, r * 0.8, "ice", 6, 0.0, false)


func _on_hurt() -> void:
	if state != "fight":
		_wake()


func _wake() -> void:
	state = "fight"
	mode = "windup"
	_t = 1.6
	_roar = 1.6
	Sfx.play(get_parent(), "growl", global_position, 8.0, 0.45)


## Flares blind it for a moment.
func scare(pos: Vector3, reach: float) -> void:
	if state == "fight" and global_position.distance_to(pos) < reach and mode != "run":
		mode = "skid"
		_t = 2.5
		velocity *= 0.3


func hear(_pos: Vector3, _reach: float) -> void:
	pass


func hit(dmg: float, pos: Vector3, dir: Vector3, pen: float, _shooter: Node) -> void:
	if state == "dead":
		return
	var l := to_local(pos)
	var mult := 1.0
	var arm := armor
	var region := ""
	if l.z < -1.5:
		region = "head"
	elif l.z < 0.9:
		region = "left" if l.x < 0.0 else "right"
	if region != "" and part_alive(region):
		# the plate takes it; a little gets through
		hurt_part(region, dmg * (0.55 + pen / 120.0), pos)
		Fx.sparks(get_parent(), pos, -dir)
		arm = 75.0
		mult = 0.35
	elif region == "head":
		mult = 1.6
	elif region == "":
		mult = 1.5      # the bare rump
	if mode == "skid" or mode == "breath":
		mult *= 1.4         # rearing up to breathe, its throat is open
	last_head = region == "head" and not part_alive("head")
	last_damage = Damage.apply(dmg, arm, pen) * mult
	health -= last_damage
	Fx.blood(get_parent(), pos, dir, last_damage > 40.0)
	if health <= 0.0:
		_die(dir)
		return
	if passive:
		return
	_on_hurt()
	# twice it has had enough and runs
	var third := 2 if health < max_health * 0.33 else (1 if health < max_health * 0.66 else 0)
	if third > _runs and mode != "run":
		_runs = third
		phase = _runs + 1
		_start_run()


## Its three gifts, one more each time it is hurt badly:
##   frost breath  - a cone of freezing mist; frost creeps over your eyes and the cold gets in
##   ice spikes    - a line of spears that bursts out of the ice towards you (watch for the glow)
##   blizzard howl - the world goes white, and then it comes out of the snow at a run
func _breath_mist() -> CPUParticles3D:
	if _mist == null:
		_mist = CPUParticles3D.new()
		_mist.amount = 90
		_mist.lifetime = 0.9
		_mist.emitting = false
		_mist.direction = Vector3(0, -0.15, -1)
		_mist.spread = 16.0
		_mist.initial_velocity_min = 13.0
		_mist.initial_velocity_max = 18.0
		_mist.gravity = Vector3(0, -0.6, 0)
		_mist.scale_amount_min = 0.7
		_mist.scale_amount_max = 2.2
		_mist.damping_min = 4.0
		_mist.damping_max = 7.0
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 1.2)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.82, 0.92, 1.0, 0.25)
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var gr := Gradient.new()
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.gradient = gr
		m.albedo_texture = g
		q.material = m
		_mist.mesh = q
		_head.add_child(_mist)
		_mist.position = Vector3(0, -0.1, -0.9)
	return _mist


func _breathe(delta: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	var fwd := -global_basis.z
	if to.length() < 17.0 and fwd.angle_to(to.normalized()) < deg_to_rad(32.0):
		player.stats.warmth = maxf(player.stats.warmth - 16.0 * delta, 0.0)
		player.stats.hurt(5.0 * delta, 0.0, "the White One's breath")
		if main and main.get("post"):
			main.post.frost = minf(main.post.frost + delta * 0.9, 1.0)
		player.shake(0.25)


func _spike_line() -> void:
	var from := global_position - global_basis.z * 3.0
	var to := player.global_position
	var dir := Vector3(to.x - from.x, 0, to.z - from.z)
	var n := int(clampf(dir.length() / 2.0, 4.0, 11.0)) + 2
	dir = dir.normalized()
	for i in n:
		var p := from + dir * (2.0 + i * 2.0) + dir.cross(Vector3.UP) * randf_range(-0.5, 0.5)
		IceSpike.spawn(get_parent(), p, 0.55 + i * 0.09, player)
	Sfx.play(get_parent(), "crack", global_position, 6.0, 0.7)


func _howl() -> void:
	Sfx.play(get_parent(), "growl", global_position, 10.0, 0.35)
	Sfx.play_flat(get_parent(), "shriek", -4.0, 0.45)
	if main and main.get("post"):
		main.post.whiteout = 0.92
	if main and main.get("weather"):
		var w: Weather = main.weather
		w.fog_add += 0.05
		get_tree().create_timer(7.0).timeout.connect(func() -> void: w.fog_add = maxf(w.fog_add - 0.05, 0.0))
	if player:
		player.message.emit("The White One howls. The %s comes down like a wall." % ("fog" if GameMode.summer() else "snow"))


func _start_run() -> void:
	mode = "run"
	_t = 9.0
	var c := Vector3(Terrain.LAKE_POS.x - 40.0, global_position.y, Terrain.LAKE_POS.y + 40.0)
	var away := global_position - player.global_position
	away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5))
	_run_to = global_position + away * 70.0
	# stay on the ice, away from the open water
	var off := Vector2(_run_to.x - c.x, _run_to.z - c.z)
	if off.length() > 120.0:
		off = off.normalized() * 120.0
		_run_to = Vector3(c.x + off.x, global_position.y, c.z + off.y)
	if Lake.hole(Vector2(_run_to.x, _run_to.z)) < 25.0:
		_run_to = Vector3(c.x - 60.0, global_position.y, c.z + 30.0)
	Sfx.play(get_parent(), "growl", global_position, 6.0, 0.6)
	if player:
		player.message.emit("The White One breaks off and runs across the ice.")


func _think(delta: float, dist: float) -> Vector3:
	_roar = maxf(_roar - delta, 0.0)
	if state != "fight":
		if (_sees and dist < 55.0) or dist < 16.0:
			_wake()
		return _roam(delta, 30.0, 1.4)
	if dist > 190.0:
		state = "idle"
		mode = "stalk"
		health = minf(max_health, health + max_health * 0.2)
		return Vector3.ZERO
	var to := _flat_to(player.global_position)
	var d := to.length()
	var dir := to.normalized() if d > 0.01 else -global_basis.z
	_t -= delta
	_slam_cd -= delta
	match mode:
		"run":
			var go := _flat_to(_run_to)
			if go.length() < 4.0 or _t <= 0.0:
				mode = "windup"
				_t = 1.8
				_roar = 1.8
				Sfx.play(get_parent(), "growl", global_position, 8.0, 0.45)
				return Vector3.ZERO
			_face(go, delta)
			return go.normalized() * 9.5
		"windup":
			_face(dir, delta)
			if _t <= 0.0:
				mode = "charge"
				_t = 2.4
				_dir = dir
				_hit_done = false
			return Vector3.ZERO
		"charge":
			# it can steer a little, no more
			_dir = _dir.slerp(dir, minf(delta * 0.55, 1.0)).normalized()
			_face(_dir, delta)
			if not _hit_done and d < 2.7:
				_hit_done = true
				_ram()
			if _t <= 0.0 or (_dir.dot(dir) < 0.2 and d > 4.0):
				mode = "skid"
				_t = 2.3
			return _dir * CHARGE
		"skid":
			# claws out, sliding, back turned
			if _t <= 0.0:
				mode = "stalk"
			return _dir * maxf(_t, 0.0) * 3.0
		"swipe":
			_face(dir, delta)
			if _t <= 0.0:
				if d < 4.2:
					var res := player.melee_hit(24.0, 0.6, self)
					if res == "parried":
						mode = "skid"
						_t = 1.6
						return Vector3.ZERO
				mode = "stalk"
				_t = 0.0
			return Vector3.ZERO
		"slam":
			if _t <= 0.0:
				_slam()
				mode = "stalk"
			return Vector3.ZERO
		"breath":
			# 0.8 s rearing up, then two seconds of freezing mist swept across you
			_face(dir, delta * 0.35)
			var mist := _breath_mist()
			if _t < 2.0:
				mist.emitting = true
				_breathe(delta)
			if _t <= 0.0:
				mist.emitting = false
				mode = "stalk"
			return Vector3.ZERO
		"spikes":
			_face(dir, delta)
			if _t <= 0.0:
				_spike_line()
				mode = "stalk"
			return Vector3.ZERO
		"howl":
			if _t <= 0.0:
				# out of the whiteout at a run
				mode = "windup"
				_t = 0.6
			return Vector3.ZERO
	# stalk: walk in, then choose
	_breath_cd -= delta
	_spike_cd -= delta
	_howl_cd -= delta
	if phase >= 3 and (_howl_cd <= 0.0 or not _howled):
		_howled = true
		_howl_cd = randf_range(30.0, 40.0)
		mode = "howl"
		_t = 2.6
		_roar = 2.6
		_howl()
		return Vector3.ZERO
	if _breath_cd <= 0.0 and d > 5.0 and d < 15.0 and _sees:
		mode = "breath"
		_t = 2.8
		_roar = 0.8
		_breath_cd = randf_range(9.0, 14.0) if phase < 3 else randf_range(6.0, 9.0)
		Sfx.play(get_parent(), "growl", global_position, 6.0, 0.7)
		Sfx.play(get_parent(), "steam", global_position - global_basis.z * 3.0, 8.0, 0.6)
		return Vector3.ZERO
	if phase >= 2 and _spike_cd <= 0.0 and d > 7.0 and d < 26.0:
		mode = "spikes"
		_t = 0.7
		_roar = 0.7
		_spike_cd = randf_range(8.0, 12.0)
		return Vector3.ZERO
	_face(dir, delta)
	if d < 3.6:
		mode = "swipe"
		_t = 0.55
		Sfx.play(get_parent(), "swing", global_position, 2.0, 0.5)
		return Vector3.ZERO
	if _slam_cd <= 0.0 and d < 11.0:
		mode = "slam"
		_t = 1.1
		_slam_cd = randf_range(12.0, 18.0)
		_roar = 1.1
		return Vector3.ZERO
	if d > 9.0 and d < 60.0 and _sees:
		mode = "windup"
		_t = 1.0
		_roar = 1.0
		Sfx.play(get_parent(), "growl", global_position, 5.0, 0.55)
		return Vector3.ZERO
	return dir * WALK


func _ram() -> void:
	player.stats.hurt(34.0, 0.8, "the White One", 20.0)
	player.velocity += _dir * 9.0 + Vector3(0, 4.5, 0)
	player.shake(2.2)
	player.hurt_marks.append([global_position, 1.6])
	Sfx.play(get_parent(), "thud", player.global_position, 6.0, 0.6)


## Both paws down: the ice in front of it gives way.
func _slam() -> void:
	Sfx.play(get_parent(), "shot_boom", global_position, 2.0, 0.5)
	var at := global_position - global_basis.z * 5.5
	var d := player.global_position.distance_to(global_position)
	if d < 9.0:
		player.stats.hurt(14.0, 0.0, "the White One")
		player.velocity += (player.global_position - global_position).normalized() * 6.0 + Vector3(0, 3.0, 0)
		player.shake(1.8)
	if lake and at.y < Terrain.LAKE_LEVEL + 1.5 and Lake.hole(Vector2(at.x, at.z)) > 8.0 and lake.breaks.size() < 14:
		lake.break_ice(Vector2(at.x, at.z), 3.6)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# it swims: open water does not swallow it
	if state != "dead" and lake and global_position.y < Terrain.LAKE_LEVEL - 1.3 and lake.in_water(global_position + Vector3(0, -0.5, 0)):
		global_position.y = Terrain.LAKE_LEVEL - 1.3
		velocity.y = 0.0


func _animate(_delta: float, moved: float) -> void:
	var amp := clampf(moved / 6.0, 0.0, 1.0) * 0.7
	var rate := 1.1 if mode != "charge" else 1.9
	for i in 4:
		_legs[i].rotation.x = sin(_phase * rate + (0.0 if i == 0 or i == 3 else PI)) * amp
	var head_x := 0.0
	var body_x := 0.0
	if _roar > 0.0:
		head_x = 0.7 + sin(_roar * 30.0) * 0.06
	if mode == "breath":
		head_x = 0.45 if _t > 2.0 else -0.1 + sin(_t * 9.0) * 0.05
		body_x = -0.1 if _t > 2.0 else 0.05
	elif mode == "howl":
		head_x = 0.95
		body_x = -0.25
	elif mode == "spikes":
		body_x = 0.35
		_legs[0].rotation.x = -0.9
		_legs[1].rotation.x = -0.9
	elif mode == "slam":
		body_x = 0.5
		_legs[0].rotation.x = -1.2
		_legs[1].rotation.x = -1.2
	elif mode == "swipe":
		_legs[1].rotation.x = -1.5 + (0.55 - maxf(_t, 0.0)) * 4.0
		head_x = 0.3
	elif mode == "charge":
		head_x = -0.25
		body_x = -0.08
	elif mode == "skid":
		body_x = 0.12
		head_x = -0.4
	_head.rotation.x = lerpf(_head.rotation.x, head_x, 0.2)
	model.rotation.x = lerpf(model.rotation.x, body_x, 0.15)
	model.rotation.z = lerpf(model.rotation.z, 0.0, 0.2)


func _lie_dead() -> void:
	model.rotation.z = PI * 0.45
	model.position.y = 0.9


func _fall(_dir: Vector3) -> void:
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", PI * 0.45, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.9, 0.9)
