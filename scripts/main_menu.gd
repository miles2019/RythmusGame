class_name MainMenu
extends Control
## FNF-inspired start menu: warm slanted panel + purple tile grid, big slanted list on the left,
## Mika front-right with a rotating rival behind her. The background is a cached static node.

signal story_pressed
signal classic_pressed
signal upload_pressed
signal quit_pressed

const BPM := 128.0
const RIVALS := ["gum", "kuro", "null", "clock", "bolt", "queen", "brute", "core"]

var _back: Control
var _mika: PlayerCharacter
var _rival: RivalCharacter
var _menu: SlantMenu
var _logo: Control
var _logo_bg: HUD.BurstBG
var _music: AudioStreamPlayer
var _credits: Control
var _options: Control
var _last_beat := -1
var _menu_info: Dictionary
var _born := Time.get_ticks_msec()
var _rival_idx := 0
var _grid_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back = Control.new()
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	add_child(_back)

	# rival peeks from behind Mika and cycles through the crew every few bars
	_rival = load("res://scenes/RivalCharacter.tscn").instantiate()
	_rival.position = Vector2(1120, 700)
	_rival.scale = Vector2(1.9, 1.9)
	add_child(_rival)
	_rival.set_variant(RIVALS[0])
	_mika = load("res://scenes/PlayerCharacter.tscn").instantiate()
	_mika.position = Vector2(930, 720)
	_mika.scale = Vector2(2.3, 2.3)
	add_child(_mika)

	_logo = Control.new()
	_logo.position = Vector2(300, 112)
	add_child(_logo)
	_logo_bg = HUD.BurstBG.new()
	_logo_bg.size = Vector2(620, 220)
	_logo_bg.position = Vector2(-310, -110)
	_logo_bg.pivot_offset = _logo_bg.size * 0.5
	_logo_bg.scale = Vector2(1.0, 0.5)
	_logo_bg.spikes = 18
	_logo_bg.fill = UIKit.HOT
	_logo.add_child(_logo_bg)
	var t1 := UIKit.label("NEON BEAT", 88, UIKit.PAPER, 14)
	var t2 := UIKit.label("//RIFT", 70, UIKit.YELLOW, 12)
	for l in [t1, t2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(620, 100)
	t1.position = Vector2(-310, -88)
	t2.position = Vector2(-310, -4)
	t1.rotation = -0.05
	t2.rotation = 0.04
	_logo.add_child(t1)
	_logo.add_child(t2)

	_menu = SlantMenu.new()
	_menu.position = Vector2(20, 230)
	_menu.spacing = 76.0
	_menu.font_size = 54
	var labels: Array[String] = ["STORY MODE", "FREEPLAY", "UPLOAD MUSIC", "OPTIONS", "CREDITS", "QUIT"]
	var cols: Array[Color] = [UIKit.HOT, UIKit.CYAN, UIKit.LIME, UIKit.AMBER, Color("b388ff"), Color("8a8aa8")]
	_menu.setup(labels, cols)
	_menu.chosen.connect(_on_chosen)
	_menu.moved.connect(_on_moved)
	add_child(_menu)

	var ver := UIKit.label("NEON BEAT//RIFT  -  8 chapters  -  Godot 4.7", 18, UIKit.PAPER, 5)
	ver.position = Vector2(740, 10)
	ver.size = Vector2(520, 26)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)

	_music = AudioStreamPlayer.new()
	_music.bus = Settings.BUS_MUSIC
	_music.volume_db = -8.0
	add_child(_music)
	_menu_info = Songs.make_info(Songs.by_id("static_bloom"))
	Synth.prewarm(_menu_info)
	_intro_animation()
	_mika.set_state(Character.State.INTRO)
	_rival.set_state(Character.State.INTRO)


func _intro_animation() -> void:
	GameFeel.set_base_scale(_logo, Vector2.ONE)
	_logo.scale = Vector2(0.1, 0.1)
	_logo.modulate.a = 0.0
	var tw := GameFeel.new_tween(_logo, "intro")
	tw.set_parallel(true)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.2)
	# list slides in from the left
	_menu.position.x = -560.0
	GameFeel.new_tween(_menu, "slide").tween_property(_menu, "position:x", 20.0, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)


func _process(delta: float) -> void:
	_grid_t += delta
	var t := Time.get_ticks_msec() / 1000.0
	var beat_pos := t * BPM / 60.0
	var beat := int(beat_pos)
	if beat != _last_beat:
		_last_beat = beat
		_mika.on_beat(beat % 4 == 0)
		_rival.on_beat(beat % 4 == 0)
		_back.queue_redraw() # the tile grid breathes on the beat
		if Time.get_ticks_msec() - _born > 900:
			GameFeel.pop(_logo, 0.03 if beat % 4 else 0.07, 0.3)
		_logo_bg.spin = beat * 0.05
		_logo_bg.queue_redraw()
		if beat % 16 == 15: # next rival steps in
			_rival_idx = (_rival_idx + 1) % RIVALS.size()
			_rival.set_variant(RIVALS[_rival_idx])
			_rival.set_state(Character.State.INTRO)
			GameFeel.squash(_rival, 1.15, 0.85, 0.5)
	# menu music: loop the drop section once the song has finished rendering
	if Synth.is_ready(_menu_info):
		if _music.stream == null:
			_music.stream = Synth.get_song(_menu_info).get("full", null)
		if _music.stream != null and (not _music.playing or _music.get_playback_position() > 52.5):
			_music.play(37.5)


func _draw_back() -> void:
	var w := size.x
	var h := size.y
	# right: purple gradient + rounded tile grid
	_back.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color("7a1fb0"), Color("a020a0"), Color("4a1580"), Color("3a0f6b")]))
	var pts := PackedVector2Array()
	var breathe := 1.0 + 0.04 * sin(_grid_t * 2.0)
	var grid := Color(1, 1, 1, 0.07)
	for gy in 12:
		for gx in 12:
			var r := Rect2(560.0 + gx * 76.0, 10.0 + gy * 76.0, 66.0 * breathe, 66.0 * breathe)
			_back.draw_rect(r, grid)
	# left: warm slanted panel (the FNF sunset look)
	var warm_top := Color("ffb36b")
	var warm_bot := Color("ff5a8f")
	_back.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(600, 0), Vector2(430, h), Vector2(0, h)]),
			PackedColorArray([warm_top, warm_top, warm_bot, warm_bot]))
	# halftone on the panel + edge line
	UIKit.draw_halftone(_back, Rect2(0, 0, 440, h), Color(1, 1, 1, 0.16))
	_back.draw_line(Vector2(600, 0), Vector2(430, h), UIKit.INK, 10.0)
	# ground shadow band under the characters
	_back.draw_rect(Rect2(560, 690, w, 40), Color(0, 0, 0, 0.35))


func _on_moved(index: int) -> void:
	_mika.set_state(Character.State.INPUT_LEFT + (index % 4))
	GameFeel.squash(_mika, 1.06, 0.95, 0.3)


func _on_chosen(index: int) -> void:
	match index:
		0: story_pressed.emit()
		1: classic_pressed.emit()
		2: upload_pressed.emit()
		3: _open_options()
		4: _open_credits()
		5: quit_pressed.emit()


func stop_music() -> void:
	_music.stop()


func _open_options() -> void:
	_menu.active = false
	var o := OptionsMenu.new()
	add_child(o)
	_options = o
	o.closed.connect(func():
		o.queue_free()
		_menu.active = true)


func _open_credits() -> void:
	_menu.active = false
	var c := Control.new()
	_credits = c
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var col := UIKit.modal_column(c, 0.85, 800.0)
	var title := UIKit.label("CREDITS", 52, UIKit.AMBER, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := UIKit.label(
		"NEON BEAT//RIFT\n\n"
		+ "Mika Pulse and the crew (Gum Grin, Kuro Static, Mr. Null, Overclock, Bolt, Queen Vex, Brute, The Rift): original characters\n"
		+ "All graphics are drawn procedurally (placeholder art)\n"
		+ "All music and sounds are synthesized at runtime\n"
		+ "Your uploaded songs stay on your PC (user://songs)\n\n"
		+ "Made with Godot 4", 24, UIKit.PAPER, 6)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var back := UIKit.button("BACK", UIKit.LIME)
	col.add_child(back)
	back.pressed.connect(_close_credits)
	back.grab_focus()


func _close_credits() -> void:
	if is_instance_valid(_credits):
		_credits.queue_free()
	_menu.active = true


func _unhandled_input(event: InputEvent) -> void:
	# Escape closes the credits panel (options handles its own Escape).
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_credits):
		_close_credits()
		get_viewport().set_input_as_handled()
