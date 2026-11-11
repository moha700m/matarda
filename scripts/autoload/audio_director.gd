extends Node

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0

func _ready() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir == null:
		push_error("MATARDA audio folder missing")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".wav"):
			var key := file_name.trim_suffix(".wav")
			_streams[key] = load("res://assets/audio/%s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func has_stream(key: String) -> bool:
	return _streams.has(key)

func stream_count() -> int:
	return _streams.size()

func play(key: String, pitch: float = 1.0) -> void:
	var stream = _streams.get(key)
	if stream == null or _players.is_empty():
		return
	var player := _players[_cursor % _players.size()]
	_cursor += 1
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(maxf(Settings.sfx_volume, 0.0001))
	player.play()
