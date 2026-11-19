class_name Breakable
extends StaticBody3D
## Something in the way that can be smashed: boards over a door, a fence panel, a gate.
## Blows and bullets wear it down; the right tool opens it at once.

signal broke

var id := ""
var hp := 120.0
var tools: Array = []          # item ids that open it with E
var what := "Boarded up"
var hint := "An axe or a crowbar would open it."
var done_text := "The boards come away."
var broken := false
var prompt := ""
var whole: Node3D              # shown while intact
var wreck: Node3D              # shown once broken
var tool_only := false         # blows and bullets do nothing
var inside := Vector3.ZERO     # local direction of the side from which E simply opens it
var inside_text := ""
var ram_mass := 0.0            # > 0: a vehicle at least this heavy can ram it open
var _cs: CollisionShape3D


func setup(size: Vector3, center: Vector3, intact: Node3D, debris: Node3D = null) -> void:
	add_to_group("gated")
	prompt = what
	whole = intact
	wreck = debris
	add_child(whole)
	if wreck:
		wreck.visible = false
		add_child(wreck)
	var shape := BoxShape3D.new()
	shape.size = size
	_cs = CollisionShape3D.new()
	_cs.shape = shape
	_cs.position = center
	add_child(_cs)


func hit(dmg: float, _pos: Vector3, _dir: Vector3, _pen: float, _shooter: Node) -> void:
	if broken or ram_mass > 0.0 or tool_only:
		return
	hp -= dmg
	if hp <= 0.0:
		smash()


func interact(who: Node3D) -> void:
	if broken:
		return
	if inside != Vector3.ZERO and (who.global_position - global_position).dot(global_basis * inside) > 0.0:
		who.message.emit(inside_text)
		smash()
		return
	for t in tools:
		if who.inv.count(str(t)) > 0 or who.arms.held == str(t):
			who.message.emit(done_text)
			smash()
			return
	who.message.emit(what + ". " + hint)


## Called by a vehicle that drives into it.
func rammed(speed: float, mass: float) -> bool:
	if broken or ram_mass <= 0.0 or mass < ram_mass or speed < 6.0:
		return false
	smash()
	return true


func smash(quiet := false) -> void:
	if broken:
		return
	broken = true
	prompt = ""
	whole.visible = false
	if wreck:
		wreck.visible = true
	_cs.set_deferred("disabled", true)
	collision_layer = 0
	if not quiet:
		Sfx.play(get_tree().current_scene, "thud", global_position, 3.0, 0.7)
		broke.emit()


func get_state() -> bool:
	return broken


func set_state(v: bool) -> void:
	if v:
		smash(true)
	elif broken:
		broken = false
		prompt = what
		whole.visible = true
		if wreck:
			wreck.visible = false
		_cs.disabled = false
		collision_layer = 1
