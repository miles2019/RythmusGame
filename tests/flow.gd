extends Node
## Full story flow with synthetic key events:
## menu -> story select -> dialogue -> loading -> song -> pause/resume -> restart -> result -> continue
## -> outro dialogue -> story select (chapter 2 now unlocked) -> classic select.

var t := 0.0
var step := 0
var main: Node
var song: Node
var presses := 0


func _key(code: int, pressed := true) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(code: int) -> void:
	_key(code)
	_key(code, false)


func _find(cls: Script) -> Node:
	for c in main.get_children():
		if c.get_script() == cls:
			return c
	return null


func _log(msg: String) -> void:
	print("[%5.1f] %s" % [Time.get_ticks_msec() / 1000.0, msg])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Progress.save_path = "user://test_progress.cfg"
	Progress.cleared = []
	main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main) # sibling, so our ALWAYS mode does not leak into the game


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 2.5:
				_tap(KEY_ENTER); _log("menu: STORY MODE"); step = 1; t = 0.0
		1:
			if t > 1.8 and _find(SongSelect):
				_log("story select up, cards=%d" % _find(SongSelect)._entries.size())
				_tap(KEY_ENTER); step = 2; t = 0.0
		2:
			if t > 1.0 and _find(DialogueScreen):
				_log("dialogue up"); step = 3; t = 0.0
		3:
			# mash enter through the dialogue (first press completes typing, second advances)
			if t > 0.35:
				t = 0.0
				presses += 1
				_tap(KEY_ENTER)
				if presses > 18 or _find(LoadingScreen) or _find(SongScene):
					_log("dialogue done after %d presses" % presses); step = 4
		4:
			song = _find(SongScene) as Node
			if song != null and song.clock.running:
				song.pause_on_focus_loss = false
				_log("song running: %s diff=%d notes=%d" % [song.info.title, song.diff, song._chart.size()]); step = 5; t = 0.0
		5:
			var tg: Dictionary
			if not song.has_meta("target"):
				for n in song._chart:
					if n.time > song.clock.time() + 0.6:
						song.set_meta("target", n)
						break
			tg = song.get_meta("target")
			if song.clock.time() >= tg.time:
				_tap(Settings.input_profile.keys[tg.lane][0])
				_log("sent real key lane %d at %.3f (note %.3f)" % [tg.lane, song.clock.time(), tg.time]); step = 6; t = 0.0
		6:
			if t > 0.3:
				_log("judged: perfect=%d great=%d good=%d combo=%d" % [song.counts[0], song.counts[1], song.counts[2], song.combo])
				_tap(KEY_ESCAPE); step = 7; t = 0.0
		7:
			if t > 0.5:
				_log("paused=%s menu_open=%s" % [get_tree().paused, song.pause_menu.is_open()])
				song.set_meta("t_at_pause", song.clock.time())
				_tap(KEY_ESCAPE); step = 8; t = 0.0
		8:
			if t > 2.2:
				_log("resumed paused=%s time=%.2f (was %.2f)" % [get_tree().paused, song.clock.time(), song.get_meta("t_at_pause")]); step = 9; t = 0.0
		9:
			if t > 0.5:
				song.restart_requested.emit(); step = 10; t = 0.0
		10:
			if t > 2.0:
				var s2 := _find(SongScene)
				_log("restart: new scene=%s old_freed=%s score=%d trauma=%.2f dmg=%.2f" % [s2 != song, not is_instance_valid(song), s2.score, GameFeel.trauma, s2.player.damage])
				song = s2
				song.counts = [200, 0, 0, 0] # pretend a clean run so the chapter counts as cleared
				song._chart = song._chart.slice(0, 200)
				song._finish(false); step = 11; t = 0.0
		11:
			if t > 5.0:
				var rs := _find(ResultScreen)
				_log("result screen=%s state=%d cleared=%s" % [rs != null, main.state, Progress.cleared])
				_tap(KEY_ENTER); step = 12; t = 0.0   # CONTINUE is focused
		12:
			if t > 1.5:
				_log("outro dialogue=%s" % (_find(DialogueScreen) != null))
				_tap(KEY_ESCAPE); step = 13; t = 0.0
		13:
			if t > 2.0:
				var ss = _find(SongSelect)
				_log("back at story select=%s" % (ss != null))
				if ss:
					var c: Dictionary = ss._entries[1]
					_log("chapter 2 locked=%s (expect false)" % c.locked)
				get_tree().quit()
