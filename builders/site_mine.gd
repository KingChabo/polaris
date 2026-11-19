class_name SiteMine
extends RefCounted
## Everything underground: the Nordstern mine, the blown road tunnel and the two shelters.
## The rooms sit in pits that Places.plan() dug; the natural ground lies over them as a lid.

const ROCK := "rock_in"
const CON := "concrete_in"


static func _planks(w: float, h: float, messy: bool) -> MeshKit:
	var b := MeshKit.new()
	if messy:
		for i in 5:
			b.box(Vector3(0.6 + i * 0.25, 0.04 + i * 0.02, (i - 2) * 0.3), Vector3(0.18, 0.04, w * 0.8), "planks_in", Basis(Vector3.UP, 0.5 + i * 0.4))
	else:
		for i in int(h / 0.42):
			b.box(Vector3(0, 0.25 + i * 0.42, 0), Vector3(0.05, 0.3, w), "planks_in", Basis(Vector3.RIGHT, sin(i * 2.3) * 0.06))
		b.box(Vector3(0.05, h * 0.5, 0), Vector3(0.05, 0.22, w * 1.25), "wood_dark_in", Basis(Vector3.RIGHT, 0.75))
		b.box(Vector3(0.05, h * 0.5, 0), Vector3(0.05, 0.22, w * 1.25), "wood_dark_in", Basis(Vector3.RIGHT, -0.75))
	return b


static func mine(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var t := pl.terrain
	var f: float = Places.D["mine_floor"]
	var px: float = Places.D["mine_px"]
	pl.at(Vector3.ZERO)
	# --- adit
	Struct.room(k, px, 138.2, 576.0, 141.8, f, 2.7, ROCK, "gravel_in", ROCK,
		{"w": [[140.0, 99.0, 2.7]], "e": [[140.0, 1.4, 2.3]], "n": [[552.0, 3.2, 2.5]], "s": [[566.0, 2.0, 2.3]]}, 0.5)
	Struct.headwall(k, t, f, false, px - 0.35, 130.0, 150.0, 138.2, 141.8, 2.7)
	k.box(Vector3(px - 4.3, f - 0.22, 140.0), Vector3(8.8, 0.2, 8.4), "gravel", Basis(Vector3(0, 0, 1), atan2(0.24, 8.6)))
	# heavy timber frame and the name of the mine over the mouth
	for s: float in [-1.0, 1.0]:
		k.tube(Vector3(px - 0.9, f, 140.0 + s * 2.1), Vector3(px - 0.9, f + 3.1, 140.0 + s * 2.0), 0.17, "wood_dark", 8)
	k.tube(Vector3(px - 0.9, f + 3.1, 137.4), Vector3(px - 0.9, f + 3.1, 142.6), 0.19, "wood_dark", 8)
	kd.box(Vector3(px - 0.75, f + 3.75, 140.0), Vector3(0.06, 0.7, 4.6), "paint_yellow")
	pl.label("STOLLEN NORDSTERN", Vector3(px - 0.79, f + 3.75, 140.0), -PI * 0.5, 0.0052)
	var boards := pl.barrier(Vector3(px + 0.5, f, 140.0), 0.0, Vector3(0.3, 2.7, 3.6), "mine_boards", _planks(3.6, 2.7, false), _planks(3.6, 2.7, true))
	boards.tools = ["axe", "crowbar"]
	boards.hp = 150.0
	kd.box(Vector3(px + 0.42, f + 1.5, 140.0), Vector3(0.02, 0.5, 1.5), "paint_red_in")
	pl.label("BETRETEN\nVERBOTEN", Vector3(px + 0.405, f + 1.5, 140.0), -PI * 0.5, 0.0028, Color(0.95, 0.93, 0.85))
	var x := px + 2.0
	var n := 0
	while x < 575.0:
		Struct.timber(kd, Vector3(x, f, 140.0), true, 3.6, 2.7)
		if n % 3 == 1:
			var lit := n % 6 == 1
			kd.sphere(Vector3(x + 1.5, f + 2.38, 141.3), 0.07, "lamp_glow" if lit else "glass_dark", 6, 4)
			if lit:
				pl.lamp(Vector3(x + 1.5, f + 2.2, 141.0), Color(1.0, 0.75, 0.45), 1.3, 9.0, n % 12 == 7)
		x += 3.0
		n += 1
	kd.tube(Vector3(px, f + 2.5, 141.3), Vector3(576.0, f + 2.5, 141.3), 0.012, "black_in", 4, -1.0, false)
	Struct.rails(kd, Vector3(474.0, f, 140.0), Vector3(px, f, 140.0))
	Struct.rails(kd, Vector3(px, f, 140.0), Vector3(592.0, f, 140.0), "_in")
	for fx: float in [545.0, 560.0, 571.0]:      # timber lagging: one of these panels is a way through
		var xx: float = fx
		for i in 6:
			kd.box(Vector3(xx, f + 0.25 + i * 0.4, 138.24), Vector3(2.0, 0.3, 0.05), "planks_in")
	pl.door(Vector3(576.25, f, 139.35), -PI * 0.5, 1.3, 2.25, true, "mine_gate", "key_mine")
	# --- drift to the foreman's office
	Struct.room(k, 550.4, 99.5, 553.6, 137.7, f, 2.5, ROCK, "gravel_in", ROCK, {"s": [[552.0, 99.0, 2.5]], "n": [[552.0, 99.0, 2.5]]}, 0.5)
	for i in 12:
		Struct.timber(kd, Vector3(552.0, f, 102.0 + i * 3.0), false, 3.2, 2.5)
	pl.lamp(Vector3(552.0, f + 2.1, 118.0), Color(1.0, 0.75, 0.45), 1.0, 8.0, true)
	Struct.room(k, 544.0, 87.0, 560.0, 99.0, f, 2.8, "planks_in", "planks_in", "wood_in", {"s": [[552.0, 3.2, 2.5]]}, 0.5)
	Interior.table(k, Vector3(547.0, f, 89.0), 0.0, 1.8, 0.9)
	Interior.chair(k, Vector3(547.0, f, 90.1), PI)
	pl.note("n_mine_log", Vector3(546.7, f + 0.78, 89.0), 0.2, "book")
	kd.cyl(Vector3(547.7, f + 0.76, 88.8), 0.06, 0.2, "lamp_glow", 8)
	pl.lamp(Vector3(547.7, f + 1.3, 89.2), Props.WARM, 1.8, 9.0, false, true)
	Interior.lockers(k, Vector3(558.6, f, 87.3), 0.0, 3)
	Struct.shelf(k, rng, Vector3(559.6, f, 94.0), -PI * 0.5, 3.0)
	Struct.bunk(k, Vector3(544.6, f, 96.0), 0.0)
	Interior.picture(kd, rng, Vector3(552.0, f + 1.6, 87.04), 0.0, 1.6, 1.0)
	for i in 3:
		k.xf = Transform3D(Basis(Vector3.UP, i * 0.5), Vector3(555.0 + i * 0.9, f, 97.6))
		Props.crate(k, 0.6 + i * 0.1)
	pl.at(Vector3.ZERO)
	pl.chest(Vector3(552.0, f, 87.5), 0.0, "mine_office", {"bolt_cutters": 1, "helmet": 1, "batteries": 2, "9mm": 20, "hot_tea": 1, "scrap": 2}, "Foreman's chest")
	# --- Meier's hiding place behind the lagging
	Struct.room(k, 565.0, 142.3, 567.0, 147.0, f, 2.3, ROCK, "gravel_in", ROCK, {"n": [[566.0, 99.0, 2.3]], "s": [[566.0, 99.0, 2.3]]}, 0.5)
	Struct.room(k, 561.0, 147.5, 571.0, 163.0, f, 2.6, ROCK, "gravel_in", ROCK, {"n": [[566.0, 2.0, 2.3]]}, 0.5)
	var lag := MeshKit.new()
	for i in 6:
		lag.box(Vector3(0, 0.25 + i * 0.4, 0), Vector3(2.0, 0.3, 0.05), "planks_in")
	var hid := pl.barrier(Vector3(566.0, f, 141.78), 0.0, Vector3(2.0, 2.4, 0.3), "mine_hidden", lag, null)
	hid.tools = ["axe", "crowbar"]
	hid.hp = 90.0
	hid.what = "Loose planks"
	hid.hint = "They sound hollow. An axe or a crowbar would have them off."
	hid.done_text = "The planks come away. There is a passage behind."
	kd.bbox(Vector3(563.0, f + 0.1, 160.0), Vector3(0.8, 0.16, 1.9), 0.06, "olive_in")
	kd.ball(Vector3(563.0, f + 0.22, 160.8), Vector3(0.24, 0.09, 0.16), "cream_in", 8, 5)
	for i in 5:
		kd.cyl(Vector3(569.0 + (i % 2) * 0.2, f, 158.0 + i * 0.25), 0.05, 0.12, "steel_in", 8)
	kd.cyl(Vector3(564.4, f, 159.2), 0.04, 0.14, "candle", 6)
	pl.lamp(Vector3(564.4, f + 0.5, 159.2), Color(1.0, 0.6, 0.25), 1.0, 7.0, true)
	k.xf = Transform3D(Basis(Vector3.UP, 0.3), Vector3(568.5, f, 150.5))
	Props.crate(k, 0.8)
	pl.at(Vector3.ZERO)
	pl.note("n_mine_wall", Vector3(568.5, f + 0.82, 150.5), 0.6)
	pl.chest(Vector3(569.6, f, 161.6), -PI * 0.5, "mine_hidden", {"plate_carrier": 1, "762_ap": 20, "medkit": 1, "painkillers": 2, "canned_food": 3}, "Meier's stash")
	# --- the lower chamber, where K-9 waits
	Struct.room(k, 577.0, 121.0, 607.0, 159.0, f, 7.0, ROCK, "gravel_in", ROCK, {"w": [[140.0, 1.4, 2.3]]}, 0.5)
	for p in [Vector2(586, 130), Vector2(586, 150), Vector2(597, 128), Vector2(597, 152)]:
		var pv: Vector2 = p
		k.box(Vector3(pv.x, f + 3.5, pv.y), Vector3(2.6, 7.0, 2.6), ROCK, Basis(Vector3.UP, 0.3 + pv.x))
		Struct.rubble(k, rng, Vector3(pv.x, f, pv.y), 2.6, 9, ROCK, 1.0)
	Struct.rubble(k, rng, Vector3(603.0, f, 154.0), 4.0, 16, "gravel_in", 1.5)
	Struct.rubble(k, rng, Vector3(581.0, f, 124.0), 3.0, 10, "gravel_in", 1.2)
	Struct.rubble(kd, rng, Vector3(592.0, f + 6.9, 140.0), 12.0, 30, ROCK, 1.6)
	Struct.cart(k, Vector3(584.0, f + 0.05, 140.0), PI * 0.5, true, "_in")
	Places.D["k9"] = Vector3(600.0, f, 140.0)      # the machine itself is a boss: see ai/mining_machine.gd
	pl.lamp(Vector3(596.0, f + 2.2, 140.0), Color(1.0, 0.82, 0.5), 2.6, 20.0, true, true)
	pl.lamp(Vector3(584.0, f + 5.5, 132.0), Color(0.5, 0.9, 1.0), 1.3, 26.0)
	pl.lamp(Vector3(600.0, f + 5.5, 150.0), Color(0.5, 0.9, 1.0), 0.9, 22.0)
	k.xf = Transform3D(Basis(Vector3.UP, 0.2), Vector3(590.0, f, 146.0))
	Props.crate(k, 0.9)
	pl.at(Vector3.ZERO)
	pl.note("n_mine_deep", Vector3(590.0, f + 0.92, 146.0), 0.4)
	pl.chest(Vector3(604.5, f, 124.0), -PI * 0.5, "mine_deep", {"expedition_suit": 1, "12g_slug": 14, "ext_mag": 1, "scrap": 6, "batteries": 3, "grip": 1}, "Tool chest")
	# --- the yard outside
	Struct.cart(k, Vector3(480.0, f + 0.05, 140.0), PI * 0.5, false)
	Struct.cart(k, Vector3(488.5, f + 0.05, 140.0), PI * 0.5)
	for s: float in [-1.0, 1.0]:
		for xx: float in [478.0, 484.0]:
			var bx: float = xx
			k.tube(Vector3(bx, f, 149.0 + s * 2.0), Vector3(bx, f + 4.6, 149.0 + s * 1.7), 0.14, "wood_dark", 7)
	k.box(Vector3(481.0, f + 5.0, 149.0), Vector3(7.4, 2.6, 4.4), "planks")
	k.box(Vector3(481.0, f + 6.5, 149.0), Vector3(8.0, 0.3, 5.0), "snow", Basis(Vector3(0, 0, 1), 0.1))
	k.box(Vector3(481.0, f + 3.3, 146.6), Vector3(1.4, 0.1, 2.4), "rust", Basis(Vector3.RIGHT, 0.7))
	Struct.rubble(k, rng, Vector3(481.0, f, 145.0), 2.2, 12, "gravel", 1.0)
	Struct.room(k, 474.0, 128.0, 480.0, 132.5, f + 0.07, 2.4, "planks", "planks_in", "planks", {"s": [[477.0, 1.1, 2.05]], "e": [[130.2, 1.2, 1.9, 1.0]]}, 0.14)
	k.box(Vector3(477.0, f + 2.78, 130.2), Vector3(7.0, 0.22, 5.6), "snow")
	kd.box(Vector3(480.08, f + 1.57, 130.2), Vector3(0.02, 0.9, 1.2), "glass_dark")
	Interior.workbench(k, rng, Vector3(477.0, f + 0.12, 128.5), 0.0, 3.0)
	pl.chest(Vector3(475.0, f + 0.12, 131.6), PI * 0.5, "mine_shed", {"scrap": 3, "firewood": 2, "gloves": 1, "bandage": 1}, "Shed box")
	var lp := Struct.floodlight(k, Vector3(492.0, f, 133.0), 1.4, true, 5.5)
	pl.lamp(lp, Color(1.0, 0.85, 0.6), 2.4, 20.0, true, true)
	pl.spot("mine", "Nordstern Mine", Vector3(498.0, f, 140.0), 26.0)


static func tunnel(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var t := pl.terrain
	var f: float = Places.D["tunnel_floor"]
	var pz: float = Places.D["tunnel_pz"]
	pl.at(Vector3.ZERO)
	Struct.room(k, 95.4, pz, 104.6, 594.6, f + 0.02, 5.4, CON, "tar_in", CON, {"n": [[100.0, 99.0, 5.4]], "s": [[100.0, 99.0, 5.4]], "e": [[552.0, 1.3, 2.2]]}, 0.6)
	Struct.headwall(k, t, f, true, 595.6, 82.0, 118.0, 95.4, 104.6, 5.4, 0.8)
	k.box(Vector3(100.0, f + 6.3, 595.6), Vector3(10.4, 1.8, 0.9), "concrete")
	kd.box(Vector3(100.0, f + 6.4, 596.08), Vector3(9.0, 1.0, 0.05), "paint_blue")
	pl.label("POLARISTUNNEL", Vector3(100.0, f + 6.4, 596.12), 0.0, 0.011, Color(0.95, 0.93, 0.85))
	Struct.headwall(k, t, f, true, pz - 0.4, 86.0, 114.0, 95.4, 104.6, 5.4, 0.8)
	k.box(Vector3(100.0, f - 0.21, pz - 4.3), Vector3(16.4, 0.2, 8.8), "tar", Basis(Vector3.RIGHT, -atan2(0.24, 8.6)))
	k.box(Vector3(100.0, f + 6.3, pz - 0.4), Vector3(10.4, 1.8, 0.9), "concrete")
	kd.box(Vector3(100.0, f + 6.4, pz - 0.82), Vector3(9.0, 1.0, 0.05), "paint_blue")
	pl.label("POLARISTUNNEL", Vector3(100.0, f + 6.4, pz - 0.86), PI, 0.011, Color(0.95, 0.93, 0.85))
	# road markings, kerbs, haunches, cable trays and emergency lamps
	var z := pz + 2.0
	var n := 0
	while z < 574.0:
		kd.box(Vector3(100.0, f + 0.03, z), Vector3(0.14, 0.01, 2.2), "paint_white_in")
		z += 5.0
	for sx: float in [-1.0, 1.0]:
		kd.box(Vector3(100.0 + sx * 4.3, f + 0.06, (pz + 588.0) * 0.5), Vector3(0.6, 0.12, 588.0 - pz), CON)
		kd.box(Vector3(100.0 + sx * 4.2, f + 5.0, (pz + 588.0) * 0.5), Vector3(1.2, 0.2, 588.0 - pz), CON, Basis(Vector3(0, 0, 1), -sx * 0.8))
		kd.box(Vector3(100.0 + sx * 4.5, f + 3.9, (pz + 588.0) * 0.5), Vector3(0.12, 0.05, 588.0 - pz), "metal_in")
	z = pz + 6.0
	while z < 574.0:
		var sx := 1.0 if n % 2 == 0 else -1.0
		var lit := n % 3 == 0
		kd.box(Vector3(100.0 + sx * 4.5, f + 3.3, z), Vector3(0.12, 0.2, 0.5), "candle" if lit else "glass_dark")
		if lit:
			pl.lamp(Vector3(100.0 + sx * 3.9, f + 3.2, z), Color(1.0, 0.55, 0.2), 1.6, 14.0, n % 2 == 0)
		z += 7.0
		n += 1
	# the queue that never got out
	pl.at(Vector3(101.6, f + 0.05, pz + 16.0), 0.06)
	Struct.bus(k, Vector3.ZERO, 0.0, 0.0, false)
	pl.at(Vector3.ZERO)
	pl.note("n_tunnel_driver", Vector3(99.4, f + 0.05, pz + 12.5), 0.5)
	for c in [["pickup", 98.2, pz + 30.0, 0.3], ["offroader", 102.4, pz + 38.0, -0.2]]:
		var root := VehicleMesh.body(str(c[0]))
		root.transform = Transform3D(Basis(Vector3.UP, float(c[3])), Vector3(float(c[1]), f + 0.3, float(c[2])))
		pl.add_child(root)
		k.box(Vector3(float(c[1]), f + 0.1, float(c[2])), Vector3(1.9, 0.2, 4.4), "black_in", Basis(Vector3.UP, float(c[3])))
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 1.7, 4.6)
		cs.shape = shape
		cs.position.y = 0.6
		body.add_child(cs)
		root.add_child(body)
	pl.stash(Vector3(102.4, f + 0.3, pz + 40.4), Vector3(1.6, 1.0, 0.6), "wreck_tunnel", {"9mm_ap": 20, "bandage": 2, "silencer": 1}, "Wreck", "Search wreck")
	pl.at(Vector3(99.0, f + 0.05, 561.0), 0.25)
	Struct.truck(k, Vector3.ZERO, 0.0, true, -0.35)
	pl.at(Vector3.ZERO)
	# the fall: rock and slabs right up to the roof
	var fk := MeshKit.new()
	for layer in 4:
		Struct.rubble(fk, rng, Vector3(0.0, layer * 1.5, layer * 2.2 - 1.0), 5.5 - layer * 0.5, 14, "rock", 2.4)
	fk.box(Vector3(0, 2.7, 3.0), Vector3(9.0, 5.4, 5.0), "rock_in")
	for i in 5:
		fk.box(Vector3(-3.5 + i * 1.8, 1.2 + (i % 3) * 0.9, -7.0 + (i % 2) * 2.0), Vector3(2.6, 0.4, 3.6), CON, Basis(Vector3.RIGHT, 0.5 + i * 0.25) * Basis(Vector3(0, 0, 1), i * 0.5 - 1.0))
	var fd := MeshKit.new()
	Struct.rubble(fd, rng, Vector3(-3.6, 0.0, 2.5), 1.6, 9, "rock", 1.1)
	Struct.rubble(fd, rng, Vector3(3.7, 0.0, 3.5), 1.5, 8, "rock", 1.0)
	var fall := pl.barrier(Vector3(100.0, f, 580.0), 0.0, Vector3(9.2, 5.4, 14.0), "tunnel_fall", fk, fd)
	fall.tools = ["blasting_charge"]
	fall.tool_only = true
	fall.what = "The roof fall"
	fall.hint = "Nothing short of a blasting charge will shift this."
	fall.done_text = "You set the charge and run. The mountain coughs — and there is daylight beyond."
	fall.broke.connect(func() -> void:
		Sfx.play(pl, "shot_boom", Vector3(100.0, f + 2.0, 582.5), 8.0, 0.8)
		if pl.main and pl.main.get("player"):
			pl.main.player.shake(1.8))
	for i in 5:
		kd.tube(Vector3(96.0 + i * 2.0, f + 5.4, 571.0), Vector3(96.4 + i * 1.9, f + 3.6 - (i % 2) * 0.8, 572.5), 0.025, "rust", 4)
	# --- barrier outside
	for x: float in [96.0, 100.0, 104.0]:
		var xx: float = x
		k.box(Vector3(xx, f + 0.45, pz - 12.0), Vector3(2.6, 0.9, 0.7), "concrete")
		kd.box(Vector3(xx, f + 0.5, pz - 12.37), Vector3(2.4, 0.3, 0.02), "hazard")
	var sp := Struct.sign(k, Vector3(107.0, f, pz - 13.0), PI, 2.4, 1.0, "paint_red", 2.6)
	pl.label("TUNNEL GESPERRT\nEinsturzgefahr", sp, PI, 0.004, Color(0.95, 0.93, 0.85))
	# --- service room behind the jammed door
	var dk := MeshKit.new()
	dk.bbox(Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 1.3), 0.02, "steel_in")
	dk.box(Vector3(-0.06, 1.7, 0), Vector3(0.02, 0.3, 0.9), "hazard_in")
	dk.box(Vector3(-0.07, 1.05, 0.5), Vector3(0.05, 0.12, 0.06), "metal_in")
	var dd := MeshKit.new()
	dd.bbox(Vector3(1.6, 0.08, 0.2), Vector3(2.2, 0.1, 1.3), 0.02, "steel_in", Basis(Vector3.UP, 0.3))
	var jam := pl.barrier(Vector3(104.9, f, 552.0), 0.0, Vector3(0.3, 2.2, 1.3), "tunnel_door", dk, dd)
	jam.tools = ["crowbar"]
	jam.tool_only = true
	jam.what = "Jammed service door"
	jam.hint = "A crowbar would force it."
	jam.done_text = "The door gives with a bang."
	pl.label("BETRIEBSRAUM", Vector3(104.58, f + 2.45, 552.0), -PI * 0.5, 0.0026, Color(0.95, 0.93, 0.85))
	Struct.room(k, 105.2, 551.0, 112.0, 553.0, f, 2.4, CON, CON, CON, {"w": [[552.0, 99.0, 2.4]], "e": [[552.0, 99.0, 2.4]]}, 0.4)
	Struct.room(k, 112.4, 545.5, 130.0, 558.5, f, 2.8, CON, CON, CON, {"w": [[552.0, 2.0, 2.4]]}, 0.4)
	for i in 4:      # switch cabinets with a few lamps still on
		k.bbox(Vector3(116.0 + i * 1.3, f + 1.0, 545.9), Vector3(1.2, 2.0, 0.6), 0.02, "grey_in")
		for j in 4:
			kd.box(Vector3(115.7 + i * 1.3 + (j % 2) * 0.3, f + 1.5 - (j / 2) * 0.25, 546.22), Vector3(0.06, 0.06, 0.02), "led_green" if (i + j) % 3 != 0 else "led_red")
		kd.box(Vector3(116.0 + i * 1.3, f + 0.7, 546.21), Vector3(0.9, 0.5, 0.01), "black_in")
	Struct.generator(k, Vector3(127.5, f, 548.0), 0.0)
	Struct.shelf(k, rng, Vector3(129.6, f, 554.5), -PI * 0.5, 3.2)
	Interior.table(k, Vector3(119.0, f, 557.5), 0.0, 1.8, 0.8)
	Interior.chair(k, Vector3(119.0, f, 556.6), 0.0, "wood_in", true)
	pl.note("n_tunnel_order", Vector3(119.2, f + 0.78, 557.5), -0.2, "folder")
	Interior.lockers(k, Vector3(124.0, f, 558.1), PI, 3)
	Struct.bunk(k, Vector3(113.1, f, 547.5), 0.0)
	pl.chest(Vector3(114.0, f, 557.6), PI, "tunnel_service", {"key_bunker": 1, "medkit": 1, "batteries": 3, "556": 40, "fuel_can": 1, "muzzle_brake": 1}, "Duty chest")
	pl.lamp(Vector3(121.0, f + 2.4, 552.0), Color(0.8, 1.0, 0.85), 1.6, 12.0, true, true)
	kd.box(Vector3(121.0, f + 2.74, 552.0), Vector3(1.2, 0.06, 0.2), "lamp_glow")
	pl.spot("tunnel", "Polaris Tunnel", Vector3(100.0, f, pz - 6.0), 26.0)


static func bunker(pl: Places, q: int) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var t := pl.terrain
	var bi: int = Places.BUNKERS[q][0]
	var bj: int = Places.BUNKERS[q][1]
	var x0 := t.gx(bi)
	var z0 := t.gx(bj - 1)
	var surf: float = Places.D["bunker_h"][q]
	var f := surf - 4.7
	var name := "B-2" if q == 0 else "B-5"
	pl.at(Vector3.ZERO)
	Struct.room(k, x0 - 9.5, z0 - 3.6, x0 - 0.4, z0 + 11.6, f, 2.7, CON, CON, CON, {"e": [[z0 + 7.2, 1.2, 2.1]], "w": [[z0 + 4.0, 1.1, 2.1]]}, 0.4)
	Struct.room(k, x0 - 15.6, z0 - 3.6, x0 - 9.9, z0 + 11.6, f, 2.7, CON, CON, CON, {"e": [[z0 + 4.0, 99.0, 2.7]]}, 0.4)
	# stair shaft and the blockhouse over it
	var full := surf + 2.5 - f
	k.box(Vector3(x0 + 4.2, f + full * 0.5, z0 + 3.3), Vector3(0.4, full, 10.2), "concrete")
	k.box(Vector3(x0 + 2.0, f + full * 0.5, z0 + 8.2), Vector3(4.8, full, 0.4), "concrete")
	k.box(Vector3(x0 - 0.2, f + 2.7 + (full - 2.7) * 0.5, z0 + 3.3), Vector3(0.4, full - 2.7, 10.2), "concrete")
	k.box(Vector3(x0 + 2.0, (f + surf) * 0.5, z0 - 0.2), Vector3(4.4, surf - f, 0.4), CON)
	k.box(Vector3(x0 + 2.0, surf - 0.05, z0 - 1.0), Vector3(4.4, 0.2, 2.0), CON)
	Struct.wall(k, Vector3(x0 - 0.4, surf, z0 - 1.8), Vector3.RIGHT, 4.8, 2.5, "concrete", [[1.8, 3.05, 0.0, 2.1]], 0.4)
	k.box(Vector3(x0 + 2.0, surf + 2.65, z0 + 3.3), Vector3(5.4, 0.3, 10.8), "concrete")
	k.box(Vector3(x0 + 2.0, surf + 2.95, z0 + 3.3), Vector3(5.2, 0.35, 10.6), "snow")
	Struct.ramp(k, Vector3(x0 + 2.0, f, z0 + 6.4), Vector3(x0 + 2.0, surf, z0), 3.6, CON)
	k.box(Vector3(x0 + 2.0, f, z0 + 7.3), Vector3(4.0, 0.1, 1.9), CON)
	for sx: float in [0.25, 3.75]:
		kd.tube(Vector3(x0 + sx, f + 1.0, z0 + 6.3), Vector3(x0 + sx, surf + 1.0, z0 + 0.1), 0.025, "steel_in", 5)
	for i in 2:
		k.cyl(Vector3(x0 - 4.0 - i * 6.0, surf - 0.3, z0 + 2.0 + i * 5.0), 0.16, 1.5, "steel", 8)
		kd.cyl(Vector3(x0 - 4.0 - i * 6.0, surf + 1.2, z0 + 2.0 + i * 5.0), 0.26, 0.14, "steel", 8, 0.1)
	kd.box(Vector3(x0 + 2.0, surf + 2.3, z0 - 2.02), Vector3(2.2, 0.36, 0.03), "paint_yellow")
	pl.label("SCHUTZRAUM " + name, Vector3(x0 + 2.0, surf + 2.3, z0 - 2.04), PI, 0.0034)
	pl.door(Vector3(x0 + 1.4, surf + 0.05, z0 - 1.8), 0.0, 1.22, 2.05, true, "bunker%d_door" % (q + 1), "key_bunker" if q == 0 else "crowbar")
	pl.door(Vector3(x0 - 0.2, f, z0 + 6.6), -PI * 0.5, 1.2, 2.08, true)
	pl.lamp(Vector3(x0 + 2.0, f + 3.4, z0 + 6.0), Color(1.0, 0.5, 0.2), 0.9, 9.0, true)
	kd.box(Vector3(x0 + 4.0, f + 3.4, z0 + 6.0), Vector3(0.06, 0.16, 0.3), "candle")
	# --- inside
	pl.lamp(Vector3(x0 - 5.0, f + 2.4, z0 + 4.0), Color(0.85, 1.0, 0.9), 1.5, 12.0, q == 1, true)
	kd.box(Vector3(x0 - 5.0, f + 2.66, z0 + 4.0), Vector3(1.2, 0.06, 0.2), "lamp_glow")
	for i in 3:
		Struct.bunk(k, Vector3(x0 - 8.9 + i * 1.5, f, z0 - 2.4), 0.0, "olive_in" if q == 0 else "cloth_in")
	Interior.table(k, Vector3(x0 - 5.0, f, z0 + 4.4), 0.0, 2.0, 0.9)
	Interior.chair(k, Vector3(x0 - 5.5, f, z0 + 5.4), PI)
	Interior.chair(k, Vector3(x0 - 4.4, f, z0 + 3.5), 0.2)
	Struct.shelf(k, rng, Vector3(x0 - 5.0, f, z0 + 11.2), PI, 4.0)
	Struct.generator(k, Vector3(x0 - 1.4, f, z0 - 2.2), 0.0)
	Interior.table(k, Vector3(x0 - 1.1, f, z0 + 2.4), PI * 0.5, 1.8, 0.8)
	Interior.radio(kd, Vector3(x0 - 1.0, f + 0.78, z0 + 2.0), -PI * 0.5)
	Interior.chair(k, Vector3(x0 - 2.0, f, z0 + 2.4), PI * 0.5)
	pl.note("n_bunker%d" % (q + 1), Vector3(x0 - 1.15, f + 0.78, z0 + 2.9) if q == 0 else Vector3(x0 - 5.0, f + 0.78, z0 + 4.4), 1.3, "folder" if q == 0 else "paper")
	# store room
	Struct.shelf(k, rng, Vector3(x0 - 15.2, f, z0 + 1.0), PI * 0.5, 4.0)
	Struct.shelf(k, rng, Vector3(x0 - 15.2, f, z0 + 8.0), PI * 0.5, 4.0)
	for i in 4:
		k.xf = Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(x0 - 11.0 - (i % 2) * 0.9, f, z0 - 2.6 + i * 0.5))
		Props.crate(k, 0.6 + (i % 2) * 0.2)
	k.xf = Transform3D(Basis.IDENTITY, Vector3(x0 - 11.0, f, z0 + 10.6))
	Props.barrel(k)
	pl.at(Vector3.ZERO)
	pl.lamp(Vector3(x0 - 12.8, f + 2.3, z0 + 4.0), Color(1.0, 0.8, 0.55), 0.9, 9.0, true)
	if q == 0:
		pl.chest(Vector3(x0 - 12.8, f, z0 + 11.0), PI, "bunker1", {"key_armory": 1, "556": 60, "kevlar_vest": 1, "medkit": 1, "red_dot": 1}, "Strongbox")
	else:
		pl.chest(Vector3(x0 - 12.8, f, z0 + 11.0), PI, "bunker2", {"canned_food": 6, "hot_tea": 3, "medkit": 2, "parka": 1, "large_pack": 1, "batteries": 4, "12g": 16}, "Shelter stores")
	pl.spot("bunker%d" % (q + 1), "Shelter " + name, Vector3(x0 + 2.0, surf, z0 - 3.0), 13.0)
