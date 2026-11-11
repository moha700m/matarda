extends Node3D

const PlayerScript := preload("res://scripts/player/matarda_player.gd")

var players := {}
var phase := MatchRules.Phase.WAITING
var time_left := MatchRules.MATCH_SECONDS
var robbery_active := false
var hold_left := MatchRules.HOLD_SECONDS
var hold_total := MatchRules.HOLD_SECONDS
var loot_ready := false
var carrier_player_id := ""
var winner := ""
var end_left := 0.0
var criminals_joined := 0
var landmarks := {}
var sun: DirectionalLight3D
var environment: Environment
var _snap_acc := 0.0
var _match_acc := 0.0
var _debug_acc := 0.0
var _round_index := 1
var _tracers: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("quality_listener")
	hold_total = MatchRules.HOLD_SECONDS_TEST if Net.test_mode else MatchRules.HOLD_SECONDS
	hold_left = hold_total
	_build_environment()
	landmarks = CityBuilder.build(self, Settings.quality)
	on_quality_changed()

func _physics_process(delta: float) -> void:
	if Net.is_server:
		for id in players.keys():
			var player: MatardaPlayer = players[id]
			var intent := _intent_for(player)
			var before_floor: bool = player.is_on_floor()
			player.tick(delta, intent, true)
			if player.is_local and not before_floor and player.is_on_floor() and player.velocity.y <= 0.1:
				pass
			if bool(intent.get("jump", false)) and player.is_local:
				AudioDirector.play("jump", 1.0)
			if intent.get("shoot", false):
				_try_fire(player)
			if player.edge_interact or (player.is_local and bool(intent.get("interact", false))):
				player.edge_interact = false
				_try_interact(player)
		_simulate_rules(delta)
		_snap_acc += delta
		_match_acc += delta
		if _snap_acc >= 0.05:
			_snap_acc = 0.0
			Net.broadcast_snapshot(_build_snapshot())
		if _match_acc >= 0.25:
			_match_acc = 0.0
			Net.broadcast_match(match_state())
		if Net.test_mode:
			_debug_acc += delta
			if _debug_acc >= 1.0:
				_debug_acc = 0.0
				for debug_player in players.values():
					print("MATARDA_POS id=%s team=%s pos=%s yaw=%.2f" % [debug_player.peer_id, debug_player.team, debug_player.global_position, debug_player.yaw])
	else:
		var me = local_player()
		if me and not me.arrested and not me.eliminated:
			var intent := Controls.poll()
			var jumped := bool(intent.get("jump", false))
			me.tick(delta, intent, false)
			Net.send_input_from(me, intent)
			if jumped:
				Net.send_action("jump")
				AudioDirector.play("jump")
			if bool(intent.get("interact", false)):
				Net.send_action("interact")
		_fade_tracers(delta)

func _intent_for(player: MatardaPlayer) -> Dictionary:
	if player.is_local and not Net.is_dedicated:
		return Controls.poll()
	var age := Time.get_ticks_msec() / 1000.0 - float(player.net_input.get("time", 0.0))
	var intent: Dictionary = player.net_input.duplicate()
	if age > MatchRules.INPUT_TIMEOUT:
		intent.x = 0.0
		intent.z = 0.0
		intent.sprint = false
		intent.shoot = false
	intent["absolute"] = true
	intent["jump"] = player.edge_jump
	intent["interact"] = false
	return intent

func push_input(peer_id: int, seq: int, x: float, z: float, crouch: bool, sprint: bool, yaw: float, pitch: float, shoot: bool) -> void:
	var player = players.get(peer_id)
	if player == null:
		return
	if seq <= int(player.net_input.get("seq", 0)) and seq > 0:
		return
	if is_nan(yaw) or is_inf(yaw):
		yaw = player.yaw
	player.net_input = {
		"seq": seq,
		"x": x,
		"z": z,
		"crouch": crouch,
		"sprint": sprint,
		"yaw": clampf(MatchRules.finitef(yaw, player.yaw), -100.0, 100.0),
		"pitch": clampf(MatchRules.finitef(pitch, 0.0), -1.2, 1.2),
		"shoot": shoot,
		"time": Time.get_ticks_msec() / 1000.0,
	}

func push_action(peer_id: int, action: String) -> bool:
	var player = players.get(peer_id)
	if player == null or player.arrested or player.eliminated:
		return false
	if action == "jump" and not player.downed:
		player.edge_jump = true
		return true
	if action == "interact":
		player.edge_interact = true
		return true
	return false

func spawn_player(data: Dictionary) -> void:
	var peer_id := int(data.get("peer_id", data.get("id", 0)))
	if players.has(peer_id):
		players[peer_id].apply_profile_numbers(data)
		return
	var player: MatardaPlayer = PlayerScript.new()
	player.name = "Player%s" % peer_id
	var local := peer_id == multiplayer.get_unique_id() and not Net.is_dedicated
	if Net.offline:
		local = true
	player.setup(data, local)
	var spawn := MatchRules.POLICE_SPAWN if player.team == MatchRules.Team.POLICE else MatchRules.CRIMINAL_SPAWN
	if data.has("pos"):
		spawn = data["pos"]
	player.yaw = float(data.get("yaw", 0.0 if player.team == MatchRules.Team.CRIMINAL else PI))
	add_child(player)
	player.global_position = spawn
	players[peer_id] = player
	if player.carrying:
		carrier_player_id = player.player_id
		loot_ready = false
	if player.team == MatchRules.Team.CRIMINAL:
		criminals_joined += 1
	if Net.is_server and phase == MatchRules.Phase.WAITING:
		phase = MatchRules.Phase.ACTIVE
		time_left = MatchRules.MATCH_SECONDS

func despawn(peer_id: int, drop_loot: bool = true) -> void:
	if not players.has(peer_id):
		return
	var player = players[peer_id]
	if drop_loot and player.carrying:
		player.carrying = false
		loot_ready = true
		carrier_player_id = ""
	players.erase(peer_id)
	player.queue_free()

func capture_state(peer_id: int) -> Dictionary:
	var player = players.get(peer_id)
	if player == null:
		return {}
	return {
		"pos": player.global_position,
		"yaw": player.yaw,
		"health": player.health,
		"cash": player.cash,
		"score": player.score,
		"carrying": player.carrying,
		"downed": player.downed,
		"arrested": player.arrested,
		"eliminated": player.eliminated,
		"team": player.team,
		"outfit": player.outfit,
	}

func local_player() -> MatardaPlayer:
	var id := 1 if Net.offline else multiplayer.get_unique_id()
	var found = players.get(id)
	if found == null:
		return null
	return found

func player_by_team(team: int):
	for player in players.values():
		if player.team == team and not player.arrested and not player.eliminated:
			return player
	return null

func match_state() -> Dictionary:
	return {
		"phase": phase,
		"time_left": time_left,
		"robbery": robbery_active,
		"hold_left": hold_left,
		"hold_total": hold_total,
		"loot_ready": loot_ready,
		"carrier": carrier_player_id,
		"winner": winner,
		"round": _round_index,
	}

func apply_match(state: Dictionary) -> void:
	phase = int(state.get("phase", phase))
	time_left = float(state.get("time_left", time_left))
	robbery_active = bool(state.get("robbery", robbery_active))
	hold_left = float(state.get("hold_left", hold_left))
	hold_total = float(state.get("hold_total", hold_total))
	loot_ready = bool(state.get("loot_ready", loot_ready))
	carrier_player_id = str(state.get("carrier", carrier_player_id))
	winner = str(state.get("winner", winner))

func apply_snapshot(states: Array) -> void:
	for state in states:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var id := int(state.get("id", 0))
		var player: MatardaPlayer = players.get(id)
		if player == null:
			spawn_player(state)
			player = players.get(id)
			if player == null:
				continue
		var me: MatardaPlayer = local_player()
		if me and id == me.peer_id:
			player.apply_profile_numbers(state)
			var server_pos: Vector3 = state.get("pos", player.global_position)
			var error: float = player.global_position.distance_to(server_pos)
			if error > 2.0:
				player.global_position = server_pos
				player.velocity = state.get("vel", player.velocity)
			elif error > 0.5:
				player.global_position = player.global_position.lerp(server_pos, 0.35)
			player.carrying = bool(state.get("carry", player.carrying))
			continue
		player.apply_profile_numbers(state)
		player.global_position = player.global_position.lerp(state.get("pos", player.global_position), 0.55)
		player.yaw = float(state.get("yaw", player.yaw))
		player.pitch = float(state.get("pitch", player.pitch))
		player.crouching = bool(state.get("crouch", false))
		player._apply_capsule(player.crouching or player.downed)
		player._animate(0.016)

func spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := maxf(0.2, from.distance_to(to))
	mesh.size = Vector3(0.035, 0.035, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	mi.mesh = mesh
	mi.position = (from + to) * 0.5
	mi.look_at_from_position(mi.position, to, Vector3.UP)
	mi.set_meta("life", 0.08)
	add_child(mi)
	_tracers.append(mi)

func _fade_tracers(delta: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		var mi := _tracers[i]
		if not is_instance_valid(mi):
			_tracers.remove_at(i)
			continue
		var life := float(mi.get_meta("life")) - delta
		mi.set_meta("life", life)
		if life <= 0.0:
			mi.queue_free()
			_tracers.remove_at(i)

func _try_fire(player: MatardaPlayer) -> void:
	if player.downed or player.arrested or player.eliminated:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < player.next_fire:
		return
	player.next_fire = now + MatchRules.FIRE_INTERVAL
	var origin: Vector3 = player.eye_position()
	var dir: Vector3 = player.aim_direction()
	var target: Vector3 = origin + dir * MatchRules.FIRE_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = MatchRules.LAYER_WORLD | MatchRules.LAYER_ACTOR
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = target
	if not hit.is_empty():
		end = hit.position
		var collider = hit.collider
		if collider and collider.is_in_group("matarda_player"):
			if collider.team != player.team and not collider.downed and not collider.arrested and not collider.eliminated:
				collider.health = maxi(0, collider.health - MatchRules.FIRE_DAMAGE)
				Net.log_event("hit")
				AudioDirector.play("hit")
				if collider.health <= 0:
					collider.downed = true
					collider.bleed = MatchRules.BLEED_SECONDS
					if collider.carrying:
						collider.carrying = false
						carrier_player_id = ""
						loot_ready = true
					Net.log_event("downed")
	spawn_tracer(origin, end)
	Net.broadcast_shot(origin, end, player.peer_id)
	if Net.is_listen_host() or Net.offline:
		AudioDirector.play("shoot")
	if Net.test_mode:
		var hit_name := "none"
		if not hit.is_empty() and hit.collider:
			hit_name = str(hit.collider.name)
		print("MATARDA_SHOT peer=%s hit=%s origin=%s dir=%s yaw=%.2f pitch=%.2f" % [player.peer_id, hit_name, origin, dir, player.yaw, player.pitch])

func _try_interact(player: MatardaPlayer) -> void:
	if player.downed or player.arrested or player.eliminated:
		return
	if player.team == MatchRules.Team.CRIMINAL:
		var vault_dist: float = player.global_position.distance_to(MatchRules.VAULT)
		if Net.test_mode:
			print("MATARDA_INTERACT pos=%s dist=%.2f robbery=%s loot=%s" % [player.global_position, vault_dist, robbery_active, loot_ready])
		if vault_dist <= MatchRules.INTERACT_DISTANCE:
			if not robbery_active and phase == MatchRules.Phase.ACTIVE:
				robbery_active = true
				hold_left = hold_total
				loot_ready = false
				AudioDirector.play("alarm")
				Net.log_event("robbery_start")
				Net.broadcast_match(match_state())
				return
			if loot_ready and carrier_player_id == "":
				carrier_player_id = player.player_id
				player.carrying = true
				player.score += 100
				player.cash += 250
				loot_ready = false
				AudioDirector.play("pickup")
				Net.log_event("loot")
				Net.broadcast_match(match_state())
				return
			AudioDirector.play("deny")
		return
	if player.team == MatchRules.Team.POLICE:
		for other in players.values():
			if other.team != MatchRules.Team.CRIMINAL or not other.downed or other.arrested:
				continue
			if player.global_position.distance_to(other.global_position) <= MatchRules.INTERACT_DISTANCE:
				other.arrested = true
				other.downed = false
				player.score += 50
				player.cash += 100
				if other.carrying:
					other.carrying = false
					carrier_player_id = ""
					loot_ready = true
				AudioDirector.play("arrest")
				Net.log_event("arrest")
				Net.broadcast_match(match_state())
				return

func _simulate_rules(delta: float) -> void:
	if phase == MatchRules.Phase.CRIMINAL_WIN or phase == MatchRules.Phase.POLICE_WIN:
		end_left -= delta
		if end_left <= 0.0:
			_reset_round()
		return
	if phase != MatchRules.Phase.ACTIVE:
		return
	time_left -= delta
	var holder_inside := false
	for player in players.values():
		if player.downed and not player.arrested:
			player.bleed -= delta
			if player.bleed <= 0.0:
				player.eliminated = true
				player.downed = false
				Net.log_event("eliminated")
		if player.team == MatchRules.Team.CRIMINAL and not player.arrested and not player.eliminated and not player.downed:
			if _inside_bank(player.global_position):
				holder_inside = true
		if player.carrying and player.global_position.distance_to(MatchRules.ESCAPE) <= MatchRules.ESCAPE_DISTANCE:
			_finish(MatchRules.Phase.CRIMINAL_WIN)
			return
	if robbery_active and carrier_player_id == "" and not loot_ready:
		if holder_inside:
			hold_left = maxf(0.0, hold_left - delta)
		else:
			hold_left = minf(hold_total, hold_left + delta * 0.35)
		if hold_left <= 0.0:
			loot_ready = true
			AudioDirector.play("pickup")
			Net.log_event("loot_ready")
			Net.broadcast_match(match_state())
	if time_left <= 0.0:
		_finish(MatchRules.Phase.POLICE_WIN)
		return
	if criminals_joined > 0 and _living_criminals() <= 0:
		_finish(MatchRules.Phase.POLICE_WIN)

func _living_criminals() -> int:
	var count := 0
	for player in players.values():
		if player.team == MatchRules.Team.CRIMINAL and not player.arrested and not player.eliminated:
			count += 1
	for held in Net.held.values():
		if int(held.get("team", -1)) == MatchRules.Team.CRIMINAL and not bool(held.get("arrested", false)) and not bool(held.get("eliminated", false)):
			count += 1
	return count

func _inside_bank(pos: Vector3) -> bool:
	return pos.x > 12.6 and pos.x < 27.4 and pos.z < -8.4 and pos.z > -19.6

func _finish(which: int) -> void:
	phase = which
	winner = "criminal" if which == MatchRules.Phase.CRIMINAL_WIN else "police"
	end_left = 8.0
	AudioDirector.play("win" if which == MatchRules.Phase.CRIMINAL_WIN else "lose")
	Net.log_event("criminal_win" if which == MatchRules.Phase.CRIMINAL_WIN else "police_win")
	Net.broadcast_match(match_state())

func _reset_round() -> void:
	phase = MatchRules.Phase.ACTIVE
	time_left = MatchRules.MATCH_SECONDS
	robbery_active = false
	hold_left = hold_total
	loot_ready = false
	carrier_player_id = ""
	winner = ""
	_round_index += 1
	for player in players.values():
		player.health = MatchRules.MAX_HEALTH
		player.downed = false
		player.arrested = false
		player.eliminated = false
		player.carrying = false
		player.bleed = 0.0
		var spawn := MatchRules.POLICE_SPAWN if player.team == MatchRules.Team.POLICE else MatchRules.CRIMINAL_SPAWN
		player.global_position = spawn
		player.velocity = Vector3.ZERO
	Net.broadcast_match(match_state())

func _build_snapshot() -> Array:
	var rows := []
	for player in players.values():
		rows.append(player.snapshot_dict())
	return rows

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.22, 0.46)
	sky_mat.sky_horizon_color = Color(0.97, 0.46, 0.26)
	sky_mat.ground_bottom_color = Color(0.16, 0.1, 0.1)
	sky_mat.ground_horizon_color = Color(0.72, 0.36, 0.22)
	sky_mat.sun_angle_max = 26.0
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.93, 0.52, 0.34)
	environment.fog_density = 0.0075
	environment.fog_aerial_perspective = 0.35
	environment.glow_enabled = false
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-32, -48, 0)
	sun.light_color = Color(1.0, 0.78, 0.55)
	sun.light_energy = 1.35
	sun.shadow_enabled = Settings.quality > 0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

func on_quality_changed() -> void:
	if sun:
		sun.shadow_enabled = Settings.quality > 0
		sun.shadow_blur = 0.0 if Settings.quality < 2 else 0.6
	if environment:
		environment.glow_enabled = Settings.quality >= 2
		environment.glow_intensity = 0.28
		environment.glow_bloom = 0.08
		environment.fog_density = 0.004 if Settings.quality == 0 else 0.0075
	var far := Settings.detail_range()
	for node in get_tree().get_nodes_in_group("detail_prop"):
		if node is GeometryInstance3D:
			node.visibility_range_end = far

func objective_key(player) -> String:
	if player == null:
		return "waiting"
	if phase == MatchRules.Phase.CRIMINAL_WIN:
		return "criminal_win"
	if phase == MatchRules.Phase.POLICE_WIN:
		return "police_win"
	if player.downed:
		return "obj_down"
	if player.team == MatchRules.Team.POLICE:
		return "obj_police"
	if player.carrying:
		return "obj_escape"
	if loot_ready:
		return "obj_loot"
	if robbery_active:
		return "obj_hold"
	return "obj_go_bank"

func prompt_key(player) -> String:
	if player == null or player.downed or phase != MatchRules.Phase.ACTIVE:
		return ""
	if player.team == MatchRules.Team.CRIMINAL:
		if player.global_position.distance_to(MatchRules.VAULT) > MatchRules.INTERACT_DISTANCE:
			return ""
		if not robbery_active:
			return "interact_rob"
		if loot_ready and carrier_player_id == "":
			return "interact_loot"
	elif player.team == MatchRules.Team.POLICE:
		for other in players.values():
			if other.downed and not other.arrested and player.global_position.distance_to(other.global_position) <= MatchRules.INTERACT_DISTANCE:
				return "interact_arrest"
	return ""
