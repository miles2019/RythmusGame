extends Node
## Headless smoke test: plays a whole song with a bot, prints the result.
## Run: godot --headless --path . res://tests/smoke.tscn -- <mode> [song_index] [difficulty] [shot_dir]
## mode: perfect | miss | jitter | reduced

var scene
var mode := "perfect"
var idx := 0
var release_at: Array = []
var done := false
var frames := 0
var rng := RandomNumberGenerator.new()
var _shots := [8.0, 26.0, 41.0, 60.0]
var _shot_dir := ""


func _ready() -> void:
	Progress.save_path = "user://test_progress.cfg" # never touch the real save
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	var song_i := int(args[1]) if args.size() > 1 else 1
	var diff := int(args[2]) if args.size() > 2 else 1
	if args.size() > 3:
		_shot_dir = args[3]
	if mode == "reduced":
		Settings.screen_shake = false
		Settings.reduced_background = true
		Settings.reduced_particles = true
		Settings.reduced_animation = true
		Settings.alt_colors = true
		Settings.note_scale = 1.4
	var info := Songs.make_info(Songs.LIST[song_i])
	var t0 := Time.get_ticks_msec()
	Synth.get_song(info)
	print("synth ms: ", Time.get_ticks_msec() - t0, " song=", info.title, " diff=", diff)
	scene = load("res://scenes/SongScene.tscn").instantiate()
	add_child(scene)
	scene.begin(info, diff, false)
	for flag in args.slice(4):
		match flag:
			"nostage": scene.stage.visible = false; scene.stage.set_process(false)
			"nochars": scene.player.visible = false; scene.rival.visible = false
			"nofx": scene.fx.visible = false
			"nopost": scene.post_fx.visible = false
			"nohud": scene.hud.visible = false
			"nolanes": scene.lanes_root.visible = false
	scene.song_finished.connect(func(r):
		print("RESULT ", r)
		done = true
		get_tree().quit(0))
	print("chart notes: ", scene._chart.size(), " mode=", mode)


func _process(_delta: float) -> void:
	frames += 1
	if done:
		return
	var t: float = scene.clock.time()
	if _shot_dir != "" and _shots.size() > 0 and t >= _shots[0]:
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [_shot_dir, int(_shots[0])])
		_shots.pop_front()
	if mode == "spam":
		# button masher: taps a random lane every ~70 ms, ignoring the chart
		if t > 0.0 and int(t * 14.0) != int((t - _delta) * 14.0):
			var ln := rng.randi() % 4
			scene.lanes[ln].press(t)
			scene.lanes[ln].release(t + 0.02)
	elif mode != "miss":
		while idx < scene._chart.size() and scene._chart[idx].time <= t:
			var n: Dictionary = scene._chart[idx]
			idx += 1
			var jit := 0.0 if mode == "perfect" else rng.randf_range(-0.07, 0.07)
			scene.lanes[n.lane].press(t + jit)
			if n.dur > 0.0:
				release_at.append([n.time + n.dur + 0.02, n.lane])
	for r in release_at.duplicate():
		if t >= r[0]:
			scene.lanes[r[1]].release(t)
			release_at.erase(r)
	if frames % 600 == 0:
		print("t=%.1f score=%d combo=%d stab=%.0f dmg=%.2f fps=%d proc=%.2fms draws=%d" % [t, scene.score, scene.combo, scene.stability, scene.player.damage, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if frames > 60 * 1000:
		print("TIMEOUT")
		get_tree().quit(1)
