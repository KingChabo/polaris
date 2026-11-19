class_name Synth
extends RefCounted
## Sounds made from nothing but maths: the worn music-box tape and the garbled
## announcement that the village loudspeakers still play.

const RATE := 11025

# "Stille Nacht" (1818, public domain). [semitones above C, length in eighth notes]
const MELODY: Array = [
	[7, 3], [9, 1], [7, 2], [4, 6], [7, 3], [9, 1], [7, 2], [4, 6],
	[14, 4], [14, 2], [11, 6], [12, 4], [12, 2], [7, 6],
	[9, 4], [9, 2], [12, 3], [11, 1], [9, 2], [7, 3], [9, 1], [7, 2], [4, 6],
	[9, 4], [9, 2], [12, 3], [11, 1], [9, 2], [7, 3], [9, 1], [7, 2], [4, 6],
	[14, 4], [14, 2], [17, 3], [14, 1], [11, 2], [12, 6], [16, 6],
	[12, 2], [7, 2], [4, 2], [7, 3], [5, 1], [2, 2], [0, 6], [-99, 6],
]

# The horror mode's own lullaby (written for POLARIS): A minor with a tritone that never resolves.
# [semitones above A4, length in quarter notes]
const LULLABY: Array = [
	[0, 2], [3, 1], [7, 2], [6, 1], [3, 3],
	[0, 2], [-1, 1], [0, 2], [3, 1], [2, 3],
	[-2, 2], [1, 1], [5, 2], [3, 1], [0, 3],
	[-1, 2], [-4, 1], [-6, 3], [-99, 3],
]

static var _music: AudioStreamWAV
static var _voice: AudioStreamWAV
static var _lullaby: AudioStreamWAV


static func music() -> AudioStreamWAV:
	if _music == null:
		_music = _wav(_tape(_music_box()))
	return _music


## Slow, detuned music box over a low tritone drone, played through the worn tape.
static func lullaby() -> AudioStreamWAV:
	if _lullaby == null:
		var q := 0.66
		var total := 0
		for n in LULLABY:
			total += int(n[1])
		var buf := PackedFloat32Array()
		buf.resize(int(total * q * RATE) + RATE * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		var t := 0.0
		for n in LULLABY:
			var semi: int = n[0]
			if semi > -50:
				var f := 440.0 * pow(2.0, (semi + rng.randf_range(-0.18, 0.18)) / 12.0)
				var start := int(t * RATE)
				var w1 := TAU * f / RATE
				var w2 := TAU * f * 2.97 / RATE
				var w3 := TAU * f * 0.5 / RATE
				for i in int(2.2 * RATE):
					var e := exp(-i * 0.00022)
					buf[start + i] += (sin(w1 * i) * e + sin(w2 * i) * e * e * e * 0.25 + sin(w3 * i) * e * 0.18) * 0.26
			t += int(n[1]) * q
		# the drone: A and E-flat a tritone apart, swelling and fading
		for i in buf.size():
			var s := float(i) / RATE
			var swell := 0.5 + 0.5 * sin(TAU * s / 11.0)
			buf[i] += (sin(TAU * 55.0 * s) * 0.5 + sin(TAU * 77.78 * s + sin(s * 0.7)) * 0.35 + sin(TAU * 110.4 * s) * 0.2) * 0.16 * swell
		_lullaby = _wav(_tape(buf))
	return _lullaby


static func announcement() -> AudioStreamWAV:
	if _voice == null:
		_voice = _wav(_make_voice())
	return _voice


static func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


static func _music_box() -> PackedFloat32Array:
	var eighth := 0.37
	var total := 0
	for n in MELODY:
		total += int(n[1])
	var buf := PackedFloat32Array()
	buf.resize(int(total * eighth * RATE) + RATE)
	var t := 0.0
	for n in MELODY:
		var semi: int = n[0]
		var beats: int = n[1]
		if semi > -50:
			var f := 523.25 * pow(2.0, semi / 12.0)
			var start := int(t * RATE)
			var ring := int(1.3 * RATE)
			var w1 := TAU * f / RATE
			var w2 := TAU * f * 3.01 / RATE
			for i in ring:
				var e := exp(-i * 0.00035)
				buf[start + i] += (sin(w1 * i) * e + sin(w2 * i) * e * e * e * 0.3) * 0.3
			# soft low note under each bar
			if beats >= 4:
				var w3 := TAU * f * 0.25 / RATE
				for i in ring:
					buf[start + i] += sin(w3 * i) * exp(-i * 0.0005) * 0.12
		t += beats * eighth
	return buf


## Makes clean sound seem to come off a stretched old tape through a horn speaker.
static func _tape(src: PackedFloat32Array) -> PackedFloat32Array:
	var n := src.size() - RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var crack := 0.0
	for i in n:
		var pos := i + 40.0 * sin(i * 0.00021) + 6.0 * sin(i * 0.0031) + 45.0
		var i0 := int(pos)
		var fr := pos - i0
		var s := src[i0] * (1.0 - fr) + src[i0 + 1] * fr
		# volume sags and drops out now and then
		var drop := 0.75 + 0.25 * sin(i * 0.00007)
		if fmod(i * 0.00003, 1.0) > 0.93:
			drop *= 0.15
		s *= drop
		if rng.randf() < 0.0006:
			crack = rng.randf_range(-0.7, 0.7)
		crack *= 0.8
		s += crack + rng.randf_range(-0.012, 0.012)
		lp += (s - lp) * 0.55
		hp += (lp - hp) * 0.06
		out[i] = tanh((lp - hp) * 2.6) * 0.6
	return out


## A voice that is almost words: chime, then mangled syllables, then long silence.
static func _make_voice() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(RATE * 34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var t := 0.5
	for f in [659.3, 523.3, 392.0]:
		var start := int(t * RATE)
		var w: float = TAU * f / RATE
		for i in int(1.2 * RATE):
			buf[start + i] += sin(w * i) * exp(-i * 0.0004) * 0.4
		t += 0.55
	t += 1.0
	var vowels: Array = [[730, 1090], [270, 2290], [300, 870], [530, 1840], [570, 840], [440, 1020]]
	var phase := 0.0
	for word in 11:
		var syll := rng.randi_range(1, 4)
		for sy in syll:
			var v: Array = vowels[rng.randi() % vowels.size()]
			var dur := rng.randf_range(0.13, 0.26)
			var f0 := rng.randf_range(95.0, 125.0)
			var th1: float = TAU * v[0] / RATE
			var th2: float = TAU * v[1] / RATE
			var a1 := 0.0; var a2 := 0.0; var b1 := 0.0; var b2 := 0.0
			var start := int(t * RATE)
			var len_s := int(dur * RATE)
			for i in len_s:
				phase = fmod(phase + f0 * (1.0 - 0.15 * i / len_s) / RATE, 1.0)
				var x := (phase * 2.0 - 1.0) + rng.randf_range(-0.15, 0.15)
				var y1 := 1.92 * cos(th1) * a1 - 0.9216 * a2 + x * 0.04
				a2 = a1; a1 = y1
				var y2 := 1.92 * cos(th2) * b1 - 0.9216 * b2 + x * 0.04
				b2 = b1; b1 = y2
				var env := sin(PI * i / len_s)
				buf[start + i] += (y1 + y2 * 0.6) * env * 0.5
			t += dur * 0.9
		t += rng.randf_range(0.12, 0.45)
	# through the broken horn: clipped, crushed, hissing
	var out := PackedFloat32Array()
	out.resize(buf.size())
	var hold := 0.0
	for i in buf.size():
		if i % 2 == 0:
			hold = tanh(buf[i] * 6.0) * 0.5
		var active := 1.0 if i < int((t + 0.5) * RATE) else 0.0
		out[i] = hold * (0.7 + 0.3 * sin(i * 0.0009)) + rng.randf_range(-0.02, 0.02) * active
	return out
