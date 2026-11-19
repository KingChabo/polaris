class_name Items
## Every item in the game. Clothing has real trade-offs: warm and armoured gear
## is heavy and slows you down.
## slot: head / body / legs / feet / hands / armor / pack  (clothing)
## use:  what happens when you use a consumable

const SLOTS := ["head", "body", "legs", "feet", "hands", "armor", "pack"]
const SLOT_NAMES := {"head": "Head", "body": "Body", "legs": "Legs", "feet": "Feet", "hands": "Hands", "armor": "Armour", "pack": "Backpack"}

const DB := {
	# --- clothing
	"wool_hat": {"name": "Wool hat", "slot": "head", "w": 0.2, "warm": 8, "value": 12},
	"fur_hood": {"name": "Fur hood", "slot": "head", "w": 0.6, "warm": 15, "mob": 0.01, "value": 40},
	"helmet": {"name": "Steel helmet", "slot": "head", "w": 1.4, "warm": 3, "armor": 12, "mob": 0.02, "value": 60},
	"light_jacket": {"name": "Light jacket", "slot": "body", "w": 0.9, "warm": 10, "value": 15},
	"parka": {"name": "Parka", "slot": "body", "w": 2.5, "warm": 30, "mob": 0.04, "value": 90},
	"expedition_suit": {"name": "Expedition suit", "slot": "body", "w": 4.5, "warm": 46, "armor": 4, "mob": 0.10, "value": 260},
	"jeans": {"name": "Jeans", "slot": "legs", "w": 0.7, "warm": 5, "value": 8},
	"snow_pants": {"name": "Snow trousers", "slot": "legs", "w": 1.5, "warm": 18, "mob": 0.03, "value": 55},
	"boots": {"name": "Leather boots", "slot": "feet", "w": 1.2, "warm": 8, "value": 20},
	"fur_boots": {"name": "Fur boots", "slot": "feet", "w": 1.8, "warm": 16, "mob": 0.02, "value": 60},
	"gloves": {"name": "Gloves", "slot": "hands", "w": 0.15, "warm": 6, "value": 10},
	"mittens": {"name": "Thick mittens", "slot": "hands", "w": 0.3, "warm": 12, "mob": 0.01, "value": 28},
	"kevlar_vest": {"name": "Kevlar vest", "slot": "armor", "w": 3.5, "warm": 3, "armor": 25, "mob": 0.05, "value": 180},
	"plate_carrier": {"name": "Plate carrier", "slot": "armor", "w": 8.0, "warm": 4, "armor": 50, "mob": 0.12, "value": 420},
	# --- one of a kind: only the three great enemies of the valley carry these
	"frost_pelt": {"name": "Pelt of the White One", "slot": "body", "w": 3.0, "warm": 60, "armor": 10, "mob": 0.05, "value": 900, "info": "Warmer than anything sewn by hand. Cut from the beast of the lake."},
	"commander_coat": {"name": "Colonel's greatcoat", "slot": "body", "w": 3.2, "warm": 38, "armor": 20, "mob": 0.04, "value": 800, "info": "Lined with ballistic cloth. Falk's name is stitched inside."},
	"plate_harness": {"name": "K-9 plate harness", "slot": "armor", "w": 6.0, "warm": 2, "armor": 64, "mob": 0.09, "value": 950, "info": "Hull plate from the mining machine on a miner's harness. Lighter than it looks."},
	"small_pack": {"name": "Small backpack", "slot": "pack", "w": 0.8, "carry": 10, "value": 45},
	"large_pack": {"name": "Expedition backpack", "slot": "pack", "w": 2.0, "carry": 25, "mob": 0.04, "value": 150},
	# --- consumables
	"canned_food": {"name": "Canned food", "w": 0.4, "use": "food", "value": 10, "info": "Fills you up: stamina comes back faster for a while."},
	"hot_tea": {"name": "Thermos of tea", "w": 0.5, "use": "tea", "value": 14, "info": "Warms you up at once."},
	"hand_warmer": {"name": "Hand warmer", "w": 0.1, "use": "warmer", "value": 9, "info": "Slow warmth for two minutes."},
	"bandage": {"name": "Bandage", "w": 0.1, "use": "bandage", "value": 12, "info": "Stops bleeding, heals a little."},
	"medkit": {"name": "First-aid kit", "w": 0.8, "use": "medkit", "value": 70, "info": "Heals a lot and stops bleeding."},
	"splint": {"name": "Splint", "w": 0.4, "use": "splint", "value": 25, "info": "Fixes a sprained ankle."},
	"painkillers": {"name": "Painkillers", "w": 0.05, "use": "pills", "value": 30, "info": "You ignore injuries for 90 seconds."},
	# --- materials (for trade and crafting later)
	"scrap": {"name": "Scrap metal", "w": 1.0, "value": 6, "info": "Repairs a vehicle engine by 25 % at the bonnet."},
	"cloth": {"name": "Cloth", "w": 0.2, "value": 3},
	"firewood": {"name": "Firewood", "w": 1.5, "value": 4},
	"batteries": {"name": "Batteries", "w": 0.2, "value": 15},
	"rope": {"name": "Climbing rope", "w": 3.0, "value": 60, "info": "Catches you when your grip gives out, and lets you abseil fast without tiring."},
	"fuel_can": {"name": "Fuel can", "w": 4.0, "value": 35, "info": "20 litres. Pour it in at the bonnet of a vehicle."},
	# --- money and things people ask you to carry
	"coin": {"name": "Kronen", "w": 0.0, "value": 1, "info": "Money. Traders in the village and in Eisgrund take it."},
	"parcel": {"name": "Marta's parcel", "w": 2.0, "quest": true, "value": 0, "info": "Jam, wool and a letter for Tove in Eisgrund."},
	"fuse": {"name": "Fuse", "w": 0.05, "quest": true, "value": 0, "info": "A heavy old ceramic fuse. The fuse box behind the hotel takes three."},
	"core_heart": {"name": "Heart of Core 31", "w": 1.5, "quest": true, "value": 0, "info": "A fist of blue ice that stays cold in your hand and pulses with the aurora. It is still alive."},
	"blasting_charge": {"name": "Blasting charge", "w": 3.0, "tool": true, "quest": true, "value": 0, "info": "Arvid's blasting gelatine with a slow fuse. Enough to clear a rockfall."},
	"relay_fuse": {"name": "Relay fuse", "w": 0.3, "quest": true, "value": 0, "info": "A heavy ceramic fuse for the Hochfunk transmitter."},
	"rotor_hub": {"name": "Rotor hub", "w": 9.0, "quest": true, "value": 0, "info": "A spare main rotor hub, still in army grease paper."},
	"flight_manifest": {"name": "Flight manifest", "w": 0.05, "quest": true, "value": 0, "info": "Six seats, one flight. Whoever holds this paper decides who is on it."},
	"wolf_pelt": {"name": "Wolf pelt", "w": 1.4, "value": 22, "info": "Traders pay for a clean pelt."},
	"grey_pelt": {"name": "Pelt of the Grey Mother", "slot": "body", "w": 3.4, "warm": 52, "armor": 16, "mob": 0.05, "value": 850, "info": "Frost grew through the fur and never melted."},
	"hollow_ash": {"name": "Hollow ash", "w": 0.2, "value": 30, "info": "Cold grey ash that will not blow away. Traders want it and do not say why."},
	"bounty_tag": {"name": "Red Flag tag", "w": 0.05, "value": 18, "info": "A raider's cloth tag. The notice boards pay for these."},
	"dead_letter": {"name": "Letter for Oda", "w": 0.05, "quest": true, "value": 0, "info": "Found in a dead man's coat. Addressed to the Einödhof."},
	"supply_crate": {"name": "Supply crate", "w": 6.0, "quest": true, "value": 0, "info": "A board job: carry it to the notice board in the other settlement."},
	"medicine_crate": {"name": "Crate of antibiotics", "w": 5.0, "quest": true, "value": 0, "info": "Army stock. Enough for one settlement, not for two."},
	# --- tools and keys: they open the closed parts of the valley
	"crowbar": {"name": "Crowbar", "w": 1.6, "tool": true, "value": 30, "info": "Pries boards off doors and forces jammed hatches."},
	"bolt_cutters": {"name": "Bolt cutters", "w": 2.2, "tool": true, "value": 55, "info": "Cuts chain-link fence."},
	"key_mine": {"name": "Mine gate key", "w": 0.05, "key": true, "value": 0, "info": "Opens the iron gate deep in the Nordstern mine."},
	"key_bunker": {"name": "Bunker key", "w": 0.05, "key": true, "value": 0, "info": "A heavy key stamped B-2. Opens the command bunker by the base."},
	"key_armory": {"name": "Armoury key", "w": 0.05, "key": true, "value": 0, "info": "Opens the armoury in the command post of the base."},
	"keycard_lab": {"name": "Lab keycard", "w": 0.02, "key": true, "value": 0, "info": "Polaris-7, clearance C. Opens the laboratory of the research station."},
	# --- vehicle upgrades: carry them to the bonnet and press E
	"snow_chains": {"name": "Snow chains", "w": 8.0, "upgrade": true, "value": 140, "info": "Vehicle upgrade. Far better grip on ice and snow, lower top speed."},
	"armor_plates": {"name": "Armour plates", "w": 24.0, "upgrade": true, "value": 320, "info": "Vehicle upgrade. Shrugs off bullets and crashes, but adds 380 kg: slower, and thin ice breaks sooner."},
	"aux_tank": {"name": "Extra fuel tank", "w": 6.0, "upgrade": true, "value": 160, "info": "Vehicle upgrade. 40 litres more fuel."},
	"winch_kit": {"name": "Winch kit", "w": 14.0, "upgrade": true, "value": 240, "info": "Vehicle upgrade. A winch for vehicles that have none."},
	# --- guns (stats are in combat/weapons.gd)
	"pistol": {"name": "Pistol", "w": 0.9, "weapon": true, "value": 120},
	"revolver": {"name": "Revolver", "w": 1.2, "weapon": true, "value": 160},
	"smg": {"name": "Submachine gun", "w": 2.8, "weapon": true, "value": 300},
	"assault_rifle": {"name": "Assault rifle", "w": 3.6, "weapon": true, "value": 520},
	"shotgun": {"name": "Pump shotgun", "w": 3.4, "weapon": true, "value": 340},
	"marksman_rifle": {"name": "Marksman rifle", "w": 4.4, "weapon": true, "value": 700},
	"sniper_rifle": {"name": "Sniper rifle", "w": 6.2, "weapon": true, "value": 1100},
	"flare_gun": {"name": "Flare gun", "w": 0.6, "weapon": true, "value": 60, "info": "Lights up the dark and scares animals away."},
	# --- melee
	"knife": {"name": "Hunting knife", "w": 0.3, "weapon": true, "value": 25, "info": "Fast, short reach."},
	"ice_pick": {"name": "Ice pick", "w": 0.7, "weapon": true, "value": 45, "info": "Punches through armour."},
	"axe": {"name": "Wood axe", "w": 1.8, "weapon": true, "value": 40, "info": "Slow, heavy blows."},
	"sword": {"name": "Old sabre", "w": 1.4, "weapon": true, "value": 380, "info": "Long reach, the best block."},
	# --- ammunition
	"9mm": {"name": "9 mm rounds", "w": 0.012, "ammo": true, "pen": 5, "value": 1},
	"9mm_ap": {"name": "9 mm armour-piercing", "w": 0.012, "ammo": true, "pen": 40, "dmg": 0.9, "value": 3},
	"357": {"name": ".357 rounds", "w": 0.016, "ammo": true, "pen": 15, "value": 2},
	"556": {"name": "5.56 rounds", "w": 0.012, "ammo": true, "pen": 25, "value": 2},
	"556_ap": {"name": "5.56 armour-piercing", "w": 0.012, "ammo": true, "pen": 60, "dmg": 0.9, "value": 5},
	"762": {"name": "7.62 rounds", "w": 0.025, "ammo": true, "pen": 35, "value": 3},
	"762_ap": {"name": "7.62 armour-piercing", "w": 0.025, "ammo": true, "pen": 70, "dmg": 0.9, "value": 7},
	"338": {"name": ".338 rounds", "w": 0.04, "ammo": true, "pen": 50, "value": 8},
	"12g": {"name": "Buckshot shells", "w": 0.045, "ammo": true, "pen": 0, "value": 2},
	"12g_slug": {"name": "Slug shells", "w": 0.045, "ammo": true, "pen": 20, "value": 4, "info": "One heavy bullet instead of pellets."},
	"flare": {"name": "Flares", "w": 0.08, "ammo": true, "pen": 0, "value": 6},
	# --- weapon mods
	"red_dot": {"name": "Red-dot sight", "w": 0.15, "mod": "sight", "value": 80, "info": "Aims faster and tighter."},
	"scope": {"name": "4× scope", "w": 0.4, "mod": "sight", "value": 160, "info": "4× zoom, slower to raise."},
	"silencer": {"name": "Silencer", "w": 0.3, "mod": "muzzle", "value": 140, "info": "Much quieter, no flash, bullets a little slower."},
	"muzzle_brake": {"name": "Muzzle brake", "w": 0.1, "mod": "muzzle", "value": 70, "info": "Less recoil, louder."},
	"grip": {"name": "Fore grip", "w": 0.15, "mod": "grip", "value": 60, "info": "Less recoil and less spread in long bursts."},
	"ext_mag": {"name": "Extended magazine", "w": 0.2, "mod": "mag", "value": 90, "info": "Half again as many rounds, slower reload."},
}


static func get_item(id: String) -> Dictionary:
	return DB.get(id, {"name": id, "w": 0.0})


## Rarity: 0 common, 1 uncommon, 2 rare, 3 epic. Follows what a thing is worth.
static func tier(id: String) -> int:
	var it := get_item(id)
	var v := float(it.get("value", 0))
	if it.has("ammo"):
		v *= 30.0
	if it.has("key") or it.has("quest"):
		return 2
	if v < 30.0:
		return 0
	if v < 130.0:
		return 1
	if v < 420.0:
		return 2
	return 3


static func name_of(id: String) -> String:
	return str(get_item(id).get("name", id))


static func num(id: String, key: String) -> float:
	return float(get_item(id).get(key, 0.0))


## Short text with everything that matters about an item.
static func describe(id: String) -> String:
	var it := get_item(id)
	var parts: Array[String] = [name_of(id), ("%.1f kg" if float(it.get("w", 0.0)) >= 0.1 else "%.2f kg") % float(it.get("w", 0.0))]
	if it.has("weapon"):
		parts.append(Weapons.describe(id))
	if it.has("ammo"):
		parts.append("Ignores %d armour" % int(it.get("pen", 0)))
	if it.has("mod"):
		parts.append("Weapon part (%s). Click to fit it to the weapon in your hands." % str(it["mod"]))
	if it.has("slot"):
		parts.append("Worn on: " + str(SLOT_NAMES[it["slot"]]))
	if it.has("warm"):
		parts.append("Warmth +%d" % int(it["warm"]))
	if it.has("armor"):
		parts.append("Armour +%d" % int(it["armor"]))
	if it.has("carry"):
		parts.append("Carry +%d kg" % int(it["carry"]))
	if it.has("mob"):
		parts.append("Speed -%d %%" % int(round(float(it["mob"]) * 100.0)))
	if it.has("info"):
		parts.append(str(it["info"]))
	parts.append("Worth %d" % int(it.get("value", 0)))
	return "\n".join(parts)


const LOOT := {
	"house": ["coin", "coin", "canned_food", "canned_food", "bandage", "firewood", "firewood", "cloth", "cloth", "scrap", "wool_hat", "gloves", "hot_tea", "hand_warmer", "snow_pants", "batteries", "painkillers", "fur_boots", "small_pack", "parka", "splint", "9mm", "9mm", "12g", "knife", "357"],
	"toyshop": ["coin", "scrap", "batteries", "batteries", "cloth", "small_pack", "hand_warmer", "hand_warmer", "gloves", "wool_hat", "flare"],
	"restaurant": ["coin", "coin", "canned_food", "canned_food", "canned_food", "hot_tea", "hot_tea", "firewood", "bandage", "cloth", "12g", "knife"],
	"hotel": ["coin", "coin", "coin", "parka", "fur_hood", "mittens", "snow_pants", "fur_boots", "medkit", "painkillers", "canned_food", "hot_tea", "bandage", "357", "9mm", "silencer"],
	"station": ["fuel_can", "scrap", "scrap", "splint", "medkit", "helmet", "batteries", "expedition_suit", "plate_carrier", "bandage", "556", "556", "762", "556_ap", "muzzle_brake", "ext_mag"],
}


static func roll(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var table: Array = LOOT.get(kind, LOOT["house"])
	var out := {}
	for i in rng.randi_range(2, 4):
		var id: String = table[rng.randi() % table.size()]
		out[id] = int(out.get(id, 0)) + (rng.randi_range(6, 16) if (get_item(id).has("ammo") or id == "coin") else 1)
	return out
