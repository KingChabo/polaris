extends SceneTree
## Writes shots/map.png: height as grey, steep ground red, lake blue, grid lines every 200 m.
func _init() -> void:
	var t := Terrain.new()
	t._setup_noise()
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	for j in 512:
		for i in 512:
			var x := -1024.0 + i * 4.0
			var z := -1024.0 + j * 4.0
			var h := t._raw_height(x, z)
			var e := 4.0
			var n := Vector3(t._raw_height(x - e, z) - t._raw_height(x + e, z), 2.0 * e, t._raw_height(x, z - e) - t._raw_height(x, z + e)).normalized()
			var g := clampf((h - 10.0) / 260.0, 0.0, 1.0)
			var c := Color(g, g, g)
			if n.y < 0.8:
				c = Color(0.9, 0.2 + g * 0.5, 0.1)
			elif n.y < 0.93:
				c = Color(g + 0.25, g + 0.15, g * 0.6)
			if h < Terrain.LAKE_LEVEL:
				c = Color(0.1, 0.3, 0.8)
			if (i % 50 == 6) or (j % 50 == 6):
				c = c.lerp(Color(0, 1, 0), 0.35)
			img.set_pixel(i, j, c)
	DirAccess.make_dir_absolute("res://shots")
	img.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
	img.save_png("res://shots/map.png")
	var out := ""
	for z in range(-900, 901, 100):
		var row := "z%5d " % z
		for x in range(-900, 901, 100):
			row += "%4d" % int(t._raw_height(x, z))
		out += row + "\n"
	print(out)
	quit()
