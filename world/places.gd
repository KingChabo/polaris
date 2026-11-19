class_name Places
extends Node3D
## The big places of the valley and the roads between them: research station, army base,
## mine, road tunnel, bunkers, the broken bridge over the Eisklamm, the fishing hamlet,
## lookouts, wrecks and the documents that tell what happened here.
## `plan()` shapes the ground before the terrain mesh exists; `build()` puts everything on it.

const STATION := Vector2(-362, -402)
const BASE := Vector2(40, -456)
const SETTLE := Vector2(-72, 48)
const BRIDGE := Vector2(-300, -340)
const HUB := Vector2(252, 8)
const J1 := Vector2(-20, -110)
const TOWER := Vector2(20, 190)
const VIEW := Vector2(540, 176)
const CABINS: Array[Vector2] = [Vector2(-58, 34), Vector2(-84, 30), Vector2(-60, 62), Vector2(-88, 60)]
const BUNKERS := [[250, 144], [267, 338]]     # grid point of the stair shaft

static var T: Terrain
static var pads: Array = []                  # [centre, half size]: kept free of trees and camps
static var roads := {}                       # name -> PackedVector3Array, a point every 4 m
static var gorge_pts := PackedVector2Array()
static var D := {}                           # numbers worked out while planning
static var rooms: Array = []                 # [AABB, warm]: roofed rooms above ground

var terrain: Terrain
var village: Village
var main: Node
var rng := RandomNumberGenerator.new()
var k: MeshKit                               # solid things
var kd: MeshKit                              # small things you walk through
var spots: Array = []                        # {id, name, pos, r, kind}
var found: Array[String] = []
var crews: Array = []                        # [id, weapon, position] for Enemies
var cabins: Array[Node3D] = []
var span: Node3D
var bridge_lever: Lever
var _scan := 0.0


static func _u() -> Vector2:
	return Vector2(-1, -1).normalized()      # along the bridge, towards the station


## Shapes the ground: level pads, roads, the ravine, and everything underground.
static func plan(t: Terrain) -> void:
	T = t
	pads.clear()
	roads.clear()
	D = {}
	var u := _u()
	# --- pads
	D["station_h"] = t.height_at(STATION.x, STATION.y)
	t.flatten(STATION, Vector2(42, 32), 0.0, D["station_h"], 14.0)
	pads.append([STATION, Vector2(47, 37)])
	D["base_h"] = t.height_at(BASE.x, BASE.y) + 1.0
	t.flatten(BASE, Vector2(48, 36), 0.0, D["base_h"], 14.0)
	pads.append([BASE, Vector2(52, 40)])
	for c in CABINS:
		t.flatten(c, Vector2(6.0, 5.5), 0.0, t.height_at(c.x, c.y), 7.0)
	pads.append([SETTLE, Vector2(36, 32)])
	t.flatten(TOWER, Vector2(9, 9), 0.0, t.height_at(TOWER.x, TOWER.y), 6.0)
	pads.append([TOWER, Vector2(12, 12)])
	var bh := []
	for b in BUNKERS:
		var c := Vector2(t.gx(b[0]) - 6.0, t.gx(b[1] - 1) + 4.0)
		var h := t.height_at(c.x, c.y)
		t.flatten(c, Vector2(15, 13), 0.0, h, 8.0)
		pads.append([c, Vector2(18, 16)])
		bh.append(h)
	D["bunker_h"] = bh
	var fm := t.height_at(498.0, 140.0)
	t.flatten(Vector2(486, 140), Vector2(14, 13), 0.0, fm, 10.0)
	pads.append([Vector2(486, 140), Vector2(19, 17)])
	D["mine_floor"] = fm
	var e_ab := BRIDGE - u * 17.0
	var w_ab := BRIDGE + u * 17.0
	D["bridge_h"] = (t.height_at(e_ab.x, e_ab.y) + t.height_at(w_ab.x, w_ab.y)) * 0.5
	t.flatten(BRIDGE, Vector2(4, 24), PI * 0.25, D["bridge_h"], 6.0)
	pads.append([BRIDGE, Vector2(26, 26)])
	# --- roads
	var defs := {
		"west": [Vector2(260, -26), HUB, Vector2(200, 16), Vector2(120, -22), J1, Vector2(-150, -200), Vector2(-240, -282), e_ab],
		"station": [w_ab, Vector2(-322, -372), STATION + Vector2(36, 8)],
		"north": [J1, Vector2(0, -250), Vector2(30, -350), BASE + Vector2(0, 40)],
		"lake": [J1, Vector2(-45, -30), SETTLE + Vector2(8, -12)],
		"south": [HUB, Vector2(240, 150), Vector2(170, 330), Vector2(112, 440), Vector2(100, 490), Vector2(100, 512)],
		"mine": [HUB, Vector2(330, 62), Vector2(420, 124), Vector2(474, 140)],
	}
	for name in defs:
		roads[name] = t.road(PackedVector2Array(defs[name]))
	# the bridge deck counts as road too
	for q in 13:
		t.pave(BRIDGE + u * (q - 6) * 3.0, 3.0)
	# --- the Eisklamm: a ravine from the west wall to the north wall
	gorge_pts = PackedVector2Array([Vector2(-640, -20), Vector2(-540, -90), Vector2(-455, -200), Vector2(-375, -262),
		BRIDGE, Vector2(-225, -418), Vector2(-160, -500), Vector2(-70, -570), Vector2(-20, -660)])
	t.gorge(gorge_pts, 7.0, 16.0, 9.0)
	SiteSouth.plan(t)
	t.settle()
	# --- underground. Grid: x = 4 * i - 1024.
	var open := 0
	fm = t.height_at(498.0, 140.0)
	t.dig(381, 290, 400, 292, fm, 4.0)                 # adit, x 500..576
	open += t.dig(400, 286, 408, 296, fm, 8.6)         # the big chamber
	open += t.dig(393, 281, 395, 290, fm, 4.0)         # drift to the office
	open += t.dig(391, 277, 397, 281, fm, 4.2)         # office
	open += t.dig(396, 292, 399, 297, fm, 4.0)         # hidden room
	D["mine_px"] = 520.0
	for i in range(381, 400):
		if t.roofed[290 * Terrain.N + i] + t.roofed[291 * Terrain.N + i] + t.roofed[292 * Terrain.N + i] == 3:
			D["mine_px"] = t.gx(i)
			break
	var ft := t.height_at(100.0, 510.0)
	D["tunnel_floor"] = ft
	t.dig(279, 383, 283, 406, ft, 7.6)                 # road tunnel, z 508..600: out into the gorge
	open += t.dig(283, 392, 289, 396, ft, 4.0)         # service room
	D["tunnel_pz"] = 540.0
	for j in range(383, 403):
		var all := true
		for i in range(279, 284):
			if t.roofed[j * Terrain.N + i] == 0:
				all = false
		if all:
			D["tunnel_pz"] = t.gx(j)
			break
	for q in BUNKERS.size():
		var bi: int = BUNKERS[q][0]
		var bj: int = BUNKERS[q][1]
		var fl: float = bh[q] - 4.7
		open += t.dig(bi - 4, bj - 2, bi, bj + 2, fl)
		open += t.dig(bi, bj - 1, bi + 1, bj + 1, fl)
		t.open_cell(bi, bj - 1)
		t.open_cell(bi, bj)
	print("Places planned: mine mouth x=%.0f, tunnel mouth z=%.0f, %d dug points without a roof" % [D["mine_px"], D["tunnel_pz"], open])


static func _avg_gorge(p: Vector2) -> float:
	var best := 1e9
	for q in gorge_pts.size() - 1:
		best = minf(best, Terrain._seg_dist(p, gorge_pts[q], gorge_pts[q + 1]).x)
	return best


## True where nothing may grow: pads, roads, the ravine, cuttings and tunnel roofs.
static func cleared(x: float, z: float) -> bool:
	if T == null:
		return false
	for p in pads:
		var c: Vector2 = p[0]
		var h: Vector2 = p[1]
		if absf(x - c.x) < h.x and absf(z - c.y) < h.y:
			return true
	if T.is_dug(x, z):
		return true
	for o in [Vector2.ZERO, Vector2(3.5, 0), Vector2(-3.5, 0), Vector2(0, 3.5), Vector2(0, -3.5)]:
		var ov: Vector2 = o
		if T.on_road(x + ov.x, z + ov.y):
			return true
	if absf(x + z + 640.0) < 90.0 and _avg_gorge(Vector2(x, z)) < 17.0:
		return true
	return false


## True within `m` metres of any place, road or the ravine (for camps and cabins).
static func near(p: Vector2, m: float) -> bool:
	if T == null:
		return false
	for pd in pads:
		var c: Vector2 = pd[0]
		var h: Vector2 = pd[1]
		if absf(p.x - c.x) < h.x + m and absf(p.y - c.y) < h.y + m:
			return true
	for q in 8:
		var o := Vector2.from_angle(q * TAU / 8.0) * m * 0.5
		if T.on_road(p.x + o.x, p.y + o.y) or T.is_dug(p.x + o.x, p.y + o.y):
			return true
	return _avg_gorge(p) < m + 16.0


## Under the lid of a tunnel, mine or shelter.
static func underground(pos: Vector3) -> bool:
	return T != null and T.is_dug(pos.x, pos.z) and T.natural_at(pos.x, pos.z) - pos.y > 1.8


## 0 = outside, 1 = out of the wind, 2 = heated.
static func shelter_at(pos: Vector3) -> int:
	if underground(pos):
		return 1
	for r in rooms:
		if (r[0] as AABB).has_point(pos):
			return 2 if r[1] else 1
	return 0


# ---------------------------------------------------------------- helpers

## Marks a room (in the current place's coordinates) as shelter.
func roofed(x0: float, z0: float, x1: float, z1: float, h: float, warm := false) -> void:
	var a := k.xf * Vector3(x0, -0.3, z0)
	var b := k.xf * Vector3(x1, h, z1)
	rooms.append([AABB(a, Vector3.ZERO).expand(b), warm])


func gy(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.y) + lift, p.y)


func chest(pos: Vector3, yaw: float, cid: String, items: Dictionary, title := "Chest") -> LootBox:
	var c := LootBox.new()
	c.setup()
	c.id = cid
	c.title = title
	c.items = items
	add_child(c)
	c.position = pos
	c.rotation.y = yaw
	return c


func stash(pos: Vector3, size: Vector3, cid: String, items: Dictionary, title: String, verb: String) -> LootBox:
	var c := LootBox.new()
	c.setup_hidden(size, title, verb)
	c.id = cid
	c.items = items
	add_child(c)
	c.position = pos
	return c


func note(nid: String, pos: Vector3, yaw := 0.0, kind := "paper") -> Note:
	var d: Array = Lore.NOTES[nid]
	var n := Note.new()
	n.id = nid
	n.title = d[0]
	n.text = d[1]
	n.setup(kind)
	add_child(n)
	n.position = pos
	n.rotation.y = yaw
	if main and main.get("reader"):
		main.reader.register(n)
	return n


func label(text: String, pos: Vector3, yaw: float, px := 0.004, col := Color(0.07, 0.06, 0.05), fs := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = 70.0
	add_child(l)
	return l


func lamp(pos: Vector3, col: Color, energy: float, reach: float, flicker := false, shadow := false) -> OmniLight3D:
	var l: OmniLight3D = Flicker.new() if flicker else OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	if flicker:
		(l as Flicker).base = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadow
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	l.distance_fade_length = 25.0
	l.distance_fade_shadow = 35.0
	add_child(l)
	return l


## A door hinged at `pos`, its leaf running along the direction of `yaw`'s +X.
func door(pos: Vector3, yaw: float, w: float, h: float, steel := false, did := "", key := "") -> Door:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var d: Door
	if did != "" or steel:
		var ld := LockDoor.new()
		if steel:
			ld.setup_steel(w, h)
		else:
			ld.setup(w, h, "paint_green")
		if did != "":
			ld.lock(did, key)
		else:
			ld.locked = false
		d = ld
	else:
		d = Door.new()
		d.setup(w, h, "planks", "plank")
	holder.add_child(d)
	return d


## The two leaves of a walk-in container standing at `p` (see Struct.container, open = true).
func cargo_doors(p: Vector3, yaw: float, mat: String) -> void:
	var b := Basis(Vector3.UP, yaw)
	leaf(p + b * Vector3(-1.1, 0.07, 2.99), yaw, 1.09, 2.3, mat, "container", -1.9)
	leaf(p + b * Vector3(1.1, 0.07, 2.99), yaw + PI, 1.09, 2.3, mat, "container", 1.9)


## A plain working door leaf of the given style (see Door.setup); `swing` forces the way it opens.
func leaf(pos: Vector3, yaw: float, w: float, h: float, mat: String, style: String, swing := 0.0) -> Door:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var d := Door.new()
	d.swing = swing
	d.setup(w, h, mat, style)
	holder.add_child(d)
	return d


func barrier(pos: Vector3, yaw: float, size: Vector3, bid: String, intact: MeshKit, debris: MeshKit) -> Breakable:
	var b := Breakable.new()
	b.id = bid
	add_child(b)
	b.position = pos
	b.rotation.y = yaw
	b.setup(size, Vector3(0, size.y * 0.5, 0), intact.node(false), debris.node(false) if debris else null)
	return b


func spot(sid: String, title: String, pos: Vector3, r: float, kind := "place") -> void:
	spots.append({"id": sid, "name": title, "pos": pos, "r": r, "kind": kind})


func found_names() -> Array:
	var out := []
	for s in spots:
		if s["id"] in found:
			out.append(s["name"])
	return out


func flush() -> void:
	k.xf = Transform3D.IDENTITY
	kd.xf = Transform3D.IDENTITY
	add_child(k.node(true))
	add_child(kd.node(false))
	k = MeshKit.new()
	kd = MeshKit.new()
	Interior.base = Transform3D.IDENTITY


func at(origin: Vector3, yaw := 0.0) -> void:
	k.xf = Transform3D(Basis(Vector3.UP, yaw), origin)
	kd.xf = k.xf
	Interior.base = k.xf
	Struct.deco = kd


# ---------------------------------------------------------------- building

func build(t: Terrain, v: Village, m: Node) -> void:
	terrain = t
	village = v
	main = m
	rng.seed = 606
	rooms.clear()
	k = MeshKit.new()
	kd = MeshKit.new()
	_roads()
	flush()
	_bridge()
	flush()
	_settlement()
	_lookouts()
	flush()
	SiteMine.mine(self)
	flush()
	SiteMine.tunnel(self)
	flush()
	SiteMine.bunker(self, 0)
	SiteMine.bunker(self, 1)
	flush()
	SiteBase.base(self)
	flush()
	SiteBase.station(self)
	flush()
	SiteSouth.build(self)
	flush()
	if not Wilds.climb.is_empty():
		spot("summit", "Gipfelblick Summit", Wilds.climb["top"], 9.0, "view")
	print("Places: %d spots, %d documents, %d guards" % [spots.size(), get_tree().get_nodes_in_group("note").size(), crews.size()])


func _road_at(name: String, f: float) -> Array:
	var r: PackedVector3Array = roads[name]
	var q := clampi(int(f * (r.size() - 1)), 1, r.size() - 2)
	var d := (r[q + 1] - r[q - 1])
	var fw := Vector3(d.x, 0, d.z).normalized()
	return [gy(Vector2(r[q].x, r[q].z)), fw, Vector3(fw.z, 0, -fw.x)]


func _wreck(name: String, f: float, type: String, side: float, turn: float, tilt: float, loot := {}) -> void:
	var ra := _road_at(name, f)
	var p: Vector3 = ra[0] + ra[2] * side
	p.y = terrain.height_at(p.x, p.z)
	var yaw := atan2(-ra[1].x, -ra[1].z) + turn
	var root := Node3D.new()
	var bs := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), tilt)
	root.transform = Transform3D(bs, p + Vector3(0, -0.14 + absf(tilt) * 0.9, 0))
	add_child(root)
	root.add_child(VehicleMesh.body(type))
	var size := Vector3(2.0, 1.7, 4.6) if type != "snowmobile" else Vector3(1.0, 1.0, 2.6)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	body.add_child(cs)
	root.add_child(body)
	# snow on and around it, and no wheels left on two corners
	at(p, yaw)
	kd.ball(Vector3(-0.3, 1.75 + absf(tilt), 0.2), Vector3(0.9, 0.16, 1.6), "snow", 9, 4)
	k.ball(Vector3(1.3, 0.1, 0.6), Vector3(1.0, 0.45, 2.2), "snow", 9, 4)
	kd.ball(Vector3(-1.2, 0.1, -1.2), Vector3(0.8, 0.35, 1.5), "snow", 8, 4)
	for w in [Vector3(0.95, 0.3, -1.5), Vector3(-0.95, 0.3, 1.5), Vector3(-1.6, 0.14, -2.6)]:
		var wv: Vector3 = w
		kd.tube(wv - Vector3(0.14, 0, 0), wv + Vector3(0.14, 0, 0), 0.38, "black", 10)
	if not loot.is_empty():
		stash(p + bs * Vector3(0, 0.2, size.z * 0.5 + 0.2), Vector3(1.6, 1.0, 0.6), "wreck_%s_%d" % [name, int(f * 100)], loot, "Wreck", "Search wreck")


func _roads() -> void:
	at(Vector3.ZERO)
	# orange poles so a driver finds the road in a white-out
	for name in roads:
		var r: PackedVector3Array = roads[name]
		for q in range(3, r.size() - 3, 7):
			var d := r[q + 1] - r[q - 1]
			var side := Vector3(d.z, 0, -d.x).normalized() * (4.9 if (q / 7) % 2 == 0 else -4.9)
			var p := r[q] + side
			if Vector2(p.x, p.z).distance_to(Terrain.VILLAGE_POS) < Terrain.VILLAGE_R * 0.92:
				continue
			Struct.snow_pole(kd, Vector3(p.x, terrain.height_at(p.x, p.z), p.z))
	# wrecks: some hold something
	_wreck("west", 0.22, "pickup", 3.2, 0.5, 0.0, {"fuel_can": 1, "scrap": 2})
	_wreck("west", 0.47, "offroader", -3.6, 2.4, 0.3, {"9mm": 18, "bandage": 1})
	_wreck("west", 0.70, "pickup", 1.0, -0.9, 0.0)
	_wreck("west", 0.9, "offroader", -2.4, 0.2, -0.2, {"canned_food": 2, "hand_warmer": 2, "762": 10})
	_wreck("north", 0.35, "pickup", -3.4, 1.9, 0.25, {"scrap": 3, "batteries": 2})
	_wreck("north", 0.74, "tracked", 2.8, 0.3, 0.0, {"556": 30, "helmet": 1})
	_wreck("lake", 0.55, "snowmobile", 2.6, 1.1, 0.6)
	_wreck("south", 0.22, "offroader", 3.0, -0.4, 0.0, {"fuel_can": 1, "medkit": 1})
	_wreck("south", 0.52, "pickup", -2.2, 2.9, 0.0, {"12g": 10, "cloth": 2, "snow_chains": 1})
	_wreck("south", 0.78, "pickup", 1.2, 0.8, 0.35)
	_wreck("mine", 0.5, "pickup", -3.3, 0.3, 0.0, {"scrap": 4, "firewood": 2})
	var ra := _road_at("south", 0.36)
	at(ra[0] + ra[2] * 4.5, atan2(ra[1].x, ra[1].z) + 0.35)
	Struct.bus(k, Vector3(0, 0.1, 0), 0.0, 0.16)
	stash(ra[0] + ra[2] * 2.2 + ra[1] * -5.6, Vector3(1.4, 1.2, 1.0), "wreck_bus", {"wool_hat": 1, "hot_tea": 1, "painkillers": 1, "small_pack": 1}, "Bus", "Search bus")
	note("n_postcard", ra[0] + ra[2] * 2.4 + ra[1] * -3.0 + Vector3(0, 0.05, 0), 0.7)
	ra = _road_at("north", 0.55)
	at(ra[0] + ra[2] * -1.5, atan2(-ra[1].x, -ra[1].z) + 0.3)
	Struct.truck(k, Vector3.ZERO, 0.0, false, 0.7)
	stash(ra[0] + ra[2] * -1.5 + Vector3(0, 0.3, 0) - ra[1] * 2.0, Vector3(1.6, 1.4, 1.2), "wreck_truck", {"canned_food": 4, "cloth": 3, "batteries": 2, "parka": 1}, "Lorry", "Search lorry")
	# signposts (German, like everything official in the Senke)
	_signpost(HUB + Vector2(7, 4), [["TUNNEL  ·  TALAUSFAHRT", "paint_blue"], ["BERGWERK NORDSTERN", "paint_yellow"], ["EISGRUND · STATION P-7", "paint_green"]], 2.6)
	_signpost(J1 + Vector2(-7, 6), [["FORSCHUNGSSTATION POLARIS-7", "paint_blue"], ["FORT NORDWACHT · SPERRGEBIET", "paint_red"], ["EISGRUND 150 m", "paint_green"]], 0.4)
	var rb := _road_at("north", 0.86)
	at(Vector3.ZERO)
	var sp := Struct.sign(k, rb[0] + rb[2] * 5.5, atan2(-rb[1].x, -rb[1].z), 2.6, 1.2, "paint_red", 2.6)
	label("MILITÄRISCHES SPERRGEBIET\nBetreten verboten\nSCHUSSWAFFENGEBRAUCH", sp, atan2(-rb[1].x, -rb[1].z), 0.0035, Color(0.95, 0.93, 0.85))


func _signpost(p2: Vector2, boards: Array, yaw: float) -> void:
	var p := gy(p2)
	at(Vector3.ZERO)
	k.cyl(p - Vector3(0, 0.3, 0), 0.07, 3.6, "steel", 7)
	for i in boards.size():
		var b: Array = boards[i]
		var byaw := yaw + i * 0.9
		var bs := Basis(Vector3.UP, byaw)
		var c := p + Vector3(0, 3.0 - i * 0.42, 0) + bs * Vector3(1.25, 0, 0.09)
		kd.box(c, Vector3(2.6, 0.34, 0.04), str(b[1]), bs)
		kd.box(c + bs * Vector3(1.4, 0, 0), Vector3(0.24, 0.24, 0.04), str(b[1]), bs * Basis(Vector3(0, 0, 1), PI * 0.25))
		label(str(b[0]), c + bs * Vector3(0, 0, 0.025), byaw, 0.0028, Color(0.95, 0.93, 0.85))
		label(str(b[0]), c + bs * Vector3(0, 0, -0.025), byaw + PI, 0.0028, Color(0.95, 0.93, 0.85))
	kd.sphere(p + Vector3(0, 3.36, 0), 0.14, "snow", 8, 5)


func _bridge() -> void:
	var u := _u()
	var h: float = D["bridge_h"]
	var yaw := PI * 0.25                       # local -Z looks towards the station
	var o := Vector3(BRIDGE.x, h, BRIDGE.y)
	at(o, yaw)
	# two halves of a steel truss; the middle fell into the Eisklamm
	for part in [[6.5, 21.0], [-21.0, -7.0]]:
		var z0: float = part[0]
		var z1: float = part[1]
		var zc := (z0 + z1) * 0.5
		k.box(Vector3(0, -0.22, zc), Vector3(5.4, 0.4, z1 - z0), "concrete")
		kd.box(Vector3(0, 0.0, zc), Vector3(0.14, 0.02, z1 - z0 - 1.0), "paint_white")
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 2.8, -0.5, zc), Vector3(0.3, 0.9, z1 - z0), "rust")
			k.tube(Vector3(sx * 2.8, 3.2, z0 + 0.4), Vector3(sx * 2.8, 3.2, z1 - 0.4), 0.13, "rust", 6)
			var n := int((z1 - z0) / 3.5)
			for i in n + 1:
				var z := lerpf(z0 + 0.4, z1 - 0.4, float(i) / n)
				k.tube(Vector3(sx * 2.8, 0.0, z), Vector3(sx * 2.8, 3.2, z), 0.09, "rust", 6)
				if i < n:
					var zn := lerpf(z0 + 0.4, z1 - 0.4, float(i + 1) / n)
					kd.tube(Vector3(sx * 2.8, 0.0, z if i % 2 == 0 else zn), Vector3(sx * 2.8, 3.2, zn if i % 2 == 0 else z), 0.06, "rust", 5)
			kd.box(Vector3(sx * 2.8, 3.36, zc), Vector3(0.5, 0.12, z1 - z0 - 1.0), "snow")
		for i in 4:
			var z := lerpf(z0 + 0.4, z1 - 0.4, i / 3.0)
			kd.tube(Vector3(-2.8, 3.2, z), Vector3(2.8, 3.2, z), 0.07, "rust", 5)
		# pier near the break
		var pz := z0 + 3.0 if z0 > 0.0 else z1 - 3.0
		k.box(Vector3(0, -9.5, pz), Vector3(4.4, 18.0, 2.2), "concrete")
		k.box(Vector3(0, -0.75, pz), Vector3(6.2, 0.6, 2.8), "concrete")
	# torn ends: girders hanging down, bars sticking out, a slab at the bottom
	for sx: float in [-1.0, 1.0]:
		kd.box(Vector3(sx * 2.8, -1.6, 4.9), Vector3(0.3, 0.8, 4.0), "rust", Basis(Vector3.RIGHT, 0.75 * sx + 0.9))
		kd.box(Vector3(sx * 2.8, -1.2, -5.6), Vector3(0.3, 0.8, 3.4), "rust", Basis(Vector3.RIGHT, -0.8))
		kd.tube(Vector3(sx * 2.8, 3.2, 6.9), Vector3(sx * 2.4, 1.2, 4.2), 0.11, "rust", 5)
	for i in 7:
		kd.tube(Vector3(-2.2 + i * 0.7, -0.2, 6.5), Vector3(-2.3 + i * 0.75, -0.7 - (i % 3) * 0.3, 5.4 - (i % 2) * 0.4), 0.02, "rust", 4)
		kd.tube(Vector3(-2.2 + i * 0.7, -0.2, -7.0), Vector3(-2.1 + i * 0.7, -0.6 - (i % 2) * 0.4, -6.0), 0.02, "rust", 4)
	k.box(Vector3(0.6, -15.4, 0.5), Vector3(5.4, 0.4, 9.0), "concrete", Basis(Vector3.RIGHT, 0.22) * Basis(Vector3(0, 0, 1), 0.3))
	k.box(Vector3(-1.5, -15.0, -3.5), Vector3(0.3, 0.8, 9.0), "rust", Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 0.3))
	Struct.rubble(k, rng, Vector3(0, -15.9, 0), 6.0, 14, "concrete", 1.2)
	# barriers and rails on the village side, guard rails on the approaches
	for sx: float in [-1.0, 1.0]:
		Struct.guard_rail(k, Vector3(sx * 3.4, -0.1, 21.0), Vector3(sx * 4.4, -0.1, 33.0))
		Struct.guard_rail(k, Vector3(sx * 3.4, -0.1, -21.0), Vector3(sx * 4.4, -0.1, -31.0))
	# a road-closure trestle: walkers squeeze past, a vehicle knocks it over
	var bi := MeshKit.new()
	var bw := MeshKit.new()
	bi.box(Vector3(0, 0.95, 0), Vector3(3.5, 0.22, 0.05), "hazard")
	bi.box(Vector3(0, 0.55, 0), Vector3(3.5, 0.14, 0.05), "paint_red")
	for sx: float in [-1.5, 1.5]:
		for sz: float in [-1.0, 1.0]:
			bi.tube(Vector3(sx, 1.05, 0), Vector3(sx, 0.0, sz * 0.4), 0.03, "steel", 5)
	bw.box(Vector3(0.3, 0.06, 1.4), Vector3(3.5, 0.05, 0.22), "hazard", Basis(Vector3.UP, 0.5))
	bw.box(Vector3(-0.6, 0.05, 2.3), Vector3(3.5, 0.05, 0.14), "paint_red", Basis(Vector3.UP, -0.3))
	var boom := barrier(o + Basis(Vector3.UP, yaw) * Vector3(0, 0, 9.5), yaw, Vector3(3.5, 1.1, 0.5), "bridge_boom", bi, bw)
	boom.ram_mass = 250.0
	boom.tools = ["crowbar", "axe"]
	boom.what = "Road closed"
	boom.hint = "You can step past it. A vehicle would knock it over."
	boom.done_text = "You drag the trestle aside."
	var sp := Struct.sign(k, Vector3(3.6, 0, 23.0), 0.0, 2.0, 1.0, "paint_red", 2.5)
	label("BRÜCKE GESPERRT\nEinsturz · Lebensgefahr", sp, yaw, 0.0036, Color(0.95, 0.93, 0.85))
	# the emergency span stands upright on the station side until someone lowers it
	var pivot := Node3D.new()
	pivot.transform = Transform3D(Basis(Vector3.UP, yaw), o + Basis(Vector3.UP, yaw) * Vector3(0, 0.02, -7.2))
	add_child(pivot)
	span = Node3D.new()
	pivot.add_child(span)
	var sk := MeshKit.new()
	sk.box(Vector3(0, -0.1, 7.0), Vector3(4.6, 0.2, 14.0), "steel")
	for i in 20:
		sk.box(Vector3(0, 0.01, 0.4 + i * 0.7), Vector3(4.4, 0.03, 0.08), "metal")
	for sx: float in [-1.0, 1.0]:
		sk.box(Vector3(sx * 2.3, 0.2, 7.0), Vector3(0.14, 0.7, 14.0), "paint_yellow")
		sk.box(Vector3(sx * 2.3, 0.2, 13.2), Vector3(0.16, 0.72, 1.4), "hazard")
	span.add_child(sk.node(true))
	span.rotation.x = -1.42
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 2.5, 0.5, -7.6), Vector3(0.3, 1.4, 0.6), "paint_yellow")
		kd.cyl(Vector3(sx * 2.5, 1.2, -7.6), 0.3, 0.2, "metal", 10)
	# control hut with the lever, on the station side
	at(o + Basis(Vector3.UP, yaw) * Vector3(7.5, 0.0, -27.0), yaw)
	var gh := terrain.height_at(k.xf.origin.x, k.xf.origin.z) - h
	Struct.room(k, -1.6, -1.6, 1.6, 1.6, gh + 0.07, 2.4, "panel_orange", "planks_in", "panel", {"w": [[0.3, 1.0, 2.05]], "n": [[0.0, 1.2, 1.9, 1.0]], "e": [[0.0, 1.2, 1.9, 1.0]]}, 0.12)
	k.box(Vector3(0, gh + 2.75, 0), Vector3(3.9, 0.2, 3.9), "snow")
	kd.box(Vector3(0, gh + 1.55, -1.66), Vector3(1.2, 0.9, 0.02), "glass_dark")
	kd.box(Vector3(1.66, gh + 1.55, 0), Vector3(0.02, 0.9, 1.2), "glass_dark")
	Interior.table(kd, Vector3(0.8, gh + 0.1, -1.0), 0.0, 1.2, 0.6)
	bridge_lever = Lever.new()
	bridge_lever.id = "bridge_lever"
	bridge_lever.label = "Lower the emergency span"
	bridge_lever.done_text = "Steel groans. The span comes down across the gap."
	bridge_lever.setup()
	add_child(bridge_lever)
	bridge_lever.transform = Transform3D(Basis(Vector3.UP, yaw + PI), k.xf * Vector3(0.0, gh + 0.1, 1.2))
	note("n_bridge", k.xf * Vector3(0.8, gh + 0.95, -1.0), yaw + 0.3)
	label("NOTSTEG\nBrückensteuerung", k.xf * Vector3(-1.74, gh + 2.25, 0.3), yaw - PI * 0.5, 0.003, Color(0.08, 0.07, 0.06))
	lamp(k.xf * Vector3(0, gh + 2.2, 0), Color(1.0, 0.6, 0.25), 1.2, 7.0, true)
	spot("bridge", "Eisklamm Bridge", o, 30.0)
	# one car did not stop in time
	at(o + Basis(Vector3.UP, yaw) * Vector3(-0.8, -15.2, 3.5), yaw + 0.4)
	var car := VehicleMesh.body("pickup")
	car.transform = k.xf * Transform3D(Basis(Vector3.RIGHT, 1.3), Vector3(0, 1.2, 0))
	add_child(car)


func _settlement() -> void:
	var names := ["Tove's house", "Boat shed", "Smokehouse cabin", "Net loft"]
	for i in CABINS.size():
		var c := CABINS[i]
		var lit := i != 3
		var n := Chalet.build("cabin", rng, lit)
		n.position = gy(c, 0.05)
		n.rotation.y = atan2(SETTLE.x - c.x, SETTLE.y - c.y - 2.0)
		add_child(n)
		Chalet.seat(n, terrain)
		n.set_meta("lit", lit)
		cabins.append(n)
		village.houses.append(n)
		var size: Vector2 = n.get_meta("size")
		var items := Items.roll("house", rng)
		if i == 1:
			items["snow_chains"] = 1
			items["fuel_can"] = 1
		elif i == 2:
			items["canned_food"] = 4
			items["hot_tea"] = 2
		elif i == 3:
			items["rope"] = 1
			items["fur_hood"] = 1
		var ch := chest(Vector3.ZERO, PI * 0.5, "settle_%d" % i, items, names[i])
		remove_child(ch)
		n.add_child(ch)
		ch.position = Vector3(-size.x * 0.5 + 0.85, Chalet.Y0, size.y * 0.5 - 0.8)
		if lit:
			lamp(n.position + Vector3(0, 2.6, 0) + n.basis * Vector3(1.4, 0, size.y * 0.5 + 0.7), Props.WARM, 1.5, 9.0, i == 2)
	note("n_tove", cabins[0].to_global(Vector3(1.2, Chalet.Y0 + 0.02, -1.0)), 0.4)
	# the yard: fish racks, a smoke oven, nets on poles, sleds, a fire barrel
	var c0 := gy(SETTLE)
	at(c0, 0.3)
	for r in 2:
		var x := -4.0 + r * 5.0
		for sx: float in [-1.2, 1.2]:
			k.tube(Vector3(x + sx, 0, -0.5), Vector3(x + sx * 0.7, 2.2, 0), 0.05, "wood_dark", 5)
			k.tube(Vector3(x + sx, 0, 0.5), Vector3(x + sx * 0.7, 2.2, 0), 0.05, "wood_dark", 5)
		for y: float in [1.5, 2.1]:
			var yy: float = y
			kd.tube(Vector3(x - 1.0, yy, 0), Vector3(x + 1.0, yy, 0), 0.025, "wood", 5)
			for j in 7:
				kd.ball(Vector3(x - 0.8 + j * 0.27, yy - 0.2, 0), Vector3(0.035, 0.17, 0.07), "grey", 6, 4)
	k.cyl(Vector3(4.5, 0, 3.5), 0.33, 0.9, "rust", 10)
	for j in 4:
		kd.cyl(Vector3(4.5 + cos(j * 1.6) * 0.15, 0.85, 3.5 + sin(j * 1.6) * 0.15), 0.07, 0.3 + (j % 2) * 0.15, "candle", 5, 0.0)
	lamp(c0 + Vector3(4.2, 1.5, 3.9), Color(1.0, 0.5, 0.2), 2.6, 13.0, true, true)
	for j in 3:
		var a := 0.8 + j * 1.9
		k.tube(Vector3(4.5 + cos(a) * 1.8 - sin(a) * 0.7, 0.22, 3.5 + sin(a) * 1.8 + cos(a) * 0.7), Vector3(4.5 + cos(a) * 1.8 + sin(a) * 0.7, 0.22, 3.5 + sin(a) * 1.8 - cos(a) * 0.7), 0.2, "wood", 8)
	for j in 4:
		k.cyl(Vector3(-9.0 + j * 2.2, 0, 6.5), 0.05, 2.6, "wood_dark", 5)
		if j < 3:
			kd.box(Vector3(-7.9 + j * 2.2, 1.5, 6.5), Vector3(2.2, 1.6, 0.01), "chainlink")
	kd.xf = Transform3D(Basis(Vector3.UP, 1.2), c0 + Vector3(-5.5, 0.05, -5.0))
	Props.sled(kd)
	kd.xf = k.xf
	k.xf = Transform3D(Basis(Vector3.UP, 0.5), c0 + Vector3(7.5, 0, -3.0))
	Props.crate(k, 0.8)
	k.xf = Transform3D(Basis(Vector3.UP, 0.1), c0 + Vector3(8.4, 0, -2.2))
	Props.barrel(k)
	# a jetty out over the ice, with two boats frozen in beside it
	var dir := (Terrain.LAKE_POS - SETTLE).normalized()
	var s := SETTLE
	for q in 80:
		if terrain.height_at(s.x, s.y) < Terrain.LAKE_LEVEL + 0.6:
			break
		s += dir
	var jy := Terrain.LAKE_LEVEL + 1.0
	var jyaw := atan2(dir.x, dir.y)
	at(Vector3(s.x, jy, s.y), jyaw)
	k.box(Vector3(0, -0.06, 7.0), Vector3(2.0, 0.12, 22.0), "planks")
	Struct.ramp(k, Vector3(0, terrain.height_at(s.x - dir.x * 7.0, s.y - dir.y * 7.0) - jy + 0.05, -7.0), Vector3(0, 0.0, -3.9), 2.0, "planks", "wood_dark")
	for i in 8:
		for sx: float in [-1.0, 1.0]:
			k.cyl(Vector3(sx * 0.95, -2.2, -3.0 + i * 3.0), 0.09, 2.9 if i % 2 == 0 else 2.3, "wood_dark", 6)
	kd.tube(Vector3(-0.95, 0.7, -3.0), Vector3(-0.95, 0.7, 18.0), 0.02, "black", 4)
	for b in [[3.2, 9.0, 0.3, "paint_blue"], [-3.4, 14.0, -0.5, "paint_red"]]:
		var bx: float = b[0]
		var bz: float = b[1]
		var bb := Basis(Vector3.UP, float(b[2])) * Basis(Vector3(0, 0, 1), 0.12)
		k.ball(Vector3(bx, -0.75, bz), Vector3(0.85, 0.5, 2.4), str(b[3]), 10, 5, bb)
		kd.ball(Vector3(bx, -0.62, bz), Vector3(0.7, 0.3, 2.1), "snow", 10, 4, bb)
		for t2: float in [-0.8, 0.6]:
			var tt: float = t2
			kd.box(Vector3(bx, -0.5, bz + tt), Vector3(1.3, 0.05, 0.22), "planks", bb)
	lamp(Vector3(s.x, jy + 1.4, s.y) + Basis(Vector3.UP, jyaw) * Vector3(1.0, 0, 17.5), Props.WARM, 1.3, 9.0, true)
	kd.cyl(Vector3(0.95, 0.0, 17.5), 0.04, 1.5, "wood_dark", 5)
	kd.box(Vector3(0.95, 1.5, 17.5), Vector3(0.16, 0.22, 0.16), "lamp_glow")
	D["jetty"] = Vector3(s.x, jy, s.y) + Basis(Vector3.UP, jyaw) * Vector3(0, 0.05, 12.0)
	var ra := _road_at("lake", 0.93)
	at(Vector3.ZERO)
	var sp := Struct.sign(k, ra[0] + ra[2] * 5.0, atan2(-ra[1].x, -ra[1].z), 2.0, 0.6, "paint_green", 2.2)
	label("EISGRUND", sp, atan2(-ra[1].x, -ra[1].z), 0.005, Color(0.95, 0.93, 0.85))
	spot("settle", "Eisgrund", c0, 34.0)


func _lookouts() -> void:
	# the ranger's tower above the lake
	var tp := gy(TOWER)
	at(Vector3.ZERO)
	Struct.tower(k, tp, 0.6, 9.0, true)
	var top := tp + Vector3(0, 9.1, 0)
	var bs := Basis(Vector3.UP, 0.6)
	chest(top + bs * Vector3(-1.5, 0.05, -1.5), 0.6, "tower", {"scope": 1, "flare": 4, "hot_tea": 1, "762": 12}, "Ranger's box")
	note("n_ranger", top + bs * Vector3(-0.4, 0.08, -1.6), 0.9, "book")
	kd.cyl(top + bs * Vector3(-1.6, 0.0, 1.2), 0.03, 1.3, "steel", 5)
	kd.tube(top + bs * Vector3(-1.6, 1.3, 1.0), top + bs * Vector3(-1.6, 1.4, 1.6), 0.06, "metal", 8)
	var sp := Struct.sign(k, tp + bs * Vector3(4.5, 0, -5.0), 0.6 + PI, 1.6, 0.5, "paint_green", 2.0)
	label("AUSSICHT SEEBLICK", sp, 0.6 + PI, 0.003, Color(0.95, 0.93, 0.85))
	spot("tower", "Seeblick Lookout", top + Vector3(0, 1.0, 0), 4.5, "view")
	# a ledge over the mine with a bench and a cross
	var vp := gy(VIEW)
	at(vp, -PI * 0.5)
	Props.bench(k)
	k.xf = Transform3D(Basis.IDENTITY, vp + Vector3(1.0, 0, 3.0))
	k.box(Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), "wood_dark")
	k.box(Vector3(0, 2.2, 0), Vector3(1.2, 0.14, 0.14), "wood_dark")
	for j in 5:
		k.ball(Vector3(0.1 * (j % 2), 0.12 + j * 0.02, 0.0) + Vector3(cos(j * 1.3), 0, sin(j * 1.3)) * 0.35, Vector3(0.3, 0.2, 0.26), "stone", 7, 4)
	chest(vp + Vector3(1.6, 0, -2.4), 0.5, "view_mine", {"hand_warmer": 2, "canned_food": 1, "338": 6, "red_dot": 1}, "Tin box")
	spot("stollenkopf", "Stollenkopf Viewpoint", vp, 8.0, "view")


# ---------------------------------------------------------------- running

func _process(delta: float) -> void:
	if span and bridge_lever:
		span.rotation.x = move_toward(span.rotation.x, 0.0 if bridge_lever.pulled else -1.42, delta * 0.28)
	_scan -= delta
	if _scan > 0.0 or main == null or main.player == null:
		return
	_scan = 0.5
	var pp: Vector3 = main.player.global_position
	for s in spots:
		if s["id"] in found:
			continue
		var c: Vector3 = s["pos"]
		var hit := pp.distance_to(c) < float(s["r"]) if s["kind"] == "view" else Vector2(pp.x - c.x, pp.z - c.z).length() < float(s["r"]) and absf(pp.y - c.y) < 30.0
		if hit:
			found.append(str(s["id"]))
			if main.get("hud"):
				main.hud.banner("VIEWPOINT" if s["kind"] == "view" else "DISCOVERED", str(s["name"]))


func to_dict() -> Dictionary:
	var gated := {}
	for n in get_tree().get_nodes_in_group("gated"):
		if str(n.get("id")) != "":
			gated[str(n.get("id"))] = n.call("get_state")
	return {"found": found, "gated": gated, "journal": main.reader.found if main.get("reader") else []}


func from_dict(d: Dictionary) -> void:
	found.clear()
	for f in d.get("found", []):
		found.append(str(f))
	var gated: Dictionary = d.get("gated", {})
	for n in get_tree().get_nodes_in_group("gated"):
		var gid := str(n.get("id"))
		if gid != "":
			n.call("set_state", bool(gated.get(gid, false)))
	if span and bridge_lever:
		span.rotation.x = 0.0 if bridge_lever.pulled else -1.42
	if main.get("reader"):
		main.reader.found.clear()
		for j in d.get("journal", []):
			main.reader.found.append(str(j))
