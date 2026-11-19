class_name Inventory
extends RefCounted
## What the player carries and wears.

signal changed

const BASE_CARRY := 32.0

var items := {}      # id -> count (carried, not worn)
var equipped := {}   # slot -> id


func add(id: String, n := 1) -> void:
	items[id] = int(items.get(id, 0)) + n
	changed.emit()


func remove(id: String, n := 1) -> bool:
	var have := int(items.get(id, 0))
	if have < n:
		return false
	if have == n:
		items.erase(id)
	else:
		items[id] = have - n
	changed.emit()
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func equip(id: String) -> bool:
	var slot := str(Items.get_item(id).get("slot", ""))
	if slot == "" or count(id) == 0:
		return false
	var old := str(equipped.get(slot, ""))
	items[id] = count(id) - 1
	if items[id] <= 0:
		items.erase(id)
	if old != "":
		items[old] = int(items.get(old, 0)) + 1
	equipped[slot] = id
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if equipped.has(slot):
		var id: String = equipped[slot]
		equipped.erase(slot)
		items[id] = int(items.get(id, 0)) + 1
		changed.emit()


func _worn(key: String) -> float:
	var t := 0.0
	for slot in equipped:
		t += Items.num(equipped[slot], key)
	return t


func weight() -> float:
	var t := _worn("w") * 0.5   # worn things sit better than carried ones
	for id in items:
		t += Items.num(id, "w") * int(items[id])
	return t


func capacity() -> float:
	return BASE_CARRY + _worn("carry")


func warmth() -> float:
	return _worn("warm")


func armor() -> float:
	return _worn("armor")


## Speed factor from stiff, heavy clothing (1.0 = free).
func mobility() -> float:
	return clampf(1.0 - _worn("mob"), 0.5, 1.0)


func to_dict() -> Dictionary:
	return {"items": items.duplicate(), "equipped": equipped.duplicate()}


func from_dict(d: Dictionary) -> void:
	items.clear()
	equipped.clear()
	var it: Dictionary = d.get("items", {})
	for id in it:
		items[str(id)] = int(it[id])
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		equipped[str(slot)] = str(eq[slot])
	changed.emit()
