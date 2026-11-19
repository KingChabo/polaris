class_name Flicker
extends OmniLight3D
## A lamp with a bad contact: dips, buzzes and sometimes goes dark for a moment.

var base := 2.0
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	var slow := sin(_t * 0.7 + _seed) * sin(_t * 0.23 + _seed * 2.0)
	var e := 1.0
	if slow > 0.35:
		e = 0.25 + 0.75 * float(fmod(_t * 17.0 + _seed, 1.0) > 0.4)
	if slow > 0.8:
		e = 0.05
	light_energy = base * e
