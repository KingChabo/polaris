class_name PostFx
extends CanvasLayer
## A full-screen pass over the 3D picture (under the HUD): grain, vignette, colour fringing,
## frost on the frame, whiteout, and flashes for blasts and jump scares.
## Other systems push effects in; they fade back by themselves.

var mat: ShaderMaterial
var fear := 0.0           # set every frame by whoever is frightening you (horror mode)
var frost := 0.0          # frost on the frame (the White One's breath), fades
var whiteout := 0.0       # blizzard howl, fades
var suppress := 0.0       # bullets cracking past your head, fades fast
var pain := 0.0           # set by the player: badly hurt, the colour drains out
var _flash := Color(0, 0, 0, 0)
var _rect: ColorRect


func setup(noise: Texture2D) -> void:
	layer = -1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://world/post.gdshader")
	mat.set_shader_parameter("noise_tex", noise)
	_rect.material = mat
	add_child(_rect)
	look(GameMode.horror())


## The base grade of the picture for each mode.
func look(horror: bool) -> void:
	if horror:
		mat.set_shader_parameter("grain", 0.06)
		mat.set_shader_parameter("vignette", 0.58)
		mat.set_shader_parameter("desat", 0.42)
		mat.set_shader_parameter("aberration", 0.0028)
		mat.set_shader_parameter("tint", Vector3(0.92, 0.97, 1.04))
		mat.set_shader_parameter("lift", Vector3(0.004, 0.006, 0.01))
	else:
		mat.set_shader_parameter("grain", 0.022)
		mat.set_shader_parameter("vignette", 0.3)
		mat.set_shader_parameter("desat", 0.0)
		mat.set_shader_parameter("aberration", 0.0012)
		mat.set_shader_parameter("tint", Vector3(1.0, 1.0, 1.0))
		mat.set_shader_parameter("lift", Vector3(0.0, 0.0, 0.0))
	if bool(Settings.get_v("reduced_fx")):
		mat.set_shader_parameter("grain", 0.006)
		mat.set_shader_parameter("aberration", 0.0)


func flash(col: Color, strength: float) -> void:
	if strength > _flash.a:
		_flash = Color(col.r, col.g, col.b, strength)


func _process(delta: float) -> void:
	_flash.a = move_toward(_flash.a, 0.0, delta * 2.2)
	frost = move_toward(frost, 0.0, delta * 0.12)
	whiteout = move_toward(whiteout, 0.0, delta * 0.18)
	suppress = move_toward(suppress, 0.0, delta * 0.9)
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("fear", maxf(fear, suppress * 0.6))
	mat.set_shader_parameter("pain", pain)
	mat.set_shader_parameter("frost", frost)
	mat.set_shader_parameter("whiteout", whiteout)
