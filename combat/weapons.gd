class_name Weapons
## Stats for every gun and melee weapon and how mods change them.
## The models are built in builders/weapon_mesh.gd.

# vel = muzzle speed m/s, spread in degrees, recoil in degrees per shot,
# noise = how far (m) enemies hear the shot.
const GUNS := {
	"pistol": {"cal": "9mm", "mag": 15, "rpm": 400.0, "auto": false, "dmg": 24.0, "vel": 360.0, "spread": 1.5, "recoil": 1.3, "reload": 1.6, "noise": 70.0, "shape": "pistol", "mods": ["sight", "muzzle", "mag"]},
	"revolver": {"cal": "357", "mag": 6, "rpm": 140.0, "auto": false, "dmg": 48.0, "vel": 430.0, "spread": 1.1, "recoil": 3.2, "reload": 2.8, "noise": 85.0, "shape": "revolver", "mods": ["sight"]},
	"smg": {"cal": "9mm", "mag": 30, "rpm": 800.0, "auto": true, "dmg": 20.0, "vel": 400.0, "spread": 2.1, "recoil": 0.9, "reload": 2.2, "noise": 75.0, "shape": "smg", "mods": ["sight", "muzzle", "mag", "grip"]},
	"assault_rifle": {"cal": "556", "mag": 30, "rpm": 650.0, "auto": true, "dmg": 30.0, "vel": 900.0, "spread": 0.9, "recoil": 1.3, "reload": 2.5, "noise": 95.0, "shape": "rifle", "mods": ["sight", "muzzle", "mag", "grip"]},
	"shotgun": {"cal": "12g", "mag": 6, "rpm": 70.0, "auto": false, "dmg": 11.0, "pellets": 9, "vel": 400.0, "spread": 4.2, "recoil": 4.5, "reload": 3.0, "noise": 100.0, "shape": "shotgun", "mods": ["sight", "muzzle"]},
	"marksman_rifle": {"cal": "762", "mag": 10, "rpm": 240.0, "auto": false, "dmg": 58.0, "vel": 820.0, "spread": 0.3, "recoil": 2.6, "reload": 2.8, "noise": 105.0, "shape": "rifle", "mods": ["sight", "muzzle", "mag", "grip"]},
	"sniper_rifle": {"cal": "338", "mag": 5, "rpm": 40.0, "auto": false, "dmg": 120.0, "vel": 910.0, "spread": 0.06, "recoil": 5.0, "reload": 3.4, "noise": 115.0, "zoom": 8.0, "shape": "sniper", "mods": ["muzzle"]},
	"flare_gun": {"cal": "flare", "mag": 1, "rpm": 30.0, "auto": false, "dmg": 40.0, "vel": 75.0, "spread": 1.0, "recoil": 2.0, "reload": 2.0, "noise": 40.0, "shape": "flare", "mods": []},
}

# windup = seconds until the blow lands, keep = share of damage that still gets through a block
const MELEE := {
	"knife": {"dmg": 16.0, "reach": 1.7, "windup": 0.2, "cool": 0.25, "stam": 5.0, "pen": 10.0, "keep": 0.6},
	"ice_pick": {"dmg": 24.0, "reach": 1.9, "windup": 0.32, "cool": 0.35, "stam": 8.0, "pen": 35.0, "keep": 0.5},
	"axe": {"dmg": 38.0, "reach": 2.1, "windup": 0.5, "cool": 0.5, "stam": 13.0, "pen": 15.0, "keep": 0.4},
	"sword": {"dmg": 30.0, "reach": 2.4, "windup": 0.33, "cool": 0.3, "stam": 9.0, "pen": 5.0, "keep": 0.2},
}


static func is_gun(id: String) -> bool:
	return GUNS.has(id)


static func is_melee(id: String) -> bool:
	return MELEE.has(id)


## Gun stats with the attached mods applied.
static func stats(id: String, mods: Array) -> Dictionary:
	var g: Dictionary = (GUNS[id] as Dictionary).duplicate()
	g["zoom"] = float(g.get("zoom", 1.25))
	g["aim_speed"] = 5.0
	g["ads"] = 0.45       # spread factor when aiming
	g["flash"] = true
	g["bloom"] = 1.0
	for m in mods:
		match str(m):
			"red_dot":
				g["ads"] = 0.3
				g["aim_speed"] = 7.0
			"scope":
				g["zoom"] = 4.0
				g["ads"] = 0.2
				g["aim_speed"] = 3.5
			"silencer":
				g["noise"] = float(g["noise"]) * 0.25
				g["vel"] = float(g["vel"]) * 0.92
				g["flash"] = false
			"muzzle_brake":
				g["recoil"] = float(g["recoil"]) * 0.75
				g["noise"] = float(g["noise"]) * 1.15
			"grip":
				g["recoil"] = float(g["recoil"]) * 0.8
				g["bloom"] = 0.6
			"ext_mag":
				g["mag"] = int(ceil(int(g["mag"]) * 1.5))
				g["reload"] = float(g["reload"]) * 1.1
	return g


static func describe(id: String) -> String:
	if GUNS.has(id):
		var g: Dictionary = GUNS[id]
		return "Damage %d%s   %d rpm   %d m/s\nMagazine %d (%s)%s" % [int(g["dmg"]),
			" ×%d" % int(g["pellets"]) if g.has("pellets") else "", int(g["rpm"]), int(g["vel"]),
			int(g["mag"]), Items.name_of(str(g["cal"])), "   automatic" if g["auto"] else ""]
	if MELEE.has(id):
		var m: Dictionary = MELEE[id]
		return "Damage %d   reach %.1f m   blow lands after %.2f s\nA block lets %d %% through" % [
			int(m["dmg"]), float(m["reach"]), float(m["windup"]), int(float(m["keep"]) * 100.0)]
	return ""


# ------------------------------------------------------------------ models
## First-person model. Guns point along -Z with the grip at the origin; the
## muzzle position is stored as meta "muzzle".
static func model(id: String, mods: Array) -> Node3D:
	var n: Node3D
	if MELEE.has(id):
		n = WeaponMesh.melee(id)
		n.set_meta("muzzle", Vector3.ZERO)
	else:
		n = WeaponMesh.gun(id, str(GUNS[id]["shape"]), mods)
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
