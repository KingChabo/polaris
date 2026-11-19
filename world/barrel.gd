class_name Barrel
extends StaticBody3D
## A fuel barrel. Shoot it and it goes up, taking whatever stands next to it along.

var hp := 25.0
var gone := false
var player: Player


func _ready() -> void:
	add_to_group("barrel")
	var k := MeshKit.new()
	k.cyl(Vector3.ZERO, 0.3, 0.9, "paint_red_in", 12)
	for y: float in [0.28, 0.62]:
		k.cyl(Vector3(0, y, 0), 0.315, 0.03, "metal_in", 12)
	k.box(Vector3(0, 0.45, 0.3), Vector3(0.26, 0.2, 0.02), "hazard_in")
	k.cyl(Vector3(0.14, 0.9, 0.1), 0.04, 0.03, "metal_in", 6)
	add_child(k.node(false))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.9
	cs.shape = sh
	cs.position.y = 0.45
	add_child(cs)


func hit(dmg: float, _pos: Vector3, _dir: Vector3, _pen: float, _shooter: Node) -> void:
	hp -= dmg
	if hp <= 0.0:
		explode()


func explode() -> void:
	if gone:
		return
	gone = true
	var at := global_position + Vector3(0, 0.6, 0)
	var world := get_parent()
	Sfx.play(world, "shot_boom", at, 8.0, 0.55)
	for i in 10:
		Fx.sparks(world, at + Vector3(randf_range(-1.2, 1.2), randf_range(0.0, 1.4), randf_range(-1.2, 1.2)), Vector3.UP)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 14.0
	l.omni_range = 16.0
	world.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.7)
	tw.tween_callback(l.queue_free)
	for e in get_tree().get_nodes_in_group("enemy"):
		var en: Node3D = e
		var d := maxf(en.global_position.distance_to(global_position) - float(en.get("bulk")), 0.0)
		if d < 7.0 and en.has_method("hit"):
			var dir := (en.global_position - global_position).normalized()
			en.call("hit", 190.0 * clampf(1.3 - d / 7.0, 0.3, 1.0), en.global_position + Vector3(0, 1.0, 0) - dir, dir, 999.0, null)
	if player:
		var p := player
		var d := p.global_position.distance_to(global_position)
		if d < 6.0:
			p.stats.hurt(55.0 * clampf(1.2 - d / 6.0, 0.2, 1.0), 0.3, "an explosion")
			p.velocity += (p.global_position - global_position).normalized() * 6.0 + Vector3(0, 3.0, 0)
			p.shake(1.6)
			p.hurt_marks.append([global_position, 1.6])
	for b in get_tree().get_nodes_in_group("barrel"):
		if b != self and b is Barrel and (b as Barrel).global_position.distance_to(global_position) < 4.5:
			(b as Barrel).hp = 0.0
			get_tree().create_timer(0.18).timeout.connect((b as Barrel).explode)
	queue_free()
