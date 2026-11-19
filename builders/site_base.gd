class_name SiteBase
extends RefCounted
## The two big compounds above ground: Fort Nordwacht and the research station Polaris-7.

const CON := "concrete_in"
const F := 0.07      # floor step that boots still walk over


static func _glass(kd: MeshKit, c: Vector3, along_x: bool, w: float, lit := false) -> void:
	kd.box(c, Vector3(w, 0.9, 0.03) if along_x else Vector3(0.03, 0.9, w), "glass_lit" if lit else "glass_dark")
	kd.box(c, Vector3(0.05, 0.9, 0.05), "metal")


static func _gate_leaf(g: MeshKit, hinge: Vector3, dir: float, open: float) -> void:
	var bs := Basis(Vector3.UP, open * dir)
	var w := 4.2 * dir
	for y: float in [0.15, 2.5]:
		var yy: float = y
		g.tube(hinge + Vector3(0, yy, 0), hinge + bs * Vector3(w, 0, 0) + Vector3(0, yy, 0), 0.05, "steel", 5)
	for q in 4:
		var x := w * q / 3.0
		g.tube(hinge + bs * Vector3(x, 0, 0) + Vector3(0, 0.15, 0), hinge + bs * Vector3(x, 0, 0) + Vector3(0, 2.5, 0), 0.05, "steel", 5)
	g.tube(hinge + Vector3(0, 0.15, 0), hinge + bs * Vector3(w, 0, 0) + Vector3(0, 2.5, 0), 0.035, "steel", 4)
	g.box(hinge + bs * Vector3(w * 0.5, 0, 0) + Vector3(0, 1.3, 0), Vector3(4.2, 2.3, 0.02), "chainlink", bs)
	g.box(hinge + bs * Vector3(w * 0.5, 0, 0.04) + Vector3(0, 1.3, 0), Vector3(4.0, 0.22, 0.03), "hazard", bs)


static func base(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var y: float = Places.D["base_h"]
	var o := Vector3(Places.BASE.x, y, Places.BASE.y)
	pl.at(o)
	# --- fence, with a gate in the south and one newer panel in the east
	var X := 46.0
	var Z := 34.0
	Struct.fence(k, Vector3(-X, 0, Z), Vector3(-4.4, 0, Z))
	Struct.fence(k, Vector3(4.4, 0, Z), Vector3(X, 0, Z))
	Struct.fence(k, Vector3(X, 0, Z), Vector3(X, 0, 12.0))
	Struct.fence(k, Vector3(X, 0, 8.5), Vector3(X, 0, -Z))
	Struct.fence(k, Vector3(X, 0, -Z), Vector3(-X, 0, -Z))
	Struct.fence(k, Vector3(-X, 0, -Z), Vector3(-X, 0, Z))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 4.6, 1.5, Z), Vector3(0.5, 3.0, 0.5), "concrete")
		kd.sphere(Vector3(sx * 4.6, 3.1, Z), 0.16, "led_red", 8, 5)
	var gi := MeshKit.new()
	_gate_leaf(gi, Vector3(-4.3, 0, 0), 1.0, 0.0)
	_gate_leaf(gi, Vector3(4.3, 0, 0), -1.0, 0.0)
	gi.box(Vector3(0, 1.1, -0.08), Vector3(3.0, 0.14, 0.08), "metal")
	var gw := MeshKit.new()
	_gate_leaf(gw, Vector3(-4.3, 0, 0), 1.0, 1.35)
	_gate_leaf(gw, Vector3(4.3, 0, 0), -1.0, 1.15)
	var gate := pl.barrier(o + Vector3(0, 0, Z), 0.0, Vector3(8.6, 2.8, 0.3), "base_gate", gi, gw)
	gate.ram_mass = 1500.0
	gate.what = "Gate, barred from inside"
	gate.hint = "Something heavy at speed might burst it. Or there is another way in."
	gate.inside = Vector3(0, 0, -1)
	gate.inside_text = "You lift the bar. The gate swings open."
	var sp := Struct.sign(k, Vector3(8.5, 0, Z + 0.6), 0.0, 3.0, 0.8, "olive", 3.2)
	pl.label("FORT NORDWACHT", sp, 0.0, 0.0055, Color(0.9, 0.88, 0.8))
	var pi := MeshKit.new()
	Struct.fence(pi, Vector3(-1.75, 0, 0), Vector3(1.75, 0, 0))
	var pw := MeshKit.new()
	for sx: float in [-1.75, 1.75]:
		pw.cyl(Vector3(sx, -0.3, 0), 0.05, 2.95, "steel", 6)
		pw.box(Vector3(sx * 0.72, 1.3, 0.25 * signf(sx)), Vector3(0.9, 2.4, 0.02), "chainlink", Basis(Vector3.UP, 0.9 * signf(sx)))
	pw.tube(Vector3(-1.75, 2.6, 0), Vector3(1.75, 2.6, 0), 0.025, "steel", 5)
	var panel := pl.barrier(o + Vector3(X, 0, 10.25), PI * 0.5, Vector3(3.5, 2.6, 0.3), "base_fence", pi, pw)
	panel.tools = ["bolt_cutters"]
	panel.tool_only = true
	panel.what = "Chain-link fence"
	panel.hint = "This panel is newer and thinner than the rest. Bolt cutters would go through it."
	panel.done_text = "The wire parts with a snap."
	# the drift over the north-west corner: a way in for anyone who walks the fence
	var dg := Basis(Vector3.UP, PI * 0.25)
	k.ball(Vector3(-X, -3.0, -Z), Vector3(5.0, 6.1, 13.0), "gravel" if GameMode.summer() else "snow", 14, 8, dg)
	kd.ball(Vector3(-X + 5.0, -0.6, -Z - 2.0), Vector3(3.0, 1.6, 4.0), "gravel" if GameMode.summer() else "snow", 10, 5, dg)
	kd.ball(Vector3(-X - 2.0, -0.5, -Z + 5.0), Vector3(3.4, 1.5, 4.4), "gravel" if GameMode.summer() else "snow", 10, 5, dg)
	# --- command post: ops room and armoury
	Struct.room(k, -33.0, -22.5, -24.2, -13.5, F, 2.9, "concrete", CON, CON,
		{"s": [[-29.0, 1.1, 2.1], [-26.0, 1.4, 2.0, 1.0]], "n": [[-31.0, 1.4, 2.0, 1.0], [-27.0, 1.4, 2.0, 1.0]], "e": [[-18.0, 1.1, 2.1]]})
	Struct.room(k, -23.8, -22.5, -19.0, -13.5, F, 2.9, "concrete", CON, CON, {"w": [[-18.0, 99.0, 2.9]]})
	k.box(Vector3(-26.0, 3.35, -18.0), Vector3(15.6, 0.3, 10.4), "concrete")
	pl.roofed(-33.0, -22.5, -19.0, -13.5, 3.0, true)
	k.box(Vector3(-26.0, 3.65, -18.0), Vector3(15.2, 0.3, 10.0), "snow")
	_glass(kd, Vector3(-26.0, 1.57, -13.3), true, 1.4, true)
	_glass(kd, Vector3(-31.0, 1.57, -22.7), true, 1.4)
	_glass(kd, Vector3(-27.0, 1.57, -22.7), true, 1.4)
	pl.door(o + Vector3(-29.55, F, -13.3), 0.0, 1.1, 2.08)
	pl.door(o + Vector3(-24.0, F, -18.55), -PI * 0.5, 1.1, 2.08, true, "armory_door", "key_armory")
	pl.label("KOMMANDANTUR", o + Vector3(-29.0, 2.45, -13.08), 0.0, 0.003, Color(0.95, 0.93, 0.85))
	Interior.console(k, Vector3(-32.4, F, -18.0), PI * 0.5)
	Interior.table(k, Vector3(-28.5, F, -19.0), 0.0, 2.4, 1.2)
	kd.box(Vector3(-28.5, F + 0.775, -19.0), Vector3(1.8, 0.01, 1.0), "paper_in")
	kd.box(Vector3(-28.9, F + 0.782, -19.1), Vector3(0.5, 0.01, 0.4), "teal_in", Basis(Vector3.UP, 0.4))
	Interior.chair(k, Vector3(-28.5, F, -17.9), PI)
	Interior.chair(k, Vector3(-27.0, F, -19.4), -PI * 0.5, "wood_in", true)
	pl.note("n_base_orders", o + Vector3(-27.9, F + 0.79, -18.8), -0.3, "folder")
	Interior.lockers(k, Vector3(-25.2, F, -21.9), 0.0, 2)
	kd.box(Vector3(-29.0, 1.9, -22.28), Vector3(1.6, 1.0, 0.02), "red_in")
	kd.box(Vector3(-29.0, 1.9, -22.26), Vector3(0.4, 0.4, 0.02), "black_in")
	pl.lamp(o + Vector3(-28.5, 2.5, -18.0), Color(1.0, 0.8, 0.55), 2.0, 11.0, true, true)
	# armoury: racks, ammo tins, the strongbox
	for i in 2:
		k.box(Vector3(-19.25, 1.0, -21.0 + i * 5.0), Vector3(0.3, 2.0, 2.4), "metal_in")
		for j in 5:
			kd.tube(Vector3(-19.5, 0.35, -21.9 + i * 5.0 + j * 0.45), Vector3(-19.42, 1.45, -21.9 + i * 5.0 + j * 0.45), 0.025, "black_in", 5)
			kd.box(Vector3(-19.52, 0.5, -21.9 + i * 5.0 + j * 0.45), Vector3(0.05, 0.4, 0.09), "wood_in")
	Struct.shelf(k, rng, Vector3(-21.4, F, -22.1), 0.0, 3.4)
	pl.chest(o + Vector3(-21.4, F, -14.1), PI, "armory", {"keycard_lab": 1, "sniper_rifle": 1, "338": 20, "556_ap": 40, "plate_carrier": 1, "scope": 1, "silencer": 1}, "Strongbox")
	pl.lamp(o + Vector3(-21.4, 2.4, -18.0), Color(0.8, 0.95, 1.0), 1.0, 8.0)
	# --- barracks
	for b in 2:
		var bx := -31.0 + b * 13.0
		Struct.quonset(k, Vector3(bx, 0, 11.0), 0.0, 12.0)
		pl.leaf(o + Vector3(bx - 0.44, 0.08, 17.0), 0.0, 0.88, 2.06, "olive", "steel")
		pl.roofed(bx - 2.9, 5.0, bx + 2.9, 17.0, 3.0, b == 0)
		for i in 3:
			Struct.bunk(k, Vector3(bx - 1.95, 0.08, 6.6 + i * 3.0), 0.0)
			if i < 2:
				Struct.bunk(k, Vector3(bx + 1.95, 0.08, 6.6 + i * 3.0), 0.0)
		Interior.lockers(k, Vector3(bx + 2.0, 0.08, 14.6), -PI * 0.5, 2)
		k.cyl(Vector3(bx, 0.08, 6.0), 0.3, 0.8, "metal_in", 8)
		k.cyl(Vector3(bx, 0.88, 6.0), 0.07, 2.2, "metal_in", 6)
		if b == 0:
			pl.lamp(o + Vector3(bx, 2.3, 11.0), Color(1.0, 0.7, 0.4), 1.4, 9.0, true)
			kd.sphere(Vector3(bx, 2.75, 11.0), 0.08, "lamp_glow", 6, 4)
	pl.note("n_base_diary", o + Vector3(-16.05, 0.72, 9.4), 0.4, "book")
	pl.chest(o + Vector3(-29.2, 0.08, 15.6), 0.0, "barracks", {"snow_pants": 1, "mittens": 1, "canned_food": 3, "9mm": 30, "bandage": 2, "helmet": 1}, "Footlocker")
	# --- vehicle shed
	Struct.room(k, 19.0, -28.0, 33.0, -18.0, 0.04, 3.8, "panel", CON, "panel", {"s": [[26.0, 99.0, 3.8]]}, 0.15)
	k.box(Vector3(26.0, 4.2, -23.0), Vector3(14.8, 0.3, 10.8), "snow")
	for xx: float in [19.0, 26.0, 33.0]:
		var px: float = xx
		k.box(Vector3(px, 1.9, -17.9), Vector3(0.25, 3.8, 0.25), "steel")
	Interior.workbench(k, rng, Vector3(26.0, 0.04, -27.5), 0.0, 4.0)
	for i in 4:
		k.xf = Transform3D(Basis.IDENTITY, o + Vector3(31.6 - (i % 2) * 0.8, 0.04, -26.5 + i * 0.75))
		Props.barrel(k)
	pl.at(o)
	var wreck := VehicleMesh.body("tracked")
	wreck.transform = Transform3D(Basis(Vector3.UP, 0.1), o + Vector3(22.5, 0.5, -22.5))
	pl.add_child(wreck)
	k.box(Vector3(22.5, 0.9, -22.5), Vector3(2.6, 1.8, 5.2), "black_in", Basis(Vector3.UP, 0.1))
	pl.chest(o + Vector3(29.0, 0.04, -27.3), 0.0, "base_garage", {"fuel_can": 2, "scrap": 4, "snow_chains": 1, "winch_kit": 1}, "Workshop chest")
	pl.lamp(o + Vector3(26.0, 3.3, -22.0), Color(1.0, 0.85, 0.6), 1.6, 13.0, true)
	# --- helipad with what is left of the helicopter
	k.cyl(Vector3(21.0, -0.2, 13.0), 8.0, 0.26, "concrete", 24)
	for part in [[-1.2, 0.0, 0.4, 3.4], [1.2, 0.0, 0.4, 3.4], [0.0, 0.0, 2.4, 0.4]]:
		kd.box(Vector3(21.0 + float(part[0]), 0.07, 13.0 + float(part[1])), Vector3(float(part[2]), 0.01, float(part[3])), "paint_white")
	Struct.heli(k, Vector3(22.0, 0.08, 12.0), 2.3)
	pl.at(o)
	# --- towers, mast, tanks, containers, lights
	Struct.tower(k, Vector3(-39.0, 0, 26.0), PI, 7.0)
	Struct.tower(k, Vector3(39.0, 0, -26.0), 0.0, 7.0)
	var top := Struct.mast(k, Vector3(-40.0, 0, -8.0), 24.0)
	pl.lamp(k.xf * top, Color(1.0, 0.1, 0.05), 2.5, 26.0, true)
	Struct.tank(k, Vector3(38.0, 0, -2.0), 0.0, 6.0, 1.2, "olive")
	Struct.tank(k, Vector3(41.6, 0, -2.0), 0.0, 6.0, 1.2, "olive")
	Struct.container(k, Vector3(4.0, 0, -28.5), PI * 0.5, "olive", true)
	pl.cargo_doors(o + Vector3(4.0, 0, -28.5), PI * 0.5, "olive")
	pl.chest(o + Vector3(2.0, 0.07, -28.5), PI * 0.5, "base_container_b", {"556": 40, "canned_food": 3, "batteries": 2, "scrap": 4}, "Ration crate")
	Struct.container(k, Vector3(4.0, 0, -25.6), PI * 0.5, "paint_blue", true)
	pl.cargo_doors(o + Vector3(4.0, 0, -25.6), PI * 0.5, "paint_blue")
	pl.chest(o + Vector3(2.0, 0.07, -25.6), PI * 0.5, "base_container_c", {"cloth": 4, "fuel_can": 1, "rope": 1, "hand_warmer": 3}, "Stores crate")
	Struct.container(k, Vector3(4.6, 2.6, -27.0), PI * 0.5 + 0.1, "rust")
	Struct.container(k, Vector3(12.5, 0, -27.0), 0.15, "paint_red", true)
	pl.cargo_doors(o + Vector3(12.5, 0, -27.0), 0.15, "paint_red")
	pl.chest(o + Basis(Vector3.UP, 0.15) * Vector3(0, 0.07, -2.0) + Vector3(12.5, 0, -27.0), 0.15, "base_container", {"762": 30, "12g": 16, "medkit": 1, "armor_plates": 1}, "Supply crate")
	for l in [[-7.0, 31.0, PI, true], [7.0, 31.0, PI, true], [-12.0, -6.0, 0.6, false], [30.0, 2.0, -1.2, true]]:
		var lp := Struct.floodlight(k, Vector3(float(l[0]), 0, float(l[1])), float(l[2]), bool(l[3]))
		if bool(l[3]):
			pl.lamp(k.xf * lp, Color(0.9, 0.95, 1.0), 3.0, 24.0, float(l[0]) > 0.0, true)
	Struct.room(k, 7.0, 28.6, 10.4, 32.0, F, 2.4, "panel", "planks_in", "panel", {"w": [[30.3, 1.0, 2.05]], "s": [[8.7, 1.6, 1.9, 1.0]], "n": [[8.7, 1.6, 1.9, 1.0]]}, 0.14)
	k.box(Vector3(8.7, 2.75, 30.3), Vector3(4.2, 0.22, 4.2), "snow")
	_glass(kd, Vector3(8.7, 1.5, 32.08), true, 1.6)
	_glass(kd, Vector3(8.7, 1.5, 28.52), true, 1.6)
	Interior.chair(k, Vector3(9.6, F, 30.3), -PI * 0.5)
	Struct.sandbags(k, Vector3(-7.5, 0, 28.5), 0.2, 6, 5)
	Struct.sandbags(k, Vector3(6.0, 0, 26.0), -0.3, 5, 5)
	Struct.sandbags(k, Vector3(-22.0, 0, -11.5), 0.0, 7, 5)
	# concrete barriers across the yard: cover for whoever gets there first
	for b: Array in [[-9.5, -1.0, 0.15], [-17.5, 3.0, -0.2], [-11.0, 9.0, 0.05], [-3.5, -6.0, 1.3], [-20.0, 12.0, 1.1]]:
		var bb := Basis(Vector3.UP, float(b[2]))
		k.bbox(Vector3(b[0], 0.3, b[1]), Vector3(2.6, 0.6, 0.6), 0.08, "concrete", bb)
		k.bbox(Vector3(b[0], 0.8, b[1]), Vector3(2.6, 0.5, 0.3), 0.06, "concrete", bb)
		kd.box(Vector3(b[0], 0.55, b[1]), Vector3(2.62, 0.08, 0.62), "hazard", bb)
	k.cyl(Vector3(-14.0, -0.3, -11.0), 0.05, 8.3, "steel", 6)
	kd.box(Vector3(-13.1, 7.4, -11.0), Vector3(1.8, 1.1, 0.02), "red")
	kd.box(Vector3(-13.1, 7.4, -10.985), Vector3(0.45, 0.45, 0.01), "black")
	for i in 5:
		k.xf = Transform3D(Basis(Vector3.UP, i * 0.8), o + Vector3(-4.0 + (i % 3) * 1.0, 0, 4.0 + (i / 3) * 1.1))
		Props.crate(k, 0.7 + (i % 2) * 0.2)
	pl.at(o)
	for g in [["base_1", "assault_rifle", Vector3(3, 0, 29)], ["base_2", "shotgun", Vector3(-24, 0, -9)], ["base_3", "marksman_rifle", Vector3(34, 0, -14)],
			["base_4", "smg", Vector3(-22, 0, 22)], ["base_5", "pistol", Vector3(14, 0, -12)], ["base_6", "sniper_rifle", Vector3(-36, 0, 18)]]:
		pl.crews.append([g[0], g[1], o + (g[2] as Vector3) + Vector3(0, 0.4, 0)])
	pl.spot("base", "Fort Nordwacht", o, 58.0)


static func station(pl: Places) -> void:
	var k := pl.k
	var kd := pl.kd
	var rng := pl.rng
	var y: float = Places.D["station_h"]
	var o := Vector3(Places.STATION.x, y, Places.STATION.y)
	pl.at(o)
	# --- laboratory (keycard) with the server room and office at its east end
	Struct.room(k, -22.0, -16.0, -8.4, -6.0, F, 3.0, "panel", "white_in", "panel_in",
		{"n": [[-19.0, 1.6, 2.0, 1.0], [-15.0, 1.6, 2.0, 1.0], [-11.0, 1.6, 2.0, 1.0]], "e": [[-11.0, 1.1, 2.1]]}, 0.3)
	Struct.room(k, -8.1, -16.0, 0.0, -6.0, F, 3.0, "panel", "grey_in", "panel_in", {"w": [[-11.0, 99.0, 3.0]], "s": [[-4.0, 1.15, 2.1]], "e": [[-12.0, 1.4, 2.0, 1.0]]}, 0.3)
	k.box(Vector3(-11.0, 3.4, -11.0), Vector3(23.4, 0.3, 11.0), "panel")
	pl.roofed(-22.0, -16.0, 0.0, -6.0, 3.1)
	k.box(Vector3(-11.0, 3.7, -11.0), Vector3(23.0, 0.3, 10.6), "snow")
	for side in [[-11.0, -5.68, 22.8, 0.03], [-11.0, -16.32, 22.8, 0.03]]:
		kd.box(Vector3(float(side[0]), 2.55, float(side[1])), Vector3(float(side[2]), 0.5, float(side[3])), "panel_orange")
	for wx: float in [-19.0, -15.0, -11.0]:
		_glass(kd, Vector3(float(wx), 1.57, -16.15), true, 1.6, wx == -15.0)
	_glass(kd, Vector3(0.15, 1.57, -12.0), false, 1.4)
	pl.label("POLARIS-7", o + Vector3(-14.5, 2.55, -5.65), 0.0, 0.0075, Color(0.97, 0.95, 0.9))
	pl.door(o + Vector3(-4.58, F, -5.85), 0.0, 1.15, 2.08, true, "lab_door", "keycard_lab")
	kd.box(Vector3(-3.2, 1.3, -5.66), Vector3(0.12, 0.18, 0.04), "black")
	kd.box(Vector3(-3.2, 1.36, -5.63), Vector3(0.03, 0.03, 0.01), "led_red")
	k.cyl(Vector3(-18.0, 3.8, -11.0), 0.3, 0.7, "steel", 8)
	Struct.dish(k, Vector3(-4.0, 3.8, -13.0), 2.4, 0.9)
	# lab: two tanks that still glow, benches, a board full of sums
	Struct.specimen(k, Vector3(-20.6, F, -7.2))
	Struct.specimen(k, Vector3(-20.6, F, -9.4))
	pl.lamp(o + Vector3(-19.6, 1.4, -8.3), Color(0.2, 0.85, 1.0), 1.6, 8.0, false, true)
	Struct.lab_bench(k, rng, Vector3(-14.5, F, -6.5), PI, 6.0, true)
	Struct.lab_bench(k, rng, Vector3(-15.0, F, -11.0), 0.0, 5.0)
	Struct.lab_bench(k, rng, Vector3(-15.0, F, -11.85), PI, 5.0, true)
	kd.box(Vector3(-21.82, 1.7, -13.0), Vector3(0.03, 1.2, 2.6), "white_in")
	for i in 7:
		kd.box(Vector3(-21.8, 2.1 - i * 0.14, -13.0 + sin(i * 2.0) * 0.4), Vector3(0.01, 0.02, 1.2 + cos(i * 3.0) * 0.6), "navy_in")
	pl.note("n_station_beast", o + Vector3(-13.2, F + 0.92, -11.0), 0.5, "folder")
	pl.chest(o + Vector3(-9.2, F, -15.3), 0.0, "lab", {"flare": 8, "medkit": 2, "painkillers": 2, "batteries": 4, "338": 15, "762_ap": 30, "hand_warmer": 3}, "Sample case")
	pl.lamp(o + Vector3(-15.0, 2.6, -11.0), Color(0.8, 0.92, 1.0), 1.4, 12.0, true)
	kd.box(Vector3(-15.0, 2.96, -11.0), Vector3(1.4, 0.06, 0.25), "lamp_glow")
	# office and servers
	for i in 3:
		Struct.rack(k, rng, Vector3(-0.55, F, -8.0 - i * 0.95), -PI * 0.5, i != 1)
	Interior.table(k, Vector3(-5.0, F, -15.2), 0.0, 2.2, 0.9)
	Interior.chair(k, Vector3(-5.0, F, -14.2), PI)
	kd.bbox(Vector3(-5.4, F + 1.05, -15.4), Vector3(0.55, 0.4, 0.05), 0.01, "grey_in")
	kd.box(Vector3(-5.4, F + 1.05, -15.37), Vector3(0.49, 0.34, 0.005), "screen_on")
	pl.note("n_station_log", o + Vector3(-4.4, F + 0.78, -15.1), -0.2, "book")
	pl.lamp(o + Vector3(-4.0, 2.5, -11.0), Color(0.6, 1.0, 0.85), 1.0, 9.0)
	# --- dormitory
	Struct.room(k, 6.0, -16.0, 20.0, -9.0, F, 2.7, "panel", "planks_in", "panel_in", {"s": [[13.0, 1.1, 2.1], [9.0, 1.4, 2.0, 1.0], [17.0, 1.4, 2.0, 1.0]]}, 0.3)
	k.box(Vector3(13.0, 3.1, -12.5), Vector3(15.0, 0.3, 8.0), "panel")
	pl.roofed(6.0, -16.0, 20.0, -9.0, 2.8, true)
	k.box(Vector3(13.0, 3.4, -12.5), Vector3(14.6, 0.3, 7.6), "snow")
	kd.box(Vector3(13.0, 2.3, -8.68), Vector3(14.4, 0.45, 0.03), "panel_orange")
	_glass(kd, Vector3(9.0, 1.57, -8.85), true, 1.4, true)
	_glass(kd, Vector3(17.0, 1.57, -8.85), true, 1.4)
	pl.door(o + Vector3(12.45, F, -8.85), 0.0, 1.1, 2.08)
	for i in 3:
		Struct.bunk(k, Vector3(7.0 + i * 1.6, F, -14.8), 0.0, ["teal_in", "cloth_in", "navy_in"][i])
	Interior.kitchen(k, rng, Vector3(18.0, F, -15.5), 0.0, 3.0, true)
	Interior.table(k, Vector3(16.0, F, -11.5), 0.0, 1.8, 0.9, "check_in")
	Interior.chair(k, Vector3(16.0, F, -10.6), PI)
	Interior.chair(k, Vector3(15.0, F, -12.3), 0.3, "wood_in", true)
	pl.chest(o + Vector3(6.8, F, -9.9), PI * 0.5, "station_dorm", {"mittens": 1, "snow_pants": 1, "canned_food": 3, "hot_tea": 2, "bandage": 2, "fur_boots": 1}, "Kit box")
	pl.lamp(o + Vector3(13.0, 2.3, -12.5), Props.WARM, 1.8, 10.0, false, true)
	# --- containment C: where it went through the wall
	Struct.room(k, -36.0, -16.0, -27.0, -8.0, F, 3.0, "panel", "white_in", "", {"e": [[-12.0, 5.0, 3.0]], "s": [[-31.0, 4.0, 3.0, 1.6]]}, 0.3)
	k.box(Vector3(-33.5, 3.3, -13.5), Vector3(5.0, 0.3, 5.6), "panel", Basis(Vector3(0, 0, 1), 0.12))
	k.box(Vector3(-28.5, 0.9, -9.5), Vector3(4.6, 0.3, 4.0), "panel", Basis(Vector3(0, 0, 1), -0.5) * Basis(Vector3.RIGHT, 0.2))
	k.cyl(Vector3(-32.0, F, -12.0), 0.5, 0.3, "metal_in", 12)
	for i in 12:
		var a := i * 0.9
		kd.cyl(Vector3(-32.0 + cos(a) * (0.5 + i * 0.25), F, -12.0 + sin(a) * (0.4 + i * 0.2)), 0.12 + (i % 3) * 0.05, 0.3 + (i % 4) * 0.25, "ice", 5, 0.0)
	for i in 7:      # a trail of ice leading out towards the lake
		kd.cyl(Vector3(-25.5 + i * 2.6, 0.0, -11.0 + i * 2.2 + sin(i * 2.0)), 0.18, 0.5 + (i % 3) * 0.3, "ice", 5, 0.0)
		kd.ball(Vector3(-24.5 + i * 2.6, 0.03, -10.0 + i * 2.2), Vector3(1.1, 0.06, 0.7), "ice", 8, 3, Basis(Vector3.UP, i * 0.7))
	Struct.rubble(k, rng, Vector3(-26.0, 0, -12.0), 2.6, 9, "concrete", 0.8)
	pl.label("C", o + Vector3(-31.0, 2.3, -7.66), 0.0, 0.012, Color(0.8, 0.36, 0.08))
	# --- generator hut, tanks, dome, dishes, masts
	Struct.room(k, 24.0, -3.0, 29.0, 2.0, F, 2.5, "panel", CON, "panel", {"w": [[-0.5, 1.1, 2.1]]}, 0.14)
	k.box(Vector3(26.5, 2.85, -0.5), Vector3(5.8, 0.22, 5.8), "snow")
	Struct.generator(k, Vector3(27.4, F, -0.5), 0.0)
	pl.roofed(24.0, -3.0, 29.0, 2.0, 2.6, true)
	for i in 3:
		k.xf = Transform3D(Basis.IDENTITY, o + Vector3(25.0, F, 1.2 - i * 0.75))
		Props.barrel(k)
	pl.at(o)
	pl.lamp(o + Vector3(26.0, 2.1, -0.5), Color(1.0, 0.7, 0.35), 1.6, 9.0, true)
	pl.chest(o + Vector3(28.3, F, 1.4), -PI * 0.5, "station_gen", {"fuel_can": 2, "scrap": 2, "batteries": 2, "aux_tank": 1}, "Tool box")
	Struct.tank(k, Vector3(14.0, 0, 21.0), PI * 0.5, 5.0, 1.0)
	Struct.tank(k, Vector3(14.0, 0, 24.4), PI * 0.5, 5.0, 1.0)
	Struct.radome(k, Vector3(-30.0, 0, 12.0))
	Struct.dish(k, Vector3(-16.0, 0, 17.0), 0.9, 1.8)
	var top := Struct.mast(k, Vector3(-36.0, 0, -25.0), 18.0)
	pl.lamp(k.xf * top, Color(1.0, 0.1, 0.05), 2.0, 22.0)
	k.cyl(Vector3(33.0, -0.3, -24.0), 0.05, 6.3, "steel", 6)
	kd.box(Vector3(33.0, 5.4, -24.0), Vector3(0.3, 0.4, 0.2), "white")
	for q in 3:
		var a := q * TAU / 3.0
		kd.tube(Vector3(33.0, 6.0, -24.0), Vector3(33.0 + cos(a) * 0.4, 6.0, -24.0 + sin(a) * 0.4), 0.012, "steel", 4)
		kd.sphere(Vector3(33.0 + cos(a) * 0.4, 6.0, -24.0 + sin(a) * 0.4), 0.07, "black", 6, 4)
	# a snowcat that will not start, boardwalks, flags on the way in
	var cat := VehicleMesh.body("tracked")
	cat.transform = Transform3D(Basis(Vector3.UP, -0.5), o + Vector3(4.0, 0.5, 10.0))
	pl.add_child(cat)
	k.box(Vector3(4.0, 0.9, 10.0), Vector3(2.6, 1.8, 5.2), "black_in", Basis(Vector3.UP, -0.5))
	kd.ball(Vector3(5.5, 0.2, 11.5), Vector3(1.6, 0.6, 2.6), "snow", 9, 4)
	for seg in [[-4.0, -4.6, 13.0, -7.6], [13.0, -7.6, 25.0, -0.5], [-4.0, -4.6, -4.0, 4.0]]:
		var a := Vector3(float(seg[0]), 0.03, float(seg[1]))
		var b := Vector3(float(seg[2]), 0.03, float(seg[3]))
		kd.box((a + b) * 0.5, Vector3(1.3, 0.05, a.distance_to(b)), "planks_in", Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z)))
	for i in 6:
		var p := Vector3(34.0 - i * 5.5, 0, 6.0 - i * 0.6)
		k.cyl(p - Vector3(0, 0.3, 0), 0.025, 2.5, "steel", 4)
		kd.box(p + Vector3(0.22, 1.95, 0), Vector3(0.44, 0.3, 0.01), "orange")
	var lp := Struct.floodlight(k, Vector3(2.0, 0, -3.5), 2.4, true, 5.5)
	pl.lamp(k.xf * lp, Color(0.9, 0.95, 1.0), 2.6, 22.0, true, true)
	for i in 4:
		k.xf = Transform3D(Basis(Vector3.UP, i * 0.5), o + Vector3(-9.0 + (i % 2) * 1.0, 0, -3.6 + (i / 2) * 1.0))
		Props.crate(k, 0.7)
	pl.at(o)
	pl.spot("station", "Research Station Polaris-7", o, 50.0)
