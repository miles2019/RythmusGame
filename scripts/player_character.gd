class_name PlayerCharacter
extends Character
## Mika Pulse: impulsive beat-maker. Warm orange/pink, big headphones, a home-built
## audio box on her chest that thumps with the beat.

const HS := 1.25 # head-feature scale (head radius 40 vs. the 32 the shapes were drawn for)


func _init() -> void:
	accent = Color("ff8a3d")
	skin = Color("ffd9c2")
	hair = Color("ff4f8a")
	body = Color("ff8a3d")
	legs = Color("2a1a4a")
	eye_color = Color("7a2a7a")


func _h(x: float, y: float) -> Vector2:
	return head_pos + Vector2(x, y) * HS


func _draw_back() -> void:
	# Twin ponytails that swing with lean and bob (secondary motion).
	var swing := sin(_clock * 3.1) * 7.0 + _x[P_LEAN] * -45.0 - _bob_v * 0.05 + _dmg * sin(_clock * 6.0) * 6.0
	var droop := 1.0 - _dmg * 0.35 # tired ponytails sag
	for side in [-1.0, 1.0]:
		var root: Vector2 = _h(26.0 * side, -12.0)
		var tip: Vector2 = root + Vector2(40.0 * side + swing * side * 0.6, 56.0 * droop + swing * 0.3)
		var mid: Vector2 = root + Vector2(28.0 * side + swing * 0.3, 26.0)
		ink_poly(PackedVector2Array([root + Vector2(0, -10), mid + Vector2(11.0 * side, 0), tip,
				mid - Vector2(11.0 * side, 0), root + Vector2(0, 12)]), hair)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9 * side, -18), tip + Vector2(7 * side, -16)]), accent)


func _draw_torso_detail() -> void:
	# white stripe + the audio box
	var mid := hip + lean_dir * 30.0
	draw_line(hip - Vector2(18, 0) + lean_dir * 6.0, sh_l + Vector2(0, 8), Color("fff4dc"), 5.0)
	var box := Transform2D(atan2(lean_dir.x, -lean_dir.y), mid)
	var pts := PackedVector2Array()
	for p in [Vector2(-19, -15), Vector2(19, -15), Vector2(19, 15), Vector2(-19, 15)]:
		pts.append(box * p)
	ink_poly(pts, Color("2b1657"), 5.0)
	var pr := 7.0 + pulse * 5.0
	draw_circle(mid, pr + 3.0, UIKit.INK)
	draw_circle(mid, pr, Color("35e6ff").lerp(Color.WHITE, pulse * 0.6))
	draw_circle(box * Vector2(-12, -9), 2.5, Color("b6ff4a"))
	if _dmg > 0.6:
		# cracked box
		draw_polyline(PackedVector2Array([mid + Vector2(-16, -12), mid + Vector2(-2, 0), mid + Vector2(-8, 6), mid + Vector2(10, 14)]), UIKit.INK, 3.0, true)


func _draw_front() -> void:
	# bangs
	ink_poly(PackedVector2Array([_h(-34, -4), _h(-30, -26), _h(-8, -36), _h(14, -36), _h(32, -24), _h(34, -2),
			_h(24, -14), _h(14, -2), _h(4, -16), _h(-8, -2), _h(-16, -16), _h(-26, -2)]), hair, 6.0)
	# headphones (they crack when she is hurt)
	draw_arc(_h(0, -2), 37.0 * HS, PI * 1.05, PI * 1.95, 14, UIKit.INK, 13.0, true)
	draw_arc(_h(0, -2), 37.0 * HS, PI * 1.05, PI * 1.95, 14, Color("35e6ff"), 7.0, true)
	for s in [-1.0, 1.0]:
		ink_disc(_h(36.0 * s, 2), 11.0 * HS + pulse * 2.0, Color("35e6ff"))
	if _dmg > 0.5:
		draw_polyline(PackedVector2Array([_h(-36, -8), _h(-31, 0), _h(-38, 6), _h(-33, 14)]), UIKit.INK, 3.5, true)
	# sticker star on cheek
	draw_circle(_h(-22, 12), 5.0, Color("fff36b"))
