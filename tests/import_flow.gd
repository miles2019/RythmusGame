extends Node
## Upload flow: ImportScreen (file -> analysis -> tune -> save) then play the saved song with a bot.

var imp: ImportScreen
var song: SongScene
var step := 0
var t := 0.0
var idx := 0


func _make_wav(path: String, bpm: float, offset: float, seconds: float) -> void:
	var sr := 44100
	var n := int(seconds * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var spb := 60.0 / bpm
	var beat := 0
	while offset + beat * spb < seconds - 0.3:
		var start := int((offset + beat * spb) * sr)
		var ph := 0.0
		for i in int(0.18 * sr):
			if start + i >= n:
				break
			var tt := float(i) / sr
			ph += TAU * (50.0 + 110.0 * exp(-tt * 30.0)) / sr
			buf[start + i] += sin(ph) * exp(-tt * 14.0) * 0.9
		beat += 1
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.data = bytes
	w.save_to_wav(path)


func _ready() -> void:
	Progress.save_path = "user://test_progress.cfg"
	Progress.custom = []
	DirAccess.make_dir_recursive_absolute("user://testwav")
	_make_wav("user://testwav/import_test.wav", 120.0, 0.25, 40.0)
	imp = ImportScreen.new()
	add_child(imp)
	imp._on_file(ProjectSettings.globalize_path("user://testwav/import_test.wav"))
	print("after _on_file: step=", imp._step)


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if imp._step == ImportScreen.Step.TUNE:
				print("analysed: bpm=%.2f offset=%.3f" % [imp._info.bpm, imp._info.offset])
				imp._tweak_bpm("+1", 1.0)
				imp._tweak_bpm("-1", -1.0)
				imp._tweak_offset(5.0)
				imp._toggle_preview()
				step = 1; t = 0.0
			elif t > 10.0:
				print("analysis timed out"); get_tree().quit(1)
		1:
			if t > 1.5:
				print("preview playing=%s last_beat=%d" % [imp._preview.playing, imp._last_beat])
				imp._save()
				print("saved: custom entries=%d id=%s" % [Progress.custom.size(), Progress.custom[0].id])
				var info: Dictionary = Progress.custom[0]
				imp.queue_free()
				song = load("res://scenes/SongScene.tscn").instantiate()
				add_child(song)
				song.begin(info, 1, false)
				print("song notes=%d sections=%d" % [song._chart.size(), info.sections.size()])
				step = 2; t = 0.0
		2:
			var tm: float = song.clock.time()
			while idx < song._chart.size() and song._chart[idx].time <= tm:
				song.lanes[song._chart[idx].lane].press(tm)
				if song._chart[idx].dur > 0.0:
					song.lanes[song._chart[idx].lane].release(tm + song._chart[idx].dur)
				idx += 1
			if tm > 14.0:
				print("after 14s: score=%d combo=%d counts=%s" % [song.score, song.combo, song.counts])
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_progress.cfg"))
				get_tree().quit()
