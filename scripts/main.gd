extends Node
## Global flow: menu -> song -> result -> (retry | menu). Screens are swapped behind a
## short slash-wipe. Every screen is freed on exit, so a restart always starts clean.

signal game_state_changed(state: int)

enum GameState { MENU, PLAYING, RESULT }

const SONG_SCENE := preload("res://scenes/SongScene.tscn")
const MENU_SCENE := preload("res://scenes/MainMenu.tscn")
const RESULT_SCENE := preload("res://scenes/ResultScreen.tscn")

var state: int = GameState.MENU
var _current: Node
var _busy := false
var _wipe: Wipe
var _ctx: Dictionary = {}
var _ctx_mode := "story"


## Diagonal slash wipe. `cover` 0 = clear, 1 = fully covered; `from_right` picks the exit side.
class Wipe extends Control:
	var cover := 0.0
	var leaving := false
	const SLANT := 220.0

	func _draw() -> void:
		if cover <= 0.0:
			return
		var w := size.x + SLANT
		var h := size.y
		var far := SLANT + 20.0 # off-screen bounds keep every quad well-formed
		if not leaving:
			var x := cover * w
			draw_colored_polygon(PackedVector2Array([Vector2(-far, 0), Vector2(x, 0), Vector2(x - SLANT, h), Vector2(-far, h)]), UIKit.HOT)
			var x2 := maxf(x - 70.0, 0.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-far, 0), Vector2(x2, 0), Vector2(x2 - SLANT, h), Vector2(-far, h)]), UIKit.INK)
		else:
			var x0 := (1.0 - cover) * w
			var x1 := x0 + 70.0
			if x0 < size.x + far - 1.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(size.x + far, 0), Vector2(size.x + far, h), Vector2(x0 - SLANT, h)]), UIKit.HOT)
			if x1 < size.x + far - 1.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x1, 0), Vector2(size.x + far, 0), Vector2(size.x + far, h), Vector2(x1 - SLANT, h)]), UIKit.INK)


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_wipe = Wipe.new()
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_wipe)
	_show_menu(false)


# ------------------------------------------------------------ navigation

func _show_menu(animated := true) -> void:
	_swap(_build_menu, animated)


func _show_select(mode: String) -> void:
	_swap(_build_select.bind(mode))


func _show_import() -> void:
	_swap(_build_import)


func _show_dialogue(which: String) -> void:
	_swap(_build_dialogue.bind(which))


func _show_loading() -> void:
	_swap(_build_loading)


func _show_song() -> void:
	_swap(_build_song)


func _show_result(result: Dictionary) -> void:
	# bookkeeping first, so the result screen can show "new best" / "continue"
	var cleared_now := false
	if not result.custom and not result.failed and result.rank != "D" and _ctx.get("mode", "") == "story":
		Progress.mark_cleared(result.song_id)
		cleared_now = true
	if not result.no_fail:
		result["new_best"] = Progress.record(result.song_id, result.difficulty, result)
	_swap(_build_result.bind(result, cleared_now))


func _back_to_select() -> void:
	_show_select(_ctx.get("mode", "classic"))


func _on_chosen(info: Dictionary, diff: int, no_fail: bool, chapter: int) -> void:
	_ctx = {"mode": _ctx_mode, "info": info, "diff": diff, "no_fail": no_fail, "chapter": chapter}
	if _ctx_mode == "story":
		_show_dialogue("intro")
	else:
		_show_loading()


# ------------------------------------------------------------ builders (run while the screen is covered)

func _build_menu() -> Node:
	var m: MainMenu = MENU_SCENE.instantiate()
	m.story_pressed.connect(func(): _show_select_mode("story"))
	m.classic_pressed.connect(func(): _show_select_mode("classic"))
	m.upload_pressed.connect(_show_import)
	m.quit_pressed.connect(func(): get_tree().quit())
	_set_state(GameState.MENU)
	return m


func _show_select_mode(mode: String) -> void:
	_ctx_mode = mode
	_ctx = {"mode": mode}
	_show_select(mode)


func _build_select(mode: String) -> Node:
	var s := SongSelect.new()
	s.setup(mode)
	s.chosen.connect(_on_chosen)
	s.import_pressed.connect(_show_import)
	s.back_pressed.connect(_show_menu)
	_set_state(GameState.MENU)
	return s


func _build_import() -> Node:
	var s := ImportScreen.new()
	s.saved.connect(func(_info): _show_select_mode("classic"))
	s.back_pressed.connect(func(): _show_select_mode("classic"))
	_set_state(GameState.MENU)
	return s


func _build_dialogue(which: String) -> Node:
	var d := DialogueScreen.new()
	d.setup(_ctx.info, which)
	if which == "intro":
		d.finished.connect(_show_loading)
	else:
		d.finished.connect(func(): _show_select_mode("story"))
	_set_state(GameState.MENU)
	return d


func _build_loading() -> Node:
	var l := LoadingScreen.new()
	l.setup(_ctx.info)
	l.finished.connect(_show_song)
	_set_state(GameState.MENU)
	return l


func _build_song() -> Node:
	var s: SongScene = SONG_SCENE.instantiate()
	s.song_finished.connect(_show_result)
	s.restart_requested.connect(_show_song)
	s.quit_requested.connect(_back_to_select)
	# begin() must run after the scene entered the tree (its @onready nodes exist).
	var ctx := _ctx
	s.ready.connect(func(): s.begin(ctx.info, ctx.diff, ctx.no_fail), CONNECT_ONE_SHOT)
	_set_state(GameState.PLAYING)
	return s


func _build_result(result: Dictionary, cleared_now: bool) -> Node:
	var r: ResultScreen = RESULT_SCENE.instantiate()
	r.setup(result, cleared_now)
	r.retry_pressed.connect(_show_loading)
	r.next_pressed.connect(func(): _show_dialogue("outro"))
	r.menu_pressed.connect(_back_to_select)
	_set_state(GameState.RESULT)
	return r


func _set_state(s: int) -> void:
	state = s
	game_state_changed.emit(s)


## Covers the screen, swaps the scene while hidden, then reveals the new one.
func _swap(builder: Callable, animated := true) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	if animated and _current != null:
		_wipe.leaving = false
		var tw := create_tween()
		tw.tween_method(_set_cover, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await tw.finished
	_replace(builder)
	if animated:
		_wipe.leaving = true
		var tw2 := create_tween()
		tw2.tween_method(_set_cover, 1.0, 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw2.finished
	_set_cover(0.0)
	_busy = false


func _replace(builder: Callable) -> void:
	if _current != null:
		_current.queue_free()
		remove_child(_current)
	_current = builder.call()
	add_child(_current)


func _set_cover(v: float) -> void:
	_wipe.cover = v
	_wipe.queue_redraw()
