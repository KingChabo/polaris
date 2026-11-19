class_name Sfx
## Small synthesised sound effects: shots, swings, hits, growls.

const RATE := 22050
static var _cache := {}

## Subtitles for sounds that matter (Settings "captions"): what you hear, and from where.
const CAPTIONS := {
	"growl": "growling", "scream": "a scream", "shriek": "shrieking", "whisper": "whispering",
	"knock": "knocking", "groan": "groaning", "slam": "a door slams", "static": "radio static",
	"shot_boom": "gunfire", "shot_big": "gunfire", "shot_small": "gunfire", "boom": "an explosion",
	"crack": "ice cracking", "steam": "hissing steam", "buzz": "buzzing", "heartbeat": "your heartbeat",
}
static var _cap_last := {}


static func _caption(parent: Node, sound: String, pos: Variant) -> void:
	if not CAPTIONS.has(sound) or not bool(Settings.get_v("captions")):
		return
	var tree := parent.get_tree()
	var main: Node = tree.current_scene if tree else null
	if main == null or main.get("hud") == null or main.get("player") == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_cap_last.get(sound, -9999)) < 1500:
		return
	_cap_last[sound] = now
	var text := str(CAPTIONS[sound])
	if pos is Vector3:
		var pl: Node3D = main.player
		var to: Vector3 = (pos as Vector3) - pl.global_position
		if to.length() > (420.0 if sound.begins_with("shot") or sound == "boom" else 45.0):
			return
		var cam: Camera3D = main.player.camera
		var f := -cam.global_basis.z
		var r := cam.global_basis.x
		to.y = 0.0
		if to.length() > 2.0:
			var fw := Vector2(f.x, f.z).normalized().dot(Vector2(to.x, to.z).normalized())
			var rt := Vector2(r.x, r.z).normalized().dot(Vector2(to.x, to.z).normalized())
			text += ", behind you" if fw < -0.5 else (", to the right" if rt > 0.5 else (", to the left" if rt < -0.5 else " ahead"))
	main.hud.caption("[" + text + "]")


static func play(parent: Node, sound: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	if not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.unit_size = 14.0 if sound.begins_with("shot") else 5.0
	p.max_distance = 400.0 if sound.begins_with("shot") else 60.0
	if sound.begins_with("shot") or sound == "crack":
		p.bus = _echo_bus()
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	_caption(parent, sound, pos)


## Gunshots and blasts go through a bus with two late echoes and a wide reverb,
## so a shot rolls back off the hills instead of stopping dead.
static func _echo_bus() -> StringName:
	if AudioServer.get_bus_index("Echo") == -1:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, "Echo")
		AudioServer.set_bus_send(i, "Master")
		var d := AudioEffectDelay.new()
		d.dry = 1.0
		d.tap1_active = true
		d.tap1_delay_ms = 360.0
		d.tap1_level_db = -12.0
		d.tap1_pan = -0.35
		d.tap2_active = true
		d.tap2_delay_ms = 840.0
		d.tap2_level_db = -18.0
		d.tap2_pan = 0.4
		d.feedback_active = false
		AudioServer.add_bus_effect(i, d)
		var r := AudioEffectReverb.new()
		r.room_size = 0.85
		r.damping = 0.75
		r.spread = 1.0
		r.hipass = 0.2
		r.dry = 1.0
		r.wet = 0.16
		AudioServer.add_bus_effect(i, r)
	return &"Echo"


static func stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var buf := PackedFloat32Array()
	match sound:
		"shot_small":
			buf = _burst(0.28, 16.0, 0.55, 150.0, 0.5)
		"shot_big":
			buf = _burst(0.5, 9.0, 0.4, 90.0, 0.8)
		"shot_boom":
			buf = _burst(0.7, 6.0, 0.25, 60.0, 1.0)
		"shot_quiet":
			buf = _burst(0.12, 40.0, 0.2, 300.0, 0.15)
		"swing":
			buf = _burst(0.2, 14.0, 0.12, 0.0, 0.0)
		"thud":
			buf = _burst(0.16, 28.0, 0.1, 80.0, 1.0)
		"clank":
			buf = _burst(0.22, 18.0, 0.8, 1400.0, 0.6)
		"click":
			buf = _burst(0.03, 120.0, 0.9, 2000.0, 0.3)
		"reload":
			buf = _burst(0.08, 50.0, 0.7, 900.0, 0.4)
		"scream", "shriek", "whisper", "knock", "sting", "cry", "groan", "buzz", "whiz", "beep", "ignite", "chime", "fail", "crack", "steam", "magnet", "heartbeat", "static", "drip", "slam":
			buf = _horror(sound)
		_:  # growl
			buf.resize(int(RATE * 0.6))
			var ph := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				ph += (70.0 + 25.0 * sin(t * 31.0)) / RATE
				var saw := fmod(ph, 1.0) * 2.0 - 1.0
				buf[i] = saw * 0.5 * sin(PI * t / 0.6) * (0.7 + 0.3 * sin(t * 190.0))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if sound == "cry":
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = buf.size()
	_cache[sound] = w
	return w


## A sound that stays in place and loops (a child crying in a hut, a humming fuse box).
static func loop(parent: Node, sound: String, pos: Vector3, db := 0.0, reach := 40.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = db
	p.unit_size = 6.0
	p.max_distance = reach
	parent.add_child(p)
	p.global_position = pos
	p.play()
	return p


## Plays a sound flat in both ears (for jump scares that must not be missed).
static func play_flat(parent: Node, sound: String, db := 0.0, pitch := 1.0) -> void:
	if not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound)
	p.volume_db = db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_caption(parent, sound, null)


## Band-pass filter (state variable), run over the whole buffer. `f` may change per sample via `sweep`.
static func _band(src: PackedFloat32Array, f0: float, f1: float, q: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var low := 0.0
	var band := 0.0
	var n := float(src.size())
	for i in src.size():
		var f := 2.0 * sin(PI * lerpf(f0, f1, i / n) / RATE)
		var high := src[i] - low - q * band
		band += f * high
		low += f * band
		out[i] = band
	return out


static func _horror(sound: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	match sound:
		"heartbeat":
			# lub-dub: two low thumps, felt more than heard
			buf.resize(int(RATE * 0.9))
			for k in 2:
				var at := int(RATE * (0.0 if k == 0 else 0.24))
				for j in int(RATE * 0.22):
					var t := float(j) / RATE
					if at + j < buf.size():
						buf[at + j] += sin(TAU * (52.0 - t * 60.0) * t) * exp(-t * 18.0) * (1.0 if k == 0 else 0.75)
		"static":
			# a dead radio: hiss, crackle and, under it, almost a voice
			var length := 2.6
			buf.resize(int(RATE * length))
			for i in buf.size():
				var t := float(i) / RATE
				var hiss := (randf() * 2.0 - 1.0) * 0.35
				var crack := (randf() * 2.0 - 1.0) * (1.0 if randf() < 0.002 else 0.0)
				var voice := sin(TAU * (140.0 + 40.0 * sin(t * 3.1)) * t) * (0.5 + 0.5 * sin(t * 11.0)) * 0.25 * smoothstep(0.6, 1.2, t) * (1.0 - smoothstep(1.9, 2.4, t))
				buf[i] = (hiss + crack + voice) * minf(t * 20.0, 1.0) * (1.0 - smoothstep(2.3, 2.6, t))
			buf = _band(buf, 900.0, 1600.0, 0.6)
		"drip":
			buf.resize(int(RATE * 0.35))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = sin(TAU * (900.0 + 1400.0 * exp(-t * 30.0)) * t) * exp(-t * 22.0) * 0.6
		"slam":
			# a door thrown shut: crack, boom, rattle
			buf.resize(int(RATE * 1.2))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = (sin(TAU * 70.0 * t) * exp(-t * 9.0) + (randf() - 0.5) * exp(-t * 40.0) * 1.6 + (randf() - 0.5) * 0.25 * exp(-t * 4.0) * (0.5 + 0.5 * sin(t * 90.0))) * 0.9
		"scream":
			# two detuned saws sweeping up and down, through a harsh mouth formant
			var length := 1.4
			buf.resize(int(RATE * length))
			var p1 := 0.0
			var p2 := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				var f := 380.0 + 700.0 * sin(PI * minf(t / 0.9, 1.0)) * (1.0 - t * 0.35) + sin(t * 47.0) * 30.0
				p1 = fmod(p1 + f / RATE, 1.0)
				p2 = fmod(p2 + f * 1.031 / RATE, 1.0)
				var s := (p1 * 2.0 - 1.0) + (p2 * 2.0 - 1.0) + (randf() * 2.0 - 1.0) * 0.6
				var env := minf(t * 30.0, 1.0) * exp(-maxf(t - 0.7, 0.0) * 5.0)
				buf[i] = s * env
			buf = _band(buf, 1500.0, 2400.0, 0.5)
			for i in buf.size():
				buf[i] = tanh(buf[i] * 3.0) * 0.8
		"shriek":
			var length := 1.7
			buf.resize(int(RATE * length))
			var ph := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				var f := 1500.0 * exp(-t * 1.6) + 180.0 + sin(t * 70.0) * 40.0
				ph += f / RATE
				var s := sin(ph * TAU) * 0.6 + sin(ph * TAU * 1.414) * 0.4 + (randf() - 0.5) * 0.5
				buf[i] = s * minf(t * 20.0, 1.0) * exp(-t * 1.8) * 0.8
		"whisper":
			# breathy noise chopped into syllables, high and close
			var length := 2.2
			buf.resize(int(RATE * length))
			var syl := 0.0
			var on := 1.0
			for i in buf.size():
				var t := float(i) / RATE
				syl -= 1.0 / RATE
				if syl <= 0.0:
					syl = randf_range(0.08, 0.22)
					on = 1.0 if randf() < 0.75 else 0.15
				buf[i] = (randf() * 2.0 - 1.0) * on * sin(PI * t / length)
			buf = _band(buf, 3200.0, 2400.0, 0.9)
			var lp := 0.0
			for i in buf.size():
				lp += (buf[i] - lp) * 0.08
				buf[i] = lp * 3.2
		"knock":
			buf.resize(int(RATE * 1.0))
			for k in 3:
				var at := int(RATE * (0.0 + k * 0.27 + (0.03 if k == 2 else 0.0)))
				for j in int(RATE * 0.18):
					var t := float(j) / RATE
					if at + j < buf.size():
						buf[at + j] += sin(TAU * 170.0 * t) * exp(-t * 32.0) * 0.9 + (randf() - 0.5) * exp(-t * 160.0) * 0.8
		"sting":
			# a dissonant cluster that hits at once and rings out, with a deep thud under it
			var length := 3.4
			buf.resize(int(RATE * length))
			var fs := [466.2, 493.9, 1046.5, 739.99, 1108.7]
			for i in buf.size():
				var t := float(i) / RATE
				var s := 0.0
				for f in fs:
					var ff: float = f
					s += sin(TAU * ff * t * (1.0 + 0.004 * sin(t * 5.0))) / fs.size()
				s += sin(TAU * 42.0 * t) * exp(-t * 3.0) * 0.9
				s += (randf() - 0.5) * exp(-t * 18.0) * 0.6
				buf[i] = s * minf(t * 60.0, 1.0) * exp(-t * 1.1)
		"cry":
			# a child sobbing: three voiced sobs and a shaky breath in, on a loop
			var length := 3.6
			buf.resize(int(RATE * length))
			var ph := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				var s := 0.0
				var sob := fmod(t, 1.2)
				if sob < 0.62:
					var f0 := 430.0 - sob * 140.0 + sin(t * 38.0) * 14.0
					ph = fmod(ph + f0 / RATE, 1.0)
					var pulse := (1.0 if ph < 0.18 else 0.0) - 0.18
					var env := sin(PI * sob / 0.62) * (0.6 + 0.4 * sin(t * 21.0))
					s = pulse * env * 2.2
				elif sob > 0.82:
					s = (randf() - 0.5) * 0.35 * sin(PI * (sob - 0.82) / 0.38)
				buf[i] = s
			var a := _band(buf, 950.0, 950.0, 0.35)
			var b := _band(buf, 2700.0, 2700.0, 0.4)
			for i in buf.size():
				buf[i] = (a[i] * 1.1 + b[i] * 0.6)
		"groan":
			var length := 1.8
			buf.resize(int(RATE * length))
			var ph := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				ph = fmod(ph + (92.0 - t * 14.0 + sin(t * 9.0) * 3.0) / RATE, 1.0)
				buf[i] = (ph * 2.0 - 1.0) * sin(PI * t / length) * (0.75 + 0.25 * sin(t * 13.0))
			buf = _band(buf, 520.0, 380.0, 0.6)
			for i in buf.size():
				buf[i] *= 2.6
		"buzz":
			buf.resize(int(RATE * 0.7))
			for i in buf.size():
				var t := float(i) / RATE
				var sq := 1.0 if fmod(t * 100.0, 1.0) < 0.5 else -1.0
				buf[i] = (sq * 0.25 + (randf() - 0.5) * (0.9 if randf() < 0.05 else 0.1)) * exp(-t * 2.0)
		"whiz":
			buf.resize(int(RATE * 0.28))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = (randf() * 2.0 - 1.0) * sin(PI * t / 0.28)
			buf = _band(buf, 5200.0, 1600.0, 0.25)
			for i in buf.size():
				buf[i] *= 1.6
		"beep":
			buf.resize(int(RATE * 0.09))
			for i in buf.size():
				buf[i] = sin(TAU * 1420.0 * i / RATE) * 0.35
		"fail":
			buf.resize(int(RATE * 0.45))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = (fmod(t * 110.0, 1.0) * 2.0 - 1.0) * 0.4 * (1.0 - t / 0.45)
		"ignite":
			buf.resize(int(RATE * 1.1))
			var lp := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				lp += ((randf() * 2.0 - 1.0) - lp) * (0.03 + t * 0.25)
				buf[i] = lp * 2.5 * minf(t * 6.0, 1.0) * exp(-t * 1.5) + ((randf() - 0.5) if randf() < 0.01 else 0.0)
		"chime":
			buf.resize(int(RATE * 1.8))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = (sin(TAU * 1046.5 * t) + 0.35 * sin(TAU * 2890.0 * t) * exp(-t * 6.0)) * exp(-t * 2.4) * 0.5
		"crack":
			buf = _burst(0.9, 5.0, 0.6, 55.0, 1.0)
			for i in range(0, buf.size(), 997):
				buf[i] = 1.0
		"steam":
			buf.resize(int(RATE * 1.4))
			for i in buf.size():
				var t := float(i) / RATE
				buf[i] = (randf() * 2.0 - 1.0) * minf(t * 10.0, 1.0) * exp(-t * 1.6) * 0.8
			buf = _band(buf, 3800.0, 2000.0, 0.7)
			for i in buf.size():
				buf[i] *= 1.8
		"magnet":
			buf.resize(int(RATE * 1.6))
			var ph := 0.0
			for i in buf.size():
				var t := float(i) / RATE
				ph += (60.0 + t * 90.0) / RATE
				buf[i] = (sin(ph * TAU) * 0.6 + sin(ph * TAU * 2.01) * 0.3) * minf(t * 4.0, 1.0) * (1.0 - t / 1.6) * (0.8 + 0.2 * sin(t * 60.0))
	return buf


## Noise burst: length s, decay rate, low-pass amount (1 = bright), thump frequency and level.
static func _burst(length: float, decay: float, bright: float, thump_hz: float, thump: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(RATE * length))
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * bright
		var e := exp(-t * decay)
		buf[i] = lp * e * 1.6 + sin(TAU * thump_hz * t * (1.0 - t * 0.8)) * thump * exp(-t * decay * 1.5)
	return buf
