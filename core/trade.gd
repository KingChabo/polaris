class_name Trade
extends Node
## Traders: who sells what, how stock changes, and what things cost today.
## Money is the Krone ("coin"). Prices follow your standing with the trader's faction,
## how much of a thing the trader has left, and what that trader is keen on.

const RESTOCK := 480.0      # seconds of play between deliveries

# pool rows: [item, most they stock, lowest standing tier that may buy it]
const TRADERS := {
	"pavel": {"faction": "village", "title": "Pavel's market stall", "keen": {"scrap": 1.6, "batteries": 1.3, "cloth": 1.3},
		"pool": [["canned_food", 5, 0], ["hot_tea", 3, 0], ["hand_warmer", 4, 0], ["bandage", 4, 0], ["cloth", 6, 0], ["batteries", 4, 0],
			["wool_hat", 1, 1], ["gloves", 1, 1], ["small_pack", 1, 2], ["snow_pants", 1, 2], ["painkillers", 2, 2], ["parka", 1, 2],
			["medkit", 1, 3], ["large_pack", 1, 3], ["expedition_suit", 1, 4]]},
	"jonas": {"faction": "village", "title": "Jonas's garage", "keen": {"scrap": 1.4, "fuel_can": 1.3},
		"pool": [["fuel_can", 3, 0], ["scrap", 8, 0], ["batteries", 3, 0], ["rope", 1, 1], ["snow_chains", 1, 2], ["aux_tank", 1, 2],
			["crowbar", 1, 2], ["winch_kit", 1, 3], ["armor_plates", 1, 4]]},
	"ilse": {"faction": "village", "title": "Ilse's arms locker", "keen": {"9mm": 1.5, "556": 1.5, "762": 1.5, "12g": 1.5},
		"pool": [["9mm", 60, 1], ["12g", 20, 1], ["357", 18, 2], ["556", 60, 2], ["762", 30, 2], ["flare", 6, 1], ["knife", 1, 1],
			["pistol", 1, 2], ["helmet", 1, 2], ["9mm_ap", 30, 3], ["556_ap", 30, 3], ["kevlar_vest", 1, 3], ["shotgun", 1, 3],
			["762_ap", 20, 4], ["marksman_rifle", 1, 4], ["plate_carrier", 1, 4]]},
	"marta": {"faction": "village", "title": "Gasthaus zum Hirschen", "keen": {"firewood": 1.8, "canned_food": 1.2},
		"pool": [["hot_tea", 6, 0], ["canned_food", 8, 0], ["firewood", 4, 0], ["hand_warmer", 3, 1], ["painkillers", 1, 2]]},
	"sigrid": {"faction": "grauwasser", "title": "Kaufhaus Halden", "keen": {"wolf_pelt": 1.6, "hollow_ash": 1.5, "bounty_tag": 1.4, "canned_food": 1.3},
		"pool": [["canned_food", 8, 0], ["hot_tea", 4, 0], ["bandage", 6, 0], ["cloth", 6, 0], ["batteries", 6, 0], ["hand_warmer", 5, 0], ["firewood", 6, 0],
			["fuel_can", 2, 1], ["painkillers", 3, 1], ["splint", 2, 1], ["parka", 1, 1], ["snow_pants", 1, 1], ["fur_boots", 1, 2], ["medkit", 2, 2],
			["large_pack", 1, 2], ["rope", 1, 2], ["expedition_suit", 1, 3], ["flare", 8, 1]]},
	"brandt": {"faction": "grauwasser", "title": "Hangar stores", "keen": {"fuel_can": 1.6, "scrap": 1.4, "batteries": 1.3},
		"pool": [["fuel_can", 2, 0], ["scrap", 10, 0], ["flare", 10, 0], ["9mm", 60, 1], ["556", 90, 1], ["762", 40, 1], ["12g", 24, 1], ["338", 12, 2],
			["556_ap", 40, 2], ["762_ap", 30, 2], ["kevlar_vest", 1, 2], ["helmet", 1, 1], ["scope", 1, 3], ["silencer", 1, 3], ["ext_mag", 1, 2],
			["plate_carrier", 1, 3], ["assault_rifle", 1, 3], ["sniper_rifle", 1, 4]]},
	"mikkel": {"faction": "eisgrund", "title": "Mikkel's boat shed", "keen": {"rope": 1.4, "scrap": 1.3, "firewood": 1.5},
		"pool": [["canned_food", 6, 0], ["rope", 2, 0], ["firewood", 6, 0], ["ice_pick", 1, 1], ["fur_boots", 1, 1], ["mittens", 1, 1],
			["fur_hood", 1, 2], ["splint", 2, 2], ["axe", 1, 2], ["12g_slug", 12, 3], ["bolt_cutters", 1, 3], ["338", 10, 4]]},
}

var main: Node
var stock := {}             # trader id -> {item: count}
var clock := 0.0            # seconds of play
var wave := 0               # how many deliveries have come
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	restock()


func _process(delta: float) -> void:
	clock += delta
	if int(clock / RESTOCK) > wave:
		wave = int(clock / RESTOCK)
		restock()
		if main and main.get("player"):
			main.player.message.emit("The traders have new stock.")


func is_trader(id: String) -> bool:
	return TRADERS.has(id)


func faction_of(id: String) -> String:
	return str(TRADERS[id]["faction"]) if TRADERS.has(id) else ""


## A fresh delivery: each trader gets a random part of the pool, in random amounts.
func restock() -> void:
	for id in TRADERS:
		_rng.seed = hash(id) + wave * 7919
		var s := {}
		for row in TRADERS[id]["pool"]:
			var most := int(row[1])
			if _rng.randf() < 0.78:
				var n := _rng.randi_range(maxi(1, most / 2), most)
				s[str(row[0])] = n
		stock[id] = s


func _min_tier(id: String, item: String) -> int:
	for row in TRADERS[id]["pool"]:
		if str(row[0]) == item:
			return int(row[2])
	return 0


func _factions() -> Factions:
	return main.factions if main else null


## Rows for the shop window: [item, count, price, locked text].
func offers(id: String) -> Array:
	var out := []
	var f := _factions()
	var s: Dictionary = stock.get(id, {})
	for row in TRADERS[id]["pool"]:
		var item := str(row[0])
		var n := int(s.get(item, 0))
		if n <= 0:
			continue
		var need := int(row[2])
		var locked := ""
		if f and f.tier(faction_of(id)) < need:
			locked = "needs %s" % Factions.TIERS[need]
		out.append([item, n, buy_price(id, item), locked])
	return out


func buy_price(id: String, item: String) -> int:
	var base := Items.num(item, "value")
	var f := _factions()
	var m := f.buy_mult(faction_of(id)) if f else 1.25
	var left := int((stock.get(id, {}) as Dictionary).get(item, 0))
	var scarce := 1.25 if left <= 1 and not Items.get_item(item).has("ammo") else 1.0
	return maxi(1, int(ceil(base * m * scarce)))


func sell_price(id: String, item: String) -> int:
	var it := Items.get_item(item)
	if it.has("key") or item == "coin" or it.has("quest"):
		return 0
	var base := Items.num(item, "value")
	var f := _factions()
	var m := f.sell_mult(faction_of(id)) if f else 0.45
	var keen: Dictionary = TRADERS[id].get("keen", {})
	m *= float(keen.get(item, 1.0))
	# the more of it they already have, the less they want another
	var have := int((stock.get(id, {}) as Dictionary).get(item, 0))
	var per := 40.0 if it.has("ammo") else 4.0
	m /= 1.0 + have / per * 0.5
	return int(floor(base * m)) if base >= 2.0 else (1 if m > 0.8 else 0)


func can_trade(id: String) -> bool:
	var f := _factions()
	return f == null or not f.hostile(faction_of(id))


## Returns "" when the deal went through, otherwise why not.
func buy(id: String, item: String, inv: Inventory) -> String:
	var s: Dictionary = stock.get(id, {})
	if int(s.get(item, 0)) <= 0:
		return "Sold out."
	var f := _factions()
	if f and f.tier(faction_of(id)) < _min_tier(id, item):
		return "Not for strangers."
	var lot := mini(10, int(s[item])) if Items.get_item(item).has("ammo") else 1
	var price := buy_price(id, item) * lot
	if inv.count("coin") < price:
		return "Not enough Kronen."
	inv.remove("coin", price)
	inv.add(item, lot)
	s[item] = int(s[item]) - lot
	return ""


func sell(id: String, item: String, inv: Inventory) -> String:
	if inv.count(item) <= 0:
		return "You have none."
	var lot := mini(10, inv.count(item)) if Items.get_item(item).has("ammo") else 1
	var total := sell_quote(id, item, inv)
	if total <= 0:
		return "Not interested."
	inv.remove(item, lot)
	inv.add("coin", total)
	var s: Dictionary = stock.get(id, {})
	s[item] = int(s.get(item, 0)) + lot
	stock[id] = s
	return ""


## What a lot of this would fetch right now (for the shop window).
func sell_quote(id: String, item: String, inv: Inventory) -> int:
	var it := Items.get_item(item)
	if it.has("ammo"):
		var lot := mini(10, inv.count(item))
		var have := int((stock.get(id, {}) as Dictionary).get(item, 0))
		var m := (_factions().sell_mult(faction_of(id)) if _factions() else 0.45) / (1.0 + have / 40.0 * 0.5)
		return maxi(1, int(Items.num(item, "value") * lot * m))
	return sell_price(id, item)


func to_dict() -> Dictionary:
	return {"stock": stock, "clock": clock, "wave": wave}


func from_dict(d: Dictionary) -> void:
	clock = float(d.get("clock", 0.0))
	wave = int(d.get("wave", 0))
	restock()
	var st: Dictionary = d.get("stock", {})
	for id in st:
		if TRADERS.has(str(id)):
			var s := {}
			for item in st[id]:
				s[str(item)] = int(st[id][item])
			stock[str(id)] = s
