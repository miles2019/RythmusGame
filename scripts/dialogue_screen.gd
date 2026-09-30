class_name DialogueScreen
extends Control
## Story cutscene: Mika and the rival face off, comic speech bubbles type out line by line.
## Enter / click / Space = next, Esc = skip everything.

signal finished

var lines: Array = []
var rival_kind := "kuro"
var chapter_title := ""
var stage_theme := "club"

var _i := 0
var _chars := 0.0
var _typing := false
var _bubble: Control
var _text: Label
var _name_tag: Label
var _prompt: Label
var _mika: PlayerCharacter
var _rival: RivalCharacter
var _stage: Stage
var _beat_t := 0.0


func setup(song_info: Dictionary, which: String) -> void:
	lines = song_info.get(which, [])
	rival_kind = song_info.rival
	chapter_title = song_info.get("chapter", "")
	stage_theme = song_info.theme
	if which == "outro":
		chapter_title = "- CLEARED -"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Stage.new()
	_stage.theme = stage_theme
	_stage.stability = 70.0
	add_child(_stage)
	_mika = load("res://scenes/PlayerCharacter.tscn").instantiate()
	_mika.position = Vector2(230, 690)
	_mika.scale = Vector2(1.5, 1.5)
	add_child(_mika)
	_rival = load("res://scenes/RivalCharacter.tscn").instantiate()
	_rival.position = Vector2(1050, 690)
	_rival.scale = Vector2(1.5, 1.5)
	add_child(_rival)
	_rival.set_variant(rival_kind)

	var chap := UIKit.label(chapter_title, 38, UIKit.YELLOW, 9)
	chap.position = Vector2(40, 20)
	chap.size = Vector2(700, 50)
	chap.rotation = -0.02
	add_child(chap)

	_bubble = Control.new()
	_bubble.position = Vector2(240, 120)
	_bubble.size = Vector2(800, 210)
	_bubble.pivot_offset = Vector2(400, 210)
	_bubble.draw.connect(_draw_bubble)
	add_child(_bubble)
	_text = UIKit.label("", 34, UIKit.INK, 0)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_text.position = Vector2(40, 52)
	_text.size = Vector2(720, 140)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_text)
	_name_tag = UIKit.label("", 30, UIKit.INK, 0)
	_name_tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_name_tag.position = Vector2(30, -26)
	_name_tag.size = Vector2(400, 44)
	_bubble.add_child(_name_tag)
	_prompt = UIKit.label("ENTER  >>", 24, UIKit.HOT, 6)
	_prompt.position = Vector2(860, 350)
	_prompt.size = Vector2(300, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_prompt)
	var skip := UIKit.label("[ESC] SKIP", 20, UIKit.PAPER, 5)
	skip.position = Vector2(1060, 680)
	skip.size = Vector2(200, 30)
	add_child(skip)
	_mika.set_state(Character.State.BEAT_IDLE)
	_rival.set_state(Character.State.BEAT_IDLE)
	if lines.is_empty():
		finished.emit.call_deferred()
		return
	_show_line()


var _speaker_is_player := true


func _draw_bubble() -> void:
	var r := Rect2(Vector2.ZERO, _bubble.size)
	var tail_x := 160.0 if _speaker_is_player else 640.0
	var tail := PackedVector2Array([Vector2(tail_x, r.size.y - 4), Vector2(tail_x + (30.0 if _speaker_is_player else -30.0), r.size.y + 70),
			Vector2(tail_x + (70.0 if _speaker_is_player else -70.0), r.size.y - 4)])
	_bubble.draw_rect(Rect2(r.position + Vector2(10, 10), r.size), UIKit.INK)
	_bubble.draw_colored_polygon(tail, UIKit.INK)
	_bubble.draw_rect(Rect2(r.position - Vector2(5, 5), r.size + Vector2(10, 10)), UIKit.INK)
	var loop := tail.duplicate()
	loop.append(tail[0])
	_bubble.draw_polyline(loop, UIKit.INK, 12.0, true)
	_bubble.draw_rect(r, UIKit.PAPER)
	_bubble.draw_colored_polygon(tail, UIKit.PAPER)
	UIKit.draw_halftone(_bubble, Rect2(r.size.x - 200, 0, 200, r.size.y), Color(0, 0, 0, 0.06), 12.0, 4.0, Vector2(r.size.x, r.size.y))
	# speaker tag
	var tag_w := 340.0
	_bubble.draw_rect(Rect2(20, -34, tag_w, 52), UIKit.INK)
	_bubble.draw_rect(Rect2(24, -30, tag_w - 8, 44), UIKit.YELLOW if _speaker_is_player else UIKit.CYAN)


func _show_line() -> void:
	var l: Array = lines[_i]
	var who: String = l[0]
	_speaker_is_player = who == "MIKA"
	var narrator := who == "NARRATOR"
	_name_tag.text = who
	_text.text = l[1]
	_text.visible_characters = 0
	_chars = 0.0
	_typing = true
	_bubble.queue_redraw()
	GameFeel.pop(_bubble, 0.06, 0.35)
	_bubble.modulate = Color(0.85, 0.85, 1.0) if narrator else Color.WHITE
	if not narrator:
		var speaker: Character = _mika if _speaker_is_player else _rival
		GameFeel.squash(speaker, 1.12, 0.9, 0.4)
		speaker.set_state(Character.State.VICTORY if not _speaker_is_player else Character.State.INTRO, 0.8)


func _process(delta: float) -> void:
	_beat_t += delta
	if _beat_t > 0.47:
		_beat_t = 0.0
		_stage.beat_pulse(0.6)
		_mika.on_beat(false)
		_rival.on_beat(false)
	_stage.beat_pos += delta * 2.1
	if _typing:
		var prev := int(_chars)
		_chars += delta * 38.0
		_text.visible_characters = int(_chars)
		if int(_chars) != prev and int(_chars) % 3 == 0:
			GameFeel.play_sfx("blip", Settings.BUS_VOICE, 0.8 + (0.5 if not _speaker_is_player else 0.0) + randf() * 0.1, -6.0)
		if _chars >= _text.text.length():
			_typing = false
			_text.visible_characters = -1
	_prompt.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)


func _advance() -> void:
	if _typing:
		_typing = false
		_text.visible_characters = -1
		return
	_i += 1
	if _i >= lines.size():
		finished.emit()
		set_process(false)
		set_process_unhandled_input(false)
		return
	_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_process_unhandled_input(false)
		finished.emit()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		_advance()
		get_viewport().set_input_as_handled()
