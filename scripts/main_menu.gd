class_name MainMenu
extends Control
## Start menu: animated stage, both characters idling on the beat, bouncy sticker buttons.

signal story_pressed
signal classic_pressed
signal upload_pressed
signal quit_pressed

const BPM := 128.0

var _stage: Stage
var _mika: PlayerCharacter
var _kuro: RivalCharacter
var _buttons: VBoxContainer
var _title: Control
var _title_bg: HUD.BurstBG
var _music: AudioStreamPlayer
var _credits: Control
var _last_beat := -1
var _first: Button
var _menu_info: Dictionary
var _born := Time.get_ticks_msec()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Stage.new()
	_stage.theme = "club"
	add_child(_stage)
	_stage.stability = 80.0
	_mika = load("res://scenes/PlayerCharacter.tscn").instantiate()
	_mika.position = Vector2(200, 690)
	_mika.scale = Vector2(1.35, 1.35)
	add_child(_mika)
	_kuro = load("res://scenes/RivalCharacter.tscn").instantiate()
	_kuro.position = Vector2(1090, 690)
	_kuro.scale = Vector2(1.35, 1.35)
	add_child(_kuro)
	_kuro.set_variant("kuro")
	_mika.damage = 0.0

	_title = Control.new()
	_title.position = Vector2(640, 118)
	add_child(_title)
	_title_bg = HUD.BurstBG.new()
	_title_bg.size = Vector2(760, 260)
	_title_bg.position = Vector2(-380, -130)
	_title_bg.spikes = 16
	_title_bg.fill = UIKit.HOT
	_title_bg.pivot_offset = _title_bg.size * 0.5
	_title_bg.scale = Vector2(1.0, 0.46) # squashed starburst: wide sticker behind the two title lines
	_title.add_child(_title_bg)
	var t1 := UIKit.label("NEON BEAT", 104, UIKit.PAPER, 16)
	var t2 := UIKit.label("//RIFT", 84, UIKit.YELLOW, 14)
	for l in [t1, t2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(700, 120)
	t1.position = Vector2(-350, -105)
	t2.position = Vector2(-350, -8)
	_title.add_child(t1)
	_title.add_child(t2)
	t1.rotation = -0.04
	t2.rotation = 0.03

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_buttons.position = Vector2(420, 262)
	add_child(_buttons)
	var defs := [
		["STORY MODE", UIKit.HOT, func(): story_pressed.emit()],
		["CLASSIC / REPLAY", UIKit.CYAN, func(): classic_pressed.emit()],
		["UPLOAD MUSIC", UIKit.LIME, func(): upload_pressed.emit()],
		["OPTIONS", UIKit.AMBER, _open_options],
		["CREDITS", UIKit.PANEL.lightened(0.25), _open_credits],
		["QUIT", UIKit.PANEL.lightened(0.15), func(): quit_pressed.emit()],
	]
	var i := 0
	for d in defs:
		var b := UIKit.button(d[0], d[1], 30, [-0.012, 0.014, -0.008, 0.012, -0.014, 0.008][i])
		b.custom_minimum_size = Vector2(440, 54)
		b.pressed.connect(d[2])
		_buttons.add_child(b)
		if _first == null:
			_first = b
		i += 1
	_first.grab_focus.call_deferred()

	_music = AudioStreamPlayer.new()
	_music.bus = Settings.BUS_MUSIC
	_music.volume_db = -8.0
	add_child(_music)
	_menu_info = Songs.make_info(Songs.by_id("static_bloom"))
	Synth.prewarm(_menu_info)
	_intro_animation()
	_mika.set_state(Character.State.INTRO)
	_kuro.set_state(Character.State.INTRO)


func _intro_animation() -> void:
	# Title slams in with overshoot; buttons pop in one after another.
	GameFeel.set_base_scale(_title, Vector2.ONE)
	_title.scale = Vector2(0.1, 0.1)
	_title.modulate.a = 0.0
	var tw := GameFeel.new_tween(_title, "intro")
	tw.set_parallel(true)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.2)
	var i := 0
	for b in _buttons.get_children():
		b.modulate.a = 0.0
		var bt := GameFeel.new_tween(b, "intro")
		bt.tween_interval(0.25 + i * 0.07)
		bt.tween_property(b, "modulate:a", 1.0, 0.1)
		bt.tween_callback(GameFeel.pop.bind(b, 0.18, 0.4))
		i += 1


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var beat_pos := t * BPM / 60.0
	_stage.beat_pos = beat_pos
	var beat := int(beat_pos)
	if beat != _last_beat:
		_last_beat = beat
		_stage.beat_pulse(1.0 if beat % 4 == 0 else 0.5)
		_mika.on_beat(beat % 4 == 0)
		_kuro.on_beat(beat % 4 == 0)
		if Time.get_ticks_msec() - _born > 900:
			GameFeel.pop(_title, 0.03 if beat % 4 else 0.07, 0.3)
		_title_bg.spin = beat * 0.05
		_title_bg.queue_redraw()
	# menu music: loop the drop section once the song has finished rendering
	if Synth.is_ready(_menu_info):
		if _music.stream == null:
			_music.stream = Synth.get_song(_menu_info).get("full", null)
		if _music.stream != null and (not _music.playing or _music.get_playback_position() > 52.5):
			_music.play(37.5)


func stop_music() -> void:
	_music.stop()


func _open_options() -> void:
	var o := OptionsMenu.new()
	add_child(o)
	o.closed.connect(func():
		o.queue_free()
		_first.grab_focus())


func _open_credits() -> void:
	var c := Control.new()
	_credits = c
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var col := UIKit.modal_column(c, 0.85, 760.0)
	var title := UIKit.label("CREDITS", 52, UIKit.AMBER, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := UIKit.label(
		"NEON BEAT//RIFT\n\n"
		+ "Mika Pulse, Kuro Static, Gum Grin, Mr. Null, Overclock: original characters\n"
		+ "All graphics are drawn procedurally (placeholder art)\n"
		+ "All music and sounds are synthesized at runtime\n"
		+ "Your uploaded songs stay on your PC (user://songs)\n\n"
		+ "Made with Godot 4", 24, UIKit.PAPER, 6)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var back := UIKit.button("BACK", UIKit.LIME)
	col.add_child(back)
	back.pressed.connect(func():
		c.queue_free()
		_first.grab_focus())
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Escape closes the credits panel (options handles its own Escape).
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_credits):
		_credits.queue_free()
		_first.grab_focus()
