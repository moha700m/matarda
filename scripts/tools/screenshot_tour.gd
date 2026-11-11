extends Node

const PlayerScript := preload("res://scripts/player/matarda_player.gd")

var report := {"controls": {}, "shots": []}

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Settings.quality = 1
	Settings.apply_quality()
	Settings.show_touch = true
	Net.start_offline()
	var world = Net.world
	world.on_quality_changed()
	for _i in 8:
		await get_tree().process_frame
	var camera := Camera3D.new()
	camera.fov = 62
	camera.far = 180
	world.add_child(camera)
	camera.current = true
	await _place(camera, Vector3(16, 16, 26), Vector3(0, 1, 0), "city_overview")
	await _place(camera, Vector3(-20, 2.4, -2.5), Vector3(-20, 1.6, -10), "police_station")
	await _place(camera, Vector3(20, 2.3, -11.5), Vector3(20, 1.2, -18.5), "bank_vault")
	await _place(camera, Vector3(7, 3.2, 20), Vector3(2, 0.8, 28), "escape_point")
	world.spawn_player({
		"peer_id": 1,
		"player_id": "tour-player-001",
		"name": "Noor",
		"team": MatchRules.Team.CRIMINAL,
		"outfit": 3,
	})
	var me: MatardaPlayer = world.local_player()
	me.global_position = Vector3(13.5, 0.2, 7.5)
	me.yaw = atan2(-(20.0 - 13.5), -(-7.5 - 7.5))
	camera.current = false
	if me.camera():
		me.camera().current = true
	var hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	world.phase = MatchRules.Phase.ACTIVE
	world.time_left = 184
	world.robbery_active = true
	world.hold_left = 11
	world.hold_total = 18
	for _i in 10:
		await get_tree().process_frame
	await _capture("gameplay_hud")
	hud.visible = false
	var menu = load("res://scripts/ui/front_end.gd").new()
	add_child(menu)
	Settings.locale = "en"
	Settings.apply_runtime()
	menu.show_screen("main")
	await _capture("main_menu")
	Settings.locale = "ar"
	Settings.apply_runtime()
	await _capture("main_menu_ar")
	menu.show_screen("settings")
	await _capture("settings")
	menu.show_screen("rooms")
	await _capture("rooms")
	menu.show_screen("character")
	await _capture("character_select")
	menu.show_screen("team")
	await _capture("team_select")
	Settings.locale = "en"
	Settings.apply_runtime()
	menu.visible = false
	hud.visible = true
	await _exercise_controls(me, hud)
	var bench := {}
	for quality in [0, 2]:
		Settings.quality = quality
		Settings.apply_quality()
		world.on_quality_changed()
		bench["q%d" % quality] = await _sample(3.0, me)
	report["benchmark"] = bench
	var path := ProjectSettings.globalize_path("res://docs/test_results/screenshot_tour.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	print("MATARDA_TOUR ", JSON.stringify(report))
	var ok: bool = bool(report["controls"].get("forward_ok", false)) and bool(report["controls"].get("jump_ok", false)) and bool(report["controls"].get("stick_ok", false))
	get_tree().quit(0 if ok else 1)

func _place(camera: Camera3D, from: Vector3, at: Vector3, shot_name: String) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	await _capture(shot_name)

func _capture(shot_name: String) -> void:
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://docs/screenshots/%s.png" % shot_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	report["shots"].append({"name": shot_name, "bytes": FileAccess.get_file_as_bytes(path).size() if err == OK else 0, "error": err})
	print("MATARDA_SHOT_SAVED %s err=%s" % [shot_name, err])

func _exercise_controls(me: MatardaPlayer, hud) -> void:
	me.global_position = Vector3(20, 0.25, 4)
	me.yaw = 0.0
	me.velocity = Vector3.ZERO
	for _i in 6:
		await get_tree().physics_frame
	var z0 := me.global_position.z
	for _i in 30:
		_drive(0.0, 1.0, false, false, false)
		await get_tree().physics_frame
	var forward := z0 - me.global_position.z
	var x0 := me.global_position.x
	for _i in 24:
		_drive(1.0, 0.0, false, false, false)
		await get_tree().physics_frame
	var strafe := me.global_position.x - x0
	for _i in 8:
		_drive(0.0, 0.0, false, false, false)
		await get_tree().physics_frame
	var y0 := me.global_position.y
	_drive(0.0, 0.0, false, true, false)
	var peak := y0
	for _i in 28:
		if _i > 0:
			Controls.scripted.jump = false
		await get_tree().physics_frame
		peak = maxf(peak, me.global_position.y)
	_drive(0.0, 0.0, false, false, true)
	await get_tree().physics_frame
	var crouch_h: float = me._shape.height
	_drive(0.0, 0.0, false, false, false)
	await get_tree().physics_frame
	var stand_h: float = me._shape.height
	var touch = _find_touch(hud)
	var stick_x := 0.0
	if touch:
		var layout: Dictionary = touch._layout()
		touch._move_stick(layout.stick + Vector2(46, 0))
		stick_x = Controls.touch_move.x
	Controls.scripted_active = false
	Controls.mouse_look = Vector2.ZERO
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, -8)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Controls._input(motion)
	var polled: Dictionary = Controls.poll()
	var look_vector: Vector2 = polled.get("look", Vector2.ZERO)
	var look: float = look_vector.x
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	var key_axis: float = Controls.poll().x
	key.pressed = false
	Input.parse_input_event(key)
	report["controls"] = {
		"forward_m": forward,
		"strafe_m": strafe,
		"jump_m": peak - y0,
		"crouch_height": crouch_h,
		"stand_height": stand_h,
		"stick_x": stick_x,
		"mouse_look": look,
		"key_right": key_axis,
		"forward_ok": forward > 0.7,
		"strafe_ok": strafe > 0.4,
		"jump_ok": peak - y0 > 0.45,
		"crouch_ok": crouch_h < stand_h - 0.2,
		"stick_ok": stick_x > 0.4,
		"mouse_ok": look > 10.0,
	}
	Controls.clear_scripted()
	print("MATARDA_CONTROLS ", JSON.stringify(report["controls"]))

func _find_touch(node: Node):
	if node.get_script() and str(node.get_script().resource_path).ends_with("touch_controls.gd"):
		return node
	for child in node.get_children():
		var found = _find_touch(child)
		if found:
			return found
	return null

func _drive(x: float, z: float, sprint: bool, jump: bool, crouch: bool) -> void:
	Controls.scripted_active = true
	Controls.scripted.absolute = true
	Controls.scripted.yaw = 0.0
	Controls.scripted.pitch = 0.0
	Controls.scripted.x = x
	Controls.scripted.z = z
	Controls.scripted.sprint = sprint
	Controls.scripted.jump = jump
	Controls.scripted.crouch = crouch
	Controls.scripted.shoot = false
	Controls.scripted.interact = false

func _sample(seconds: float, me) -> Dictionary:
	var elapsed := 0.0
	var frames := 0
	var bucket_t := 0.0
	var bucket_f := 0
	var min_fps := 9999.0
	var ram := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		var step: float = get_process_delta_time()
		elapsed += step
		frames += 1
		bucket_t += step
		bucket_f += 1
		if bucket_t >= 0.5:
			min_fps = minf(min_fps, bucket_f / bucket_t)
			bucket_t = 0.0
			bucket_f = 0
		ram = maxf(ram, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		if me:
			me.yaw += step * 0.35
	return {"avg_fps": frames / maxf(elapsed, 0.001), "min_fps": min_fps, "ram_static_mb": ram}
