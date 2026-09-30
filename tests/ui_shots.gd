extends Node
## Screenshots of the menu screens. Arg 1 = output dir.

var dir := ""
var step := 0
var t := 0.0
var cur: Node


func _ready() -> void:
	Progress.save_path = "user://test_progress.cfg" # never touch the real save
	dir = OS.get_cmdline_user_args()[0]
	Progress.cleared = ["gum_drop"]  # in memory only (never saved by this test)
	Progress.custom = [{"id": "custom_demo", "custom": true, "title": "MY OWN SONG", "artist": "YOUR TRACK", "bpm": 127.4, "rival": "null", "stars": 2, "style": "custom"}]
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
				_shot("classic")
				var d := DialogueScreen.new()
				d.setup(Songs.make_info(Songs.LIST[2]), "intro")
				_go(d); step = 3
		3:
			if t > 2.2:
				_shot("dialogue"); var l := LoadingScreen.new(); l.setup(Songs.make_info(Songs.LIST[0])); _go(l); step = 4
		4:
			if t > 0.4:
				_shot("loading"); _go(ImportScreen.new()); step = 5
		5:
			if t > 0.8:
				_shot("import")
				var r = load("res://scenes/ResultScreen.tscn").instantiate()
				r.setup({"score": 110743, "max_combo": 204, "counts": [180, 15, 6, 3], "accuracy": 0.96, "rank": "S", "failed": false, "no_fail": false, "total_notes": 204, "doubles": 20, "holds": 8, "new_record": true, "title": "STATIC BLOOM", "difficulty": 2, "new_best": true}, true)
				_go(r); step = 6
		6:
			if t > 3.2:
				_shot("result"); get_tree().quit()
