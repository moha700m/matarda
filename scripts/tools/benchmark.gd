extends Node

func _ready() -> void:
	var seconds := 4.0
	for token in OS.get_cmdline_user_args():
		if str(token).is_valid_float():
			seconds = float(token)
	Net.start_offline()
	Net.world.spawn_player({
		"peer_id": 1,
		"player_id": "bench-player-01",
		"name": "Bench",
		"team": MatchRules.Team.POLICE,
		"outfit": 0,
	})
	var report := {}
	for quality in [0, 2]:
		Settings.quality = quality
		Settings.apply_quality()
		Net.world.on_quality_changed()
		report["q%d" % quality] = await _sample(seconds)
	var path := ProjectSettings.globalize_path("res://docs/test_results/benchmark.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	print("MATARDA_BENCH ", JSON.stringify(report))
	get_tree().quit(0)

func _sample(seconds: float) -> Dictionary:
	var elapsed := 0.0
	var frames := 0
	var bucket_t := 0.0
	var bucket_f := 0
	var min_fps := 9999.0
	var ram_peak := 0.0
	var me = Net.world.local_player()
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
		ram_peak = maxf(ram_peak, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		if me:
			me.yaw += step * 0.4
	return {
		"avg_fps": frames / maxf(elapsed, 0.001),
		"min_fps": min_fps,
		"ram_static_mb": ram_peak,
		"seconds": elapsed,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
	}
