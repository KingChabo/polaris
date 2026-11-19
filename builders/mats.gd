class_name Mats
extends RefCounted
## All building and prop materials, made from one procedural shader.
## A name ending in "_in" is the indoor version (no snow on it).

static var noise_tex: Texture2D
static var _cache := {}

# name: [kind, colour, second colour]
# kinds: 0 log wall, 1 plaster, 2 stone, 3 shingles, 4 metal, 5 snow, 6 striped cloth, 7 upright planks, 8 plain paint
const DEFS := {
	"wood": [0, Color(0.30, 0.18, 0.10)],
	"wood_dark": [0, Color(0.15, 0.09, 0.055)],
	"planks": [7, Color(0.36, 0.24, 0.14)],
	"plaster": [1, Color(0.80, 0.77, 0.70)],
	"concrete": [1, Color(0.42, 0.43, 0.44)],
	"stone": [2, Color(0.40, 0.39, 0.38)],
	"roof": [3, Color(0.15, 0.09, 0.07)],
	"metal": [4, Color(0.17, 0.18, 0.20)],
	"steel": [4, Color(0.45, 0.47, 0.5)],
	"snow": [5, Color(0.90, 0.93, 0.98)],
	"stripes_red": [6, Color(0.55, 0.07, 0.06), Color(0.85, 0.80, 0.68)],
	"stripes_green": [6, Color(0.07, 0.30, 0.14), Color(0.85, 0.80, 0.68)],
	"paint_red": [7, Color(0.50, 0.07, 0.06)],
	"paint_green": [7, Color(0.07, 0.28, 0.13)],
	"paint_blue": [7, Color(0.10, 0.20, 0.42)],
	"paint_yellow": [7, Color(0.75, 0.55, 0.10)],
	"paint_white": [7, Color(0.82, 0.80, 0.74)],
	"red": [8, Color(0.62, 0.06, 0.05)],
	"green": [8, Color(0.06, 0.32, 0.12)],
	"blue": [8, Color(0.08, 0.18, 0.5)],
	"yellow": [8, Color(0.85, 0.62, 0.08)],
	"white": [8, Color(0.85, 0.84, 0.8)],
	"black": [8, Color(0.03, 0.03, 0.035)],
	"skin": [14, Color(0.71, 0.51, 0.41)],
	"skin_pale": [14, Color(0.76, 0.6, 0.52)],
	"skin_ruddy": [14, Color(0.7, 0.46, 0.38)],
	"skin_tan": [14, Color(0.6, 0.42, 0.31)],
	"skin_dark": [14, Color(0.4, 0.27, 0.2)],
	"lips": [14, Color(0.6, 0.34, 0.31)],
	"eye_white": [8, Color(0.74, 0.72, 0.69)],
	"iris": [8, Color(0.15, 0.2, 0.22)],
	"orange": [8, Color(0.85, 0.35, 0.05)],
	"cloth": [8, Color(0.35, 0.12, 0.12)],
	"fur": [15, Color(0.40, 0.40, 0.43)],
	"fur_dark": [15, Color(0.17, 0.17, 0.19)],
	"fur_brown": [15, Color(0.33, 0.24, 0.16)],
	"olive": [8, Color(0.19, 0.22, 0.13)],
	"navy": [8, Color(0.08, 0.10, 0.17)],
	"camo": [8, Color(0.70, 0.72, 0.76)],
	"rock": [8, Color(0.21, 0.21, 0.235)],
	"cream": [8, Color(0.80, 0.74, 0.60)],
	"teal": [8, Color(0.08, 0.30, 0.30)],
	"leather": [8, Color(0.28, 0.15, 0.08)],
	"paper": [8, Color(0.85, 0.82, 0.72)],
	"grey": [8, Color(0.40, 0.41, 0.44)],
	"pine": [8, Color(0.04, 0.17, 0.07)],
	"tile": [1, Color(0.16, 0.36, 0.26)],
	"rug": [6, Color(0.42, 0.06, 0.07), Color(0.16, 0.10, 0.20)],
	"check": [6, Color(0.62, 0.10, 0.09), Color(0.86, 0.83, 0.76)],
	"tar": [8, Color(0.055, 0.057, 0.065)],
	"frost_skin": [14, Color(0.58, 0.64, 0.70)],
	"rust": [4, Color(0.33, 0.17, 0.09)],
	"hazard": [6, Color(0.85, 0.62, 0.05), Color(0.05, 0.05, 0.05)],
	"panel": [7, Color(0.78, 0.80, 0.82)],
	"panel_orange": [7, Color(0.80, 0.36, 0.08)],
	"gravel": [2, Color(0.2, 0.19, 0.19)],
	"clad_red": [9, Color(0.42, 0.085, 0.06)],
	"clad_ochre": [9, Color(0.66, 0.46, 0.16)],
	"clad_blue": [10, Color(0.20, 0.30, 0.40)],
	"clad_green": [9, Color(0.16, 0.27, 0.20)],
	"clad_white": [10, Color(0.80, 0.79, 0.74)],
	"clad_grey": [10, Color(0.36, 0.38, 0.40)],
	"clad_black": [9, Color(0.075, 0.07, 0.07)],
	"clad_yellow": [10, Color(0.78, 0.66, 0.36)],
	"clad_brown": [9, Color(0.27, 0.16, 0.10)],
	"trim": [8, Color(0.86, 0.85, 0.80)],
	"trim_dark": [8, Color(0.10, 0.10, 0.11)],
	"roof_metal": [11, Color(0.10, 0.105, 0.115)],
	"roof_red": [11, Color(0.33, 0.09, 0.07)],
	"roof_green": [11, Color(0.11, 0.20, 0.15)],
	"corrugated": [13, Color(0.42, 0.44, 0.46)],
	"brick": [12, Color(0.42, 0.17, 0.11)],
	"brick_yellow": [12, Color(0.62, 0.50, 0.30)],
	"wall": [1, Color(0.84, 0.82, 0.76)],
	"render_ochre": [1, Color(0.74, 0.58, 0.30)],
	"asphalt": [8, Color(0.07, 0.072, 0.08)],
	"plastic_green": [8, Color(0.07, 0.22, 0.12)],
	"plastic_grey": [8, Color(0.16, 0.17, 0.18)],
	"sign_blue": [8, Color(0.05, 0.20, 0.55)],
	"sign_red": [8, Color(0.70, 0.05, 0.05)],
	"sign_yellow": [8, Color(0.92, 0.72, 0.05)],
	"car_blue": [8, Color(0.10, 0.20, 0.42)],
	"car_silver": [8, Color(0.55, 0.57, 0.60)],
	"car_white": [8, Color(0.85, 0.85, 0.84)],
	"car_black": [8, Color(0.05, 0.05, 0.06)],
	"car_red": [8, Color(0.78, 0.10, 0.07)],
	"car_olive": [8, Color(0.38, 0.44, 0.24)],
	"car_yellow": [8, Color(0.98, 0.76, 0.10)],
	"car_orange": [8, Color(0.98, 0.42, 0.06)],
	# item pictures
	"tin": [17, Color(0.6, 0.62, 0.65)],
	"gunmetal": [17, Color(0.07, 0.075, 0.085)],
	"steel_clean": [17, Color(0.46, 0.48, 0.52)],
	"worn": [17, Color(0.19, 0.2, 0.22)],
	"polymer": [18, Color(0.04, 0.042, 0.046)],
	"polymer_tan": [18, Color(0.4, 0.32, 0.2)],
	"polymer_green": [18, Color(0.16, 0.2, 0.12)],
	"glove": [18, Color(0.075, 0.065, 0.055)],
	"walnut": [19, Color(0.4, 0.2, 0.09)],
	"walnut_dark": [19, Color(0.22, 0.11, 0.055)],
	"denim": [8, Color(0.13, 0.2, 0.36)],
	"khaki": [8, Color(0.42, 0.38, 0.26)],
	"tan": [8, Color(0.55, 0.42, 0.26)],
	"canvas": [8, Color(0.3, 0.36, 0.2)],
	"kevlar": [8, Color(0.12, 0.14, 0.13)],
	"wool_red": [15, Color(0.6, 0.1, 0.08)],
	"wool_white": [15, Color(0.82, 0.8, 0.76)],
	"pelt": [15, Color(0.78, 0.82, 0.88)],
	"bone": [8, Color(0.82, 0.78, 0.66)],
	"pill": [8, Color(0.8, 0.42, 0.08)],
}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material
	match name:
		"glass_lit":
			m = _std(Color(1.0, 0.75, 0.42), 0.3, Color(1.0, 0.66, 0.30), 1.9)
		"glass_cold":
			m = _std(Color(0.75, 0.85, 1.0), 0.3, Color(0.6, 0.78, 1.0), 0.8)
		"lamp_sodium":
			m = _std(Color(1.0, 0.7, 0.35), 0.4, Color(1.0, 0.58, 0.22), 6.0)
		"lamp_white":
			m = _std(Color(0.9, 0.95, 1.0), 0.4, Color(0.85, 0.93, 1.0), 6.0)
		"tail_red":
			m = _std(Color(0.35, 0.02, 0.02), 0.25, Color.BLACK, 0.0)
		"glass_lit2":
			m = _std(Color(1.0, 0.85, 0.6), 0.3, Color(1.0, 0.80, 0.52), 1.3)
		"glass_tv":
			m = _std(Color(0.5, 0.65, 1.0), 0.3, Color(0.35, 0.5, 1.0), 0.9)
		"glass_dark":
			m = _std(Color(0.02, 0.035, 0.06), 0.06, Color.BLACK, 0.0)
			m.metallic = 0.3
		"glass_clear":
			m = _std(Color(0.6, 0.8, 0.9, 0.16), 0.04, Color.BLACK, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"lamp_glow":
			m = _std(Color(1.0, 0.8, 0.5), 0.4, Color(1.0, 0.72, 0.36), 5.0)
		"candle":
			m = _std(Color(1.0, 0.8, 0.5), 0.4, Color(1.0, 0.6, 0.2), 4.0)
		"gold":
			m = _std(Color(1.0, 0.8, 0.3), 0.3, Color(1.0, 0.75, 0.25), 3.5)
		"brass":
			m = _std(Color(0.72, 0.55, 0.22), 0.35, Color.BLACK, 0.0)
			m.metallic = 0.85
		"chrome":
			m = _std(Color(0.78, 0.8, 0.84), 0.18, Color.BLACK, 0.0)
			m.metallic = 0.95
		"gold_coin":
			m = _std(Color(0.95, 0.72, 0.25), 0.28, Color.BLACK, 0.0)
			m.metallic = 0.95
		"heart_glow":
			m = _std(Color(0.5, 0.9, 1.0), 0.1, Color(0.3, 0.85, 1.0), 2.2)
		"copper":
			m = _std(Color(0.72, 0.38, 0.2), 0.3, Color.BLACK, 0.0)
			m.metallic = 0.9
		"chainlink":
			var cm := ShaderMaterial.new()
			cm.shader = load("res://world/chainlink.gdshader")
			m = cm
		"screen_on":
			m = _std(Color(0.1, 0.5, 0.45), 0.3, Color(0.15, 0.9, 0.75), 2.2)
		"led_red":
			m = _std(Color(0.9, 0.1, 0.05), 0.3, Color(1.0, 0.12, 0.05), 5.0)
		"led_green":
			m = _std(Color(0.1, 0.9, 0.3), 0.3, Color(0.1, 1.0, 0.3), 4.0)
		"specimen":
			m = _std(Color(0.3, 0.85, 0.9, 0.55), 0.08, Color(0.2, 0.8, 1.0), 1.6)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"hollow_skin":
			# wet, near-black skin that catches the light only at its edges
			var hs := _std(Color(0.02, 0.019, 0.022), 0.32, Color.BLACK, 0.0)
			hs.rim_enabled = true
			hs.rim = 0.9
			hs.rim_tint = 0.15
			hs.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			m = hs
		"hollow_face":
			var hf := _std(Color(0.42, 0.42, 0.41), 0.5, Color(0.5, 0.5, 0.48), 0.32)    # a pale face that hangs in the dark
			hf.rim_enabled = true
			hf.rim = 0.5
			m = hf
		"hollow_teeth":
			m = _std(Color(0.7, 0.66, 0.55), 0.4, Color.BLACK, 0.0)
		"hollow_rag":
			m = _std(Color(0.035, 0.032, 0.035), 0.9, Color.BLACK, 0.0)
			(m as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		"flame":
			var fl := _std(Color(0, 0, 0), 1.0, Color(1.0, 0.36, 0.06), 2.4)
			fl.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fl.albedo_color = Color(1.0, 0.36, 0.06)
			fl.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = fl
		"flame_core":
			var fc := _std(Color(0, 0, 0), 1.0, Color(1.0, 0.75, 0.3), 2.0)
			fc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fc.albedo_color = Color(1.0, 0.72, 0.32)
			fc.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = fc
		"frost_eye":
			m = _std(Color(0.7, 0.9, 1.0), 0.3, Color(0.55, 0.85, 1.0), 4.0)
		"ice":
			m = _std(Color(0.62, 0.80, 0.90, 0.75), 0.05, Color(0.05, 0.10, 0.14), 1.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_:
			var base := name.trim_suffix("_in")
			# "<colour>_coat": the same colour as a padded winter coat with stitched baffles
			var coat := base.ends_with("_coat")
			if coat:
				base = base.trim_suffix("_coat")
			var def: Array = DEFS.get(base, DEFS["white"])
			var sm := ShaderMaterial.new()
			sm.shader = load("res://world/surface.gdshader")
			sm.set_shader_parameter("noise_tex", noise_tex)
			sm.set_shader_parameter("kind", 16 if coat and int(def[0]) == 8 else def[0])
			sm.set_shader_parameter("tint", def[1])
			sm.set_shader_parameter("tint2", def[2] if def.size() > 2 else def[1])
			sm.set_shader_parameter("snow_amount", 0.0 if (name.ends_with("_in") or coat or GameMode.summer()) else 1.0)
			_pbr(sm, base, int(def[0]), name.ends_with("_in"))
			m = sm
	_cache[name] = m
	return m


# kind -> [scan, repeats per metre, how much of the scan, keep the scan's colour, turned]
const PBR := {
	0: ["weathered_planks", 0.45, 0.8, 0.0, false],
	7: ["brown_planks_03", 0.5, 0.8, 0.0, true],
	9: ["weathered_planks", 0.5, 0.75, 0.0, true],
	10: ["brown_planks_03", 0.5, 0.7, 0.0, false],
	1: ["white_plaster_02", 0.35, 0.85, 0.0, false],
	2: ["rocky_terrain_02", 0.35, 0.85, 0.0, false],
	3: ["roof_slates_03", 0.5, 0.85, 0.0, false],
	11: ["roof_slates_03", 0.45, 0.8, 0.0, false],
	4: ["rusty_metal_02", 0.4, 0.8, 0.0, false],
	12: ["red_brick_03", 0.45, 0.9, 0.0, false],
	13: ["corrugated_iron_02", 0.5, 0.85, 0.0, false],
}
const PBR_NAMES := {
	"concrete": ["concrete_floor_02", 0.3, 0.9, 0.0, false],
	"rust": ["rusty_metal_02", 0.4, 0.95, 1.0, false],
	"planks_in": ["wood_floor_deck", 0.45, 0.85, 0.0, false],
	"bark": ["pine_bark", 0.6, 1.0, 1.0, false],
	"snow": ["snow_02", 0.35, 0.85, 0.0, false],
}
static var _means := {}


static func _pbr(sm: ShaderMaterial, base: String, kind: int, indoor: bool) -> void:
	var d: Array = PBR_NAMES.get(base + ("_in" if indoor else ""), PBR_NAMES.get(base, PBR.get(kind, [])))
	if d.is_empty() or ModelLib.skip.has("mats"):
		return
	var alb := ModelLib.tex(str(d[0]), "diff")
	if alb == null:
		return
	if not _means.has(d[0]):
		var img := alb.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
		var c := Vector3.ZERO
		for y in 8:
			for x in 8:
				var px := img.get_pixel(x, y)
				c += Vector3(px.r, px.g, px.b)
		_means[d[0]] = c / 64.0
	sm.set_shader_parameter("pbr_alb", alb)
	sm.set_shader_parameter("pbr_nrm", ModelLib.tex(str(d[0]), "nor"))
	sm.set_shader_parameter("pbr_rgh", ModelLib.tex(str(d[0]), "rough"))
	sm.set_shader_parameter("pbr_scale", float(d[1]))
	sm.set_shader_parameter("pbr_amt", float(d[2]))
	sm.set_shader_parameter("pbr_mean", _means[d[0]])
	sm.set_shader_parameter("pbr_keep", float(d[3]))
	sm.set_shader_parameter("pbr_rot", bool(d[4]))


static func _std(albedo: Color, rough: float, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m
