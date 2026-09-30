class_name RivalCharacter
extends Character
## The four rival crew leaders in one class; `variant` picks the look:
##   "gum"  Gum Grin  - goofy mohawk kid with a bubble-gum bubble
##   "kuro" Kuro Static - calm hooded rival with a triangle halo
##   "null" Mr. Null  - skull mask, black coat, red glitch lines
##   "clock" Overclock - monitor-head robot with a spinning gear
## They react late on purpose (beat_delay_max) so they feel unhurried.

const HS := 1.25

var variant := "kuro"


func _init() -> void:
	facing = -1.0
	beat_delay_max = 0.035
	stiffness = 160.0
	damping = 13.0


## Must be called once after instancing (before the first frame is drawn).
func set_variant(v: String) -> void:
	variant = v
	match v:
		"gum":
			accent = Color("b6ff4a"); skin = Color("ffc2d9"); hair = Color("b6ff4a")
			body = Color("ffd23f"); legs = Color("6a2a8a"); eye_color = Color("2a1a4a")
			head_r = 44.0
		"null":
			accent = Color("ff3b3b"); skin = Color("f4f0e6"); hair = Color("120a24")
			body = Color("1a1026"); legs = Color("0c0716"); eye_color = Color("ff3b3b")
		"clock":
			accent = Color("fff36b"); skin = Color("8fa0b8"); hair = Color("3a4a64")
			body = Color("5a6c88"); legs = Color("2e3a52"); eye_color = Color("b6ff4a")
			head_r = 42.0
		_:
			accent = Color("35e6ff"); skin = Color("cfd8ff"); hair = Color("120a24")
			body = Color("221548"); legs = Color("120a24"); eye_color = Color("35e6ff")
	queue_redraw()


func _h(x: float, y: float) -> Vector2:
	return head_pos + Vector2(x, y) * HS


func _draw_head() -> void:
	if variant == "clock":
		# monitor head
		var c := head_pos
		var pts := PackedVector2Array([c + Vector2(-50, -40), c + Vector2(50, -40), c + Vector2(50, 38), c + Vector2(-50, 38)])
		ink_poly(pts, skin)
		ink_poly(PackedVector2Array([c + Vector2(-42, -32), c + Vector2(42, -32), c + Vector2(42, 30), c + Vector2(-42, 30)]), Color("0e1a14"), 4.0)
		return
	ink_disc(head_pos, head_r, skin)


func _draw_face() -> void:
	match variant:
		"clock":
			_draw_monitor_face()
		"null":
			_draw_skull_face()
		"gum":
			super._draw_face()
			# enormous grin with teeth
			var c := head_pos + Vector2(5, 4)
			var mp := c + Vector2(2, 22)
			ink_oval(mp, 22.0 + _x[P_MOUTH] * 4.0, 8.0 + _x[P_MOUTH] * 12.0, UIKit.INK)
			draw_rect(Rect2(mp.x - 16, mp.y - 6, 32, 6), Color.WHITE)
			# bubble gum inflating on the beat
			var br := 8.0 + pulse * 20.0
			draw_circle(mp + Vector2(10, 6), br + 3.0, UIKit.INK)
			draw_circle(mp + Vector2(10, 6), br, Color("ff7ac8"))
			draw_circle(mp + Vector2(10 - br * 0.3, 6 - br * 0.3), br * 0.25, Color(1, 1, 1, 0.6))
		_:
			super._draw_face()


func _draw_monitor_face() -> void:
	var c := head_pos
	var col := eye_color
	if eye_style == 2 or eye_style == 4:
		col = Color("ff5a7a")
	match eye_style:
		1: # ^ ^
			for s in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([c + Vector2(14.0 * s - 10, 0), c + Vector2(14.0 * s, -10), c + Vector2(14.0 * s + 10, 0)]), col, 6.0, true)
		2, 4: # X X
			for s in [-1.0, 1.0]:
				draw_line(c + Vector2(14.0 * s - 9, -12), c + Vector2(14.0 * s + 9, 6), col, 6.0)
				draw_line(c + Vector2(14.0 * s - 9, 6), c + Vector2(14.0 * s + 9, -12), col, 6.0)
		_:
			for s in [-1.0, 1.0]:
				draw_rect(Rect2(c.x + 14.0 * s - 8, c.y - 14, 16, 22 if eye_style == 0 else 12), col)
	var m: float = _x[P_MOUTH]
	draw_rect(Rect2(c.x - 18, c.y + 14, 36, 4 + m * 10.0), col)
	# scanline flicker
	for k in 4:
		var y := c.y - 30.0 + fposmod(_clock * 40.0 + k * 15.0, 60.0)
		draw_line(Vector2(c.x - 42, y), Vector2(c.x + 42, y), Color(1, 1, 1, 0.07), 3.0)


func _draw_skull_face() -> void:
	var c := head_pos + Vector2(4, 2)
	# hollow eye sockets with red pinpricks
	for s in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(15.0 * s, -4)
		if eye_style == 1:
			draw_arc(e, 9.0, PI, TAU, 10, UIKit.INK, 6.0, true)
		else:
			ink_oval(e, 11.0, 14.0, UIKit.INK)
			draw_circle(e + Vector2(2, 1), 4.0 + (2.0 if eye_style == 3 else 0.0), eye_color)
	# nose hole + stitched mouth
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 8), c + Vector2(6, 18), c + Vector2(-4, 18)]), UIKit.INK)
	var m: float = _x[P_MOUTH]
	draw_line(c + Vector2(-20, 28 + m * 4.0), c + Vector2(24, 28 + m * 4.0), UIKit.INK, 4.5)
	for k in 6:
		var x := c.x - 16 + k * 8.0
		draw_line(Vector2(x, c.y + 22 + m * 4.0), Vector2(x, c.y + 34 + m * 4.0), UIKit.INK, 3.5)


func _draw_back() -> void:
	match variant:
		"kuro":
			# rotating triangle halo behind the shoulders
			var c := shoulder + Vector2(0, -20)
			var pts := PackedVector2Array()
			for i in 3:
				pts.append(c + Vector2.from_angle(_clock * 0.8 + i * TAU / 3.0 - PI / 2.0) * (86.0 + pulse * 10.0))
			pts.append(pts[0])
			draw_polyline(pts, UIKit.INK, 11.0, true)
			draw_polyline(pts, accent.lerp(Color.WHITE, pulse * 0.4), 5.0, true)
		"null":
			# glitch bars flickering behind him
			for k in 5:
				var y := shoulder.y - 60.0 + k * 26.0 + sin(_clock * 11.0 + k * 2.0) * 6.0
				var w := 40.0 + fposmod(_boil * 37.0 + k * 53.0, 60.0)
				draw_rect(Rect2(-w * 0.5 + sin(_clock * 7.0 + k) * 14.0, y, w, 7), Color(1.0, 0.23, 0.23, 0.55 + pulse * 0.3))
		"clock":
			# antenna
			var a0 := head_pos + Vector2(0, -40)
			var a1 := a0 + Vector2(sin(_clock * 3.0) * 6.0, -30)
			draw_line(a0, a1, UIKit.INK, 9.0)
			draw_line(a0, a1, skin, 4.0)
			ink_disc(a1, 7.0 + pulse * 3.0, accent)


func _draw_torso_detail() -> void:
	var glow := accent.lerp(Color.WHITE, pulse * 0.5)
	match variant:
		"gum":
			# hoodie pocket + smiley
			var m := hip.lerp(shoulder, 0.45)
			ink_oval(m, 13.0, 13.0, Color("ff7ac8"), true)
			draw_circle(m + Vector2(-4, -3), 2.0, UIKit.INK)
			draw_circle(m + Vector2(4, -3), 2.0, UIKit.INK)
			draw_arc(m + Vector2(0, 1), 6.0, 0.3, PI - 0.3, 8, UIKit.INK, 2.5, true)
		"kuro":
			# long coat flaring below the hip + glowing triangle
			ink_poly(PackedVector2Array([hip + Vector2(-22, 0), hip + Vector2(22, 0), hip + Vector2(38, 50), hip + Vector2(-38, 50)]), body.darkened(0.15))
			var m := hip + lean_dir * 34.0
			draw_polyline(PackedVector2Array([m + Vector2(-11, 11), m + Vector2(0, -13), m + Vector2(11, 11), m + Vector2(-11, 11)]), glow, 4.0, true)
			draw_line(hip + Vector2(-34, 46), hip + Vector2(34, 46), glow, 3.5)
		"null":
			ink_poly(PackedVector2Array([hip + Vector2(-22, 0), hip + Vector2(22, 0), hip + Vector2(42, 56), hip + Vector2(-42, 56)]), body.lightened(0.05))
			draw_line(hip + Vector2(0, -6), hip + lean_dir * 52.0, Color("ff3b3b"), 4.0)
			for k in 3:
				draw_line(hip.lerp(shoulder, 0.25 + k * 0.22) + Vector2(-10, 0), hip.lerp(shoulder, 0.25 + k * 0.22) + Vector2(10, 0), Color("ff3b3b"), 3.0)
		"clock":
			# spinning gear on the chest
			var m := hip.lerp(shoulder, 0.5)
			var pts := PackedVector2Array()
			for i in 16:
				var r := 18.0 if i % 2 == 0 else 12.0
				pts.append(m + Vector2.from_angle(_clock * 2.0 + i * TAU / 16.0) * r)
			ink_poly(pts, accent, 4.0)
			draw_circle(m, 5.0, UIKit.INK)


func _draw_front() -> void:
	var h := head_pos
	match variant:
		"gum":
			# neon mohawk
			for k in 5:
				var x := -24.0 + k * 12.0
				ink_poly(PackedVector2Array([h + Vector2(x - 7, -head_r + 6), h + Vector2(x + sin(_clock * 4.0 + k) * 3.0, -head_r - 34 - (k % 2) * 10.0), h + Vector2(x + 7, -head_r + 6)]), hair, 5.0)
		"kuro":
			ink_poly(PackedVector2Array([_h(-36, 0), _h(-38, -22), _h(-20, -30), _h(-26, -50), _h(-4, -38), _h(4, -58),
					_h(16, -36), _h(38, -46), _h(34, -18), _h(38, 4), _h(24, -12), _h(8, -2), _h(-8, -14), _h(-22, -2)]), hair, 6.0)
			draw_line(_h(-6, -34), _h(10, -14), accent, 5.0)
		"null":
			# hood around the skull mask
			draw_arc(h, head_r + 6.0, PI * 0.85, PI * 2.15, 16, UIKit.INK, 18.0, true)
			draw_arc(h, head_r + 6.0, PI * 0.85, PI * 2.15, 16, body, 12.0, true)
		"clock":
			# bolt on the side
			draw_circle(h + Vector2(-46, 0), 5.0, UIKit.INK)
			draw_circle(h + Vector2(46, 0), 5.0, UIKit.INK)
