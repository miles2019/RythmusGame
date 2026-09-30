class_name Synth
extends RefCounted
## Procedural audio so the game needs zero asset files.
## PLACEHOLDER AUDIO: songs and sounds here can be swapped for real recordings; uploaded
## songs (CustomSongs) already bypass this class completely.
##
## Songs are rendered once per id on a worker thread and cached on disk (user://cache),
## so the second start of a song is instant.

const SR := 22050
const CACHE_VERSION := 4
const STEMS := ["drums", "bass", "lead", "pad"]

static var _songs: Dictionary = {}     # id -> {"full": AudioStreamWAV, "length": float}
static var _threads: Dictionary = {}   # id -> Thread
static var _sfx: Dictionary = {}
static var _mutex := Mutex.new()


# ---------------------------------------------------------------- public song API

## Starts rendering (or loading from the disk cache) on a worker thread.
static func prewarm(info: Dictionary) -> void:
	var id: String = info.id
	if _songs.has(id) or _threads.has(id):
		return
	var t := Thread.new()
	_threads[id] = t
	t.start(_load_or_render.bind(info))


static func is_ready(info: Dictionary) -> bool:
	var id: String = info.id
	if _songs.has(id):
		return true
	return not _threads.has(id) or not (_threads[id] as Thread).is_alive()


## Blocks only if the worker is still busy.
static func get_song(info: Dictionary) -> Dictionary:
	var id: String = info.id
	if _songs.has(id):
		return _songs[id]
	if not _threads.has(id):
		_songs[id] = _load_or_render(info)
		return _songs[id]
	var res: Dictionary = (_threads[id] as Thread).wait_to_finish()
	_threads.erase(id)
	_songs[id] = res
	return res


static func _load_or_render(info: Dictionary) -> Dictionary:
	var path := "user://cache/%s_v%d.bin" % [info.id, CACHE_VERSION]
	var cached := _read_cache(path)
	if not cached.is_empty():
		return cached
	var res := _render_song(info)
	_write_cache(path, res)
	return res


static func _write_cache(path: String, res: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://cache")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var w: AudioStreamWAV = res.full
	f.store_double(res.length)
	f.store_32(w.data.size())
	f.store_buffer(w.data)


static func _read_cache(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var length := f.get_double()
	var n := f.get_32()
	var data := f.get_buffer(n)
	if data.size() != n or n < 1000:
		return {}
	return {"full": _wav_from_bytes(data, false), "length": length}


# ---------------------------------------------------------------- song rendering

static func _render_song(info: Dictionary) -> Dictionary:
	var bpm: float = info.bpm
	var style: String = info.style
	var bars: int = info.bars
	var spb := 60.0 / bpm
	var bar_len := int(4.0 * spb * SR)
	var step := bar_len / 16.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info.get("seed", 1))
	var full := PackedFloat32Array()
	full.resize((bars + 1) * bar_len)

	var inst := _instruments(style, rng)
	var root: int = info.root
	var prog: Array = info.prog
	var hook: Array = info.get("hook", [])
	var hook_len := 32 # steps: hooks span 2 bars

	for bar in bars:
		var b0 := bar * bar_len
		var fade := 1.0 if bar < 36 else lerpf(1.0, 0.0, float(bar - 36) / 4.0)
		var gd := Chart.stem_gain("drums", bar) * fade
		var gb := Chart.stem_gain("bass", bar) * fade
		var gl := Chart.stem_gain("lead", bar) * fade
		var gp := Chart.stem_gain("pad", bar) * fade
		var chord_def: Array = prog[bar % 8]
		var chord_root: int = root + int(chord_def[0])
		var ivs: Array = Songs.CHORDS[chord_def[1]]
		var gap_from := 12 if bar == 19 else 99 # one silent beat before the drop

		if gd > 0.0:
			_drums(full, inst, style, bar, b0, step, gd, gap_from)
		if gb > 0.0:
			_bass(full, inst, style, chord_root, ivs, bar, b0, step, gb, gap_from)
		if gl > 0.0:
			_lead(full, inst, style, chord_root, ivs, hook, hook_len, root, bar, b0, step, gl, gap_from, spb)
		if gp > 0.0:
			var pad_chord: Array = []
			for iv in ivs:
				pad_chord.append(chord_root + 24 + iv)
			_mix(full, _pad(pad_chord, 4.0 * spb), b0, 0.5 * gp)

	# transition sfx baked into the song: riser into the drop, impact on it
	_mix(full, _riser_samples(rng), 20 * bar_len - SR, 0.6)
	_mix(full, _impact_samples(rng), 20 * bar_len, 0.8)
	return {"full": _to_wav(full, 0.8, false, true), "length": float(full.size()) / SR}


static func _instruments(style: String, rng: RandomNumberGenerator) -> Dictionary:
	var d := {}
	match style:
		"funk":
			d.kick = _kick(70.0, 48.0, 0.22, 11.0)
			d.snare = _snare(rng, 0.2, 210.0, 15.0)
		"punk":
			d.kick = _kick(120.0, 55.0, 0.25, 10.0)
			d.snare = _snare(rng, 0.24, 180.0, 13.0)
		"dnb":
			d.kick = _kick(150.0, 50.0, 0.2, 13.0)
			d.snare = _snare(rng, 0.2, 230.0, 14.0)
		_:
			d.kick = _kick(130.0, 42.0, 0.32, 8.0)
			d.snare = _clap(rng)
	d.hat = _hat(rng, 0.045)
	d.open = _hat(rng, 0.16)
	d.crash = _hat(rng, 0.9)
	d.cache = {}
	return d


static func _drums(full: PackedFloat32Array, inst: Dictionary, style: String, bar: int, b0: int,
		step: float, g: float, gap_from: int) -> void:
	var kicks: Array
	var snares: Array
	var ghosts: Array = []
	var hats: Array
	var open_at := -1
	match style:
		"funk":
			kicks = [0, 7, 10]; snares = [4, 12]; ghosts = [2, 9, 15]
			hats = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]; open_at = 14
		"punk":
			kicks = [0, 6, 8, 10]; snares = [4, 12]
			hats = [0, 2, 4, 6, 8, 10, 12, 14]
		"dnb":
			kicks = [0, 10]; snares = [4, 12]; ghosts = [7, 9, 15]
			hats = [0, 2, 4, 6, 8, 10, 12, 14]; open_at = 11
		_:
			kicks = [0, 4, 8, 12]; snares = [4, 12]
			hats = [2, 6, 10, 14, 1, 3, 5, 7, 9, 11, 13, 15]; open_at = 14
	for s in kicks:
		if s < gap_from:
			_mix(full, inst.kick, b0 + int(s * step), 0.9 * g)
	for s in snares:
		if s < gap_from:
			_mix(full, inst.snare, b0 + int(s * step), 0.7 * g)
	for s in ghosts:
		if s < gap_from:
			_mix(full, inst.snare, b0 + int(s * step), 0.18 * g)
	for s in hats:
		if s >= gap_from:
			continue
		var accent := 0.32 if (s % 4 == 2) else 0.14
		if style == "punk":
			accent = 0.3
		_mix(full, inst.open if s == open_at else inst.hat, b0 + int(s * step), accent * g)
	if style == "punk" and bar % 4 == 0 and bar >= 4:
		_mix(full, inst.crash, b0, 0.22 * g)
	if bar % 4 == 3: # fill: snare roll crescendo
		for k in 4:
			var s := 12 + k
			if s < gap_from:
				_mix(full, inst.snare, b0 + int(s * step), (0.3 + k * 0.12) * g)


static func _bass(full: PackedFloat32Array, inst: Dictionary, style: String, chord_root: int, ivs: Array,
		bar: int, b0: int, step: float, g: float, gap_from: int) -> void:
	var low := chord_root
	var notes: Array # [step, semitones, length_steps, gain]
	match style:
		"funk":
			notes = [[0, 0, 2, 1.0], [3, 0, 1, 0.8], [6, 12, 1, 0.7], [7, 0, 1, 0.8], [10, 7, 2, 0.9], [12, 0, 2, 1.0], [15, 10, 1, 0.7]]
		"punk":
			notes = []
			for s in range(0, 16, 2):
				notes.append([s, 0 if s != 14 else 7, 2, 0.9])
		"dnb":
			notes = [[0, 0, 6, 1.0], [6, 0, 4, 0.9], [10, 7, 6, 1.0]]
		_:
			notes = []
			for s in range(0, 16, 2):
				notes.append([s, 12 if s % 8 == 6 else 0, 2, 1.0 if s % 4 == 2 else 0.6])
	for n in notes:
		if n[0] >= gap_from:
			continue
		var key := "b%s_%d_%d_%s" % [style, low + n[1], n[2], str(bar % 2)]
		if not inst.cache.has(key):
			inst.cache[key] = _bass_note(style, _mtof(low + n[1]), n[2] * step / SR)
		_mix(full, inst.cache[key], b0 + int(n[0] * step), 0.75 * g * n[3])


static func _lead(full: PackedFloat32Array, inst: Dictionary, style: String, chord_root: int, ivs: Array,
		hook: Array, hook_len: int, root: int, bar: int, b0: int, step: float, g: float, gap_from: int, spb: float) -> void:
	var sec := Chart.section_index(bar)
	if style == "funk":
		# off-beat chord stabs
		for s in [2, 5, 10, 13]:
			if s >= gap_from:
				continue
			var key := "s%d_%s" % [chord_root, str(ivs)]
			if not inst.cache.has(key):
				inst.cache[key] = _stab(ivs, chord_root + 24, 0.16)
			_mix(full, inst.cache[key], b0 + int(s * step), 0.5 * g)
	elif style == "punk":
		for s in [0, 3, 6, 8, 11, 14]:
			if s >= gap_from:
				continue
			var key := "p%d" % chord_root
			if not inst.cache.has(key):
				inst.cache[key] = _power(chord_root + 12, 0.3)
			_mix(full, inst.cache[key], b0 + int(s * step), 0.42 * g)
	else:
		var arp := [0, -1, 2, 1, -1, 1, 2, -1, 0, -1, 2, 3, 2, -1, 1, 0]
		if style == "dnb":
			arp = [0, 2, 1, 2, 0, 2, 1, 3, 0, 2, 1, 2, 3, 2, 1, 2]
		for s in 16:
			var idx: int = arp[s]
			if idx < 0 or s >= gap_from:
				continue
			var midi: int = (chord_root + 24 + ivs[mini(idx, ivs.size() - 1)]) if idx < 3 else (chord_root + 36)
			var key := "a%d" % midi
			if not inst.cache.has(key):
				inst.cache[key] = _pluck(_mtof(midi))
			var at := b0 + int(s * step)
			_mix(full, inst.cache[key], at, 0.42 * g)
			_mix(full, inst.cache[key], at + int(0.75 * spb * SR), 0.14 * g) # echo tap
	# sung hook (funk/punk) in the louder sections
	if not hook.is_empty() and sec >= 2:
		var local := (bar % 2) * 16
		for h in hook:
			var hs: int = h[0]
			if hs < local or hs >= local + 16:
				continue
			var st := hs - local
			if st >= gap_from:
				continue
			var midi: int = root + 36 + int(h[1])
			var key := "h%d_%d" % [midi, h[2]]
			if not inst.cache.has(key):
				inst.cache[key] = _hook_note(_mtof(midi), h[2] * step / SR, style == "punk")
			_mix(full, inst.cache[key], b0 + int(st * step), 0.45 * g)


static func _mtof(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)


static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var n := dst.size()
	var idx := at
	if idx >= n:
		return
	var count := mini(src.size(), n - idx)
	for i in count:
		dst[idx + i] += src[i] * gain


static func _to_wav(buf: PackedFloat32Array, gain: float, loop := true, soft := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := tanh(buf[i] * gain * 1.1) * 1.0 if soft else clampf(buf[i] * gain, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	return _wav_from_bytes(bytes, loop)


static func _wav_from_bytes(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = bytes.size() / 2
	return w


# ---------------------------------------------------------------- instruments

static func _kick(f_start: float, f_end: float, dur: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * (f_end + f_start * exp(-t * 30.0)) / SR
		out[i] = (sin(ph) * exp(-t * decay) + (0.35 if i < 60 else 0.0) * sin(i * 1.7)) * 1.1
	return out


static func _snare(rng: RandomNumberGenerator, dur: float, tone: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-t * decay) * 0.7 + sin(TAU * tone * t) * exp(-t * 26.0) * 0.5
	return out


static func _clap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.2 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var burst := 1.0 if fmod(t, 0.012) < 0.006 and t < 0.036 else 0.0
		out[i] = rng.randf_range(-1.0, 1.0) * (burst * 0.8 + exp(-t * 18.0) * 0.6)
	return out


static func _hat(rng: RandomNumberGenerator, length: float) -> PackedFloat32Array:
	var n := int(length * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / SR
		var x := rng.randf_range(-1.0, 1.0)
		out[i] = (x - prev) * exp(-t * (3.0 / length)) * 0.6 # differencing = crude high-pass
		prev = x
	return out


static func _bass_note(style: String, freq: float, dur: float) -> PackedFloat32Array:
	var n := int(maxf(dur, 0.08) * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var env := minf(t * 500.0, 1.0) * minf((dur - t) * 60.0 + 0.2, 1.0)
		var s := 0.0
		match style:
			"funk": # plucky: filter closes quickly
				var saw := 2.0 * fposmod(freq * t, 1.0) - 1.0
				lp += (saw - lp) * (0.05 + 0.4 * exp(-t * 18.0))
				s = lp * 1.1 + sin(TAU * freq * t) * 0.4
				env *= exp(-t * 3.0)
			"punk": # clipped saw: cheap distortion
				var saw := 2.0 * fposmod(freq * t, 1.0) - 1.0
				lp += (saw - lp) * 0.3
				s = tanh(lp * 3.5) * 0.7 + sin(TAU * freq * t) * 0.3
				env *= exp(-t * 2.0)
			"dnb": # reese: detuned saws + sub, slow wobble
				var a := 2.0 * fposmod(freq * 0.994 * t, 1.0) - 1.0
				var b := 2.0 * fposmod(freq * 1.006 * t, 1.0) - 1.0
				lp += ((a + b) * 0.5 - lp) * (0.1 + 0.08 * sin(t * 12.0))
				s = lp * 0.9 + sin(TAU * freq * t) * 0.6
			_:
				var saw := 2.0 * fposmod(freq * t, 1.0) - 1.0
				lp += (saw - lp) * 0.16
				s = lp * 0.9 + sin(TAU * freq * t) * 0.6
				env *= exp(-t * 6.0)
		out[i] = s * env
	return out


static func _pluck(freq: float) -> PackedFloat32Array:
	var n := int(0.16 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var sq := 1.0 if fposmod(freq * t, 1.0) < 0.3 else -1.0
		out[i] = (sq * 0.25 + sin(TAU * freq * t) * 0.3) * minf(t * 600.0, 1.0) * exp(-t * 13.0)
	return out


## Short chord stab (funk "guitar"): detuned saws through a closing filter.
static func _stab(ivs: Array, base: int, dur: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for iv in ivs:
		var f := _mtof(base + iv)
		var lp := 0.0
		for i in n:
			var t := float(i) / SR
			var saw := 2.0 * fposmod(f * t, 1.0) - 1.0
			lp += (saw - lp) * (0.08 + 0.35 * exp(-t * 25.0))
			out[i] += lp * minf(t * 800.0, 1.0) * exp(-t * 14.0) * 0.3
	return out


static func _power(midi: int, dur: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var f1 := _mtof(midi)
	var f2 := f1 * 1.4983
	for i in n:
		var t := float(i) / SR
		var s := (2.0 * fposmod(f1 * t, 1.0) - 1.0) + (2.0 * fposmod(f2 * t, 1.0) - 1.0) * 0.8
		out[i] = tanh(s * 2.2) * 0.4 * minf(t * 600.0, 1.0) * exp(-t * 6.0)
	return out


static func _hook_note(freq: float, dur: float, rough: bool) -> PackedFloat32Array:
	var n := int(maxf(dur, 0.08) * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * freq * (1.0 + 0.006 * sin(t * 38.0) * minf(t * 6.0, 1.0)) / SR # vibrato
		var s := sin(ph) + 0.5 * sin(ph * 2.0) + (0.3 * sin(ph * 3.0) if rough else 0.15 * sin(ph * 3.0))
		out[i] = s * 0.3 * minf(t * 300.0, 1.0) * minf((dur - t) * 40.0 + 0.3, 1.0) * exp(-t * 2.0)
	return out


static func _pad(chord: Array, length: float) -> PackedFloat32Array:
	var n := int(length * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for m in chord:
		var f := _mtof(m)
		for i in n:
			var t := float(i) / SR
			var env := minf(t / 0.4, 1.0) * minf((length - t) / 0.4, 1.0)
			out[i] += (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.004 * t)) * env * 0.05
	return out


# ---------------------------------------------------------------- sound effects

## Cached one-shot streams (see _build_sfx for the list).
static func sfx(sfx_name: String) -> AudioStream:
	_mutex.lock()
	if _sfx.is_empty():
		_build_sfx()
	_mutex.unlock()
	return _sfx.get(sfx_name, null)


static func _tone(f0: float, f1: float, dur: float, decay: float, wave := 0, gain := 0.6) -> PackedFloat32Array:
	# wave: 0 sine, 1 square, 2 saw
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		ph += TAU * lerpf(f0, f1, t / dur) / SR
		var s := sin(ph)
		if wave == 1:
			s = 0.5 if sin(ph) > 0.0 else -0.5
		elif wave == 2:
			s = (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.6
		out[i] = s * minf(t * 800.0, 1.0) * exp(-t * decay) * gain
	return out


static func _sum(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var big := a if a.size() >= b.size() else b
	var small := b if a.size() >= b.size() else a
	var out := big.duplicate()
	for i in small.size():
		out[i] += small[i]
	return out


static func _seq(parts: Array, step: float) -> PackedFloat32Array:
	var step_n := int(step * SR)
	var total := 0
	for i in parts.size():
		total = maxi(total, i * step_n + parts[i].size())
	var out := PackedFloat32Array()
	out.resize(total)
	for i in parts.size():
		var p: PackedFloat32Array = parts[i]
		for j in p.size():
			out[i * step_n + j] += p[j]
	return out


static func _noise(rng: RandomNumberGenerator, dur: float, decay: float, gain := 0.6) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / SR * decay) * gain
	return out


static func _impact_samples(rng: RandomNumberGenerator) -> PackedFloat32Array:
	return _sum(_tone(90, 35, 0.6, 5, 0, 1.0), _hat(rng, 0.6))


## Sine sweep + growing noise: the tension before the drop.
static func _riser_samples(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var riser := PackedFloat32Array()
	riser.resize(SR)
	var ph := 0.0
	for i in SR:
		var t := float(i) / SR
		ph += TAU * (200.0 + 1800.0 * t * t) / SR
		riser[i] = (sin(ph) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.15 * t) * t
	return riser


static func _build_sfx() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_sfx["perfect"] = _to_wav(_sum(_sum(_tone(1046, 1046, 0.28, 9, 0, 0.5), _tone(1568, 1568, 0.22, 11, 0, 0.35)),
			_tone(2093, 2093, 0.12, 20, 0, 0.2)), 0.9, false)
	_sfx["great"] = _to_wav(_sum(_tone(784, 784, 0.2, 12, 0, 0.5), _tone(1176, 1176, 0.14, 16, 0, 0.3)), 0.9, false)
	_sfx["good"] = _to_wav(_tone(587, 587, 0.12, 22, 0, 0.55), 0.9, false)
	_sfx["miss"] = _to_wav(_tone(180, 70, 0.2, 10, 2, 0.5), 0.8, false)
	# comic "smack": noise crack + falling thud, played when the player takes damage
	_sfx["smack"] = _to_wav(_sum(_noise(rng, 0.18, 26.0, 0.9), _tone(240, 60, 0.22, 12, 2, 0.7)), 0.9, false)
	_sfx["splat"] = _to_wav(_sum(_noise(rng, 0.25, 14.0, 0.5), _tone(400, 120, 0.2, 14, 0, 0.4)), 0.8, false)
	_sfx["whoosh"] = _to_wav(_noise(rng, 0.3, 7.0, 0.35), 0.8, false)
	_sfx["tick"] = _to_wav(_tone(1400, 1400, 0.03, 90, 0, 0.5), 0.7, false)
	_sfx["ui_move"] = _to_wav(_tone(700, 900, 0.05, 50, 1, 0.4), 0.7, false)
	_sfx["ui_confirm"] = _to_wav(_seq([_tone(660, 660, 0.09, 20, 1, 0.4), _tone(990, 990, 0.16, 14, 1, 0.4)], 0.07), 0.8, false)
	_sfx["ui_back"] = _to_wav(_seq([_tone(660, 660, 0.08, 20, 1, 0.4), _tone(440, 440, 0.14, 16, 1, 0.4)], 0.06), 0.8, false)
	_sfx["record"] = _to_wav(_seq([_tone(523, 523, 0.14, 12), _tone(659, 659, 0.14, 12),
			_tone(784, 784, 0.14, 12), _tone(1046, 1046, 0.3, 8)], 0.06), 0.9, false)
	_sfx["impact"] = _to_wav(_impact_samples(rng), 0.9, false)
	_sfx["riser"] = _to_wav(_riser_samples(rng), 0.9, false)
	_sfx["voice_hey"] = _to_wav(_seq([_tone(500, 720, 0.09, 12, 1, 0.35), _tone(720, 900, 0.1, 14, 1, 0.35)], 0.07), 0.8, false)
	_sfx["voice_ouch"] = _to_wav(_tone(520, 240, 0.18, 10, 1, 0.4), 0.8, false)
	_sfx["voice_win"] = _to_wav(_seq([_tone(600, 600, 0.08, 12, 1, 0.35), _tone(760, 760, 0.08, 12, 1, 0.35),
			_tone(900, 1200, 0.2, 9, 1, 0.35)], 0.08), 0.8, false)
	_sfx["voice_lose"] = _to_wav(_seq([_tone(500, 420, 0.12, 10, 1, 0.35), _tone(380, 200, 0.3, 6, 1, 0.35)], 0.11), 0.8, false)
	# dialogue blips for the story text (pitch-shifted per speaker at play time)
	_sfx["blip"] = _to_wav(_tone(520, 480, 0.05, 40, 1, 0.3), 0.7, false)
