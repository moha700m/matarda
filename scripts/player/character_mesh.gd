extends RefCounted
class_name CharacterMesh

## Stylized low-poly people. Joint pivots drive idle, walk, run, and crouch.
## Police wear a cap and vest. Criminals wear a hoodie and a mask.

const SKINS := [
	Color(0.80, 0.62, 0.48),
	Color(0.55, 0.38, 0.28),
	Color(0.90, 0.76, 0.62),
	Color(0.42, 0.30, 0.24),
]
const HAIR := [
	Color(0.18, 0.12, 0.08),
	Color(0.10, 0.10, 0.12),
	Color(0.45, 0.28, 0.14),
	Color(0.05, 0.05, 0.06),
]
const POLICE := Color(0.16, 0.28, 0.62)
const POLICE_DARK := Color(0.10, 0.16, 0.32)
const CRIMINAL := Color(0.22, 0.16, 0.18)
const HOOD := Color(0.62, 0.18, 0.10)
const PANTS := Color(0.14, 0.15, 0.18)
const SHOE := Color(0.08, 0.08, 0.09)

static func team_color(team: int) -> Color:
	return POLICE if team == MatchRules.Team.POLICE else HOOD

static func build(outfit: int, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var skin: Color = SKINS[clampi(outfit, 0, 3)]
	var hair: Color = HAIR[clampi(outfit, 0, 3)]
	var police := team == MatchRules.Team.POLICE
	var shirt := POLICE if police else HOOD
	var pants := Color(0.12, 0.16, 0.28) if police else PANTS
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 1.05, 0)
	root.add_child(torso)
	_box(torso, "Chest", Vector3(0, 0.12, 0), Vector3(0.42, 0.38, 0.24), shirt)
	_box(torso, "Hip", Vector3(0, -0.16, 0), Vector3(0.36, 0.18, 0.22), pants)
	if police:
		_box(torso, "Vest", Vector3(0, 0.12, -0.02), Vector3(0.46, 0.34, 0.28), POLICE_DARK)
		_box(torso, "Badge", Vector3(-0.12, 0.18, -0.16), Vector3(0.07, 0.08, 0.02), Color(0.95, 0.78, 0.28))
		_box(torso, "Belt", Vector3(0, -0.08, 0), Vector3(0.44, 0.06, 0.26), Color(0.08, 0.08, 0.09))
	else:
		_box(torso, "Hoodie", Vector3(0, 0.08, 0), Vector3(0.48, 0.46, 0.30), shirt.darkened(0.12))
		_box(torso, "Pocket", Vector3(0.12, -0.02, -0.16), Vector3(0.12, 0.08, 0.02), shirt.darkened(0.22))
	_limb(root, "ShoulderL", Vector3(-0.26, 1.28, 0), Vector3(0, -0.18, 0), Vector3(0.11, 0.34, 0.11), shirt)
	_limb(root, "ShoulderR", Vector3(0.26, 1.28, 0), Vector3(0, -0.18, 0), Vector3(0.11, 0.34, 0.11), shirt)
	var hand_l := _limb(root, "ElbowL", Vector3(-0.26, 0.92, 0), Vector3(0, -0.1, 0), Vector3(0.09, 0.16, 0.09), skin)
	var hand_r := _limb(root, "ElbowR", Vector3(0.26, 0.92, 0), Vector3(0, -0.1, -0.02), Vector3(0.09, 0.16, 0.1), skin)
	hand_l.name = "HandL"
	hand_r.name = "HandR"
	_box(hand_r, "Pistol", Vector3(0.02, -0.02, -0.12), Vector3(0.05, 0.07, 0.18), Color(0.12, 0.12, 0.14))
	_limb(root, "HipL", Vector3(-0.1, 0.78, 0), Vector3(0, -0.2, 0), Vector3(0.13, 0.36, 0.13), pants)
	_limb(root, "HipR", Vector3(0.1, 0.78, 0), Vector3(0, -0.2, 0), Vector3(0.13, 0.36, 0.13), pants)
	var knee_l := _limb(root, "KneeL", Vector3(-0.1, 0.4, 0), Vector3(0, -0.16, 0.02), Vector3(0.12, 0.28, 0.12), pants)
	var knee_r := _limb(root, "KneeR", Vector3(0.1, 0.4, 0), Vector3(0, -0.16, 0.02), Vector3(0.12, 0.28, 0.12), pants)
	_box(knee_l, "Shoe", Vector3(0, -0.32, 0.05), Vector3(0.13, 0.08, 0.22), SHOE)
	_box(knee_r, "Shoe", Vector3(0, -0.32, 0.05), Vector3(0.13, 0.08, 0.22), SHOE)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.58, 0)
	root.add_child(head)
	_sphere(head, "Skull", Vector3(0, 0.06, 0), 0.15, skin, Vector3(1.0, 1.08, 0.96))
	_box(head, "Hair", Vector3(0, 0.16, 0.01), Vector3(0.28, 0.1, 0.26), hair)
	_box(head, "Brow", Vector3(0, 0.1, -0.1), Vector3(0.2, 0.035, 0.06), hair)
	_sphere(head, "EyeL", Vector3(-0.05, 0.05, -0.12), 0.022, Color(0.08, 0.08, 0.1), Vector3.ONE)
	_sphere(head, "EyeR", Vector3(0.05, 0.05, -0.12), 0.022, Color(0.08, 0.08, 0.1), Vector3.ONE)
	_box(head, "Nose", Vector3(0, 0.01, -0.14), Vector3(0.03, 0.04, 0.03), skin.darkened(0.08))
	if police:
		_box(head, "Cap", Vector3(0, 0.2, -0.01), Vector3(0.3, 0.08, 0.3), POLICE_DARK)
		_box(head, "Brim", Vector3(0, 0.15, -0.14), Vector3(0.3, 0.025, 0.14), POLICE_DARK)
		_box(head, "CapBadge", Vector3(0, 0.16, -0.16), Vector3(0.05, 0.04, 0.015), Color(0.95, 0.78, 0.28))
	else:
		_sphere(head, "Hood", Vector3(0, 0.08, 0.1), 0.17, shirt.darkened(0.18), Vector3(1.12, 1.02, 0.95))
		_box(head, "Mask", Vector3(0, 0.05, -0.13), Vector3(0.2, 0.06, 0.03), Color(0.05, 0.05, 0.06))
	return root

static func pose(visual: Node3D, speed: float, time: float, crouch: bool) -> void:
	if visual == null:
		return
	var moving := speed > 0.35
	var running := speed > MatchRules.WALK_SPEED * 1.15
	var freq := 11.5 if running else 7.2
	var amp := 0.85 if running else 0.55
	var swing := sin(time * freq) * amp if moving else sin(time * 1.6) * 0.06
	_set_rot(visual, "HipL", swing * 0.9 + (0.55 if crouch else 0.0))
	_set_rot(visual, "HipR", -swing * 0.9 + (0.55 if crouch else 0.0))
	_set_rot(visual, "KneeL", maxf(0.0, -swing) * 0.8 + (0.7 if crouch else 0.15))
	_set_rot(visual, "KneeR", maxf(0.0, swing) * 0.8 + (0.7 if crouch else 0.15))
	_set_rot(visual, "ShoulderL", -swing * 0.65)
	_set_rot(visual, "ShoulderR", swing * 0.65)
	var torso := visual.get_node_or_null("Torso") as Node3D
	if torso:
		torso.rotation.x = (0.12 if running else 0.0) + (0.28 if crouch else 0.0)
		torso.position.y = 0.92 if crouch else 1.05 + sin(time * 1.6) * 0.012
	var head := visual.get_node_or_null("Head") as Node3D
	if head:
		head.position.y = 1.32 if crouch else 1.58
		head.rotation.y = sin(time * 1.4) * 0.04
	visual.position.y = -0.28 if crouch else 0.0

static func _set_rot(visual: Node3D, node_name: String, angle: float) -> void:
	var node := visual.get_node_or_null(node_name) as Node3D
	if node:
		node.rotation.x = angle

static func _limb(parent: Node3D, node_name: String, joint: Vector3, mesh_pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = joint
	parent.add_child(pivot)
	_box(pivot, "Mesh", mesh_pos, size, color)
	return pivot

static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.metallic = 0.02
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat

static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
