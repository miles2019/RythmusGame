extends Node
func _ready() -> void:
	for s in Songs.LIST:
		var info := Songs.make_info(s)
		var t0 := Time.get_ticks_msec()
		var song := Synth.get_song(info)
		var w: AudioStreamWAV = song.full
		var d := w.data
		var n := d.size() / 2
		var peak := 0
		var clipped := 0
		var sec_rms := []
		var per := int(Synth.SR * 60.0 / info.bpm * 4.0 * 4.0)  # 4 bars
		var acc := 0.0
		for i in n:
			var v := absi(d.decode_s16(i * 2))
			peak = maxi(peak, v)
			if v >= 31990:
				clipped += 1
			acc += float(v) * v
			if (i + 1) % per == 0:
				sec_rms.append(snappedf(sqrt(acc / per) / 32768.0, 0.01))
				acc = 0.0
		print("%s: %.1fs (load %d ms) peak=%.2f clipped=%d rms per 4 bars=%s" % [info.title, song.length, Time.get_ticks_msec() - t0, peak / 32768.0, clipped, sec_rms])
	get_tree().quit()
