class_name HorrorAudio
extends Node
## The horror mode's sound bed, made live from maths: a low beating drone, something
## breathing in the dark, a ringing in the ears when fear is high, and your own heartbeat.
## On top, the lullaby drifts in when it is quiet and fades when something is close.

const RATE := 11025.0

var fear := 0.0          # 0 calm .. 1 it is right behind you
var music_level := 1.0   # the menu can turn the lullaby down

var _pb: AudioStreamGeneratorPlayback
var _lull: AudioStreamPlayer
var _p0 := 0.0
var _p1 := 0.0
var _p2 := 0.0
var _p3 := 0.0
var _beat := 0.0
var _t := 0.0
var _lp := 0.0
var _bp_low := 0.0
var _bp_band := 0.0
var _heart_lp := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	var ap := AudioStreamPlayer.new()
	ap.stream = gen
	ap.volume_db = -6.0
	add_child(ap)
	ap.play()
	_pb = ap.get_stream_playback()
	_lull = AudioStreamPlayer.new()
	_lull.stream = Synth.lullaby()
	_lull.volume_db = -16.0
	add_child(_lull)
	_lull.play()


func _process(delta: float) -> void:
	# the lullaby is loudest when nothing is near, and gives way to the drone when something is
	var want := lerpf(-13.0, -34.0, clampf(fear * 1.6, 0.0, 1.0)) + linear_to_db(maxf(music_level, 0.01))
	_lull.volume_db = move_toward(_lull.volume_db, want, delta * 8.0)
	_lull.pitch_scale = 1.0 - fear * 0.06
	if _pb == null:
		return
	var frames := _pb.get_frames_available()
	var hr := 0.95 + fear * 1.3
	var f_bp := 2.0 * sin(PI * 600.0 / RATE)
	for i in frames:
		_t += 1.0 / RATE
		_p0 = fmod(_p0 + 41.2 / RATE, 1.0)
		_p1 = fmod(_p1 + 43.65 / RATE, 1.0)
		_p2 = fmod(_p2 + 58.27 / RATE, 1.0)
		_p3 = fmod(_p3 + 1975.5 / RATE, 1.0)
		_beat = fmod(_beat + hr / RATE, 1.0)
		var swell := 0.55 + 0.45 * sin(_t * 0.37) * sin(_t * 0.11 + 1.3)
		var s := (sin(_p0 * TAU) * 0.42 + sin(_p1 * TAU) * 0.3 + sin(_p2 * TAU) * 0.22 * (0.4 + fear)) * swell * 0.6
		# breath: band-passed noise, in and out every seven seconds
		var breath := maxf(sin(_t * TAU / 7.0), 0.0)
		var hi := (randf() * 2.0 - 1.0) - _bp_low - 0.7 * _bp_band
		_bp_band += f_bp * hi
		_bp_low += f_bp * _bp_band
		s += _bp_band * breath * breath * 0.22
		# tinnitus when it is close
		s += sin(_p3 * TAU) * 0.03 * fear * fear
		# heartbeat: two soft thumps
		var th := exp(-_beat * 18.0) + 0.65 * (exp(-(_beat - 0.24) * 20.0) if _beat > 0.24 else 0.0)
		_heart_lp += (sin(_beat * TAU * 2.6) * th - _heart_lp) * 0.2
		s += _heart_lp * clampf(fear * 1.4, 0.0, 1.0) * 1.1
		_lp += (s - _lp) * 0.5
		_pb.push_frame(Vector2(_lp, _lp))
