class_name OptionsMenu
extends Control
## Options + accessibility + key rebinding. Values apply live; they are saved on close.

signal closed

var _rebind_lane := -1
var _rebind_slot := -1
var _key_buttons: Array = []   # [lane][slot] -> Button
var _hint: Label
var _back: Button
var _sound_labels: Array[Label] = []
var _sound_dialog: FileDialog
var _sound_lane := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var col := UIKit.modal_column(self, 0.85, 800.0)
	var title := UIKit.label("OPTIONS", 46, UIKit.AMBER, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_header(list, "AUDIO")
	_slider(list, "Music", 0.0, 1.0, 0.05, Settings.music_volume, func(v): Settings.music_volume = v; Settings.apply_audio())
	_slider(list, "UI sounds", 0.0, 1.0, 0.05, Settings.ui_volume, func(v): Settings.ui_volume = v; Settings.apply_audio())
	_slider(list, "Hit effects", 0.0, 1.0, 0.05, Settings.hit_volume, func(v): Settings.hit_volume = v; Settings.apply_audio())
	_slider(list, "Voices", 0.0, 1.0, 0.05, Settings.voice_volume, func(v): Settings.voice_volume = v; Settings.apply_audio())

	_header(list, "TIMING")
	_slider(list, "Latency offset (ms)", -200.0, 200.0, 5.0, Settings.latency_ms, func(v): Settings.latency_ms = v)
	var cal := UIKit.button("CALIBRATE AUDIO SYNC...", UIKit.AMBER, 24)
	cal.custom_minimum_size = Vector2(420, 48)
	cal.pressed.connect(_open_calibration)
	list.add_child(cal)
	_slider(list, "Hit window size", 0.7, 1.6, 0.05, Settings.timing_scale, func(v): Settings.timing_scale = v)

	_header(list, "ACCESSIBILITY")
	_slider(list, "Note size", 0.8, 1.4, 0.05, Settings.note_scale, func(v): Settings.note_scale = v)
	_toggle(list, "Screen shake", Settings.screen_shake, func(v): Settings.screen_shake = v)
	_toggle(list, "Reduce background animation", Settings.reduced_background, func(v): Settings.reduced_background = v)
	_toggle(list, "Reduce particles", Settings.reduced_particles, func(v): Settings.reduced_particles = v)
	_toggle(list, "Reduce squash / pop / hit-pause", Settings.reduced_animation, func(v): Settings.reduced_animation = v)
	_toggle(list, "Screen effects (shader) - turn off if the game runs slowly", Settings.post_effects, func(v): Settings.post_effects = v)
	_toggle(list, "Show FPS", Settings.show_fps, func(v): Settings.show_fps = v)
	_toggle(list, "Alternative colours (arrows always stay distinct)", Settings.alt_colors, func(v): Settings.alt_colors = v)

	_header(list, "KEYS  (click a slot, then press a key)")
	for lane in InputProfile.LANES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_l := UIKit.label(InputProfile.LANE_NAMES[lane], 22, Settings.lane_color(lane), 5)
		name_l.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_l)
		var btns := []
		for slot in InputProfile.SLOTS:
			var b := UIKit.button(InputProfile.key_name(Settings.input_profile.keys[lane][slot]), UIKit.CYAN, 22)
			b.custom_minimum_size = Vector2(150, 46)
			b.pressed.connect(_start_rebind.bind(lane, slot))
			row.add_child(b)
			btns.append(b)
		_key_buttons.append(btns)
		list.add_child(row)
	var reset := UIKit.button("Reset keys", UIKit.HOT, 22)
	reset.custom_minimum_size = Vector2(220, 46)
	reset.pressed.connect(func():
		Settings.input_profile.reset_defaults()
		_refresh_keys())
	list.add_child(reset)

	_header(list, "HIT SOUNDS  (your own sample per button, max 3 s)")
	_sound_labels.clear()
	for lane in InputProfile.LANES:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		var sname := UIKit.label(InputProfile.LANE_NAMES[lane], 22, Settings.lane_color(lane), 5)
		sname.custom_minimum_size = Vector2(110, 0)
		srow.add_child(sname)
		var up := UIKit.button("UPLOAD", UIKit.LIME, 20)
		up.custom_minimum_size = Vector2(130, 44)
		up.pressed.connect(_pick_sound.bind(lane))
		srow.add_child(up)
		var test := UIKit.button("TEST", UIKit.CYAN, 20)
		test.custom_minimum_size = Vector2(90, 44)
		test.pressed.connect(_test_sound.bind(lane))
		srow.add_child(test)
		var dflt := UIKit.button("DEFAULT", UIKit.HOT, 20)
		dflt.custom_minimum_size = Vector2(130, 44)
		dflt.pressed.connect(_reset_sound.bind(lane))
		srow.add_child(dflt)
		var state := UIKit.label("", 18, UIKit.PAPER, 4)
		srow.add_child(state)
		_sound_labels.append(state)
		list.add_child(srow)
	_refresh_sound_labels()
	_sound_dialog = FileDialog.new()
	_sound_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sound_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_sound_dialog.use_native_dialog = true
	_sound_dialog.title = "Choose a hit sound"
	_sound_dialog.filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; Audio files"])
	_sound_dialog.size = Vector2i(900, 600)
	_sound_dialog.file_selected.connect(_on_sound_file)
	add_child(_sound_dialog)

	_hint = UIKit.label("", 20, UIKit.LIME, 5)
	col.add_child(_hint)
	_back = UIKit.button("BACK", UIKit.LIME)
	_back.pressed.connect(_close)
	col.add_child(_back)
	_back.grab_focus()


func _header(parent: Control, text: String) -> void:
	var l := UIKit.label(text, 24, UIKit.CYAN, 6)
	parent.add_child(l)


func _slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UIKit.label(text, 22, UIKit.PAPER, 5)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := UIKit.slider(lo, hi, step, value)
	row.add_child(s)
	var val := UIKit.label(_fmt(value, step), 20, UIKit.PAPER, 4)
	val.custom_minimum_size = Vector2(70, 0)
	row.add_child(val)
	s.value_changed.connect(func(v):
		val.text = _fmt(v, step)
		on_change.call(v)
		GameFeel.play_sfx("tick"))
	parent.add_child(row)


func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v


func _toggle(parent: Control, text: String, value: bool, on_change: Callable) -> void:
	var c := UIKit.check(text, value)
	c.toggled.connect(func(v):
		on_change.call(v)
		GameFeel.play_sfx("ui_move"))
	parent.add_child(c)


func _start_rebind(lane: int, slot: int) -> void:
	_rebind_lane = lane
	_rebind_slot = slot
	_key_buttons[lane][slot].text = "press key..."
	_hint.text = "Press a key for %s (Esc cancels)" % InputProfile.LANE_NAMES[lane]


func _refresh_keys() -> void:
	for lane in InputProfile.LANES:
		for slot in InputProfile.SLOTS:
			_key_buttons[lane][slot].text = InputProfile.key_name(Settings.input_profile.keys[lane][slot])


func _input(event: InputEvent) -> void:
	for c in get_children():
		if c is CalibrationScreen:
			return # calibration handles its own keys (incl. Esc)
	if _rebind_lane >= 0 and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Settings.input_profile.rebind(_rebind_lane, _rebind_slot, event.physical_keycode)
			GameFeel.play_sfx("ui_confirm")
		_rebind_lane = -1
		_hint.text = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()
	elif _rebind_lane < 0 and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	Settings.notify_changed()
	GameFeel.play_sfx("ui_back")
	closed.emit()


func _open_calibration() -> void:
	var cal := CalibrationScreen.new()
	add_child(cal)
	cal.closed.connect(cal.queue_free)
	cal.applied.connect(_close) # latency was saved; leave the options so the slider shows the new value next time


func _pick_sound(lane: int) -> void:
	_sound_lane = lane
	_sound_dialog.popup_centered()


func _on_sound_file(path: String) -> void:
	var err := Settings.set_hit_sound(_sound_lane, path)
	_hint.text = err if err != "" else "Hit sound for %s set." % InputProfile.LANE_NAMES[_sound_lane]
	_refresh_sound_labels()
	if err == "":
		_test_sound(_sound_lane)


func _test_sound(lane: int) -> void:
	var s := Settings.hit_stream(lane)
	if s != null:
		GameFeel.play_stream(s, Settings.BUS_HITS)
	else:
		GameFeel.play_sfx("perfect", Settings.BUS_HITS)


func _reset_sound(lane: int) -> void:
	Settings.clear_hit_sound(lane)
	_hint.text = "%s back to the default sound." % InputProfile.LANE_NAMES[lane]
	_refresh_sound_labels()
	_test_sound(lane)


func _refresh_sound_labels() -> void:
	for lane in _sound_labels.size():
		var f: String = Settings.hit_sound_files[lane]
		_sound_labels[lane].text = "custom: " + f.get_file() if f != "" else "default"
