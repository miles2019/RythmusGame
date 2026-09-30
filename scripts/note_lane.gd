class_name NoteLane
extends Node2D
## One input lane: receptor visuals, note movement and *timing evaluation*.
## It knows nothing about score, characters or camera — it only emits signals.

signal note_hit(note: Note, rating: int, dt: float)
signal note_missed(note: Note)
signal hold_finished(note: Note, success: bool)
signal ghost_press(lane: int)

const HIT_Y := 590.0
const TOP_Y := -70.0
const HOLD_RELEASE_GRACE := 0.12 ## releasing this close to the tail end still counts
const EARLY_MISS := 0.22        ## a press this early before a note burns that note

@export var lane_width := 112.0
@export var scroll_speed := 590.0 ## px/s, set per difficulty; approach time = (HIT_Y - TOP_Y) / speed

var lane := 0
var held: Note = null
var rec_scale := 1.0
var beat_glow := 0.0
var _active: Array[Note] = []
var _down := 0
var _note_scene: PackedScene
var _hint := ""
var _back: LaneBack


func setup(lane_index: int, note_scene: PackedScene) -> void:
	lane = lane_index
	_note_scene = note_scene
	lane_width = 112.0 * maxf(1.0, Settings.note_scale * 0.95) # big notes get wider lanes
	position = Vector2(640.0 + (lane - 1.5) * lane_width, 0.0)
	_back = LaneBack.new()
	_back.lane_node = self
	_back.show_behind_parent = true
	add_child(_back)
	refresh_hint()
	Settings.changed.connect(refresh_hint)


func _exit_tree() -> void:
	if Settings.changed.is_connected(refresh_hint):
		Settings.changed.disconnect(refresh_hint)


func refresh_hint() -> void:
	_hint = Settings.input_profile.lane_hint(lane)
	if _back:
		_back.queue_redraw()
	queue_redraw()

func approach_time() -> float:
	return (HIT_Y - TOP_Y) / scroll_speed


func reset() -> void:
	for n in _active:
		if is_instance_valid(n):
			n.queue_free()
	_active.clear()
	held = null
	_down = 0
	rec_scale = 1.0
	beat_glow = 0.0


func add_note(data: Dictionary) -> Note:
	var n: Note = _note_scene.instantiate()
	n.lane = lane
	n.time = data.time
	n.dur = data.dur
	n.kind = data.kind
	n.position = Vector2(0, TOP_Y)
	n.tail_px = n.dur * scroll_speed
	add_child(n)
	_active.append(n)
	return n


func on_beat() -> void:
	beat_glow = 1.0


func is_down() -> bool:
	return _down > 0


# ------------------------------------------------------------------ input -> judgement

## Called with the (latency-corrected, extrapolated) song time of the key press.
## Returns true if a note was hit.
func press(t: float) -> bool:
	_down += 1
	_press_visual()
	if held != null:
		return false # a second key for the same lane while holding: nothing to judge
	var good := GameFeel.window_for(GameFeel.Rating.GOOD)
	for n in _active:
		if n.state != Note.State.PENDING:
			continue
		var dt := t - n.time
		if dt < -good:
			# Pressed clearly too early for the nearest note: that note is lost (no spam-hitting
			# a note from afar). Further away than EARLY_MISS = a stray tap, handled below.
			if dt >= -EARLY_MISS:
				n.state = Note.State.MISSED
				n.modulate = Color(1, 1, 1, 0.4)
				note_missed.emit(n)
				return false
			break # sorted by time: everything after is even later
		if absf(dt) > good:
			continue # too late for this one, the miss check will collect it
		var rating := GameFeel.Rating.GOOD
		if absf(dt) <= GameFeel.window_for(GameFeel.Rating.PERFECT):
			rating = GameFeel.Rating.PERFECT
		elif absf(dt) <= GameFeel.window_for(GameFeel.Rating.GREAT):
			rating = GameFeel.Rating.GREAT
		if n.dur > 0.0:
			n.state = Note.State.HOLDING
			held = n
			n.position.y = HIT_Y
		else:
			n.state = Note.State.DONE
		note_hit.emit(n, rating, dt)
		return true
	ghost_press.emit(lane) # harmless: visual only, no penalty
	return false


func release(t: float) -> void:
	_down = maxi(_down - 1, 0)
	if _down > 0:
		return
	_release_visual()
	if held != null:
		var end := held.time + held.dur
		var ok := t >= end - HOLD_RELEASE_GRACE * Settings.timing_scale
		_finish_hold(ok)


## Drops any stuck key state (after pause / focus loss). A held note ends without penalty
## when the tail was nearly done, otherwise it counts as dropped.
func cancel_input(t: float) -> void:
	if _down == 0 and held == null:
		return
	_down = 1
	release(t)


func _finish_hold(success: bool) -> void:
	var n := held
	held = null
	n.state = Note.State.DONE if success else Note.State.MISSED
	hold_finished.emit(n, success)


# ------------------------------------------------------------------ per-frame update

func update_lane(t: float, pulse: float) -> void:
	var good := GameFeel.window_for(GameFeel.Rating.GOOD)
	for i in range(_active.size() - 1, -1, -1):
		var n := _active[i]
		n.pulse = pulse
		match n.state:
			Note.State.PENDING:
				n.position.y = HIT_Y - (n.time - t) * scroll_speed
				if t - n.time > good:
					n.state = Note.State.MISSED
					n.modulate = Color(1, 1, 1, 0.4)
					note_missed.emit(n)
			Note.State.HOLDING:
				n.position.y = HIT_Y
				n.tail_px = maxf((n.time + n.dur - t) * scroll_speed, 0.0)
				if t >= n.time + n.dur:
					_finish_hold(true) # held to the end: no need to release
			Note.State.MISSED:
				n.position.y = HIT_Y - (n.time - t) * scroll_speed
				n.modulate = Color(1, 1, 1, 0.4)
		if n.state == Note.State.DONE or (n.state == Note.State.MISSED and n.position.y - n.tail_px > 780.0):
			_active.remove_at(i)
			n.queue_free()
	beat_glow = maxf(beat_glow - 4.0 * get_process_delta_time(), 0.0)
	queue_redraw()


# ------------------------------------------------------------------ visuals

func _press_visual() -> void:
	rec_scale = 0.8
	GameFeel.new_tween(self, "rec").tween_property(self, "rec_scale", 1.0, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _release_visual() -> void:
	queue_redraw()


## Static lane decoration (strip, edges, key hint) in its own node: redrawn only when the key
## hints or colours change, not every frame.
class LaneBack extends Node2D:
	var lane_node: NoteLane

	func _draw() -> void:
		if lane_node == null:
			return
		var w := lane_node.lane_width
		var col := Settings.lane_color(lane_node.lane)
		var strip := UIKit.INK
		strip.a = 0.45
		draw_rect(Rect2(-w * 0.5, -60, w, 800), strip)
		var edge := col
		edge.a = 0.35
		draw_line(Vector2(-w * 0.5, -60), Vector2(-w * 0.5, 740), edge, 2.0)
		draw_line(Vector2(w * 0.5, -60), Vector2(w * 0.5, 740), edge, 2.0)
		# key hint: always visible, so the input display never depends on colour
		var font := UIKit.font()
		draw_string_outline(font, Vector2(-w * 0.5, HIT_Y + 84), lane_node._hint, HORIZONTAL_ALIGNMENT_CENTER, w, 20, 6, UIKit.INK)
		draw_string(font, Vector2(-w * 0.5, HIT_Y + 84), lane_node._hint, HORIZONTAL_ALIGNMENT_CENTER, w, 20, UIKit.PAPER)


func _draw() -> void:
	var w := lane_width
	var col := Settings.lane_color(lane)
	# press beam
	if _down > 0:
		var top := col
		top.a = 0.0
		var bot := col
		bot.a = 0.42
		draw_polygon(PackedVector2Array([Vector2(-w * 0.5, HIT_Y - 340), Vector2(w * 0.5, HIT_Y - 340),
				Vector2(w * 0.5, HIT_Y + 20), Vector2(-w * 0.5, HIT_Y + 20)]),
				PackedColorArray([top, top, bot, bot]))
	# hit line
	var hl := Color(1, 1, 1, 0.25 + beat_glow * 0.3)
	draw_line(Vector2(-w * 0.5, HIT_Y), Vector2(w * 0.5, HIT_Y), hl, 3.0)
	# receptor (outlined arrow, filled while pressed)
	var r := 40.0 * Settings.note_scale * rec_scale * (1.0 + beat_glow * 0.06)
	var pts := Note.arrow_points(lane, r)
	var loop := pts.duplicate()
	loop.append(pts[0])
	var c := col
	c.a = 0.85 if _down > 0 else 0.3 + beat_glow * 0.25
	if _down > 0:
		draw_circle(Vector2(0, HIT_Y), r * 1.5, Color(col.r, col.g, col.b, 0.25))
	draw_set_transform(Vector2(0, HIT_Y))
	draw_colored_polygon(pts, c)
	draw_polyline(loop, UIKit.INK, 8.0)
	draw_polyline(loop, col.lightened(0.3), 3.0)
	draw_set_transform(Vector2.ZERO)
