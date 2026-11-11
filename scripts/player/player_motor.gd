extends RefCounted
class_name PlayerMotor

## Deterministic character step shared by the server and the predicting client.
## Horizontal displacement is clamped to the sprint speed so a spiked velocity
## cannot outrun the rules.

static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

static func right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))

static func wish_vector(yaw: float, axis_x: float, axis_z: float) -> Vector3:
	var axes := MatchRules.clamp_axes(axis_x, axis_z)
	if axes.length_squared() < 0.0001:
		return Vector3.ZERO
	return (right(yaw) * axes.x + forward(yaw) * axes.y).normalized()

static func step(body: CharacterBody3D, wish: Vector3, jump: bool, crouch: bool, sprint: bool, delta: float) -> void:
	var speed := MatchRules.CROUCH_SPEED if crouch else (MatchRules.RUN_SPEED if sprint else MatchRules.WALK_SPEED)
	var accel := MatchRules.ACCEL if body.is_on_floor() else MatchRules.AIR_ACCEL
	var hv := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var target := wish * speed
	hv = hv.move_toward(target, accel * speed * delta)
	body.velocity.x = hv.x
	body.velocity.z = hv.z
	if not body.is_on_floor():
		body.velocity.y -= MatchRules.GRAVITY * delta
	elif jump:
		body.velocity.y = MatchRules.JUMP_VELOCITY
	elif body.velocity.y < 0.0:
		body.velocity.y = -0.08
	body.velocity.y = clampf(body.velocity.y, -30.0, MatchRules.JUMP_VELOCITY + 0.4)
	body.move_and_slide()

static func clamp_horizontal(body: CharacterBody3D, before: Vector3, delta: float) -> bool:
	var dx := body.global_position.x - before.x
	var dz := body.global_position.z - before.z
	var dist := Vector2(dx, dz).length()
	var max_dist := MatchRules.RUN_SPEED * delta * 1.35 + 0.025
	if dist <= max_dist:
		return false
	var scale := max_dist / dist
	body.global_position.x = before.x + dx * scale
	body.global_position.z = before.z + dz * scale
	body.velocity.x *= scale
	body.velocity.z *= scale
	return true
