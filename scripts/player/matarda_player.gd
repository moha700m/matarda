extends CharacterBody3D
class_name MatardaPlayer

## Third-person body. The server calls tick() with authoritative=true.
## The owning client also ticks for prediction. Remotes are moved by snapshots.

var peer_id := 0
var player_id := ""
var display_name := "Guest"
var team := MatchRules.Team.NONE
var outfit := 0
var health := MatchRules.MAX_HEALTH
var cash := 0
var score := 0
var carrying := false
var downed := false
var arrested := false
var eliminated := false
var crouching := false
var sprinting := false
var yaw := 0.0
var pitch := 0.0
var next_fire := 0.0
var bleed := 0.0
var is_local := false
var net_input := {
	"seq": 0,
	"x": 0.0,
	"z": 0.0,
	"crouch": false,
	"sprint": false,
	"yaw": 0.0,
	"pitch": 0.0,
	"shoot": false,
	"time": 0.0,
}
var edge_jump := false
var edge_interact := false

var _visual: Node3D
var _shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _pivot: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _anim_time := 0.0
var _step_acc := 0.0
var _name_label: Label3D

func setup(data: Dictionary, local: bool) -> void:
	peer_id = int(data.get("peer_id", data.get("id", 0)))
	player_id = str(data.get("player_id", ""))
	display_name = str(data.get("name", "Guest"))
	team = int(data.get("team", MatchRules.Team.POLICE))
	outfit = clampi(int(data.get("outfit", 0)), 0, 3)
	health = int(data.get("health", MatchRules.MAX_HEALTH))
	cash = int(data.get("cash", 0))
	score = int(data.get("score", 0))
	carrying = bool(data.get("carrying", false))
	is_local = local
	add_to_group("matarda_player")
	collision_layer = MatchRules.LAYER_ACTOR
	collision_mask = MatchRules.LAYER_WORLD
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50)
	_shape = CapsuleShape3D.new()
	_shape.radius = MatchRules.BODY_RADIUS
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _shape
	add_child(_shape_node)
	_apply_capsule(false)
	_visual = CharacterMesh.build(outfit, team)
	add_child(_visual)
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.position = Vector3(0, 1.9, 0)
	_name_label.pixel_size = 0.006
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 42
	_name_label.pixel_size = 0.008
	_name_label.modulate = CharacterMesh.team_color(team)
	_name_label.outline_size = 10
	if ThemeKit.font_bold():
		_name_label.font = ThemeKit.font_bold()
	add_child(_name_label)
	if local:
		_build_camera()

func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.35, 0)
	add_child(_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = 3.6
	_arm.margin = 0.2
	_arm.collision_mask = MatchRules.LAYER_WORLD
	_pivot.add_child(_arm)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 68.0
	_camera.near = 0.08
	_camera.far = Settings.camera_far()
	_camera.position = Vector3(0.35, 0.1, 0)
	_arm.add_child(_camera)

func camera() -> Camera3D:
	return _camera

func eye_position() -> Vector3:
	var h := MatchRules.CROUCH_HEIGHT if crouching else MatchRules.STAND_HEIGHT
	return global_position + Vector3(0, h * 0.86, 0)

func aim_direction() -> Vector3:
	var flat := PlayerMotor.forward(yaw)
	var cp := cos(pitch)
	return Vector3(flat.x * cp, sin(pitch), flat.z * cp).normalized()

func tick(delta: float, intent: Dictionary, authoritative: bool) -> void:
	if arrested or eliminated:
		velocity = Vector3.ZERO
		return
	if downed:
		_apply_capsule(true)
		velocity.x = move_toward(velocity.x, 0.0, delta * 16.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 16.0)
		if not is_on_floor():
			velocity.y -= MatchRules.GRAVITY * delta
		move_and_slide()
		_animate(delta)
		return
	if bool(intent.get("absolute", false)):
		yaw = MatchRules.finitef(float(intent.get("yaw", yaw)), yaw)
		pitch = clampf(MatchRules.finitef(float(intent.get("pitch", pitch)), pitch), -1.05, 0.85)
	else:
		var look: Vector2 = intent.get("look", Vector2.ZERO)
		var sens := 0.0032
		yaw -= look.x * sens
		pitch = clampf(pitch - look.y * sens, -1.05, 0.85)
	crouching = bool(intent.get("crouch", false))
	sprinting = bool(intent.get("sprint", false)) and not crouching
	_apply_capsule(crouching)
	var wish := PlayerMotor.wish_vector(yaw, float(intent.get("x", 0.0)), float(intent.get("z", 0.0)))
	var before := global_position
	var do_jump := bool(intent.get("jump", false)) or (authoritative and edge_jump)
	if authoritative:
		edge_jump = false
	PlayerMotor.step(self, wish, do_jump and is_on_floor(), crouching, sprinting, delta)
	if PlayerMotor.clamp_horizontal(self, before, delta) and authoritative:
		Net.note_speed_clamp()
	if is_local and _pivot:
		_pivot.rotation.y = yaw
		_pivot.rotation.x = -pitch
		_pivot.position.y = 0.95 if crouching else 1.35
		if _camera:
			_camera.far = Settings.camera_far()
	_animate(delta)

func _animate(delta: float) -> void:
	_anim_time += delta
	var speed := Vector2(velocity.x, velocity.z).length()
	CharacterMesh.pose(_visual, speed, _anim_time, crouching or downed)
	if carrying and _visual:
		_visual.rotation.z = sin(_anim_time * 2.0) * 0.04
	if is_local and is_on_floor() and not downed and speed > 2.2 and not crouching:
		_step_acc += delta
		if _step_acc > 0.42:
			_step_acc = 0.0
			AudioDirector.play("footstep", randf_range(0.92, 1.08))
	else:
		_step_acc = 0.0

func _apply_capsule(crouch: bool) -> void:
	var h := MatchRules.CROUCH_HEIGHT if crouch else MatchRules.STAND_HEIGHT
	# Godot 4.7 CapsuleShape3D.height includes both hemispheres.
	_shape.height = maxf(h, _shape.radius * 2.0 + 0.02)
	_shape_node.position.y = _shape.height * 0.5

func apply_profile_numbers(data: Dictionary) -> void:
	health = int(data.get("health", health))
	cash = int(data.get("cash", cash))
	score = int(data.get("score", score))
	carrying = bool(data.get("carry", data.get("carrying", carrying)))
	downed = bool(data.get("down", data.get("downed", downed)))
	arrested = bool(data.get("arrested", arrested))
	team = int(data.get("team", team))

func snapshot_dict() -> Dictionary:
	return {
		"id": peer_id,
		"player_id": player_id,
		"name": display_name,
		"pos": global_position,
		"vel": velocity,
		"yaw": yaw,
		"pitch": pitch,
		"crouch": crouching,
		"sprint": sprinting,
		"health": health,
		"team": team,
		"cash": cash,
		"score": score,
		"carry": carrying,
		"down": downed,
		"arrested": arrested,
		"outfit": outfit,
	}
