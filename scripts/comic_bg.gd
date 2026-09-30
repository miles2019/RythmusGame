class_name ComicBG
extends Control
## Animated comic-book backdrop for menu screens: slow sunburst, halftone corner,
## diagonal tape stripes and drifting shapes. `accent`/`accent2` tint it per screen.

var accent := Color("ff4fa3")
var accent2 := Color("35e6ff")
var base_top := Color("2a1257")
var base_bottom := Color("120a24")
var _t := 0.0
var pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


func beat() -> void:
	pulse = 1.0


func _process(delta: float) -> void:
	_t += delta * (0.25 if Settings.reduced_background else 1.0)
	pulse = maxf(pulse - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var w := 1280.0
	var h := 720.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([base_top, base_top, base_bottom, base_bottom]))
	# sunburst rays
	var centre := Vector2(w * 0.5, h * 0.55)
	var rays := 20
	for i in rays:
		if i % 2 == 0:
			continue
		var a0 := _t * 0.08 + i * TAU / rays
		var a1 := a0 + TAU / rays
		var c := accent
		c.a = 0.10 + pulse * 0.06
		draw_colored_polygon(PackedVector2Array([centre, centre + Vector2.from_angle(a0) * 1400.0, centre + Vector2.from_angle(a1) * 1400.0]), c)
	# halftone over the whole screen (one tiled texture draw)
	var dot := accent2
	dot.a = 0.10
	UIKit.draw_halftone(self, Rect2(0, 0, w, h), dot)
	# tape stripes
	for k in 2:
		var y := 600.0 + k * 40.0
		var tc := accent2 if k == 0 else accent
		tc.a = 0.25
		draw_colored_polygon(PackedVector2Array([Vector2(-20, y), Vector2(w + 20, y - 50), Vector2(w + 20, y - 26), Vector2(-20, y + 24)]), tc)
	# drifting shapes
	for i in 12:
		var hsh := fposmod(sin(i * 78.233) * 43758.5453, 1.0)
		var x := fposmod(hsh * w + sin(_t * 0.4 + i) * 30.0, w)
		var y := fposmod(h - (_t * (14.0 + hsh * 22.0) + hsh * h), h + 80.0) - 40.0
		var s := 10.0 + hsh * 18.0
		var c := accent2.lerp(Color.WHITE, 0.3) if i % 2 == 0 else accent.lerp(Color.WHITE, 0.3)
		c.a = 0.35
		var ang := _t * (0.6 + hsh) + i
		match i % 3:
			0:
				draw_colored_polygon(UIKit.burst_points(Vector2(x, y), s, s * 0.45, 4, ang), c)
			1:
				draw_arc(Vector2(x, y), s, 0, TAU, 14, c, 4.0, true)
			_:
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - s) , Vector2(x + s, y + s * 0.7), Vector2(x - s, y + s * 0.7)]), c)
