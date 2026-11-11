extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(168, 168)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.04, 0.06, 0.1, 0.82), true)
	draw_rect(rect, Color(1.0, 0.48, 0.1, 0.9), false, 2.0)
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_arc(center, radius, 0, TAU, 40, Color(1, 1, 1, 0.08), 1.0, true)
	var world = Net.world
	if world == null:
		return
	var me = world.local_player()
	var origin := Vector3.ZERO
	var yaw := 0.0
	if me:
		origin = me.global_position
		yaw = me.yaw
	var scale := 2.15
	_blip(center, origin, yaw, scale, radius, MatchRules.VAULT, Color("FF7A1A"))
	_blip(center, origin, yaw, scale, radius, MatchRules.POLICE_SPAWN, Color("2F6FED"))
	_blip(center, origin, yaw, scale, radius, MatchRules.ESCAPE, Color("3DDC97"))
	for player in world.players.values():
		if me and player.peer_id == me.peer_id:
			continue
		var color := CharacterMesh.team_color(player.team)
		_blip(center, origin, yaw, scale, radius, player.global_position, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -9),
		center + Vector2(6, 7),
		center + Vector2(-6, 7),
	]), Color("F4F1EA"))

func _blip(center: Vector2, origin: Vector3, yaw: float, scale: float, radius: float, world_pos: Vector3, color: Color) -> void:
	var rel := world_pos - origin
	var point := Vector2(rel.x, rel.z).rotated(yaw) * scale
	if point.length() > radius:
		point = point.normalized() * radius
	draw_circle(center + point, 4.5, color)
