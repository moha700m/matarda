extends Node

signal welcome_received(payload)
signal rejected(reason)
signal room_received(info)
signal connection_failed_reason(reason)
signal disconnected
signal match_received(state)

const WorldScript := preload("res://scripts/game/world_session.gd")

var is_server := false
var is_dedicated := false
var offline := false
var test_mode := false
var probing := false
var expect_disconnect := false
var port := 7777
var my_id := 0
var world = null
var profiles := {}
var held := {}
var welcome := {}
var net_errors := 0
var speed_clamps := 0
var rejected_actions := 0
var events: Array = []
var result_path := ""
var input_seq := 0
var _action_times := {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(_delta: float) -> void:
	if not is_server:
		return
	var now := Time.get_unix_time_from_system()
	var expired: Array = []
	for key in held.keys():
		if float(held[key].get("expire", 0.0)) < now:
			expired.append(key)
	for key in expired:
		if world and str(world.carrier_player_id) == str(key):
			world.carrier_player_id = ""
			world.loot_ready = true
		held.erase(key)
		log_event("hold_expired:%s" % key)

func start_dedicated(listen_port: int) -> int:
	return _start_server(listen_port, true)

func start_listen(listen_port: int) -> int:
	return _start_server(listen_port, false)

func start_offline() -> void:
	offline = true
	is_server = true
	is_dedicated = false
	my_id = 1
	ensure_world()

func join(ip: String, listen_port: int) -> int:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, listen_port)
	if err != OK:
		net_errors += 1
		print("MATARDA_NET_ERROR create_client %s" % err)
		connection_failed_reason.emit("create_client")
		return err
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_dedicated = false
	offline = false
	port = listen_port
	return OK

func probe(ip: String, listen_port: int) -> int:
	probing = true
	expect_disconnect = false
	return join(ip, listen_port)

func leave() -> void:
	expect_disconnect = true
	_close_peer()
	is_server = false

func ensure_world():
	if world and is_instance_valid(world):
		return world
	world = WorldScript.new()
	world.name = "WorldSession"
	add_child(world)
	return world

func destroy_world() -> void:
	if world and is_instance_valid(world):
		world.queue_free()
	world = null
	players_clear_local()

func players_clear_local() -> void:
	profiles.clear()

func is_listen_host() -> bool:
	return is_server and not is_dedicated and not offline

func note_speed_clamp() -> void:
	speed_clamps += 1

func log_event(ev: String) -> void:
	events.append(ev)
	print("MATARDA_EVENT %s" % ev)
	write_result()

func write_result() -> void:
	if result_path == "":
		return
	var payload := {
		"events": events,
		"net_errors": net_errors,
		"speed_clamps": speed_clamps,
		"rejected_actions": rejected_actions,
		"players": profiles.size(),
		"held": held.size(),
		"phase": world.phase if world else -1,
		"carrier": world.carrier_player_id if world else "",
		"robbery": world.robbery_active if world else false,
		"loot_ready": world.loot_ready if world else false,
	}
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "\t"))

func room_info() -> Dictionary:
	var phase_name := "lobby"
	if world:
		match int(world.phase):
			MatchRules.Phase.ACTIVE:
				phase_name = "active"
			MatchRules.Phase.CRIMINAL_WIN:
				phase_name = "criminal_win"
			MatchRules.Phase.POLICE_WIN:
				phase_name = "police_win"
	return {
		"name": "Sunset District",
		"name_key": "sunset_room",
		"map": "sunset_blocks",
		"players": profiles.size(),
		"max": MatchRules.MAX_PLAYERS,
		"phase": phase_name,
		"port": port,
	}

func submit_team(team: int) -> void:
	if offline:
		return
	if is_server:
		_apply_team(1, team)
	else:
		rpc_select_team.rpc_id(1, team)

func send_input_from(player, intent: Dictionary) -> void:
	if is_server or offline:
		return
	if multiplayer.multiplayer_peer == null:
		return
	input_seq += 1
	rpc_input.rpc_id(
		1,
		input_seq,
		float(intent.get("x", 0.0)),
		float(intent.get("z", 0.0)),
		bool(intent.get("crouch", false)),
		bool(intent.get("sprint", false)),
		float(player.yaw),
		float(player.pitch),
		bool(intent.get("shoot", false))
	)

func send_action(action: String) -> void:
	if offline:
		return
	if is_server:
		if _allow_action(1) and world:
			world.push_action(1, action)
		return
	if multiplayer.multiplayer_peer == null:
		return
	rpc_action.rpc_id(1, action)

func broadcast_snapshot(states: Array) -> void:
	if offline or not is_server or multiplayer.multiplayer_peer == null:
		return
	rpc_snapshot.rpc(states)

func broadcast_match(state: Dictionary) -> void:
	if offline or not is_server or multiplayer.multiplayer_peer == null:
		return
	rpc_match.rpc(state)

func broadcast_shot(from: Vector3, to: Vector3, shooter: int) -> void:
	if offline or multiplayer.multiplayer_peer == null:
		return
	rpc_shot.rpc(from, to, shooter)

func _start_server(listen_port: int, dedicated: bool) -> int:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(listen_port, MatchRules.MAX_PLAYERS)
	if err != OK:
		net_errors += 1
		print("MATARDA_NET_ERROR create_server %s" % err)
		return err
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_dedicated = dedicated
	offline = false
	port = listen_port
	my_id = 1
	ensure_world()
	if not dedicated:
		_register_local_host()
	print("MATARDA_SERVER_READY port=%s" % listen_port)
	write_result()
	return OK

func _register_local_host() -> void:
	profiles[1] = _blank_profile(Settings.player_id, Settings.player_name, Settings.outfit)
	welcome = _public_profile(1)
	welcome_received.emit(welcome)

func _blank_profile(player_id: String, display_name: String, outfit: int) -> Dictionary:
	return {
		"player_id": player_id,
		"name": _clean_name(display_name),
		"outfit": clampi(outfit, 0, 3),
		"team": MatchRules.Team.NONE,
		"score": 0,
		"cash": 0,
		"health": MatchRules.MAX_HEALTH,
		"carrying": false,
		"spawned": false,
		"restored": false,
		"downed": false,
		"arrested": false,
		"eliminated": false,
	}

func _public_profile(peer_id: int) -> Dictionary:
	var prof: Dictionary = profiles[peer_id].duplicate(true)
	prof["peer_id"] = peer_id
	prof["room"] = room_info()
	return prof

func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	ensure_world()
	if probing:
		rpc_query.rpc_id(1)
		return
	rpc_hello.rpc_id(1, Settings.player_id, Settings.player_name, Settings.outfit)

func _on_connection_failed() -> void:
	net_errors += 1
	probing = false
	print("MATARDA_NET_ERROR connection_failed")
	connection_failed_reason.emit("connection_failed")

func _on_server_disconnected() -> void:
	print("MATARDA_NET server_disconnected")
	if not expect_disconnect:
		net_errors += 1
		print("MATARDA_NET_ERROR unexpected_disconnect")
	expect_disconnect = false
	disconnected.emit()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if not is_server:
		return
	if not profiles.has(id):
		return
	var prof: Dictionary = profiles[id]
	var row: Dictionary = prof.duplicate(true)
	row["expire"] = Time.get_unix_time_from_system() + MatchRules.RECONNECT_SECONDS
	if world:
		var live: Dictionary = world.capture_state(id)
		if not live.is_empty():
			row["health"] = live.get("health", row.get("health", 100))
			row["cash"] = live.get("cash", 0)
			row["score"] = live.get("score", 0)
			row["carrying"] = live.get("carrying", false)
			row["pos"] = live.get("pos", MatchRules.CRIMINAL_SPAWN)
			row["yaw"] = live.get("yaw", 0.0)
			row["downed"] = live.get("downed", false)
			row["arrested"] = live.get("arrested", false)
			row["eliminated"] = live.get("eliminated", false)
			row["team"] = live.get("team", row.get("team", MatchRules.Team.NONE))
			row["outfit"] = live.get("outfit", row.get("outfit", 0))
	held[str(prof.get("player_id", ""))] = row
	profiles.erase(id)
	if world:
		world.despawn(id, false)
	if multiplayer.multiplayer_peer != null:
		rpc_despawn.rpc(id)
	log_event("disconnect:%s" % str(prof.get("player_id", "")))

func _apply_team(peer_id: int, team: int) -> void:
	var prof = profiles.get(peer_id)
	if prof == null or bool(prof.get("spawned", false)):
		return
	if bool(prof.get("restored", false)):
		team = int(prof.get("team", team))
	elif team != MatchRules.Team.POLICE and team != MatchRules.Team.CRIMINAL:
		return
	else:
		prof["team"] = team
	prof["spawned"] = true
	profiles[peer_id] = prof
	_spawn_profile(peer_id)

func _spawn_profile(peer_id: int) -> void:
	var data := _public_profile(peer_id)
	ensure_world().spawn_player(data)
	if offline or multiplayer.multiplayer_peer == null:
		return
	rpc_spawn.rpc(peer_id, data)
	if world:
		for other_id in world.players.keys():
			if int(other_id) == peer_id:
				continue
			var other = world.players[other_id]
			rpc_spawn.rpc_id(peer_id, int(other_id), other.snapshot_dict())
	log_event("spawn:%s team=%s" % [str(data.get("player_id", "")), str(data.get("team", -1))])

func _allow_action(peer_id: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var kept: Array = []
	for stamp in _action_times.get(peer_id, []):
		if now - float(stamp) < 1.0:
			kept.append(stamp)
	if kept.size() >= 12:
		rejected_actions += 1
		_action_times[peer_id] = kept
		return false
	kept.append(now)
	_action_times[peer_id] = kept
	return true

func _valid_player_id(player_id: String) -> bool:
	if player_id.length() < 6 or player_id.length() > 40:
		return false
	for i in player_id.length():
		var ch := player_id.unicode_at(i)
		var ok := (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95 or ch == 45
		if not ok:
			return false
	return true

func _clean_name(display_name: String) -> String:
	var trimmed := display_name.replace("\n", " ").replace("\r", " ").strip_edges()
	if trimmed == "":
		trimmed = "Guest"
	return trimmed.substr(0, 16)

@rpc("any_peer", "reliable")
func rpc_query() -> void:
	if not is_server:
		return
	rpc_room.rpc_id(multiplayer.get_remote_sender_id(), room_info())

@rpc("authority", "reliable")
func rpc_room(info: Dictionary) -> void:
	room_received.emit(info)
	if probing:
		probing = false
		expect_disconnect = true
		_close_peer()

@rpc("any_peer", "reliable")
func rpc_hello(player_id: String, display_name: String, outfit: int) -> void:
	if not is_server:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _valid_player_id(player_id):
		rpc_reject.rpc_id(sender, "bad_id")
		log_event("reject_bad_id")
		return
	for existing_id in profiles.keys():
		if int(existing_id) != sender and str(profiles[existing_id].get("player_id", "")) == player_id:
			rpc_reject.rpc_id(sender, "duplicate")
			log_event("reject_duplicate")
			return
	var prof := _blank_profile(player_id, display_name, int(outfit))
	var restored := false
	if held.has(player_id):
		var previous: Dictionary = held[player_id]
		if float(previous.get("expire", 0.0)) >= Time.get_unix_time_from_system():
			restored = true
			prof["team"] = int(previous.get("team", MatchRules.Team.NONE))
			prof["score"] = int(previous.get("score", 0))
			prof["cash"] = int(previous.get("cash", 0))
			prof["health"] = int(previous.get("health", MatchRules.MAX_HEALTH))
			prof["carrying"] = bool(previous.get("carrying", false))
			prof["outfit"] = int(previous.get("outfit", prof["outfit"]))
			prof["name"] = str(previous.get("name", prof["name"]))
			prof["downed"] = bool(previous.get("downed", false))
			prof["arrested"] = bool(previous.get("arrested", false))
			prof["eliminated"] = bool(previous.get("eliminated", false))
			if previous.has("pos"):
				prof["pos"] = previous["pos"]
			if previous.has("yaw"):
				prof["yaw"] = previous["yaw"]
		held.erase(player_id)
	prof["restored"] = restored
	profiles[sender] = prof
	rpc_welcome.rpc_id(sender, _public_profile(sender))
	log_event("hello:%s restored=%s score=%s" % [player_id, restored, str(prof["score"])])
	if restored and int(prof["team"]) != MatchRules.Team.NONE and not bool(prof.get("arrested", false)):
		prof["spawned"] = true
		profiles[sender] = prof
		_spawn_profile(sender)

@rpc("authority", "reliable")
func rpc_welcome(payload: Dictionary) -> void:
	welcome = payload
	welcome_received.emit(payload)

@rpc("authority", "reliable")
func rpc_reject(reason: String) -> void:
	net_errors += 1
	print("MATARDA_NET_ERROR reject %s" % reason)
	rejected.emit(reason)

@rpc("any_peer", "reliable")
func rpc_select_team(team: int) -> void:
	if not is_server:
		return
	_apply_team(multiplayer.get_remote_sender_id(), team)

@rpc("authority", "reliable")
func rpc_spawn(peer_id: int, data: Dictionary) -> void:
	if is_server:
		return
	data = data.duplicate(true)
	data["peer_id"] = peer_id
	ensure_world().spawn_player(data)

@rpc("authority", "reliable")
func rpc_despawn(peer_id: int) -> void:
	if is_server or world == null:
		return
	world.despawn(peer_id, false)

@rpc("any_peer", "unreliable_ordered")
func rpc_input(seq: int, x: float, z: float, crouch: bool, sprint: bool, yaw: float, pitch: float, shoot: bool) -> void:
	if not is_server or world == null:
		return
	world.push_input(multiplayer.get_remote_sender_id(), seq, x, z, crouch, sprint, yaw, pitch, shoot)

@rpc("any_peer", "reliable")
func rpc_action(action: String) -> void:
	if not is_server or world == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _allow_action(sender):
		return
	if action != "jump" and action != "interact":
		return
	world.push_action(sender, action)

@rpc("authority", "unreliable_ordered")
func rpc_snapshot(states: Array) -> void:
	if is_server or world == null:
		return
	world.apply_snapshot(states)

@rpc("authority", "reliable")
func rpc_match(state: Dictionary) -> void:
	if world:
		world.apply_match(state)
	match_received.emit(state)

@rpc("authority", "unreliable")
func rpc_shot(from: Vector3, to: Vector3, _shooter: int) -> void:
	if is_server:
		return
	if world:
		world.spawn_tracer(from, to)
	AudioDirector.play("shoot")
