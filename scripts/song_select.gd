class_name SongSelect
extends Control
## FNF-freeplay style song list for both STORY (chapters, sequential unlocks) and FREEPLAY
## (every cleared song + uploaded tracks). Left: coloured slanted panel with Mika at the decks.
## Right: diagonal song list, highscore digits, cover card. Up/Down choose, Left/Right change the
## difficulty, Enter plays, Esc goes back, Del removes an uploaded song, N toggles no-fail.

signal chosen(info: Dictionary, diff: int, no_fail: bool, chapter: int)
signal import_pressed
signal back_pressed

var mode := "story"   ## "story" | "classic"

var _back: Control
var _ui: Control
var _mika: PlayerCharacter
var _entries: Array[Dictionary] = []
var _sel := 0
var _pos := 0.0            # smoothed scroll position (index space)
var _diff := Difficulty.NORMAL
var _no_fail := false
var _accent := UIKit.HOT
var _shake := 0.0
var _t := 0.0
var _last_beat := -1


func setup(screen_mode: String) -> void:
	mode = screen_mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diff = Progress.difficulty
	_back = Control.new()
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	add_child(_back)
	_mika = load("res://scenes/PlayerCharacter.tscn").instantiate()
	_mika.position = Vector2(215, 668)
	_mika.scale = Vector2(1.9, 1.9)
	add_child(_mika)
	_mika.set_state(Character.State.BEAT_IDLE)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.draw.connect(_draw_ui)
	_ui.gui_input.connect(_on_gui_input)
	add_child(_ui)
	_build_entries()
	_sel = _initial_selection()
	_pos = _sel
	_accent = _entry_accent(_sel)
	_back.queue_redraw()


func _build_entries() -> void:
	_entries.clear()
	for i in Songs.LIST.size():
		var def: Dictionary = Songs.LIST[i]
		var unlocked: bool = Progress.chapter_unlocked(i) if mode == "story" else Progress.replay_unlocked(i)
		var status := ""
		if mode == "story":
			status = "CLEARED" if Progress.cleared.has(def.id) else ("NEW!" if unlocked else "")
		_entries.append({"info": Songs.make_info(def), "locked": not unlocked, "import": false,
				"chapter": i, "status": status, "id": def.id, "custom": false})
	if mode == "classic":
		for entry in Progress.custom:
			_entries.append({"info": entry, "locked": false, "import": false, "chapter": -1,
					"status": "", "id": entry.id, "custom": true})
		_entries.append({"info": {}, "locked": false, "import": true, "chapter": -1, "status": "", "id": "", "custom": false})


func _initial_selection() -> int:
	if mode == "story": # first chapter that is unlocked but not cleared yet
		for i in Songs.LIST.size():
			if Progress.chapter_unlocked(i) and not Progress.cleared.has(Songs.LIST[i].id):
				return i
		return Songs.LIST.size() - 1
	return 0


func _entry_accent(i: int) -> Color:
	var e: Dictionary = _entries[i]
	if e.import:
		return UIKit.LIME
	if e.locked:
		return Color("6f5f99")
	var secs: Array = e.info.sections
	return secs[3].accent if secs.size() > 3 else UIKit.HOT


# ------------------------------------------------------------ drawing

func _draw_back() -> void:
	var w := 1280.0
	var h := 720.0
	_back.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color("2b1b5a"), Color("1a0f3e"), Color("0e0620"), Color("150a30")]))
	# diagonal stripes on the right
	var st := PackedVector2Array()
	for k in 16:
		st.append(Vector2(520.0 + k * 90.0, 0))
		st.append(Vector2(320.0 + k * 90.0, h))
	_back.draw_multiline(st, Color(1, 1, 1, 0.035), 26.0)
	# left coloured panel with the big faded title pattern
	var c := _accent
	_back.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(540, 0), Vector2(400, h), Vector2(0, h)]),
			PackedColorArray([c, c, c.darkened(0.25), c.darkened(0.25)]))
	var font := UIKit.font()
	var name_text := "?" if _entries.is_empty() else _big_text(_sel)
	for row in 5:
		var xo := -80.0 - (row % 2) * 160.0
		_back.draw_string(font, Vector2(xo, 150.0 + row * 120.0), name_text + "  " + name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(1, 1, 1, 0.14))
	UIKit.draw_halftone(_back, Rect2(0, 0, 420, h), Color(0, 0, 0, 0.12))
	_back.draw_line(Vector2(540, 0), Vector2(400, h), UIKit.INK, 10.0)
	# the decks under Mika
	for x in [80.0, 330.0]:
		_back.draw_circle(Vector2(x, 690), 78.0, UIKit.INK)
		_back.draw_circle(Vector2(x, 690), 70.0, Color("2a2a3a"))
		for r in range(24, 68, 11):
			_back.draw_arc(Vector2(x, 690), float(r), 0, TAU, 28, Color(1, 1, 1, 0.08), 2.0)
		_back.draw_circle(Vector2(x, 690), 22.0, _accent)


func _big_text(i: int) -> String:
	var e: Dictionary = _entries[i]
	if e.import:
		return "UPLOAD"
	if e.locked:
		return "??????"
	return str(e.info.title)


func _draw_ui() -> void:
	var font := UIKit.font()
	# --- top and bottom bands
	_ui.draw_rect(Rect2(0, 0, 1280, 46), UIKit.INK)
	_ui.draw_string(font, Vector2(16, 36), "STORY MODE" if mode == "story" else "FREEPLAY", HORIZONTAL_ALIGNMENT_LEFT, 500, 34, Color.WHITE)
	var right := "NEON BEAT OST"
	if not _entries.is_empty() and _entries[_sel].custom:
		right = "MY MUSIC"
	elif mode == "story" and not _entries.is_empty():
		right = "CHAPTER %d / %d" % [_sel + 1, Songs.LIST.size()]
	_ui.draw_string(font, Vector2(764, 36), right, HORIZONTAL_ALIGNMENT_RIGHT, 500, 34, Color.WHITE)
	_ui.draw_rect(Rect2(0, 690, 1280, 30), UIKit.INK)
	var hint := "UP/DOWN song   LEFT/RIGHT difficulty   ENTER play   ESC back"
	if mode == "classic":
		hint += "   N no-fail: %s   DEL remove upload" % ("ON" if _no_fail else "off")
	_ui.draw_string(font, Vector2(16, 713), hint, HORIZONTAL_ALIGNMENT_LEFT, 1250, 20, Color("c9c0ff"))
	_draw_difficulty(font)
	_draw_highscore(font)
	_draw_list(font)
	_draw_cover(font)


func _draw_difficulty(font: Font) -> void:
	var col: Color = Difficulty.COLORS[_diff]
	var pulse := 1.0 + 0.06 * sin(_t * 6.0)
	# arrows
	_ui.draw_colored_polygon(PackedVector2Array([Vector2(30, 98), Vector2(58, 76), Vector2(58, 120)]), UIKit.INK)
	_ui.draw_colored_polygon(PackedVector2Array([Vector2(36, 98), Vector2(54, 84), Vector2(54, 112)]), col)
	_ui.draw_colored_polygon(PackedVector2Array([Vector2(318, 98), Vector2(290, 76), Vector2(290, 120)]), UIKit.INK)
	_ui.draw_colored_polygon(PackedVector2Array([Vector2(312, 98), Vector2(294, 84), Vector2(294, 112)]), col)
	var txt: String = Difficulty.SHORT_NAMES[_diff]
	_ui.draw_set_transform(Vector2(174, 118), 0.0, Vector2(pulse, pulse))
	_ui.draw_string_outline(font, Vector2(-100, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 200, 68, 14, UIKit.INK)
	_ui.draw_string(font, Vector2(-100, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 200, 68, col)
	_ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ui.draw_string(font, Vector2(20, 156), Difficulty.DESCRIPTIONS[_diff].left(44), HORIZONTAL_ALIGNMENT_LEFT, 400, 16, Color(1, 1, 1, 0.75))


func _draw_highscore(font: Font) -> void:
	var e := _entries[_sel] if not _entries.is_empty() else {}
	var best: Dictionary = {}
	if not e.is_empty() and not e.import and not e.locked:
		best = Progress.best_for(e.id, _diff)
	var score: int = best.get("score", 0)
	_ui.draw_string_outline(font, Vector2(700, 82), "HIGHSCORE", HORIZONTAL_ALIGNMENT_LEFT, 300, 36, 10, UIKit.INK)
	_ui.draw_string(font, Vector2(700, 82), "HIGHSCORE", HORIZONTAL_ALIGNMENT_LEFT, 300, 36, UIKit.AMBER)
	var digits := "%07d" % mini(score, 9999999)
	for i in 7:
		var x := 700.0 + i * 38.0
		_ui.draw_rect(Rect2(x - 2, 92, 36, 52), UIKit.INK)
		_ui.draw_rect(Rect2(x, 94, 32, 48), Color("0f3a4a"))
		_ui.draw_string(font, Vector2(x, 132), digits[i], HORIZONTAL_ALIGNMENT_CENTER, 32, 40, UIKit.CYAN if score > 0 else Color("2a6a7a"))
	var rank: String = best.get("rank", "-")
	_ui.draw_rect(Rect2(1000, 88, 112, 60), UIKit.INK)
	_ui.draw_rect(Rect2(1004, 92, 104, 52), Color("1a1a2a"))
	_ui.draw_string(font, Vector2(1004, 126), "RANK", HORIZONTAL_ALIGNMENT_CENTER, 104, 18, Color("8a8aa8"))
	_ui.draw_string(font, Vector2(1004, 142), rank, HORIZONTAL_ALIGNMENT_CENTER, 104, 34, UIKit.YELLOW if rank != "-" else Color("555566"))


func _draw_list(font: Font) -> void:
	for k in 7:
		var d := k - 3
		var i := int(round(_pos)) + d
		if i < 0 or i >= _entries.size():
			continue
		var off := float(i) - _pos           # distance from the highlighted slot (smooth)
		var y := 384.0 + off * 92.0
		var x := 560.0 + absf(off) * 36.0 + (_shake * sin(_t * 60.0) * 8.0 if i == _sel else 0.0)
		var e: Dictionary = _entries[i]
		var sel := i == _sel
		var w := 400.0
		var h := 78.0
		var slant := 22.0
		var poly := PackedVector2Array([Vector2(x, y - h * 0.5), Vector2(x + w, y - h * 0.5), Vector2(x + w - slant, y + h * 0.5), Vector2(x - slant * 0.3, y + h * 0.5)])
		var shadow := PackedVector2Array()
		for p in poly:
			shadow.append(p + Vector2(6, 6))
		_ui.draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
		var fill := Color("2a2f55") if not sel else Color("3b4a8a")
		if e.locked:
			fill = Color("23233a")
		_ui.draw_colored_polygon(poly, fill)
		var loop := poly.duplicate()
		loop.append(poly[0])
		_ui.draw_polyline(loop, UIKit.YELLOW if sel else Color(1, 1, 1, 0.25), 5.0 if sel else 2.0)
		# icon
		var ic := Vector2(x - 30.0, y)
		if e.import:
			_ui.draw_circle(ic, 27.0, UIKit.INK)
			_ui.draw_circle(ic, 23.0, UIKit.LIME)
			_ui.draw_rect(Rect2(ic.x - 3, ic.y - 14, 6, 28), UIKit.INK)
			_ui.draw_rect(Rect2(ic.x - 14, ic.y - 3, 28, 6), UIKit.INK)
		elif e.locked:
			_ui.draw_circle(ic, 27.0, UIKit.INK)
			_ui.draw_circle(ic, 23.0, Color("3a2d5c"))
			_ui.draw_string(font, Vector2(ic.x - 12, ic.y + 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 24, 40, Color("9a88cc"))
		else:
			HUD.draw_face(_ui, ic, 21.0, e.info.get("rival", "kuro"), 1)
		# text
		var title := "UPLOAD MUSIC" if e.import else ("???" if e.locked else str(e.info.title))
		var sub := ""
		if e.import:
			sub = "mp3 / ogg / wav"
		elif e.locked:
			sub = "LOCKED - clear the previous chapter" if mode == "story" else "LOCKED - clear it in story mode"
		else:
			sub = "%d BPM" % int(round(float(e.info.get("bpm", 0))))
			if e.chapter >= 0 and mode == "story":
				sub = "CH.%d  %s  %s" % [e.chapter + 1, sub, e.status]
			elif e.custom:
				sub += "  YOUR TRACK"
			else:
				sub += "  " + str(e.info.get("style", "")).to_upper()
		_ui.draw_string_outline(font, Vector2(x + 26, y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 38, 8, UIKit.INK)
		_ui.draw_string(font, Vector2(x + 26, y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 38, Color.WHITE if not e.locked else Color("7a7a9a"))
		_ui.draw_string(font, Vector2(x + 26, y + 26), sub, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 18, UIKit.CYAN if not e.locked else Color("5a5a7a"))
		# song star rating, right side
		if not e.import and not e.locked:
			var stars: int = e.info.get("stars", 1)
			for s in 5:
				var sc := Vector2(x + w - 100.0 + s * 16.0, y + 22.0)
				_ui.draw_colored_polygon(UIKit.burst_points(sc, 7.0, 3.0, 5, -PI / 2.0), UIKit.YELLOW if s < stars else Color("3a3a5a"))


func _draw_cover(font: Font) -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries[_sel]
	var r := Rect2(1046, 190, 200, 200)
	_ui.draw_set_transform(r.get_center(), 0.05, Vector2.ONE)
	var local := Rect2(-100, -100, 200, 200)
	_ui.draw_rect(Rect2(local.position + Vector2(9, 9), local.size), Color(0, 0, 0, 0.45))
	_ui.draw_rect(local.grow(6), UIKit.INK)
	_ui.draw_rect(local, _accent.darkened(0.35))
	# brick texture like a record sleeve
	var bricks := PackedVector2Array()
	for row in 7:
		bricks.append(Vector2(-100, -100 + row * 30))
		bricks.append(Vector2(100, -100 + row * 30))
	_ui.draw_multiline(bricks, Color(1, 1, 1, 0.08), 2.0)
	if e.import:
		_ui.draw_circle(Vector2.ZERO, 58.0, UIKit.LIME)
		_ui.draw_rect(Rect2(-6, -34, 12, 68), UIKit.INK)
		_ui.draw_rect(Rect2(-34, -6, 68, 12), UIKit.INK)
	elif e.locked:
		_ui.draw_string(font, Vector2(-100, 34), "?", HORIZONTAL_ALIGNMENT_CENTER, 200, 120, Color(1, 1, 1, 0.25))
	else:
		_ui.draw_colored_polygon(UIKit.burst_points(Vector2.ZERO, 92.0, 70.0, 12, _t * 0.3), _accent)
		HUD.draw_face(_ui, Vector2(0, 4), 50.0, e.info.get("rival", "kuro"), 0)
	_ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not e.import and not e.locked:
		var art := str(e.info.get("artist", ""))
		_ui.draw_multiline_string_outline(font, Vector2(1030, 430), art, HORIZONTAL_ALIGNMENT_CENTER, 232, 22, 2, 7, UIKit.INK)
		_ui.draw_multiline_string(font, Vector2(1030, 430), art, HORIZONTAL_ALIGNMENT_CENTER, 232, 22, 2, UIKit.PAPER)


# ------------------------------------------------------------ input + logic

func _process(delta: float) -> void:
	_t += delta
	_pos = lerpf(_pos, float(_sel), clampf(delta * 14.0, 0.0, 1.0))
	_shake = maxf(_shake - delta * 4.0, 0.0)
	var beat := int(_t * 2.0) # calm idle bounce independent of any song
	if beat != _last_beat:
		_last_beat = beat
		_mika.on_beat(beat % 4 == 0)
	_ui.queue_redraw()


func _move(delta: int) -> void:
	if _entries.is_empty():
		return
	_sel = wrapi(_sel + delta, 0, _entries.size())
	GameFeel.play_sfx("ui_move")
	_mika.set_state(Character.State.INPUT_LEFT + (_sel % 4))
	GameFeel.squash(_mika, 1.06, 0.95, 0.3)
	_retint()


func _retint() -> void:
	var target := _entry_accent(_sel)
	var tw := GameFeel.new_tween(self, "tint")
	tw.tween_method(func(c: Color):
		_accent = c
		_back.queue_redraw(), _accent, target, 0.3)


func _change_diff(delta: int) -> void:
	_diff = clampi(_diff + delta, 0, 2)
	Progress.difficulty = _diff
	GameFeel.play_sfx("ui_move")
	if _diff == Difficulty.HARD and delta > 0:
		_mika.hurt(0.3)
	else:
		_mika.hit(1, 1)


func _play() -> void:
	if _entries.is_empty():
		return
	var e: Dictionary = _entries[_sel]
	if e.import:
		GameFeel.play_sfx("ui_confirm")
		import_pressed.emit()
		return
	if e.locked:
		GameFeel.play_sfx("ui_back")
		_shake = 1.0
		return
	GameFeel.play_sfx("ui_confirm")
	chosen.emit(e.info, _diff, _no_fail, e.chapter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_change_diff(1)
	elif event.is_action_pressed("ui_left"):
		_change_diff(-1)
	elif event.is_action_pressed("ui_accept"):
		_play()
	elif event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N and mode == "classic":
		_no_fail = not _no_fail
		GameFeel.play_sfx("ui_move")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE and mode == "classic":
		var e: Dictionary = _entries[_sel]
		if e.custom:
			Progress.remove_custom(e.id)
			GameFeel.play_sfx("splat")
			_build_entries()
			_sel = mini(_sel, _entries.size() - 1)
			_retint()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				_move(1)
			MOUSE_BUTTON_WHEEL_UP:
				_move(-1)
			MOUSE_BUTTON_LEFT:
				var p: Vector2 = event.position
				if p.y > 70.0 and p.y < 130.0 and p.x < 80.0:
					_change_diff(-1)
				elif p.y > 70.0 and p.y < 130.0 and p.x > 270.0 and p.x < 340.0:
					_change_diff(1)
				elif p.x > 540.0 and p.x < 1040.0:
					var d := int(round((p.y - 384.0) / 92.0))
					if d == 0:
						_play()
					else:
						_move(d)
