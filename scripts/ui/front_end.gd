extends CanvasLayer

signal host_requested(port)
signal join_requested(ip, port)
signal team_confirmed
signal quit_requested

var screen_name := ""
var _root: Control
var _status: Label
var _preview: Node3D
var _menu_actors: Array = []
var _ip := "127.0.0.1"
var _port := 7777
var _selected_room := 0

func _ready() -> void:
	layer = 30
	Locale.locale_changed.connect(_on_locale)

func _process(delta: float) -> void:
	if _preview:
		_preview.rotate_y(delta * 0.7)
	var tick := Time.get_ticks_msec() / 1000.0
	for actor in _menu_actors:
		if actor is Node3D:
			CharacterMesh.pose(actor, 0.2, tick, false)

func show_screen(name: String) -> void:
	screen_name = name
	_menu_actors.clear()
	_preview = null
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.layout_direction = Locale.layout()
	_root.theme = ThemeKit.make_theme()
	add_child(_root)
	if name == "main":
		_add_menu_scene(_root)
	else:
		ThemeKit.backdrop(_root)
	match name:
		"main":
			_screen_main()
		"settings":
			_screen_settings()
		"rooms":
			_screen_rooms()
		"character":
			_screen_character()
		"team":
			_screen_team()

func _on_locale() -> void:
	if screen_name != "":
		show_screen(screen_name)

func _center_panel(width: float = 520) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.add_theme_stylebox_override("panel", ThemeKit.panel())
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

func _add_menu_scene(parent: Control) -> void:
	var holder := SubViewportContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.48, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.48, 0.5)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	root.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -40, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.3
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(16, 0.2, 10)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.22)
	plane.material = mat
	ground.mesh = plane
	ground.position = Vector3(0, -0.1, 0)
	root.add_child(ground)
	var police := CharacterMesh.build(2, MatchRules.Team.POLICE)
	police.position = Vector3(-3.3, 0, 0.4)
	police.rotation.y = PI * 0.85
	police.scale = Vector3(1.25, 1.25, 1.25)
	root.add_child(police)
	var criminal := CharacterMesh.build(0, MatchRules.Team.CRIMINAL)
	criminal.position = Vector3(3.3, 0, 0.4)
	criminal.rotation.y = -PI * 0.85
	criminal.scale = Vector3(1.25, 1.25, 1.25)
	root.add_child(criminal)
	var left_wall := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(2.2, 2.4, 1.4)
	var left_mat := StandardMaterial3D.new()
	left_mat.albedo_color = Color(0.2, 0.3, 0.55)
	block.material = left_mat
	left_wall.mesh = block
	left_wall.position = Vector3(-4.2, 1.2, -1.6)
	root.add_child(left_wall)
	var right_wall := MeshInstance3D.new()
	var block_r := BoxMesh.new()
	block_r.size = Vector3(2.4, 2.8, 1.6)
	var right_mat := StandardMaterial3D.new()
	right_mat.albedo_color = Color(0.78, 0.62, 0.42)
	block_r.material = right_mat
	right_wall.mesh = block_r
	right_wall.position = Vector3(4.3, 1.4, -1.8)
	root.add_child(right_wall)
	_menu_actors = [police, criminal]
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.35, 5.6), Vector3(0, 1.05, 0))

func _screen_main() -> void:
	var box := _center_panel(480)
	box.add_child(ThemeKit.make_label(Locale.t("title"), 54, true, true))
	box.add_child(ThemeKit.make_label(Locale.t("tagline"), 18, true, false))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = Locale.t("guest_name")
	name_edit.text = Settings.player_name
	name_edit.text_direction = Locale.direction()
	name_edit.add_theme_stylebox_override("normal", ThemeKit.line_style())
	name_edit.custom_minimum_size = Vector2(0, 48)
	name_edit.text_changed.connect(func(value: String) -> void:
		Settings.player_name = value.substr(0, 16)
	)
	box.add_child(name_edit)
	_button(box, "play", true, func() -> void:
		Settings.save_settings()
		show_screen("rooms")
	)
	_button(box, "settings", false, func() -> void: show_screen("settings"))
	_button(box, "language", false, _toggle_language)
	_button(box, "quit", false, func() -> void: quit_requested.emit())
	box.add_child(ThemeKit.make_label(Locale.t("copyright"), 13, true, false))

func _screen_settings() -> void:
	var box := _center_panel(520)
	box.add_child(ThemeKit.make_label(Locale.t("settings"), 32, true, true))
	box.add_child(ThemeKit.make_label(Locale.t("graphics"), 16, false, true))
	var quality := HBoxContainer.new()
	quality.add_theme_constant_override("separation", 8)
	box.add_child(quality)
	for index in 3:
		var key: String = ["low", "medium", "high"][index]
		var button := Button.new()
		button.text = Locale.t(key)
		ThemeKit.style_button(button, Settings.quality == index)
		var captured := index
		button.pressed.connect(func() -> void:
			Settings.quality = captured
			Settings.apply_runtime()
			Settings.save_settings()
			show_screen("settings")
		)
		quality.add_child(button)
	box.add_child(ThemeKit.make_label(Locale.t("sound"), 16, false, true))
	_slider(box, "master", Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v
		Settings.apply_audio()
		Settings.save_settings()
	)
	_slider(box, "sfx", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v
		Settings.save_settings()
		AudioDirector.play("ui_click")
	)
	box.add_child(ThemeKit.make_label(Locale.t("controls"), 16, false, true))
	_slider(box, "control_size", (Settings.control_scale - 0.7) / 0.75, func(v: float) -> void:
		Settings.control_scale = 0.7 + v * 0.75
		Settings.save_settings()
	)
	_slider(box, "opacity", (Settings.control_opacity - 0.35) / 0.65, func(v: float) -> void:
		Settings.control_opacity = 0.35 + v * 0.65
		Settings.save_settings()
	)
	_button(box, "left_handed" if not Settings.left_handed else "right_handed", false, func() -> void:
		Settings.left_handed = not Settings.left_handed
		Settings.save_settings()
		show_screen("settings")
	)
	_button(box, "language", false, _toggle_language)
	_button(box, "back", true, func() -> void: show_screen("main"))

func _screen_rooms() -> void:
	var box := _center_panel(560)
	box.add_child(ThemeKit.make_label(Locale.t("rooms"), 32, true, true))
	box.add_child(ThemeKit.make_label(Locale.t("room_hint"), 14, true, false))
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 180)
	list.allow_reselect = true
	for row in Settings.rooms:
		var label := "%s   %s:%s" % [str(row.get("name", "Room")), str(row.get("ip", "")), str(row.get("port", 7777))]
		list.add_item(label)
	if list.item_count > 0:
		list.select(mini(_selected_room, list.item_count - 1))
	list.item_selected.connect(func(index: int) -> void: _selected_room = index)
	box.add_child(list)
	var ip_row := HBoxContainer.new()
	box.add_child(ip_row)
	var ip_edit := LineEdit.new()
	ip_edit.placeholder_text = Locale.t("ip")
	ip_edit.text = _ip
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.add_theme_stylebox_override("normal", ThemeKit.line_style())
	ip_edit.text_changed.connect(func(v: String) -> void: _ip = v.strip_edges())
	ip_row.add_child(ip_edit)
	var port_edit := LineEdit.new()
	port_edit.placeholder_text = Locale.t("port")
	port_edit.text = str(_port)
	port_edit.custom_minimum_size = Vector2(110, 44)
	port_edit.add_theme_stylebox_override("normal", ThemeKit.line_style())
	port_edit.text_changed.connect(func(v: String) -> void:
		if v.is_valid_int():
			_port = clampi(int(v), 1, 65535)
	)
	ip_row.add_child(port_edit)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var add := Button.new()
	add.text = Locale.t("add")
	ThemeKit.style_button(add, false)
	add.pressed.connect(func() -> void:
		if _ip != "":
			Settings.upsert_room(_ip, _port, _ip)
			show_screen("rooms")
	)
	actions.add_child(add)
	var refresh := Button.new()
	refresh.text = Locale.t("refresh")
	ThemeKit.style_button(refresh, false)
	refresh.pressed.connect(_refresh_selected)
	actions.add_child(refresh)
	_status = ThemeKit.make_label("", 14, true, false)
	box.add_child(_status)
	_button(box, "join", true, _join_selected)
	_button(box, "host", false, func() -> void:
		host_requested.emit(_port)
	)
	_button(box, "back", false, func() -> void: show_screen("main"))

func _screen_character() -> void:
	var box := _center_panel(480)
	box.add_child(ThemeKit.make_label(Locale.t("character"), 32, true, true))
	box.add_child(ThemeKit.make_label(Locale.outfit_name(Settings.outfit), 16, true, false))
	_preview = _character_view(box, Settings.outfit, MatchRules.Team.CRIMINAL)
	var row := HBoxContainer.new()
	box.add_child(row)
	for index in 4:
		var button := Button.new()
		button.text = Locale.outfit_name(index)
		ThemeKit.style_button(button, Settings.outfit == index)
		var captured := index
		button.pressed.connect(func() -> void:
			Settings.outfit = captured
			Settings.save_settings()
			show_screen("character")
		)
		row.add_child(button)
	_button(box, "next", true, func() -> void: show_screen("team"))
	_button(box, "back", false, func() -> void: show_screen("rooms"))

func _screen_team() -> void:
	var box := _center_panel(560)
	box.add_child(ThemeKit.make_label(Locale.t("team"), 32, true, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var police := VBoxContainer.new()
	police.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(police)
	police.add_child(ThemeKit.make_label(Locale.t("police"), 20, true, true))
	_character_view(police, Settings.outfit, MatchRules.Team.POLICE)
	police.add_child(ThemeKit.make_label(Locale.t("police_blurb"), 13, true, false))
	var choose_police := Button.new()
	choose_police.text = Locale.t("police")
	ThemeKit.style_button(choose_police, true)
	choose_police.pressed.connect(func() -> void: _confirm_team(MatchRules.Team.POLICE))
	police.add_child(choose_police)
	var criminals := VBoxContainer.new()
	criminals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(criminals)
	criminals.add_child(ThemeKit.make_label(Locale.t("criminals"), 20, true, true))
	_character_view(criminals, Settings.outfit, MatchRules.Team.CRIMINAL)
	criminals.add_child(ThemeKit.make_label(Locale.t("criminal_blurb"), 13, true, false))
	var choose_criminal := Button.new()
	choose_criminal.text = Locale.t("criminals")
	ThemeKit.style_button(choose_criminal, true)
	choose_criminal.pressed.connect(func() -> void: _confirm_team(MatchRules.Team.CRIMINAL))
	criminals.add_child(choose_criminal)
	_button(box, "back", false, func() -> void: show_screen("character"))

func set_status(text: String) -> void:
	if _status:
		_status.text = text

func _confirm_team(team: int) -> void:
	Settings.save_settings()
	Net.submit_team(team)
	team_confirmed.emit()

func _join_selected() -> void:
	if Settings.rooms.is_empty():
		join_requested.emit(_ip, _port)
		return
	var index := clampi(_selected_room, 0, Settings.rooms.size() - 1)
	var row = Settings.rooms[index]
	join_requested.emit(str(row.get("ip", _ip)), int(row.get("port", _port)))

func _refresh_selected() -> void:
	if Settings.rooms.is_empty():
		return
	var row = Settings.rooms[clampi(_selected_room, 0, Settings.rooms.size() - 1)]
	set_status(Locale.t("connecting"))
	var err := Net.probe(str(row.get("ip", "127.0.0.1")), int(row.get("port", 7777)))
	if err != OK:
		set_status(Locale.t("connect_fail"))

func _toggle_language() -> void:
	Settings.locale = "en" if Settings.locale == "ar" else "ar"
	Settings.apply_runtime()
	Settings.save_settings()

func _button(parent: Node, key: String, filled: bool, handler: Callable) -> void:
	var button := Button.new()
	button.text = Locale.t(key)
	ThemeKit.style_button(button, filled)
	button.pressed.connect(handler)
	parent.add_child(button)

func _slider(parent: Node, key: String, value: float, handler: Callable) -> void:
	parent.add_child(ThemeKit.make_label(Locale.t(key), 14, false, false))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(handler)
	parent.add_child(slider)

func _add_hero(parent: Node) -> void:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(0, 140)
	holder.stretch = true
	parent.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 280)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.2, 3.2), Vector3(0, 0.6, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -40, 0)
	light.light_color = Color(1.0, 0.8, 0.55)
	root.add_child(light)
	_preview = Node3D.new()
	root.add_child(_preview)
	_box(_preview, Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.35), ThemeKit.ORANGE)
	_box(_preview, Vector3(-0.7, 0.35, 0.2), Vector3(0.45, 0.7, 0.3), ThemeKit.POLICE)
	_box(_preview, Vector3(0.75, 0.8, -0.15), Vector3(0.4, 1.3, 0.4), Color(0.2, 0.24, 0.34))

func _character_view(parent: Node, outfit: int, team: int) -> Node3D:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(0, 220)
	holder.stretch = true
	parent.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 480)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.55, 0.48)
	env.ambient_light_energy = 0.55
	world_env.environment = env
	root.add_child(world_env)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.85, 1.25, -2.15), Vector3(0, 1.15, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -50, 0)
	light.light_color = Color(1.0, 0.78, 0.55)
	root.add_child(light)
	var visual := CharacterMesh.build(outfit, team)
	root.add_child(visual)
	return visual

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh.material = mat
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
