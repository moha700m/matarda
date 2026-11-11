extends Node

var role := "criminal"
var result_path := ""
var exit_after := "win"
var expect_restore := false
var welcome := {}
var started := false
var failed := false
var elapsed := 0.0
var state := "boot"
var state_time := 0.0
var interact_cd := 0.0
var seen_health := 100
var escape_step := 0
var police_seen_at := -1.0
var carry_latched := false

func on_welcome(payload: Dictionary) -> void:
	welcome = payload
	if expect_restore:
		var ok := bool(payload.get("restored", false)) and int(payload.get("team", -1)) == MatchRules.Team.CRIMINAL and int(payload.get("score", 0)) >= 100
		if not ok:
			fail("restore_mismatch")
			return
		if exit_after == "restore":
			finish(true)
			return
		started = true
		state = "escape"
		state_time = 0.0
		return
	Net.submit_team(MatchRules.Team.POLICE if role == "police" else MatchRules.Team.CRIMINAL)
	started = true

func fail(reason: String) -> void:
	if failed:
		return
	failed = true
	print("MATARDA_CLIENT_FAIL %s" % reason)
	_write({"ok": false, "reason": reason})
	get_tree().quit(1)

func finish(ok: bool) -> void:
	if failed:
		return
	failed = true
	print("MATARDA_CLIENT_DONE ok=%s role=%s" % [ok, role])
	_write({"ok": ok})
	get_tree().quit(0 if ok else 1)

func _physics_process(delta: float) -> void:
	if failed:
		return
	elapsed += delta
	if not started:
		if elapsed > 20.0:
			fail("no_welcome")
		return
	var world = Net.world
	var me: MatardaPlayer = null
	if world:
		me = world.local_player()
	if me == null:
		if elapsed > 20.0:
			fail("no_spawn")
		return
	state_time += delta
	interact_cd = maxf(0.0, interact_cd - delta)
	_watch_health(world, me)
	if elapsed > 80.0:
		fail("timeout")
		return
	if role == "police":
		_police(me, world)
	else:
		_criminal(me, world)

func _watch_health(world, me) -> void:
	for player in world.players.values():
		if player.peer_id != me.peer_id and player.team != me.team:
			seen_health = mini(seen_health, int(player.health))

func _script(yaw: float, throttle: float, shoot: bool, interact: bool) -> void:
	Controls.scripted_active = true
	Controls.scripted.absolute = true
	Controls.scripted.yaw = yaw
	Controls.scripted.pitch = 0.0
	Controls.scripted.x = 0.0
	Controls.scripted.z = throttle
	Controls.scripted.sprint = throttle > 0.5
	Controls.scripted.crouch = false
	Controls.scripted.jump = false
	Controls.scripted.shoot = shoot
	Controls.scripted.interact = interact

func _goto(me, target: Vector3) -> bool:
	var flat := Vector3(target.x - me.global_position.x, 0, target.z - me.global_position.z)
	if flat.length() < 0.9:
		_script(me.yaw, 0.0, false, false)
		return true
	var yaw := atan2(-flat.x, -flat.z)
	_script(yaw, 1.0, false, false)
	return false

func _pulse_interact(me) -> void:
	var send := interact_cd <= 0.0
	if send:
		interact_cd = 0.75
	_script(me.yaw, 0.0, false, send)

func _police(me: MatardaPlayer, world) -> void:
	var target: MatardaPlayer = null
	for player in world.players.values():
		if player.team == MatchRules.Team.CRIMINAL and not player.arrested:
			target = player as MatardaPlayer
			break
	if target == null:
		_script(me.yaw, 0.0, false, false)
		return
	var to: Vector3 = target.eye_position() - me.eye_position()
	var yaw := atan2(-to.x, -to.z)
	var horiz := Vector2(to.x, to.z).length()
	var pitch := atan2(to.y, maxf(0.01, horiz))
	Controls.scripted_active = true
	Controls.scripted.absolute = true
	Controls.scripted.yaw = yaw
	Controls.scripted.pitch = pitch
	Controls.scripted.x = 0.0
	Controls.scripted.z = 0.0
	Controls.scripted.sprint = false
	Controls.scripted.crouch = false
	Controls.scripted.jump = false
	Controls.scripted.interact = false
	if state == "boot":
		state = "aim"
		state_time = 0.0
	var firing := state == "fire"
	Controls.scripted.shoot = firing
	if state == "aim" and state_time > 0.75:
		state = "fire"
		state_time = 0.0
	elif state == "fire" and state_time > 0.42:
		state = "done"
		state_time = 0.0
		Controls.scripted.shoot = false
	elif state == "done" and state_time > 0.4:
		finish(seen_health < MatchRules.MAX_HEALTH)

func _criminal(me: MatardaPlayer, world) -> void:
	if world.phase == MatchRules.Phase.CRIMINAL_WIN:
		finish(true)
		return
	match state:
		"boot":
			_script(0.0, 0.0, false, false)
			var police_here := false
			for player in world.players.values():
				if player.team == MatchRules.Team.POLICE:
					police_here = true
			if police_here and police_seen_at < 0.0:
				police_seen_at = state_time
			if (police_seen_at >= 0.0 and state_time - police_seen_at > 2.6) or state_time > 8.0:
				state = "door"
				state_time = 0.0
		"door":
			if _goto(me, MatchRules.BANK_DOOR):
				state = "vault"
				state_time = 0.0
		"vault":
			if _goto(me, MatchRules.VAULT_STAND):
				state = "start_rob"
				state_time = 0.0
				interact_cd = 0.0
		"start_rob":
			_pulse_interact(me)
			if world.robbery_active:
				state = "hold"
				state_time = 0.0
			elif state_time > 8.0:
				fail("robbery_did_not_start")
		"hold":
			_script(me.yaw, 0.0, false, false)
			if world.loot_ready:
				state = "take"
				state_time = 0.0
				interact_cd = 0.0
			elif state_time > 20.0:
				fail("loot_not_ready")
		"take":
			if me.carrying or world.carrier_player_id == Settings.player_id:
				if not carry_latched:
					carry_latched = true
					state_time = 0.0
				if exit_after == "carry":
					_script(me.yaw, 0.0, false, false)
					if state_time > 0.55:
						finish(true)
				else:
					state = "escape"
					escape_step = 0
					state_time = 0.0
			else:
				_pulse_interact(me)
				if state_time > 6.0:
					fail("did_not_take_loot")
		"escape":
			var points: Array = [Vector3(20, 0.05, 0), Vector3(0, 0.05, 0), MatchRules.ESCAPE]
			if escape_step >= points.size():
				_script(me.yaw, 0.0, false, false)
				if state_time > 4.0:
					fail("no_escape_win")
				return
			if _goto(me, points[escape_step]):
				escape_step += 1
				state_time = 0.0

func _write(extra: Dictionary) -> void:
	var data := {
		"ok": bool(extra.get("ok", false)),
		"role": role,
		"reason": str(extra.get("reason", "")),
		"restored": bool(welcome.get("restored", false)),
		"team": int(welcome.get("team", -1)),
		"welcome_score": int(welcome.get("score", 0)),
		"welcome_cash": int(welcome.get("cash", 0)),
		"seen_health": seen_health,
		"net_errors": Net.net_errors,
		"state": state,
	}
	var world = Net.world
	var me: MatardaPlayer = null
	if world:
		me = world.local_player()
	if me:
		data["live_score"] = me.score
		data["live_cash"] = me.cash
		data["carrying"] = me.carrying
		data["health"] = me.health
	if result_path != "":
		var file := FileAccess.open(result_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
