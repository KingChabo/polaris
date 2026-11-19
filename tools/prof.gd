extends SceneTree
## Prints natural heights along lines, to pick spots for the places.
func _init() -> void:
	var t := Terrain.new()
	t._setup_noise()
	var lines := [
		["mine z=100 x", Vector2(360, 100), Vector2(1, 0), 30, 8.0],
		["mine z=60 x", Vector2(360, 60), Vector2(1, 0), 30, 8.0],
		["mine z=140 x", Vector2(360, 140), Vector2(1, 0), 30, 8.0],
		["tunnel x=100 z", Vector2(100, 440), Vector2(0, 1), 30, 8.0],
		["tunnel x=60 z", Vector2(60, 440), Vector2(0, 1), 30, 8.0],
		["tunnel x=140 z", Vector2(140, 440), Vector2(0, 1), 30, 8.0],
		["gorge diag", Vector2(-560, -80), Vector2(1, -1).normalized(), 42, 16.0],
		["gorge +60", Vector2(-600, -120), Vector2(1, -1).normalized(), 42, 16.0],
		["cross road->station", Vector2(-200, -240), Vector2(-1, -1).normalized(), 24, 12.0],
		["base z=-470 x", Vector2(-80, -470), Vector2(1, 0), 24, 10.0],
		["base x=40 z", Vector2(40, -380), Vector2(0, -1), 24, 10.0],
		["settle z=60", Vector2(-120, 60), Vector2(1, 0), 20, 8.0],
		["settle z=20", Vector2(-120, 20), Vector2(1, 0), 20, 8.0],
		["bunker2 z=330", Vector2(-40, 330), Vector2(1, 0), 16, 8.0],
		["tower z=190", Vector2(-80, 190), Vector2(1, 0), 20, 8.0],
	]
	for l in lines:
		var row := "%-22s" % str(l[0])
		for q in int(l[3]):
			var p: Vector2 = l[1] + l[2] * q * float(l[4])
			row += "%4d" % int(t._raw_height(p.x, p.y))
		print(row)
	quit()
