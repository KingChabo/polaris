class_name Blast
## Explosions: damage that falls off with distance, is cut by cover, and throws you about.

static func hurt_all(tree: SceneTree, pos: Vector3, radius: float, dmg: float, by: Node, cause: String) -> void:
	var scene := tree.current_scene
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state if scene is Node3D else null
	var player: Player = scene.get("player") if scene else null
	if player:
		var chest := player.global_position + Vector3(0, 1.0, 0)
		var d := chest.distance_to(pos)
		if d < radius:
			var k := pow(1.0 - d / radius, 1.2)
			if space and _blocked(space, pos + Vector3(0, 0.3, 0), chest, player):
				k *= 0.3
			player.stats.hurt(dmg * k, 0.6 * k, cause, 20.0)
			var away := (chest - pos)
			away.y = 0.0
			player.velocity += away.normalized() * 9.0 * k + Vector3(0, 4.0 * k, 0)
			player.hurt_marks.append([pos, 1.6])
			player.rumble(1.0, 1.0, 0.5)
			if scene.get("post"):
				scene.post.flash(Color(1.0, 0.75, 0.45), 0.45 * k)
		if d < radius * 4.0:
			player.shake(clampf(2.4 * (1.0 - d / (radius * 4.0)), 0.3, 2.4))
	for n in tree.get_nodes_in_group("enemy"):
		var e := n as Node3D
		if e == null or e == by or not e.has_method("hit"):
			continue
		var de := e.global_position.distance_to(pos)
		if de < radius:
			var dir := (e.global_position - pos).normalized()
			e.hit(dmg * (1.0 - de / radius), e.global_position + Vector3(0, 1.0, 0), dir, 15.0, by)


static func _blocked(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, player: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return not space.intersect_ray(q).is_empty()
