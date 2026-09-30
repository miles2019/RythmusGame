extends Node
## Screenshots of the menu screens. Arg 1 = output dir.

var dir := ""
var step := 0
var t := 0.0
var cur: Node


func _ready() -> void:
	Progress.save_path = "user://test_progress.cfg"
	dir = OS.get_cmdline_user_args()[0]
	Progress.cleared = ["gum_drop", "static_bloom"]  # in memory only (never saved by this test)
	Progress.best = {"gum_drop|1": {"score": 123456, "rank": "A", "combo": 99}}
	Progress.custom = [{"id": "custom_demo", "custom": true, "title": "MY OWN SONG", "artist": "YOUR TRACK", "bpm": 127.4, "rival": "null", "stars": 2, "style": "custom", "theme": "club", "offset": 0.0, "bars": 40, "duration": 80.0, "sections": [{"bar": 0, "name": "INTRO", "accent": Color("ff4fa3")}, {"bar": 4, "name": "VERSE", "accent": Color("35e6ff")}, {"bar": 8, "name": "DROP", "accent": Color("ffb03b")}, {"bar": 12, "name": "OUTRO", "accent": Color("b6ff4a")}]}]
	_go(load("res://scenes/MainMenu.tscn").instantiate())


func _go(n: Node) -> void:
	if cur:
		cur.queue_free()
	cur = n
	add_child(n)
	t = 0.0


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/ui_%s.png" % [dir, n])


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 2.0:
				_shot("menu"); var s := SongSelect.new(); s.setup("story"); _go(s); step = 1
		1:
			if t > 1.2:
				_shot("story"); var s := SongSelect.new(); s.setup("classic"); _go(s); step = 2
		2:
			if t > 1.2:
				_shot("classic"); _go(CalibrationScreen.new()); step = 3
		3:
			if t > 1.0:
				_shot("calibration"); get_tree().quit()
