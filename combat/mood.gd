class_name CombatMood
extends Node
## Knows whether a fight is going on, and plays a tense pulse while it is.
## `level` goes from 0 (calm) to 1 (in a fight); the HUD reads it too.

var player: Player
var level := 0.0
var fighting: Array[Node3D] = []     # enemies that are after you right now

var _playback: AudioStreamGeneratorPlayback
var _ap: AudioStreamPlayer
var _phase := 0.0
var _beat := 0.0
var _lp := 0.0
var _scan := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 11025.0
	gen.buffer_length = 0.2
	_ap = AudioStreamPlayer.new()
	_ap.stream = gen
	_ap.volume_db = -9.0
	add_child(_ap)
	_ap.play()
	_playback = _ap.get_stream_playback()


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0 and player:
		_scan = 0.25
		fighting.clear()
		for n in get_tree().get_nodes_in_group("enemy"):
			var e: Node3D = n
			if str(e.get("state")) == "fight" and e.global_position.distance_to(player.global_position) < 90.0:
				fighting.append(e)
	level = move_toward(level, 1.0 if not fighting.is_empty() else 0.0, delta * (1.5 if not fighting.is_empty() else 0.25))
	if _playback == null:
		return
	# a low drone with a slow double thump, like a heartbeat
	var frames := _playback.get_frames_available()
	var rate := 1.25 + 0.5 * level
	for i in frames:
		_phase = fmod(_phase + 46.0 / 11025.0, 1.0)
		_beat = fmod(_beat + rate / 11025.0, 1.0)
		var thump := exp(-_beat * 16.0) + 0.7 * exp(-maxf(_beat - 0.22, 0.0) * 18.0) * (1.0 if _beat > 0.22 else 0.0)
		var s := sin(_phase * TAU) * 0.22 + sin(_phase * TAU * 1.5) * 0.1
		s += sin(_beat * TAU * 3.0) * thump * 0.8
		_lp += (s - _lp) * 0.25
		var out := _lp * level
		_playback.push_frame(Vector2(out, out))
