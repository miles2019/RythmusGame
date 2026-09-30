class_name BeatClock
extends Node
## Single source of truth for song time.
##
## The audio hardware clock is the master; between mix chunks we extrapolate with the
## frame delta and gently steer towards the audio position so frame hitches never
## make notes jump. If the audio position stalls (dummy driver, device loss) we fall
## back to pure delta time instead of freezing the game.

signal song_started
signal song_finished
signal beat_reached(beat: int)
signal bar_reached(bar: int)

@export var bpm := 128.0
@export var beats_per_bar := 4
@export var lead_in_beats := 4.0     ## silent count-in before the music starts
@export var song_bars := 40
var first_beat := 0.0          ## song time of beat 0 (uploaded tracks rarely start exactly on it)
var length_override := 0.0     ## > 0: real track length in seconds
@export var steer_strength := 0.15   ## how fast we chase the audio clock (0..1 per frame)
@export var snap_threshold := 0.10   ## larger error than this (seconds) -> hard snap

var latency := 0.0        ## seconds, from Settings; shifts notes AND beat visuals together
var running := false
var _t := -1.0            ## raw song time (audio-aligned)
var _stamp_us := 0
var _player: AudioStreamPlayer
var _loop_len := 1.0
var _loops := 0
var _last_raw := 0.0
var _stall := 0.0
var _audio_started := false
var _last_beat := -1
var _last_bar := -1
var _finished := false


func seconds_per_beat() -> float:
	return 60.0 / bpm


func song_length() -> float:
	return length_override if length_override > 0.0 else song_bars * beats_per_bar * seconds_per_beat()


## Reference player must be the one that loops every `loop_len` seconds.
func start(reference_player: AudioStreamPlayer, loop_len: float) -> void:
	_player = reference_player
	_loop_len = loop_len
	_loops = 0
	_last_raw = 0.0
	_stall = 0.0
	_audio_started = false
	_finished = false
	_last_beat = -1
	_last_bar = -1
	latency = Settings.latency_ms / 1000.0
	_t = -lead_in_beats * seconds_per_beat()
	_stamp_us = Time.get_ticks_usec()
	running = true


func stop() -> void:
	running = false
	_player = null


## Current song time in seconds. Extrapolated from the last frame so an input event
## (which arrives *before* _process in the same frame) is not judged a frame late.
func time() -> float:
	if not running:
		return _t - latency
	var extra := 0.0
	if not get_tree().paused:
		extra = clampf((Time.get_ticks_usec() - _stamp_us) / 1_000_000.0, 0.0, 0.05)
	return _t + extra - latency


func beat_position() -> float:
	return (time() - first_beat) / seconds_per_beat()


## 0..1 position inside the current beat (for pulses).
func beat_phase() -> float:
	return fposmod(beat_position(), 1.0)


func _process(delta: float) -> void:
	if not running:
		return
	_t += delta
	if not _audio_started and _t >= 0.0:
		_audio_started = true
		if _player:
			_player.play()
		song_started.emit()
	if _audio_started and _player and _player.playing:
		var raw := _player.get_playback_position()
		if raw < _last_raw - _loop_len * 0.5:
			_loops += 1
		_stall = _stall + delta if is_equal_approx(raw, _last_raw) else 0.0
		_last_raw = raw
		if _stall < 0.25:
			var audio_t := _loops * _loop_len + raw \
					+ AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
			var err := audio_t - _t
			if absf(err) > snap_threshold:
				_t = audio_t
			else:
				_t += err * steer_strength
	_stamp_us = Time.get_ticks_usec()
	_emit_beats()
	if not _finished and time() >= song_length():
		_finished = true
		song_finished.emit()


func _emit_beats() -> void:
	var beat := floori((time() - first_beat) / seconds_per_beat())
	while _last_beat < beat:
		_last_beat += 1
		if _last_beat < 0:
			continue
		beat_reached.emit(_last_beat)
		var bar := _last_beat / beats_per_bar
		if _last_beat % beats_per_bar == 0 and bar != _last_bar:
			_last_bar = bar
			bar_reached.emit(bar)
