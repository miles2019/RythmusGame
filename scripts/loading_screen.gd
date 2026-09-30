class_name LoadingScreen
extends Control
## "TUNING THE RIFT": shown while a built-in song is rendered/loaded from cache.
## Animated equalizer bars so the wait never looks frozen; emits `finished` when ready.

signal finished

var info: Dictionary = {}
var _t := 0.0
var _label: Label
var _eq: Control
var _emitted := false


func setup(song_info: Dictionary) -> void:
	info = song_info


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ComicBG.new()
	add_child(bg)
	_eq = Control.new()
	_eq.position = Vector2(440, 330)
	_eq.size = Vector2(400, 120)
	_eq.draw.connect(_draw_eq)
	add_child(_eq)
	var title := UIKit.label("TUNING THE RIFT", 72, UIKit.PAPER, 12)
	title.position = Vector2(140, 170)
	title.size = Vector2(1000, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.rotation = -0.03
	add_child(title)
	_label = UIKit.label(str(info.get("title", "")), 36, UIKit.YELLOW, 8)
	_label.position = Vector2(140, 480)
	_label.size = Vector2(1000, 60)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	if not info.get("custom", false):
		Synth.prewarm(info)


func _process(delta: float) -> void:
	_t += delta
	_eq.queue_redraw()
	if _emitted:
		return
	var is_ok: bool = info.get("custom", false) or Synth.is_ready(info)
	if is_ok and _t > 0.7: # short minimum so the screen does not flash by
		_emitted = true
		finished.emit()


func _draw_eq() -> void:
	for i in 16:
		var h := 14.0 + (sin(_t * 7.0 + i * 0.8) * 0.5 + 0.5) * 90.0 * (0.4 + 0.6 * fposmod(sin(i * 12.9) * 43.0, 1.0))
		var x := i * 25.0
		var col := UIKit.HOT if i % 2 == 0 else UIKit.CYAN
		_eq.draw_rect(Rect2(x - 3, 116.0 - h - 3, 22, h + 6), UIKit.INK)
		_eq.draw_rect(Rect2(x, 116.0 - h, 16, h), col)
