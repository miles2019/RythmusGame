extends Node
## Renders every built-in song, prints loudness and note counts / peak density per difficulty.
func _ready() -> void:
	for s in Songs.LIST:
		var info := Songs.make_info(s)
		var t0 := Time.get_ticks_msec()
		var song := Synth.get_song(info)
		var w: AudioStreamWAV = song.full
		var d := w.data
		var n := d.size() / 2
		var peak := 0
		for i in range(0, n, 7):
			peak = maxi(peak, absi(d.decode_s16(i * 2)))
		var line := "%-16s %5.1fs load %4d ms peak %.2f | " % [info.title, song.length, Time.get_ticks_msec() - t0, peak / 32768.0]
		for diff in 3:
			var chart := Chart.build(info, diff, song)
			var best := 0
			var j := 0
			for i in chart.size():
				while chart[i].time - chart[j].time > 1.0:
					j += 1
				best = maxi(best, i - j + 1)
			var holds := 0
			var doubles := 0
			for c in chart:
				if c.kind == Chart.Kind.HOLD: holds += 1
				if c.kind == Chart.Kind.DOUBLE: doubles += 1
			line += "%s %d notes (peak %d/s, %d holds, %d dbl)  " % [Difficulty.SHORT_NAMES[diff], chart.size(), best, holds, doubles / 2]
		print(line)
	get_tree().quit()
