extends RefCounted
class_name CharacterMesh

## Low-poly person built from primitive meshes. Outfit index picks skin and accessories.
## Team tints the torso. Nothing here is a photographed sprite.

const SKINS := [
	Color(0.80, 0.62, 0.48),
	Color(0.55, 0.38, 0.28),
	Color(0.90, 0.76, 0.62),
	Color(0.42, 0.30, 0.24),
]
const POLICE := Color(0.184, 0.435, 0.929)
const CRIMINAL := Color(0.910, 0.365, 0.016)
const PANTS := Color(0.12, 0.13, 0.16)
const SHOE := Color(0.08, 0.08, 0.09)

static func team_color(team: int) -> Color:
	return POLICE if team == MatchRules.Team.POLICE else CRIMINAL

static func build(outfit: int, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var skin: Color = SKINS[clampi(outfit, 0, 3)]
	var shirt := team_color(team)
	var pants := PANTS
	if outfit == 3:
		pants = Color(0.22, 0.18, 0.16)
		shirt = shirt.darkened(0.08)
	_box(root, "Torso", Vector3(0, 1.12, 0), Vector3(0.46, 0.52, 0.26), shirt)
	_box(root, "Pelvis", Vector3(0, 0.82, 0), Vector3(0.4, 0.22, 0.24), pants)
	_sphere(root, "Head", Vector3(0, 1.58, 0), 0.16, skin)
	_box(root, "ArmL", Vector3(-0.34, 1.12, 0), Vector3(0.12, 0.42, 0.12), shirt)
	_box(root, "ArmR", Vector3(0.34, 1.12, 0), Vector3(0.12, 0.42, 0.12), shirt)
	_box(root, "HandL", Vector3(-0.34, 0.86, 0), Vector3(0.1, 0.1, 0.1), skin)
	_box(root, "HandR", Vector3(0.34, 0.86, 0.04), Vector3(0.1, 0.1, 0.12), skin)
	_box(root, "LegL", Vector3(-0.12, 0.42, 0), Vector3(0.14, 0.48, 0.14), pants)
	_box(root, "LegR", Vector3(0.12, 0.42, 0), Vector3(0.14, 0.48, 0.14), pants)
	_box(root, "ShoeL", Vector3(-0.12, 0.08, 0.04), Vector3(0.15, 0.1, 0.24), SHOE)
	_box(root, "ShoeR", Vector3(0.12, 0.08, 0.04), Vector3(0.15, 0.1, 0.24), SHOE)
	_box(root, "Pistol", Vector3(0.34, 0.88, -0.16), Vector3(0.06, 0.08, 0.22), Color(0.15, 0.15, 0.17))
	if outfit == 1:
		_box(root, "Vest", Vector3(0, 1.14, -0.02), Vector3(0.5, 0.42, 0.3), shirt.darkened(0.25))
	elif outfit == 2:
		_box(root, "Cap", Vector3(0, 1.74, -0.02), Vector3(0.28, 0.08, 0.28), shirt.darkened(0.15))
		_box(root, "Brim", Vector3(0, 1.7, -0.14), Vector3(0.28, 0.04, 0.16), shirt.darkened(0.2))
	elif outfit == 3:
		_box(root, "Jacket", Vector3(0, 1.05, 0), Vector3(0.52, 0.62, 0.32), shirt.darkened(0.18))
	return root

static func pose(visual: Node3D, speed: float, time: float, crouch: bool) -> void:
	if visual == null:
		return
	var swing := sin(time * 9.0) * clampf(speed / MatchRules.RUN_SPEED, 0.0, 1.0)
	var leg_l := visual.get_node_or_null("LegL") as Node3D
	var leg_r := visual.get_node_or_null("LegR") as Node3D
	var arm_l := visual.get_node_or_null("ArmL") as Node3D
	var arm_r := visual.get_node_or_null("ArmR") as Node3D
	if leg_l:
		leg_l.rotation.x = swing * 0.7
	if leg_r:
		leg_r.rotation.x = -swing * 0.7
	if arm_l:
		arm_l.rotation.x = -swing * 0.5
	if arm_r:
		arm_r.rotation.x = swing * 0.35
	visual.position.y = -0.45 if crouch else 0.0
	visual.scale = Vector3(1, 0.78, 1) if crouch else Vector3.ONE

static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat

static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)

static func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
