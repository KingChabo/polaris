class_name ItemMesh
## A small 3D model of every item, used for the pictures in the backpack, at the trader and on
## the HUD. Models face +Z, stand on y = 0 and are sized freely: the picture is fitted to them.
## Weapons come from WeaponMesh; here are clothes, food, tools, parts, ammunition.

const COAT := {
	"light_jacket": ["khaki", "", false], "parka": ["navy_coat", "fur_brown", true],
	"expedition_suit": ["orange_coat", "fur", true], "frost_pelt": ["pelt", "pelt", true], "grey_pelt": ["fur", "fur", true],
	"commander_coat": ["navy", "fur_dark", false],
}


static func build(id: String) -> Node3D:
	if Weapons.GUNS.has(id) or Weapons.MELEE.has(id):
		var w := Weapons.model(id, [])
		var holder := Node3D.new()
		holder.add_child(w)
		if Weapons.MELEE.has(id):
			w.rotation = Vector3(0, PI * 0.5, -0.85)       # blade up to the right
		else:
			w.rotation = Vector3(0.0, -PI * 0.5 - 0.3, 0.0)   # muzzle to the right, turned a little towards you
			holder.rotation.z = 0.7 if float(Weapons.GUNS[id].get("vel", 0)) > 500.0 else 0.3
		return holder
	var k := MeshKit.new()
	k.winter = true
	var it := Items.get_item(id)
	match str(it.get("slot", "")):
		"head":
			_head(k, id)
		"body":
			_coat(k, id)
		"legs":
			_legs(k, id)
		"feet":
			_boots(k, id)
		"hands":
			_gloves(k, id)
		"armor":
			_vest(k, id)
		"pack":
			_pack(k, id)
		_:
			if it.has("ammo") or id in ["9mm", "9mm_ap", "357", "556", "556_ap", "762", "762_ap", "338", "12g", "12g_slug", "flare"]:
				_ammo(k, id)
			else:
				_thing(k, id)
	return k.node(false)


static func _ring(k: MeshKit, c: Vector3, r: float, thick: float, mat: String, n := 16, squash := 1.0, tilt := Basis.IDENTITY) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		k.tube(c + tilt * Vector3(cos(a0) * r, 0, sin(a0) * r * squash), c + tilt * Vector3(cos(a1) * r, 0, sin(a1) * r * squash), thick, mat, 6)


static func _head(k: MeshKit, id: String) -> void:
	match id:
		"helmet":
			k.ball(Vector3(0, 0.1, 0), Vector3(0.13, 0.115, 0.15), "olive_in", 18, 9)
			k.cyl(Vector3(0, 0.055, 0), 0.146, 0.022, "olive_in", 18, 0.14)
			k.box(Vector3(0, 0.1, 0), Vector3(0.275, 0.02, 0.02), "kevlar_in")
			for sx: float in [-1.0, 1.0]:
				k.tube(Vector3(sx * 0.12, 0.06, 0.0), Vector3(sx * 0.07, -0.05, 0.03), 0.008, "leather_in", 5)
			k.tube(Vector3(-0.07, -0.05, 0.03), Vector3(0.07, -0.05, 0.03), 0.008, "leather_in", 5)
		"fur_hood":
			k.ball(Vector3(0, 0.12, -0.02), Vector3(0.14, 0.16, 0.15), "tan_coat_in", 16, 9)
			for i in 14:
				var a := -0.5 + PI * 2.0 * i / 14.0
				k.sphere(Vector3(cos(a) * 0.115, 0.12 + sin(a) * 0.13, 0.1), 0.043, "fur_brown_in", 8, 5)
			k.ball(Vector3(0, 0.12, 0.06), Vector3(0.09, 0.105, 0.03), "black_in", 12, 6)
		_:
			k.ball(Vector3(0, 0.09, 0), Vector3(0.115, 0.125, 0.115), "wool_red_in", 16, 9)
			k.cyl(Vector3(0, 0.0, 0), 0.122, 0.07, "wool_white_in", 18, 0.12)
			for i in 18:
				var a := TAU * i / 18.0
				k.tube(Vector3(cos(a) * 0.124, 0.003, sin(a) * 0.124), Vector3(cos(a) * 0.122, 0.068, sin(a) * 0.122), 0.007, "wool_white_in", 4)
			k.sphere(Vector3(0, 0.235, 0), 0.042, "wool_white_in", 10, 6)


static func _coat(k: MeshKit, id: String) -> void:
	var d: Array = COAT.get(id, ["khaki", "", false])
	var m: String = str(d[0]) + "_in"
	var fur: String = str(d[1])
	var puffy: bool = d[2]
	var long := id == "commander_coat"
	var r := 0.02 if puffy else 0.0
	var hem := -0.42 if long else -0.3
	# body: chest, waist, skirt
	k.ball(Vector3(0, 0.12, 0), Vector3(0.2 + r, 0.2, 0.115 + r), m, 16, 8)
	k.cyl(Vector3(0, hem, 0), 0.185 + r, 0.36 - hem - 0.3 + 0.02, m, 16, 0.19 + r)
	k.ball(Vector3(0, -0.02, 0), Vector3(0.195 + r, 0.2, 0.11 + r), m, 16, 8)
	# sleeves hang a little away from the body
	for sx: float in [-1.0, 1.0]:
		k.sphere(Vector3(sx * 0.2, 0.21, 0), 0.075 + r, m, 10, 6)
		k.capsule(Vector3(sx * 0.215, 0.2, 0), Vector3(sx * 0.3, -0.02, 0.01), 0.066 + r, m, 10, 0.058 + r)
		k.capsule(Vector3(sx * 0.3, -0.02, 0.01), Vector3(sx * 0.325, -0.22, 0.03), 0.058 + r, m, 10, 0.05 + r)
		k.cyl(Vector3(sx * 0.325, -0.27, 0.03), 0.052 + r, 0.05, ("fur_in" if fur == "pelt" else "kevlar_in"), 10)
	# front: zip or buttons, pockets
	if long:
		k.box(Vector3(0.03, -0.05, 0.118), Vector3(0.012, 0.7, 0.01), "black_in")
		for i in 5:
			for sx: float in [-1.0, 1.0]:
				k.cyl(Vector3(0.03 + sx * 0.055, 0.2 - i * 0.11, 0.115), 0.014, 0.012, "brass", 8, -1.0, true)
		for sx: float in [-1.0, 1.0]:
			k.bbox(Vector3(sx * 0.165, 0.305, 0.0), Vector3(0.1, 0.022, 0.07), 0.008, "red_in")
	else:
		k.box(Vector3(0, -0.01, 0.121 + r), Vector3(0.014, 0.6, 0.008), "tin_in")
		k.box(Vector3(0, 0.27, 0.126 + r), Vector3(0.016, 0.03, 0.008), "tin_in")
	for sx: float in [-1.0, 1.0]:
		k.bbox(Vector3(sx * 0.1, -0.16, 0.112 + r), Vector3(0.11, 0.1, 0.02), 0.008, m)
		k.bbox(Vector3(sx * 0.1, -0.105, 0.118 + r), Vector3(0.115, 0.03, 0.02), 0.008, m)
	# collar or hood
	if fur != "":
		for i in 12:
			var a := PI * i / 11.0
			k.sphere(Vector3(cos(a) * 0.105, 0.325, -sin(a) * 0.08 + 0.03), 0.046, fur + "_in", 8, 5)
		k.ball(Vector3(0, 0.36, -0.07), Vector3(0.1, 0.1, 0.07), m, 12, 6)
	else:
		for sx: float in [-1.0, 1.0]:
			k.bbox(Vector3(sx * 0.055, 0.315, 0.06), Vector3(0.1, 0.05, 0.03), 0.01, m, Basis(Vector3(0, 0, 1), sx * -0.5))
		k.cyl(Vector3(0, 0.29, -0.01), 0.075, 0.06, m, 12, 0.07)


static func _legs(k: MeshKit, id: String) -> void:
	var snow := id == "snow_pants"
	var m := "navy_coat_in" if snow else "denim_in"
	var r := 0.02 if snow else 0.0
	k.cyl(Vector3(0, 0.3, 0), 0.165 + r, 0.07, m, 16, 0.16 + r)
	k.ball(Vector3(0, 0.26, 0), Vector3(0.17 + r, 0.12, 0.105 + r), m, 16, 7)
	for sx: float in [-1.0, 1.0]:
		k.capsule(Vector3(sx * 0.085, 0.2, 0), Vector3(sx * 0.1, -0.12, 0.01), 0.082 + r, m, 12, 0.068 + r)
		k.capsule(Vector3(sx * 0.1, -0.12, 0.01), Vector3(sx * 0.115, -0.46, 0.0), 0.068 + r, m, 12, 0.062 + r)
		if snow:
			k.cyl(Vector3(sx * 0.115, -0.5, 0.0), 0.085, 0.05, "kevlar_in", 12)
			k.tube(Vector3(sx * 0.07, 0.36, 0.09), Vector3(sx * 0.09, 0.62, 0.02), 0.014, "kevlar_in", 6)
		else:
			k.bbox(Vector3(sx * 0.085, 0.24, 0.1), Vector3(0.085, 0.07, 0.012), 0.006, m)
			k.cyl(Vector3(sx * 0.12, 0.275, 0.108), 0.006, 0.006, "copper", 6)
	# belt, button, fly
	k.cyl(Vector3(0, 0.345, 0), 0.168 + r, 0.035, "leather_in" if not snow else "kevlar_in", 16)
	k.bbox(Vector3(0, 0.362, 0.168 + r), Vector3(0.05, 0.04, 0.012), 0.005, "brass")
	k.box(Vector3(0.012, 0.25, 0.108 + r), Vector3(0.006, 0.14, 0.006), "black_in")


static func _boots(k: MeshKit, id: String) -> void:
	var fur := id == "fur_boots"
	var m := "tan_in" if fur else "leather_in"
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.13
		var z := sx * -0.05
		k.cyl(Vector3(x, 0.07, z - 0.05), 0.062, 0.24, m, 12, 0.066)
		k.ball(Vector3(x, 0.07, z + 0.03), Vector3(0.066, 0.06, 0.14), m, 12, 7)
		k.ball(Vector3(x, 0.06, z + 0.115), Vector3(0.062, 0.05, 0.062), m, 10, 6)
		k.bbox(Vector3(x, 0.014, z + 0.03), Vector3(0.14, 0.03, 0.3), 0.012, "tar_in")
		k.bbox(Vector3(x, 0.006, z - 0.08), Vector3(0.13, 0.03, 0.09), 0.01, "tar_in")
		if fur:
			for i in 9:
				var a := TAU * i / 9.0
				k.sphere(Vector3(x + cos(a) * 0.06, 0.31, z - 0.05 + sin(a) * 0.06), 0.032, "fur_in", 7, 4)
			k.tube(Vector3(x - 0.07, 0.16, z - 0.03), Vector3(x + 0.07, 0.16, z - 0.03), 0.012, "leather_in", 6)
		else:
			k.cyl(Vector3(x, 0.3, z - 0.05), 0.07, 0.022, "wood_dark_in", 12)
			for i in 5:
				k.tube(Vector3(x - 0.028, 0.12 + i * 0.034, z + 0.012 - i * 0.004), Vector3(x + 0.028, 0.137 + i * 0.034, z + 0.012 - i * 0.004), 0.005, "cream_in", 4)
				for q: float in [-1.0, 1.0]:
					k.cyl(Vector3(x + q * 0.03, 0.118 + i * 0.034, z + 0.012 - i * 0.004), 0.007, 0.006, "brass", 6)


static func _gloves(k: MeshKit, id: String) -> void:
	var mit := id == "mittens"
	var m := "wool_red_in" if mit else "leather_in"
	for sx: float in [-1.0, 1.0]:
		var o := Vector3(sx * 0.1, 0.0, 0.0)
		var b := Basis(Vector3(0, 0, 1), sx * -0.22)
		k.ball(o + b * Vector3(0, 0.14, 0), Vector3(0.062, 0.085, 0.032 if not mit else 0.045), m, 12, 7, b)
		k.cyl(o + b * Vector3(0, -0.02, 0), 0.05, 0.1, ("wool_white_in" if mit else m), 12, 0.056)
		if mit:
			k.ball(o + b * Vector3(0, 0.225, 0), Vector3(0.06, 0.07, 0.044), m, 12, 7, b)
		else:
			for i in 4:
				var fx := -0.042 + i * 0.028
				var fl: float = [0.09, 0.105, 0.1, 0.08][i]
				k.capsule(o + b * Vector3(fx, 0.2, 0), o + b * Vector3(fx * 1.15, 0.2 + fl, 0), 0.0135, m, 7, 0.011)
			k.cyl(o + b * Vector3(0, -0.025, 0), 0.058, 0.02, "kevlar_in", 12)
		k.capsule(o + b * Vector3(sx * 0.055, 0.1, 0.005), o + b * Vector3(sx * 0.1, 0.17, 0.01), 0.018 if not mit else 0.026, m, 7, 0.014 if not mit else 0.022)


static func _vest(k: MeshKit, id: String) -> void:
	var m := "kevlar_in"
	var plate := id != "kevlar_vest"
	if id == "plate_carrier":
		m = "tan_in"
	elif id == "plate_harness":
		m = "leather_in"
	k.bbox(Vector3(0, 0.0, 0.05), Vector3(0.36, 0.42, 0.07), 0.03, m)
	k.bbox(Vector3(0, 0.0, -0.06), Vector3(0.36, 0.44, 0.06), 0.03, m)
	for sx: float in [-1.0, 1.0]:
		k.bbox(Vector3(sx * 0.12, 0.25, 0.0), Vector3(0.075, 0.1, 0.16), 0.02, m)
		k.bbox(Vector3(sx * 0.19, -0.05, 0.0), Vector3(0.03, 0.2, 0.13), 0.01, m)
	if id == "plate_harness":
		k.bbox(Vector3(0, 0.02, 0.095), Vector3(0.3, 0.34, 0.03), 0.02, "rust_in")
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				k.cyl(Vector3(sx * 0.12, 0.02 + sy * 0.13, 0.108), 0.012, 0.01, "steel_clean_in", 8, -1.0, true)
		k.box(Vector3(0, 0.02, 0.112), Vector3(0.2, 0.05, 0.006), "hazard_in")
	else:
		if plate:
			k.bbox(Vector3(0, 0.05, 0.092), Vector3(0.27, 0.27, 0.025), 0.02, m)
		for i in 3:
			var px := -0.11 + i * 0.11
			k.bbox(Vector3(px, -0.12, 0.105 if plate else 0.092), Vector3(0.09, 0.13, 0.04), 0.012, m)
			k.bbox(Vector3(px, -0.07, 0.125 if plate else 0.112), Vector3(0.092, 0.04, 0.012), 0.005, m)
			k.cyl(Vector3(px, -0.085, 0.128 if plate else 0.115), 0.008, 0.008, "black_in", 6)
		for i in 3:
			k.box(Vector3(0, 0.1 + i * 0.045, 0.108 if plate else 0.09), Vector3(0.24, 0.016, 0.006), "black_in")


static func _pack(k: MeshKit, id: String) -> void:
	var big := id == "large_pack"
	var m := "orange_coat_in" if big else "canvas_in"
	var h := 0.56 if big else 0.4
	var w := 0.32 if big else 0.28
	k.bbox(Vector3(0, h * 0.5, 0), Vector3(w, h, 0.2), 0.06, m)
	k.bbox(Vector3(0, h * 0.34, 0.11), Vector3(w * 0.72, h * 0.42, 0.07), 0.03, m)
	k.bbox(Vector3(0, h * 0.98, 0.015), Vector3(w * 1.04, 0.09, 0.24), 0.035, m)
	for sx: float in [-1.0, 1.0]:
		k.tube(Vector3(sx * w * 0.3, h * 1.0, 0.13), Vector3(sx * w * 0.3, h * 0.72, 0.135), 0.011, "kevlar_in", 5)
		k.bbox(Vector3(sx * w * 0.3, h * 0.72, 0.138), Vector3(0.035, 0.03, 0.012), 0.004, "black_in")
		k.bbox(Vector3(sx * (w * 0.5 + 0.03), h * 0.3, 0.0), Vector3(0.06, h * 0.36, 0.13), 0.025, m)
		for i in 6:
			var t0 := i / 6.0
			var t1 := (i + 1) / 6.0
			k.tube(Vector3(sx * w * 0.32, h * (0.92 - t0 * 0.8), -0.1 - sin(t0 * PI) * 0.07), Vector3(sx * w * 0.32, h * (0.92 - t1 * 0.8), -0.1 - sin(t1 * PI) * 0.07), 0.02, "kevlar_in", 6)
	k.box(Vector3(0, h * 0.5, 0.147), Vector3(w * 0.5, 0.008, 0.006), "tin_in")
	if big:
		k.capsule(Vector3(-w * 0.55, h * 1.1, 0.0), Vector3(w * 0.55, h * 1.1, 0.0), 0.06, "navy_coat_in", 10)
		for sx: float in [-0.5, 0.5]:
			k.cyl(Vector3(sx * w * 0.6, h * 1.035, 0.0), 0.064, 0.02, "black_in", 10, -1.0, true)


static func _round(k: MeshKit, at: Vector3, r: float, case_h: float, tip_h: float, tip := "copper", neck := 1.0, basis := Basis.IDENTITY) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(basis, at)
	k.cyl(Vector3.ZERO, r * 1.06, r * 0.22, "brass", 12)
	k.cyl(Vector3(0, r * 0.22, 0), r * 0.9, r * 0.14, "brass", 12)
	k.cyl(Vector3(0, r * 0.36, 0), r, case_h, "brass", 12)
	var y := r * 0.36 + case_h
	if neck < 1.0:
		k.cyl(Vector3(0, y, 0), r, r * 0.5, "brass", 12, r * neck)
		y += r * 0.5
		k.cyl(Vector3(0, y, 0), r * neck, r * 0.7, "brass", 12)
		y += r * 0.7
	var tr := r * neck * 0.96
	k.cyl(Vector3(0, y, 0), tr, tip_h * 0.45, tip, 12, tr * 0.82)
	k.cyl(Vector3(0, y + tip_h * 0.45, 0), tr * 0.82, tip_h * 0.35, tip, 12, tr * 0.45)
	k.ball(Vector3(0, y + tip_h * 0.8, 0), Vector3(tr * 0.45, tip_h * 0.2, tr * 0.45), tip, 10, 5)
	k.xf = xf


static func _shell(k: MeshKit, at: Vector3, r: float, h: float, hull: String, basis := Basis.IDENTITY) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(basis, at)
	k.cyl(Vector3.ZERO, r * 1.08, r * 0.2, "brass", 14)
	k.cyl(Vector3(0, r * 0.2, 0), r, h * 0.28, "brass", 14)
	k.cyl(Vector3(0, r * 0.2 + h * 0.28, 0), r * 0.98, h * 0.68, hull, 14)
	k.cyl(Vector3(0, r * 0.2 + h * 0.96, 0), r * 0.98, h * 0.04, hull, 14, r * 0.8)
	k.xf = xf


static func _ammo(k: MeshKit, id: String) -> void:
	var lay := Basis(Vector3(0, 0, 1), -PI * 0.5) * Basis(Vector3(0, 1, 0), 0.0)
	match id:
		"12g", "12g_slug":
			var hull := "red_in" if id == "12g" else "green_in"
			_shell(k, Vector3(-0.03, 0, 0.0), 0.021, 0.14, hull)
			_shell(k, Vector3(0.022, 0, -0.012), 0.021, 0.14, hull)
			_shell(k, Vector3(-0.06, 0.021, 0.06), 0.021, 0.14, hull, Basis(Vector3(0, 1, 0), 0.5) * lay)
		"flare":
			_shell(k, Vector3(-0.02, 0, 0), 0.03, 0.17, "orange_in")
			_shell(k, Vector3(-0.07, 0.03, 0.08), 0.03, 0.17, "orange_in", Basis(Vector3(0, 1, 0), 0.4) * lay)
		_:
			var r := 0.012
			var ch := 0.04
			var th := 0.03
			var neck := 1.0
			match id.trim_suffix("_ap"):
				"357":
					r = 0.013
					ch = 0.07
					th = 0.03
				"556":
					r = 0.011
					ch = 0.085
					th = 0.05
					neck = 0.62
				"762":
					r = 0.0135
					ch = 0.1
					th = 0.06
					neck = 0.66
				"338":
					r = 0.017
					ch = 0.14
					th = 0.075
					neck = 0.6
			var tip := "black_in" if id.ends_with("_ap") else ("tin_in" if id == "357" else "copper")
			for i in 4:
				_round(k, Vector3(-r * 3.3 + i * r * 2.2, 0, -absf(i - 1.5) * r * 0.8), r, ch, th, tip, neck)
			_round(k, Vector3(-r * 3.0, r * 1.06, r * 5.0), r, ch, th, tip, neck, Basis(Vector3(0, 1, 0), 0.35) * lay)


static func _key(k: MeshKit, head: String, tag: String) -> void:
	var b := Basis(Vector3(0, 0, 1), -0.6)
	_ring(k, b * Vector3(0, 0.1, 0), 0.05, 0.012, head, 14, 1.0, b * Basis(Vector3(1, 0, 0), PI * 0.5))
	k.tube(b * Vector3(0, 0.05, 0), b * Vector3(0, -0.16, 0), 0.011, head, 8)
	for i in 3:
		k.box(b * Vector3(0.018, -0.1 - i * 0.022, 0), Vector3(0.03 - i * 0.006, 0.012, 0.01), head, b)
	_ring(k, b * Vector3(0, 0.17, 0), 0.03, 0.004, "tin_in", 10, 1.0, b * Basis(Vector3(0, 0, 1), PI * 0.5))
	k.bbox(Vector3(-0.11, 0.1, 0.0), Vector3(0.1, 0.15, 0.012), 0.02, tag, Basis(Vector3(0, 0, 1), 0.5))
	k.box(Vector3(-0.11, 0.1, 0.008), Vector3(0.06, 0.04, 0.004), "paper_in", Basis(Vector3(0, 0, 1), 0.5))


static func _thing(k: MeshKit, id: String) -> void:
	match id:
		"canned_food":
			k.cyl(Vector3.ZERO, 0.075, 0.2, "tin_in", 20)
			k.cyl(Vector3(0, 0.03, 0), 0.0765, 0.14, "red_in", 20)
			k.cyl(Vector3(0, 0.075, 0), 0.077, 0.05, "cream_in", 20)
			for y: float in [0.0, 0.195]:
				k.cyl(Vector3(0, y, 0), 0.078, 0.008, "tin_in", 20)
			_ring(k, Vector3(0.02, 0.208, 0.02), 0.022, 0.004, "tin_in", 10)
		"hot_tea":
			k.cyl(Vector3.ZERO, 0.055, 0.26, "olive_in", 18)
			k.cyl(Vector3(0, 0.26, 0), 0.055, 0.02, "tin_in", 18, 0.045)
			k.cyl(Vector3(0, 0.28, 0), 0.047, 0.075, "tin_in", 18, 0.044)
			for y: float in [0.03, 0.22]:
				k.cyl(Vector3(0, y, 0), 0.0565, 0.012, "tin_in", 18)
			k.bbox(Vector3(0.075, 0.14, 0), Vector3(0.016, 0.13, 0.03), 0.006, "black_in")
			for y: float in [0.085, 0.195]:
				k.box(Vector3(0.062, y, 0), Vector3(0.03, 0.016, 0.03), "black_in")
			# the cup beside it, steaming tea inside
			k.cyl(Vector3(-0.14, 0.0, 0.05), 0.04, 0.06, "tin_in", 14, 0.046, false)
			k.cyl(Vector3(-0.14, 0.045, 0.05), 0.041, 0.004, "wood_in", 14)
		"hand_warmer":
			k.bbox(Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.14), 0.045, "orange_in", Basis(Vector3(0, 1, 0), 0.3))
			k.box(Vector3(0, 0.102, 0), Vector3(0.11, 0.004, 0.06), "paper_in", Basis(Vector3(0, 1, 0), 0.3))
			k.box(Vector3(0, 0.105, 0), Vector3(0.07, 0.004, 0.02), "red_in", Basis(Vector3(0, 1, 0), 0.3))
		"bandage":
			var b := Basis(Vector3(1, 0, 0), PI * 0.5) * Basis(Vector3(0, 0, 1), 0.2)
			k.xf = Transform3D(b, Vector3(0, 0.09, 0))
			k.cyl(Vector3(0, -0.06, 0), 0.09, 0.12, "wool_white_in", 20)
			k.cyl(Vector3(0, -0.062, 0), 0.03, 0.124, "paper_in", 12)
			for i in 4:
				k.cyl(Vector3(0, -0.061, 0), 0.045 + i * 0.012, 0.122, "cream_in", 20, -1.0, false)
			k.xf = Transform3D.IDENTITY
			k.box(Vector3(0.13, 0.004, 0.02), Vector3(0.16, 0.006, 0.115), "wool_white_in", Basis(Vector3(0, 1, 0), -0.25))
			k.box(Vector3(0.2, 0.008, 0.035), Vector3(0.012, 0.004, 0.115), "red_in", Basis(Vector3(0, 1, 0), -0.25))
		"medkit":
			k.bbox(Vector3(0, 0.1, 0), Vector3(0.34, 0.2, 0.2), 0.03, "red_in")
			k.box(Vector3(0, 0.1, 0.101), Vector3(0.1, 0.03, 0.004), "white_in")
			k.box(Vector3(0, 0.1, 0.101), Vector3(0.03, 0.1, 0.004), "white_in")
			k.box(Vector3(0, 0.14, 0.0), Vector3(0.345, 0.006, 0.205), "black_in")
			for sx: float in [-1.0, 1.0]:
				k.bbox(Vector3(sx * 0.1, 0.14, 0.104), Vector3(0.035, 0.05, 0.012), 0.004, "tin_in")
				k.tube(Vector3(sx * 0.06, 0.2, 0), Vector3(sx * 0.06, 0.235, 0), 0.008, "black_in", 6)
			k.capsule(Vector3(-0.06, 0.235, 0), Vector3(0.06, 0.235, 0), 0.011, "black_in", 8)
		"splint":
			for sx: float in [-1.0, 1.0]:
				k.bbox(Vector3(sx * 0.045, 0.02, 0), Vector3(0.06, 0.02, 0.5), 0.006, "planks_in", Basis(Vector3(0, 1, 0), 0.5))
			for z: float in [-0.16, 0.0, 0.16]:
				var c := Basis(Vector3(0, 1, 0), 0.5) * Vector3(0, 0.02, z)
				k.bbox(c, Vector3(0.17, 0.034, 0.045), 0.012, "wool_white_in", Basis(Vector3(0, 1, 0), 0.5))
		"painkillers":
			k.cyl(Vector3.ZERO, 0.05, 0.13, "pill_in", 18)
			k.cyl(Vector3(0, 0.13, 0), 0.05, 0.012, "pill_in", 18, 0.04)
			k.cyl(Vector3(0, 0.142, 0), 0.043, 0.04, "white_in", 18)
			for i in 12:
				var a := TAU * i / 12.0
				k.box(Vector3(cos(a) * 0.044, 0.162, sin(a) * 0.044), Vector3(0.006, 0.036, 0.006), "white_in", Basis(Vector3(0, 1, 0), -a))
			k.cyl(Vector3(0, 0.03, 0), 0.051, 0.075, "paper_in", 18)
			k.box(Vector3(0, 0.07, 0.051), Vector3(0.05, 0.016, 0.003), "blue_in")
			for i in 3:
				k.ball(Vector3(0.1 + i * 0.035, 0.008, 0.04 - i * 0.03), Vector3(0.016, 0.008, 0.016), "white_in", 10, 5)
		"scrap":
			k.bbox(Vector3(0, 0.012, 0), Vector3(0.3, 0.02, 0.2), 0.004, "rust_in", Basis(Vector3(0, 1, 0), 0.3))
			# a gear
			k.cyl(Vector3(-0.05, 0.022, 0.03), 0.07, 0.024, "steel_clean_in", 16)
			k.cyl(Vector3(-0.05, 0.02, 0.03), 0.025, 0.03, "black_in", 10)
			for i in 10:
				var a := TAU * i / 10.0
				k.box(Vector3(-0.05 + cos(a) * 0.075, 0.034, 0.03 + sin(a) * 0.075), Vector3(0.026, 0.024, 0.022), "steel_clean_in", Basis(Vector3(0, 1, 0), -a))
			# pipe, bolts, bent strip
			k.tube(Vector3(0.02, 0.05, -0.08), Vector3(0.16, 0.03, 0.06), 0.022, "rust_in", 10)
			k.tube(Vector3(0.02, 0.05, -0.08), Vector3(0.022, 0.05, -0.078), 0.016, "black_in", 8)
			for i in 3:
				var bp := Vector3(0.05 + i * 0.04, 0.022, 0.1 - i * 0.02)
				k.cyl(bp, 0.012, 0.012, "tin_in", 6)
				k.tube(bp + Vector3(0, 0.006, 0), bp + Vector3(0.04, 0.006, 0.02), 0.006, "tin_in", 6)
			k.box(Vector3(-0.1, 0.03, -0.07), Vector3(0.14, 0.006, 0.03), "tin_in", Basis(Vector3(0, 1, 0), 0.8) * Basis(Vector3(0, 0, 1), 0.2))
		"cloth":
			var cols := ["wool_white_in", "check_in", "denim_in", "wool_red_in"]
			for i in 4:
				k.bbox(Vector3(0.005 * (i % 2), 0.025 + i * 0.045, 0.004 * i), Vector3(0.3 - i * 0.012, 0.042, 0.22 - i * 0.01), 0.018, cols[i], Basis(Vector3(0, 1, 0), 0.06 * (i - 1.5)))
		"firewood":
			var lay := Basis(Vector3(1, 0, 0), PI * 0.5)
			for p: Array in [[-0.075, 0.07, 0.0, 0.07], [0.075, 0.07, 0.01, 0.068], [0.0, 0.19, 0.0, 0.066]]:
				var c := Vector3(float(p[0]), float(p[1]), float(p[2]))
				var r := float(p[3])
				k.tube(c + Vector3(0, 0, -0.22), c + Vector3(0, 0, 0.22), r, "wood_in", 12)
				k.tube(c + Vector3(0, 0, 0.215), c + Vector3(0, 0, 0.223), r * 0.92, "tan_in", 12)
				k.tube(c + Vector3(0, 0, 0.221), c + Vector3(0, 0, 0.226), r * 0.5, "planks_in", 10)
				k.tube(c + Vector3(0, 0, 0.224), c + Vector3(0, 0, 0.228), r * 0.18, "wood_dark_in", 8)
			k.tube(Vector3(-0.16, 0.12, 0.08), Vector3(0.16, 0.12, 0.08), 0.008, "cream_in", 6)
		"batteries":
			for sx: float in [-1.0, 1.0]:
				var x := sx * 0.04
				k.cyl(Vector3(x, 0, 0), 0.034, 0.05, "tin_in", 16)
				k.cyl(Vector3(x, 0.05, 0), 0.0345, 0.1, "black_in", 16)
				k.cyl(Vector3(x, 0.15, 0), 0.0345, 0.04, "copper", 16)
				k.cyl(Vector3(x, 0.19, 0), 0.03, 0.006, "tin_in", 16)
				k.cyl(Vector3(x, 0.196, 0), 0.012, 0.012, "tin_in", 10)
				k.box(Vector3(x, 0.1, 0.0345), Vector3(0.02, 0.035, 0.002), "yellow_in")
		"rope":
			for i in 5:
				_ring(k, Vector3(0, 0.02 + i * 0.03, 0), 0.13 - absf(i - 2) * 0.006, 0.02, "tan_in", 20)
			for a: float in [0.6, 3.7]:
				for j in 3:
					k.tube(Vector3(cos(a + j * 0.09) * 0.13, 0.0, sin(a + j * 0.09) * 0.13), Vector3(cos(a + j * 0.09) * 0.13, 0.17, sin(a + j * 0.09) * 0.13), 0.021, "tan_in", 6)
			k.tube(Vector3(0.13, 0.02, 0.0), Vector3(0.24, 0.015, 0.09), 0.019, "tan_in", 8)
		"fuel_can":
			k.bbox(Vector3(0, 0.2, 0), Vector3(0.3, 0.4, 0.14), 0.03, "paint_red_in")
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.05, 0.2, 0.0), Vector3(0.012, 0.3, 0.15), "paint_red_in", Basis(Vector3(0, 0, 1), sx * 0.5))
			for z: float in [-0.04, 0.0, 0.04]:
				k.capsule(Vector3(-0.09, 0.44, z), Vector3(0.03, 0.44, z), 0.012, "paint_red_in", 8)
			for x: float in [-0.09, 0.03]:
				k.box(Vector3(x, 0.415, 0), Vector3(0.016, 0.05, 0.1), "paint_red_in")
			k.cyl(Vector3(0.1, 0.39, 0), 0.03, 0.06, "paint_red_in", 12, 0.026)
			k.cyl(Vector3(0.1, 0.45, 0), 0.032, 0.025, "black_in", 12)
			k.box(Vector3(0.13, 0.47, 0), Vector3(0.05, 0.01, 0.02), "tin_in")
		"coin":
			for i in 7:
				k.cyl(Vector3(sin(i * 1.7) * 0.006, i * 0.014, cos(i * 2.3) * 0.006), 0.06, 0.012, "gold_coin", 20)
			for p: Array in [[0.12, 0.05, 0.3], [-0.11, 0.08, -0.4]]:
				var b := Basis(Vector3(1, 0, 0), 1.25) * Basis(Vector3(0, 0, 1), float(p[2]))
				k.xf = Transform3D(b, Vector3(float(p[0]), 0.058, float(p[1])))
				k.cyl(Vector3(0, -0.006, 0), 0.06, 0.012, "gold_coin", 20)
				k.cyl(Vector3(0, 0.006, 0), 0.042, 0.002, "brass", 16)
				k.xf = Transform3D.IDENTITY
			k.cyl(Vector3(0, 0.098, 0), 0.044, 0.002, "brass", 16)
		"parcel":
			k.bbox(Vector3(0, 0.1, 0), Vector3(0.34, 0.2, 0.26), 0.012, "tan_in")
			k.box(Vector3(0, 0.1, 0), Vector3(0.345, 0.205, 0.012), "cream_in")
			k.box(Vector3(0, 0.1, 0), Vector3(0.012, 0.205, 0.265), "cream_in")
			k.box(Vector3(-0.08, 0.202, 0.06), Vector3(0.12, 0.003, 0.08), "paper_in")
			k.box(Vector3(0.1, 0.202, -0.07), Vector3(0.05, 0.003, 0.06), "red_in")
			k.sphere(Vector3(0, 0.21, 0), 0.016, "cream_in", 8, 5)
		"fuse", "relay_fuse":
			var b := Basis(Vector3(0, 0, 1), -1.2) * Basis(Vector3(0, 1, 0), 0.5)
			k.xf = Transform3D(b, Vector3(0, 0.07, 0))
			k.cyl(Vector3(0, -0.1, 0), 0.04, 0.2, "bone_in", 16)
			for y: float in [-0.13, 0.1]:
				k.cyl(Vector3(0, y, 0), 0.043, 0.035, "copper", 16)
			k.box(Vector3(0, 0, 0.04), Vector3(0.03, 0.09, 0.003), "paper_in")
			k.cyl(Vector3(0, -0.14, 0), 0.012, 0.012, "copper", 8)
			k.xf = Transform3D.IDENTITY
		"core_heart":
			for i in 7:
				var a := TAU * i / 7.0
				var b := Basis(Vector3(cos(a), 0, sin(a)), 0.55 + (i % 3) * 0.2)
				k.cyl(b * Vector3(0, 0.02, 0) + Vector3(0, 0.12, 0), 0.03, 0.16 + (i % 2) * 0.05, "ice", 6, 0.004)
				k.cyl(b * Vector3(0, -0.02, 0) + Vector3(0, 0.12, 0), 0.004, 0.04, "ice", 6, 0.03)
			k.cyl(Vector3(0, 0.1, 0), 0.05, 0.24, "ice", 6, 0.006)
			k.sphere(Vector3(0, 0.13, 0), 0.07, "heart_glow", 14, 8)
		"blasting_charge":
			for i in 4:
				k.capsule(Vector3(-0.09 + i * 0.06, 0.03, -0.12), Vector3(-0.09 + i * 0.06, 0.03, 0.12), 0.028, "red_in", 10)
			for z: float in [-0.07, 0.07]:
				k.box(Vector3(0, 0.03, z), Vector3(0.26, 0.064, 0.02), "black_in")
			k.tube(Vector3(0.0, 0.06, 0.12), Vector3(0.1, 0.12, 0.22), 0.006, "cream_in", 5)
			k.tube(Vector3(0.1, 0.12, 0.22), Vector3(0.02, 0.02, 0.3), 0.006, "cream_in", 5)
		"rotor_hub":
			k.cyl(Vector3(0, 0, 0), 0.1, 0.1, "steel_clean_in", 18)
			k.cyl(Vector3(0, 0.1, 0), 0.05, 0.12, "gunmetal_in", 14)
			for i in 3:
				var a := i * TAU / 3.0
				k.tube(Vector3(cos(a) * 0.08, 0.05, sin(a) * 0.08), Vector3(cos(a) * 0.24, 0.05, sin(a) * 0.24), 0.028, "steel_clean_in", 8)
				k.cyl(Vector3(cos(a) * 0.24, 0.02, sin(a) * 0.24), 0.036, 0.06, "gunmetal_in", 10)
			k.cyl(Vector3(0, 0.22, 0), 0.07, 0.015, "paint_red", 14)
		"flight_manifest", "dead_letter":
			k.box(Vector3(0, 0.004, 0), Vector3(0.21, 0.006, 0.3), "paper_in")
			if id == "dead_letter":
				k.box(Vector3(0.06, 0.008, -0.1), Vector3(0.04, 0.002, 0.05), "red_in")
				k.box(Vector3(-0.02, 0.008, 0.03), Vector3(0.1, 0.002, 0.008), "black_in")
			else:
				k.box(Vector3(0, 0.008, -0.11), Vector3(0.17, 0.002, 0.03), "navy_in")
				for i in 6:
					k.box(Vector3(0, 0.008, -0.06 + i * 0.033), Vector3(0.17, 0.002, 0.003), "black_in")
				k.box(Vector3(0, 0.012, -0.15), Vector3(0.1, 0.012, 0.02), "tin_in")
		"wolf_pelt":
			k.ball(Vector3(0, 0.03, 0), Vector3(0.2, 0.035, 0.3), "fur_dark", 12, 5)
			k.ball(Vector3(0, 0.035, -0.3), Vector3(0.08, 0.03, 0.09), "fur_dark", 8, 4)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-0.2, 0.2]:
					k.ball(Vector3(sx * 0.22, 0.02, sz), Vector3(0.08, 0.02, 0.05), "fur_dark", 8, 4)
			k.ball(Vector3(0, 0.03, 0.34), Vector3(0.035, 0.025, 0.1), "fur", 8, 4)
		"hollow_ash":
			k.cyl(Vector3(0, 0, 0), 0.05, 0.11, "glass_dark", 14)
			k.cyl(Vector3(0, 0.005, 0), 0.044, 0.07, "grey_in", 12)
			k.cyl(Vector3(0, 0.11, 0), 0.036, 0.03, "tin_in", 12)
		"bounty_tag":
			k.box(Vector3(0, 0.004, 0), Vector3(0.16, 0.006, 0.07), "red_in")
			k.box(Vector3(-0.02, 0.008, 0), Vector3(0.07, 0.002, 0.03), "black_in")
			k.cyl(Vector3(0.065, 0.0, 0), 0.008, 0.012, "tin_in", 8)
			k.tube(Vector3(0.065, 0.008, 0), Vector3(0.14, 0.008, 0.04), 0.003, "cream_in", 4)
		"supply_crate":
			k.bbox(Vector3(0, 0.13, 0), Vector3(0.42, 0.26, 0.3), 0.012, "planks_in")
			for x: float in [-0.14, 0.14]:
				k.box(Vector3(x, 0.13, 0), Vector3(0.03, 0.27, 0.31), "tin_in")
			k.box(Vector3(0, 0.13, 0.152), Vector3(0.12, 0.08, 0.004), "paper_in")
		"medicine_crate":
			k.bbox(Vector3(0, 0.12, 0), Vector3(0.4, 0.24, 0.28), 0.012, "paint_white_in")
			for y: float in [0.04, 0.2]:
				k.box(Vector3(0, y, 0), Vector3(0.41, 0.03, 0.29), "tin_in")
			k.box(Vector3(0, 0.12, 0.141), Vector3(0.1, 0.035, 0.004), "green_in")
			k.box(Vector3(0, 0.12, 0.141), Vector3(0.035, 0.1, 0.004), "green_in")
			for sx: float in [-1.0, 1.0]:
				k.capsule(Vector3(sx * 0.205, 0.15, -0.05), Vector3(sx * 0.205, 0.15, 0.05), 0.012, "black_in", 6)
				k.bbox(Vector3(sx * 0.13, 0.2, 0.143), Vector3(0.04, 0.05, 0.01), 0.004, "tin_in")
		"crowbar":
			var b := Basis(Vector3(0, 0, 1), -0.9)
			k.tube(b * Vector3(0, -0.3, 0), b * Vector3(0, 0.24, 0), 0.016, "paint_blue_in", 6)
			for i in 5:
				var a0 := i * 0.42
				var a1 := (i + 1) * 0.42
				k.tube(b * Vector3(0.06 - cos(a0) * 0.06, 0.24 + sin(a0) * 0.06, 0), b * Vector3(0.06 - cos(a1) * 0.06, 0.24 + sin(a1) * 0.06, 0), 0.016, "paint_blue_in", 6)
			k.box(b * Vector3(0.118, 0.215, 0), Vector3(0.012, 0.07, 0.04), "steel_clean_in", b * Basis(Vector3(0, 0, 1), 0.25))
			k.box(b * Vector3(0.01, -0.33, 0), Vector3(0.01, 0.07, 0.038), "steel_clean_in", b * Basis(Vector3(0, 0, 1), 0.3))
		"bolt_cutters":
			for sx: float in [-1.0, 1.0]:
				var b := Basis(Vector3(0, 0, 1), sx * 0.16)
				k.tube(b * Vector3(sx * 0.012, -0.36, 0), b * Vector3(sx * 0.012, -0.02, 0), 0.014, "steel_clean_in", 8)
				k.capsule(b * Vector3(sx * 0.012, -0.37, 0), b * Vector3(sx * 0.012, -0.17, 0), 0.02, "red_in", 8)
				k.bbox(Vector3(sx * 0.022, 0.05, 0), Vector3(0.04, 0.1, 0.024), 0.008, "black_in", Basis(Vector3(0, 0, 1), sx * -0.18))
				k.box(Vector3(sx * 0.014, 0.1, 0), Vector3(0.022, 0.05, 0.012), "chrome", Basis(Vector3(0, 0, 1), sx * -0.3))
			k.cyl(Vector3(0, 0.0, -0.016), 0.02, 0.032, "tin_in", 10)
			k.xf = Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3.ZERO)
			k.cyl(Vector3(0, -0.02, 0), 0.016, 0.04, "tin_in", 6)
			k.xf = Transform3D.IDENTITY
		"key_mine":
			_key(k, "brass", "yellow_in")
		"key_bunker":
			_key(k, "tin_in", "olive_in")
		"key_armory":
			_key(k, "chrome", "red_in")
		"keycard_lab":
			var b := Basis(Vector3(1, 0, 0), -0.3) * Basis(Vector3(0, 0, 1), 0.25)
			k.bbox(Vector3(0, 0.1, 0), Vector3(0.3, 0.19, 0.008), 0.02, "white_in", b)
			k.box(b * Vector3(0, 0.055, 0.005) + Vector3(0, 0.1, 0), Vector3(0.3, 0.05, 0.002), "teal_in", b)
			k.box(b * Vector3(-0.085, -0.02, 0.005) + Vector3(0, 0.1, 0), Vector3(0.08, 0.09, 0.002), "grey_in", b)
			k.box(b * Vector3(0.09, -0.01, 0.005) + Vector3(0, 0.1, 0), Vector3(0.05, 0.04, 0.002), "gold_coin", b)
			for i in 3:
				k.box(b * Vector3(0.05, -0.05 - i * 0.012, 0.005) + Vector3(0, 0.1, 0), Vector3(0.13, 0.005, 0.002), "black_in", b)
			k.box(b * Vector3(0, 0.115, 0) + Vector3(0, 0.1, 0), Vector3(0.05, 0.04, 0.012), "tin_in", b)
			k.tube(b * Vector3(0, 0.13, 0) + Vector3(0, 0.1, 0), b * Vector3(-0.03, 0.26, 0) + Vector3(0, 0.1, 0), 0.006, "blue_in", 5)
		"snow_chains":
			for i in 12:
				var a := TAU * i / 12.0
				var c := Vector3(cos(a) * 0.16, 0.02 + (i % 2) * 0.012, sin(a) * 0.11)
				_ring(k, c, 0.03, 0.007, "tin_in", 8, 0.6, Basis(Vector3(0, 1, 0), -a + PI * 0.5) * Basis(Vector3(1, 0, 0), (i % 2) * 1.2))
			for i in 5:
				var c := Vector3(-0.1 + i * 0.05, 0.03 + (i % 2) * 0.012, -0.1 + i * 0.05)
				_ring(k, c, 0.03, 0.007, "tin_in", 8, 0.6, Basis(Vector3(0, 1, 0), -0.8) * Basis(Vector3(1, 0, 0), (i % 2) * 1.2))
			k.capsule(Vector3(0.16, 0.03, 0.0), Vector3(0.22, 0.03, 0.03), 0.012, "red_in", 6)
		"armor_plates":
			for i in 2:
				var b := Basis(Vector3(0, 1, 0), 0.25 + i * 0.3) * Basis(Vector3(1, 0, 0), -0.25 - i * 0.2)
				k.bbox(Vector3(-0.05 + i * 0.1, 0.16 - i * 0.02, -0.04 + i * 0.09), Vector3(0.26, 0.32, 0.018), 0.012, "steel_clean_in", b)
				for sx: float in [-1.0, 1.0]:
					for sy: float in [-1.0, 1.0]:
						k.cyl(Vector3(-0.05 + i * 0.1, 0.16 - i * 0.02, -0.04 + i * 0.09) + b * Vector3(sx * 0.1, sy * 0.13, 0.008), 0.009, 0.008, "black_in", 6)
		"aux_tank":
			var b := Basis(Vector3(0, 0, 1), PI * 0.5)
			k.xf = Transform3D(b, Vector3(0, 0.12, 0))
			k.cyl(Vector3(0, -0.2, 0), 0.115, 0.4, "olive_in", 20)
			for y: float in [-0.21, 0.19]:
				k.ball(Vector3(0, y + 0.01, 0), Vector3(0.113, 0.03, 0.113), "olive_in", 18, 6)
			for y: float in [-0.12, 0.1]:
				k.cyl(Vector3(0, y, 0), 0.12, 0.02, "black_in", 20)
			k.xf = Transform3D.IDENTITY
			k.cyl(Vector3(-0.08, 0.23, 0), 0.025, 0.04, "tin_in", 10)
			k.cyl(Vector3(-0.08, 0.27, 0), 0.03, 0.016, "yellow_in", 10)
			for i in 5:
				k.tube(Vector3(0.1 + i * 0.03, 0.23 - i * i * 0.012, 0.02 * i), Vector3(0.13 + i * 0.03, 0.23 - (i + 1) * (i + 1) * 0.012, 0.02 * (i + 1)), 0.012, "black_in", 6)
		"winch_kit":
			var b := Basis(Vector3(0, 0, 1), PI * 0.5)
			k.xf = Transform3D(b, Vector3(0, 0.11, 0))
			k.cyl(Vector3(0, -0.1, 0), 0.07, 0.2, "tin_in", 16)
			for i in 9:
				k.cyl(Vector3(0, -0.085 + i * 0.019, 0), 0.078, 0.017, "steel_clean_in", 16)
			for y: float in [-0.115, 0.1]:
				k.cyl(Vector3(0, y, 0), 0.105, 0.016, "black_in", 18)
			k.xf = Transform3D.IDENTITY
			k.bbox(Vector3(0, 0.012, 0), Vector3(0.3, 0.024, 0.2), 0.006, "black_in")
			k.bbox(Vector3(-0.19, 0.11, 0), Vector3(0.12, 0.13, 0.13), 0.02, "paint_red_in")
			k.tube(Vector3(0.05, 0.19, 0.0), Vector3(0.14, 0.05, 0.16), 0.008, "steel_clean_in", 6)
			for i in 6:
				var a0 := -0.4 + i * 0.65
				var a1 := -0.4 + (i + 1) * 0.65
				k.tube(Vector3(0.14 + sin(a0) * 0.035, 0.012, 0.2 - cos(a0) * 0.035), Vector3(0.14 + sin(a1) * 0.035, 0.012, 0.2 - cos(a1) * 0.035), 0.011, "paint_yellow_in", 6)
		"red_dot":
			k.bbox(Vector3(0, 0.02, 0), Vector3(0.05, 0.03, 0.09), 0.006, "black_in")
			k.bbox(Vector3(0, 0.065, -0.02), Vector3(0.052, 0.062, 0.03), 0.01, "black_in")
			k.box(Vector3(0, 0.065, -0.02), Vector3(0.036, 0.044, 0.032), "glass_clear")
			k.sphere(Vector3(0, 0.065, -0.02), 0.004, "led_red", 6, 4)
			k.cyl(Vector3(0.028, 0.02, 0.02), 0.012, 0.012, "tin_in", 8)
			k.bbox(Vector3(0, 0.0, 0), Vector3(0.036, 0.012, 0.07), 0.003, "worn_in")
		"scope":
			var b := Basis(Vector3(1, 0, 0), PI * 0.5)
			k.xf = Transform3D(b, Vector3(0, 0.06, 0))
			k.cyl(Vector3(0, -0.15, 0), 0.02, 0.3, "black_in", 14)
			k.cyl(Vector3(0, -0.2, 0), 0.03, 0.09, "black_in", 14, 0.021)
			k.cyl(Vector3(0, -0.22, 0), 0.031, 0.022, "black_in", 14)
			k.cyl(Vector3(0, 0.1, 0), 0.021, 0.06, "black_in", 14, 0.027)
			k.cyl(Vector3(0, 0.16, 0), 0.028, 0.03, "kevlar_in", 14)
			k.cyl(Vector3(0, -0.221, 0), 0.027, 0.002, "glass_cold", 14)
			k.cyl(Vector3(0, 0.19, 0), 0.024, 0.002, "glass_dark", 14)
			k.xf = Transform3D.IDENTITY
			k.cyl(Vector3(0, 0.08, 0.0), 0.014, 0.022, "tin_in", 10)
			k.cyl(Vector3(0.022, 0.053, 0.0), 0.014, 0.014, "tin_in", 10)
			for z: float in [-0.06, 0.06]:
				k.bbox(Vector3(0, 0.03, z), Vector3(0.03, 0.05, 0.02), 0.004, "worn_in")
		"silencer":
			var b := Basis(Vector3(0, 0, 1), -1.15)
			k.xf = Transform3D(b, Vector3(0, 0.05, 0))
			k.cyl(Vector3(0, -0.13, 0), 0.03, 0.26, "black_in", 16)
			for i in 6:
				k.cyl(Vector3(0, -0.11 + i * 0.012, 0), 0.0315, 0.006, "kevlar_in", 16)
			k.cyl(Vector3(0, 0.13, 0), 0.03, 0.008, "black_in", 16, 0.024)
			k.cyl(Vector3(0, 0.138, 0), 0.01, 0.002, "tar_in", 10)
			k.cyl(Vector3(0, -0.15, 0), 0.02, 0.02, "tin_in", 12)
			k.xf = Transform3D.IDENTITY
		"muzzle_brake":
			var b := Basis(Vector3(0, 0, 1), -1.15)
			k.xf = Transform3D(b, Vector3(0, 0.04, 0))
			k.cyl(Vector3(0, -0.05, 0), 0.024, 0.1, "steel_clean_in", 14)
			k.cyl(Vector3(0, -0.07, 0), 0.018, 0.02, "steel_clean_in", 12)
			for i in 3:
				k.box(Vector3(0, -0.025 + i * 0.026, 0), Vector3(0.05, 0.012, 0.014), "black_in")
			k.cyl(Vector3(0, 0.05, 0), 0.012, 0.002, "tar_in", 10)
			k.xf = Transform3D.IDENTITY
		"grip":
			k.bbox(Vector3(0, 0.15, 0), Vector3(0.05, 0.02, 0.07), 0.004, "black_in")
			k.cyl(Vector3(0, 0.0, 0), 0.024, 0.14, "black_in", 14, 0.02)
			for i in 5:
				k.cyl(Vector3(0, 0.02 + i * 0.022, 0), 0.0255, 0.008, "kevlar_in", 14)
			k.cyl(Vector3(0, -0.006, 0), 0.026, 0.008, "tin_in", 14)
		"ext_mag":
			var b := Basis(Vector3(0, 0, 1), 0.2)
			for i in 8:
				var t := i / 8.0
				k.bbox(b * Vector3(t * t * 0.05, 0.02 + i * 0.03, 0), Vector3(0.062, 0.033, 0.026), 0.005, "black_in", b * Basis(Vector3(0, 0, 1), -t * 0.35))
			k.bbox(b * Vector3(-0.004, 0.012, 0), Vector3(0.07, 0.014, 0.03), 0.004, "kevlar_in", b)
			k.xf = Transform3D(b * Basis(Vector3(0, 0, 1), -0.35 + PI * 0.5), b * Vector3(0.045, 0.262, 0))
			_round(k, Vector3(-0.012, -0.02, 0), 0.0075, 0.03, 0.02, "copper", 0.62)
			k.xf = Transform3D.IDENTITY
		_:
			k.bbox(Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.24), 0.02, "tan_in")
			k.box(Vector3(0, 0.201, 0), Vector3(0.245, 0.004, 0.05), "cream_in")
