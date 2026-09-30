class_name SongCard
extends Button
## A selectable trading-card for a song / story chapter / the "upload" slot.
## Content is drawn on top of the button style, so focus, hover and press feedback
## (scale bounce, loud outline) come from the shared button juice.

var data: Dictionary = {}
var locked := false
var is_import := false
var chapter_no := 0          ## 1-based story chapter number, 0 = none
var status := ""             ## "NEW!", "CLEARED", ""
var best_rank := ""
var best_score := 0
var accent := UIKit.HOT


func setup(song: Dictionary, accent_color: Color) -> void:
	data = song
	accent = accent_color
	custom_minimum_size = Vector2(250, 360)
	add_theme_stylebox_override("normal", UIKit.box(UIKit.PANEL, accent, 6, 14, 8))
	add_theme_stylebox_override("hover", UIKit.box(UIKit.PANEL.lightened(0.12), UIKit.PAPER, 7, 14, 10))
	add_theme_stylebox_override("focus", UIKit.box(UIKit.PANEL.lightened(0.18), UIKit.YELLOW, 8, 14, 12))
	add_theme_stylebox_override("pressed", UIKit.box(UIKit.PANEL.darkened(0.1), UIKit.PAPER, 7, 14, 3))
	focus_mode = Control.FOCUS_ALL
	text = ""
	GameFeel.juice_button(self)


func _draw() -> void:
	var font := UIKit.font()
	var w := size.x
	if is_import:
		draw_circle(Vector2(w * 0.5, 130), 62.0, UIKit.INK)
		draw_circle(Vector2(w * 0.5, 130), 56.0, UIKit.LIME)
		draw_rect(Rect2(w * 0.5 - 7, 100, 14, 60), UIKit.INK)
		draw_rect(Rect2(w * 0.5 - 30, 123, 60, 14), UIKit.INK)
		_text(font, "UPLOAD MUSIC", Vector2(14, 250), w - 28, 30, UIKit.PAPER)
		_text(font, "mp3 / ogg / wav", Vector2(14, 310), w - 28, 20, UIKit.CYAN)
		return
	var centre := Vector2(w * 0.5, 120)
	if locked:
		draw_circle(centre, 62.0, UIKit.INK)
		draw_circle(centre, 56.0, Color("3a2d5c"))
		_text(font, "?", Vector2(0, 62), w, 100, Color("9a88cc"), 1, HORIZONTAL_ALIGNMENT_CENTER)
		_text(font, "LOCKED", Vector2(14, 250), w - 28, 34, Color("8f7bff"))
		_text(font, "clear the story chapter", Vector2(14, 300), w - 28, 18, Color("6f5f99"))
		return
	# rival portrait on a burst
	var pts := UIKit.burst_points(centre, 82.0, 62.0, 10, 0.2)
	draw_colored_polygon(pts, accent)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, UIKit.INK, 5.0, true)
	HUD.draw_face(self, centre + Vector2(0, 4), 44.0, data.get("rival", "kuro"), 0)
	if chapter_no > 0:
		_text(font, "CH.%d" % chapter_no, Vector2(10, 12), 120, 28, UIKit.YELLOW)
	_text(font, str(data.get("title", "?")), Vector2(12, 222), w - 24, 30, UIKit.PAPER, 2)
	_text(font, "%d BPM" % int(round(float(data.get("bpm", 0)))), Vector2(12, 296), w - 24, 22, UIKit.CYAN)
	# star rating (difficulty of the song itself)
	var stars: int = data.get("stars", 1)
	for i in 4:
		var c := Vector2(w - 88.0 + i * 20.0, 306)
		draw_colored_polygon(UIKit.burst_points(c, 9.0, 4.0, 5, -PI / 2.0), UIKit.YELLOW if i < stars else Color("3a2d5c"))
	if status != "":
		var sc := UIKit.LIME if status == "CLEARED" else UIKit.HOT
		draw_rect(Rect2(w - 112, 10, 104, 34), UIKit.INK)
		draw_rect(Rect2(w - 108, 14, 96, 26), sc)
		_text(font, status, Vector2(w - 108, 15), 96, 22, UIKit.INK, 1, HORIZONTAL_ALIGNMENT_CENTER, false)
	if best_rank != "":
		_text(font, "BEST %s  %d" % [best_rank, best_score], Vector2(12, 330), w - 24, 20, UIKit.AMBER)


func _text(font: Font, t: String, pos: Vector2, width: float, fsize: int, color: Color, lines := 1, align := HORIZONTAL_ALIGNMENT_LEFT, outline := true) -> void:
	# outline first, then fill: readable on any background
	if outline:
		draw_multiline_string_outline(font, pos + Vector2(0, fsize), t, align, width, fsize, lines, 7, UIKit.INK)
	draw_multiline_string(font, pos + Vector2(0, fsize), t, align, width, fsize, lines, color)
