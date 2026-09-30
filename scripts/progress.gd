extends Node
## Autoload "Progress": story unlocks, best scores and the library of uploaded songs.

var save_path := "user://progress.cfg"  # tests point this elsewhere so they never touch real saves

var cleared: Array = []        ## built-in song ids finished in story mode
var best: Dictionary = {}      ## "song|difficulty" -> {score, rank, combo}
var custom: Array = []         ## uploaded songs (info-shaped dictionaries, see CustomSongs)
var difficulty := Difficulty.NORMAL
var story_seen_ending := false
var max_combo := 0             ## best combo ever (drives the "new record" banner)


func _ready() -> void:
	load_progress()


## Story chapter i is playable when the previous chapter was cleared.
func chapter_unlocked(i: int) -> bool:
	return i == 0 or cleared.has(Songs.LIST[i - 1].id)


## Classic/Replay: a song is free once its chapter was cleared (the first one is always free).
func replay_unlocked(i: int) -> bool:
	return i == 0 or cleared.has(Songs.LIST[i].id)


func mark_cleared(id: String) -> void:
	if not cleared.has(id):
		cleared.append(id)
		save_progress()


func best_for(id: String, diff: int) -> Dictionary:
	return best.get("%s|%d" % [id, diff], {})


## Stores the result if it is a new best; returns true then.
func record(id: String, diff: int, result: Dictionary) -> bool:
	var key := "%s|%d" % [id, diff]
	var old: Dictionary = best.get(key, {})
	if old.is_empty() or result.score > old.score:
		best[key] = {"score": result.score, "rank": result.rank, "combo": result.max_combo}
		save_progress()
		return true
	return false


func add_custom(info: Dictionary) -> void:
	var clean := {}
	for k in info:
		if not str(k).begins_with("_"): # runtime-only data (e.g. "_data") is never saved
			clean[k] = info[k]
	for i in custom.size():
		if custom[i].id == clean.id:
			custom[i] = clean # re-importing the same file replaces the entry
			save_progress()
			return
	custom.append(clean)
	save_progress()


func remove_custom(id: String) -> void:
	for i in custom.size():
		if custom[i].id == id:
			var path: String = custom[i].get("file", "")
			if path != "" and FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			custom.remove_at(i)
			break
	save_progress()


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("story", "cleared", cleared)
	cfg.set_value("story", "seen_ending", story_seen_ending)
	cfg.set_value("scores", "best", best)
	cfg.set_value("songs", "custom", custom)
	cfg.set_value("options", "difficulty", difficulty)
	cfg.set_value("records", "max_combo", max_combo)
	cfg.save(save_path)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	cleared = cfg.get_value("story", "cleared", [])
	story_seen_ending = cfg.get_value("story", "seen_ending", false)
	best = cfg.get_value("scores", "best", {})
	custom = cfg.get_value("songs", "custom", [])
	difficulty = int(cfg.get_value("options", "difficulty", Difficulty.NORMAL))
	max_combo = int(cfg.get_value("records", "max_combo", 0))
