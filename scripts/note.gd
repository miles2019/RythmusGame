class_name Note
extends Node2D
## One falling note. It owns only its data and drawing; the lane moves and judges it.

enum State { PENDING, HOLDING, DONE, MISSED }

var lane := 0
var time := 0.0         ## seconds on the song clock when it must be hit
var dur := 0.0          ## > 0 for hold notes
var kind := Chart.Kind.NORMAL
var pair: Note = null   ## double-note partner (lives in another lane)
var state := State.PENDING
var tail_px := 0.0      ## remaining hold tail in pixels, set by the lane
var pulse := 1.0        ## beat "breathing", set by the lane

const BASE_RADIUS := 42.0
const LANE_ANGLES := [-PI / 2.0, PI, 0.0, PI / 2.0] # left, down, up, right


static func arrow_points(lane_idx: int, r: float) -> PackedVector2Array:
	var base := [Vector2(0, -1), Vector2(0.95, 0.05), Vector2(0.42, 0.05), Vector2(0.42, 0.85),
			Vector2(-0.42, 0.85), Vector2(-0.42, 0.05), Vector2(-0.95, 0.05)]
	var pts := PackedVector2Array()
	for p in base:
		pts.append(p.rotated(LANE_ANGLES[lane_idx]) * r)
	return pts


func _ready() -> void:
	# Spawn pop: notes appear with a small elastic overshoot instead of just existing.
	GameFeel.pop(self, 0.35, 0.3)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := BASE_RADIUS * Settings.note_scale * pulse
	var col := Settings.lane_color(lane)
	var t := Time.get_ticks_msec() / 1000.0
	if dur > 0.0 and tail_px > 0.0:
		# Hold tail: a fat ribbon that breathes at the head and at the far end (out of phase).
		var w := r * 0.62 * (1.0 + 0.07 * sin(t * 11.0))
		var cap := r * 0.45 * (1.0 + 0.12 * sin(t * 11.0 + PI))
		var tc := col
		tc.a = 0.85
		var ink := UIKit.INK
		draw_rect(Rect2(-w - 3, -tail_px, w * 2 + 6, tail_px), ink)
		draw_circle(Vector2(0, -tail_px), w + 3, ink)
		draw_rect(Rect2(-w, -tail_px, w * 2, tail_px), tc)
		draw_circle(Vector2(0, -tail_px), w, tc)
		draw_circle(Vector2(0, -tail_px), cap, col.lightened(0.5))
	if state == State.HOLDING:
		draw_circle(Vector2.ZERO, r * 1.35, Color(1, 1, 1, 0.25 + 0.15 * sin(t * 18.0)))
	if kind == Chart.Kind.DOUBLE:
		draw_arc(Vector2.ZERO, r * 1.28, 0.0, TAU, 32, Color("fff36b"), 5.0, true)
		if pair != null and is_instance_valid(pair) and pair.time == time and pair.lane > lane:
			var d := to_local(pair.global_position)
			draw_line(Vector2.ZERO, d, UIKit.INK, 14.0)
			draw_line(Vector2.ZERO, d, Color("fff36b"), 7.0)
	var pts := arrow_points(lane, r)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, col)
	draw_polyline(outline, UIKit.INK, 7.0, true)
	draw_polyline(outline, Color.WHITE, 2.0, true)
	# glossy highlight = sticker feel
	draw_circle(Vector2(-r * 0.22, -r * 0.3).rotated(LANE_ANGLES[lane]) * 0.6, r * 0.13, Color(1, 1, 1, 0.75))
