class_name Factions
extends Node
## The four groups of the valley, what they think of you, and where they hold ground.
## Standing runs from -100 to 100 and changes prices, what traders will sell, and who shoots first.

signal changed(faction: String, delta: int, why: String)

const DEFS := {
	"village": {"name": "Polaris Villagers", "short": "Village", "start": 10, "col": Color(1.0, 0.8, 0.35)},
	"eisgrund": {"name": "Fishers of Eisgrund", "short": "Eisgrund", "start": 0, "col": Color(0.45, 0.8, 0.9)},
	"raiders": {"name": "Red Flags", "short": "Red Flags", "start": -60, "col": Color(0.92, 0.22, 0.2)},
	"nordwacht": {"name": "Garrison Nordwacht", "short": "Nordwacht", "start": -45, "col": Color(0.55, 0.65, 0.4)},
	"grauwasser": {"name": "Grauwasser Townsfolk", "short": "Grauwasser", "start": 5, "col": Color(0.75, 0.7, 0.95)},
}
const TIERS := ["Hostile", "Wary", "Neutral", "Trusted", "Ally"]

var main: Node
var rep := {}
var zones: Array = []       # [faction, centre (Vector3), radius]


func _ready() -> void:
	reset()


func reset() -> void:
	for f in DEFS:
		rep[f] = int(DEFS[f]["start"])


func setup_zones() -> void:
	zones.clear()
	var v := Terrain.VILLAGE_POS
	zones.append(["village", Vector3(v.x, 0, v.y + 20.0), 150.0])
	zones.append(["raiders", Vector3(v.x + 80.0, 0, v.y - 100.0), 34.0])
	zones.append(["eisgrund", Vector3(Places.SETTLE.x, 0, Places.SETTLE.y), 48.0])
	zones.append(["nordwacht", Vector3(Places.BASE.x, 0, Places.BASE.y), 75.0])
	zones.append(["grauwasser", Vector3(SiteSouth.TOWN.x, 0, SiteSouth.TOWN.y), 140.0])
	zones.append(["grauwasser", Vector3(SiteSouth.STRIP.x, 0, SiteSouth.STRIP.y), 60.0])
	zones.append(["nordwacht", Vector3(SiteSouth.CHECK.x, 0, SiteSouth.CHECK.y), 45.0])
	zones.append(["raiders", Vector3(SiteSouth.MILL.x, 0, SiteSouth.MILL.y), 60.0])
	for c: Vector2 in SiteSouth.RAID_CAMPS:
		zones.append(["raiders", Vector3(c.x, 0, c.y), 40.0])
	if main and main.get("wilds"):
		for c in main.wilds.camps:
			var p: Vector3 = c
			zones.append(["raiders", Vector3(p.x, 0, p.z), 42.0])


## Whose ground this is ("" = nobody's). Small zones win over big ones.
func at(pos: Vector3) -> String:
	var best := ""
	var best_r := 1e9
	for z in zones:
		var c: Vector3 = z[1]
		var r: float = z[2]
		if Vector2(pos.x - c.x, pos.z - c.z).length() < r and r < best_r:
			best = str(z[0])
			best_r = r
	return best


func add(f: String, n: int, why := "") -> void:
	if not rep.has(f) or n == 0:
		return
	var before := tier(f)
	rep[f] = clampi(int(rep[f]) + n, -100, 100)
	changed.emit(f, n, why)
	if main and main.get("player"):
		var line := "%s %+d" % [DEFS[f]["short"], n]
		if tier(f) != before:
			line += "  —  now %s" % TIERS[tier(f)]
		main.player.message.emit(line)


## 0 hostile, 1 wary, 2 neutral, 3 trusted, 4 ally.
func tier(f: String) -> int:
	var r := int(rep.get(f, 0))
	if r < -30:
		return 0
	if r < 0:
		return 1
	if r < 30:
		return 2
	if r < 70:
		return 3
	return 4


func tier_name(f: String) -> String:
	return TIERS[tier(f)]


func hostile(f: String) -> bool:
	return tier(f) == 0


## What you pay: friends get a discount, strangers pay more.
func buy_mult(f: String) -> float:
	return [1.6, 1.4, 1.25, 1.1, 1.0][tier(f)]


## What you get when you sell.
func sell_mult(f: String) -> float:
	return [0.25, 0.35, 0.45, 0.55, 0.65][tier(f)]


func to_dict() -> Dictionary:
	return rep.duplicate()


func from_dict(d: Dictionary) -> void:
	reset()
	for f in d:
		if rep.has(str(f)):
			rep[str(f)] = int(d[f])
