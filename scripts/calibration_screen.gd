class_name CalibrationScreen
extends Control
## Audio sync calibration: a click track plays, you tap on every click, the median offset
## between your taps and the clicks becomes the latency offset (used by BeatClock for all
## songs, so notes line up with what you HEAR on your setup: Bluetooth, USB, HDMI ...).

signal closed
signal applied

const BPM := 120.0
const LOOP_SECONDS := 8.0
const NEEDED := 12

var _clock: BeatClock
var _player: AudioStreamPlayer
var _offsets: Array[float] = []
var _info: Label
var _result: Label
var _apply_btn: Button
var _pulse := 0.0
var _flash := 0.0
var _median_ms := 0.0
var _draw_area: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ComicBG.new()
	bg.accent = UIKit.AMBER
	bg.accent2 = UIKit.CYAN
	add_child(bg)
	var title := UIKit.label("AUDIO SYNC", 64, UIKit.PAPER, 12)
	title.position = Vector2(50, 18)
	title.size = Vector2(800, 80)
	title.rotation = -0.02
	add_child(title)
	_info = UIKit.label("Tap SPACE (or any key / click) exactly ON every click you hear.", 28, UIKit.YELLOW, 7)
	_info.position = Vector2(60, 120)
	_info.size = Vector2(1100, 40)
	add_child(_info)
	_draw_area = Control.new()
	_draw_area.position = Vector2(60, 180)
	_draw_area.size = Vector2(1160, 300)
	_draw_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_area.draw.connect(_draw_viz)
	add_child(_draw_area)
	_result = UIKit.label("", 34, UIKit.PAPER, 8)
	_result.position = Vector2(60, 500)
	_result.size = Vector2(1100, 50)
	add_child(_result)
	var retry := UIKit.button("RESTART", UIKit.CYAN, 26, -0.01)
	retry.custom_minimum_size = Vector2(220, 58)
	retry.pressed.connect(_restart)
	retry.position = Vector2(60, 590)
	retry.focus_mode = Control.FOCUS_NONE # keys are for tapping here
	add_child(retry)
	_apply_btn = UIKit.button("APPLY", UIKit.LIME, 28, 0.01)
	_apply_btn.custom_minimum_size = Vector2(240, 58)
	_apply_btn.pressed.connect(_apply)
	_apply_btn.position = Vector2(320, 590)
	_apply_btn.focus_mode = Control.FOCUS_NONE
	_apply_btn.disabled = true
	add_child(_apply_btn)
	var cancel := UIKit.button("CANCEL (Esc)", UIKit.HOT, 26, 0.02)
	cancel.custom_minimum_size = Vector2(240, 58)
	cancel.pressed.connect(_cancel)
	cancel.position = Vector2(1000, 590)
	cancel.focus_mode = Control.FOCUS_NONE
	add_child(cancel)

	_player = AudioStreamPlayer.new()
	_player.bus = Settings.BUS_MUSIC
	_player.stream = _click_track()
	add_child(_player)
	_clock = BeatClock.new()
	_clock.bpm = BPM
	_clock.lead_in_beats = 4.0
	add_child(_clock)
	_clock.beat_reached.connect(_on_beat)
	_restart()


func _click_track() -> AudioStreamWAV:
	var sr := 22050
	var n := int(LOOP_SECONDS * sr)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var spb := 60.0 / BPM
	for beat in int(LOOP_SECONDS / spb):
		var start := int(beat * spb * sr)
		var accent := 1.0 if beat % 4 == 0 else 0.7
		for i in int(0.05 * sr):
			var t := float(i) / sr
			var v := sin(TAU * (1800.0 if beat % 4 == 0 else 1300.0) * t) * exp(-t * 60.0) * accent
			bytes.encode_s16((start + i) * 2, int(v * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _restart() -> void:
	_offsets.clear()
	_player.stop()
	_clock.start(_player, LOOP_SECONDS)
	_clock.latency = 0.0 # measure the raw offset, no correction applied
	_result.text = "Get ready... (4 beats)"
	_apply_btn.disabled = true


func _on_beat(_b: int) -> void:
	_pulse = 1.0


func _input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel()
			get_viewport().set_input_as_handled()
			return
		tap = true
	elif event is InputEventMouseButton and event.pressed:
		tap = true
	elif event is InputEventJoypadButton and event.pressed:
		tap = true
	if not tap:
		return
	var t := _clock.time() # same clock + extrapolation the game uses
	if t < 1.0:
		return # still in the count-in
	var spb := 60.0 / BPM
	var d := t - roundf(t / spb) * spb
	_offsets.append(d)
	_flash = 1.0
	get_viewport().set_input_as_handled()
	_update_result()


func _update_result() -> void:
	var sorted := _offsets.duplicate()
	sorted.sort()
	_median_ms = sorted[sorted.size() / 2] * 1000.0
	if _offsets.size() < NEEDED:
		_result.text = "%d / %d taps   (current estimate: %+d ms)" % [_offsets.size(), NEEDED, int(round(_median_ms))]
	else:
		_result.text = "Done!  Your offset: %+d ms.  APPLY to use it." % int(round(_median_ms))
		_apply_btn.disabled = false
		GameFeel.play_sfx("record")


func _apply() -> void:
	Settings.latency_ms = clampf(_median_ms, -250.0, 250.0)
	Settings.notify_changed()
	_player.stop()
	applied.emit()
	closed.emit()


func _cancel() -> void:
	_player.stop()
	closed.emit()


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta * 4.0, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_draw_area.queue_redraw()


func _draw_viz() -> void:
	# pulsing circle on every click + a dot per tap on a early/late axis
	var centre := Vector2(180, 150)
	_draw_area.draw_circle(centre, 90.0 + _pulse * 30.0, UIKit.INK)
	_draw_area.draw_circle(centre, 80.0 + _pulse * 28.0, UIKit.YELLOW.lerp(Color.WHITE, _flash))
	var font := UIKit.font()
	_draw_area.draw_string(font, Vector2(480, 40), "EARLY", HORIZONTAL_ALIGNMENT_LEFT, 200, 26, UIKit.CYAN)
	_draw_area.draw_string(font, Vector2(1000, 40), "LATE", HORIZONTAL_ALIGNMENT_RIGHT, 140, 26, UIKit.HOT)
	_draw_area.draw_rect(Rect2(480, 140, 660, 10), UIKit.INK)
	_draw_area.draw_rect(Rect2(808, 120, 4, 50), UIKit.PAPER)
	for d in _offsets:
		var x := 810.0 + clampf(d, -0.25, 0.25) / 0.25 * 330.0
		_draw_area.draw_circle(Vector2(x, 145), 9.0, UIKit.AMBER)
	if not _offsets.is_empty():
		var mx := 810.0 + clampf(_median_ms / 1000.0, -0.25, 0.25) / 0.25 * 330.0
		_draw_area.draw_rect(Rect2(mx - 3, 110, 6, 70), UIKit.LIME)
