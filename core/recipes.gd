class_name Recipes
## What you can make at a workbench: [result, how many, ingredients].

const LIST := [
	["bandage", 1, {"cloth": 2}],
	["splint", 1, {"firewood": 1, "cloth": 1}],
	["hand_warmer", 2, {"batteries": 1, "cloth": 1}],
	["medkit", 1, {"bandage": 2, "painkillers": 1, "cloth": 1}],
	["9mm_ap", 10, {"9mm": 10, "scrap": 1}],
	["556_ap", 10, {"556": 10, "scrap": 1}],
	["762_ap", 10, {"762": 10, "scrap": 2}],
	["12g_slug", 6, {"12g": 6, "scrap": 1}],
	["knife", 1, {"scrap": 2, "cloth": 1}],
	["crowbar", 1, {"scrap": 4}],
	["snow_chains", 1, {"scrap": 8, "rope": 1}],
	["aux_tank", 1, {"scrap": 6, "fuel_can": 1}],
	["armor_plates", 1, {"scrap": 18}],
	["helmet", 1, {"scrap": 5, "cloth": 2}],
]


static func can_make(i: int, inv: Inventory) -> bool:
	var need: Dictionary = LIST[i][2]
	for id in need:
		if inv.count(str(id)) < int(need[id]):
			return false
	return true


static func make(i: int, inv: Inventory) -> bool:
	if not can_make(i, inv):
		return false
	var need: Dictionary = LIST[i][2]
	for id in need:
		inv.remove(str(id), int(need[id]))
	inv.add(str(LIST[i][0]), int(LIST[i][1]))
	return true
