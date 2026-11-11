extends CanvasLayer

var _timer: Label
var _objective: Label
var _health: Label
var _cash: Label
var _prompt: Label
var _banner: Label
var _minimap: Control
var _touch: Control
var paused := false
var pause_panel: Control

func _ready() -> void:
	layer = 20
	_build()
	Locale.locale_changed.connect(_refresh_static)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Locale.layout()
	add_child(root)
	_minimap = preload("res://scripts/ui/minimap.gd").new()
	if Locale.is_rtl():
		_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_minimap.offset_left = -184
		_minimap.offset_right = -16
	else:
		_minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_minimap.offset_left = 16
		_minimap.offset_right = 184
	_minimap.offset_top = 16
	_minimap.offset_bottom = 184
	root.add_child(_minimap)
	_timer = ThemeKit.make_label("04:00", 28, true, true)
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_left = -180
	_timer.offset_right = 180
	_timer.offset_top = 12
	_timer.offset_bottom = 48
	root.add_child(_timer)
	_objective = ThemeKit.make_label("", 16, true, false)
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.offset_left = -280
	_objective.offset_right = 280
	_objective.offset_top = 48
	_objective.offset_bottom = 78
	root.add_child(_objective)
	var heart := HudIcon.new()
	heart.kind = "heart"
	heart.custom_minimum_size = Vector2(22, 22)
	heart.size = Vector2(22, 22)
	_health = ThemeKit.make_label("", 18, false, true)
	_health.add_child(heart)
	_health.set_anchors_preset(Control.PRESET_TOP_RIGHT if Locale.is_rtl() else Control.PRESET_TOP_LEFT)
	_place_counter(_health, 196)
	root.add_child(_health)
	var coin := HudIcon.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(22, 22)
	coin.size = Vector2(22, 22)
	_cash = ThemeKit.make_label("", 18, false, true)
	_cash.add_child(coin)
	_cash.set_anchors_preset(Control.PRESET_TOP_RIGHT if Locale.is_rtl() else Control.PRESET_TOP_LEFT)
	_place_counter(_cash, 228)
	root.add_child(_cash)
	_prompt = ThemeKit.make_label("", 18, true, true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_top = 80
	_prompt.offset_bottom = 120
	_prompt.offset_left = -260
	_prompt.offset_right = 260
	root.add_child(_prompt)
	_banner = ThemeKit.make_label("", 36, true, true)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -320
	_banner.offset_right = 320
	_banner.offset_top = -40
	_banner.offset_bottom = 40
	_banner.visible = false
	root.add_child(_banner)
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.85)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_right = 2
	cross.offset_top = -2
	cross.offset_bottom = 2
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	var pause := Button.new()
	pause.text = Locale.t("pause")
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT if not Locale.is_rtl() else Control.PRESET_TOP_LEFT)
	if Locale.is_rtl():
		pause.offset_left = 16
		pause.offset_right = 140
	else:
		pause.offset_left = -140
		pause.offset_right = -16
	pause.offset_top = 14
	pause.offset_bottom = 58
	ThemeKit.style_button(pause, false)
	pause.pressed.connect(_toggle_pause)
	root.add_child(pause)
	_touch = preload("res://scripts/ui/touch_controls.gd").new()
	root.add_child(_touch)

func _place_counter(label: Label, top: float) -> void:
	if Locale.is_rtl():
		label.offset_left = -280
		label.offset_right = -16
	else:
		label.offset_left = 196
		label.offset_right = 460
	label.offset_top = top
	label.offset_bottom = top + 28

func _process(_delta: float) -> void:
	var world = Net.world
	if world == null:
		return
	var me = world.local_player()
	var seconds := maxi(0, int(ceil(world.time_left)))
	_timer.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_objective.text = Locale.t(world.objective_key(me))
	if me:
		_health.text = "    %d" % me.health
		_cash.text = "    %d    %s %d" % [me.cash, Locale.t("score"), me.score]
		var prompt: String = world.prompt_key(me)
		_prompt.text = Locale.t(prompt) if prompt != "" else ""
	else:
		_health.text = ""
		_cash.text = ""
		_prompt.text = ""
	if world.phase == MatchRules.Phase.CRIMINAL_WIN or world.phase == MatchRules.Phase.POLICE_WIN:
		_banner.visible = true
		_banner.text = Locale.t("criminal_win" if world.phase == MatchRules.Phase.CRIMINAL_WIN else "police_win")
	else:
		_banner.visible = false
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		if Input.is_key_pressed(KEY_ESCAPE) and not _esc_held:
			_esc_held = true
			_toggle_pause()
	elif not Input.is_key_pressed(KEY_ESCAPE):
		_esc_held = false

var _esc_held := false

func _toggle_pause() -> void:
	paused = not paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_open_pause()
	else:
		_close_pause()
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -220
	pause_panel.offset_right = 220
	pause_panel.offset_top = -160
	pause_panel.offset_bottom = 160
	pause_panel.add_theme_stylebox_override("panel", ThemeKit.panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pause_panel.add_child(box)
	box.add_child(ThemeKit.make_label(Locale.t("pause"), 26, true, true))
	var resume := Button.new()
	resume.text = Locale.t("resume")
	ThemeKit.style_button(resume, true)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var leave := Button.new()
	leave.text = Locale.t("disconnect")
	ThemeKit.style_button(leave, false)
	leave.pressed.connect(func() -> void:
		Net.leave()
		get_tree().reload_current_scene()
	)
	box.add_child(leave)
	add_child(pause_panel)

func _close_pause() -> void:
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null

class HudIcon extends Control:
	var kind := "heart"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2(0, 2)

	func _draw() -> void:
		var c := ThemeKit.ORANGE if kind == "coin" else Color("FF5A5A")
		if kind == "heart":
			draw_circle(Vector2(7, 8), 5, c)
			draw_circle(Vector2(14, 8), 5, c)
			draw_colored_polygon(PackedVector2Array([Vector2(3, 10), Vector2(18, 10), Vector2(10.5, 20)]), c)
		else:
			draw_circle(Vector2(11, 11), 8, c)
			draw_circle(Vector2(11, 11), 4, Color(0.55, 0.32, 0.08))

func _refresh_static() -> void:
	for child in get_children():
		child.queue_free()
	_build()
