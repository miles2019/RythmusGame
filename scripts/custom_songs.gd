class_name CustomSongs
extends RefCounted
## Import of user music: decode -> find tempo + beat offset -> onset strengths per 16th slot.
## The result is a normal "song info" dictionary (plus `file` and `onsets`) that the game
## plays like any built-in song, with the chart generated from the actual beats of the track.
##
## Decoding uses AudioStreamPlayback.mix_audio(), i.e. faster than real time and with no
## third-party decoder; mp3, ogg and wav are supported. Runs on a worker thread.

const SONG_DIR := "user://songs"
const MIX_RATE := 44100.0
const HOP := 512                      # frames per analysis hop (~11.6 ms)
const EXTENSIONS := ["mp3", "ogg", "wav"]

var progress := 0.0                   # 0..1, readable from the UI thread
var _thread: Thread


## Loads a stream from raw bytes by extension. Returns null for unsupported/corrupt data.
static func stream_from_bytes(bytes: PackedByteArray, ext: String) -> AudioStream:
	match ext.to_lower():
		"mp3":
			return AudioStreamMP3.load_from_buffer(bytes)
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			return AudioStreamWAV.load_from_buffer(bytes)
	return null


static func load_stream(info: Dictionary) -> AudioStream:
	var path: String = info.get("file", "")
	if path == "" or not FileAccess.file_exists(path):
		return null
	return stream_from_bytes(FileAccess.get_file_as_bytes(path), path.get_extension())


## Copies the picked file into user://songs so the song keeps working if the original moves.
static func store_file(src_path: String) -> String:
	var ext := src_path.get_extension().to_lower()
	if not EXTENSIONS.has(ext):
		return ""
	var bytes := FileAccess.get_file_as_bytes(src_path)
	if bytes.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(SONG_DIR)
	var id := "%s_%d" % [src_path.get_file().get_basename().validate_filename().left(24), bytes.size()]
	var dst := "%s/%s.%s" % [SONG_DIR, id, ext]
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	return dst


func start_analysis(stream: AudioStream, title: String, file: String, done: Callable) -> void:
	progress = 0.0
	_thread = Thread.new()
	_thread.start(_run.bind(stream, title, file, done))


func _run(stream: AudioStream, title: String, file: String, done: Callable) -> void:
	var info := analyze(stream, title, file)
	done.call_deferred(info)


func finish() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## Decode + tempo detection. The returned info also carries "_data" (onset envelope etc.) so
## the import screen can re-grid after manual BPM/offset tweaks; keys starting with "_" are
## never saved.
func analyze(stream: AudioStream, title: String, file: String) -> Dictionary:
	var length := stream.get_length()
	if length <= 1.0:
		return {}
	var total_frames := int(length * MIX_RATE)
	var hops := total_frames / HOP
	var env := PackedFloat32Array()
	var envd := PackedFloat32Array()
	env.resize(hops)
	envd.resize(hops)
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var chunk := HOP * 16
	var h := 0
	while h < hops:
		var frames := mini(chunk, (hops - h) * HOP)
		var buf := pb.mix_audio(1.0, frames)
		if buf.is_empty():
			break
		var hops_here := buf.size() / HOP
		for k in hops_here:
			var e := 0.0
			var d := 0.0
			var prev := 0.0
			var base := k * HOP
			for i in range(0, HOP, 4): # stride 4 keeps this cheap; tempo does not need every sample
				var v := buf[base + i]
				var m := (v.x + v.y) * 0.5
				e += m * m
				d += (m - prev) * (m - prev)
				prev = m
			if h + k < hops:
				env[h + k] = sqrt(e / 128.0)
				envd[h + k] = sqrt(d / 128.0)
		h += maxi(hops_here, 1)
		progress = 0.7 * float(h) / hops
	# onset function: positive flux of amplitude + high-frequency-ish difference energy
	var onset := PackedFloat32Array()
	onset.resize(hops)
	var peak := 0.0001
	for k in range(1, hops):
		var o := maxf(env[k] - env[k - 1], 0.0) + 0.6 * maxf(envd[k] - envd[k - 1], 0.0)
		onset[k] = o
		peak = maxf(peak, o)
	var sm := PackedFloat32Array()
	sm.resize(hops)
	for k in range(1, hops - 1):
		sm[k] = (onset[k - 1] * 0.25 + onset[k] * 0.5 + onset[k + 1] * 0.25) / peak
	progress = 0.75
	var hop_s := HOP / MIX_RATE
	var coarse := _coarse_bpm(sm, hop_s)
	progress = 0.85
	var fit := _fit_grid(sm, hop_s, coarse)
	progress = 0.95
	var data := {"sm": sm, "env": env, "length": length, "hop_s": hop_s}
	var info := make_info(data, title, file, fit.bpm, fit.offset)
	progress = 1.0
	return info


## Builds the song info for a given tempo grid (re-callable after manual BPM/offset edits).
static func make_info(data: Dictionary, title: String, file: String, bpm: float, offset: float) -> Dictionary:
	var sm: PackedFloat32Array = data.sm
	var env: PackedFloat32Array = data.env
	var length: float = data.length
	var hop_s: float = data.hop_s
	var spb := 60.0 / bpm
	while offset < 0.0:
		offset += spb
	while offset >= spb:
		offset -= spb
	# strength per sixteenth slot
	var slots := maxi(int((length - offset) / (spb * 0.25)), 0)
	var strengths := PackedFloat32Array()
	strengths.resize(slots)
	var hops := sm.size()
	for i in slots:
		var c := int(round((offset + i * spb * 0.25) / hop_s))
		var m := 0.0
		for k in range(maxi(c - 2, 0), mini(c + 3, hops)):
			m = maxf(m, sm[k])
		strengths[i] = m
	var sorted := strengths.duplicate()
	sorted.sort()
	var p95 := maxf(sorted[int(sorted.size() * 0.95)] if sorted.size() > 0 else 1.0, 0.0001)
	var onsets: Array = []
	for i in slots:
		onsets.append(int(clampf(strengths[i] / p95, 0.0, 1.0) * 100.0))
	var bars := int(ceil((length - offset) / (spb * 4.0)))
	var id := "custom_%s" % file.get_file().get_basename()
	var info := {
		"id": id, "custom": true, "title": title.to_upper(), "artist": "YOUR TRACK",
		"bpm": bpm, "offset": offset, "duration": length, "bars": bars, "file": file,
		"onsets": onsets, "style": "custom", "theme": "club",
		"rival": "gum" if bpm < 110.0 else ("kuro" if bpm < 130.0 else ("null" if bpm < 150.0 else "clock")),
		"stars": 2, "seed": 1, "_data": data,
	}
	info["sections"] = _sections(env, hop_s, offset, spb, bars)
	return info


## Builds a section list (8-bar blocks) from loudness so the stage colours follow the song.
static func _sections(env: PackedFloat32Array, hop_s: float, offset: float, spb: float, bars: int) -> Array:
	var accents: Array = Songs.THEMES["club"]
	var out: Array = []
	var block := 8
	var n := int(ceil(float(bars) / block))
	var loud: Array = []
	for b in n:
		var t0 := offset + b * block * 4.0 * spb
		var t1 := t0 + block * 4.0 * spb
		var sum := 0.0
		var cnt := 0
		for k in range(int(t0 / hop_s), mini(int(t1 / hop_s), env.size())):
			sum += env[k]
			cnt += 1
		loud.append(sum / maxf(cnt, 1))
	var sorted: Array = loud.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if sorted.size() > 0 else 0.0
	for b in n:
		var name := "VERSE"
		if b == 0:
			name = "INTRO"
		elif b == n - 1 and n > 2:
			name = "OUTRO"
		elif loud[b] > median * 1.15:
			name = "DROP"
		elif b > 0 and loud[b] > loud[b - 1] * 1.05:
			name = "BUILD-UP"
		out.append({"bar": b * block, "name": name, "accent": accents[b % accents.size()]})
	return out


## Autocorrelation of the onset function, weighted towards musically common tempos.
static func _coarse_bpm(sm: PackedFloat32Array, hop_s: float) -> float:
	var n := mini(sm.size(), int(120.0 / hop_s)) # first two minutes are plenty
	var best_bpm := 120.0
	var best := -1.0
	var bpm := 70.0
	while bpm <= 180.0:
		var lag := 60.0 / bpm / hop_s
		var li := int(round(lag))
		var score := 0.0
		for k in range(li, n):
			# interpolate between neighbouring lags for sub-hop accuracy
			score += sm[k] * sm[k - li]
		var prior := exp(-pow(log(bpm / 125.0), 2.0) / (2.0 * 0.35 * 0.35))
		score = score / float(n) * prior
		if score > best:
			best = score
			best_bpm = bpm
		bpm += 0.5
	return best_bpm


static func _at(sm: PackedFloat32Array, pos: float) -> float:
	var i := int(pos)
	if i < 0 or i >= sm.size() - 1:
		return 0.0
	var f := pos - i
	return sm[i] * (1.0 - f) + sm[i + 1] * f


## Joint search over tempo and first-beat offset: sum the onset function on a beat comb.
static func _fit_grid(sm: PackedFloat32Array, hop_s: float, coarse: float) -> Dictionary:
	var best := {"bpm": coarse, "offset": 0.0, "score": -1.0}
	var length := sm.size() * hop_s
	# stage A: coarse tempo neighbourhood, first ~60 s, 32 offset bins
	var bpm := coarse * 0.97
	while bpm <= coarse * 1.03:
		var spb := 60.0 / bpm
		var beats := int(minf(60.0, length) / spb)
		for ob in 32:
			var off := spb * ob / 32.0
			var score := 0.0
			for k in beats:
				score += _at(sm, (off + k * spb) / hop_s)
			if score > best.score:
				best = {"bpm": bpm, "offset": off, "score": score}
		bpm += 0.1
	# stage B: refine on the whole track (drift shows up over minutes)
	var b2 := {"bpm": best.bpm, "offset": best.offset, "score": -1.0}
	var cand: float = best.bpm - 0.4
	while cand <= best.bpm + 0.4:
		var spb: float = 60.0 / cand
		var beats := int((length - 1.0) / spb)
		for ob in range(-8, 9):
			var off: float = best.offset + ob * hop_s * 0.5
			var score := 0.0
			for k in beats:
				score += _at(sm, (off + k * spb) / hop_s)
			if score > b2.score:
				b2 = {"bpm": cand, "offset": off, "score": score}
		cand += 0.02
	return b2
