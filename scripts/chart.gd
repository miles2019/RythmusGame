class_name Chart
extends RefCounted
## Note chart generation for built-in songs (template per section + style) and for uploaded
## songs (from the analysed onset strengths). Both respect the chosen difficulty.
## PLACEHOLDER: a hand-authored chart would simply return the same dictionary format.

enum Kind { NORMAL, HOLD, DOUBLE }

## Verse steps (eighth-note positions 0..7) per style: gives each song its own rhythm feel.
const VERSE_STEPS := {
	"funk": [0, 3, 4, 6, 7],
	"house": [0, 2, 4, 6],
	"punk": [0, 1, 2, 4, 5, 6],
	"dnb": [0, 2, 3, 4, 6, 7],
}


static func section_index(bar: int) -> int:
	var idx := 0
	for i in Songs.SECTION_BARS.size():
		if bar >= Songs.SECTION_BARS[i]:
			idx = i
	return idx


## Per-stem loudness (0..1.2) for a bar of a built-in song. Clear dynamics between sections:
## quiet verse, growing build-up, loud drop.
static func stem_gain(stem: String, bar: int) -> float:
	var sec := section_index(bar)
	match stem:
		"pad":
			return [1.0, 0.9, 0.8, 0.5, 0.7, 1.0][sec]
		"drums":
			if bar < 2:
				return 0.0
			if bar < 4:
				return 0.5
			return [0.0, 0.8, 0.95, 1.1, 0.95, 0.5][sec]
		"bass":
			return [0.0, 0.75, 0.9, 1.15, 0.95, 0.5][sec]
		"lead":
			return [0.0, 0.0, 0.5, 1.05, 0.8, 0.3][sec]
	return 1.0


## Returns notes sorted by time: {time, lane, dur, kind, pair} (pair = partner index or -1).
## Section threshold offsets for event charts: quiet intro/verse, dense drop.
const SEC_OFF := [0.45, 0.22, 0.06, -0.05, 0.0, 0.3]
const EV_BASE := [0.5, 0.34, 0.2]
const EV_GAP := [0.20, 0.13, 0.095]   ## minimum seconds between two notes


## Entry point. Built-in songs are charted from the events the synth recorded while rendering
## (kick, snare, bass, melody ...), so the notes follow the music. Falls back to a template
## when no events are available; uploaded songs use their analysed onsets.
static func build(info: Dictionary, diff: int, song := {}) -> Array[Dictionary]:
	if info.get("custom", false):
		return build_custom(info, diff)
	if song.has("onsets"):
		return _build_from_events(info, diff, song)
	return _build_template(info, diff)


static func _build_from_events(info: Dictionary, diff: int, song: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info.get("seed", 42)) * 10 + diff
	var spb := 60.0 / float(info.bpm)
	var onsets: PackedByteArray = song.onsets
	var insts: PackedByteArray = song.inst
	var lanes_h: PackedByteArray = song.lanes
	var lens: PackedByteArray = song.lens
	var notes: Array[Dictionary] = []
	var busy := [0.0, 0.0, 0.0, 0.0]
	var prev := 1
	var last_t := -9.0
	var hold_until := 0.0
	var bars: int = info.bars
	for i in onsets.size():
		var bar := i / 16
		var step := i % 16
		if bar < 2 or bar >= bars - 2 or onsets[i] == 0:
			continue
		var s := float(onsets[i]) / 100.0
		var sec := section_index(bar)
		var inst: int = insts[i]
		var thr: float = EV_BASE[diff] + SEC_OFF[sec] * [1.0, 1.0, 0.6][diff] - (int(info.get("stars", 2)) - 2) * 0.035
		if s < thr:
			continue
		# which grid positions may carry a note
		var on_quarter := step % 4 == 0
		var on_eighth := step % 2 == 0
		match diff:
			Difficulty.EASY:
				if not (on_quarter or (on_eighth and s >= 0.85 and sec >= 3)):
					continue
			Difficulty.NORMAL:
				if not (on_eighth or (s >= 0.75 and sec >= 1)):
					continue
		var t := i * spb * 0.25
		if t - last_t < EV_GAP[diff]:
			continue
		if diff == Difficulty.EASY and t < hold_until:
			continue
		var hint: int = lanes_h[i]
		var lane := -1
		if hint != 255 and busy[hint] <= t + 0.001 and rng.randf() < [0.45, 0.75, 0.8][diff]:
			lane = hint
		if lane < 0:
			lane = _pick_lane(rng, prev, busy, t, -1)
		if lane < 0:
			continue
		# sustained bass / melody notes become holds
		var len_steps: int = lens[i]
		var kind := Kind.NORMAL
		var dur := 0.0
		if (inst == Synth.I_BASS or inst == Synth.I_HOOK) and len_steps >= (6 if diff == Difficulty.EASY else 3) \
				and step % 2 == 0 and s >= 0.6:
			kind = Kind.HOLD
			dur = minf(len_steps * 0.25 * spb * 0.9, 2.0 * spb)
		# short bass holds give every song some sustain gameplay
		if kind == Kind.NORMAL and inst == Synth.I_BASS and len_steps >= 2 and step % 8 == 0 and sec >= 2 \
				and diff >= Difficulty.NORMAL and s >= 0.4 and rng.randf() < 0.5:
			kind = Kind.HOLD
			dur = spb * 0.9
		# doubles on big moments (hook on the beat, crash), more of them on harder settings
		var want_double := diff >= Difficulty.NORMAL and step % 4 == 0 and sec >= 2 and kind == Kind.NORMAL \
				and ((inst == Synth.I_HOOK and s >= 0.8) or (step == 0 and bar % 4 == 0 and s >= 0.75)
				or (diff == Difficulty.HARD and inst == Synth.I_KICK and step % 8 == 0 and sec >= 3))
		if want_double:
			var lane2 := _pick_lane(rng, lane, busy, t, lane)
			if lane2 >= 0:
				var i0 := notes.size()
				notes.append({"time": t, "lane": lane, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0 + 1})
				notes.append({"time": t, "lane": lane2, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0})
				busy[lane] = t + spb * 0.3
				busy[lane2] = t + spb * 0.3
				prev = lane
				last_t = t
				continue
		notes.append({"time": t, "lane": lane, "dur": dur, "kind": kind, "pair": -1})
		busy[lane] = t + dur + spb * 0.25
		if dur > 0.0:
			hold_until = t + dur
		prev = lane
		last_t = t
		# hard mode: a sixteenth "echo" note right after strong hits in the loud sections
		if diff == Difficulty.HARD and kind == Kind.NORMAL and sec >= 3 and s >= 0.85 and rng.randf() < 0.4:
			var t2 := t + spb * 0.25
			var l2 := _pick_lane(rng, lane, busy, t2, -1)
			if l2 >= 0 and i + 4 < onsets.size() - 32:
				notes.append({"time": t2, "lane": l2, "dur": 0.0, "kind": Kind.NORMAL, "pair": -1})
				busy[l2] = t2 + spb * 0.2
				last_t = t2
				prev = l2
	return notes


static func _build_template(info: Dictionary, diff: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(info.get("seed", 42)) * 10 + diff
	var spb := 60.0 / float(info.bpm)
	var notes: Array[Dictionary] = []
	var busy := [0.0, 0.0, 0.0, 0.0] # per lane: time until which it is occupied
	var prev := 1
	var verse_steps: Array = VERSE_STEPS.get(info.style, [0, 2, 4, 6])
	var allow_odd := diff >= Difficulty.NORMAL
	var allow_double := diff >= Difficulty.NORMAL

	for bar in int(info.bars) - 2:
		var sec := section_index(bar)
		for step in 8: # eighth notes inside the bar
			var t := (bar * 4.0 + step * 0.5) * spb
			var on_beat := step % 2 == 0
			var kind := -1
			var dur := 0.0
			match sec:
				0: # intro: two gentle taps to teach the lanes
					if bar >= 2 and (step == 0 or step == 4):
						kind = Kind.NORMAL
				1: # verse: song-specific rhythm
					if step in verse_steps:
						kind = Kind.NORMAL
					if bar % 4 == 3 and step == 7:
						kind = Kind.NORMAL
				2: # build-up: quarters, eighth pairs late in the bar, holds on even bars
					if step == 0 and bar % 2 == 0 and bar < 19:
						kind = Kind.HOLD
						dur = 1.5 * spb
					elif on_beat or step >= 5:
						kind = Kind.NORMAL
					if step >= 1 and step <= 2 and bar % 2 == 0 and bar < 19:
						kind = -1 # the hold occupies this space
					if bar == 19 and step >= 6:
						kind = -1 # breathing gap before the drop
				3: # drop: eighth streams, doubles on beats 1 and 3, holds in bars 22 & 26
					if step == 0 or step == 4:
						kind = Kind.DOUBLE
					elif (bar == 22 or bar == 26) and step == 2:
						kind = Kind.HOLD
						dur = 1.5 * spb
					elif (bar == 22 or bar == 26) and step == 3:
						kind = -1
					else:
						kind = Kind.NORMAL
				4: # final: mixed density
					if step == 0 and bar % 2 == 0:
						kind = Kind.DOUBLE
					elif step == 4 and bar % 4 == 1:
						kind = Kind.HOLD
						dur = 1.5 * spb
					elif on_beat or step >= 6:
						kind = Kind.NORMAL
					if bar % 4 == 1 and step >= 5 and step <= 6:
						kind = -1
				5: # outro: fade out with sparse quarters
					if step == 0 or (step == 4 and bar < 38):
						kind = Kind.NORMAL
			if kind < 0:
				continue
			# difficulty filters
			if not allow_odd and not on_beat:
				continue
			if diff == Difficulty.EASY and sec == 3 and step % 4 != 0 and step != 2 and step != 6:
				continue
			if kind == Kind.DOUBLE and not allow_double:
				kind = Kind.NORMAL
			if kind == Kind.HOLD and diff == Difficulty.EASY and bar % 4 != 0:
				kind = Kind.NORMAL
				dur = 0.0
			var lane := _pick_lane(rng, prev, busy, t, -1)
			if lane < 0:
				continue
			if kind == Kind.DOUBLE:
				var lane2 := _pick_lane(rng, prev, busy, t, lane)
				if lane2 < 0:
					kind = Kind.NORMAL
				else:
					var i0 := notes.size()
					notes.append({"time": t, "lane": lane, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0 + 1})
					notes.append({"time": t, "lane": lane2, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0})
					busy[lane] = t + spb * 0.4
					busy[lane2] = t + spb * 0.4
					prev = lane
					continue
			notes.append({"time": t, "lane": lane, "dur": dur, "kind": kind, "pair": -1})
			busy[lane] = t + maxf(dur, 0.0) + spb * 0.4
			prev = lane
			# hard mode: sixteenth "echo" note right after strong eighths in the loud sections
			if diff == Difficulty.HARD and (sec == 3 or sec == 4) and kind == Kind.NORMAL \
					and not on_beat and rng.randf() < 0.45:
				var t2 := t + spb * 0.25
				var l2 := _pick_lane(rng, prev, busy, t2, -1)
				if l2 >= 0:
					notes.append({"time": t2, "lane": l2, "dur": 0.0, "kind": Kind.NORMAL, "pair": -1})
					busy[l2] = t2 + spb * 0.3
					prev = l2
	return notes


## Uploaded songs: notes come from the analysed onset strengths (one value per sixteenth slot).
static func build_custom(info: Dictionary, diff: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(info.id)) + diff
	var spb := 60.0 / float(info.bpm)
	var offset: float = info.offset
	var onsets: Array = info.onsets
	var thresholds := [0.5, 0.36, 0.26]
	var grid := [4, 2, 1]        # slot multiple that may carry a note (4 = quarters only)
	var min_gap := [3, 2, 1]     # slots between any two notes
	var notes: Array[Dictionary] = []
	var busy := [0.0, 0.0, 0.0, 0.0]
	var prev := 1
	var last_slot := -99
	var i := 0
	while i < onsets.size():
		var s := float(onsets[i]) / 100.0
		var t := offset + i * spb * 0.25
		if i % grid[diff] != 0 or s < thresholds[diff] or i - last_slot < min_gap[diff] or t < offset + spb * 2.0:
			i += 1
			continue
		var lane := _pick_lane(rng, prev, busy, t, -1)
		if lane < 0:
			i += 1
			continue
		var kind := Kind.NORMAL
		var dur := 0.0
		# a loud onset followed by silence reads as a sustained note -> hold
		if diff >= Difficulty.NORMAL and s > 0.7 and i % 4 == 0:
			var quiet := true
			for k in range(1, 6):
				if i + k < onsets.size() and float(onsets[i + k]) > 30.0:
					quiet = false
					break
			if quiet:
				kind = Kind.HOLD
				dur = 1.5 * spb
		if diff >= Difficulty.NORMAL and kind == Kind.NORMAL and s > 0.92 and i % 8 == 0:
			var lane2 := _pick_lane(rng, lane, busy, t, lane)
			if lane2 >= 0:
				var i0 := notes.size()
				notes.append({"time": t, "lane": lane, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0 + 1})
				notes.append({"time": t, "lane": lane2, "dur": 0.0, "kind": Kind.DOUBLE, "pair": i0})
				busy[lane] = t + spb * 0.4
				busy[lane2] = t + spb * 0.4
				prev = lane
				last_slot = i
				i += 1
				continue
		notes.append({"time": t, "lane": lane, "dur": dur, "kind": kind, "pair": -1})
		busy[lane] = t + dur + spb * 0.4
		prev = lane
		last_slot = i
		i += 1
	return notes


static func _pick_lane(rng: RandomNumberGenerator, prev: int, busy: Array, t: float, avoid: int) -> int:
	var options: Array[int] = []
	for l in 4:
		if l != avoid and busy[l] <= t + 0.001:
			options.append(l)
	if options.is_empty():
		return -1
	# Prefer stepping to a neighbouring lane (readable flow), else anything free.
	var near: Array[int] = []
	for l in options:
		if absi(l - prev) == 1:
			near.append(l)
	if not near.is_empty() and rng.randf() < 0.6:
		return near[rng.randi() % near.size()]
	return options[rng.randi() % options.size()]
