class_name Stats
extends Node
## Health, stamina, body warmth, injuries and carried weight.
## The player calls tick() every physics frame.

signal note(text: String)
signal died(cause: String)

var inv: Inventory
var health := 100.0
var stamina := 100.0
var warmth := 100.0
var wet := 0.0          # 0 dry .. 1 soaked
var bleeding := 0.0     # health lost per second
var sprain := false
var pills := 0.0        # seconds of painkillers left
var fed := 0.0          # seconds of "well fed" left
var warmer := 0.0       # seconds of hand warmer left
var warm_rate := 0.0    # last warmth change per second (for the HUD arrow)

var _rest := 0.0
var _winded := false
var _cold_warned := false
var _dead := false


func load_ratio() -> float:
	return inv.weight() / maxf(inv.capacity(), 1.0)


func overloaded() -> bool:
	return load_ratio() > 1.0


func can_sprint() -> bool:
	return not _winded and stamina > 1.0 and not overloaded() and (not sprain or pills > 0.0)


func speed_mult() -> float:
	var m := inv.mobility()
	var l := load_ratio()
	if l > 1.0:
		m *= 0.55
	elif l > 0.7:
		m *= lerpf(1.0, 0.8, (l - 0.7) / 0.3)
	if sprain and pills <= 0.0:
		m *= 0.6
	if warmth < 20.0:
		m *= 0.85
	return m


func use_stamina(amount: float) -> bool:
	if stamina < amount * 0.5:
		return false
	stamina = maxf(stamina - amount, 0.0)
	_rest = 0.0
	return true


## shelter: 0 outside, 1 inside a cold building, 2 inside a heated one.
func tick(delta: float, sprinting: bool, moving: bool, in_water: bool, shelter: int, storm: float) -> void:
	if _dead:
		return
	pills = maxf(pills - delta, 0.0)
	fed = maxf(fed - delta, 0.0)
	warmer = maxf(warmer - delta, 0.0)

	# --- stamina
	if sprinting:
		stamina = maxf(stamina - 9.0 * (1.0 + maxf(load_ratio() - 0.5, 0.0)) * delta, 0.0)
		_rest = 0.0
		if stamina <= 0.0:
			_winded = true
	else:
		_rest += delta
		if _rest > 1.0:
			var regen := 14.0
			if fed > 0.0:
				regen *= 1.5
			if warmth < 25.0:
				regen *= 0.5
			stamina = minf(stamina + regen * delta, 100.0)
		if stamina > 25.0:
			_winded = false

	# --- warmth
	if in_water:
		wet = 1.0
	else:
		wet = maxf(wet - delta / (25.0 if shelter == 2 else 90.0), 0.0)
	# summer: only rain and storms chill you, the lake is cool but not deadly
	var cold := (22.0 * storm) if GameMode.summer() else (34.0 + 40.0 * storm)
	if shelter >= 1:
		cold *= 0.4
	if in_water:
		cold = 60.0 if GameMode.summer() else 170.0
	var body := inv.warmth() * 0.6 * (1.0 - 0.7 * wet)
	if sprinting:
		body += 12.0
	elif moving:
		body += 5.0
	if warmer > 0.0:
		body += 12.0
	warm_rate = clampf((body - cold) * 0.012, -3.0, 1.2)
	if shelter == 2 and not in_water:
		warm_rate = 3.0
	warmth = clampf(warmth + warm_rate * delta, 0.0, 100.0)
	if warmth < 25.0 and not _cold_warned:
		_cold_warned = true
		note.emit("You are freezing. Find a heated house or warmer clothes.")
	elif warmth > 45.0:
		_cold_warned = false

	# --- health
	if warmth <= 0.0:
		_damage(1.5 * delta, "cold")
	if bleeding > 0.0:
		_damage(bleeding * delta, "blood loss")
		# wounds clot by themselves, slowly; small ones faster. A bandage is the quick way.
		bleeding = maxf(bleeding - (0.06 if bleeding < 0.3 else 0.02) * delta, 0.0)
	if health > 0.0 and health < 100.0 and bleeding <= 0.0 and warmth > 50.0 and fed > 0.0:
		health = minf(health + 0.4 * delta, 100.0)


func _damage(amount: float, cause: String) -> void:
	health -= amount
	if health <= 0.0 and not _dead:
		health = 0.0
		_dead = true
		died.emit(cause)


## Damage from outside (bullets, claws, ...). Armour takes its share.
func hurt(amount: float, bleed := 0.0, cause := "wounds", pen := 0.0) -> void:
	var k := Damage.apply(1.0, inv.armor(), pen) * Settings.dmg_taken()
	bleeding = minf(bleeding + bleed * k, 3.0)
	_damage(amount * k, cause)


func fall(speed: float) -> void:
	if speed < 9.0:
		return
	_damage((speed - 9.0) * 8.0, "a fall")
	if speed > 12.0 and not sprain:
		sprain = true
		note.emit("You sprained your ankle. A splint fixes it.")
	else:
		note.emit("That hurt.")


## Use a consumable. Returns false when it would be wasted.
func consume(id: String) -> bool:
	match str(Items.get_item(id).get("use", "")):
		"food":
			fed = 240.0
			stamina = minf(stamina + 30.0, 100.0)
			note.emit("You ate. Stamina recovers faster for a while.")
		"tea":
			warmth = minf(warmth + 30.0, 100.0)
			note.emit("Hot tea. That helps.")
		"warmer":
			warmer = 120.0
			note.emit("The hand warmer starts to glow.")
		"bandage":
			if bleeding <= 0.0 and health >= 100.0:
				note.emit("You don't need a bandage right now.")
				return false
			bleeding = 0.0
			health = minf(health + 10.0, 100.0)
			note.emit("Bandaged.")
		"medkit":
			if bleeding <= 0.0 and health >= 100.0:
				note.emit("You are not hurt.")
				return false
			bleeding = 0.0
			health = minf(health + 60.0, 100.0)
			note.emit("Wounds treated.")
		"splint":
			if not sprain:
				note.emit("Nothing to splint.")
				return false
			sprain = false
			note.emit("Ankle splinted.")
		"pills":
			pills = 90.0
			note.emit("The pain fades.")
		_:
			return false
	return true


func revive() -> void:
	_dead = false
	health = 60.0
	stamina = 100.0
	warmth = 70.0
	wet = 0.0
	bleeding = 0.0
	sprain = false


func status() -> Array[String]:
	var s: Array[String] = []
	if bleeding > 0.0:
		s.append("Bleeding")
	if sprain:
		s.append("Sprained ankle")
	if warmth < 25.0:
		s.append("Freezing")
	if wet > 0.3:
		s.append("Wet")
	if overloaded():
		s.append("Overloaded")
	if pills > 0.0:
		s.append("Painkillers")
	if fed > 0.0:
		s.append("Well fed")
	return s


func to_dict() -> Dictionary:
	return {"health": health, "stamina": stamina, "warmth": warmth, "wet": wet, "bleeding": bleeding,
		"sprain": sprain, "pills": pills, "fed": fed, "warmer": warmer}


func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", 100.0))
	stamina = float(d.get("stamina", 100.0))
	warmth = float(d.get("warmth", 100.0))
	wet = float(d.get("wet", 0.0))
	bleeding = float(d.get("bleeding", 0.0))
	sprain = bool(d.get("sprain", false))
	pills = float(d.get("pills", 0.0))
	fed = float(d.get("fed", 0.0))
	warmer = float(d.get("warmer", 0.0))
	_dead = false
