class_name SongScene
extends Node2D
## One playable song (built-in or uploaded). Wires the pieces together and owns scoring:
##   input event -> NoteLane (timing evaluation) -> signals -> score + GameFeel + visuals.
## Input detection, timing evaluation and feedback are deliberately three separate steps.

signal note_hit(note: Note, rating: int, dt: float)
signal note_missed(note: Note)
signal combo_changed(combo: int)
signal beat_reached(beat: int)
signal song_started
signal song_finished(result: Dictionary)
signal restart_requested
signal quit_requested

enum Phase { COUNT_IN, PLAYING, FINISHED }

const NOTE_SCENE := preload("res://scenes/Note.tscn")
const LANE_SCENE := preload("res://scenes/NoteLane.tscn")
const HOLD_TAIL_SCORE := 150
const DOUBLE_BONUS := 100
const RIVAL_COLORS := {"gum": Color("ffd23f"), "kuro": Color("35e6ff"), "null": Color("ff3b3b"), "clock": Color("b6ff4a")}

@onready var stage: Stage = $Stage
@onready var camera: CameraRig = $Camera
@onready var lanes_root: Node2D = $Lanes
@onready var player: PlayerCharacter = $Player
@onready var rival: RivalCharacter = $Rival
@onready var fx: FxLayer = $Fx
@onready var hud: HUD = $HUD
@onready var post_fx: PostFX = $PostFX
@onready var clock: BeatClock = $BeatClock
@onready var music: AudioStreamPlayer = $Music
@onready var pause_menu: PauseMenu = $PauseMenu

var phase := Phase.COUNT_IN
var no_fail := false
var lanes: Array[NoteLane] = []
var info: Dictionary = {}
var diff := Difficulty.NORMAL

var score := 0
var combo := 0
var max_combo := 0
var stability := 60.0
var counts := [0, 0, 0, 0] # perfect, great, good, miss
var doubles := 0
var holds_ok := 0
var pause_on_focus_loss := true

var _chart: Array[Dictionary] = []
var _spawned: Array = []
var _next_spawn := 0
var _section := -1
var _sections: Array = []
var _perfect_streak := 0
var _record_at_start := 0
var _finishing := false
var _injury := 0.0 # sticks to the player: every miss leaves a mark, hits heal slowly


func _ready() -> void:
	for i in 4:
		var l: NoteLane = LANE_SCENE.instantiate()
		lanes_root.add_child(l)
		l.setup(i, NOTE_SCENE)
		l.note_hit.connect(_on_note_hit)
		l.note_missed.connect(_on_note_missed)
		l.hold_finished.connect(_on_hold_finished)
		l.ghost_press.connect(_on_ghost_press)
		lanes.append(l)
	clock.beat_reached.connect(_on_beat)
	clock.bar_reached.connect(_on_bar)
	clock.song_finished.connect(_on_clock_finished)
	clock.song_started.connect(func(): song_started.emit())
	pause_menu.resume_finished.connect(_on_resume)
	pause_menu.restart_pressed.connect(func(): restart_requested.emit())
	pause_menu.quit_pressed.connect(func(): quit_requested.emit())
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	# Make sure nothing leaks past this scene: pause flag, shake, hit-pause, difficulty windows.
	get_tree().paused = false
	GameFeel.reset()
	GameFeel.difficulty_scale = 1.0
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


## Starts (or restarts) the song from a fully clean state.
func begin(song_info: Dictionary, difficulty: int, no_fail_mode := false) -> void:
	info = song_info
	diff = difficulty
	no_fail = no_fail_mode
	GameFeel.reset()
	GameFeel.difficulty_scale = Difficulty.WINDOW_SCALE[diff]
	stage.reset()
	camera.reset()
	fx.clear()
	hud.reset()
	post_fx.reset()
	player.reset()
	rival.reset()
	rival.set_variant(info.rival)
	for l in lanes:
		l.reset()
	score = 0; combo = 0; max_combo = 0; stability = 60.0; doubles = 0; holds_ok = 0; _injury = 0.0
	counts = [0, 0, 0, 0]
	_perfect_streak = 0
	_next_spawn = 0
	_section = -1
	_finishing = false
	phase = Phase.COUNT_IN
	_record_at_start = _load_record()
	_sections = info.sections

	stage.theme = info.theme
	stage.stability = stability
	hud.set_rival(info.rival, RIVAL_COLORS.get(info.rival, UIKit.CYAN))
	hud.set_difficulty("%s  %s" % [info.title, Difficulty.NAMES[diff]], Difficulty.COLORS[diff])

	clock.bpm = info.bpm
	clock.first_beat = info.offset
	clock.song_bars = info.bars
	clock.length_override = info.duration if info.custom else 0.0
	_chart = Chart.build(info, diff)
	_spawned.clear()
	_spawned.resize(_chart.size())

	var stream: AudioStream = null
	var length := 100.0
	if info.custom:
		stream = CustomSongs.load_stream(info)
		length = info.duration
	else:
		var song := Synth.get_song(info)
		stream = song.get("full", null)
		length = song.get("length", 100.0)
	music.stream = stream
	music.volume_db = 0.0
	if stream == null:
		push_warning("SongScene: no music stream, running silent on the clock only")
	clock.start(music, length)
	player.set_state(Character.State.INTRO)
	rival.set_state(Character.State.INTRO)
	hud.set_stability(stability)
	hud.set_accent(_sections[0].accent)
	stage.accent = _sections[0].accent
	_update_damage()
	hud.show_banner("GET READY", UIKit.CYAN)


func _process(_delta: float) -> void:
	if phase == Phase.FINISHED:
		return
	var t := clock.time()
	if phase == Phase.COUNT_IN and t >= 0.0:
		phase = Phase.PLAYING
	# spawn notes that enter the visible approach window
	var lead := lanes[0].approach_time()
	while _next_spawn < _chart.size() and _chart[_next_spawn].time - lead <= t:
		_spawn(_next_spawn)
		_next_spawn += 1
	var pulse := 1.0 + 0.08 * pow(1.0 - clock.beat_phase(), 3.0) # notes "breathe" on the beat
	for l in lanes:
		l.update_lane(t, pulse)
	stage.beat_pos = clock.beat_position()
	hud.set_progress(clampf(t / clock.song_length(), 0.0, 1.0))
	# a stability of 0 ends the run (unless practice mode)
	if not no_fail and stability <= 0.0 and not _finishing:
		_finish(true)


func _spawn(i: int) -> void:
	var data := _chart[i]
	var n := lanes[data.lane].add_note(data)
	_spawned[i] = n
	var p: int = data.pair
	if p >= 0 and p < i and is_instance_valid(_spawned[p]):
		n.pair = _spawned[p]
		_spawned[p].pair = n


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if phase == Phase.FINISHED:
		return
	if event.is_action_pressed("ui_cancel"):
		_pause()
		get_viewport().set_input_as_handled()
		return
	var lane := Settings.input_profile.lane_for_event(event)
	if lane < 0:
		return
	# clock.time() extrapolates to *now*, so the press is judged at its real moment.
	if event.is_pressed():
		lanes[lane].press(clock.time())
	else:
		lanes[lane].release(clock.time())
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and phase != Phase.FINISHED and not get_tree().paused:
		_pause() # losing focus mid-song must not cost the player a run


func _pause() -> void:
	if get_tree().paused or _finishing:
		return
	get_tree().paused = true
	pause_menu.open()


func _on_resume() -> void:
	# Keys may have been released while paused; resync so no lane is stuck "down".
	for l in lanes:
		l.cancel_input(clock.time())
	get_tree().paused = false


func _on_settings_changed() -> void:
	clock.latency = Settings.latency_ms / 1000.0


# ------------------------------------------------------------------ judgement results

func _note_pos(lane: int) -> Vector2:
	return lanes[lane].position + Vector2(0, NoteLane.HIT_Y)


func _on_note_hit(note: Note, rating: int, dt: float) -> void:
	var prof: Dictionary = GameFeel.RATINGS[rating]
	counts[rating] += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	var gain := int(prof.score * (1.0 + minf(combo, 100) / 100.0) * Difficulty.SCORE_SCALE[diff])
	score += gain
	_injury = maxf(_injury - 0.012, 0.0) # hits slowly heal
	_change_stability(prof.stability * Difficulty.GAIN_SCALE[diff])
	# Double bonus: both partners hit -> extra points + text.
	if note.pair != null and is_instance_valid(note.pair) and note.pair.state != Note.State.PENDING \
			and note.pair.state != Note.State.MISSED:
		score += DOUBLE_BONUS
		doubles += 1
		fx.float_text(_note_pos(note.lane) + Vector2(0, -130), "DOUBLE!", Color("fff36b"), 34, 0.8, true)
	var pos := _note_pos(note.lane)
	GameFeel.trigger_hit(rating, note.lane, pos, combo)
	player.hit(note.lane, rating)
	if note.dur > 0.0:
		player.hold_pose(note.lane, true)
	# paint splat on the backdrop + combo-driven speed lines
	stage.add_splat(pos + Vector2(0, -200), prof.color if rating <= GameFeel.Rating.GREAT else Settings.lane_color(note.lane))
	stage.combo_fx = clampf((combo - 20) / 60.0, 0.0, 1.0)
	if rating == GameFeel.Rating.PERFECT:
		post_fx.shock(Vector2(pos.x / 1280.0, pos.y / 720.0))
	# rival takes punishment proportional to how well the player is doing
	rival.damage = clampf((counts[0] + counts[1] * 0.6) / maxf(_chart.size() * 0.75, 1.0), 0.0, 0.9)
	# Rival reacts to a run of perfects with a stagger.
	if rating == GameFeel.Rating.PERFECT:
		_perfect_streak += 1
		if _perfect_streak % 4 == 0:
			rival.hurt(0.7)
			GameFeel.play_sfx("voice_ouch", Settings.BUS_VOICE, 0.8)
			fx.float_text(Vector2(1080, 420), "OOF!", Color("ffb03b"), 34, 0.6, true)
	else:
		_perfect_streak = 0
	stage.beat_pulse(0.35 if rating == GameFeel.Rating.PERFECT else 0.15)
	hud.show_rating(rating, dt)
	hud.set_score(score)
	hud.set_combo(combo)
	combo_changed.emit(combo)
	_check_combo_banner()
	note_hit.emit(note, rating, dt)


func _on_note_missed(note: Note) -> void:
	counts[GameFeel.Rating.MISS] += 1
	_perfect_streak = 0
	var had_combo := combo > 0
	combo = 0
	stage.combo_fx = 0.0
	_injury = minf(_injury + 0.09, 1.0)
	_change_stability(GameFeel.RATINGS[GameFeel.Rating.MISS].stability * Difficulty.LOSS_SCALE[diff])
	GameFeel.trigger_miss(note.lane, _note_pos(note.lane))
	_player_takes_damage()
	rival.set_state(Character.State.VICTORY, 0.6) # smug little taunt
	stage.shudder()
	hud.show_rating(GameFeel.Rating.MISS)
	if had_combo:
		hud.set_combo(0)
	combo_changed.emit(0)
	note_missed.emit(note)


## The player's figure visibly gets hit: recoil, impact star, paint splatter, damage marks.
func _player_takes_damage() -> void:
	player.miss()
	var body_pos := player.position + Vector2(0, -150)
	fx.float_text(player.position + Vector2(60, -260), ["OUCH!", "OOF!", "BONK!", "YIKES!"][randi() % 4], Color("ff5a7a"), 40, 0.7, true)
	fx.burst(body_pos, player.blood, 14, 380.0, 8.0, 0.5, Vector2.UP, TAU)
	fx.burst(body_pos, Color("fff36b"), 6, 300.0, 6.0, 0.4, Vector2.UP, TAU, 1)
	fx.ring(body_pos, Color("ff5a7a"), 10.0, 90.0, 0.3, 6.0)
	stage.add_splat(player.position + Vector2(40, -120), player.blood, 55.0)
	GameFeel.play_sfx("voice_ouch", Settings.BUS_VOICE, 1.1)
	post_fx.shock(Vector2(player.position.x / 1280.0, 0.6))
	_update_damage()


func _update_damage() -> void:
	var d := clampf(maxf((55.0 - stability) / 55.0, _injury), 0.0, 1.0)
	player.damage = d
	post_fx.set_damage(d * 0.85)


func _on_hold_finished(note: Note, success: bool) -> void:
	player.hold_pose(note.lane, false)
	var pos := _note_pos(note.lane)
	if success:
		holds_ok += 1
		score += int(HOLD_TAIL_SCORE * Difficulty.SCORE_SCALE[diff])
		_change_stability(1.0 * Difficulty.GAIN_SCALE[diff])
		hud.set_score(score)
		fx.float_text(pos + Vector2(0, -130), "HOLD!", Color("5cffc4"), 34, 0.7, true)
		fx.ring(pos, Color("5cffc4"), 20.0, 80.0, 0.3, 6.0)
		fx.burst(pos, Color("5cffc4"), 8, 320.0, 6.0, 0.4)
		GameFeel.add_trauma(0.08)
		GameFeel.play_sfx("great", Settings.BUS_HITS, 1.25)
	else:
		_change_stability(-3.0 * Difficulty.LOSS_SCALE[diff])
		fx.float_text(pos + Vector2(0, -90), "DROPPED", Color("ff5a7a"), 26, 0.6)
		GameFeel.play_sfx("miss", Settings.BUS_HITS, 1.3)


func _on_ghost_press(lane: int) -> void:
	# A press with no note nearby is free (no penalty) but never silent: tiny tick + puff.
	GameFeel.play_sfx("tick", Settings.BUS_HITS, 0.9 + lane * 0.08, -8.0)
	fx.burst(_note_pos(lane), Settings.lane_color(lane), 3, 120.0, 4.0, 0.25, Vector2.UP, 1.0)
	player.set_state(Character.State.INPUT_LEFT + lane)


func _change_stability(delta: float) -> void:
	stability = clampf(stability + delta, 0.0, 100.0)
	hud.set_stability(stability)
	stage.stability = stability
	_update_damage()


func _check_combo_banner() -> void:
	if combo >= 10 and combo % 10 == 0 and combo > _record_at_start:
		hud.show_banner("NEW COMBO RECORD  %d" % combo, UIKit.AMBER)
		GameFeel.play_sfx("record", Settings.BUS_HITS)
		GameFeel.play_sfx("voice_hey", Settings.BUS_VOICE)
		GameFeel.add_trauma(0.25)
		stage.impact(UIKit.AMBER)
	elif combo in [25, 50, 100, 150, 200]:
		hud.show_banner("%d COMBO!" % combo, UIKit.LIME)
		GameFeel.play_sfx("voice_hey", Settings.BUS_VOICE, 1.15)


# ------------------------------------------------------------------ beat + sections

func _on_beat(beat: int) -> void:
	var strong := beat % 4 == 0
	stage.beat_pulse(1.0 if strong else 0.5)
	camera.on_beat(strong)
	hud.beat()
	player.on_beat(strong)
	rival.on_beat(strong)
	for l in lanes:
		l.on_beat()
	# Drop section: the rival "plays" along with a lane pose on every second beat.
	if _section >= 0 and _sections[_section].name == "DROP" and beat % 2 == 0 and rival.is_free_for_beat():
		rival.set_state(Character.State.INPUT_LEFT + (beat / 2) % 4)
	if not info.custom and beat == 19 * 4 + 2:
		hud.show_banner("BREAK...", UIKit.HOT)
	beat_reached.emit(beat)


func _section_for_bar(bar: int) -> int:
	var idx := 0
	for i in _sections.size():
		if bar >= _sections[i].bar:
			idx = i
	return idx


func _on_bar(bar: int) -> void:
	var sec := _section_for_bar(bar)
	if sec == _section:
		return
	_section = sec
	var s: Dictionary = _sections[sec]
	stage.set_accent(s.accent)
	hud.set_accent(s.accent)
	hud.set_section(s.name)
	if bar == 0:
		return
	# One surprise per section.
	match s.name:
		"VERSE":
			hud.show_banner("GO!", UIKit.CYAN)
		"DROP":
			# For built-in songs the riser + impact are baked into the audio on this same bar.
			stage.impact(Color.WHITE)
			GameFeel.add_trauma(0.7)
			camera.punch(0.045)
			post_fx.kick(2.0)
			post_fx.shock(Vector2(0.5, 0.45))
			rival.hurt(1.0)
			hud.show_banner("DROP!", UIKit.AMBER)
		"BUILD-UP":
			hud.show_banner("BUILD-UP", UIKit.HOT)
		"FINAL RIFT":
			stage.impact(UIKit.LIME)
			GameFeel.add_trauma(0.35)
			hud.show_banner("FINAL RIFT", UIKit.LIME)
		"OUTRO":
			hud.show_banner("LAST BARS", Color("8f7bff"))


func _on_clock_finished() -> void:
	_finish(false)


# ------------------------------------------------------------------ finish

func _finish(failed: bool) -> void:
	if _finishing:
		return
	_finishing = true
	phase = Phase.FINISHED
	clock.stop()
	var judged: int = counts[0] + counts[1] + counts[2] + counts[3]
	var weighted: float = counts[0] + counts[1] * 0.8 + counts[2] * 0.5
	var accuracy := weighted / float(maxi(judged, 1))
	var completion := float(judged) / float(maxi(_chart.size(), 1))
	var rank := _rank_for(accuracy, failed, completion)
	var new_record := max_combo > _record_at_start
	if new_record:
		_save_record(max_combo)
	var good_run := not failed and rank != "D"
	if good_run:
		player.set_state(Character.State.VICTORY)
		rival.set_state(Character.State.DEFEAT)
		rival.damage = maxf(rival.damage, 0.8)
		GameFeel.play_sfx("voice_win", Settings.BUS_VOICE)
	else:
		player.set_state(Character.State.DEFEAT)
		player.damage = 1.0
		rival.set_state(Character.State.VICTORY)
		GameFeel.play_sfx("voice_lose", Settings.BUS_VOICE)
	var tw := GameFeel.new_tween(music, "fade")
	tw.tween_property(music, "volume_db", -40.0, 1.2)
	var result := {
		"score": score, "max_combo": max_combo, "counts": counts.duplicate(), "accuracy": accuracy,
		"rank": rank, "failed": failed, "no_fail": no_fail, "total_notes": _chart.size(),
		"doubles": doubles, "holds": holds_ok, "new_record": new_record,
		"song_id": info.id, "title": info.title, "difficulty": diff, "rival": info.rival, "custom": info.custom,
	}
	# Tween-based delay (bound to this node): dies with the scene, never fires after a restart.
	var delay := create_tween()
	delay.tween_interval(1.9)
	delay.tween_callback(func(): song_finished.emit(result))


static func _rank_for(accuracy: float, failed: bool, completion: float) -> String:
	if failed or completion < 0.5:
		return "D"
	if accuracy >= 0.95:
		return "S"
	if accuracy >= 0.88:
		return "A"
	if accuracy >= 0.75:
		return "B"
	if accuracy >= 0.6:
		return "C"
	return "D"


func _load_record() -> int:
	return Progress.max_combo


func _save_record(v: int) -> void:
	Progress.max_combo = v
	Progress.save_progress()
