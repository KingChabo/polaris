class_name GameMode
## Which game is running: the story ("normal") or the horror version of the same valley.
## The world is built once per mode, so switching mode reloads the scene; `pending`
## tells the fresh scene what to do once it is built.

const MODES := ["normal", "horror", "creator"]

static var mode := "normal"
static var pending := ""
## Summer (green valley, snow only on the high mountains, houses built in Blender) or winter.
## Horror stays in winter. `--winter` / `--summer` on the command line override it.
static var season := "summer"


static func horror() -> bool:
	return mode == "horror"


## Creator mode: no story, no enemies, cannot be hurt, [F] flies — for trying out designs.
static func creator() -> bool:
	return mode == "creator"


static func summer() -> bool:
	if "--winter" in OS.get_cmdline_user_args():
		return false
	if "--summer" in OS.get_cmdline_user_args():
		return true
	return season == "summer" and mode != "horror"


## Story text written for the winter valley, told for the season being played.
static func season_text(t: String) -> String:
	if not summer():
		return t
	for pair in [["the Christmas market", "the summer fair"], ["Christmas market", "summer fair"],
			["a tree with a thousand lights", "a maypole hung with a thousand lights"],
			["Glühwein in paper cups", "berry wine in paper cups"], [" Dec —", " Aug —"],
			["Glühwein? Ha. I have snow, and hot snow.", "Cold beer? Ha. I have lake water, and warm lake water."],
			["Snow chains. Without them the lake is a skating rink with a grave under it.", "Good tyres. After rain the lake road is mud, and the lake has a grave under it."],
			["back before the snow. That was the first snow.", "back before the hay was in. That was two summers ago."],
			["Sit down, you look frozen.", "Sit down, you look done in."]]:
		t = t.replace(pair[0], pair[1])
	return t


static func save_path(m := "") -> String:
	var mm := m if m != "" else mode
	if mm == "creator":
		return "user://polaris_creator.json"
	return "user://polaris_horror.json" if mm == "horror" else "user://polaris_save.json"


## Switches to another mode and rebuilds the world; `then` is "new" or "load".
static func switch(tree: SceneTree, m: String, then: String) -> void:
	mode = m
	pending = then
	SaveGame.path = save_path(m)
	tree.paused = false
	tree.reload_current_scene()
