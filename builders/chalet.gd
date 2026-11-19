class_name Chalet
extends RefCounted
## Builds alpine houses in code: stone base, plastered ground floor you can walk
## into, timber upper floors, snow-loaded gable roof, balcony, shutters, icicles,
## furniture. Front (door) faces +Z.

const FH := 2.9      # floor height
const T := 0.25      # wall thickness
const Y0 := 0.18     # floor level above ground
const SW := 1.0      # stair width
const RUN := 4.0     # stair run, first riser to last
const PT := 0.12     # inner partition thickness
const SHUTTERS: Array[String] = ["paint_green", "paint_red", "paint_blue", "wood_dark"]


static var _count := 0

# wall, roof, door for ordinary houses: the paint you see in any northern town
const PALETTES := [
	["clad_red", "roof_metal", "trim"],
	["clad_ochre", "roof_metal", "paint_green"],
	["clad_blue", "roof_metal", "trim"],
	["clad_white", "roof_red", "paint_blue"],
	["clad_green", "roof_red", "trim"],
	["clad_grey", "roof_metal", "paint_red"],
	["clad_yellow", "roof_red", "paint_green"],
	["clad_black", "roof_metal", "paint_red"],
	["clad_red", "roof_red", "trim"],
	["clad_brown", "roof_metal", "trim"],
]


static func build(kind: String, rng: RandomNumberGenerator, lit: bool) -> Node3D:
	var w := rng.randf_range(8.0, 10.0)
	var d := rng.randf_range(7.0, 8.5)
	var floors := 2
	var sign_text := ""
	var win_w := 1.1
	var wall_mat := "plaster"
	match kind:
		"toyshop":
			w = 12.0; d = 9.0; sign_text = "SPIELWAREN  WICHTEL & SOHN"; win_w = 2.2
		"restaurant":
			w = 14.0; d = 10.0; sign_text = "GASTHAUS ZUM HIRSCHEN"; win_w = 1.6
		"hotel":
			w = 20.0; d = 12.0; floors = 3; sign_text = "HOTEL POLARSTERN"; win_w = 1.5
		"station":
			w = 10.0; d = 9.0; floors = 1; sign_text = "BERGBAHN  POLARIS"
		"cabin":
			w = rng.randf_range(5.6, 6.4); d = rng.randf_range(5.0, 5.6); floors = 1; wall_mat = "wood"
		_:
			if rng.randf() < 0.25:
				floors = 1
	# summer: the outside is a model made in Blender, with its own fixed size
	var shell := HouseScan.model_for(kind, floors)
	if shell != "":
		var sz: Array = HouseScan.SIZES[shell]
		w = sz[0]
		d = sz[1]
		floors = sz[2]
	var blend := shell != ""
	var hw := w * 0.5
	var hd := d * 0.5
	var top := Y0 + floors * FH
	var st := stair_plan(kind, hw, hd) if floors > 1 else {}
	var steps := StaticBody3D.new()       # smooth ramps under the treads, so walking up never snags
	var k := MeshKit.new()
	var shutter := SHUTTERS[rng.randi() % SHUTTERS.size()]
	var root := Node3D.new()

	# look: a town house is painted boards on a concrete footing under a sheet-metal roof
	var town := kind != "cabin"
	_count += 1
	var sr := RandomNumberGenerator.new()
	sr.seed = 4177 + _count * 131
	var pal: Array = PALETTES[sr.randi() % PALETTES.size()]
	match kind:
		"hotel":
			pal = ["render_ochre", "roof_green", "paint_green"]
		"restaurant":
			pal = ["clad_red", "roof_metal", "paint_green"]
		"toyshop":
			pal = ["clad_yellow", "roof_red", "paint_red"]
		"station":
			pal = ["clad_grey", "roof_metal", "paint_red"]
	var clad: String = pal[0] if town else wall_mat
	var upper: String = clad if town else "wood"
	var roof_mat: String = pal[1] if town else "wood_dark"
	var door_mat: String = pal[2] if town else shutter
	var trim := "trim" if clad != "clad_white" else "clad_grey"
	var frame := trim if town else "paint_white"
	var liner := "wall_in" if town else ""
	if not town:
		door_mat = "paint_green" if kind != "house" else shutter
	var shut := "" if town else shutter

	# base and floor
	if not blend:
		k.box(Vector3(0, -0.68, 0), Vector3(w + (0.12 if town else 0.3), 1.64, d + (0.12 if town else 0.3)), "concrete" if town else "stone")
	k.box(Vector3(0, Y0 - 0.03, 0), Vector3(w - 0.1, 0.06, d - 0.1), "planks_in")
	if not blend:
		k.box(Vector3(0, 0.06, hd + 0.75), Vector3(1.7, 0.06, 1.75), "planks", Basis(Vector3.RIGHT, 0.118))

	# ground floor walls with real openings
	var front: Array = []
	var n_front := maxi(1, int((hw - 1.6) / (win_w + 1.3)))
	var span := (hw - 1.3) / n_front
	for i in range(n_front - 1, -1, -1):
		var c := hw - 1.1 - (i + 0.5) * span
		front.append([c - win_w * 0.5, c + win_w * 0.5, 0.95, 2.15])
	front.append([hw - 0.5, hw + 0.5, 0.0, 2.1])
	for i in n_front:
		var c := hw + 1.1 + (i + 0.5) * span
		front.append([c - win_w * 0.5, c + win_w * 0.5, 0.95, 2.15])
	var side: Array = []
	var n_side := maxi(1, int(d / 3.6))
	for i in n_side:
		var c := d * (i + 0.5) / n_side
		side.append([c - 0.55, c + 0.55, 0.95, 2.15])
	if not blend:
		_ground_walls(k, w, d, clad, front, side, liner, shut, frame, town)
	if town:
		if not blend:
			# corner boards, a water table over the plinth, vents in the foundation
			for cx2: float in [-1.0, 1.0]:
				for cz2: float in [-1.0, 1.0]:
					k.box(Vector3(cx2 * (hw + 0.015), Y0 + floors * FH * 0.5, cz2 * (hd + 0.015)), Vector3(0.15, floors * FH, 0.15), trim)
			for sz2: float in [-1.0, 1.0]:
				k.box(Vector3(0, Y0 + 0.03, sz2 * (hd + 0.05)), Vector3(w + 0.16, 0.07, 0.08), trim, Basis(Vector3.RIGHT, sz2 * 0.35))
				k.box(Vector3(sz2 * (hw + 0.05), Y0 + 0.03, 0), Vector3(0.08, 0.07, d + 0.16), trim, Basis(Vector3(0, 0, 1), -sz2 * 0.35))
				for vx: float in [-0.5, 0.5]:
					k.box(Vector3(vx * hw, -0.02, sz2 * (hd + 0.065)), Vector3(0.3, 0.14, 0.02), "black")
		# the slab stays inside the wall; outside a painted board marks the floor line
		_holed(k, Vector3(0, Y0 + FH, 0), Vector3(w - 0.04, 0.26, d - 0.04), _hole(st), "planks_in")
		if floors > 1 and not blend:
			for f in range(1, floors):
				for sz: float in [-1.0, 1.0]:
					k.box(Vector3(0, Y0 + f * FH, sz * (hd + 0.02)), Vector3(w + 0.1, 0.16, 0.05), trim)
					k.box(Vector3(sz * (hw + 0.02), Y0 + f * FH, 0), Vector3(0.05, 0.16, d + 0.1), trim)
	elif blend:
		k.box(Vector3(0, Y0 + FH, 0), Vector3(w - 2.0 * T * 0.6, 0.2, d - 2.0 * T * 0.6), "wood_dark")
	else:
		# ceiling slab doubles as the beam band outside
		k.box(Vector3(0, Y0 + FH, 0), Vector3(w + 0.16, 0.26, d + 0.16), "wood_dark")
	# stairs: a hall along the back wall behind a thin partition, a door at the foot of the flight
	if not st.is_empty():
		_skin = PT
		_wall(k, Vector3(-hw + T, Y0, st.zp), Vector3.RIGHT, w - T * 2.0, FH, "plaster_in",
			[[st.xb - (-hw + T), st.xa - (-hw + T), 0.0, 2.1]])
		_skin = T
		for e in [st.xb, st.xa]:
			k.box(Vector3(e, Y0 + 1.05, st.zp), Vector3(0.08, 2.1, PT + 0.04), "wood_dark_in")
		k.box(Vector3((st.xb + st.xa) * 0.5, Y0 + 2.14, st.zp), Vector3(1.08, 0.08, PT + 0.04), "wood_dark_in")
		_flight(k, steps, st, Y0, FH + 0.13, false)
	# upper floors: real rooms behind real windows
	if floors > 1:
		var bays := maxi(2, int(w / 3.2))
		var zc: float = st.zc
		for f in range(1, floors):
			var fy := Y0 + f * FH
			var yw := fy + 0.13
			var hgt := FH if f < floors - 1 else FH - 0.13
			var fr: Array = []
			var bk: Array = []
			for i in bays:
				var u := w * (i + 0.5) / bays
				fr.append([u - 0.5, u + 0.5, 0.745, 1.995])
				if u - hw < st.xt - 0.7 or u - hw > st.xa + 0.7:
					bk.append([u - 0.5, u + 0.5, 0.745, 1.995])
			var sd: Array = []
			for i in n_side:
				var u := d * (i + 0.5) / n_side
				if absf(u - hd - zc) > 0.7:
					sd.append([u - 0.5, u + 0.5, 0.745, 1.995])
			if not blend:
				_upper_walls(k, w, d, yw, hgt, fy, upper, fr, bk, sd, liner, shut, frame)
			if f >= 2:
				_holed(k, Vector3(0, fy, 0), Vector3(w - 0.04, 0.26, d - 0.04), _hole(st), "planks_in")
				_flight(k, steps, st, fy - FH + 0.13, FH, true)
			# a rail round the stairwell; the flight above closes the far end where there is one
			_rail(k, Vector3(st.xt, yw, st.z1 + 0.03), Vector3(st.hx1 + 0.03, yw, st.z1 + 0.03))
			if f == floors - 1:
				_rail(k, Vector3(st.hx1 + 0.03, yw, st.z0), Vector3(st.hx1 + 0.03, yw, st.z1 + 0.03))
			var edges: Array = []
			for i in bays + 1:
				edges.append(-hw + w * i / bays)
			Interior.upper(k, rng, kind, f, floors, hw, hd, st, edges, lit, root)
			if lit:
				var ul := OmniLight3D.new()
				ul.position = Vector3(0, fy + 2.1, (zc + hd) * 0.5)
				ul.light_color = Color(1.0, 0.72, 0.45)
				ul.light_energy = 1.5
				ul.omni_range = maxf(w, d) * 0.8
				ul.distance_fade_enabled = true
				ul.distance_fade_begin = 50.0
				ul.distance_fade_length = 15.0
				root.add_child(ul)
				# a lamp over the stairwell, so the flight is not a black hole
				var sl := OmniLight3D.new()
				sl.position = Vector3((st.xt + st.xb) * 0.5, fy + 2.0, (st.z0 + st.z1) * 0.5)
				sl.light_color = Color(1.0, 0.78, 0.55)
				sl.light_energy = 0.9
				sl.omni_range = 5.5
				sl.distance_fade_enabled = true
				sl.distance_fade_begin = 30.0
				sl.distance_fade_length = 10.0
				root.add_child(sl)
			if blend or (town and kind != "hotel" and kind != "restaurant"):
				continue
			# balcony across the front
			var rail := "trim" if town else "wood_dark"
			var by := Y0 + f * FH
			var bw := w * 0.86
			k.box(Vector3(0, by, hd + 0.6), Vector3(bw, 0.12, 1.2), "planks")
			k.box(Vector3(0, by + 1.0, hd + 1.15), Vector3(bw, 0.09, 0.1), rail)
			k.box(Vector3(0, by + 0.25, hd + 1.15), Vector3(bw, 0.07, 0.06), rail)
			for s in [-1.0, 1.0]:
				k.box(Vector3(s * bw * 0.5, by + 1.0, hd + 0.6), Vector3(0.1, 0.09, 1.2), rail)
				k.box(Vector3(s * bw * 0.5, by + 0.5, hd + 1.15), Vector3(0.12, 1.0, 0.12), rail)
			if town:
				var nb := int(bw / 0.14)
				for i in nb:
					k.box(Vector3(-bw * 0.5 + bw * (i + 0.5) / nb, by + 0.62, hd + 1.15), Vector3(0.03, 0.7, 0.03), "trim_dark")
			else:
				var nb := int(bw / 0.28)
				for i in nb:
					k.box(Vector3(-bw * 0.5 + bw * (i + 0.5) / nb, by + 0.62, hd + 1.15), Vector3(0.14, 0.7, 0.03), "wood")
			for i in 4:
				var bx := -bw * 0.45 + bw * 0.9 * i / 3.0
				k.box(Vector3(bx, by - 0.3, hd + 0.5), Vector3(0.14, 0.14, 1.1), "wood_dark", Basis(Vector3.RIGHT, -0.5))
	if not blend:
		# corner posts / corner boards
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				if town:
					k.box(Vector3(sx * (hw + 0.005), (Y0 + top) * 0.5, sz * (hd + 0.005)), Vector3(0.2, top - Y0, 0.2), trim)
				else:
					k.box(Vector3(sx * (hw - 0.08), (Y0 + top) * 0.5, sz * (hd - 0.08)), Vector3(0.34, top - Y0, 0.34), "wood_dark")

		# gables and roof
		var pitch := 0.5
		var ridge := top + tan(pitch) * hw
		for sz in [-1.0, 1.0]:
			var gz: float = sz * (hd - 0.06)
			var a := Vector3(-hw, top, gz)
			var b := Vector3(hw, top, gz)
			var c := Vector3(0, ridge, gz)
			k.tri(a, b, c, upper if town else "planks")
			k.tri(b, a, c, upper if town else "planks")
		_window(k, Vector3(0, top + (ridge - top) * 0.38, hd - 0.06), Vector3.BACK, 0.8, 0.9, _glass(rng, lit), shut, false, frame)
		var over := 0.6 if town else 1.0
		var over_z := 0.55 if town else 1.5
		var slab := (hw + over) / cos(pitch)
		var snow_t := sr.randf_range(0.2, 0.36)
		for s in [-1.0, 1.0]:
			var sgn: float = s
			var basis := Basis(Vector3(0, 0, 1), -pitch * sgn)
			var nrm := Vector3(sin(pitch) * sgn, cos(pitch), 0)
			var mid := Vector3(sgn * (hw + over) * 0.5, ridge - tan(pitch) * (hw + over) * 0.5, 0)
			var ex := sgn * (hw + over)
			var ey := ridge - tan(pitch) * (hw + over) - 0.02
			if town:
				k.box(mid + nrm * 0.05, Vector3(slab, 0.1, d + over_z * 2.0), roof_mat, basis)
				# the snow has slid back from the eaves in places and hangs over in others
				var cover := sr.randf_range(0.78, 0.97)
				var smid := mid - basis.x * sgn * slab * (1.0 - cover) * 0.5
				k.box(smid + nrm * (0.1 + snow_t * 0.5), Vector3(slab * cover, snow_t, d + over_z * 2.0 - 0.1), "snow", basis)
				if cover > 0.9:
					k.ball(Vector3(ex, ey + 0.2, sr.randf_range(-hd, hd) * 0.5), Vector3(0.24, 0.17, d * sr.randf_range(0.25, 0.5)), "snow", 8, 5)
				# barge boards, fascia, gutter and a downpipe
				for sz in [-1.0, 1.0]:
					k.box(mid + nrm * 0.02 + Vector3(0, 0, sz * (hd + over_z)), Vector3(slab, 0.2, 0.05), trim, basis)
				k.box(Vector3(ex - sgn * 0.02, ey - 0.02, 0), Vector3(0.04, 0.16, d + over_z * 2.0), trim)
				k.tube(Vector3(ex + sgn * 0.05, ey - 0.06, -hd - over_z), Vector3(ex + sgn * 0.05, ey - 0.06, hd + over_z), 0.055, "steel", 6)
				var pz := (hd - 0.25) * (1.0 if sgn > 0.0 else -1.0)
				k.tube(Vector3(ex + sgn * 0.05, ey - 0.08, pz), Vector3(sgn * (hw + 0.09), ey - 0.5, pz), 0.04, "steel", 5)
				k.tube(Vector3(sgn * (hw + 0.09), ey - 0.5, pz), Vector3(sgn * (hw + 0.09), 0.25, pz), 0.04, "steel", 5)
			else:
				k.box(mid + nrm * 0.09, Vector3(slab, 0.18, d + over_z * 2.0), "wood_dark", basis)
				k.box(mid + nrm * 0.33, Vector3(slab - 0.1, 0.32, d + over_z * 2.0 - 0.16), "snow", basis)
				# rafters showing under the overhang
				var nr := int(d / 1.2)
				for i in nr + 1:
					var rz := -hd - over_z + 0.2 + (d + over_z * 2.0 - 0.4) * i / nr
					k.box(mid - nrm * 0.07 + Vector3(0, 0, rz), Vector3(slab - 0.2, 0.14, 0.12), "wood", basis)
			# icicles along the eaves
			var z := -hd - over_z + 0.1
			while z < hd + over_z - 0.1:
				if rng.randf() < 0.75:
					var len := rng.randf_range(0.12, 0.5) * (2.2 if rng.randf() < 0.12 else 1.0)
					if not town or len > 0.3:
						k.cyl(Vector3(ex - sgn * 0.05 + (sgn * 0.1 if town else 0.0), ey - len - (0.1 if town else 0.0), z), 0.0, len, "ice", 4, rng.randf_range(0.02, 0.045), false)
				z += rng.randf_range(0.18, 0.45)
		# snow ridge cap and chimney
		var cx := hw * 0.45
		if town:
			k.ball(Vector3(0, ridge + 0.12 + snow_t, 0), Vector3(0.7, 0.22, hd + over_z - 0.1), "snow", 8, 5)
			if sr.randf() < 0.3:
				k.cyl(Vector3(cx, ridge - tan(pitch) * cx - 0.2, -hd * 0.3), 0.14, 1.9, "steel", 8)
				k.cyl(Vector3(cx, ridge - tan(pitch) * cx + 1.7, -hd * 0.3), 0.24, 0.1, "metal", 8, 0.08)
			else:
				k.box(Vector3(cx, ridge - tan(pitch) * cx + 0.6, -hd * 0.3), Vector3(0.7, 1.9, 0.7), "brick")
				k.box(Vector3(cx, ridge - tan(pitch) * cx + 1.6, -hd * 0.3), Vector3(0.86, 0.1, 0.86), "trim_dark")
				k.box(Vector3(cx, ridge - tan(pitch) * cx + 1.72, -hd * 0.3), Vector3(0.6, 0.12, 0.6), "snow")
			# an aerial clamped to the ridge
			if sr.randf() < 0.7:
				var az := sr.randf_range(-hd * 0.6, hd * 0.6)
				k.tube(Vector3(-0.3, ridge - 0.1, az), Vector3(-0.3, ridge + 2.3, az), 0.018, "steel", 5)
				for i in 5:
					k.tube(Vector3(-0.65 + i * 0.03, ridge + 2.2 - i * 0.14, az), Vector3(0.05 - i * 0.03, ridge + 2.2 - i * 0.14, az), 0.008, "steel", 4)
			_town_extras(k, sr, kind, hw, hd, lit, trim)
		else:
			k.box(Vector3(0, ridge + 0.36, 0), Vector3(0.9, 0.3, d + over_z * 2.0 - 0.3), "snow")
			k.box(Vector3(cx, ridge - tan(pitch) * cx + 0.7, -hd * 0.3), Vector3(0.75, 2.0, 0.75), "stone")
			k.box(Vector3(cx, ridge - tan(pitch) * cx + 1.75, -hd * 0.3), Vector3(0.95, 0.12, 0.95), "stone")

	elif town:
		_town_extras(k, sr, kind, hw, hd, lit, trim)

	Interior.furnish(k, rng, kind, hw, hd, lit, root, st)
	root.add_child(k.node(true))
	if blend:
		HouseScan.attach(root, shell, clad, roof_mat, door_mat, trim)
	if steps.get_child_count() > 0:
		root.add_child(steps)
	else:
		steps.free()

	var door := Door.new()
	door.setup(1.0, 2.1, door_mat, "plank" if kind == "cabin" else "house")
	door.position = Vector3(-0.5, Y0, hd - T * 0.5)
	root.add_child(door)

	if lit:
		var light := OmniLight3D.new()
		light.position = Vector3(0, Y0 + 2.2, 0)
		light.light_color = Color(1.0, 0.70, 0.40)
		light.light_energy = 2.4
		light.omni_range = maxf(w, d) * 0.95
		light.shadow_enabled = true
		light.distance_fade_enabled = true
		light.distance_fade_begin = 90.0
		light.distance_fade_length = 20.0
		light.distance_fade_shadow = 45.0
		root.add_child(light)

	if sign_text != "":
		var lab := Label3D.new()
		lab.text = sign_text
		lab.font_size = 96
		lab.pixel_size = 0.0042
		lab.modulate = Color(0.93, 0.90, 0.80) if town else Color(0.85, 0.68, 0.32)
		lab.outline_modulate = Color(0.05, 0.03, 0.02)
		lab.outline_size = 16
		# in town the porch roof sits over the door, so the sign goes above it
		var sy := Y0 + (3.08 if town else 2.62)
		lab.position = Vector3(0, sy, hd + 0.2)
		root.add_child(lab)
		var board := MeshKit.new()
		var bl := sign_text.length() * 0.21 + 0.6
		board.box(Vector3(0, sy, hd + 0.13), Vector3(bl, 0.62, 0.08), "trim_dark" if town else "wood_dark")
		root.add_child(board.node(false))
	root.set_meta("size", Vector2(w, d))
	root.set_meta("floors", floors)
	root.set_meta("kind", kind)
	if not st.is_empty():
		root.set_meta("stair", st)
	return root


## Where the stairs go. They climb along the back wall towards -X: landing at the foot (xb..xa),
## treads from xb to xt, a landing at the top. hx1 is where the stairwell's hole ends (head room).
static func stair_plan(kind: String, hw: float, hd: float) -> Dictionary:
	var xt := -hw + T + 0.9
	if kind == "hotel":
		xt = -7.5
	var xb := xt + RUN
	var z0 := -hd + T
	var z1 := z0 + SW
	return {"xt": xt, "xb": xb, "xa": xb + 1.0, "hx1": xb - 0.3, "z0": z0, "z1": z1,
		"zp": z1 + PT * 0.5, "hall": SW + PT, "zc": z1 + 1.2}


## A ground-floor spot given in the room plan of an old one-storey layout: with a stair hall at
## the back the rooms sit `hall / 2` further forward.
static func room(h: Node3D, local: Vector3) -> Vector3:
	if h.has_meta("stair"):
		return local + Vector3(0, 0, float((h.get_meta("stair") as Dictionary)["hall"]) * 0.5)
	return local


## The stairwell in a slab, [x0, x1, z0, z1]; none without stairs.
static func _hole(st: Dictionary) -> Array:
	if st.is_empty():
		return []
	return [st.xt, st.hx1, st.z0 - 0.3, st.z1]


## A flat box with a rectangular hole [x0, x1, z0, z1] (centre `c`, size `size`).
static func _holed(k: MeshKit, c: Vector3, size: Vector3, hole: Array, mat: String) -> void:
	var lo := c - size * 0.5
	var hi := c + size * 0.5
	if hole.is_empty():
		k.box(c, size, mat)
		return
	var hx0 := clampf(hole[0], lo.x, hi.x)
	var hx1 := clampf(hole[1], lo.x, hi.x)
	var hz0 := clampf(hole[2], lo.z, hi.z)
	var hz1 := clampf(hole[3], lo.z, hi.z)
	var part := func(x0: float, x1: float, z0: float, z1: float) -> void:
		if x1 - x0 > 0.005 and z1 - z0 > 0.005:
			k.box(Vector3((x0 + x1) * 0.5, c.y, (z0 + z1) * 0.5), Vector3(x1 - x0, size.y, z1 - z0), mat)
	part.call(lo.x, hx0, lo.z, hi.z)
	part.call(hx1, hi.x, lo.z, hi.z)
	part.call(hx0, hx1, lo.z, hz0)
	part.call(hx0, hx1, hz1, hi.z)


## One flight from `yb` up `rise` metres. Treads, risers and stringers you see; a smooth ramp
## through the nosings you walk on. `open` adds a soffit and a hand rail on the open side.
static func _flight(k: MeshKit, body: StaticBody3D, st: Dictionary, yb: float, rise: float, open: bool) -> void:
	var n := roundi(rise / 0.18)
	var riser := rise / n
	var tread := RUN / (n - 1)
	var xb: float = st.xb
	var xt: float = st.xt
	var zm: float = (st.z0 + st.z1) * 0.5
	for i in range(1, n):
		var x0 := xb - (i - 1) * tread
		var ty := yb + i * riser
		k.box(Vector3(x0 - tread * 0.5 + 0.015, ty - 0.025, zm), Vector3(tread + 0.03, 0.05, SW), "planks_in")
		k.box(Vector3(x0, ty - riser * 0.5 - 0.025, zm), Vector3(0.025, riser - 0.05, SW - 0.04), "wood_dark_in")
	k.box(Vector3(xt, yb + rise - riser * 0.5, zm), Vector3(0.025, riser, SW - 0.04), "wood_dark_in")
	# the line through the nosings
	var p0 := Vector3(xb + tread, yb, zm)
	var p1 := Vector3(xt, yb + rise, zm)
	var len := p0.distance_to(p1)
	var ang := atan2(-(p1.y - p0.y), p0.x - p1.x)
	var bas := Basis(Vector3(0, 0, 1), ang)
	var up := bas.y
	var mid := (p0 + p1) * 0.5
	for z: float in [st.z0 + 0.03, st.z1 - 0.03]:
		k.box(Vector3(mid.x, mid.y, z) - up * 0.1, Vector3(len, 0.28, 0.05), "wood_dark_in", bas)
	if open:
		k.box(mid - up * 0.25, Vector3(len, 0.03, SW), "planks_in", bas)
		var rz: float = st.z1 + 0.02
		k.box(Vector3(mid.x, mid.y + 0.92, rz), Vector3(len, 0.06, 0.06), "wood_dark_in", bas)
		for t in 5:
			var q := p0.lerp(p1, t / 4.0)
			k.box(Vector3(q.x, q.y + 0.46, rz), Vector3(0.045, 0.92, 0.045), "wood_dark_in")
	# the ramp rides 3 cm over the nosings, so no tread edge can catch a foot
	var r0 := p0 + Vector3(0.04, 0, 0)
	var r1 := p1 + Vector3(0, 0.03, 0)
	var rlen := r0.distance_to(r1)
	var rb := Basis(Vector3(0, 0, 1), atan2(-(r1.y - r0.y), r0.x - r1.x))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rlen, 0.1, SW - 0.04)
	cs.shape = box
	cs.transform = Transform3D(rb, (r0 + r1) * 0.5 - rb.y * 0.05)
	body.add_child(cs)


## A banister on a floor from `a` to `b` (both at floor height).
static func _rail(k: MeshKit, a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var dir := (b - a) / len
	var bas := Basis(Vector3.UP, atan2(-dir.z, dir.x))
	var m := (a + b) * 0.5
	k.box(m + Vector3(0, 0.95, 0), Vector3(len + 0.06, 0.06, 0.07), "wood_dark_in", bas)
	k.box(m + Vector3(0, 0.12, 0), Vector3(len, 0.05, 0.04), "wood_dark_in", bas)
	var n := maxi(1, int(len / 0.12))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		var thick := 0.07 if i == 0 or i == n else 0.025
		k.box(q + Vector3(0, 0.5, 0), Vector3(thick, 0.9, thick), "wood_dark_in")


## What stands and hangs around a lived-in house: porch, lamp, bins, firewood, heat pump, dish.
static func _town_extras(k: MeshKit, sr: RandomNumberGenerator, kind: String, hw: float, hd: float, lit: bool, trim: String) -> void:
	# porch roof over the door on two posts
	var pw := 2.6 if kind == "house" else 4.2
	var py := Y0 + 2.42
	k.box(Vector3(0, py, hd + 0.85), Vector3(pw, 0.1, 1.7), "roof_metal", Basis(Vector3.RIGHT, 0.14))
	if not GameMode.summer():
		k.box(Vector3(0, py + 0.16, hd + 0.8), Vector3(pw - 0.15, 0.2, 1.5), "snow", Basis(Vector3.RIGHT, 0.14))
	k.box(Vector3(0, py - 0.16, hd + 1.66), Vector3(pw, 0.14, 0.05), trim)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * (pw * 0.5 - 0.08), py * 0.5 - 0.12, hd + 1.6), Vector3(0.1, py - 0.1, 0.1), trim)
		k.box(Vector3(sx * (pw * 0.5 - 0.08), 0.02, hd + 1.6), Vector3(0.22, 0.2, 0.22), "concrete")
	# house number, bell push, a mat on the step and a hand rail down the steps
	k.box(Vector3(0.82, Y0 + 1.62, hd + 0.03), Vector3(0.16, 0.12, 0.02), "sign_blue")
	k.box(Vector3(0.82, Y0 + 1.62, hd + 0.042), Vector3(0.09, 0.06, 0.006), "white")
	k.box(Vector3(0.7, Y0 + 1.2, hd + 0.03), Vector3(0.05, 0.09, 0.025), "trim_dark")
	k.cyl(Vector3(0.7, Y0 + 1.2, hd + 0.04), 0.012, 0.012, "brass", 8)
	k.box(Vector3(0, Y0 + 0.012, hd + 0.42), Vector3(0.8, 0.02, 0.5), "rug")
	for rz: float in [hd + 0.1, hd + 1.55]:
		k.tube(Vector3(-0.82, 0.12 if rz > hd + 1.0 else Y0, rz), Vector3(-0.82, (0.12 if rz > hd + 1.0 else Y0) + 0.9, rz), 0.02, "trim_dark", 6)
	k.tube(Vector3(-0.82, Y0 + 0.9, hd + 0.1), Vector3(-0.82, 1.02, hd + 1.55), 0.022, "trim_dark", 6)
	# lamp beside the door
	k.box(Vector3(0.82, Y0 + 2.0, hd + 0.05), Vector3(0.06, 0.1, 0.1), "trim_dark")
	k.box(Vector3(0.82, Y0 + 1.94, hd + 0.13), Vector3(0.13, 0.2, 0.13), "lamp_glow" if lit else "glass_dark")
	# letter box by the door
	k.box(Vector3(-0.85, Y0 + 1.25, hd + 0.08), Vector3(0.3, 0.38, 0.12), "trim_dark" if sr.randf() < 0.5 else "paint_green")
	if kind != "house":
		return
	# wheelie bins at the front corner
	if sr.randf() < 0.8:
		var bx := (hw - 0.55) * (1.0 if sr.randf() < 0.5 else -1.0)
		for i in 2:
			var c := Vector3(bx - i * 0.68 * signf(bx), 0.55, hd + 0.5)
			var col := "plastic_green" if i == 0 else "plastic_grey"
			k.bbox(c, Vector3(0.56, 0.96, 0.66), 0.05, col)
			k.box(c + Vector3(0, 0.51, 0.02), Vector3(0.6, 0.06, 0.72), col)
			if not GameMode.summer():
				k.box(c + Vector3(0, 0.58, 0.0), Vector3(0.5, 0.1, 0.6), "snow")
	# firewood stacked along the side under the eaves
	if sr.randf() < 0.65:
		var sx := 1.0 if sr.randf() < 0.5 else -1.0
		var len := sr.randf_range(2.0, 3.4)
		var zc := sr.randf_range(-hd + 2.0, hd - 2.2)
		k.box(Vector3(sx * (hw + 0.34), 0.55, zc), Vector3(0.42, 1.1, len), "wood")
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * (hw + 0.34), 0.65, zc + sz * (len * 0.5 + 0.04)), Vector3(0.08, 1.3, 0.08), "wood_dark")
		k.box(Vector3(sx * (hw + 0.36), 1.14, zc), Vector3(0.6, 0.04, len + 0.3), "corrugated", Basis(Vector3(0, 0, 1), -0.12 * sx))
		if not GameMode.summer():
			k.box(Vector3(sx * (hw + 0.36), 1.22, zc), Vector3(0.55, 0.12, len + 0.2), "snow")
	# heat pump on the back wall
	if sr.randf() < 0.6:
		var x := sr.randf_range(-hw + 1.2, hw - 1.2)
		k.bbox(Vector3(x, 0.75, -hd - 0.24), Vector3(0.9, 0.62, 0.34), 0.04, "white")
		k.cyl(Vector3(x - 0.14, 0.75, -hd - 0.42), 0.2, 0.02, "plastic_grey", 12)
		k.box(Vector3(x, 0.38, -hd - 0.24), Vector3(0.8, 0.12, 0.3), "steel")
		k.tube(Vector3(x + 0.4, 0.9, -hd - 0.1), Vector3(x + 0.4, 2.2, -hd - 0.04), 0.03, "white", 5)
	# satellite dish under the gable
	if sr.randf() < 0.45:
		var dx := (hw - 0.9) * (1.0 if sr.randf() < 0.5 else -1.0)
		var dy := Y0 + FH * 0.82
		k.tube(Vector3(dx, dy, hd + 0.02), Vector3(dx, dy + 0.1, hd + 0.3), 0.02, "steel", 5)
		k.ball(Vector3(dx, dy + 0.18, hd + 0.34), Vector3(0.3, 0.3, 0.05), "grey", 10, 4, Basis(Vector3.RIGHT, -0.35))
	# aluminium ladder left leaning against the back
	if sr.randf() < 0.25:
		var lx := sr.randf_range(-hw + 0.8, hw - 0.8)
		for sx2: float in [-0.2, 0.2]:
			k.tube(Vector3(lx + sx2, 0.0, -hd - 1.0), Vector3(lx + sx2, 3.3, -hd - 0.06), 0.022, "steel", 4)
		for i in 10:
			var f := (i + 0.5) / 10.0
			k.tube(Vector3(lx - 0.2, 3.3 * f, -hd - 1.0 + 0.94 * f), Vector3(lx + 0.2, 3.3 * f, -hd - 1.0 + 0.94 * f), 0.015, "steel", 4)


static func _glass(rng: RandomNumberGenerator, lit: bool) -> String:
	if lit and rng.randf() < 0.45:
		_lit_n += 1
		return ["glass_lit", "glass_lit2", "glass_lit", "glass_tv", "glass_lit2"][_lit_n % 5]
	return "glass_dark"


static var _lit_n := 0


## Wall of boxes from `origin` along `along` (X or Z axis), leaving holes [u0, u1, v0, v1].
## With `liner` the wall is two skins: `mat` outside (towards `out`), `liner` inside.
static func _wall(k: MeshKit, origin: Vector3, along: Vector3, length: float, height: float, mat: String, holes: Array, out := Vector3.ZERO, liner := "") -> void:
	if liner != "":
		_wall(k, origin + out * T * 0.25, along, length, height, mat, holes, Vector3.ZERO, "")
		_skin = T * 0.5
		_wall(k, origin - out * T * 0.25, along, length, height, liner, holes, Vector3.ZERO, "")
		_skin = T
		return
	if out != Vector3.ZERO:
		pass
	var u := 0.0
	for h in holes:
		var hole: Array = h
		_piece(k, origin, along, u, hole[0], 0.0, height, mat)
		_piece(k, origin, along, hole[0], hole[1], 0.0, hole[2], mat)
		_piece(k, origin, along, hole[0], hole[1], hole[3], height, mat)
		u = hole[1]
	_piece(k, origin, along, u, length, 0.0, height, mat)


static var _skin := T


static func _piece(k: MeshKit, origin: Vector3, along: Vector3, u0: float, u1: float, v0: float, v1: float, mat: String) -> void:
	if u1 - u0 < 0.01 or v1 - v0 < 0.01:
		return
	var size := Vector3(absf(along.x) * (u1 - u0) + absf(along.z) * _skin, v1 - v0, absf(along.z) * (u1 - u0) + absf(along.x) * _skin)
	k.box(origin + along * (u0 + u1) * 0.5 + Vector3(0, (v0 + v1) * 0.5, 0), size, mat)


## Window on a wall. `c` lies on the outer wall face, `out` points away from the house.
static func _window(k: MeshKit, c: Vector3, out: Vector3, w: float, h: float, glass: String, shutter: String, opening: bool, frame := "paint_white") -> void:
	var al := Vector3(out.z, 0, -out.x)
	var gpos := c - out * (T * 0.5 if opening else -0.02)
	var town := shutter == ""
	var fw := 0.11 if town else 0.08
	k.box(gpos, _sz(al, out, w, h, 0.03), glass)
	for s in [-1.0, 1.0]:
		var sg: float = s
		k.box(c + al * sg * (w * 0.5 + fw * 0.5 - 0.01) + out * 0.03, _sz(al, out, fw, h + fw * 2.0 - 0.02, 0.12), frame)
		k.box(c + Vector3(0, sg * (h * 0.5 + fw * 0.5 - 0.01), 0) + out * 0.03, _sz(al, out, w + fw * 2.0 - 0.02, fw, 0.12), frame)
		if w < 1.4 and not town:
			k.box(c + al * sg * (w * 0.5 + 0.1 + w * 0.26) + out * 0.05, _sz(al, out, w * 0.5, h + 0.1, 0.05), shutter)
	if opening and w < 1.4:
		var inside := c - out * (T + 0.05)
		k.box(inside + Vector3(0, h * 0.5 + 0.16, 0), _sz(al, out, w + 0.5, 0.03, 0.03), "wood_dark_in")
		for s2 in [-1.0, 1.0]:
			var sg2: float = s2
			k.box(inside + al * sg2 * (w * 0.5 + 0.02) + Vector3(0, -0.02, 0), _sz(al, out, 0.3, h + 0.34, 0.035), "check_in")
			k.box(inside + al * sg2 * (w * 0.5 + 0.02) + Vector3(0, -0.1, 0), _sz(al, out, 0.34, 0.05, 0.045), "cream_in")
	if town:
		# one upright bar, one cross bar high up, a drip board over the head and a sloping sill
		k.box(gpos + out * 0.03, _sz(al, out, 0.05, h, 0.04), frame)
		k.box(gpos + out * 0.03 + Vector3(0, h * 0.22, 0), _sz(al, out, w, 0.045, 0.04), frame)
		if w > 1.4:
			for s3 in [-1.0, 1.0]:
				var sg3: float = s3
				k.box(gpos + out * 0.03 + al * sg3 * w * 0.25, _sz(al, out, 0.045, h, 0.04), frame)
		k.box(c + Vector3(0, h * 0.5 + fw + 0.02, 0) + out * 0.07, _sz(al, out, w + fw * 2.0 + 0.1, 0.04, 0.2), frame)
		k.box(c - Vector3(0, h * 0.5 + fw + 0.01, 0) + out * 0.09, _sz(al, out, w + fw * 2.0 + 0.06, 0.05, 0.24), frame)
		k.ball(c - Vector3(0, h * 0.5 + fw - 0.035, 0) + out * 0.13, _sz(al, out, w * 0.5 + fw, 0.045, 0.07), "snow", 8, 4)
	else:
		k.box(gpos + out * 0.03, _sz(al, out, 0.045, h, 0.04), "paint_white")
		k.box(gpos + out * 0.03, _sz(al, out, w, 0.045, 0.04), "paint_white")
		k.box(c - Vector3(0, h * 0.5 + 0.1, 0) + out * 0.12, _sz(al, out, w + 0.3, 0.07, 0.3), "wood_dark")


static func _sz(al: Vector3, out: Vector3, a: float, b: float, c: float) -> Vector3:
	return Vector3(absf(al.x) * a + absf(out.x) * c, b, absf(al.z) * a + absf(out.z) * c)


# ------------------------------------------------------------------ furniture

static func _furnish(k: MeshKit, rng: RandomNumberGenerator, kind: String, hw: float, hd: float, lit: bool) -> void:
	var ix := hw - T - 0.1
	var iz := hd - T - 0.1
	# ceiling lamp
	k.box(Vector3(0, Y0 + 2.5, 0), Vector3(0.02, 0.5, 0.02), "black_in")
	k.sphere(Vector3(0, Y0 + 2.2, 0), 0.13, "lamp_glow" if lit else "glass_dark", 8, 5)
	_stove(k, Vector3(ix - 0.6, Y0, -iz + 0.5), lit)
	match kind:
		"toyshop":
			_counter(k, Vector3(0, Y0, -iz + 1.6), 4.0)
			for s in [-1.0, 1.0]:
				var sg: float = s
				_shelf(k, rng, Vector3(sg * ix, Y0, -1.0), Vector3(0, 0, 1), 4.5, -sg, true)
			_shelf(k, rng, Vector3(-2.5, Y0, -iz), Vector3(1, 0, 0), 3.0, 1.0, true)
			_table(k, Vector3(-2.6, Y0, 1.4), 1.6, 1.0)
			_toys(k, rng, Vector3(-2.6, Y0 + 0.78, 1.4), 1.4, 0.8, 9)
			_table(k, Vector3(2.8, Y0, 1.2), 1.6, 1.0)
			_toys(k, rng, Vector3(2.8, Y0 + 0.78, 1.2), 1.4, 0.8, 9)
			# rocking horse
			k.box(Vector3(0.5, Y0 + 0.6, 2.0), Vector3(0.3, 0.35, 0.9), "white_in")
			k.box(Vector3(0.5, Y0 + 0.95, 2.45), Vector3(0.2, 0.5, 0.25), "white_in", Basis(Vector3.RIGHT, 0.5))
			k.box(Vector3(0.5, Y0 + 0.82, 1.95), Vector3(0.32, 0.06, 0.4), "red_in")
			for s in [-1.0, 1.0]:
				var sg: float = s
				k.box(Vector3(0.5 + sg * 0.2, Y0 + 0.08, 2.0), Vector3(0.05, 0.1, 1.5), "red_in")
				k.box(Vector3(0.5 + sg * 0.12, Y0 + 0.28, 1.7), Vector3(0.07, 0.5, 0.07), "white_in")
				k.box(Vector3(0.5 + sg * 0.12, Y0 + 0.28, 2.3), Vector3(0.07, 0.5, 0.07), "white_in")
		"restaurant":
			_counter(k, Vector3(-ix + 2.2, Y0, -iz + 1.2), 3.6)
			_shelf(k, rng, Vector3(-ix + 2.2, Y0, -iz), Vector3(1, 0, 0), 3.4, 1.0, false)
			for tx in [-3.6, 0.6, 4.4]:
				for tz in [0.2, 2.9]:
					var tp := Vector3(tx, Y0, tz)
					_table(k, tp, 1.5, 0.85)
					_bench(k, tp + Vector3(0, 0, -0.75), 1.5)
					_bench(k, tp + Vector3(0, 0, 0.75), 1.5)
					if rng.randf() < 0.7:
						k.cyl(tp + Vector3(rng.randf_range(-0.4, 0.4), 0.78, 0), 0.04, 0.22, "green_in", 6)
						k.cyl(tp + Vector3(rng.randf_range(-0.5, 0.5), 0.78, 0.2), 0.11, 0.02, "white_in", 8)
					k.cyl(tp + Vector3(0.1, 0.78, -0.1), 0.025, 0.14, "white_in", 6)
					if lit:
						k.sphere(tp + Vector3(0.1, 0.95, -0.1), 0.025, "candle", 6, 4)
		"hotel":
			_counter(k, Vector3(-4.5, Y0, -iz + 1.6), 4.5)
			# key board behind the reception
			k.box(Vector3(-4.5, Y0 + 1.6, -iz + 0.05), Vector3(2.2, 1.1, 0.06), "wood_dark_in")
			for i in 18:
				k.box(Vector3(-5.4 + (i % 6) * 0.36, Y0 + 1.95 - (i / 6) * 0.32, -iz + 0.1), Vector3(0.04, 0.12, 0.02), "gold")
			_sofa(k, Vector3(4.5, Y0, -iz + 0.6), 0.0)
			_sofa(k, Vector3(ix - 0.6, Y0, 1.0), -PI * 0.5)
			_table(k, Vector3(4.5, Y0 - 0.3, 0.9), 1.2, 0.7)
			k.box(Vector3(0, Y0 + 0.012, 0.5), Vector3(5.0, 0.02, 3.4), "cloth_in")
			_shelf(k, rng, Vector3(-ix, Y0, 1.5), Vector3(0, 0, 1), 3.0, 1.0, false)
			# abandoned luggage
			for i in 4:
				var p := Vector3(rng.randf_range(-2.0, 2.0), Y0, rng.randf_range(1.5, 3.5))
				k.box(p + Vector3(0, 0.22, 0), Vector3(0.7, 0.44, 0.28), ["cloth_in", "blue_in", "wood_dark_in"][i % 3], Basis(Vector3.UP, rng.randf() * TAU))
		_:
			_table(k, Vector3(-1.2, Y0, 0.6), 1.5, 0.85)
			_bench(k, Vector3(-1.2, Y0, -0.15), 1.5)
			_bench(k, Vector3(-1.2, Y0, 1.35), 1.5)
			_shelf(k, rng, Vector3(-ix, Y0, -0.5), Vector3(0, 0, 1), 2.2, 1.0, false)
			# bed
			var bp := Vector3(ix - 0.6, Y0, iz - 1.2)
			k.box(bp + Vector3(0, 0.2, 0), Vector3(1.0, 0.4, 2.0), "wood_in")
			k.box(bp + Vector3(0, 0.47, 0), Vector3(0.92, 0.14, 1.92), "white_in")
			k.box(bp + Vector3(0, 0.56, 0.3), Vector3(0.96, 0.08, 1.3), "cloth_in")
			k.box(bp + Vector3(0, 0.6, -0.72), Vector3(0.6, 0.12, 0.35), "white_in")
			k.box(bp + Vector3(0, 0.6, -1.0), Vector3(1.0, 1.2, 0.06), "wood_dark_in")
			k.box(Vector3(-1.0, Y0 + 0.012, 0.6), Vector3(3.0, 0.02, 2.2), "cloth_in")


static func _table(k: MeshKit, p: Vector3, w: float, d: float) -> void:
	k.box(p + Vector3(0, 0.75, 0), Vector3(w, 0.06, d), "planks_in")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(p + Vector3(sx * (w * 0.5 - 0.08), 0.36, sz * (d * 0.5 - 0.08)), Vector3(0.07, 0.72, 0.07), "wood_dark_in")


static func _bench(k: MeshKit, p: Vector3, w: float) -> void:
	k.box(p + Vector3(0, 0.45, 0), Vector3(w, 0.05, 0.34), "planks_in")
	for sx in [-1.0, 1.0]:
		k.box(p + Vector3(sx * (w * 0.5 - 0.1), 0.22, 0), Vector3(0.06, 0.44, 0.3), "wood_dark_in")


static func _counter(k: MeshKit, p: Vector3, w: float) -> void:
	k.box(p + Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.6), "wood_in")
	k.box(p + Vector3(0, 1.03, 0), Vector3(w + 0.1, 0.06, 0.72), "planks_in")
	# cash register
	k.box(p + Vector3(w * 0.3, 1.2, 0), Vector3(0.4, 0.3, 0.4), "metal_in")
	k.box(p + Vector3(w * 0.3, 1.42, -0.08), Vector3(0.36, 0.16, 0.2), "metal_in")


static func _stove(k: MeshKit, p: Vector3, lit: bool) -> void:
	if k.model("furniture/barrel_stove", p, 0.86, 0.0, 0.0):
		k.cyl(p + Vector3(0, 0.84, 0), 0.075, FH - 0.95, "metal_in", 8)
		k.model("furniture/pot_enamel_01", p + Vector3(0.12, 0.86, 0.05), 0.18, 0.6, 0.0)
		for i in 5:
			k.cyl(p + Vector3(-0.9 - (i % 3) * 0.17, 0.0 + (i / 3) * 0.16, -0.1), 0.08, 0.45, "wood_in", 6)
		return
	k.box(p + Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.6), "metal_in")
	k.box(p + Vector3(0, 1.02, 0), Vector3(0.85, 0.05, 0.7), "metal_in")
	k.cyl(p + Vector3(0.15, 1.04, -0.1), 0.08, FH - 1.2, "metal_in", 8)
	k.box(p + Vector3(-0.38, 0.45, 0), Vector3(0.03, 0.3, 0.3), "candle" if lit else "black_in")
	# firewood
	for i in 5:
		k.cyl(p + Vector3(-0.9 - (i % 3) * 0.17, 0.0 + (i / 3) * 0.16, -0.1), 0.08, 0.45, "wood_in", 6)


static func _sofa(k: MeshKit, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.box(p + b * Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.8), "cloth_in", b)
	k.box(p + b * Vector3(0, 0.7, -0.32), Vector3(2.0, 0.5, 0.18), "cloth_in", b)
	for s in [-1.0, 1.0]:
		var sg: float = s
		k.box(p + b * Vector3(sg * 1.05, 0.38, 0), Vector3(0.16, 0.76, 0.8), "wood_dark_in", b)


## Shelf against a wall. `along` is the wall direction, `face` (+1/-1) the side the shelf opens to.
static func _shelf(k: MeshKit, rng: RandomNumberGenerator, p: Vector3, along: Vector3, w: float, face: float, toys: bool) -> void:
	var out := Vector3(along.z, 0, along.x) * face
	if along.x > 0.5:
		out = Vector3(0, 0, face)
	k.box(p + out * 0.03 + Vector3(0, 1.0, 0), _sz(along, out, w, 2.0, 0.05), "wood_dark_in")
	for i in 5:
		var y := 0.1 + i * 0.45
		var c := p + out * 0.2 + Vector3(0, y, 0)
		k.box(c, _sz(along, out, w, 0.04, 0.34), "planks_in")
		if i < 4:
			var count := int(w * 2.2)
			for j in count:
				if rng.randf() < 0.3:
					continue
				var q := c + along * (-w * 0.5 + w * (j + 0.5) / count) + Vector3(0, 0.02, 0)
				if toys:
					_toy(k, rng, q)
				else:
					var hgt := rng.randf_range(0.18, 0.32)
					if rng.randf() < 0.5:
						k.cyl(q, rng.randf_range(0.04, 0.07), hgt, ["green_in", "wood_in", "white_in", "blue_in"][rng.randi() % 4], 6)
					else:
						k.box(q + Vector3(0, hgt * 0.5, 0), Vector3(0.14, hgt, 0.18), ["cloth_in", "wood_dark_in", "blue_in", "yellow_in"][rng.randi() % 4])


static func _toys(k: MeshKit, rng: RandomNumberGenerator, c: Vector3, w: float, d: float, n: int) -> void:
	for i in n:
		_toy(k, rng, c + Vector3(rng.randf_range(-w, w) * 0.5, 0, rng.randf_range(-d, d) * 0.5))


static func _toy(k: MeshKit, rng: RandomNumberGenerator, q: Vector3) -> void:
	var cols: Array[String] = ["red_in", "green_in", "blue_in", "yellow_in", "white_in", "orange_in"]
	var col := cols[rng.randi() % cols.size()]
	match rng.randi() % 5:
		0:  # ball
			k.sphere(q + Vector3(0, 0.09, 0), 0.09, col, 8, 5)
		1:  # building blocks
			k.box(q + Vector3(0, 0.06, 0), Vector3(0.12, 0.12, 0.12), col)
			k.box(q + Vector3(0.02, 0.18, 0), Vector3(0.12, 0.12, 0.12), cols[rng.randi() % cols.size()], Basis(Vector3.UP, 0.5))
		2:  # little soldier
			k.cyl(q, 0.045, 0.2, col, 6)
			k.sphere(q + Vector3(0, 0.24, 0), 0.045, "skin_in", 6, 4)
			k.cyl(q + Vector3(0, 0.27, 0), 0.04, 0.08, "black_in", 6)
		3:  # toy car
			k.box(q + Vector3(0, 0.06, 0), Vector3(0.24, 0.07, 0.12), col)
			k.box(q + Vector3(-0.02, 0.12, 0), Vector3(0.12, 0.06, 0.11), col)
		_:  # spinning top
			k.cyl(q, 0.0, 0.1, col, 8, 0.09)
			k.cyl(q + Vector3(0, 0.1, 0), 0.09, 0.03, "yellow_in", 8)
			k.cyl(q + Vector3(0, 0.13, 0), 0.012, 0.08, "wood_in", 5)


## Sets a house that stands on a slope so that no ground comes up through its floor: lifts it
## to the highest ground under it, puts a stone base below, and a plank ramp along the front.
static func seat(n: Node3D, terrain: Terrain) -> void:
	var size: Vector2 = n.get_meta("size")
	var hi := -INF
	var lo := INF
	for ix in 7:
		for iz in 7:
			var g := n.to_global(Vector3((ix / 6.0 - 0.5) * size.x, 0, (iz / 6.0 - 0.5) * size.y))
			var h := terrain.height_at(g.x, g.z)
			hi = maxf(hi, h)
			lo = minf(lo, h)
	var want := hi + 0.05
	if want > n.global_position.y + 0.01:
		n.global_position.y = want
	var drop := n.global_position.y - lo
	if drop < 0.12:
		return
	var k := MeshKit.new()
	k.box(Vector3(0, Y0 - 0.06 - (drop + 0.4) * 0.5, 0), Vector3(size.x - 0.04, drop + 0.4, size.y - 0.04), "rock")
	# how far the ground lies below the door sill along the front
	var front := 0.0
	for ix in 7:
		var g := n.to_global(Vector3((ix / 6.0 - 0.5) * size.x, 0, size.y * 0.5 + 1.2))
		front = maxf(front, n.global_position.y + Y0 - terrain.height_at(g.x, g.z))
	if front > 0.2:
		var run := maxf(front * 2.6, 1.4)
		var ang := atan2(front + 0.1, run)
		var len := sqrt(run * run + (front + 0.1) * (front + 0.1))
		k.box(Vector3(0, Y0 - 0.04 - (front + 0.1) * 0.5, size.y * 0.5 + 0.9 + run * 0.5), Vector3(size.x, 0.08, len), "planks", Basis(Vector3.RIGHT, ang))
		k.box(Vector3(0, Y0 - 0.05, size.y * 0.5 + 0.45), Vector3(size.x, 0.08, 0.95), "planks")
	n.add_child(k.node(true))


## The upper storey's walls and windows of a house built in code.
static func _upper_walls(k: MeshKit, w: float, d: float, yw: float, hgt: float, fy: float, upper: String, fr: Array, bk: Array, sd: Array, liner: String, shut: String, frame: String) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_wall(k, Vector3(-hw, yw, hd - T * 0.5), Vector3.RIGHT, w, hgt, upper, fr, Vector3.BACK, liner)
	_wall(k, Vector3(-hw, yw, -hd + T * 0.5), Vector3.RIGHT, w, hgt, upper, bk, Vector3.FORWARD, liner)
	_wall(k, Vector3(-hw + T * 0.5, yw, -hd), Vector3.BACK, d, hgt, upper, sd, Vector3.LEFT, liner)
	_wall(k, Vector3(hw - T * 0.5, yw, -hd), Vector3.BACK, d, hgt, upper, sd, Vector3.RIGHT, liner)
	var wy := fy + 1.5
	for h in fr:
		_window(k, Vector3(-hw + (h[0] + h[1]) * 0.5, wy, hd), Vector3.BACK, 1.0, 1.25, "glass_clear", shut, true, frame)
	for h in bk:
		_window(k, Vector3(-hw + (h[0] + h[1]) * 0.5, wy, -hd), Vector3.FORWARD, 1.0, 1.25, "glass_clear", shut, true, frame)
	for h in sd:
		var z: float = -hd + (h[0] + h[1]) * 0.5
		_window(k, Vector3(-hw, wy, z), Vector3.LEFT, 1.0, 1.25, "glass_clear", shut, true, frame)
		_window(k, Vector3(hw, wy, z), Vector3.RIGHT, 1.0, 1.25, "glass_clear", shut, true, frame)


## The ground floor's walls, windows and door frame of a house built in code.
static func _ground_walls(k: MeshKit, w: float, d: float, clad: String, front: Array, side: Array, liner: String, shut: String, frame: String, town: bool) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	_wall(k, Vector3(-hw, Y0, hd - T * 0.5), Vector3.RIGHT, w, FH, clad, front, Vector3.BACK, liner)
	_wall(k, Vector3(-hw, Y0, -hd + T * 0.5), Vector3.RIGHT, w, FH, clad, [], Vector3.FORWARD, liner)
	_wall(k, Vector3(-hw + T * 0.5, Y0, -hd), Vector3.BACK, d, FH, clad, side, Vector3.LEFT, liner)
	_wall(k, Vector3(hw - T * 0.5, Y0, -hd), Vector3.BACK, d, FH, clad, side, Vector3.RIGHT, liner)
	for h in front:
		var hole: Array = h
		if hole[2] > 0.1:
			_window(k, Vector3(-hw + (hole[0] + hole[1]) * 0.5, Y0 + 1.55, hd), Vector3.BACK, hole[1] - hole[0], 1.2, "glass_clear", shut, true, frame)
	for h in side:
		var hole: Array = h
		var z: float = -hd + (hole[0] + hole[1]) * 0.5
		_window(k, Vector3(-hw, Y0 + 1.55, z), Vector3.LEFT, 1.1, 1.2, "glass_clear", shut, true, frame)
		_window(k, Vector3(hw, Y0 + 1.55, z), Vector3.RIGHT, 1.1, 1.2, "glass_clear", shut, true, frame)
	# door frame
	var dfr := frame if town else "wood_dark"
	k.box(Vector3(-0.56, Y0 + 1.08, hd), Vector3(0.12, 2.16, T + 0.1), dfr)
	k.box(Vector3(0.56, Y0 + 1.08, hd), Vector3(0.12, 2.16, T + 0.1), dfr)
	k.box(Vector3(0, Y0 + 2.16, hd), Vector3(1.24, 0.12, T + 0.1), dfr)
