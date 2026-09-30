class_name ImportScreen
extends Control
## Upload your own music: pick a file -> the game finds tempo + first beat -> you can
## fine-tune BPM/offset while listening to a metronome over the track -> save.
## Saved songs show up in CLASSIC / REPLAY with a chart built from the track's real beats.

signal saved(info: Dictionary)
signal back_pressed

enum Step { PICK, ANALYZE, TUNE }

var _step := Step.PICK
var _bg: ComicBG
var _dialog: FileDialog
var _box: Control            # container swapped per step
var _analyzer: CustomSongs
var _info: Dictionary = {}
var _stream: AudioStream
var _stored_path := ""
var _title_edit: LineEdit
var _bpm_label: Label
var _off_label: Label
var _status: Label
var _preview: AudioStreamPlayer
var _preview_btn: Button
var _last_beat := -999
var _flash := 0.0
var _eq: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ComicBG.new()
	_bg.accent = UIKit.LIME
	_bg.accent2 = UIKit.HOT
	add_child(_bg)
	var title := UIKit.label("UPLOAD MUSIC", 64, UIKit.PAPER, 12)
	title.position = Vector2(50, 18)
	title.size = Vector2(800, 80)
	title.rotation = -0.02
	add_child(title)
	_box = Control.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	_preview = AudioStreamPlayer.new()
	_preview.bus = Settings.BUS_MUSIC
	add_child(_preview)
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Choose a song"
	_dialog.filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; Audio files"])
	_dialog.file_selected.connect(_on_file)
	_dialog.size = Vector2i(900, 600)
	add_child(_dialog)
	_show_pick()


func _clear_box() -> void:
	for c in _box.get_children():
		c.queue_free()
	_preview.stop()


func _add(ctrl: Control, pos: Vector2) -> Control:
	ctrl.position = pos
	_box.add_child(ctrl)
	return ctrl


func _text(t: String, size: int, pos: Vector2, width: float, color := UIKit.PAPER) -> Label:
	var l := UIKit.label(t, size, color, 7)
	l.size = Vector2(width, size * 1.5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(l, pos)
	return l


# ------------------------------------------------------------ step 1: pick

func _show_pick() -> void:
	_step = Step.PICK
	_clear_box()
	_text("1. Pick an mp3, ogg or wav file.\n2. The game listens and finds the beat.\n3. Check the metronome, fine-tune, save.\n\nThen play it under CLASSIC / REPLAY.", 28, Vector2(60, 140), 760)
	var pick := UIKit.button("CHOOSE FILE...", UIKit.LIME, 34, -0.02)
	pick.custom_minimum_size = Vector2(380, 80)
	pick.pressed.connect(func(): _dialog.popup_centered())
	_add(pick, Vector2(60, 400))
	_status = _text("", 24, Vector2(60, 500), 900, UIKit.AMBER)
	var back := UIKit.button("BACK", UIKit.HOT, 28, 0.02)
	back.custom_minimum_size = Vector2(200, 56)
	back.pressed.connect(func(): back_pressed.emit())
	_add(back, Vector2(1040, 600))
	pick.grab_focus.call_deferred()


func _on_file(path: String) -> void:
	_stored_path = CustomSongs.store_file(path)
	if _stored_path == "":
		_status.text = "That file could not be read (use mp3, ogg or wav)."
		return
	_stream = CustomSongs.load_stream({"file": _stored_path})
	if _stream == null:
		_status.text = "This audio file could not be decoded."
		return
	_show_analysis(path.get_file().get_basename())


# ------------------------------------------------------------ step 2: analyze

func _show_analysis(title_guess: String) -> void:
	_step = Step.ANALYZE
	_clear_box()
	_text("LISTENING TO YOUR TRACK...", 48, Vector2(60, 200), 1100, UIKit.YELLOW)
	_status = _text("finding the tempo", 26, Vector2(60, 520), 900)
	_eq = Control.new()
	_eq.position = Vector2(60, 300)
	_eq.size = Vector2(700, 160)
	_eq.draw.connect(_draw_eq)
	_box.add_child(_eq)
	_analyzer = CustomSongs.new()
	_analyzer.start_analysis(_stream, title_guess, _stored_path, _on_analyzed)


func _draw_eq() -> void:
	for i in 28:
		var h := 10.0 + (sin(_t * 8.0 + i * 0.7) * 0.5 + 0.5) * 120.0 * (0.3 + 0.7 * fposmod(sin(i * 12.9) * 43.0, 1.0))
		var col := UIKit.LIME if i % 2 == 0 else UIKit.HOT
		_eq.draw_rect(Rect2(i * 25.0 - 3, 146.0 - h - 3, 22, h + 6), UIKit.INK)
		_eq.draw_rect(Rect2(i * 25.0, 146.0 - h, 16, h), col)
	var f: float = _analyzer.progress if _analyzer else 0.0
	_eq.draw_rect(Rect2(-4, 150, 708, 18), UIKit.INK)
	_eq.draw_rect(Rect2(0, 154, 700.0 * f, 10), UIKit.YELLOW)


func _on_analyzed(info: Dictionary) -> void:
	_analyzer.finish()
	if info.is_empty():
		_show_pick()
		_status.text = "Could not analyse this file (too short or unreadable)."
		return
	_info = info
	_show_tune()


# ------------------------------------------------------------ step 3: tune

func _show_tune() -> void:
	_step = Step.TUNE
	_clear_box()
	_text("TITLE", 22, Vector2(60, 120), 200, UIKit.CYAN)
	_title_edit = LineEdit.new()
	_title_edit.text = _info.title
	_title_edit.custom_minimum_size = Vector2(620, 48)
	_title_edit.add_theme_font_size_override("font_size", 28)
	_title_edit.max_length = 28
	_add(_title_edit, Vector2(60, 150))

	_text("TEMPO", 22, Vector2(60, 230), 200, UIKit.CYAN)
	_bpm_label = _text("", 44, Vector2(60, 256), 300, UIKit.YELLOW)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_add(row, Vector2(360, 262))
	for d in [["/2", 0.5], ["-1", -1.0], ["-.1", -0.1], ["+.1", 0.1], ["+1", 1.0], ["x2", 2.0]]:
		var b := UIKit.button(d[0], UIKit.CYAN, 22)
		b.custom_minimum_size = Vector2(72, 48)
		b.pressed.connect(_tweak_bpm.bind(d[0], d[1]))
		row.add_child(b)

	_text("FIRST BEAT", 22, Vector2(60, 340), 300, UIKit.CYAN)
	_off_label = _text("", 40, Vector2(60, 366), 300, UIKit.YELLOW)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_add(row2, Vector2(360, 372))
	for d in [["-20", -20.0], ["-5", -5.0], ["+5", 5.0], ["+20", 20.0]]:
		var b := UIKit.button(d[0] + "ms", UIKit.LIME, 22)
		b.custom_minimum_size = Vector2(104, 48)
		b.pressed.connect(_tweak_offset.bind(d[1]))
		row2.add_child(b)

	_status = _text("Press PREVIEW: you should hear the ticks exactly on the kick drum.", 22, Vector2(60, 450), 1000, UIKit.PAPER)
	_preview_btn = UIKit.button("PREVIEW (tick on beats)", UIKit.AMBER, 26)
	_preview_btn.custom_minimum_size = Vector2(380, 62)
	_preview_btn.pressed.connect(_toggle_preview)
	_add(_preview_btn, Vector2(60, 520))
	var jump := UIKit.button("+30s", UIKit.AMBER, 24)
	jump.custom_minimum_size = Vector2(120, 62)
	jump.pressed.connect(func(): _seek(30.0))
	_add(jump, Vector2(460, 520))
	var save := UIKit.button("SAVE SONG", UIKit.LIME, 30, -0.02)
	save.custom_minimum_size = Vector2(300, 70)
	save.pressed.connect(_save)
	_add(save, Vector2(700, 514))
	var back := UIKit.button("CANCEL", UIKit.HOT, 26, 0.02)
	back.custom_minimum_size = Vector2(200, 56)
	back.pressed.connect(func():
		_preview.stop()
		back_pressed.emit())
	_add(back, Vector2(1040, 600))
	_refresh_labels()
	_preview_btn.grab_focus.call_deferred()


func _refresh_labels() -> void:
	_bpm_label.text = "%.2f BPM" % _info.bpm
	_off_label.text = "%d ms" % int(round(_info.offset * 1000.0))


func _regrid(bpm: float, offset: float) -> void:
	_info = CustomSongs.make_info(_info._data, _title_edit.text, _info.file, clampf(bpm, 50.0, 220.0), offset)
	_refresh_labels()
	_last_beat = -999


func _tweak_bpm(label: String, amount: float) -> void:
	var bpm: float = _info.bpm
	if label == "/2" or label == "x2":
		bpm *= amount
	else:
		bpm += amount
	_regrid(bpm, _info.offset)


func _tweak_offset(ms: float) -> void:
	_regrid(_info.bpm, _info.offset + ms / 1000.0)


func _toggle_preview() -> void:
	if _preview.playing:
		_preview.stop()
		_preview_btn.text = "PREVIEW (tick on beats)"
		return
	_preview.stream = _stream
	_preview.play()
	_last_beat = -999
	_preview_btn.text = "STOP"


func _seek(seconds: float) -> void:
	if not _preview.playing:
		_toggle_preview()
	_preview.seek(minf(_preview.get_playback_position() + seconds, _info.duration - 5.0))
	_last_beat = -999


func _save() -> void:
	_preview.stop()
	var info := CustomSongs.make_info(_info._data, _title_edit.text.strip_edges() if _title_edit.text.strip_edges() != "" else "MY SONG", _info.file, _info.bpm, _info.offset)
	Progress.add_custom(info)
	GameFeel.play_sfx("record")
	saved.emit(info)


func _process(delta: float) -> void:
	_t += delta
	_bg.pulse = maxf(_bg.pulse - delta, 0.0)
	if _step == Step.ANALYZE and _eq:
		_eq.queue_redraw()
		_status.text = "finding the tempo... %d%%" % int((_analyzer.progress if _analyzer else 0.0) * 100.0)
	if _step == Step.TUNE and _preview.playing:
		var pos := _preview.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		var b := floori((pos - _info.offset) / (60.0 / _info.bpm))
		if b != _last_beat and b >= 0:
			_last_beat = b
			GameFeel.play_sfx("tick", Settings.BUS_UI, 1.6 if b % 4 == 0 else 1.0, -2.0)
			_bg.beat()
			GameFeel.pop(_bpm_label, 0.15, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step != Step.ANALYZE:
		_preview.stop()
		back_pressed.emit()
		get_viewport().set_input_as_handled()
