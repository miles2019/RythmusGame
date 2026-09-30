extends Node
## Autoload "GameFeel": the one place that decides *how strong* feedback is.
##
## Gameplay code says "a PERFECT happened at lane 2"; this manager turns that into
## camera trauma, hit-pause, sound and a `hit_fx` signal that visual layers (particles,
## rings, characters, HUD) listen to. All strengths live in RATINGS / the export vars
## below, and all of them are scaled by Settings (screen shake, reduced animation/particles).

signal hit_fx(rating: int, lane: int, pos: Vector2, profile: Dictionary)
signal miss_fx(lane: int, pos: Vector2)

enum Rating { PERFECT, GREAT, GOOD, MISS }

## Base timing windows in seconds (half-width). Multiplied by Settings.timing_scale.
const WINDOWS := [0.040, 0.080, 0.115]

## One row per rating: everything a hit can trigger, in one table.
const RATINGS := {
	Rating.PERFECT: {
		"name": "PERFECT", "color": Color("fff36b"), "score": 300, "stability": 1.6,
		"rings": 2, "particles": 18, "stars": 5, "pop": 0.32, "shake": 0.22,
		"hitstop": 0.055, "flash": 0.55, "pitch": 1.0, "sfx": "perfect", "camera_zoom": 0.018,
	},
	Rating.GREAT: {
		"name": "GREAT", "color": Color("5cffc4"), "score": 200, "stability": 0.9,
		"rings": 1, "particles": 10, "stars": 0, "pop": 0.22, "shake": 0.08,
		"hitstop": 0.0, "flash": 0.3, "pitch": 1.0, "sfx": "great", "camera_zoom": 0.006,
	},
	Rating.GOOD: {
		"name": "GOOD", "color": Color("6fb7ff"), "score": 100, "stability": 0.3,
		"rings": 0, "particles": 4, "stars": 0, "pop": 0.12, "shake": 0.0,
		"hitstop": 0.0, "flash": 0.12, "pitch": 1.0, "sfx": "good", "camera_zoom": 0.0,
	},
	Rating.MISS: {
		"name": "MISS", "color": Color("ff5a7a"), "score": 0, "stability": -8.0,
		"rings": 0, "particles": 5, "stars": 0, "pop": 0.0, "shake": 0.32,
		"hitstop": 0.0, "flash": 0.0, "pitch": 1.0, "sfx": "miss", "camera_zoom": 0.0,
	},
}

## Rating-specific shape id used by HUD icons so rating is never colour-only.
const RATING_SHAPES := {Rating.PERFECT: "star", Rating.GREAT: "diamond", Rating.GOOD: "circle", Rating.MISS: "cross"}

@export var shake_max_px := 9.0        ## hard cap so lanes stay readable
@export var shake_decay := 2.6         ## trauma lost per second
@export var hitstop_max := 0.08        ## never freeze character animation longer than this

var difficulty_scale := 1.0            ## set per song from Difficulty.WINDOW_SCALE
var trauma := 0.0
var _hitstop := 0.0
var _pools: Dictionary = {}
var _pool_cursor: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [Settings.BUS_UI, Settings.BUS_HITS, Settings.BUS_VOICE]:
		var arr: Array[AudioStreamPlayer] = []
		for i in (8 if bus == Settings.BUS_HITS else 4):
			var p := AudioStreamPlayer.new()
			p.bus = bus
			add_child(p)
			arr.append(p)
		_pools[bus] = arr
		_pool_cursor[bus] = 0


func _process(delta: float) -> void:
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_hitstop = maxf(_hitstop - delta, 0.0) # real time: process_mode is ALWAYS, no time_scale games


## Clears everything that could linger between songs/restarts.
func reset() -> void:
	trauma = 0.0
	_hitstop = 0.0


# ---------------------------------------------------------------- camera + hit-pause

func add_trauma(amount: float) -> void:
	if Settings.screen_shake:
		trauma = minf(trauma + amount, 1.0)


## Current shake offset in pixels; quadratic so small trauma stays subtle.
func shake_offset() -> Vector2:
	if not Settings.screen_shake or trauma <= 0.0:
		return Vector2.ZERO
	var s := trauma * trauma * shake_max_px
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * s


## Hit-pause freezes *character/stage animation* only. The song clock and notes
## are never paused, otherwise the visuals would lie about the timing.
func request_hitstop(seconds: float) -> void:
	seconds *= Settings.motion_scale()
	_hitstop = minf(maxf(_hitstop, seconds), hitstop_max)


func anim_scale() -> float:
	return 0.0 if _hitstop > 0.0 else 1.0


# ---------------------------------------------------------------- central hit dispatch

func window_for(rating: int) -> float:
	return WINDOWS[rating] * Settings.timing_scale * difficulty_scale


func trigger_hit(rating: int, lane: int, pos: Vector2, combo: int) -> void:
	var prof: Dictionary = RATINGS[rating]
	add_trauma(prof.shake)
	request_hitstop(prof.hitstop)
	# Slight pitch climb with combo makes streaks audibly rewarding.
	var pitch: float = prof.pitch * (1.0 + minf(combo, 50) * 0.002) * [0.94, 1.0, 1.06, 1.12][lane]
	play_sfx(prof.sfx, Settings.BUS_HITS, pitch)
	hit_fx.emit(rating, lane, pos, prof)


func trigger_miss(lane: int, pos: Vector2) -> void:
	var prof: Dictionary = RATINGS[Rating.MISS]
	add_trauma(prof.shake)
	request_hitstop(0.06)
	play_sfx("smack", Settings.BUS_HITS)
	play_sfx("miss", Settings.BUS_HITS)
	miss_fx.emit(lane, pos)


# ---------------------------------------------------------------- audio helper

func play_sfx(sfx_name: String, bus := "UI", pitch := 1.0, volume_db := 0.0) -> void:
	var stream := Synth.sfx(sfx_name)
	if stream == null or not _pools.has(bus):
		return # missing asset must never crash
	var arr: Array = _pools[bus]
	var i: int = _pool_cursor[bus]
	_pool_cursor[bus] = (i + 1) % arr.size()
	var p: AudioStreamPlayer = arr[i]
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# ---------------------------------------------------------------- tween helpers

## Returns a fresh tween bound to `node`; any earlier tween in the same slot is killed,
## so re-triggering an effect can never stack or leave the node in a half state.
func new_tween(node: Node, slot: String) -> Tween:
	var key := "_tw_" + slot
	if node.has_meta(key):
		var old: Variant = node.get_meta(key)
		if old is Tween and old.is_valid():
			old.kill()
	var tw := node.create_tween()
	node.set_meta(key, tw)
	return tw


func _base_scale(node: CanvasItem) -> Vector2:
	if not node.has_meta("_base_scale"):
		node.set_meta("_base_scale", node.scale)
	return node.get_meta("_base_scale")


func set_base_scale(node: CanvasItem, s: Vector2) -> void:
	node.set_meta("_base_scale", s)
	node.scale = s


func _center_pivot(node: CanvasItem) -> void:
	if node is Control:
		node.pivot_offset = node.size * 0.5


## Punch up then spring back with overshoot.
func pop(node: CanvasItem, strength := 0.25, dur := 0.32) -> void:
	if not is_instance_valid(node):
		return
	_center_pivot(node)
	var base := _base_scale(node)
	node.scale = base * (1.0 + strength * Settings.motion_scale())
	new_tween(node, "scale").tween_property(node, "scale", base, dur) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Squash (sx,sy multipliers) then release with elastic overshoot.
func squash(node: CanvasItem, sx: float, sy: float, dur := 0.4) -> void:
	if not is_instance_valid(node):
		return
	_center_pivot(node)
	var m := Settings.motion_scale()
	var base := _base_scale(node)
	node.scale = base * Vector2(lerpf(1.0, sx, m), lerpf(1.0, sy, m))
	new_tween(node, "scale").tween_property(node, "scale", base, dur) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func flash(node: CanvasItem, color: Color, dur := 0.18) -> void:
	if not is_instance_valid(node):
		return
	node.modulate = color
	new_tween(node, "flash").tween_property(node, "modulate", Color.WHITE, dur)


## Bouncy, sticky button: hover grows, press squashes, release overshoots.
func juice_button(btn: Control) -> void:
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.pivot_offset = btn.size * 0.5
	var grow := func(amount: float, sound: bool):
		if sound:
			play_sfx("ui_move")
		var m := Settings.motion_scale()
		new_tween(btn, "scale").tween_property(btn, "scale", Vector2.ONE * (1.0 + amount * m), 0.28) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	btn.mouse_entered.connect(func(): grow.call(0.08, true))
	btn.focus_entered.connect(func(): grow.call(0.08, true))
	btn.mouse_exited.connect(func(): if not btn.has_focus(): grow.call(0.0, false))
	btn.focus_exited.connect(func(): grow.call(0.0, false))
	if btn is BaseButton:
		btn.button_down.connect(func():
			new_tween(btn, "scale").tween_property(btn, "scale", Vector2.ONE.lerp(Vector2(1.06, 0.88), Settings.motion_scale()), 0.06))
		btn.button_up.connect(func(): grow.call(0.08, false))
		btn.pressed.connect(func(): play_sfx("ui_confirm"))
