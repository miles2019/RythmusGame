class_name ResultScreen
extends Control
## Result: numbers count up with pops, the rank slams in with an elastic stamp.

signal retry_pressed
signal next_pressed
signal menu_pressed

const RANK_COLORS := {"S": Color("fff36b"), "A": Color("5cffc4"), "B": Color("6fb7ff"), "C": Color("ffb03b"), "D": Color("ff5a7a")}

var _result: Dictionary = {}
var _stage: Stage
var _retry: Button
var _next_btn: Button


var _story_next := false
var _song_line := ""


func setup(result: Dictionary, story_next := false) -> void:
	_story_next = story_next
	_song_line = "%s  -  %s%s" % [result.get("title", ""), Difficulty.NAMES[result.get("difficulty", 1)], "  (NEW BEST!)" if result.get("new_best", false) else ""]
	_result = result


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Stage.new()
	add_child(_stage)
	var failed: bool = _result.get("failed", false)
	var rank: String = _result.get("rank", "D")
	_stage.stability = 20.0 if failed else 95.0
	_stage.accent = RANK_COLORS[rank]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.NIGHT, RANK_COLORS[rank], 6, 22, 16))
	panel.position = Vector2(200, 60)
	panel.custom_minimum_size = Vector2(880, 600)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title_text := "RIFT COLLAPSED" if failed else "RIFT STABILIZED"
	if _result.get("no_fail", false) and not failed:
		title_text += "  (CLASSIC)"
	var title := UIKit.label(title_text, 46, UIKit.HOT if failed else UIKit.CYAN, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 40)
	v.add_child(mid)
	var rank_l := UIKit.label(rank, 240, RANK_COLORS[rank], 24)
	rank_l.custom_minimum_size = Vector2(240, 300)
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid.add_child(rank_l)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	mid.add_child(rows)
	var score_l := _row(rows, "SCORE", "0", UIKit.PAPER, 40)
	_row(rows, "MAX COMBO", str(_result.max_combo), UIKit.PAPER, 28)
	_row(rows, "ACCURACY", "%.1f%%" % (_result.accuracy * 100.0), UIKit.PAPER, 28)
	var counts: Array = _result.counts
	# The rating name AND shape prefix keep this readable without colour.
	_row(rows, "*  PERFECT", str(counts[0]), GameFeel.RATINGS[0].color, 24)
	_row(rows, "<>  GREAT", str(counts[1]), GameFeel.RATINGS[1].color, 24)
	_row(rows, "o  GOOD", str(counts[2]), GameFeel.RATINGS[2].color, 24)
	_row(rows, "x  MISS", str(counts[3]), GameFeel.RATINGS[3].color, 24)
	_row(rows, "DOUBLES / HOLDS", "%d / %d" % [_result.doubles, _result.holds], UIKit.PAPER, 22)
	if _result.get("new_record", false):
		var rec := UIKit.label("NEW COMBO RECORD!", 30, UIKit.AMBER, 8)
		rows.add_child(rec)
		GameFeel.pop(rec, 0.5, 0.6)

	v.add_child(UIKit.label(_song_line, 24, UIKit.YELLOW, 6))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	v.add_child(buttons)
	_retry = UIKit.button("RETRY", UIKit.LIME)
	_retry.custom_minimum_size = Vector2(240, 62)
	var menu := UIKit.button("MENU", UIKit.HOT)
	menu.custom_minimum_size = Vector2(240, 62)
	if _story_next:
		_next_btn = UIKit.button("CONTINUE", UIKit.CYAN)
		_next_btn.modulate.a = 0.0
		_next_btn.custom_minimum_size = Vector2(240, 62)
		_next_btn.pressed.connect(func(): next_pressed.emit())
		buttons.add_child(_next_btn)
	buttons.add_child(_retry)
	buttons.add_child(menu)
	_retry.pressed.connect(func(): retry_pressed.emit())
	menu.pressed.connect(func(): menu_pressed.emit())
	_retry.modulate.a = 0.0
	menu.modulate.a = 0.0

	# --- choreography
	rank_l.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(440, 300)
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(f: float): score_l.text = str(int(_result.score * f)), 0.0, 1.0, 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		score_l.text = str(_result.score)
		GameFeel.pop(score_l, 0.25)
		rank_l.modulate.a = 1.0
		rank_l.pivot_offset = rank_l.size * 0.5
		rank_l.scale = Vector2(2.6, 2.6)
		GameFeel.new_tween(rank_l, "stamp").tween_property(rank_l, "scale", Vector2.ONE, 0.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		GameFeel.play_sfx("impact", Settings.BUS_HITS, 1.4, -6.0)
		GameFeel.play_sfx("record" if rank in ["S", "A"] else "ui_confirm", Settings.BUS_HITS)
		_stage.impact(RANK_COLORS[rank]))
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		_retry.modulate.a = 1.0
		menu.modulate.a = 1.0
		GameFeel.pop(_retry, 0.15)
		GameFeel.pop(menu, 0.15)
		if _next_btn:
			_next_btn.modulate.a = 1.0
			GameFeel.pop(_next_btn, 0.15)
			_next_btn.grab_focus()
		else:
			_retry.grab_focus())


func _row(parent: Control, caption: String, value: String, color: Color, size: int) -> Label:
	var h := HBoxContainer.new()
	var c := UIKit.label(caption, size - 6 if size > 24 else size, UIKit.PAPER, 5)
	c.custom_minimum_size = Vector2(260, 0)
	h.add_child(c)
	var l := UIKit.label(value, size, color, 6)
	h.add_child(l)
	parent.add_child(h)
	return l


func _process(_delta: float) -> void:
	_stage.beat_pos = Time.get_ticks_msec() / 1000.0 * 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		retry_pressed.emit()
