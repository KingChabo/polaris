class_name Spinner
extends Node3D
## Keeps old mechanical decorations moving: steady, stuttering (runs, sticks,
## jerks free) or rocking back and forth.

var axis := Vector3.UP
var speed := 0.5
var amp := 0.3
var mode := "steady"

var _t := 0.0
var _angle := 0.0
var _base: Basis


func _ready() -> void:
	_base = transform.basis
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	match mode:
		"steady":
			_angle += speed * delta
		"stutter":
			var phase := fmod(_t, 9.0)
			var s := speed
			if phase > 5.0 and phase < 7.5:
				s = 0.0
			elif phase >= 7.5 and phase < 7.8:
				s = -speed * 1.5
			elif phase >= 4.0 and phase <= 5.0:
				s = speed * (5.0 - phase)
			_angle += s * delta * (0.8 + 0.2 * sin(_t * 13.0))
		"rock":
			_angle = sin(_t * speed) * amp + sin(_t * speed * 7.3) * amp * 0.05
	transform.basis = _base * Basis(axis, _angle)
