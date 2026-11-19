class_name WeaponMesh
## Detailed weapon models. Guns point along -Z with the pistol grip at the origin
## and the bore at y = BORE. Metas: "muzzle", "support" (where the other hand
## holds), "mag" (where the magazine sits, for the reload animation).

const BORE := 0.035
const GUNMETAL := "gunmetal_in"
const POLY := "polymer_in"
const STEEL := "steel_clean_in"
const WORN := "worn_in"


static func gun(id: String, shape: String, mods: Array) -> Node3D:
	var k := MeshKit.new()
	var d := {"muzzle": Vector3(0, BORE, -0.3), "support": Vector3(0.0, -0.02, -0.02), "mag": Vector3(0, -0.06, 0.02), "rail_z": -0.08, "fore_z": -0.3}
	var scan: Node3D = _scanned(id, d)
	if scan:
		mods = mods.filter(func(m): return not (m in ["scope", "red_dot"]))
		_mods(k, d, mods, shape)
		var root := k.node(false)
		root.add_child(scan)
		for key in ["muzzle", "support", "mag", "sight"]:
			root.set_meta(key, d[key])
		return root
	# made in Blender from the same plan (bevelled, real metal and walnut surfaces): the code shape
	# still runs to fill in the hand and muzzle points, then the model stands in for its mesh
	var made: Node3D = ModelLib.spawn("guns/" + id) if ModelLib.has("guns/" + id) else null
	if made:
		var skip := MeshKit.new()
		_shape(skip, id, d, mods)
		_mods(k, d, mods, shape)
		var root := k.node(false)
		root.add_child(made)
		for key in ["muzzle", "support", "mag"]:
			root.set_meta(key, d[key])
		root.set_meta("sight", _sight(id, mods))
		return root
	_shape(k, id, d, mods)
	_mods(k, d, mods, shape)
	var n := k.node(false)
	for key in ["muzzle", "support", "mag"]:
		n.set_meta(key, d[key])
	n.set_meta("sight", _sight(id, mods))
	return n


static func _sight(id: String, mods: Array) -> float:
	var sights := {"pistol": 0.078, "revolver": 0.083, "smg": 0.08, "assault_rifle": 0.084, "marksman_rifle": 0.084,
		"shotgun": 0.072, "sniper_rifle": 0.1, "flare_gun": 0.076}
	if "scope" in mods:
		return 0.1
	if "red_dot" in mods:
		return 0.098
	return float(sights.get(id, 0.08))


static func _shape(k: MeshKit, id: String, d: Dictionary, mods: Array) -> void:
	match id:
		"pistol":
			_pistol(k, d, mods)
		"revolver":
			_revolver(k, d)
		"smg":
			_smg(k, d, mods)
		"assault_rifle":
			_assault(k, d, mods)
		"marksman_rifle":
			_marksman(k, d, mods)
		"shotgun":
			_shotgun(k, d)
		"sniper_rifle":
			_sniper(k, d)
		_:
			_flare(k, d)


## Scanned guns made in Blender (Poly Haven, CC0). In the files the barrel points along +X
## with +Y up; `at` is the scan point that goes to the grip origin.
const SCANS := {
	"pistol": {"file": "service_pistol", "at": Vector3(0.008, -0.013, 0.0), "muzzle": Vector3(0, 0.05, -0.182),
		"support": Vector3(-0.025, -0.045, 0.01), "mag": Vector3(0, -0.05, 0.006), "sight": 0.073},
	"marksman_rifle": {"file": "bolt_action_rifle_7_62", "at": Vector3(0.32, -0.016, 0.0), "muzzle": Vector3(0, BORE, -0.916),
		"support": Vector3(0, -0.01, -0.4), "mag": Vector3(0, -0.056, -0.12), "sight": 0.066, "fore_z": -0.4},
}


static func _scanned(id: String, d: Dictionary) -> Node3D:
	if not SCANS.has(id) or not ModelLib.has(SCANS[id]["file"]):
		return null
	var info: Dictionary = SCANS[id]
	var m := ModelLib.spawn(info["file"])
	if m == null:
		return null
	# barrel +X -> -Z, then move the grip to the origin
	var b := Basis(Vector3.UP, PI * 0.5)
	var at: Vector3 = info["at"]
	m.transform = Transform3D(b, Vector3(0, at.y, -at.x))
	for key in ["muzzle", "support", "mag", "sight", "fore_z"]:
		if info.has(key):
			d[key] = info[key]
	return m


# ------------------------------------------------------------ shared parts
static func _barrel(k: MeshKit, z0: float, z1: float, r: float, mat := GUNMETAL, y := BORE) -> void:
	k.tube(Vector3(0, y, z0), Vector3(0, y, z1), r, mat, 10)
	k.tube(Vector3(0, y, z1 + 0.002), Vector3(0, y, z1 - 0.001), r * 0.55, "black_in", 8)   # the hole


static func _grip(k: MeshKit, mat: String, at := Vector3(0, -0.05, 0.022), size := Vector3(0.03, 0.115, 0.046), tilt := -0.22) -> void:
	var b := Basis(Vector3.RIGHT, tilt)
	k.bbox(at, size, 0.008, mat, b)
	for i in 5:   # grip grooves
		k.box(at + b * Vector3(0, -0.04 + i * 0.02, 0), Vector3(size.x + 0.003, 0.004, size.z * 0.7), GUNMETAL, b)
	k.bbox(at + b * Vector3(0, -size.y * 0.5, 0), Vector3(size.x + 0.004, 0.008, size.z + 0.004), 0.003, GUNMETAL, b)


static func _trigger(k: MeshKit, z := -0.03, y := 0.0) -> void:
	k.box(Vector3(0, y - 0.034, z - 0.012), Vector3(0.008, 0.004, 0.066), GUNMETAL)
	k.box(Vector3(0, y - 0.018, z - 0.046), Vector3(0.008, 0.034, 0.004), GUNMETAL, Basis(Vector3.RIGHT, 0.25))
	k.box(Vector3(0, y - 0.016, z - 0.008), Vector3(0.006, 0.026, 0.006), STEEL, Basis(Vector3.RIGHT, -0.3))


static func _irons(k: MeshKit, rear_z: float, front_z: float, top := 0.08) -> void:
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.box(Vector3(x * 0.007, top - 0.005, rear_z), Vector3(0.005, 0.012, 0.008), GUNMETAL)
	k.box(Vector3(0, top - 0.012, rear_z), Vector3(0.022, 0.006, 0.01), GUNMETAL)
	k.box(Vector3(0, top - 0.006, front_z), Vector3(0.004, 0.014, 0.006), GUNMETAL)
	k.ball(Vector3(0, top - 0.001, front_z + 0.004), Vector3(0.0022, 0.0022, 0.0015), "white_in", 5, 3)


static func _rail(k: MeshKit, z0: float, z1: float, y: float) -> void:
	k.box(Vector3(0, y, (z0 + z1) * 0.5), Vector3(0.018, 0.006, absf(z1 - z0)), GUNMETAL)
	var n := int(absf(z1 - z0) / 0.012)
	for i in n:
		k.box(Vector3(0, y + 0.005, z0 + (z1 - z0) * (i + 0.5) / n), Vector3(0.022, 0.004, 0.006), GUNMETAL)


## A magazine that curves forward, made of short segments.
static func _mag(k: MeshKit, at: Vector3, length: float, curve: float, size: Vector2, mat := WORN) -> void:
	var segs := 4
	var p := at
	var ang := 0.1
	for i in segs:
		var b := Basis(Vector3.RIGHT, ang)
		var step := length / segs
		k.bbox(p + b * Vector3(0, -step * 0.5, 0), Vector3(size.x, step + 0.004, size.y), 0.004, mat, b)
		p += b * Vector3(0, -step, 0)
		ang += curve / segs
	k.bbox(p, Vector3(size.x + 0.004, 0.008, size.y + 0.006), 0.003, GUNMETAL, Basis(Vector3.RIGHT, ang))


static func _stock(k: MeshKit, mat: String, z0: float, length: float, drop := 0.03) -> void:
	var tilt := Basis(Vector3.RIGHT, -atan2(drop, length))
	var mid := Vector3(0, 0.02 - drop * 0.5, z0 + length * 0.5)
	k.bbox(mid, Vector3(0.032, 0.05, length), 0.012, mat, tilt)
	k.bbox(mid + Vector3(0, -0.03, length * 0.2), Vector3(0.03, 0.05, length * 0.6), 0.012, mat, Basis(Vector3.RIGHT, -atan2(drop, length) - 0.18))
	k.bbox(Vector3(0, 0.0 - drop, z0 + length), Vector3(0.036, 0.115, 0.016), 0.006, "black_in")   # butt pad


# ------------------------------------------------------------ the guns
static func _pistol(k: MeshKit, d: Dictionary, mods: Array) -> void:
	k.bbox(Vector3(0, 0.05, -0.075), Vector3(0.03, 0.034, 0.2), 0.006, GUNMETAL)                 # slide
	k.bbox(Vector3(0, 0.024, -0.065), Vector3(0.029, 0.022, 0.17), 0.005, POLY)                  # frame
	k.box(Vector3(0, 0.02, -0.14), Vector3(0.022, 0.008, 0.04), GUNMETAL)                        # light rail
	for i in 6:
		k.box(Vector3(0, 0.05, 0.005 - i * 0.008), Vector3(0.032, 0.026, 0.003), POLY)           # slide serrations
	k.box(Vector3(0.0155, 0.056, -0.07), Vector3(0.002, 0.014, 0.036), STEEL)                    # ejection port
	_barrel(k, -0.16, -0.182, 0.0075, STEEL, 0.05)
	_grip(k, POLY)
	_trigger(k, -0.022, 0.012)
	var deep := 0.05 if "ext_mag" in mods else 0.0
	k.bbox(Vector3(0, -0.112 - deep * 0.5, 0.036), Vector3(0.026, 0.014 + deep, 0.04), 0.004, WORN, Basis(Vector3.RIGHT, -0.22))
	_irons(k, 0.018, -0.165, 0.08)
	k.box(Vector3(0, 0.05, 0.03), Vector3(0.012, 0.016, 0.01), GUNMETAL)                         # striker plate
	d["muzzle"] = Vector3(0, 0.05, -0.182)
	d["support"] = Vector3(-0.025, -0.045, 0.01)
	d["mag"] = Vector3(0, -0.1, 0.035)
	d["bore"] = 0.05


static func _revolver(k: MeshKit, d: Dictionary) -> void:
	k.bbox(Vector3(0, 0.04, -0.03), Vector3(0.022, 0.07, 0.11), 0.008, STEEL)                    # frame
	k.tube(Vector3(0, 0.04, -0.012), Vector3(0, 0.04, -0.062), 0.024, STEEL, 12)                 # cylinder
	for i in 6:
		var a := TAU * i / 6.0
		k.tube(Vector3(cos(a) * 0.022, 0.04 + sin(a) * 0.022, -0.016), Vector3(cos(a) * 0.022, 0.04 + sin(a) * 0.022, -0.058), 0.006, WORN, 6)
		k.ball(Vector3(cos(a + 0.52) * 0.015, 0.04 + sin(a + 0.52) * 0.015, -0.0105), Vector3(0.0045, 0.0045, 0.002), "brass", 6, 3)
	_barrel(k, -0.07, -0.22, 0.0095, STEEL, 0.052)
	k.bbox(Vector3(0, 0.036, -0.14), Vector3(0.014, 0.014, 0.14), 0.004, STEEL)                  # under-lug
	k.box(Vector3(0, 0.066, -0.14), Vector3(0.008, 0.006, 0.15), STEEL)                          # rib
	k.box(Vector3(0, 0.078, -0.21), Vector3(0.004, 0.018, 0.016), GUNMETAL)                      # front sight
	k.box(Vector3(0, 0.08, 0.02), Vector3(0.016, 0.008, 0.012), GUNMETAL)                        # rear notch
	k.box(Vector3(0, 0.075, 0.04), Vector3(0.008, 0.024, 0.012), STEEL, Basis(Vector3.RIGHT, -0.6))   # hammer
	var b := Basis(Vector3.RIGHT, -0.3)
	k.bbox(Vector3(0, -0.04, 0.03), Vector3(0.03, 0.1, 0.045), 0.012, "walnut_dark_in", b)
	k.bbox(Vector3(0, -0.085, 0.048), Vector3(0.032, 0.03, 0.05), 0.012, "walnut_dark_in", b)
	k.ball(Vector3(0.016, -0.03, 0.03), Vector3(0.003, 0.008, 0.008), "brass", 6, 3)
	_trigger(k, -0.01, 0.015)
	d["muzzle"] = Vector3(0, 0.052, -0.22)
	d["support"] = Vector3(-0.025, -0.045, 0.015)
	d["bore"] = 0.052


static func _smg(k: MeshKit, d: Dictionary, mods: Array) -> void:
	k.tube(Vector3(0, 0.045, 0.07), Vector3(0, 0.045, -0.2), 0.02, GUNMETAL, 10)                 # receiver tube
	k.bbox(Vector3(0, 0.015, -0.06), Vector3(0.032, 0.04, 0.2), 0.006, POLY)                     # lower
	k.bbox(Vector3(0, 0.035, -0.27), Vector3(0.04, 0.05, 0.14), 0.01, POLY)                      # handguard
	for i in 3:
		k.box(Vector3(0, 0.035, -0.23 - i * 0.035), Vector3(0.042, 0.012, 0.02), GUNMETAL)
	_barrel(k, -0.2, -0.37, 0.0085)
	k.tube(Vector3(0, BORE, -0.36), Vector3(0, BORE, -0.385), 0.012, GUNMETAL, 8)
	k.tube(Vector3(0.0, 0.064, -0.22), Vector3(0.022, 0.07, -0.22), 0.005, STEEL, 6)             # cocking handle
	k.ball(Vector3(0.026, 0.07, -0.22), Vector3(0.008, 0.008, 0.008), GUNMETAL, 6, 4)
	_grip(k, POLY)
	_trigger(k, -0.03, 0.0)
	_mag(k, Vector3(0, -0.005, -0.12), 0.16 + (0.07 if "ext_mag" in mods else 0.0), 0.35, Vector2(0.022, 0.034))
	# folding stock: two rods and a butt plate
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.tube(Vector3(x * 0.014, 0.045, 0.07), Vector3(x * 0.014, 0.035, 0.27), 0.004, STEEL, 6)
	k.bbox(Vector3(0, 0.02, 0.275), Vector3(0.036, 0.09, 0.012), 0.004, GUNMETAL)
	# hooded front sight and rear drum
	k.tube(Vector3(0, 0.076, -0.33), Vector3(0, 0.076, -0.345), 0.012, GUNMETAL, 8, 0.012, false)
	_irons(k, 0.02, -0.337, 0.082)
	d["muzzle"] = Vector3(0, BORE, -0.385)
	d["support"] = Vector3(0, 0.0, -0.27)
	d["mag"] = Vector3(0, -0.09, -0.12)
	d["fore_z"] = -0.27


static func _assault(k: MeshKit, d: Dictionary, mods: Array) -> void:
	k.bbox(Vector3(0, 0.035, -0.09), Vector3(0.036, 0.062, 0.3), 0.007, GUNMETAL)                # receiver
	k.box(Vector3(0.0185, 0.045, -0.08), Vector3(0.002, 0.018, 0.06), STEEL)                     # ejection port
	k.ball(Vector3(0.019, 0.03, -0.02), Vector3(0.003, 0.007, 0.007), STEEL, 6, 3)               # selector
	k.tube(Vector3(0.018, 0.05, -0.15), Vector3(0.034, 0.05, -0.15), 0.004, STEEL, 6)            # charging handle
	k.bbox(Vector3(0, 0.036, -0.37), Vector3(0.042, 0.052, 0.26), 0.012, POLY)                   # handguard
	for i in 5:
		for sx in [-1.0, 1.0]:
			var x: float = sx
			k.box(Vector3(x * 0.0215, 0.04, -0.27 - i * 0.045), Vector3(0.002, 0.012, 0.028), "black_in")   # vents
	k.tube(Vector3(0, 0.062, -0.24), Vector3(0, 0.062, -0.52), 0.007, GUNMETAL, 8)               # gas tube
	_barrel(k, -0.24, -0.66, 0.0085)
	k.bbox(Vector3(0, 0.05, -0.53), Vector3(0.016, 0.05, 0.02), 0.004, GUNMETAL)                 # gas block
	k.tube(Vector3(0, BORE, -0.63), Vector3(0, BORE, -0.69), 0.012, GUNMETAL, 8)                 # flash hider
	for i in 3:
		k.box(Vector3(0, BORE, -0.645 - i * 0.014), Vector3(0.026, 0.004, 0.006), "black_in")
	_grip(k, POLY)
	_trigger(k, -0.03, 0.004)
	_mag(k, Vector3(0, 0.005, -0.13), 0.17 + (0.08 if "ext_mag" in mods else 0.0), 0.45, Vector2(0.024, 0.06))
	k.box(Vector3(0, -0.005, -0.085), Vector3(0.012, 0.03, 0.008), STEEL)                        # mag catch
	# buffer tube and adjustable stock
	k.tube(Vector3(0, 0.04, 0.06), Vector3(0, 0.04, 0.26), 0.013, GUNMETAL, 8)
	k.bbox(Vector3(0, 0.025, 0.24), Vector3(0.034, 0.08, 0.14), 0.012, POLY)
	k.bbox(Vector3(0, 0.0, 0.305), Vector3(0.036, 0.13, 0.016), 0.006, "black_in")
	k.box(Vector3(0, -0.02, 0.22), Vector3(0.02, 0.05, 0.06), POLY, Basis(Vector3.RIGHT, 0.5))
	_rail(k, 0.04, -0.22, 0.068)
	# front sight tower with ears, rear aperture
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.box(Vector3(x * 0.009, 0.074, -0.53), Vector3(0.003, 0.022, 0.012), GUNMETAL)
	_irons(k, 0.03, -0.53, 0.086)
	d["muzzle"] = Vector3(0, BORE, -0.69)
	d["support"] = Vector3(0, 0.0, -0.36)
	d["mag"] = Vector3(0, -0.1, -0.14)
	d["fore_z"] = -0.36


static func _marksman(k: MeshKit, d: Dictionary, mods: Array) -> void:
	var wood := "walnut_in"
	k.bbox(Vector3(0, 0.038, -0.1), Vector3(0.036, 0.056, 0.32), 0.008, GUNMETAL)
	k.box(Vector3(0.0185, 0.048, -0.1), Vector3(0.002, 0.016, 0.07), STEEL)
	k.tube(Vector3(0.018, 0.05, -0.02), Vector3(0.04, 0.045, -0.02), 0.004, STEEL, 6)            # op handle
	k.ball(Vector3(0.043, 0.044, -0.02), Vector3(0.007, 0.007, 0.007), STEEL, 6, 4)
	k.bbox(Vector3(0, 0.022, -0.4), Vector3(0.044, 0.046, 0.3), 0.014, wood)                     # wooden fore-end
	k.bbox(Vector3(0, 0.05, -0.4), Vector3(0.03, 0.02, 0.26), 0.008, wood)
	_barrel(k, -0.26, -0.8, 0.009)
	k.tube(Vector3(0, BORE, -0.76), Vector3(0, BORE, -0.84), 0.0125, GUNMETAL, 8)
	k.bbox(Vector3(0, 0.055, -0.6), Vector3(0.014, 0.036, 0.018), 0.004, GUNMETAL)
	# one-piece wooden stock with a pistol-grip curve
	_stock(k, wood, 0.05, 0.3, 0.035)
	k.bbox(Vector3(0, -0.04, 0.03), Vector3(0.032, 0.1, 0.05), 0.014, wood, Basis(Vector3.RIGHT, -0.35))
	k.bbox(Vector3(0, 0.055, 0.2), Vector3(0.03, 0.03, 0.14), 0.01, POLY)                        # cheek rest
	_trigger(k, -0.03, 0.004)
	var deep := 0.06 if "ext_mag" in mods else 0.0
	k.bbox(Vector3(0, -0.035 - deep * 0.5, -0.13), Vector3(0.026, 0.08 + deep, 0.07), 0.005, WORN, Basis(Vector3.RIGHT, 0.08))
	_rail(k, 0.03, -0.2, 0.069)
	_irons(k, 0.03, -0.6, 0.086)
	d["muzzle"] = Vector3(0, BORE, -0.84)
	d["support"] = Vector3(0, -0.01, -0.4)
	d["mag"] = Vector3(0, -0.08, -0.13)
	d["fore_z"] = -0.42


static func _shotgun(k: MeshKit, d: Dictionary) -> void:
	var wood := "walnut_dark_in"
	k.bbox(Vector3(0, 0.03, -0.1), Vector3(0.038, 0.068, 0.26), 0.01, GUNMETAL)                  # receiver
	k.box(Vector3(0.0195, 0.04, -0.12), Vector3(0.002, 0.02, 0.07), STEEL)                       # ejection port
	k.box(Vector3(0, -0.005, -0.12), Vector3(0.024, 0.004, 0.09), STEEL)                         # loading gate
	_barrel(k, -0.22, -0.74, 0.0115, GUNMETAL, 0.045)
	k.tube(Vector3(0, 0.016, -0.22), Vector3(0, 0.016, -0.66), 0.0115, GUNMETAL, 10)             # magazine tube
	k.ball(Vector3(0, 0.016, -0.662), Vector3(0.013, 0.013, 0.008), STEEL, 8, 4)
	k.bbox(Vector3(0, 0.03, -0.64), Vector3(0.012, 0.04, 0.014), 0.003, GUNMETAL)                # barrel band
	# ribbed wooden pump
	k.tube(Vector3(0, 0.016, -0.34), Vector3(0, 0.016, -0.52), 0.024, wood, 10)
	for i in 7:
		k.tube(Vector3(0, 0.016, -0.35 - i * 0.024), Vector3(0, 0.016, -0.36 - i * 0.024), 0.026, wood, 10)
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.box(Vector3(x * 0.015, 0.016, -0.28), Vector3(0.003, 0.008, 0.12), STEEL)             # action bars
	_stock(k, wood, 0.04, 0.3, 0.05)
	k.bbox(Vector3(0, -0.035, 0.035), Vector3(0.032, 0.09, 0.052), 0.014, wood, Basis(Vector3.RIGHT, -0.45))
	_trigger(k, -0.03, 0.002)
	k.ball(Vector3(0, 0.062, -0.73), Vector3(0.004, 0.004, 0.004), "brass", 6, 4)                # bead
	k.box(Vector3(0, 0.07, 0.0), Vector3(0.018, 0.012, 0.012), GUNMETAL)
	k.box(Vector3(0, 0.078, 0.0), Vector3(0.004, 0.006, 0.014), "black_in")
	d["muzzle"] = Vector3(0, 0.045, -0.74)
	d["support"] = Vector3(0, -0.005, -0.43)
	d["bore"] = 0.045
	d["fore_z"] = -0.43


static func _sniper(k: MeshKit, d: Dictionary) -> void:
	var body := "olive_in"
	k.bbox(Vector3(0, 0.035, -0.1), Vector3(0.04, 0.06, 0.34), 0.01, GUNMETAL)                   # action
	k.bbox(Vector3(0, 0.012, -0.38), Vector3(0.05, 0.05, 0.36), 0.016, body)                     # fore-end
	_barrel(k, -0.27, -0.92, 0.012)
	for i in 6:   # fluting
		var a := TAU * i / 6.0
		k.tube(Vector3(cos(a) * 0.011, BORE + sin(a) * 0.011, -0.4), Vector3(cos(a) * 0.011, BORE + sin(a) * 0.011, -0.82), 0.004, "black_in", 4)
	# muzzle brake
	k.bbox(Vector3(0, BORE, -0.95), Vector3(0.034, 0.028, 0.07), 0.006, GUNMETAL)
	for i in 3:
		k.box(Vector3(0, BORE, -0.928 - i * 0.02), Vector3(0.036, 0.014, 0.008), "black_in")
	# bolt with a round knob
	k.tube(Vector3(0, 0.05, 0.05), Vector3(0, 0.05, -0.02), 0.009, STEEL, 8)
	k.tube(Vector3(0.012, 0.05, 0.03), Vector3(0.045, 0.03, 0.035), 0.004, STEEL, 6)
	k.ball(Vector3(0.05, 0.026, 0.036), Vector3(0.011, 0.011, 0.011), GUNMETAL, 8, 5)
	# chassis stock with cheek riser and thumb hole
	k.bbox(Vector3(0, 0.005, 0.2), Vector3(0.038, 0.07, 0.3), 0.014, body)
	k.bbox(Vector3(0, -0.04, 0.26), Vector3(0.034, 0.06, 0.16), 0.014, body)
	k.bbox(Vector3(0, 0.055, 0.2), Vector3(0.034, 0.03, 0.15), 0.01, POLY)
	k.bbox(Vector3(0, -0.01, 0.36), Vector3(0.04, 0.14, 0.02), 0.006, "black_in")
	_grip(k, POLY, Vector3(0, -0.05, 0.03), Vector3(0.032, 0.11, 0.05), -0.3)
	_trigger(k, -0.03, 0.002)
	k.bbox(Vector3(0, -0.035, -0.12), Vector3(0.03, 0.07, 0.085), 0.005, WORN)                   # box magazine
	# folded bipod
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.tube(Vector3(x * 0.018, -0.012, -0.52), Vector3(x * 0.03, -0.022, -0.3), 0.005, GUNMETAL, 6)
		k.ball(Vector3(x * 0.03, -0.022, -0.3), Vector3(0.008, 0.008, 0.012), "black_in", 6, 4)
	k.bbox(Vector3(0, -0.012, -0.53), Vector3(0.05, 0.02, 0.03), 0.005, GUNMETAL)
	_scope(k, -0.1, 0.34, 0.1, true)
	d["muzzle"] = Vector3(0, BORE, -0.985)
	d["support"] = Vector3(0, -0.02, -0.38)
	d["mag"] = Vector3(0, -0.08, -0.12)
	d["fore_z"] = -0.4


static func _flare(k: MeshKit, d: Dictionary) -> void:
	k.tube(Vector3(0, 0.045, -0.02), Vector3(0, 0.045, -0.17), 0.021, "orange_in", 12)
	k.tube(Vector3(0, 0.045, -0.172), Vector3(0, 0.045, -0.168), 0.016, "black_in", 10)
	k.tube(Vector3(0, 0.045, -0.15), Vector3(0, 0.045, -0.17), 0.024, "orange_in", 12)
	k.bbox(Vector3(0, 0.03, 0.01), Vector3(0.032, 0.06, 0.08), 0.01, "orange_in")
	k.tube(Vector3(-0.02, 0.02, -0.02), Vector3(0.02, 0.02, -0.02), 0.006, STEEL, 6)             # hinge pin
	k.box(Vector3(0, 0.07, 0.035), Vector3(0.01, 0.02, 0.012), STEEL, Basis(Vector3.RIGHT, -0.5))
	_grip(k, "black_in", Vector3(0, -0.05, 0.03), Vector3(0.03, 0.11, 0.045), -0.25)
	_trigger(k, -0.015, 0.008)
	k.box(Vector3(0, 0.072, -0.16), Vector3(0.004, 0.012, 0.008), "black_in")
	d["muzzle"] = Vector3(0, 0.045, -0.17)
	d["support"] = Vector3(-0.025, -0.045, 0.015)
	d["bore"] = 0.045


# ------------------------------------------------------------ attachments
static func _scope(k: MeshKit, z: float, length: float, y: float, big: bool) -> void:
	var r := 0.015 if big else 0.013
	var z0 := z + length * 0.5
	var z1 := z - length * 0.5
	k.tube(Vector3(0, y, z0), Vector3(0, y, z1), r, GUNMETAL, 12)
	k.tube(Vector3(0, y, z1 + 0.08), Vector3(0, y, z1), r, GUNMETAL, 12, r * 1.75)               # objective bell
	k.tube(Vector3(0, y, z1 + 0.002), Vector3(0, y, z1 - 0.001), r * 1.6, "glass_dark", 12)
	k.tube(Vector3(0, y, z0), Vector3(0, y, z0 - 0.06), r * 1.4, GUNMETAL, 12, r)                # eyepiece
	k.tube(Vector3(0, y, z0 + 0.001), Vector3(0, y, z0 - 0.002), r * 1.25, "glass_dark", 12)
	k.tube(Vector3(0, y, z), Vector3(0, y + r + 0.016, z), 0.009, GUNMETAL, 8)                   # turrets
	k.tube(Vector3(0, y, z), Vector3(r + 0.016, y, z), 0.009, GUNMETAL, 8)
	for dz in [-0.06, 0.07]:
		var o: float = dz
		k.bbox(Vector3(0, y - 0.004, z + o), Vector3(0.04, 0.042, 0.016), 0.006, GUNMETAL)       # rings
		k.box(Vector3(0, y - r - 0.01, z + o), Vector3(0.022, 0.016, 0.02), GUNMETAL)


static func _mods(k: MeshKit, d: Dictionary, mods: Array, shape: String) -> void:
	var muzzle: Vector3 = d["muzzle"]
	if "red_dot" in mods:
		var z := -0.08
		k.bbox(Vector3(0, 0.076, z), Vector3(0.03, 0.012, 0.055), 0.003, GUNMETAL)
		k.tube(Vector3(0, 0.1, z + 0.02), Vector3(0, 0.1, z - 0.02), 0.019, GUNMETAL, 12, 0.019, false)
		k.tube(Vector3(0, 0.1, z - 0.02), Vector3(0, 0.1, z + 0.02), 0.0175, "black_in", 12, 0.0175, false)   # inside of the hood
		k.ball(Vector3(0, 0.098, z), Vector3(0.0018, 0.0018, 0.0018), "candle", 6, 4)
		k.tube(Vector3(0.019, 0.09, z), Vector3(0.028, 0.09, z), 0.006, GUNMETAL, 6)
	if "scope" in mods and shape != "sniper":
		_scope(k, -0.1, 0.26, 0.1, false)
	if "silencer" in mods:
		k.tube(muzzle + Vector3(0, 0, 0.01), muzzle - Vector3(0, 0, 0.18), 0.02, GUNMETAL, 12)
		k.tube(muzzle - Vector3(0, 0, 0.181), muzzle - Vector3(0, 0, 0.178), 0.008, "black_in", 8)
		for i in 4:
			k.tube(muzzle - Vector3(0, 0, 0.02 + i * 0.045), muzzle - Vector3(0, 0, 0.026 + i * 0.045), 0.0208, WORN, 12)
		muzzle.z -= 0.18
	if "muzzle_brake" in mods:
		k.bbox(muzzle - Vector3(0, 0, 0.025), Vector3(0.03, 0.026, 0.055), 0.005, WORN)
		for i in 2:
			k.box(muzzle - Vector3(0, 0, 0.015 + i * 0.02), Vector3(0.032, 0.012, 0.008), "black_in")
		muzzle.z -= 0.055
	if "grip" in mods:
		var z: float = d["fore_z"]
		k.tube(Vector3(0, 0.01, z), Vector3(0, -0.09, z + 0.012), 0.015, POLY, 8, 0.017)
		k.bbox(Vector3(0, 0.01, z), Vector3(0.026, 0.012, 0.04), 0.003, GUNMETAL)
		d["support"] = Vector3(0, -0.05, z + 0.006)
	d["muzzle"] = muzzle


# ------------------------------------------------------------ blades
## Melee weapons stand upright (+Y) with the hand at the origin; the edge faces -Z.
static func melee(id: String) -> Node3D:
	var k := MeshKit.new()
	match id:
		"knife":
			k.bbox(Vector3(0, 0.0, 0), Vector3(0.026, 0.11, 0.032), 0.01, "black_in")
			for i in 4:
				k.box(Vector3(0, -0.035 + i * 0.022, 0), Vector3(0.028, 0.005, 0.034), POLY)
			k.bbox(Vector3(0, 0.062, 0), Vector3(0.014, 0.012, 0.062), 0.004, STEEL)             # guard
			k.ball(Vector3(0, -0.06, 0), Vector3(0.015, 0.012, 0.018), STEEL, 8, 4)              # pommel
			_blade(k, 0.07, 0.19, 0.034, 0.005, 0.07)
		"sword":
			k.tube(Vector3(0, -0.11, 0), Vector3(0, 0.08, 0), 0.015, "walnut_dark_in", 8)
			for i in 9:
				k.tube(Vector3(0, -0.1 + i * 0.02, 0), Vector3(0, -0.094 + i * 0.02, 0), 0.0165, "brass", 8)   # wire wrap
			k.ball(Vector3(0, -0.125, 0), Vector3(0.022, 0.02, 0.022), "brass", 8, 5)            # pommel
			k.bbox(Vector3(0, 0.088, 0), Vector3(0.02, 0.016, 0.16), 0.006, "brass")             # cross guard
			# knuckle bow
			for i in 6:
				var a0 := PI * i / 6.0
				var a1 := PI * (i + 1) / 6.0
				k.tube(Vector3(0, -0.02 - cos(a0) * 0.1, -0.02 - sin(a0) * 0.06), Vector3(0, -0.02 - cos(a1) * 0.1, -0.02 - sin(a1) * 0.06), 0.005, "brass", 6)
			_blade(k, 0.096, 0.86, 0.042, 0.007, 0.16, true)
		"axe":
			# curved hickory handle
			for i in 6:
				var y0 := -0.14 + i * 0.12
				var bend0 := sin(i * 0.5) * 0.012
				var bend1 := sin((i + 1) * 0.5) * 0.012
				k.tube(Vector3(0, y0, bend0), Vector3(0, y0 + 0.12, bend1), 0.017, "walnut_in", 8, 0.016)
			k.ball(Vector3(0, -0.14, 0), Vector3(0.02, 0.016, 0.024), "walnut_in", 8, 4)
			# head: poll, cheek and a flared bit
			k.bbox(Vector3(0, 0.52, 0.03), Vector3(0.036, 0.07, 0.05), 0.008, WORN)
			k.bbox(Vector3(0, 0.52, -0.03), Vector3(0.03, 0.08, 0.09), 0.008, WORN)
			var st := "steel_clean_in"
			k.quad_o(Vector3(0.012, 0.56, -0.07), Vector3(0.012, 0.47, -0.07), Vector3(0, 0.44, -0.16), Vector3(0, 0.6, -0.16), Vector3.RIGHT, st)
			k.quad_o(Vector3(-0.012, 0.56, -0.07), Vector3(-0.012, 0.47, -0.07), Vector3(0, 0.44, -0.16), Vector3(0, 0.6, -0.16), Vector3.LEFT, st)
			k.quad_o(Vector3(0.012, 0.56, -0.07), Vector3(-0.012, 0.56, -0.07), Vector3(0, 0.6, -0.16), Vector3(0, 0.6, -0.16), Vector3.UP, st)
			k.quad_o(Vector3(0.012, 0.47, -0.07), Vector3(-0.012, 0.47, -0.07), Vector3(0, 0.44, -0.16), Vector3(0, 0.44, -0.16), Vector3.DOWN, st)
		_:  # ice pick: a climbing axe
			k.tube(Vector3(0, -0.12, 0), Vector3(0, 0.42, 0), 0.013, STEEL, 8)
			k.tube(Vector3(0, -0.12, 0), Vector3(0, 0.1, 0), 0.017, "red_in", 8)                 # rubber grip
			k.tube(Vector3(0, -0.12, 0), Vector3(0, -0.19, 0), 0.01, STEEL, 6, 0.0)              # spike
			k.bbox(Vector3(0, 0.43, 0), Vector3(0.022, 0.035, 0.05), 0.006, STEEL)
			# long toothed pick, curving down
			for i in 5:
				var z0 := -0.02 - i * 0.045
				var z1 := z0 - 0.045
				var y0 := 0.435 - i * i * 0.005
				var y1 := 0.435 - (i + 1) * (i + 1) * 0.005
				k.tube(Vector3(0, y0, z0), Vector3(0, y1, z1), 0.008 - i * 0.0012, STEEL, 6, 0.0068 - i * 0.0012)
				k.box(Vector3(0, y1 - 0.01, z1 + 0.01), Vector3(0.006, 0.01, 0.01), STEEL, Basis(Vector3.RIGHT, 0.6))
			# adze at the back
			k.bbox(Vector3(0, 0.432, 0.06), Vector3(0.05, 0.008, 0.07), 0.003, STEEL, Basis(Vector3.RIGHT, 0.25))
			k.tube(Vector3(0, -0.1, 0.02), Vector3(0, -0.02, 0.04), 0.003, "red_in", 4)          # wrist loop
	return k.node(false)


## A blade with a real edge: thick spine at +Z, sharp at -Z, tapering to a point.
static func _blade(k: MeshKit, y0: float, length: float, width: float, thick: float, tip: float, curved := false) -> void:
	var segs := 6 if curved else 2
	var body := length - tip
	var st := "steel_clean_in"
	for i in segs:
		var a := y0 + body * i / segs
		var b := y0 + body * (i + 1) / segs
		var ca := (pow(float(i) / segs, 2.0) * 0.05) if curved else 0.0
		var cb := (pow(float(i + 1) / segs, 2.0) * 0.05) if curved else 0.0
		for sx in [-1.0, 1.0]:
			var x: float = sx
			var out := Vector3(x, 0, -0.2)
			k.quad_o(Vector3(x * thick, a, width * 0.5 + ca), Vector3(x * thick, b, width * 0.5 + cb),
					Vector3(0, b, -width * 0.5 + cb), Vector3(0, a, -width * 0.5 + ca), out, st)
		k.quad_o(Vector3(-thick, a, width * 0.5 + ca), Vector3(thick, a, width * 0.5 + ca),
				Vector3(thick, b, width * 0.5 + cb), Vector3(-thick, b, width * 0.5 + cb), Vector3.BACK, WORN)
	var c := 0.05 if curved else 0.0
	var top := y0 + body
	var point := Vector3(0, y0 + length, width * 0.35 + c + (0.02 if curved else 0.0))
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.tri_o(Vector3(x * thick, top, width * 0.5 + c), point, Vector3(0, top, -width * 0.5 + c), Vector3(x, 0, -0.2), st)
	k.tri_o(Vector3(-thick, top, width * 0.5 + c), Vector3(thick, top, width * 0.5 + c), point, Vector3.BACK, WORN)
	k.quad_o(Vector3(-thick, y0, width * 0.5), Vector3(thick, y0, width * 0.5), Vector3(0, y0, -width * 0.5), Vector3(0, y0, -width * 0.5), Vector3.DOWN, st)
