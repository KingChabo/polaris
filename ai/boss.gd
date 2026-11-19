class_name Boss
extends Enemy
## Shared base of the three big fights: a name for the bar at the top of the screen,
## parts that can be shot off, phases, and a reward that only this enemy drops.

var boss_name := "Boss"
var boss_sub := ""             # one line under the name: what to do
var phase := 1
var parts := {}                # name -> {"hp", "max", "node", "label"}
var reward := {}
var reward_rep := {}
var main: Node


## Adds a part that has its own hit points. `node` is hidden when it breaks.
func add_part(pname: String, hp: float, node: Node3D, label: String) -> void:
	parts[pname] = {"hp": hp, "max": hp, "node": node, "label": label}


func part_alive(pname: String) -> bool:
	return parts.has(pname) and float(parts[pname]["hp"]) > 0.0


func parts_left() -> int:
	var n := 0
	for p in parts:
		if float(parts[p]["hp"]) > 0.0:
			n += 1
	return n


## Damage to a part. Returns true when this blow broke it.
func hurt_part(pname: String, dmg: float, pos: Vector3) -> bool:
	if not part_alive(pname):
		return false
	var p: Dictionary = parts[pname]
	p["hp"] = float(p["hp"]) - dmg
	if float(p["hp"]) > 0.0:
		return false
	p["hp"] = 0.0
	var n: Node3D = p["node"]
	if n:
		n.visible = false
	Sfx.play(get_parent(), "clank", pos, 4.0, 0.6)
	for i in 4:
		Fx.sparks(get_parent(), pos + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.4), randf_range(-0.4, 0.4)), Vector3.UP)
	if player:
		player.message.emit("%s: %s destroyed" % [boss_name, str(p["label"])])
	_part_broke(pname)
	return true


func _part_broke(_pname: String) -> void:
	pass


## For the HUD.
func bar() -> Dictionary:
	var pips := []
	for p in parts:
		pips.append(float(parts[p]["hp"]) / float(parts[p]["max"]))
	return {"name": boss_name, "sub": boss_sub, "frac": clampf(health / max_health, 0.0, 1.0), "pips": pips, "phase": phase}


func _die(dir: Vector3) -> void:
	loot = reward.duplicate()
	body_title = boss_name
	super._die(dir)


## Loading a save in which this one is already dead: lie there, no loot, no fight.
func make_dead() -> void:
	state = "dead"
	health = 0.0
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_lie_dead()


func _lie_dead() -> void:
	if model:
		model.rotation.x = PI * 0.48
		model.position.y = 0.14
