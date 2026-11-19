class_name GreyMother
extends Wolf
## The Grey Mother: the old she-wolf of the Steinbruch, twice the size of her pack and
## white with frost. She never runs. Twice she howls and the pack comes down from the rim.

var boss_name := "The Grey Mother"
var boss_sub := "She lunges after she circles. Step aside, then strike."
var phase := 1
var reward := {}
var main: Node
var calls := 0
var den := Vector3.ZERO


func setup_boss(rng: RandomNumberGenerator) -> void:
	furs = ["fur"]
	size_min = 1.85
	size_max = 1.85
	setup(rng)
	for c in get_children():
		if c is CollisionShape3D:
			var cap := CapsuleShape3D.new()
			cap.radius = 0.62
			cap.height = 1.7
			(c as CollisionShape3D).shape = cap
			c.position.y = 0.85
	max_health = 620.0
	health = max_health
	armor = 12.0
	speed = 6.0
	bite = 27.0
	bite_reach = 2.7
	view_dist = 48.0
	bulk = 1.0
	bag_side = 1.6
	display_name = boss_name
	body_title = boss_name
	loot = {}


func bar() -> Dictionary:
	return {"name": boss_name, "sub": boss_sub, "frac": clampf(health / max_health, 0.0, 1.0), "pips": [], "phase": phase}


func _on_hurt() -> void:
	if state != "fight":
		_attack()


func scare(_pos: Vector3, _reach: float) -> void:
	stagger(0.8)      # a flare only blinds her for a moment


func _think(delta: float, dist: float) -> Vector3:
	if state == "fight":
		var third := 2 if health < max_health * 0.33 else (1 if health < max_health * 0.66 else 0)
		if third > calls:
			calls = third
			phase = calls + 1
			_howl()
	return super._think(delta, dist)


func _howl() -> void:
	Sfx.play(get_parent(), "growl", global_position, 8.0, 0.55)
	stagger(1.2)
	if player:
		player.message.emit("The Grey Mother howls  —  the pack answers.")
	if phase >= 3:
		speed = 7.2
		boss_sub = "She is bleeding and faster for it. Do not let her behind you."
	if main == null:
		return
	for i in 2 + calls:
		var a := i * TAU / float(2 + calls) + calls
		var p := global_position + Vector3(cos(a), 0, sin(a)) * 16.0
		p.y = main.terrain.height_at(p.x, p.z) + 0.4
		var w: Wolf = main.enemies.wolf(p)
		w.state = "fight"


func _die(dir: Vector3) -> void:
	loot = reward.duplicate()
	super._die(dir)


func make_dead() -> void:
	state = "dead"
	health = 0.0
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	model.rotation.z = PI * 0.5
	model.position.y = 0.3
