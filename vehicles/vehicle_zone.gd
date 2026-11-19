class_name VehicleZone
extends StaticBody3D
## A spot on a vehicle you can look at and use with E: a door or the bonnet.

var vehicle: Vehicle
var kind := "door"
var prompt: String:
	get:
		if kind == "door":
			return vehicle.door_prompt()
		return str(vehicle.service_action(vehicle.world.player)[1])


func interact(who: Object) -> void:
	if kind == "door":
		vehicle.use_door(who)
	else:
		vehicle.service(who)


func hit(dmg: float, pos: Vector3, dir: Vector3, pen: float, shooter: Node) -> void:
	vehicle.hit(dmg, pos, dir, pen, shooter)
