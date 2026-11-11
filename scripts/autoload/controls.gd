extends Node

## Aggregates keyboard, mouse, and the on-screen touch controls into one intent.

var touch_move := Vector2.ZERO
var touch_active := false
var touch_jump := false
var touch_shoot := false
var touch_interact := false
var touch_sprint := false
var touch_crouch_pulse := false
var touch_look := Vector2.ZERO
var crouch_toggled := false
var mouse_look := Vector2.ZERO
var scripted_active := false
var scripted := {
	"x": 0.0,
	"z": 0.0,
	"jump": false,
	"crouch": false,
	"sprint": false,
	"shoot": false,
	"interact": false,
	"yaw": 0.0,
	"pitch": 0.0,
	"absolute": false,
}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		var dragging := (motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0
		if captured or dragging:
			mouse_look += motion.relative

func poll() -> Dictionary:
	if scripted_active:
		var shot := {
			"x": float(scripted.x),
			"z": float(scripted.z),
			"jump": bool(scripted.jump),
			"crouch": bool(scripted.crouch),
			"sprint": bool(scripted.sprint),
			"shoot": bool(scripted.shoot),
			"interact": bool(scripted.interact),
			"yaw": float(scripted.yaw),
			"pitch": float(scripted.pitch),
			"absolute": bool(scripted.absolute),
			"look": Vector2.ZERO,
		}
		scripted.jump = false
		scripted.interact = false
		return shot
	if Input.is_action_just_pressed("crouch") or touch_crouch_pulse:
		crouch_toggled = not crouch_toggled
	touch_crouch_pulse = false
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_active:
		move = touch_move
	var look := mouse_look + touch_look
	mouse_look = Vector2.ZERO
	touch_look = Vector2.ZERO
	var jump := Input.is_action_just_pressed("jump") or touch_jump
	touch_jump = false
	var interact := Input.is_action_just_pressed("interact") or touch_interact
	touch_interact = false
	var shoot := Input.is_action_pressed("shoot") or touch_shoot
	var sprint := Input.is_action_pressed("sprint") or touch_sprint
	return {
		"x": move.x,
		"z": move.y,
		"jump": jump,
		"crouch": crouch_toggled,
		"sprint": sprint,
		"shoot": shoot,
		"interact": interact,
		"yaw": 0.0,
		"pitch": 0.0,
		"absolute": false,
		"look": look,
	}

func clear_scripted() -> void:
	scripted_active = false
	scripted = {
		"x": 0.0, "z": 0.0, "jump": false, "crouch": false, "sprint": false,
		"shoot": false, "interact": false, "yaw": 0.0, "pitch": 0.0, "absolute": false,
	}
