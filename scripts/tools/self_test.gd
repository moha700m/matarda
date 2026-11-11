extends Node

const PlayerScript := preload("res://scripts/player/matarda_player.gd")

var failed := 0

func _ready() -> void:
	# Let the autoload finish entering the tree before the first simulation step.
	await get_tree().process_frame
	await _run()

func _run() -> void:
	check("audio_bank", AudioDirector.stream_count() >= 8)
	check("locale_ar", Locale.t("play") != "play" or Settings.locale == "en")
	Settings.locale = "ar"
	check("locale_play_ar", Locale.t("play") == "العب")
	check("locale_rtl", Locale.is_rtl())
	Settings.locale = "en"
	var axes := MatchRules.clamp_axes(NAN, 4.0)
	check("nan_axis", not is_nan(axes.x) and axes.length() <= 1.0 + 0.001)
	Net.test_mode = true
	Net.start_offline()
	var world = Net.world
	for _i in 5:
		await get_tree().physics_frame
	check("city_vault", world.landmarks["vault"].distance_to(MatchRules.VAULT) < 0.01)
	check("city_escape", world.landmarks["escape"].distance_to(MatchRules.ESCAPE) < 0.01)
	world.spawn_player({
		"peer_id": 1,
		"player_id": "selftest-player",
		"name": "Solo",
		"team": MatchRules.Team.CRIMINAL,
		"outfit": 2,
	})
	var me: MatardaPlayer = world.local_player()
	check("spawned", me != null)
	me.global_position = Vector3(20, 0.3, 0)
	me.yaw = 0.0
	me.velocity = Vector3.ZERO
	for _i in 8:
		await get_tree().physics_frame
	check("feet_on_floor", me.global_position.y > -0.08 and me.global_position.y < 0.2)
	print("MATARDA_MEASURE rest_y=", me.global_position.y)
	var origin_z: float = me.global_position.z
	for _i in 36:
		_drive(0.0, 1.0, false, false, false)
		await get_tree().physics_frame
	var walked: float = origin_z - me.global_position.z
	check("walk_forward", walked > 1.0)
	print("MATARDA_MEASURE walk_m=", walked)
	var run_z: float = me.global_position.z
	for _i in 36:
		_drive(0.0, 1.0, true, false, false)
		await get_tree().physics_frame
	var ran: float = run_z - me.global_position.z
	check("sprint_faster", ran > walked * 1.25)
	print("MATARDA_MEASURE sprint_m=", ran)
	me.velocity = Vector3.ZERO
	for _i in 10:
		_drive(0.0, 0.0, false, false, false)
		await get_tree().physics_frame
	var y0: float = me.global_position.y
	_drive(0.0, 0.0, false, true, false)
	var peak: float = y0
	for _i in 30:
		if _i > 0:
			Controls.scripted.jump = false
		await get_tree().physics_frame
		peak = maxf(peak, me.global_position.y)
	check("jump", peak - y0 > 0.55)
	print("MATARDA_MEASURE jump_m=", peak - y0)
	_drive(0.0, 0.0, false, false, true)
	await get_tree().physics_frame
	var crouch_h: float = me._shape.height
	_drive(0.0, 0.0, false, false, false)
	await get_tree().physics_frame
	var stand_h: float = me._shape.height
	check("crouch_shorter", crouch_h < stand_h - 0.2)
	var before: Vector3 = me.global_position
	me.velocity = Vector3(50, 0, 0)
	PlayerMotor.step(me, Vector3.ZERO, false, false, false, 1.0 / 60.0)
	var clamped := PlayerMotor.clamp_horizontal(me, before, 1.0 / 60.0)
	check("speed_clamp", clamped)
	me.global_position = Vector3(4, 0.3, 0)
	me.velocity = Vector3.ZERO
	var cop: MatardaPlayer = PlayerScript.new()
	cop.setup({
		"peer_id": 2,
		"player_id": "selftest-police",
		"name": "Cop",
		"team": MatchRules.Team.POLICE,
		"outfit": 1,
	}, false)
	world.add_child(cop)
	world.players[2] = cop
	cop.global_position = Vector3(-2, 0.3, 0)
	cop.pitch = 0.0
	for _i in 8:
		await get_tree().physics_frame
	cop.yaw = -PI / 2.0
	cop.pitch = 0.0
	var hp: int = me.health
	world._try_fire(cop)
	world._try_fire(cop)
	check("fire_rate", me.health == hp - MatchRules.FIRE_DAMAGE)
	cop.next_fire = 0.0
	world._try_fire(cop)
	check("fire_second_shot", me.health == hp - MatchRules.FIRE_DAMAGE * 2)
	me.health = MatchRules.MAX_HEALTH
	me.global_position = Vector3(0, 0.3, 12)
	for _i in 3:
		await get_tree().physics_frame
	world._try_interact(me)
	check("interact_too_far", world.robbery_active == false)
	me.global_position = MatchRules.VAULT_STAND + Vector3(0, 0.2, 0)
	me.velocity = Vector3.ZERO
	for _i in 4:
		await get_tree().physics_frame
	world.phase = MatchRules.Phase.ACTIVE
	world._try_interact(me)
	check("robbery_starts", world.robbery_active)
	# Clear the roadway and prove the bank door can be walked through.
	me.global_position = Vector3(20, 0.3, 0)
	me.velocity = Vector3.ZERO
	for _i in 5:
		await get_tree().physics_frame
	for _i in 180:
		_drive(0.0, 1.0, true, false, false)
		await get_tree().physics_frame
	print("MATARDA_MEASURE door_z=", me.global_position.z, " door_x=", me.global_position.x)
	check("entered_bank", me.global_position.z < -9.0 and absf(me.global_position.x - 20.0) < 2.0)
	Controls.clear_scripted()
	print("MATARDA_SELFTEST %s" % ("PASS" if failed == 0 else "FAIL"))
	get_tree().quit(0 if failed == 0 else 1)

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

func check(name: String, ok: bool) -> void:
	print("MATARDA_TEST %s %s" % [name, "PASS" if ok else "FAIL"])
	if not ok:
		failed += 1
