extends RefCounted
class_name CityBuilder

## Procedural low-poly sunset district. Meshes are boxes, cylinders, and spheres
## created in code. Windows and lamps are detail instances with a visibility range.

static var _materials := {}

static func build(parent: Node3D, quality: int) -> Dictionary:
	_materials.clear()
	var range_end := Settings.detail_range()
	_ground(parent)
	_roads(parent)
	_bank(parent, range_end)
	_station(parent, range_end)
	_escape(parent)
	_blocks(parent, quality, range_end)
	_dressing(parent, range_end)
	return {
		"vault": MatchRules.VAULT,
		"vault_stand": MatchRules.VAULT_STAND,
		"escape": MatchRules.ESCAPE,
		"police_spawn": MatchRules.POLICE_SPAWN,
		"criminal_spawn": MatchRules.CRIMINAL_SPAWN,
		"bank_door": MatchRules.BANK_DOOR,
	}

static func _mat(color: Color, rough: float = 0.88, emission: Color = Color(0, 0, 0), energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, rough, emission]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = 0.04
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	_materials[key] = mat
	return mat

static func _mesh(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision: bool, shadow: bool, detail: bool, range_end: float, rough: float = 0.88) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color, rough)
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if detail:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = 3.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mi.add_to_group("detail_prop")
	parent.add_child(mi)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = MatchRules.LAYER_WORLD
		body.collision_mask = 0
		body.position = pos
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)
	return mi

static func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, collision: bool, detail: bool, range_end: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _mat(color, 0.9)
	mi.mesh = mesh
	mi.position = pos
	if detail:
		mi.visibility_range_end = range_end
		mi.add_to_group("detail_prop")
	parent.add_child(mi)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = MatchRules.LAYER_WORLD
		body.collision_mask = 0
		body.position = pos
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = radius
		cyl.height = height
		shape.shape = cyl
		body.add_child(shape)
		parent.add_child(body)

static func _label(parent: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_modulate = Color(0.04, 0.05, 0.08)
	label.outline_size = 16
	label.no_depth_test = false
	if ThemeKit.font_bold():
		label.font = ThemeKit.font_bold()
	parent.add_child(label)

static func _ground(parent: Node3D) -> void:
	_mesh(parent, Vector3(0, -0.2, 0), Vector3(96, 0.4, 96), Color(0.45, 0.38, 0.30), true, false, false, 0, 0.95)
	# sidewalks sit slightly above the ground but below the road center so they don't snag
	_mesh(parent, Vector3(0, 0.015, 8.2), Vector3(78, 0.03, 2.2), Color(0.62, 0.58, 0.52), false, false, false, 0)
	_mesh(parent, Vector3(0, 0.015, -8.2), Vector3(78, 0.03, 2.2), Color(0.62, 0.58, 0.52), false, false, false, 0)
	_mesh(parent, Vector3(8.2, 0.015, 0), Vector3(2.2, 0.03, 78), Color(0.62, 0.58, 0.52), false, false, false, 0)
	_mesh(parent, Vector3(-8.2, 0.015, 0), Vector3(2.2, 0.03, 78), Color(0.62, 0.58, 0.52), false, false, false, 0)

static func _roads(parent: Node3D) -> void:
	var asphalt := Color(0.16, 0.16, 0.18)
	_mesh(parent, Vector3(0, 0.03, 0), Vector3(84, 0.04, 12), asphalt, false, false, false, 0, 0.95)
	_mesh(parent, Vector3(0, 0.035, 0), Vector3(12, 0.04, 84), asphalt, false, false, false, 0, 0.95)
	var paint := Color(0.82, 0.78, 0.66)
	for i in range(-6, 7):
		if abs(i) < 1:
			continue
		_mesh(parent, Vector3(i * 6.0, 0.06, 0), Vector3(1.6, 0.012, 0.16), paint, false, false, true, 55)
		_mesh(parent, Vector3(0, 0.065, i * 6.0), Vector3(0.16, 0.012, 1.6), paint, false, false, true, 55)

static func _bank(parent: Node3D, range_end: float) -> void:
	var stone := Color(0.78, 0.70, 0.58)
	var trim := Color(0.55, 0.42, 0.30)
	var wall_h := 5.2
	var y := wall_h * 0.5
	# south wall with a door gap centered on x=20
	_mesh(parent, Vector3(15.15, y, -8), Vector3(6.3, wall_h, 0.45), stone, true, true, false, 0)
	_mesh(parent, Vector3(24.85, y, -8), Vector3(6.3, wall_h, 0.45), stone, true, true, false, 0)
	_mesh(parent, Vector3(20, wall_h - 0.35, -8), Vector3(3.6, 0.7, 0.45), stone, true, true, false, 0)
	# north, west, east
	_mesh(parent, Vector3(20, y, -20), Vector3(16.4, wall_h, 0.45), stone, true, true, false, 0)
	_mesh(parent, Vector3(12, y, -14), Vector3(0.45, wall_h, 12.4), stone, true, true, false, 0)
	_mesh(parent, Vector3(28, y, -14), Vector3(0.45, wall_h, 12.4), stone, true, true, false, 0)
	# back roof over the vault only
	_mesh(parent, Vector3(20, 5.25, -18.2), Vector3(15.2, 0.28, 3.4), trim, true, true, false, 0)
	# columns outside the door, off the center line
	_cyl(parent, Vector3(17.5, 1.6, -7.35), 0.28, 3.2, Color(0.86, 0.8, 0.68), true, false, range_end)
	_cyl(parent, Vector3(22.5, 1.6, -7.35), 0.28, 3.2, Color(0.86, 0.8, 0.68), true, false, range_end)
	_mesh(parent, Vector3(20, 3.35, -7.35), Vector3(6.2, 0.35, 0.7), trim, false, true, false, 0)
	# windows on the outer walls
	for i in range(-2, 3):
		_window(parent, Vector3(20 + i * 2.4, 2.4, -20.28), range_end)
		_window(parent, Vector3(11.72, 2.4, -14 + i * 2.0), range_end)
	_vault_room(parent)
	_label(parent, Vector3(20, 4.35, -6.9), "BANK", Color(0.98, 0.94, 0.86))
	_label(parent, Vector3(20, 3.7, -6.9), "المصرف", Color(1.0, 0.72, 0.32))

static func _station(parent: Node3D, range_end: float) -> void:
	var wall := Color(0.22, 0.32, 0.48)
	var stripe := Color(0.95, 0.48, 0.16)
	var wall_h := 5.0
	var y := wall_h * 0.5
	# door faces south, centered x=-20, same gap pattern as the bank
	_mesh(parent, Vector3(-24.85, y, -8), Vector3(6.3, wall_h, 0.45), wall, true, true, false, 0)
	_mesh(parent, Vector3(-15.15, y, -8), Vector3(6.3, wall_h, 0.45), wall, true, true, false, 0)
	_mesh(parent, Vector3(-20, wall_h - 0.35, -8), Vector3(3.6, 0.7, 0.45), wall, true, true, false, 0)
	_mesh(parent, Vector3(-20, y, -20), Vector3(16.4, wall_h, 0.45), wall, true, true, false, 0)
	_mesh(parent, Vector3(-28, y, -14), Vector3(0.45, wall_h, 12.4), wall, true, true, false, 0)
	_mesh(parent, Vector3(-12, y, -14), Vector3(0.45, wall_h, 12.4), wall, true, true, false, 0)
	_mesh(parent, Vector3(-20, 3.15, -7.55), Vector3(4.4, 0.22, 0.28), stripe, false, false, false, 0)
	_mesh(parent, Vector3(-20, 0.55, -11), Vector3(2.4, 0.9, 0.8), Color(0.3, 0.36, 0.48), true, true, false, 0)
	_cyl(parent, Vector3(-26.4, 2.2, -6.6), 0.07, 4.4, Color(0.75, 0.76, 0.8), true, false, range_end)
	_mesh(parent, Vector3(-26.4, 4.5, -6.6), Vector3(1.05, 0.62, 0.06), stripe, false, false, true, range_end)
	for i in range(-2, 3):
		_window(parent, Vector3(-20 + i * 2.3, 3.3, -20.28), range_end)
	_label(parent, Vector3(-20, 4.55, -6.85), "POLICE", Color(0.9, 0.94, 1.0))
	_label(parent, Vector3(-20, 3.85, -6.85), "الشرطة", Color(0.55, 0.75, 1.0))

static func _escape(parent: Node3D) -> void:
	_mesh(parent, Vector3(0, 0.04, 28), Vector3(4.6, 0.06, 4.6), Color(0.95, 0.48, 0.12), false, false, false, 0, 0.6)
	_mesh(parent, Vector3(0, 0.08, 28), Vector3(2.2, 0.04, 0.28), Color(0.98, 0.95, 0.9), false, false, false, 0)
	# van parked off the roadway so the escape point stays walkable
	var van := Color(0.2, 0.22, 0.26)
	_mesh(parent, Vector3(8.6, 0.7, 28), Vector3(2.4, 1.1, 4.4), van, true, true, false, 0)
	_mesh(parent, Vector3(8.6, 1.45, 27.2), Vector3(2.2, 0.7, 1.8), Color(0.55, 0.72, 0.82), false, true, false, 0, 0.2)
	_cyl(parent, Vector3(7.7, 0.28, 26.4), 0.32, 0.3, Color(0.1, 0.1, 0.1), false, false, 0)
	_cyl(parent, Vector3(9.5, 0.28, 29.6), 0.32, 0.3, Color(0.1, 0.1, 0.1), false, false, 0)
	_label(parent, Vector3(0, 2.2, 28), "ESCAPE", Color(1.0, 0.72, 0.35))

static func _window(parent: Node3D, pos: Vector3, range_end: float) -> void:
	_mesh(parent, pos, Vector3(0.7, 0.9, 0.08), Color(0.18, 0.16, 0.14), false, false, true, range_end)
	var glow := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.62, 0.04)
	mesh.material = _mat(Color(1, 0.78, 0.45), 0.4, Color(1.0, 0.7, 0.35), 0.7)
	glow.mesh = mesh
	glow.position = pos + Vector3(0, 0, -0.02 if pos.z < -10 else 0.02)
	glow.visibility_range_end = range_end
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.add_to_group("detail_prop")
	parent.add_child(glow)

static func _blocks(parent: Node3D, quality: int, range_end: float) -> void:
	var walls := [
		Color(0.76, 0.58, 0.42),
		Color(0.70, 0.5, 0.4),
		Color(0.82, 0.66, 0.48),
		Color(0.62, 0.48, 0.4),
		Color(0.58, 0.42, 0.38),
	]
	var roofs := [
		Color(0.55, 0.26, 0.2),
		Color(0.42, 0.24, 0.22),
		Color(0.62, 0.32, 0.22),
	]
	var specs := [
		Vector4(-20, 16, 8, 7), Vector4(-34, 16, 7, 11), Vector4(18, 16, 8, 8),
		Vector4(32, 16, 7, 6), Vector4(-20, 30, 8, 9), Vector4(18, 32, 7, 7),
		Vector4(32, 30, 8, 12), Vector4(-34, 30, 7, 8), Vector4(-34, -30, 8, 11),
		Vector4(-18, -32, 7, 6), Vector4(18, -32, 8, 9), Vector4(32, -30, 8, 13),
		Vector4(34, 0, 6, 8), Vector4(-36, 0, 6, 7), Vector4(34, -14, 6, 9),
		Vector4(-36, -14, 6, 6),
	]
	var index := 0
	for spec in specs:
		var w: float = spec.z
		var d := 7.5
		var h: float = spec.w
		if not _footprint_free(spec.x, spec.y, w, d):
			continue
		var wall: Color = walls[index % walls.size()]
		var roof: Color = roofs[index % roofs.size()]
		var shadow := quality > 0
		_mesh(parent, Vector3(spec.x, h * 0.5, spec.y), Vector3(w, h, d), wall, true, shadow, false, 0)
		_mesh(parent, Vector3(spec.x, h + 0.16, spec.y), Vector3(w + 0.55, 0.28, d + 0.55), roof, false, shadow, false, 0)
		_mesh(parent, Vector3(spec.x, h - 0.08, spec.y), Vector3(w + 0.15, 0.12, d + 0.15), wall.darkened(0.18), false, false, false, 0)
		var front_z: float = spec.y + d * 0.5 + 0.04
		_mesh(parent, Vector3(spec.x, 1.15, front_z), Vector3(1.15, 2.1, 0.08), Color(0.2, 0.16, 0.14), false, false, true, range_end)
		_mesh(parent, Vector3(spec.x, 2.35, front_z + 0.08), Vector3(1.8, 0.08, 0.35), roof, false, false, true, range_end)
		var cols := maxi(2, int(w / 2.4))
		for col in cols:
			var wx: float = spec.x - w * 0.32 + float(col) * (w * 0.64 / float(maxi(1, cols - 1)))
			_window(parent, Vector3(wx, h * 0.62, front_z), range_end)
		index += 1

static func _dressing(parent: Node3D, range_end: float) -> void:
	for i in range(-5, 6):
		if abs(i) < 1:
			continue
		var lamp_x := float(i * 7.0)
		_lamp(parent, Vector3(lamp_x, 0, 7.4), range_end)
		# Keep the bank and station doorways clear.
		if absf(lamp_x - 20.0) < 5.0 or absf(lamp_x + 20.0) < 5.0:
			continue
		_lamp(parent, Vector3(lamp_x, 0, -7.4), range_end)
		if abs(i) > 1:
			_tree(parent, Vector3(i * 7.0, 0, 11.2), range_end)
	# parked cars clear of x=0, x=20 and x=-12 lanes
	_car(parent, Vector3(-22, 0, 4.8), Color(0.72, 0.24, 0.18))
	_car(parent, Vector3(30, 0, -4.6), Color(0.22, 0.32, 0.48))
	_car(parent, Vector3(10, 0, 16), Color(0.86, 0.7, 0.28))
	_bench(parent, Vector3(14, 0, 9.4), range_end)
	_bench(parent, Vector3(-16, 0, 9.4), range_end)
	_bench(parent, Vector3(26, 0, -5.6), range_end)
	_traffic(parent, Vector3(7.4, 0, 7.4), range_end)
	_traffic(parent, Vector3(-7.4, 0, 7.4), range_end)
	_traffic(parent, Vector3(7.4, 0, -6.2), range_end)
	_traffic(parent, Vector3(-7.4, 0, 6.6), range_end)

static func _lamp(parent: Node3D, pos: Vector3, range_end: float) -> void:
	_cyl(parent, pos + Vector3(0, 1.6, 0), 0.08, 3.2, Color(0.25, 0.25, 0.28), false, true, range_end)
	var bulb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _mat(Color(1, 0.85, 0.55), 0.3, Color(1, 0.8, 0.45), 1.1)
	bulb.mesh = mesh
	bulb.position = pos + Vector3(0, 3.25, 0)
	bulb.visibility_range_end = range_end
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.add_to_group("detail_prop")
	parent.add_child(bulb)

static func _tree(parent: Node3D, pos: Vector3, range_end: float) -> void:
	_cyl(parent, pos + Vector3(0, 0.7, 0), 0.16, 1.4, Color(0.32, 0.22, 0.16), true, true, range_end)
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.85
	mesh.height = 1.5
	mesh.radial_segments = 8
	mesh.rings = 5
	mesh.material = _mat(Color(0.22, 0.4, 0.26), 0.95)
	crown.mesh = mesh
	crown.position = pos + Vector3(0, 1.9, 0)
	crown.visibility_range_end = range_end
	crown.add_to_group("detail_prop")
	parent.add_child(crown)

static func _car(parent: Node3D, pos: Vector3, color: Color) -> void:
	_mesh(parent, pos + Vector3(0, 0.42, 0), Vector3(1.7, 0.48, 3.5), color, true, true, false, 0)
	_mesh(parent, pos + Vector3(0, 0.88, -0.15), Vector3(1.45, 0.42, 1.55), color.lightened(0.12), false, true, false, 0)
	_mesh(parent, pos + Vector3(0, 0.42, -1.72), Vector3(0.5, 0.16, 0.08), Color(0.95, 0.92, 0.7), false, false, false, 0)
	_wheel(parent, pos + Vector3(-0.72, 0.22, 1.15))
	_wheel(parent, pos + Vector3(0.72, 0.22, 1.15))
	_wheel(parent, pos + Vector3(-0.72, 0.22, -1.15))
	_wheel(parent, pos + Vector3(0.72, 0.22, -1.15))

static func _wheel(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.16
	mesh.radial_segments = 10
	mesh.material = _mat(Color(0.08, 0.08, 0.09), 0.7)
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(mi)

static func _bench(parent: Node3D, pos: Vector3, range_end: float) -> void:
	var wood := Color(0.45, 0.3, 0.18)
	_mesh(parent, pos + Vector3(0, 0.42, 0), Vector3(1.4, 0.08, 0.42), wood, false, false, true, range_end)
	_mesh(parent, pos + Vector3(0, 0.72, 0.16), Vector3(1.4, 0.4, 0.08), wood, false, false, true, range_end)
	_mesh(parent, pos + Vector3(-0.6, 0.28, 0), Vector3(0.08, 0.4, 0.4), Color(0.15, 0.15, 0.16), false, false, true, range_end)
	_mesh(parent, pos + Vector3(0.6, 0.28, 0), Vector3(0.08, 0.4, 0.4), Color(0.15, 0.15, 0.16), false, false, true, range_end)

static func _traffic(parent: Node3D, pos: Vector3, range_end: float) -> void:
	_cyl(parent, pos + Vector3(0, 1.7, 0), 0.07, 3.4, Color(0.18, 0.18, 0.2), false, true, range_end)
	_mesh(parent, pos + Vector3(0, 3.35, 0), Vector3(0.28, 0.72, 0.28), Color(0.1, 0.1, 0.12), false, false, true, range_end)
	_emissive_sphere(parent, pos + Vector3(0, 3.55, -0.12), 0.07, Color(0.9, 0.15, 0.12), range_end)
	_emissive_sphere(parent, pos + Vector3(0, 3.35, -0.12), 0.07, Color(0.9, 0.75, 0.15), range_end)
	_emissive_sphere(parent, pos + Vector3(0, 3.15, -0.12), 0.07, Color(0.2, 0.75, 0.28), range_end)

static func _emissive_sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, range_end: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _mat(color, 0.35, color, 1.4)
	mi.mesh = mesh
	mi.position = pos
	mi.visibility_range_end = range_end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("detail_prop")
	parent.add_child(mi)

static func _vault_room(parent: Node3D) -> void:
	_mesh(parent, Vector3(20, 0.045, -14.5), Vector3(14.5, 0.04, 9.5), Color(0.42, 0.36, 0.32), false, false, false, 0)
	var door := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.05
	disc.bottom_radius = 1.05
	disc.height = 0.22
	disc.radial_segments = 20
	disc.material = _mat(Color(0.62, 0.5, 0.22), 0.32)
	door.mesh = disc
	door.position = Vector3(20, 1.25, -19.55)
	door.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(door)
	var wheel := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.28
	ring.bottom_radius = 0.28
	ring.height = 0.08
	ring.radial_segments = 12
	ring.material = _mat(Color(0.85, 0.7, 0.28), 0.28)
	wheel.mesh = ring
	wheel.position = Vector3(20, 1.25, -19.38)
	wheel.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(wheel)
	for bar in 6:
		var bolt := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.06
		cyl.radial_segments = 8
		cyl.material = _mat(Color(0.35, 0.28, 0.14), 0.4)
		bolt.mesh = cyl
		var ang := bar / 6.0 * TAU
		bolt.position = Vector3(20 + cos(ang) * 0.72, 1.25 + sin(ang) * 0.72, -19.4)
		bolt.rotation_degrees = Vector3(90, 0, 0)
		parent.add_child(bolt)
	_mesh(parent, Vector3(16.4, 0.28, -17.2), Vector3(0.9, 0.28, 0.55), Color(0.95, 0.78, 0.22), true, true, false, 0, 0.25)
	_mesh(parent, Vector3(16.4, 0.52, -17.2), Vector3(0.7, 0.16, 0.4), Color(0.98, 0.84, 0.3), false, false, false, 0, 0.22)
	_mesh(parent, Vector3(23.6, 0.18, -16.6), Vector3(0.7, 0.22, 0.45), Color(0.18, 0.55, 0.32), false, false, false, 0)
	_mesh(parent, Vector3(23.6, 0.38, -16.6), Vector3(0.62, 0.16, 0.38), Color(0.22, 0.62, 0.36), false, false, false, 0)
	_mesh(parent, Vector3(14.4, 0.55, -13.2), Vector3(1.3, 1.0, 2.4), Color(0.5, 0.4, 0.32), true, true, false, 0)

static func _footprint_free(cx: float, cz: float, w: float, d: float) -> bool:
	var min_x := cx - w * 0.5
	var max_x := cx + w * 0.5
	var min_z := cz - d * 0.5
	var max_z := cz + d * 0.5
	if _overlap(min_x, max_x, min_z, max_z, -7.2, 7.2, -46, 46):
		return false
	if _overlap(min_x, max_x, min_z, max_z, -46, 46, -7.2, 7.2):
		return false
	if _overlap(min_x, max_x, min_z, max_z, 11.2, 28.8, -20.8, -7.2):
		return false
	if _overlap(min_x, max_x, min_z, max_z, -28.8, -11.2, -20.8, -7.2):
		return false
	if _overlap(min_x, max_x, min_z, max_z, -3.5, 11.5, 24.5, 31.5):
		return false
	return true

static func _overlap(ax0: float, ax1: float, az0: float, az1: float, bx0: float, bx1: float, bz0: float, bz1: float) -> bool:
	return ax0 < bx1 and ax1 > bx0 and az0 < bz1 and az1 > bz0
