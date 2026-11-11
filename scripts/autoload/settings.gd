extends Node

signal changed

const SAVE_PATH := "user://settings.cfg"

var player_name := "Guest"
var player_id := ""
var outfit := 0
var quality := 1
var master_volume := 0.85
var sfx_volume := 0.9
var control_scale := 1.0
var control_opacity := 0.88
var left_handed := false
var locale := "en"
var show_touch := true
var rooms: Array = [{"name": "Local", "ip": "127.0.0.1", "port": 7777}]

func _ready() -> void:
	_register_actions()
	load_settings()
	if player_id == "":
		player_id = make_id()
		save_settings()
	apply_runtime()

func make_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chars := "abcdef0123456789"
	var out := ""
	for i in 16:
		out += chars[rng.randi_range(0, chars.length() - 1)]
	return "p_" + out

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name))
	player_id = str(cfg.get_value("player", "id", player_id))
	outfit = clampi(int(cfg.get_value("player", "outfit", outfit)), 0, 3)
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 2)
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	control_scale = clampf(float(cfg.get_value("controls", "scale", control_scale)), 0.7, 1.45)
	control_opacity = clampf(float(cfg.get_value("controls", "opacity", control_opacity)), 0.35, 1.0)
	left_handed = bool(cfg.get_value("controls", "left_handed", left_handed))
	locale = str(cfg.get_value("ui", "locale", locale))
	show_touch = bool(cfg.get_value("controls", "show_touch", show_touch))
	var saved_rooms = cfg.get_value("net", "rooms", rooms)
	if saved_rooms is Array and saved_rooms.size() > 0:
		rooms = saved_rooms

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name.substr(0, 16))
	cfg.set_value("player", "id", player_id)
	cfg.set_value("player", "outfit", outfit)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("controls", "scale", control_scale)
	cfg.set_value("controls", "opacity", control_opacity)
	cfg.set_value("controls", "left_handed", left_handed)
	cfg.set_value("controls", "show_touch", show_touch)
	cfg.set_value("ui", "locale", locale)
	cfg.set_value("net", "rooms", rooms)
	cfg.save(SAVE_PATH)

func apply_runtime() -> void:
	apply_audio()
	apply_quality()
	if locale != "ar" and locale != "en":
		locale = "en"
	TranslationServer.set_locale(locale)
	changed.emit()

func apply_audio() -> void:
	var master := maxf(master_volume, 0.0001)
	AudioServer.set_bus_volume_db(0, linear_to_db(master))

func apply_quality() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var vp := tree.root.get_viewport()
	if vp == null:
		return
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.7
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 0.85
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	tree.call_group("quality_listener", "on_quality_changed")

func camera_far() -> float:
	match quality:
		0:
			return 70.0
		1:
			return 120.0
		_:
			return 180.0

func detail_range() -> float:
	match quality:
		0:
			return 26.0
		1:
			return 48.0
		_:
			return 90.0

func upsert_room(ip: String, port: int, room_name: String = "") -> void:
	for i in rooms.size():
		var row = rooms[i]
		if str(row.get("ip", "")) == ip and int(row.get("port", 0)) == port:
			if room_name != "":
				row["name"] = room_name
				rooms[i] = row
			save_settings()
			changed.emit()
			return
	rooms.append({"name": room_name if room_name != "" else ip, "ip": ip, "port": port})
	save_settings()
	changed.emit()

func _register_actions() -> void:
	if InputMap.has_action("move_forward"):
		return
	_bind_key("move_forward", [KEY_W, KEY_UP])
	_bind_key("move_back", [KEY_S, KEY_DOWN])
	_bind_key("move_left", [KEY_A, KEY_LEFT])
	_bind_key("move_right", [KEY_D, KEY_RIGHT])
	_bind_key("jump", [KEY_SPACE])
	_bind_key("crouch", [KEY_C, KEY_CTRL])
	_bind_key("sprint", [KEY_SHIFT])
	_bind_key("interact", [KEY_F, KEY_E])
	_bind_key("shoot", [])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mouse)

func _bind_key(action: String, keys: Array) -> void:
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
