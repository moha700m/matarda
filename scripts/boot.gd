extends Node

var _ui: CanvasLayer
var _hud: CanvasLayer
var _args := {}

func _ready() -> void:
	_args = _parse_args()
	_apply_cli()
	if _args.has("selftest"):
		_add_tool("res://scripts/tools/self_test.gd")
		return
	if _args.has("server"):
		Net.test_mode = _args.has("test-mode")
		Net.result_path = str(_args.get("result", ""))
		var err := Net.start_dedicated(int(_args.get("port", 7777)))
		if err != OK:
			get_tree().quit(1)
		return
	if _args.has("screenshot-tour"):
		_add_tool("res://scripts/tools/screenshot_tour.gd")
		return
	if _args.has("benchmark"):
		_add_tool("res://scripts/tools/benchmark.gd")
		return
	if _args.has("autoplay"):
		_start_autoplay()
		return
	_open_menu()

func _add_tool(path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("Failed to compile %s" % path)
		get_tree().quit(1)
		return
	add_child(script.new())

func _parse_args() -> Dictionary:
	var out := {}
	var user := OS.get_cmdline_user_args()
	var index := 0
	while index < user.size():
		var token := str(user[index])
		if token.begins_with("--"):
			var key := token.trim_prefix("--")
			if index + 1 < user.size() and not str(user[index + 1]).begins_with("--"):
				out[key] = user[index + 1]
				index += 2
			else:
				out[key] = true
				index += 1
		else:
			index += 1
	return out

func _apply_cli() -> void:
	if _args.has("player-id"):
		Settings.player_id = str(_args["player-id"])
	if _args.has("name"):
		Settings.player_name = str(_args["name"])
	if _args.has("outfit"):
		Settings.outfit = clampi(int(_args["outfit"]), 0, 3)
	if _args.has("quality"):
		var label := str(_args["quality"])
		Settings.quality = 0 if label == "low" else (2 if label == "high" else 1)
		Settings.apply_quality()
	if _args.has("locale"):
		Settings.locale = str(_args["locale"])
		Settings.apply_runtime()

func _open_menu() -> void:
	_ui = load("res://scripts/ui/front_end.gd").new()
	add_child(_ui)
	_ui.host_requested.connect(_on_host)
	_ui.join_requested.connect(_on_join)
	_ui.team_confirmed.connect(_on_team_confirmed)
	_ui.quit_requested.connect(func() -> void: get_tree().quit())
	Net.welcome_received.connect(_on_welcome)
	Net.connection_failed_reason.connect(func(_reason: String) -> void:
		if _ui and _ui.has_method("set_status"):
			_ui.set_status(Locale.t("connect_fail"))
	)
	Net.room_received.connect(func(info: Dictionary) -> void:
		if _ui and _ui.has_method("set_status"):
			_ui.set_status("%s  %s/%s  %s" % [str(info.get("name", "")), str(info.get("players", 0)), str(info.get("max", 8)), str(info.get("phase", ""))])
	)
	_ui.show_screen("main")

func _on_host(port: int) -> void:
	var err := Net.start_listen(port)
	if err != OK:
		_ui.set_status(Locale.t("connect_fail"))
		return
	_ui.set_status(Locale.t("hosted"))
	_ui.show_screen("character")

func _on_join(ip: String, port: int) -> void:
	_ui.set_status(Locale.t("connecting"))
	Settings.upsert_room(ip, port)
	var err := Net.join(ip, port)
	if err != OK:
		_ui.set_status(Locale.t("connect_fail"))

func _on_welcome(payload: Dictionary) -> void:
	if _ui == null:
		return
	if bool(payload.get("restored", false)):
		_ui.set_status(Locale.t("restored"))
		_enter_match()
		return
	if _ui.screen_name == "rooms" or _ui.screen_name == "main":
		_ui.show_screen("character")

func _on_team_confirmed() -> void:
	_enter_match()

func _enter_match() -> void:
	if _hud == null:
		_hud = load("res://scripts/ui/hud.gd").new()
		add_child(_hud)
	if _ui:
		_ui.visible = false
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _start_autoplay() -> void:
	var bot = load("res://scripts/tools/autoplay.gd").new()
	bot.role = str(_args.get("role", "criminal"))
	bot.result_path = str(_args.get("result", ""))
	bot.exit_after = str(_args.get("exit-after", "win"))
	bot.expect_restore = _args.has("expect-restore")
	add_child(bot)
	Net.welcome_received.connect(bot.on_welcome)
	Net.rejected.connect(func(_reason: String) -> void: bot.fail("rejected"))
	Net.connection_failed_reason.connect(func(_reason: String) -> void: bot.fail("connect"))
	var err := Net.join(str(_args.get("ip", "127.0.0.1")), int(_args.get("port", 7777)))
	if err != OK:
		bot.fail("create_client")
