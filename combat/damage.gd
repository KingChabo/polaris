class_name Damage
## How armour and armour-piercing rounds change damage.

const HEAD := 2.2   # head shots

## armour 0..100, pen = how much armour the hit ignores.
static func apply(amount: float, armor: float, pen: float) -> float:
	var eff := maxf(armor - pen, 0.0)
	return amount * (1.0 - clampf(eff / 100.0, 0.0, 0.8))
