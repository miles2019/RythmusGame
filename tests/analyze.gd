extends Node
## Builds test tracks with a known tempo, saves them as .wav, runs the import analysis on them.

func _make(bpm: float, offset: float, seconds: float, swing_noise := true) -> AudioStreamWAV:
	var sr := 44100
	var n := int(seconds * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var spb := 60.0 / bpm
	var beat := 0
	while offset + beat * spb < seconds - 0.3:
		var start := int((offset + beat * spb) * sr)
		var dur := int(0.18 * sr)
		var ph := 0.0
		for i in dur:
			if start + i >= n:
				break
			var t := float(i) / sr
			ph += TAU * (50.0 + 110.0 * exp(-t * 30.0)) / sr
			buf[start + i] += sin(ph) * exp(-t * 14.0) * 0.9
		if beat % 2 == 1:
			for i in int(0.12 * sr):
				if start + i >= n:
					break
				buf[start + i] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / sr * 25.0) * 0.5
		# off-beat hat
		var hs := int((offset + (beat + 0.5) * spb) * sr)
		for i in int(0.03 * sr):
			if hs + i < n:
				buf[hs + i] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / sr * 120.0) * 0.25
		beat += 1
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.data = bytes
	return w


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://testwav")
	for spec in [[137.0, 0.31], [93.4, 0.05], [174.0, 0.2], [100.0, 0.0]]:
		var w := _make(spec[0], spec[1], 75.0)
		var path := "user://testwav/t_%d.wav" % int(spec[0])
		w.save_to_wav(path)
		var stored := CustomSongs.store_file(ProjectSettings.globalize_path(path))
		var stream := CustomSongs.load_stream({"file": stored})
		var t0 := Time.get_ticks_msec()
		var an := CustomSongs.new()
		var info := an.analyze(stream, "test", stored)
		print("expected %.2f bpm / %.3f s  ->  got %.2f bpm / %.3f s  (analysis %d ms)" % [spec[0], spec[1], info.bpm, info.offset, Time.get_ticks_msec() - t0])
		var notes := Chart.build(info, 1)
		print("   chart notes: easy=%d normal=%d hard=%d sections=%d" % [Chart.build(info, 0).size(), notes.size(), Chart.build(info, 2).size(), info.sections.size()])
	get_tree().quit()
