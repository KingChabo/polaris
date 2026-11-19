class_name Humanoid
## Builds people and wolves from rounded parts, with joints that can be animated.
## Figures face -Z, feet at the origin.
## Metas on a person: "torso", "head", "arm_l/r", "elbow_l/r", "hand_l/r", "leg_l/r", "knee_l/r".

const HIP := 0.95

## look: coat, trousers, hat ("hood", "beanie", "ushanka", "helmet", "none"), hat_col, mask, goggles,
## vest, pack, beard, scarf (colour name or ""), skin, hair
static func build(look: Dictionary) -> Node3D:
	var coat := str(look.get("coat", "olive")) + "_coat"
	var trousers := str(look.get("trousers", "black")) + "_in"
	var skin := str(look.get("skin", "skin")) + "_in"
	var hat := str(look.get("hat", "hood"))
	var hat_col := str(look.get("hat_col", look.get("coat", "olive"))) + "_in"
	var fur := "fur_brown_in"
	var root := Node3D.new()

	# ---- torso (hips up to the collar)
	var k := MeshKit.new()
	k.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.74)), Vector3.ZERO)
	k.ball(Vector3(0, 0.0, 0), Vector3(0.185, 0.13, 0.19), trousers)
	k.tube(Vector3(0, -0.2, 0), Vector3(0, 0.06, 0), 0.225, coat, 14, 0.2, false)      # parka skirt
	k.tube(Vector3(0, 0.04, 0), Vector3(0, 0.4, 0), 0.2, coat, 14, 0.215, false)
	k.ball(Vector3(0, 0.41, 0), Vector3(0.245, 0.125, 0.2), coat, 16, 7)                # shoulders
	k.ball(Vector3(0, 0.47, 0.02), Vector3(0.17, 0.085, 0.16), coat, 14, 6)             # slope up to the neck
	k.tube(Vector3(0, -0.2, 0), Vector3(0, -0.17, 0), 0.229, "black_in", 14, 0.228, false)   # hem drawcord
	k.tube(Vector3(0, 0.03, 0), Vector3(0, 0.075, 0), 0.208, "black_in", 14)            # belt
	k.tube(Vector3(0, 0.47, 0), Vector3(0, 0.56, 0), 0.105, coat, 12, 0.085, false)     # collar
	k.xf = Transform3D.IDENTITY
	k.tube(Vector3(0, 0.48, 0), Vector3(0, 0.62, 0), 0.052, skin, 8)                    # neck
	k.box(Vector3(0, 0.2, -0.158), Vector3(0.022, 0.5, 0.012), "black_in")              # zip
	k.bbox(Vector3(0, 0.05, -0.16), Vector3(0.05, 0.04, 0.02), 0.006, "steel_in")       # buckle
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.bbox(Vector3(x * 0.105, -0.07, -0.158), Vector3(0.11, 0.1, 0.03), 0.01, coat)   # pockets
		k.box(Vector3(x * 0.105, -0.02, -0.172), Vector3(0.115, 0.02, 0.012), coat)
	for sx in [-1.0, 1.0]:
		var x: float = sx
		k.bbox(Vector3(x * 0.1, 0.33, -0.156), Vector3(0.085, 0.075, 0.02), 0.008, coat)   # chest pockets
		k.bbox(Vector3(x * 0.1, 0.362, -0.166), Vector3(0.09, 0.028, 0.012), 0.005, coat)
		k.cyl(Vector3(x * 0.1, 0.352, -0.176), 0.007, 0.006, "black_in", 6)
	if hat != "hood":
		# the hood lies folded on the back, its fur edge showing over the shoulders
		k.ball(Vector3(0, 0.47, 0.13), Vector3(0.15, 0.1, 0.085), coat, 12, 6)
		for i in 9:
			var a := PI * i / 8.0
			k.ball(Vector3(cos(a) * 0.125, 0.52, 0.07 + sin(a) * 0.075), Vector3(0.03, 0.026, 0.03), fur, 6, 4)
	_gear(k, look, coat, fur)
	var torso := k.node(false)
	torso.position = Vector3(0, HIP, 0)
	root.add_child(torso)
	root.set_meta("torso", torso)

	# ---- head
	var h := MeshKit.new()
	h.ball(Vector3(0, 0.115, 0), Vector3(0.092, 0.115, 0.102), skin, 14, 9)
	h.ball(Vector3(0, 0.045, -0.02), Vector3(0.075, 0.06, 0.08), skin, 10, 6)                   # jaw
	# the bones under the skin: brow ridge, cheekbones, chin
	h.ball(Vector3(0, 0.15, -0.074), Vector3(0.068, 0.017, 0.03), skin, 10, 4)
	h.ball(Vector3(0, 0.026, -0.071), Vector3(0.03, 0.024, 0.026), skin, 8, 5)
	# nose: bridge, tip and wings
	h.tube(Vector3(0, 0.142, -0.094), Vector3(0, 0.104, -0.113), 0.01, skin, 6, 0.015)
	h.ball(Vector3(0, 0.099, -0.114), Vector3(0.014, 0.012, 0.013), skin, 8, 5)
	var hair_col := str(look.get("hair", "fur_brown")) + "_in"
	for sx in [-1.0, 1.0]:
		var x: float = sx
		h.ball(Vector3(x * 0.012, 0.095, -0.107), Vector3(0.009, 0.008, 0.009), skin, 6, 4)    # nostril wing
		h.ball(Vector3(x * 0.052, 0.1, -0.064), Vector3(0.026, 0.018, 0.022), skin, 8, 5)      # cheekbone
		if str(look.get("eyes", "")) == "glow":
			h.ball(Vector3(x * 0.036, 0.128, -0.088), Vector3(0.016, 0.01, 0.012), "frost_eye", 8, 4)
		else:
			h.ball(Vector3(x * 0.034, 0.128, -0.082), Vector3(0.0145, 0.0085, 0.012), "eye_white_in", 8, 4)
			h.ball(Vector3(x * 0.034, 0.1275, -0.0915), Vector3(0.0066, 0.0066, 0.0035), "iris_in", 8, 4)
			h.ball(Vector3(x * 0.034, 0.1275, -0.0941), Vector3(0.003, 0.003, 0.0016), "black_in", 6, 3)
		h.ball(Vector3(x * 0.034, 0.1352, -0.0855), Vector3(0.0175, 0.0066, 0.013), skin, 8, 4)        # upper lid
		h.ball(Vector3(x * 0.034, 0.1195, -0.085), Vector3(0.0165, 0.0055, 0.012), skin, 8, 4)        # lower lid
		h.box(Vector3(x * 0.037, 0.151, -0.098), Vector3(0.042, 0.008, 0.012), hair_col if hair_col != "white_in" else "fur_in", Basis(Vector3.BACK, -x * 0.15))   # brow
		h.ball(Vector3(x * 0.094, 0.11, 0.005), Vector3(0.014, 0.03, 0.02), skin, 6, 4)        # ears
	# lips and the line between them
	h.ball(Vector3(0, 0.0655, -0.093), Vector3(0.021, 0.0055, 0.008), "lips_in", 8, 4)
	h.ball(Vector3(0, 0.0555, -0.091), Vector3(0.019, 0.0065, 0.009), "lips_in", 8, 4)
	h.box(Vector3(0, 0.0605, -0.0985), Vector3(0.034, 0.0025, 0.004), "black_in")
	if bool(look.get("beard", false)):
		# a full beard: a base over the jaw, ragged tufts round its edge, a moustache
		h.ball(Vector3(0, 0.038, -0.05), Vector3(0.074, 0.062, 0.066), hair_col, 10, 6)
		for i in 15:
			var a := lerpf(-1.2, 1.2, i / 14.0)
			var drop := 0.018 + 0.026 * (1.0 - absf(a) / 1.2)
			h.ball(Vector3(sin(a) * 0.07, 0.05 - drop, -cos(a) * 0.066 - 0.012), Vector3(0.021, 0.028, 0.018), hair_col, 6, 4, Basis(Vector3.FORWARD, a * 0.4))
		h.ball(Vector3(0, -0.005, -0.082), Vector3(0.03, 0.03, 0.022), hair_col, 8, 5)      # chin tuft
		for sx in [-1.0, 1.0]:
			var x: float = sx
			h.ball(Vector3(x * 0.018, 0.072, -0.104), Vector3(0.024, 0.008, 0.011), hair_col, 8, 4, Basis(Vector3.BACK, x * 0.28))
	if bool(look.get("mask", false)):
		h.ball(Vector3(0, 0.06, -0.022), Vector3(0.097, 0.075, 0.1), "black_in", 12, 6)        # face wrap
	if bool(look.get("goggles", false)):
		h.bbox(Vector3(0, 0.13, -0.092), Vector3(0.17, 0.062, 0.045), 0.018, "black_in")
		for sx in [-1.0, 1.0]:
			var x: float = sx
			h.bbox(Vector3(x * 0.04, 0.13, -0.112), Vector3(0.068, 0.046, 0.014), 0.012, "glass_dark")
		h.tube(Vector3(0, 0.13, 0.0), Vector3(0, 0.15, 0.0), 0.106, "black_in", 12, 0.106, false)
	_hat(h, look, hat, hat_col, fur)
	var head := h.node(false)
	head.position = Vector3(0, 0.6, 0)
	torso.add_child(head)
	root.set_meta("head", head)

	# ---- arms and legs
	for side in [-1.0, 1.0]:
		var sx: float = side
		var tag := "l" if sx < 0.0 else "r"
		var a := MeshKit.new()
		a.ball(Vector3(-sx * 0.012, 0.0, 0), Vector3(0.074, 0.082, 0.08), coat, 12, 7)
		a.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.28, 0), 0.064, coat, 14, 0.055)
		var arm := a.node(false)
		arm.position = Vector3(sx * 0.245, 0.44, 0)
		torso.add_child(arm)
		var f := MeshKit.new()
		f.capsule(Vector3.ZERO, Vector3(0, -0.24, 0), 0.053, coat, 14, 0.045)
		f.tube(Vector3(0, -0.195, 0), Vector3(0, -0.225, 0), 0.052, coat, 12, 0.05)               # sleeve end
		f.tube(Vector3(0, -0.215, 0), Vector3(0, -0.262, 0), 0.043, "kevlar_in", 10, 0.04)        # knitted cuff
		# a gloved hand: palm, four fingers curled a little, thumb
		f.ball(Vector3(0, -0.297, -0.004), Vector3(0.024, 0.042, 0.04), "glove_in", 10, 6)
		for i in 4:
			var fz := -0.034 + i * 0.02
			var fl: float = [0.05, 0.058, 0.055, 0.044][i]
			f.capsule(Vector3(0, -0.325, fz), Vector3(-sx * 0.006, -0.325 - fl * 0.6, fz - 0.004), 0.0098, "glove_in", 6, 0.009)
			f.capsule(Vector3(-sx * 0.006, -0.325 - fl * 0.6, fz - 0.004), Vector3(-sx * 0.02, -0.325 - fl, fz - 0.006), 0.009, "glove_in", 6, 0.008)
		f.capsule(Vector3(-sx * 0.012, -0.285, -0.04), Vector3(-sx * 0.026, -0.325, -0.058), 0.0115, "glove_in", 6, 0.0095)
		var fore := f.node(false)
		fore.position = Vector3(0, -0.29, 0)
		arm.add_child(fore)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.31, -0.01)
		fore.add_child(hand)
		root.set_meta("arm_" + tag, arm)
		root.set_meta("elbow_" + tag, fore)
		root.set_meta("hand_" + tag, hand)

		var l := MeshKit.new()
		l.capsule(Vector3(0, -0.02, 0), Vector3(0, -0.42, 0), 0.098, trousers, 14, 0.078)
		l.bbox(Vector3(sx * 0.088, -0.22, 0.0), Vector3(0.03, 0.12, 0.1), 0.01, trousers)         # cargo pocket
		l.bbox(Vector3(sx * 0.092, -0.172, 0.0), Vector3(0.03, 0.03, 0.104), 0.008, trousers)
		var leg := l.node(false)
		leg.position = Vector3(sx * 0.1, HIP, 0)
		root.add_child(leg)
		var s := MeshKit.new()
		s.capsule(Vector3.ZERO, Vector3(0, -0.36, 0), 0.076, trousers, 14, 0.066)
		s.tube(Vector3(0, -0.2, 0), Vector3(0, -0.25, 0), 0.071, trousers, 12, 0.076)                # trouser leg bunched over the boot
		s.ball(Vector3(0, 0.0, -0.03), Vector3(0.066, 0.066, 0.056), trousers, 10, 6)               # knee
		s.tube(Vector3(0, -0.24, 0), Vector3(0, -0.45, 0), 0.073, "leather_in", 12, 0.068)        # boot shaft
		s.tube(Vector3(0, -0.24, 0), Vector3(0, -0.27, 0), 0.08, fur, 10)                         # fur cuff
		s.ball(Vector3(0, -0.465, -0.05), Vector3(0.066, 0.052, 0.13), "leather_in", 12, 6)       # foot
		s.ball(Vector3(0, -0.47, -0.135), Vector3(0.059, 0.042, 0.052), "leather_in", 10, 5)        # toe cap
		for i in 5:
			s.tube(Vector3(-0.024, -0.3 - i * 0.03, -0.069 - i * 0.004), Vector3(0.024, -0.3 - i * 0.03, -0.069 - i * 0.004), 0.004, "cream_in", 4)
		s.bbox(Vector3(0, -0.508, -0.045), Vector3(0.13, 0.03, 0.285), 0.012, "tar_in")          # sole
		s.bbox(Vector3(0, -0.52, 0.045), Vector3(0.118, 0.03, 0.085), 0.008, "tar_in")            # heel
		var shin := s.node(false)
		shin.position = Vector3(0, -0.43, 0)
		leg.add_child(shin)
		root.set_meta("leg_" + tag, leg)
		root.set_meta("knee_" + tag, shin)
	if ScanPerson.wanted(look):
		ScanPerson.dress(root, look)
	return root


## Scarf, backpack and vest, drawn round the torso (hips at y = 0).
static func _gear(k: MeshKit, look: Dictionary, coat: String, fur: String, scan := false) -> void:
	var scarf := str(look.get("scarf", ""))
	if scarf != "":
		k.ball(Vector3(0, 0.515, 0.0), Vector3(0.118, 0.04, 0.1), scarf + "_in", 14, 6, Basis(Vector3.BACK, 0.1))
		k.ball(Vector3(0.006, 0.56, -0.006), Vector3(0.104, 0.036, 0.094), scarf + "_in", 14, 6, Basis(Vector3.BACK, -0.14))
		k.ball(Vector3(0.05, 0.5, -0.1), Vector3(0.04, 0.03, 0.03), scarf + "_in", 8, 5)      # knot
		if not scan:
			k.bbox(Vector3(0.05, 0.38, -0.15), Vector3(0.07, 0.22, 0.025), 0.008, scarf + "_in", Basis(Vector3.BACK, 0.12))
	if bool(look.get("pack", true)):
		k.bbox(Vector3(0, 0.25, 0.22), Vector3(0.3, 0.4, 0.17), 0.04, fur)
		k.bbox(Vector3(0, 0.16, 0.315), Vector3(0.2, 0.16, 0.05), 0.02, fur)
		k.capsule(Vector3(-0.17, 0.48, 0.22), Vector3(0.17, 0.48, 0.22), 0.06, "cloth_in", 8)   # bedroll
		for sx in [-1.0, 1.0]:
			var x: float = sx
			k.box(Vector3(x * 0.13, 0.3, -0.158), Vector3(0.035, 0.34, 0.012), "black_in")
			k.box(Vector3(x * 0.13, 0.48, 0.03), Vector3(0.035, 0.012, 0.36), "black_in")
	if bool(look.get("vest", false)):
		k.bbox(Vector3(0, 0.27, -0.16), Vector3(0.33, 0.33, 0.06), 0.02, "olive_in")
		k.bbox(Vector3(0, 0.27, 0.15), Vector3(0.33, 0.33, 0.05), 0.02, "olive_in")
		for sx in [-0.11, 0.0, 0.11]:
			var x: float = sx
			k.bbox(Vector3(x, 0.17, -0.205), Vector3(0.085, 0.14, 0.045), 0.012, "black_in")
			k.box(Vector3(x, 0.235, -0.225), Vector3(0.087, 0.03, 0.012), "olive_in")
		for sx in [-1.0, 1.0]:
			var x: float = sx
			k.bbox(Vector3(x * 0.13, 0.47, 0.0), Vector3(0.06, 0.03, 0.34), 0.01, "olive_in")


## Hood, beanie, ushanka or helmet (or hair) on a head whose centre is at y = 0.115.
static func _hat(h: MeshKit, look: Dictionary, hat: String, hat_col: String, fur: String) -> void:
	match hat:
		"hood":
			h.ball(Vector3(0, 0.125, 0.038), Vector3(0.128, 0.148, 0.128), hat_col, 14, 9)
			h.tube(Vector3(0, 0.0, 0.03), Vector3(0, -0.06, 0.02), 0.12, hat_col, 12, 0.135, false)
			# fur ruff round the face: a soft rolled rim, and tufts standing out of it
			var ring := 28
			for i in ring:
				var a0 := TAU * i / ring
				var a1 := TAU * (i + 1) / ring
				var p0 := Vector3(cos(a0) * 0.114, 0.12 + sin(a0) * 0.132, -0.05 + absf(cos(a0)) * 0.02)
				var p1 := Vector3(cos(a1) * 0.114, 0.12 + sin(a1) * 0.132, -0.05 + absf(cos(a1)) * 0.02)
				h.tube(p0, p1, 0.019, fur, 7, 0.019, false)
			for i in 96:
				var a := TAU * i / 96.0
				var r := 1.06 + 0.08 * sin(i * 2.4)
				var tuft := fur if i % 3 != 0 else "fur_dark_in"
				h.ball(Vector3(cos(a) * 0.116 * r, 0.12 + sin(a) * 0.134 * r, -0.052 + absf(cos(a)) * 0.02 + 0.008 * sin(i * 5.1)), Vector3(0.026 + 0.006 * sin(i * 3.7), 0.009, 0.026), tuft, 5, 3, Basis(Vector3.BACK, a + 0.35 * sin(i * 1.9)))
		"beanie":
			h.ball(Vector3(0, 0.165, 0.005), Vector3(0.099, 0.085, 0.109), hat_col, 12, 6)
			h.tube(Vector3(0, 0.14, 0.005), Vector3(0, 0.175, 0.005), 0.104, hat_col, 12, 0.1, false)
			h.ball(Vector3(0, 0.26, 0.005), Vector3(0.03, 0.03, 0.03), "white_in", 6, 4)
		"ushanka":
			h.ball(Vector3(0, 0.17, 0.005), Vector3(0.105, 0.085, 0.115), fur, 12, 6)
			h.bbox(Vector3(0, 0.175, -0.1), Vector3(0.15, 0.07, 0.03), 0.012, fur)
			for sx in [-1.0, 1.0]:
				var x: float = sx
				h.bbox(Vector3(x * 0.1, 0.09, 0.01), Vector3(0.03, 0.15, 0.1), 0.012, fur)
		"helmet":
			h.ball(Vector3(0, 0.15, 0.005), Vector3(0.112, 0.1, 0.122), "olive_in", 14, 7)
			h.tube(Vector3(0, 0.125, 0.005), Vector3(0, 0.14, 0.005), 0.12, "olive_in", 14, 0.114, false)
			h.tube(Vector3(0, 0.165, 0.005), Vector3(0, 0.18, 0.005), 0.113, "kevlar_in", 14, 0.11, false)
			h.box(Vector3(0, 0.06, -0.06), Vector3(0.012, 0.13, 0.012), "black_in", Basis(Vector3.RIGHT, 0.5))
		_:
			h.ball(Vector3(0, 0.15, 0.015), Vector3(0.096, 0.09, 0.106), str(look.get("hair", "fur_dark")) + "_in", 12, 6)


## Gives a look the things that differ from person to person: skin, hair, and how tall and broad
## they are. `key` picks them, so the same person always comes out the same.
static func vary(look: Dictionary, key: int) -> Dictionary:
	var out := look.duplicate()
	var r := RandomNumberGenerator.new()
	r.seed = key
	if not out.has("skin"):
		out["skin"] = ["skin", "skin", "skin_pale", "skin_pale", "skin_ruddy", "skin_tan", "skin_dark"][r.randi() % 7]
	if not out.has("hair"):
		out["hair"] = ["fur_brown", "fur_dark", "fur_brown", "fur", "fur_dark"][r.randi() % 5]
	out["tall"] = r.randf_range(0.95, 1.05)
	out["broad"] = r.randf_range(0.94, 1.08)
	return out


## Scales a built figure to the height and width `vary` chose.
static func fit(m: Node3D, look: Dictionary) -> void:
	var broad := float(look.get("broad", 1.0))
	m.scale = Vector3(broad, float(look.get("tall", 1.0)), broad)


## Walk cycle: legs swing and bend at the knee, arms swing against them, the body bobs.
## `amt` 0 = standing still, 1 = brisk walk. Leaves the arms alone if `arms` is false.
static func walk(m: Node3D, phase: float, amt: float, arms := true, weight := 0.3) -> void:
	var s := sin(phase)
	var c := cos(phase)
	var leg_l: Node3D = m.get_meta("leg_l")
	var leg_r: Node3D = m.get_meta("leg_r")
	var knee_l: Node3D = m.get_meta("knee_l")
	var knee_r: Node3D = m.get_meta("knee_r")
	var torso: Node3D = m.get_meta("torso")
	leg_l.rotation.x = lerpf(leg_l.rotation.x, s * 0.62 * amt, weight)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -s * 0.62 * amt, weight)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, -maxf(c, 0.0) * 0.95 * amt - 0.04, weight)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, -maxf(-c, 0.0) * 0.95 * amt - 0.04, weight)
	var hip := float(m.get_meta("hip", HIP))
	torso.position.y = hip - 0.012 + (0.0 if m.has_meta("scan") else absf(c) * 0.03 * amt)
	torso.rotation.y = lerpf(torso.rotation.y, s * 0.12 * amt, weight)
	if arms:
		var arm_l: Node3D = m.get_meta("arm_l")
		var arm_r: Node3D = m.get_meta("arm_r")
		var el_l: Node3D = m.get_meta("elbow_l")
		var el_r: Node3D = m.get_meta("elbow_r")
		arm_l.rotation = arm_l.rotation.lerp(Vector3(-s * 0.5 * amt, 0, -0.07), weight)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(s * 0.5 * amt, 0, 0.07), weight)
		el_l.rotation = el_l.rotation.lerp(Vector3(0.25 + maxf(-s, 0.0) * 0.5 * amt, 0, 0), weight)
		el_r.rotation = el_r.rotation.lerp(Vector3(0.25 + maxf(s, 0.0) * 0.5 * amt, 0, 0), weight)


## Real walking numbers for a speed in m/s: Vector2(phase per second, swing amount for walk()).
## Cadence rises with speed (about 1.8 steps a second at a stroll, 3.3 at a run) and the stride
## is what is left, so the feet keep pace with the ground instead of skating.
static func gait(speed: float) -> Vector2:
	if speed < 0.05:
		return Vector2.ZERO
	var steps := 1.0 + 0.62 * minf(speed, 4.5)
	var stride := speed / steps
	var swing := asin(clampf(stride / 1.75, 0.0, 0.85))
	return Vector2(PI * steps, swing / 0.62)


## Slow breathing and a little weight shifting while standing.
static func breathe(m: Node3D, t: float) -> void:
	var torso: Node3D = m.get_meta("torso")
	var head: Node3D = m.get_meta("head")
	torso.rotation.x = sin(t * 1.3) * 0.015
	torso.rotation.z = sin(t * 0.4) * 0.02
	head.rotation.x = sin(t * 1.3 + 0.6) * 0.02


## A wolf, facing -Z. Metas "legs" (Array of 4 pivots), "knees", "head", "tail".
static func wolf(fur_name: String) -> Node3D:
	var fur := fur_name + "_in"
	var root := Node3D.new()
	var k := MeshKit.new()
	k.ball(Vector3(0, 0.66, 0.1), Vector3(0.185, 0.2, 0.46), fur, 14, 8)                     # barrel
	k.ball(Vector3(0, 0.7, -0.26), Vector3(0.2, 0.235, 0.27), fur, 14, 8)                    # deep chest
	k.ball(Vector3(0, 0.66, 0.42), Vector3(0.175, 0.2, 0.22), fur, 12, 7)                    # haunches
	k.ball(Vector3(0, 0.56, 0.05), Vector3(0.13, 0.1, 0.38), "camo_in", 10, 6)               # pale underside
	k.tube(Vector3(0, 0.72, -0.36), Vector3(0, 0.86, -0.56), 0.165, fur, 12, 0.115, false)   # thick neck
	for i in 9:   # shaggy ruff and hackles along the spine
		var a := PI * i / 8.0
		k.ball(Vector3(cos(a) * 0.15, 0.76 + sin(a) * 0.12, -0.4), Vector3(0.06, 0.07, 0.1), fur, 6, 4)
		k.ball(Vector3(0, 0.86 - i * 0.004, -0.3 + i * 0.09), Vector3(0.05, 0.035, 0.07), "fur_dark_in", 6, 4)
	root.add_child(k.node(false))
	var h := MeshKit.new()
	h.ball(Vector3(0, 0.0, -0.05), Vector3(0.115, 0.105, 0.135), fur, 12, 7)
	h.ball(Vector3(0, -0.02, 0.0), Vector3(0.13, 0.1, 0.09), fur, 10, 6)                     # cheeks
	h.tube(Vector3(0, -0.015, -0.13), Vector3(0, -0.035, -0.33), 0.062, fur, 10, 0.038)      # muzzle
	h.ball(Vector3(0, -0.02, -0.335), Vector3(0.026, 0.02, 0.022), "black_in", 6, 4)         # nose
	h.tube(Vector3(0, -0.075, -0.1), Vector3(0, -0.078, -0.3), 0.04, "fur_dark_in", 8, 0.024) # jaw
	for sx in [-1.0, 1.0]:
		var x: float = sx
		h.tube(Vector3(x * 0.075, 0.07, 0.01), Vector3(x * 0.095, 0.165, 0.02), 0.042, fur, 6, 0.0)   # ears
		h.tube(Vector3(x * 0.075, 0.075, 0.0), Vector3(x * 0.092, 0.15, 0.008), 0.026, "black_in", 5, 0.0)
		h.ball(Vector3(x * 0.055, 0.035, -0.145), Vector3(0.011, 0.008, 0.008), "candle", 6, 4)       # eyes catch the light
		h.box(Vector3(x * 0.055, 0.05, -0.143), Vector3(0.035, 0.008, 0.014), "fur_dark_in", Basis(Vector3.BACK, x * 0.4))   # brow
		h.ball(Vector3(x * 0.032, -0.064, -0.28), Vector3(0.006, 0.022, 0.006), "white_in", 4, 3)     # fangs
	var head := h.node(false)
	head.position = Vector3(0, 0.9, -0.6)
	root.add_child(head)
	root.set_meta("head", head)
	var t := MeshKit.new()
	t.tube(Vector3.ZERO, Vector3(0, 0, 0.26), 0.05, fur, 8, 0.085, false)
	t.tube(Vector3(0, 0, 0.26), Vector3(0, 0, 0.5), 0.085, fur, 8, 0.0, false)
	t.ball(Vector3(0, 0, 0.44), Vector3(0.035, 0.035, 0.06), "camo_in", 6, 4)
	var tail := t.node(false)
	tail.position = Vector3(0, 0.74, 0.6)
	tail.rotation.x = -0.6
	root.add_child(tail)
	root.set_meta("tail", tail)
	var legs: Array[Node3D] = []
	var knees: Array[Node3D] = []
	for p in [Vector3(-0.12, 0.6, -0.3), Vector3(0.12, 0.6, -0.3), Vector3(-0.12, 0.62, 0.44), Vector3(0.12, 0.62, 0.44)]:
		var at: Vector3 = p
		var back := at.z > 0.0
		var l := MeshKit.new()
		l.capsule(Vector3.ZERO, Vector3(0, -0.3, 0.06 if back else 0.0), 0.095 if back else 0.075, fur, 10, 0.052)
		var leg := l.node(false)
		leg.position = at
		root.add_child(leg)
		var s2 := MeshKit.new()
		s2.capsule(Vector3.ZERO, Vector3(0, -0.25, -0.05 if back else -0.01), 0.048, fur, 8, 0.036)
		s2.ball(Vector3(0, -0.275, -0.07 if back else -0.035), Vector3(0.048, 0.035, 0.065), "fur_dark_in", 8, 4)
		var shin := s2.node(false)
		shin.position = Vector3(0, -0.3, 0.06 if back else 0.0)
		leg.add_child(shin)
		legs.append(leg)
		knees.append(shin)
	root.set_meta("legs", legs)
	root.set_meta("knees", knees)
	return root
