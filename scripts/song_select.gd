class_name SongSelect
extends Control
## Card carousel used for both STORY (chapters, sequential unlocks) and CLASSIC/REPLAY
## (every cleared song + uploaded tracks, free play). Difficulty is picked here.

signal chosen(info: Dictionary, diff: int, no_fail: bool, chapter: int)
signal import_pressed
signal back_pressed

var mode := "story"   ## "story" | "classic"

var _bg: ComicBG
var _scroll: ScrollContainer
var _row: HBoxContainer
var _diff_buttons: Array[Button] = []
var _diff_text: Label
var _nofail: CheckButton
var _hint: Label
var _back: Button
var _cards: Array[SongCard] = []
var _diff := Difficulty.NORMAL
var _first_focus: Control


func setup(screen_mode: String) -> void:
	mode = screen_mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ComicBG.new()
	_bg.accent = UIKit.HOT if mode == "story" else UIKit.CYAN
	_bg.accent2 = UIKit.CYAN if mode == "story" else UIKit.LIME
	add_child(_bg)
	_diff = Progress.difficulty

	var title := UIKit.label("STORY MODE" if mode == "story" else "CLASSIC / REPLAY", 64, UIKit.PAPER, 12)
	title.position = Vector2(50, 18)
	title.size = Vector2(800, 80)
	title.rotation = -0.02
	add_child(title)
	var sub := UIKit.label("Clear a chapter to unlock the next one." if mode == "story" else "Every cleared song, plus your own music.", 22, UIKit.YELLOW, 6)
	sub.position = Vector2(56, 88)
	sub.size = Vector2(900, 30)
	add_child(sub)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 126)
	_scroll.size = Vector2(1280, 400)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 40)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	_scroll.add_child(pad)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 26)
	pad.add_child(_row)
	_build_cards()

	# difficulty selector (segmented buttons)
	var diff_row := HBoxContainer.new()
	diff_row.position = Vector2(50, 548)
	diff_row.add_theme_constant_override("separation", 14)
	add_child(diff_row)
	var group := ButtonGroup.new()
	for d in 3:
		var b := UIKit.button(Difficulty.NAMES[d], Difficulty.COLORS[d], 26)
		b.custom_minimum_size = Vector2(170, 52)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d == _diff
		b.pressed.connect(_set_diff.bind(d))
		diff_row.add_child(b)
		_diff_buttons.append(b)
	_diff_text = UIKit.label(Difficulty.DESCRIPTIONS[_diff], 22, UIKit.PAPER, 6)
	_diff_text.position = Vector2(50, 610)
	_diff_text.size = Vector2(700, 30)
	add_child(_diff_text)
	if mode == "classic":
		_nofail = UIKit.check("No-fail practice", false)
		_nofail.position = Vector2(620, 552)
		add_child(_nofail)
	_hint = UIKit.label("", 20, UIKit.CYAN, 5)
	_hint.position = Vector2(50, 654)
	_hint.size = Vector2(800, 28)
	add_child(_hint)
	_back = UIKit.button("BACK", UIKit.HOT, 28, 0.02)
	_back.custom_minimum_size = Vector2(200, 56)
	_back.position = Vector2(1040, 600)
	_back.pressed.connect(func(): back_pressed.emit())
	add_child(_back)
	if _first_focus:
		_first_focus.grab_focus.call_deferred()
	_refresh_diff_ui()


func _build_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	_cards.clear()
	_first_focus = null
	var accents := [UIKit.HOT, UIKit.CYAN, UIKit.AMBER, UIKit.LIME]
	var latest_new: SongCard = null
	var last_unlocked: SongCard = null
	for i in Songs.LIST.size():
		var def: Dictionary = Songs.LIST[i]
		var card := SongCard.new()
		var acc: Color = accents[i % 4]
		card.setup(Songs.make_info(def), acc)
		card.rotation = ((i % 3) - 1) * 0.018
		var unlocked: bool = Progress.chapter_unlocked(i) if mode == "story" else Progress.replay_unlocked(i)
		card.locked = not unlocked
		if mode == "story":
			card.chapter_no = i + 1
			card.status = "CLEARED" if Progress.cleared.has(def.id) else ("NEW!" if unlocked else "")
		var best := _best_any(def.id)
		card.best_rank = best.get("rank", "")
		card.best_score = best.get("score", 0)
		card.pressed.connect(_on_card.bind(card, i))
		card.focus_entered.connect(_on_card_focus.bind(card))
		_row.add_child(card)
		_cards.append(card)
		if unlocked and latest_new == null and not (mode == "story" and Progress.cleared.has(def.id)):
			latest_new = card
		if unlocked:
			last_unlocked = card
	if mode == "classic":
		for entry in Progress.custom:
			var card := SongCard.new()
			card.setup(entry, UIKit.LIME)
			var best := _best_any(entry.id)
			card.best_rank = best.get("rank", "")
			card.best_score = best.get("score", 0)
			card.pressed.connect(_on_card.bind(card, -1))
			card.focus_entered.connect(_on_card_focus.bind(card))
			_row.add_child(card)
			_cards.append(card)
		var imp := SongCard.new()
		imp.setup({}, UIKit.LIME)
		imp.is_import = true
		imp.pressed.connect(func(): import_pressed.emit())
		imp.focus_entered.connect(_on_card_focus.bind(imp))
		_row.add_child(imp)
		_cards.append(imp)
	_first_focus = latest_new if latest_new != null else (last_unlocked if last_unlocked != null else (_cards[0] if not _cards.is_empty() else null))


func _best_any(id: String) -> Dictionary:
	var best := {}
	for d in 3:
		var b: Dictionary = Progress.best_for(id, d)
		if not b.is_empty() and (best.is_empty() or b.score > best.score):
			best = b
	return best


func _on_card_focus(card: SongCard) -> void:
	_scroll.ensure_control_visible(card)
	if card.is_import:
		_hint.text = "Pick an mp3 / ogg / wav - the game finds the beat and builds a chart."
	elif card.locked:
		_hint.text = "Locked." if mode == "classic" else "Clear the previous chapter first."
	elif card.data.get("custom", false):
		_hint.text = "[DEL] removes this uploaded song."
	else:
		_hint.text = "%s  -  %s" % [card.data.get("artist", ""), card.data.get("style", "").to_upper()]


func _on_card(card: SongCard, index: int) -> void:
	if card.locked:
		GameFeel.play_sfx("ui_back")
		GameFeel.squash(card, 0.92, 1.06, 0.3)
		return
	var info: Dictionary = card.data if card.data.get("custom", false) else Songs.make_info(card.data)
	chosen.emit(info, _diff, _nofail != null and _nofail.button_pressed, index)


func _set_diff(d: int) -> void:
	_diff = d
	Progress.difficulty = d
	_refresh_diff_ui()


func _refresh_diff_ui() -> void:
	_diff_text.text = Difficulty.DESCRIPTIONS[_diff]
	for i in _diff_buttons.size():
		_diff_buttons[i].modulate = Color.WHITE if i == _diff else Color(0.65, 0.65, 0.75)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
		get_viewport().set_input_as_handled()
	elif mode == "classic" and event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		var f := get_viewport().gui_get_focus_owner()
		if f is SongCard and f.data.get("custom", false):
			Progress.remove_custom(f.data.id)
			GameFeel.play_sfx("splat")
			_build_cards()
			if _first_focus:
				_first_focus.grab_focus.call_deferred()
