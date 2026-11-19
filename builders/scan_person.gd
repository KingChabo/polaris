class_name ScanPerson
extends Node3D
## A real person made in Blender (MakeHuman figure, dressed in a parka and gloves, skinned)
## standing in for the code-built figure. The figure's joints stay where the AI poses them
## (torso, head, arms, elbows, hands, legs, knees); their meshes are dropped, the joints are
## moved onto the skeleton's joints, and every frame the skeleton copies their rotations.

const DIR := "people/"
const BODIES := ["m_work", "m_old", "m_dark", "m_asian", "f_young", "f_old"]
const HEAD_UP := -0.035      # code head centre (y 0.115) vs the skin's head bone
## bone -> [joint meta, point the bone straight down at rest]
const MAP := {
	"spine_01": ["torso", false], "head": ["head", false],
	"upperarm_l": ["arm_l", true], "lowerarm_l": ["elbow_l", true], "hand_l": ["hand_l", false],
	"upperarm_r": ["arm_r", true], "lowerarm_r": ["elbow_r", true], "hand_r": ["hand_r", false],
	"thigh_l": ["leg_l", true], "calf_l": ["knee_l", true], "foot_l": ["knee_l", false],
	"thigh_r": ["leg_r", true], "calf_r": ["knee_r", true], "foot_r": ["knee_r", false],
}
static var enabled := true

var _figure: Node3D
var _skel: Skeleton3D
var _order: PackedInt32Array            # bones parents-first
var _rest := []                         # local rest transforms (skeleton space)
var _parent := PackedInt32Array()
var _joint := []                        # Node3D or null per bone
var _align := []                        # Basis per bone: realigned rest (global, skeleton space)
var _to_skel := Basis()                 # figure space -> skeleton space (rotation)
var _skip := 0
var _live := PackedInt32Array()        # bones posed every frame: the mapped ones and their parents
var _glob := []                         # scratch: global poses (skeleton space)


static func wanted(look: Dictionary) -> bool:
	return enabled and bool(look.get("scan", true)) and str(look.get("eyes", "")) != "glow" \
		and str(look.get("skin", "")) != "frost_skin" and ModelLib.has(DIR + pick(look))


## Which body fits a look: a "body" key wins, else skin and hair choose.
static func pick(look: Dictionary) -> String:
	if look.has("body"):
		return str(look["body"])
	var skin := str(look.get("skin", "skin"))
	var hair := str(look.get("hair", ""))
	var key := hash(str(look.get("coat", "")) + str(look.get("hat", "")) + str(look.get("tall", 1.0)))
	if skin in ["skin_dark"]:
		return "m_dark"
	if hair in ["white", "grey"]:
		return "m_old"
	if skin == "skin_tan":
		return "m_asian"
	return ["m_work", "m_work", "m_asian", "m_old"][absi(key) % 4] if skin != "skin_pale" else "m_work"


## Swaps the code figure's skin for a scanned one. Keeps every joint and meta.
static func dress(root: Node3D, look: Dictionary) -> void:
	var scene := ModelLib.spawn(DIR + pick(look))
	if scene == null:
		return
	# drop the code meshes, keep the joints
	for n in root.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).mesh = null
	scene.rotation.y = PI          # MakeHuman faces +Z in Godot, the figures face -Z
	var sp := ScanPerson.new()
	sp.name = "Scan"
	sp.process_priority = 100      # after the AI has posed the joints
	root.add_child(sp)
	sp.add_child(scene)
	sp._figure = root
	sp._setup(scene, look)
	root.set_meta("scan", sp)


func _setup(scene: Node3D, look: Dictionary) -> void:
	var sk := scene.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty():
		return
	_skel = sk[0]
	# skeleton space -> figure space
	var m := Transform3D.IDENTITY
	var n: Node = _skel
	while n != _figure and n != null:
		m = (n as Node3D).transform * m
		n = n.get_parent()
	var fig_basis := m.basis.orthonormalized()
	_to_skel = fig_basis.inverse()
	var count := _skel.get_bone_count()
	_parent.resize(count)
	var glob := []
	glob.resize(count)
	for i in count:
		_parent[i] = _skel.get_bone_parent(i)
		_rest.append(_skel.get_bone_rest(i))
	_order = _sorted(count)
	for i in _order:
		var p := _parent[i]
		glob[i] = _rest[i] if p < 0 else (glob[p] as Transform3D) * (_rest[i] as Transform3D)
	_joint.resize(count)
	_align.resize(count)
	var down := (_to_skel * Vector3.DOWN).normalized()
	var turn := {}
	for i in _order:
		var bname := _skel.get_bone_name(i)
		var g: Transform3D = glob[i]
		var q := Basis()
		if MAP.has(bname):
			var spec: Array = MAP[bname]
			_joint[i] = _figure.get_meta(spec[0]) if _figure.has_meta(spec[0]) else null
			if spec[1]:
				var child := _first_child(i)
				if child >= 0:
					var dir := ((glob[child] as Transform3D).origin - g.origin).normalized()
					q = _between(dir, down)
			elif _parent[i] >= 0 and turn.has(_parent[i]):
				q = turn[_parent[i]]
		turn[i] = q
		_align[i] = q * g.basis.orthonormalized()
	# only bones that turn (and their parents) are posed each frame; the rest keep their rest pose
	var need := {}
	for i in _order:
		if _joint[i] != null:
			var b := i
			while b >= 0 and not need.has(b):
				need[b] = true
				b = _parent[b]
	for i in _order:
		if need.has(i):
			_live.append(i)
		else:
			_skel.set_bone_pose_rotation(i, (_rest[i] as Transform3D).basis.get_rotation_quaternion())
	_glob = glob.duplicate()
	# move the code joints onto the skeleton's joints (figure space)
	var pos := func(b: String) -> Vector3:
		var i := _skel.find_bone(b)
		return m * (glob[i] as Transform3D).origin if i >= 0 else Vector3.ZERO
	var torso: Node3D = _figure.get_meta("torso")
	var hip: Vector3 = pos.call("spine_01")
	torso.position = Vector3(0, hip.y, 0)
	_figure.set_meta("hip", hip.y)
	var head: Node3D = _figure.get_meta("head")
	head.position = pos.call("head") - torso.position + Vector3(0, HEAD_UP, 0)
	for tag in ["l", "r"]:
		var arm: Node3D = _figure.get_meta("arm_" + tag)
		var el: Node3D = _figure.get_meta("elbow_" + tag)
		var hand: Node3D = _figure.get_meta("hand_" + tag)
		var sh: Vector3 = pos.call("upperarm_" + tag)
		var elb: Vector3 = pos.call("lowerarm_" + tag)
		var wr: Vector3 = pos.call("hand_" + tag)
		var fing: Vector3 = pos.call("middle_01_" + tag)
		arm.position = sh - torso.position
		el.position = Vector3(0, -sh.distance_to(elb), 0)
		hand.position = Vector3(0, -elb.distance_to(wr) - wr.distance_to(fing) * 0.75, -0.01)
		var leg: Node3D = _figure.get_meta("leg_" + tag)
		var knee: Node3D = _figure.get_meta("knee_" + tag)
		var th: Vector3 = pos.call("thigh_" + tag)
		leg.position = th
		knee.position = Vector3(0, -th.distance_to(pos.call("calf_" + tag)), 0)
	# gear and hat from the code figure, on the moved joints
	var coat := str(look.get("coat", "olive")) + "_coat"
	var fur := "fur_brown_in"
	var gk := MeshKit.new()
	Humanoid._gear(gk, look, coat, fur, true)
	var gear := gk.node(false)
	gear.position.y = -0.04
	torso.add_child(gear)
	var hat := str(look.get("hat", "hood"))
	if hat != "none":
		var hk := MeshKit.new()
		Humanoid._hat(hk, look, hat, str(look.get("hat_col", look.get("coat", "olive"))) + "_in", fur)
		var hn := hk.node(false)
		head.add_child(hn)
		_fit_hat(scene, hn, pos.call("head"))
	_tint(scene, look)
	_pose()


## The hats are made for the round code head. A scanned head (with its hair) is longer,
## wider or flatter, so the hat is measured onto it: same width and depth, sitting on the crown.
func _fit_hat(scene: Node3D, hat: Node3D, head_bone: Vector3) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var n := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null or "parka" in inst.name.to_lower() or "trouser" in inst.name.to_lower():
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = inst
		while p != _figure and p != null:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for si in inst.mesh.get_surface_count():
			var arr := inst.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for vi in range(0, verts.size(), 3):
				var v := xf * verts[vi]
				if v.y < head_bone.y + 0.02 or Vector2(v.x - head_bone.x, v.z - head_bone.z).length() > 0.17:
					continue
				lo = lo.min(v)
				hi = hi.max(v)
				n += 1
	if n < 30:
		return
	var rx := (hi.x - lo.x) * 0.5
	var rz := (hi.z - lo.z) * 0.5
	var sx := clampf(rx / 0.092, 0.75, 1.45)
	var sz := clampf(rz / 0.102, 0.75, 1.45)
	var sy := (sx + sz) * 0.5
	var k := 1.04          # a little room for the hair under it
	hat.scale = Vector3(sx, sy, sz) * k
	var origin := head_bone + Vector3(0, HEAD_UP, 0)
	var top_local := hi.y - origin.y
	hat.position = Vector3((lo.x + hi.x) * 0.5 - origin.x, top_local + 0.006 - 0.23 * sy * k, (lo.z + hi.z) * 0.5 - origin.z)


## Parka and trousers in the look's colours.
func _tint(scene: Node3D, look: Dictionary) -> void:
	var cols := {"parka": _col(str(look.get("coat", "olive"))).lightened(0.08),
		"trousers": _col(str(look.get("trousers", "black"))).lightened(0.05)}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		inst.visibility_range_end = 140.0
		for s in inst.mesh.get_surface_count():
			var mat := inst.mesh.surface_get_material(s)
			if not mat is BaseMaterial3D:
				continue
			for key in cols:
				if mat.resource_name.begins_with(key):
					var c := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					c.albedo_color = cols[key]
					c.cull_mode = BaseMaterial3D.CULL_DISABLED
					c.uv1_scale = Vector3(6, 6, 1)        # fine weave, not chain mail
					c.normal_scale = 0.45
					inst.set_surface_override_material(s, c)


static func _col(name: String) -> Color:
	var d: Array = Mats.DEFS.get(name, [0, Color(0.3, 0.3, 0.3)])
	return d[1]


func _process(_delta: float) -> void:
	if _skel == null or not is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_squared_to(global_position)
		if d > 19600.0:           # past 140 m the body is not drawn
			return
		var every := 1 if d < 900.0 else (2 if d < 3600.0 else 5)
		_skip = (_skip + 1) % every
		if _skip != 0:
			return
		# behind the camera: nobody sees the pose
		if d > 64.0 and cam.global_basis.z.dot(global_position - cam.global_position) > 0.0:
			return
	_pose()


func _pose() -> void:
	var inv := _to_skel.inverse()
	for i in _live:
		var p := _parent[i]
		var pg: Transform3D = Transform3D.IDENTITY if p < 0 else _glob[p]
		var g: Transform3D = pg * (_rest[i] as Transform3D)
		var j = _joint[i]
		if j != null:
			g.basis = (_to_skel * _rot(j as Node3D) * inv) * (_align[i] as Basis)
		_glob[i] = g
		_skel.set_bone_pose_rotation(i, (pg.basis.inverse() * g.basis).get_rotation_quaternion())


## A joint's rotation relative to the figure.
func _rot(j: Node3D) -> Basis:
	var b := j.basis
	var n := j.get_parent()
	while n != _figure and n is Node3D:
		b = (n as Node3D).basis * b
		n = n.get_parent()
	return b.orthonormalized()


func _first_child(i: int) -> int:
	var best := -1
	for c in _parent.size():
		if _parent[c] == i:
			var bn := _skel.get_bone_name(c)
			if best < 0 or bn.begins_with("middle") or bn.begins_with("lowerarm") or bn.begins_with("calf") or bn.begins_with("hand") or bn.begins_with("foot"):
				best = c
	return best


func _sorted(count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var done := {}
	while out.size() < count:
		for i in count:
			if done.has(i):
				continue
			var p := _parent[i]
			if p < 0 or done.has(p):
				out.append(i)
				done[i] = true
	return out


static func _between(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	if axis.length() < 1e-5:
		return Basis()
	return Basis(axis.normalized(), a.angle_to(b))
