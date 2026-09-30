class_name HUD
extends CanvasLayer
## Gameplay UI in comic-book style. Everything reacts (pop, spring, pulse) instead of just
## showing numbers. Side columns keep the lanes free; the tug-of-war bar at the top shows
## the rift stability with both fighters' faces reacting to who is winning.

const LEFT_X := 40.0
const COL_W := 350.0

var _root: Control
var _combo_num: Label
var _combo_cap: Label
var _combo_bg: BurstBG
var _rating: Label
var _icon: RatingIcon
var _timing: Label
var _score: Label
var _section: Label
var _banner: Label
var _banner_bg: BurstBG
var _bar: TugBar
var _progress: ProgressLine
var _pause_hint: Label
var _diff: Label
var _combo_shake := 0.0
var _fps: Label


## Comic face used in the tug-of-war bar. mood: 0 happy, 1 neutral, 2 hurt, 3 knocked out.
static func draw_face(ci: CanvasItem, c: Vector2, r: float, kind: String, mood: int) -> void:
	var skin := Color("ffd9c2")
	var hair := Color("ff4f8a")
	match kind:
		"gum":
			skin = Color("ffc2d9"); hair = Color("b6ff4a")
		"kuro":
			skin = Color("cfd8ff"); hair = Color("120a24")
		"null":
			skin = Color("f4f0e6"); hair = Color("120a24")
		"clock":
			skin = Color("8fa0b8"); hair = Color("3a4a64")
		"bolt":
			skin = Color("ffd9b8"); hair = Color("fff36b")
		"queen":
			skin = Color("f0c8d8"); hair = Color("7a2a9a")
		"brute":
			skin = Color("9ac27a"); hair = Color("2a2a2a")
		"core":
			skin = Color("2a1a44"); hair = Color("6a2aff")
	# hair / back shapes
	match kind:
		"mika":
			for s in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(r * 0.95 * s, r * 0.35), r * 0.3 + 3.0, UIKit.INK)
				ci.draw_circle(c + Vector2(r * 0.95 * s, r * 0.35), r * 0.3, hair)
		"gum", "bolt":
			for k in 3:
				var x := (k - 1) * r * 0.5
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - 6, -r * 0.8), c + Vector2(x, -r * 1.55), c + Vector2(x + 6, -r * 0.8)]), hair)
		"queen":
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 1.3 + 3.0, UIKit.INK)
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 1.3, hair)
		"core":
			for s in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6 * s, -r * 0.6), c + Vector2(r * 1.3 * s, -r * 1.6), c + Vector2(r * 0.9 * s, -r * 0.4)]), hair)
		"kuro":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.2), c + Vector2(-r * 0.6, -r * 1.45), c + Vector2(0, -r * 0.9),
					c + Vector2(r * 0.6, -r * 1.5), c + Vector2(r, -r * 0.2)]), hair)
	if kind == "clock":
		ci.draw_rect(Rect2(c.x - r - 3, c.y - r * 0.85 - 3, r * 2 + 6, r * 1.7 + 6), UIKit.INK)
		ci.draw_rect(Rect2(c.x - r, c.y - r * 0.85, r * 2, r * 1.7), skin)
		ci.draw_rect(Rect2(c.x - r * 0.8, c.y - r * 0.65, r * 1.6, r * 1.3), Color("0e1a14"))
	else:
		ci.draw_circle(c, r + 3.0, UIKit.INK)
		ci.draw_circle(c, r, skin)
		match kind:
			"mika":
				ci.draw_arc(c, r * 0.95, PI * 1.1, PI * 1.9, 10, Color("35e6ff"), 5.0, true)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.5, -r * 1.0), c + Vector2(0, -r * 0.5),
						c + Vector2(r * 0.5, -r * 1.0), c + Vector2(r, -r * 0.3), c + Vector2(0, -r * 0.4)]), hair)
			"kuro":
				pass
	# eyes / mouth by mood
	var ec := Color("1a0f2e") if kind != "clock" else Color("b6ff4a")
	if kind == "null":
		ec = Color("ff3b3b")
	var ex := r * 0.38
	var ey := -r * 0.05
	match mood:
		0:
			for s in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(ex * s, ey + 2), r * 0.2, PI, TAU, 8, ec, 3.5, true)
			ci.draw_arc(c + Vector2(0, r * 0.35), r * 0.35, 0.2, PI - 0.2, 10, ec, 3.5, true)
		1:
			for s in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(ex * s, ey), r * 0.17, ec)
			ci.draw_line(c + Vector2(-r * 0.25, r * 0.45), c + Vector2(r * 0.25, r * 0.45), ec, 3.5)
		2:
			for s in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(ex * s - 5 * s, ey - 6), c + Vector2(ex * s + 4 * s, ey), c + Vector2(ex * s - 5 * s, ey + 6)]), ec, 3.5, true)
			ci.draw_circle(c + Vector2(0, r * 0.5), r * 0.2, ec)
			# plaster
			ci.draw_rect(Rect2(c.x + r * 0.15, c.y + r * 0.1, r * 0.6, r * 0.22), Color("ffd9a8"))
		3:
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(ex * s - 5, ey - 5), c + Vector2(ex * s + 5, ey + 5), ec, 3.5)
				ci.draw_line(c + Vector2(ex * s - 5, ey + 5), c + Vector2(ex * s + 5, ey - 5), ec, 3.5)
			ci.draw_line(c + Vector2(-r * 0.25, r * 0.5), c + Vector2(r * 0.25, r * 0.5), ec, 3.5)


## Yellow comic starburst behind a label; pops with the label.
class BurstBG extends Control:
	var fill := Color("fff36b")
	var spikes := 11
	var spin := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var pts := UIKit.burst_points(c, size.x * 0.5, size.x * 0.36, spikes, spin)
		draw_colored_polygon(pts, fill)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, UIKit.INK, 6.0, true)


class RatingIcon extends Control:
	var shape := "star"
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		size = Vector2(44, 44)

	func _draw() -> void:
		var c := size * 0.5
		var r := 17.0
		var pts := PackedVector2Array()
		match shape:
			"star":
				for i in 10:
					pts.append(c + Vector2.from_angle(i * PI / 5.0 - PI / 2.0) * (r if i % 2 == 0 else r * 0.45))
			"diamond":
				pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			"circle":
				for i in 20:
					pts.append(c + Vector2.from_angle(i * TAU / 20.0) * r * 0.85)
			"cross":
				draw_line(c + Vector2(-r, -r), c + Vector2(r, r), UIKit.INK, 12.0)
				draw_line(c + Vector2(-r, r), c + Vector2(r, -r), UIKit.INK, 12.0)
				draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, 6.0)
				draw_line(c + Vector2(-r, r), c + Vector2(r, -r), color, 6.0)
				return
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_colored_polygon(pts, color)
		draw_polyline(loop, UIKit.INK, 4.0, true)


## FNF-style tug-of-war bar: stability fills from the player's side, faces ride the boundary.
class TugBar extends Control:
	var value := 60.0
	var shown := 60.0
	var pulse := 0.0
	var left_col := Color("ff8a3d")
	var right_col := Color("35e6ff")
	var rival_kind := "kuro"

	func _init() -> void:
		custom_minimum_size = Vector2(600, 30)
		size = Vector2(600, 30)

	func _process(delta: float) -> void:
		shown = lerpf(shown, value, clampf(delta * 10.0, 0.0, 1.0))
		pulse = maxf(pulse - delta * 4.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var f := clampf(shown / 100.0, 0.0, 1.0)
		draw_rect(Rect2(-6, -6, size.x + 12, size.y + 12), UIKit.INK)
		draw_rect(Rect2(0, 0, size.x, size.y), right_col.darkened(0.15))
		var w := size.x * f
		draw_rect(Rect2(0, 0, w, size.y), left_col.lerp(Color.WHITE, pulse * 0.35))
		for i in range(1, 10):
			draw_line(Vector2(size.x * i / 10.0, 0), Vector2(size.x * i / 10.0, size.y), Color(UIKit.INK, 0.5), 2.0)
		draw_line(Vector2(w, -4), Vector2(w, size.y + 4), UIKit.INK, 6.0)
		# faces sit on the boundary and squash with the beat
		var s := 1.0 + pulse * 0.12
		var pm := 0 if f > 0.66 else (1 if f > 0.33 else (2 if f > 0.12 else 3))
		var rm := 3 if f > 0.9 else (2 if f > 0.66 else (1 if f > 0.33 else 0))
		var cy := size.y * 0.5 - 4.0
		HUD.draw_face(self, Vector2(clampf(w - 28.0, 28.0, size.x - 80.0), cy), 22.0 * s, "mika", pm)
		HUD.draw_face(self, Vector2(clampf(w + 28.0, 80.0, size.x - 28.0), cy), 22.0 * s, rival_kind, rm)
		if f < 0.25 and int(Time.get_ticks_msec() / 250) % 2 == 0:
			# text warning so "low" is never colour-only
			var font := UIKit.font()
			draw_string_outline(font, Vector2(size.x * 0.5 - 60, size.y + 28), "DANGER!", HORIZONTAL_ALIGNMENT_CENTER, 120, 24, 6, UIKit.INK)
			draw_string(font, Vector2(size.x * 0.5 - 60, size.y + 28), "DANGER!", HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color("ff5a7a"))


class ProgressLine extends Control:
	var frac := 0.0
	var accent := Color("35e6ff")

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(UIKit.INK, 0.85))
		draw_rect(Rect2(0, 0, size.x * clampf(frac, 0.0, 1.0), size.y), accent)
		draw_circle(Vector2(size.x * clampf(frac, 0.0, 1.0), size.y * 0.5), size.y * 0.9, Color.WHITE)


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_progress = ProgressLine.new()
	_progress.size = Vector2(1280, 8)
	_root.add_child(_progress)

	_bar = TugBar.new()
	_bar.position = Vector2(340, 34)
	_root.add_child(_bar)

	_section = _text("", 24, Vector2(LEFT_X, 22), COL_W, HORIZONTAL_ALIGNMENT_LEFT, UIKit.AMBER)
	_diff = _text("", 20, Vector2(LEFT_X, 50), COL_W, HORIZONTAL_ALIGNMENT_LEFT, UIKit.PAPER)
	_score = _text("0", 44, Vector2(900, 52), 340, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.PAPER)
	_text("SCORE", 20, Vector2(900, 28), 340, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.CYAN)

	_combo_bg = BurstBG.new()
	_combo_bg.position = Vector2(LEFT_X + 70, 88)
	_combo_bg.size = Vector2(210, 210)
	_combo_bg.fill = Color("ff4fa3")
	_root.add_child(_combo_bg)
	_combo_cap = _text("COMBO", 24, Vector2(LEFT_X, 130), COL_W, HORIZONTAL_ALIGNMENT_CENTER, UIKit.PAPER)
	_combo_num = _text("0", 92, Vector2(LEFT_X, 146), COL_W, HORIZONTAL_ALIGNMENT_CENTER, UIKit.PAPER)
	_combo_num.pivot_offset = Vector2(COL_W * 0.5, 60)

	_icon = RatingIcon.new()
	_icon.position = Vector2(LEFT_X + 10, 316)
	_root.add_child(_icon)
	_rating = _text("", 44, Vector2(LEFT_X + 56, 300), COL_W - 56, HORIZONTAL_ALIGNMENT_LEFT, UIKit.PAPER)
	_rating.pivot_offset = Vector2(60, 28)
	_timing = _text("", 22, Vector2(LEFT_X + 56, 350), COL_W - 56, HORIZONTAL_ALIGNMENT_LEFT, UIKit.PAPER)

	_banner_bg = BurstBG.new()
	_banner_bg.position = Vector2(950, 80)
	_banner_bg.size = Vector2(300, 300)
	_banner_bg.spikes = 13
	_root.add_child(_banner_bg)
	_banner = _text("", 32, Vector2(960, 190), 280, HORIZONTAL_ALIGNMENT_CENTER, UIKit.INK)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.size = Vector2(280, 100)
	_banner.pivot_offset = Vector2(140, 50)
	_banner.add_theme_constant_override("outline_size", 0)
	_banner.add_theme_constant_override("shadow_offset_x", 0)
	_banner.add_theme_constant_override("shadow_offset_y", 0)
	_banner_bg.pivot_offset = Vector2(150, 150)

	_pause_hint = _text("[ESC] PAUSE", 20, Vector2(900, 684), 340, HORIZONTAL_ALIGNMENT_RIGHT, UIKit.PAPER)
	_fps = _text("", 18, Vector2(LEFT_X, 690), 200, HORIZONTAL_ALIGNMENT_LEFT, UIKit.LIME)
	reset()


func _text(t: String, size: int, pos: Vector2, width: float, align: int, color: Color) -> Label:
	var l := UIKit.label(t, size, color)
	l.position = pos
	l.size = Vector2(width, size * 1.4)
	l.horizontal_alignment = align as HorizontalAlignment
	_root.add_child(l)
	return l


func reset() -> void:
	for n in [_combo_num, _rating, _banner, _banner_bg, _score, _combo_bg]:
		GameFeel.new_tween(n, "scale").kill()
		GameFeel.set_base_scale(n, Vector2.ONE)
		n.modulate = Color.WHITE
	_combo_num.text = "0"
	_combo_num.modulate = Color(1, 1, 1, 0.45)
	_combo_bg.visible = false
	_rating.text = ""
	_timing.text = ""
	_icon.visible = false
	_score.text = "0"
	_banner.modulate.a = 0.0
	_banner_bg.modulate.a = 0.0
	_bar.value = 60.0
	_bar.shown = 60.0
	_progress.frac = 0.0
	_combo_shake = 0.0
	_combo_num.position = Vector2(LEFT_X, 146)


## Who the player is fighting: rival face + bar colours.
func set_rival(kind: String, rival_color: Color) -> void:
	_bar.rival_kind = kind
	_bar.right_col = rival_color


func set_difficulty(text: String, color: Color) -> void:
	_diff.text = text
	_diff.add_theme_color_override("font_color", color)


func set_accent(c: Color) -> void:
	_progress.accent = c


func set_progress(f: float) -> void:
	_progress.frac = f
	_progress.queue_redraw()


func set_section(section_name: String) -> void:
	_section.text = section_name
	GameFeel.pop(_section, 0.35)


func set_score(s: int) -> void:
	_score.text = str(s)
	GameFeel.pop(_score, 0.12, 0.25)


func set_stability(v: float) -> void:
	_bar.value = v


func beat() -> void:
	_bar.pulse = 1.0


func set_combo(c: int) -> void:
	_combo_num.text = str(c)
	_combo_bg.visible = c >= 10
	if c > 0:
		_combo_num.modulate = Color.WHITE
		GameFeel.pop(_combo_num, 0.28 if c % 10 else 0.5, 0.35)
		if c >= 10:
			GameFeel.pop(_combo_bg, 0.25 if c % 10 else 0.5, 0.4)
			_combo_bg.spin = c * 0.1
			_combo_bg.queue_redraw()
	else:
		# Broken combo: quick, readable drop instead of a punishing animation.
		_combo_num.modulate = Color(1, 0.4, 0.5, 0.6)
		_combo_shake = 1.0
		GameFeel.squash(_combo_num, 0.85, 1.15, 0.3)


func show_rating(rating: int, dt := 0.0) -> void:
	var prof: Dictionary = GameFeel.RATINGS[rating]
	_rating.text = prof.name
	_rating.add_theme_color_override("font_color", prof.color)
	_icon.shape = GameFeel.RATING_SHAPES[rating]
	_icon.color = prof.color
	_icon.visible = true
	_icon.queue_redraw()
	# Early/late is spelled out, never conveyed by colour alone.
	if rating == GameFeel.Rating.PERFECT or rating == GameFeel.Rating.MISS:
		_timing.text = ""
	else:
		_timing.text = "EARLY" if dt < 0.0 else "LATE"
	GameFeel.pop(_rating, 0.4 * (1.0 if rating <= GameFeel.Rating.GREAT else 0.5), 0.3)
	GameFeel.pop(_icon, 0.5, 0.35)


func show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner_bg.fill = color
	_banner_bg.queue_redraw()
	for n in [_banner, _banner_bg]:
		n.modulate.a = 1.0
		n.scale = Vector2(0.3, 0.3)
		var tw := GameFeel.new_tween(n, "scale")
		tw.tween_property(n, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.0)
		tw.tween_property(n, "modulate:a", 0.0, 0.3)
	_banner_bg.rotation = randf_range(-0.12, 0.12)


func _process(delta: float) -> void:
	_fps.visible = Settings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _combo_shake > 0.0:
		_combo_shake = maxf(_combo_shake - delta * 4.0, 0.0)
		_combo_num.position.x = LEFT_X + sin(_combo_shake * 40.0) * 8.0 * _combo_shake * Settings.motion_scale()
	else:
		_combo_num.position.x = LEFT_X
