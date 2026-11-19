class_name Weather
extends Node3D
## Snowfall, snowstorms, fog and wind sound. `storm` goes from 0 (calm) to 1 (blizzard).

var storm := 0.15
var target_storm := 0.15
var wind := Vector3(2.0, 0.0, 1.0)

var env: Environment
var follow: Node3D
var auto_cycle := true
var fog_add := 0.0                      # extra fog on top of the storm (horror mode, the White One's howl)
var haze_add := 0.0
var calm_glow := Color(0.03, 0.05, 0.09)  # what the fog glows with on a calm night
var storm_floor := 0.0                   # the weather never gets calmer than this

var _snow: GPUParticles3D
var _pm: ParticleProcessMaterial
var _timer := 40.0
var _playback: AudioStreamGeneratorPlayback
var _lp1 := 0.0
var _lp2 := 0.0
var _gust := 0.0
var _t := 0.0


func _ready() -> void:
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = Vector3(32, 12, 32)
	_pm.direction = Vector3(0, -1, 0)
	_pm.spread = 25.0
	_pm.initial_velocity_min = 0.6
	_pm.initial_velocity_max = 2.0
	_pm.gravity = Vector3(1.0, -1.4, 0.5)
	_pm.scale_min = 0.5
	_pm.scale_max = 1.3
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 1.2
	_pm.turbulence_noise_scale = 3.0

	var flake := QuadMesh.new()
	flake.size = Vector2(0.07, 0.07)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.85, 0.9, 1.0, 0.75)
	fm.albedo_texture = _dot_texture()
	flake.material = fm

	if GameMode.summer():
		# summer: the "storm" is rain, thin fast streaks, and none on fair days
		flake.size = Vector2(0.012, 0.42)
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		fm.albedo_color = Color(0.72, 0.77, 0.84, 0.32)
		fm.albedo_texture = null
		_pm.initial_velocity_min = 7.0
		_pm.initial_velocity_max = 9.0
		_pm.spread = 4.0
		_pm.turbulence_enabled = false

	_snow = GPUParticles3D.new()
	_snow.amount = 14000
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0
	_snow.process_material = _pm
	_snow.draw_pass_1 = flake
	_snow.visibility_aabb = AABB(Vector3(-80, -60, -80), Vector3(160, 120, 160))
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_snow)

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 11025.0
	gen.buffer_length = 0.25
	var ap := AudioStreamPlayer.new()
	ap.stream = gen
	ap.volume_db = -8.0
	add_child(ap)
	ap.play()
	_playback = ap.get_stream_playback()


func _dot_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	if auto_cycle:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(60.0, 160.0)
			var r := randf()
			target_storm = maxf(0.05 if r < 0.4 else (0.35 if r < 0.75 else 1.0), storm_floor)
	storm = move_toward(storm, target_storm, delta * 0.04)

	if follow:
		_snow.global_position = follow.global_position + Vector3(0, 7, 0) + wind * -0.8 * storm
		_snow.visible = not Places.underground(follow.global_position)
	_gust = 0.5 + 0.5 * sin(_t * 0.31) * sin(_t * 0.13 + 1.7)
	var w := wind.normalized() * lerpf(1.0, 16.0, storm) * (0.7 + 0.6 * _gust)
	if GameMode.summer():
		_pm.gravity = Vector3(w.x * 0.3, -9.0, w.z * 0.3)
		_snow.amount_ratio = smoothstep(0.25, 0.9, storm) * 0.6
	else:
		_pm.gravity = Vector3(w.x, lerpf(-1.3, -3.0, storm), w.z)
		_snow.amount_ratio = lerpf(0.12, 1.0, storm)

	if env:
		env.volumetric_fog_density = (lerpf(0.0006, 0.012, storm * storm) if GameMode.summer() else lerpf(0.004, 0.05, storm * storm)) + fog_add
		env.fog_density = (lerpf(0.00018, 0.002, storm * storm) if GameMode.summer() else lerpf(0.0006, 0.008, storm * storm)) + haze_add
		env.volumetric_fog_emission = Color.BLACK if GameMode.summer() else calm_glow.lerp(Color(0.17, 0.21, 0.31), storm)
		env.volumetric_fog_emission_energy = lerpf(0.6, 1.0, storm)
		env.volumetric_fog_sky_affect = storm * (0.5 if GameMode.summer() else 1.0)
		env.fog_sky_affect = lerpf(0.03 if GameMode.summer() else 0.15, 1.0, storm)
	_fill_wind()


func _fill_wind() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var cut := lerpf(0.02, 0.11, storm) * (0.6 + 0.8 * _gust)
	var gain := lerpf(1.5, 7.0, storm) * (0.5 + _gust)
	for i in frames:
		var white := randf() * 2.0 - 1.0
		_lp1 += (white - _lp1) * cut
		_lp2 += (_lp1 - _lp2) * cut
		var s := clampf(_lp2 * gain, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
