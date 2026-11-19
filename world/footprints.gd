class_name Footprints
extends Node3D
## Leaves boot prints in the snow behind the player. Old prints are reused.

const MAX := 220

var terrain: Terrain
var _pool: Array[Decal] = []
var _next := 0
var _tex: ImageTexture


func _ready() -> void:
	_tex = _boot_texture()


func add_print(pos: Vector3, yaw: float, left: bool) -> void:
	if terrain and terrain.on_lake(pos.x, pos.z):
		return  # no prints on bare ice
	var d: Decal
	if _pool.size() < MAX:
		d = Decal.new()
		d.texture_albedo = _tex
		d.size = Vector3(0.3, 0.7, 0.52)
		d.albedo_mix = 1.0
		d.upper_fade = 0.01
		d.lower_fade = 0.01
		d.distance_fade_enabled = true
		d.distance_fade_begin = 45.0
		d.distance_fade_length = 15.0
		add_child(d)
		_pool.append(d)
	else:
		d = _pool[_next]
		_next = (_next + 1) % MAX
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * (-0.14 if left else 0.14)
	d.global_position = pos + side
	d.rotation = Vector3(0, yaw, 0)


func _boot_texture() -> ImageTexture:
	var w := 48
	var h := 80
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			# sole (front) and heel (back) as two soft ellipses
			var sole := Vector2(u / 0.72, (v + 0.28) / 0.62).length()
			var heel := Vector2(u / 0.58, (v - 0.62) / 0.32).length()
			var a := maxf(smoothstep(1.0, 0.7, sole), smoothstep(1.0, 0.7, heel))
			# tread lines
			var tread := 0.85 + 0.15 * sin(v * 38.0)
			# pressed snow is darker and bluer; the rim is slightly lit
			var rim := smoothstep(0.55, 0.95, minf(sole, heel)) * a
			var col := Color(0.50, 0.58, 0.74).lerp(Color(0.8, 0.85, 0.95), rim * 0.6) * tread
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * 0.55))
	return ImageTexture.create_from_image(img)
