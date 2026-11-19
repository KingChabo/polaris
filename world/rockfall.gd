class_name Rockfall
extends Node3D
## A piece of the roof coming down: first dust and a red mark on the floor, then the rock.

const WARN := 1.3
const DROP := 0.35

var player: Player
var radius := 2.2
var damage := 24.0
var landed := false
var _t := 0.0
var _ring: MeshInstance3D
var _rock: Node3D


func _ready() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	_ring = MeshInstance3D.new()
	_ring.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.2, 0.1, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = m
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var k := MeshKit.new()
	k.bbox(Vector3.ZERO, Vector3(1.5, 1.1, 1.3), 0.3, "rock_in", Basis(Vector3(1, 0.4, 0.2).normalized(), randf() * TAU))
	k.bbox(Vector3(0.5, 0.2, 0.3), Vector3(0.8, 0.7, 0.9), 0.2, "rock_in", Basis(Vector3.UP, randf() * TAU))
	_rock = k.node(false)
	_rock.position.y = 6.6
	_rock.visible = false
	add_child(_rock)


func _process(delta: float) -> void:
	_t += delta
	if not landed:
		if _t < WARN:
			_ring.scale = Vector3.ONE * (0.4 + 0.6 * _t / WARN)
			return
		_rock.visible = true
		var f := clampf((_t - WARN) / DROP, 0.0, 1.0)
		_rock.position.y = lerpf(6.6, 0.45, f * f)
		if f >= 1.0:
			_land()
	elif _t > WARN + DROP + 7.0:
		queue_free()


func _land() -> void:
	landed = true
	_ring.visible = false
	Sfx.play(get_parent(), "thud", global_position, 6.0, 0.5)
	Fx.sparks(get_parent(), global_position + Vector3(0, 0.3, 0), Vector3.UP)
	if player and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < radius \
			and absf(player.global_position.y - global_position.y) < 3.0:
		player.stats.hurt(damage, 0.2, "falling rock")
		player.shake(1.5)
		player.hurt_marks.append([global_position + Vector3(0, 4.0, 0), 1.6])
