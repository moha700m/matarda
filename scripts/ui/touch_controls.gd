extends Control

## On-screen joystick (bottom corner) and round action buttons (opposite corner).
## Camera look is a drag on the rest of the screen, except the top HUD strip.

var _stick_index := -1
var _cam_index := -1
var _held := {}
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.changed.connect(queue_redraw)

func _process(_delta: float) -> void:
	visible = Settings.show_touch
	if visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventScreenDrag:
		_drag(event)

func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _passthrough(event.position):
			return
		var button_name := _button_at(event.position)
		if button_name != "":
			_held[event.index] = button_name
			_set_button(button_name, true)
			return
		var layout := _layout()
		if _stick_index < 0 and event.position.distance_to(layout.stick) <= layout.radius * 1.4:
			_stick_index = event.index
			_move_stick(event.position)
			return
		if _cam_index < 0:
			_cam_index = event.index
	else:
		if _held.has(event.index):
			_set_button(str(_held[event.index]), false)
			_held.erase(event.index)
		if event.index == _stick_index:
			_stick_index = -1
			_knob = Vector2.ZERO
			Controls.touch_active = false
			Controls.touch_move = Vector2.ZERO
		if event.index == _cam_index:
			_cam_index = -1

func _drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_index:
		_move_stick(event.position)
	elif event.index == _cam_index:
		Controls.touch_look += event.relative

func _move_stick(pos: Vector2) -> void:
	var layout := _layout()
	var stick: Vector2 = layout.stick
	var delta: Vector2 = pos - stick
	var limit: float = layout.knob
	if delta.length() > limit:
		delta = delta.normalized() * limit
	_knob = delta
	var axes: Vector2 = delta / limit
	if axes.length() < 0.12:
		axes = Vector2.ZERO
	Controls.touch_active = true
	# Screen Y grows downward. Forward is up the screen, which is negative Y.
	Controls.touch_move = Vector2(axes.x, -axes.y)

func _set_button(button_name: String, down: bool) -> void:
	match button_name:
		"shoot":
			Controls.touch_shoot = down
		"sprint":
			Controls.touch_sprint = down
		"jump":
			if down:
				Controls.touch_jump = true
		"interact":
			if down:
				Controls.touch_interact = true
		"crouch":
			if down:
				Controls.touch_crouch_pulse = true

func _passthrough(pos: Vector2) -> bool:
	return pos.y < 76.0

func _layout() -> Dictionary:
	var size := get_size()
	if size.x < 10.0:
		size = get_viewport_rect().size
	var scale := Settings.control_scale
	var stick := Vector2(118.0 * scale, size.y - 128.0 * scale)
	var shoot := Vector2(size.x - 86.0 * scale, size.y - 92.0 * scale)
	if Settings.left_handed:
		stick.x = size.x - stick.x
		shoot.x = size.x - shoot.x
	var mirror := -1.0 if Settings.left_handed else 1.0
	return {
		"stick": stick,
		"radius": 92.0 * scale,
		"knob": 54.0 * scale,
		"shoot": shoot,
		"jump": shoot + Vector2(-118.0 * mirror, -18.0) * scale,
		"crouch": shoot + Vector2(-10.0 * mirror, -118.0) * scale,
		"sprint": shoot + Vector2(-118.0 * mirror, -118.0) * scale,
		"interact": shoot + Vector2(8.0 * mirror, -210.0) * scale,
		"scale": scale,
	}

func _buttons() -> Dictionary:
	var layout := _layout()
	var scale: float = layout.scale
	return {
		"shoot": {"at": layout.shoot, "r": 42.0 * scale, "label": Locale.t("shoot")},
		"jump": {"at": layout.jump, "r": 34.0 * scale, "label": Locale.t("jump")},
		"crouch": {"at": layout.crouch, "r": 34.0 * scale, "label": Locale.t("crouch")},
		"sprint": {"at": layout.sprint, "r": 34.0 * scale, "label": Locale.t("sprint")},
		"interact": {"at": layout.interact, "r": 32.0 * scale, "label": Locale.t("interact")},
	}

func _button_at(pos: Vector2) -> String:
	var found := ""
	var best := 99999.0
	for name in _buttons().keys():
		var spec: Dictionary = _buttons()[name]
		var dist := pos.distance_to(spec.at)
		if dist <= float(spec.r) and dist < best:
			best = dist
			found = name
	return found

func _draw() -> void:
	var alpha := Settings.control_opacity
	var layout := _layout()
	var base := Color(0.05, 0.07, 0.12, 0.55 * alpha)
	var ring := Color(1.0, 0.48, 0.1, 0.95 * alpha)
	draw_circle(layout.stick, layout.radius, base)
	draw_arc(layout.stick, layout.radius, 0, TAU, 48, ring, 3.0, true)
	draw_circle(layout.stick + _knob, layout.knob * 0.55, Color(1.0, 0.62, 0.28, 0.95 * alpha))
	for name in _buttons().keys():
		var spec: Dictionary = _buttons()[name]
		var held := false
		for value in _held.values():
			if str(value) == str(name):
				held = true
		var fill := Color(1.0, 0.48, 0.1, 0.9 * alpha) if held or name == "shoot" else Color(0.08, 0.11, 0.18, 0.72 * alpha)
		if name == "shoot" and not held:
			fill = Color(0.85, 0.32, 0.08, 0.88 * alpha)
		draw_circle(spec.at, spec.r, fill)
		draw_arc(spec.at, spec.r, 0, TAU, 40, ring, 2.5, true)
		_draw_icon(str(name), spec.at, float(spec.r) * 0.42, Color(0.98, 0.96, 0.93, alpha))

func _draw_icon(kind: String, at: Vector2, s: float, color: Color) -> void:
	match kind:
		"shoot":
			draw_arc(at, s * 0.85, 0, TAU, 20, color, 2.2, true)
			draw_circle(at, s * 0.22, color)
		"jump":
			draw_polyline(PackedVector2Array([at + Vector2(-s, s * 0.35), at + Vector2(0, -s * 0.7), at + Vector2(s, s * 0.35)]), color, 3.0, true)
		"crouch":
			draw_polyline(PackedVector2Array([at + Vector2(-s, -s * 0.25), at + Vector2(0, s * 0.65), at + Vector2(s, -s * 0.25)]), color, 3.0, true)
		"sprint":
			draw_polyline(PackedVector2Array([at + Vector2(-s * 0.2, s * 0.55), at + Vector2(s * 0.55, 0), at + Vector2(-s * 0.2, -s * 0.55)]), color, 3.0, true)
			draw_polyline(PackedVector2Array([at + Vector2(-s * 0.85, s * 0.55), at + Vector2(-s * 0.1, 0), at + Vector2(-s * 0.85, -s * 0.55)]), color, 3.0, true)
		"interact":
			draw_arc(at + Vector2(0, s * 0.15), s * 0.55, PI, TAU, 12, color, 2.4, true)
			draw_line(at + Vector2(0, s * 0.15), at + Vector2(0, -s * 0.7), color, 2.4)
			draw_line(at + Vector2(-s * 0.45, -s * 0.15), at + Vector2(s * 0.45, -s * 0.15), color, 2.4)
