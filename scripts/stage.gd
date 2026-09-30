class_name Stage
extends Node2D
## Animated backdrop with a per-song theme (alley / roof / club / server / arena / ballroom /
## junkyard / void). Reacts to the beat, the section accent colour, the barrier "stability",
## the combo (speed lines) and keeps paint splats from hits/misses for a few seconds.
##
## PERFORMANCE: everything that does not move (sky, skyline, bricks, racks ...) lives in the
## child node `Back`, which only redraws when the theme or accent colour changes. Godot replays
## the cached draw commands for free, so the per-frame script cost is just the animated bits.

const CENTER := Vector2(640, 320)
const SEGMENTS := 28
const MAX_SPLATS := 28

var theme := "club": set = _set_theme
var accent := Color("35e6ff")
var stability := 60.0   ## 0..100, drives how many barrier segments are intact
var beat_pos := 0.0     ## in beats, set by the song scene each frame
var pulse := 0.0        ## 0..1 beat pulse, decays
var flash_alpha := 0.0
var flash_color := Color.WHITE
var crack := 0.0        ## brief red shudder after a miss
var combo_fx := 0.0     ## 0..1, rises with the combo: speed lines + hotter colours

var _back: Back
var _drawn_accent := Color(0, 0, 0, 0)
var _seg_jitter := PackedFloat32Array()
var _splat_pos := PackedVector2Array()
var _splat_col := PackedColorArray()
var _splat_age := PackedFloat32Array()
var _splat_r := PackedFloat32Array()
var _splat_seed := PackedFloat32Array()
var _splat_cursor := 0
var _splats_alive := false


## The static layer. Draws through Stage._draw_static so all theme code lives in one file.
class Back extends Node2D:
	var stage: Stage

	func _draw() -> void:
		if stage:
			stage._draw_static(self)


func _ready() -> void:
	z_index = -100
	_back = Back.new()
	_back.stage = self
	_back.z_index = -1
	add_child(_back)
	_seg_jitter.resize(SEGMENTS)
	for i in SEGMENTS:
		_seg_jitter[i] = fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
	_splat_pos.resize(MAX_SPLATS)
	_splat_col.resize(MAX_SPLATS)
	_splat_age.resize(MAX_SPLATS)
	_splat_r.resize(MAX_SPLATS)
	_splat_seed.resize(MAX_SPLATS)
	_splat_age.fill(99.0)


func _set_theme(t: String) -> void:
	theme = t
	_drawn_accent = Color(0, 0, 0, 0)  # force a redraw of the static layer


func reset() -> void:
	pulse = 0.0
	flash_alpha = 0.0
	crack = 0.0
	combo_fx = 0.0
	_splat_age.fill(99.0)
	_splats_alive = false
	GameFeel.new_tween(self, "accent").kill()


func set_accent(c: Color) -> void:
	GameFeel.new_tween(self, "accent").tween_property(self, "accent", c, 0.6)


func beat_pulse(strength := 1.0) -> void:
	pulse = maxf(pulse, strength)


func impact(color := Color.WHITE) -> void:
	flash_color = color
	flash_alpha = 0.25 if Settings.reduced_background else 0.55
	pulse = 1.0


func shudder() -> void:
	crack = 1.0


## Paint splat stuck to the backdrop (comic hit marks). Colour = rating/lane colour.
func add_splat(pos: Vector2, color: Color, radius := 40.0) -> void:
	if Settings.reduced_background:
		return
	var i := _splat_cursor
	_splat_cursor = (_splat_cursor + 1) % MAX_SPLATS
	_splat_pos[i] = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	_splat_col[i] = color
	_splat_age[i] = 0.0
	_splat_r[i] = radius * randf_range(0.8, 1.4)
	_splat_seed[i] = randf() * 100.0
	_splats_alive = true


func _process(delta: float) -> void:
	pulse = maxf(pulse - delta * 3.2, 0.0)
	flash_alpha = maxf(flash_alpha - delta * 2.5, 0.0)
	crack = maxf(crack - delta * 2.0, 0.0)
	if _splats_alive:
		var any := false
		for i in MAX_SPLATS:
			if _splat_age[i] < 6.0:
				_splat_age[i] += delta
				any = true
		_splats_alive = any
	if not accent.is_equal_approx(_drawn_accent):
		_drawn_accent = accent
		_back.queue_redraw()
	queue_redraw()


# ---------------------------------------------------------------- animated layer

func _draw() -> void:
	var anim := 0.0 if Settings.reduced_background else 1.0
	var p := pulse * (0.5 if Settings.reduced_background else 1.0)
	if p > 0.02: # beat flash over the static sky
		var f := accent
		f.a = 0.07 * p
		draw_rect(Rect2(-60, -60, 1400, 840), f)
	_draw_animated_theme(p, anim)
	if _splats_alive:
		_draw_splats()
	# spotlights over the two characters
	var sc := accent
	sc.a = 0.05 + p * 0.07
	for x in [200.0, 1080.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 50, -60), Vector2(x + 50, -60),
				Vector2(x + 210, 720), Vector2(x - 210, 720)]), sc)
	_draw_floor(p, anim)
	_draw_rift(p, anim)
	if combo_fx > 0.05 and anim > 0.0:
		_draw_speed_lines()
	if flash_alpha > 0.0:
		var f2 := flash_color
		f2.a = flash_alpha
		draw_rect(Rect2(-60, -60, 1400, 840), f2)


func _draw_animated_theme(p: float, anim: float) -> void:
	match theme:
		"alley": # neon sign flickers
			var sign_c := accent.lerp(Color.WHITE, 0.3 + p * 0.4)
			sign_c.a = 0.85 if int(beat_pos * 2.0) % 11 != 7 else 0.3
			draw_arc(Vector2(640, 110), 70.0, PI, TAU, 16, UIKit.INK, 14.0)
			draw_arc(Vector2(640, 110), 70.0, PI, TAU, 16, sign_c, 8.0)
		"club", "arena": # moving light rays
			for k in 6:
				var lx := 100.0 + k * 215.0
				var ang := sin(beat_pos * 0.5 * anim + k) * 0.35
				var ray := accent
				ray.a = 0.07 + p * 0.06
				var tip := Vector2(lx, 42) + Vector2(sin(ang), cos(ang)) * 560.0
				draw_colored_polygon(PackedVector2Array([Vector2(lx - 6, 42), Vector2(lx + 6, 42), tip + Vector2(46, 0), tip - Vector2(46, 0)]), ray)
		"server": # blinking LEDs + falling data
			for k in 6:
				var rx := 30.0 + k * 215.0
				for j in range(0, 14, 2):
					var on := int(beat_pos * 2.0 * anim + j * 3 + k * 5) % 7 < 3
					draw_circle(Vector2(rx + 22, 87.0 + j * 38.0), 4.0, Color("b6ff4a") if on else Color("17402c"))
			for k in 6:
				var x := 40.0 + k * 210.0
				var y := fposmod(beat_pos * 40.0 * anim + k * 97.0, 760.0) - 40.0
				draw_line(Vector2(x, y), Vector2(x, y + 50.0), Color(0.4, 1.0, 0.6, 0.25), 3.0)
		"void": # drifting shards
			for k in 7:
				var a := beat_pos * 0.1 * anim + k * 0.9
				var pt := Vector2(640, 300) + Vector2(cos(a) * (220.0 + k * 40.0), sin(a * 1.3) * (140.0 + k * 20.0))
				var c := accent
				c.a = 0.35
				draw_colored_polygon(PackedVector2Array([pt + Vector2(0, -14), pt + Vector2(10, 10), pt + Vector2(-10, 10)]), c)
		"ballroom": # chandelier sparkle
			for k in 3:
				var cx := 320.0 + k * 320.0
				var tw := 0.5 + 0.5 * sin(beat_pos * 3.0 + k)
				draw_circle(Vector2(cx, 120), 6.0 + tw * 4.0, Color(1, 0.95, 0.6, 0.5 + 0.4 * tw))
	# floating diamonds (parallax drift) for all themes
	for i in 6:
		var h := fposmod(sin(i * 78.233) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 39.346) * 12345.6789, 1.0)
		var x := h * 1280.0
		var y := fposmod(h2 * 760.0 - beat_pos * (6.0 + h * 10.0) * anim, 760.0) - 20.0
		var s := 8.0 + h2 * 14.0
		var c := accent.lerp(Color.WHITE, 0.3)
		c.a = 0.10 + 0.1 * h
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - s), Vector2(x + s * 0.7, y), Vector2(x, y + s), Vector2(x - s * 0.7, y)]), c)


func _draw_floor(p: float, anim: float) -> void:
	var vp := Vector2(640, 430)
	var gc := accent
	gc.a = 0.16 + p * 0.1
	var pts := PackedVector2Array()
	for i in range(-10, 11): # converging lines: one batched call
		pts.append(vp)
		pts.append(Vector2(640 + i * 260.0, 740))
	var scroll := fposmod(beat_pos * 0.5 * anim, 1.0)
	for i in 8:
		var t := (i + scroll) / 8.0
		var y := vp.y + (740.0 - vp.y) * t * t
		pts.append(Vector2(-40, y))
		pts.append(Vector2(1320, y))
	draw_multiline(pts, gc, 2.0)


func _draw_rift(p: float, anim: float) -> void:
	var intact := int(round(stability / 100.0 * SEGMENTS))
	var base_r := 270.0 + p * 14.0
	var rot := beat_pos * 0.08 * anim
	var ink := UIKit.INK
	var c_on := accent.lerp(Color.WHITE, 0.4 + p * 0.3)
	c_on.a = 0.55 + p * 0.3
	for i in SEGMENTS:
		var a0 := rot + i * TAU / SEGMENTS
		if i < intact:
			var a1 := a0 + TAU / SEGMENTS * 0.8
			draw_arc(CENTER, base_r, a0, a1, 4, ink, 15.0 + p * 4.0)
			draw_arc(CENTER, base_r, a0, a1, 4, c_on, 9.0 + p * 4.0)
		else:
			var c := Color("ff5a7a") if crack > 0.0 else accent.darkened(0.4)
			c.a = 0.25 + crack * 0.5
			var j := _seg_jitter[i]
			draw_arc(CENTER, base_r + (j - 0.5) * 26.0 * (1.0 + crack), a0 + j * 0.1, a0 + 0.07 + j * 0.05, 3, c, 5.0)


func _draw_splats() -> void:
	for i in MAX_SPLATS:
		var age := _splat_age[i]
		if age > 6.0:
			continue
		var k := age / 6.0
		var c: Color = _splat_col[i]
		c.a = 0.55 * (1.0 - k * k)
		var r: float = _splat_r[i] * (0.6 + minf(age * 6.0, 0.4))
		var pts := PackedVector2Array()
		var sd: float = _splat_seed[i]
		for j in 10:
			var rr := r * (1.0 if j % 2 == 0 else 0.55) * (0.8 + 0.3 * fposmod(sin(sd + j * 3.1) * 43.0, 1.0))
			pts.append(_splat_pos[i] + Vector2.from_angle(j * TAU / 10.0) * rr)
		draw_colored_polygon(pts, c)


func _draw_speed_lines() -> void:
	# manga-style radial lines from the screen centre, only at the edges so lanes stay clean
	var col := accent.lerp(Color.WHITE, 0.6)
	col.a = 0.16 * combo_fx
	var pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0 + beat_pos * 0.05
		var d := Vector2.from_angle(a)
		var r0 := 500.0 + fposmod(sin(i * 91.7) * 100.0, 120.0)
		pts.append(CENTER + d * r0)
		pts.append(CENTER + d * (r0 + 280.0))
	draw_multiline(pts, col, 4.0)


# ---------------------------------------------------------------- static layer (cached)

func _draw_static(ci: CanvasItem) -> void:
	_static_sky(ci)
	match theme:
		"alley":
			_static_alley(ci)
		"roof":
			_static_roof(ci)
		"club":
			_static_club(ci)
		"server":
			_static_server(ci)
		"arena":
			_static_arena(ci)
		"ballroom":
			_static_ballroom(ci)
		"junkyard":
			_static_junkyard(ci)
		"void":
			_static_void(ci)
	# vignette
	var v := UIKit.INK
	v.a = 0.55
	var clear := UIKit.INK
	clear.a = 0.0
	ci.draw_polygon(PackedVector2Array([Vector2(-60, -60), Vector2(260, -60), Vector2(260, 780), Vector2(-60, 780)]),
			PackedColorArray([v, clear, clear, v]))
	ci.draw_polygon(PackedVector2Array([Vector2(1020, -60), Vector2(1340, -60), Vector2(1340, 780), Vector2(1020, 780)]),
			PackedColorArray([clear, v, v, clear]))


func _static_sky(ci: CanvasItem) -> void:
	var top_base := UIKit.NIGHT
	var bot_base := Color("0c2a3a")
	match theme:
		"alley":
			top_base = Color("2b1450"); bot_base = Color("1a2a3a")
		"roof":
			top_base = Color("0d1b3d"); bot_base = Color("24396b")
		"club":
			top_base = Color("2a0d2e"); bot_base = Color("3a1030")
		"server":
			top_base = Color("05160f"); bot_base = Color("0b2a20")
		"arena":
			top_base = Color("0d2a4a"); bot_base = Color("1a3a2a")
		"ballroom":
			top_base = Color("3a0d2e"); bot_base = Color("2a1040")
		"junkyard":
			top_base = Color("3a2a1a"); bot_base = Color("1a1410")
		"void":
			top_base = Color("0a0418"); bot_base = Color("1a0828")
	var top := top_base.lerp(accent, 0.14)
	var bottom := bot_base.lerp(accent, 0.08)
	ci.draw_polygon(PackedVector2Array([Vector2(-60, -60), Vector2(1340, -60), Vector2(1340, 780), Vector2(-60, 780)]),
			PackedColorArray([top, top, bottom, bottom]))


func _static_alley(ci: CanvasItem) -> void:
	var line := accent
	line.a = 0.12
	var pts := PackedVector2Array()
	for row in 13:
		var y := row * 34.0 - 6.0
		pts.append(Vector2(-40, y))
		pts.append(Vector2(1320, y))
		var off := 35.0 if row % 2 == 0 else 0.0
		for k in 19:
			pts.append(Vector2(off + k * 70.0, y))
			pts.append(Vector2(off + k * 70.0, y + 34.0))
	ci.draw_multiline(pts, line, 2.0)
	ci.draw_line(Vector2(570, 110), Vector2(570, 160), accent.lerp(Color.WHITE, 0.3), 8.0)
	ci.draw_line(Vector2(710, 110), Vector2(710, 160), accent.lerp(Color.WHITE, 0.3), 8.0)
	for x in [90.0, 1140.0]:
		ci.draw_rect(Rect2(x, 470, 120, 100), Color(0.04, 0.03, 0.08, 0.85))
		ci.draw_rect(Rect2(x - 6, 462, 132, 14), Color(0.08, 0.06, 0.14, 0.95))


func _static_roof(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(900, 120), 64.0, Color(1.0, 0.97, 0.85, 0.85))
	ci.draw_circle(Vector2(880, 106), 14.0, Color(0.85, 0.82, 0.7, 0.6))
	for layer in 2:
		var x := -20.0
		var seed_i := layer * 17
		var win := PackedVector2Array()
		while x < 1300.0:
			var w := 60.0 + fposmod(sin((x + seed_i) * 0.37) * 99.0, 50.0)
			var h := 120.0 + fposmod(sin((x + seed_i) * 0.11) * 300.0, 170.0) + layer * 50.0
			ci.draw_rect(Rect2(x, 470.0 - h, w, h + 260.0), Color(0.03, 0.05, 0.12, 0.95) if layer == 0 else Color(0.06, 0.09, 0.2, 0.9))
			var wy := 470.0 - h + 14.0
			while wy < 440.0:
				var wx := x + 8.0
				while wx < x + w - 10.0:
					if fposmod(sin((wx * 12.9 + wy * 7.3 + layer) * 43.0) * 9e3, 1.0) > 0.62:
						win.append(Vector2(wx + 3.5, wy))
						win.append(Vector2(wx + 3.5, wy + 9.0))
					wx += 18.0
				wy += 24.0
			x += w + 4.0
		# all lit windows of this layer in ONE draw call
		ci.draw_multiline(win, Color(1.0, 0.9, 0.5, 0.55 if layer == 0 else 0.3), 7.0)


func _static_club(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-40, 28, 1360, 14), Color(0.05, 0.03, 0.08, 0.9))
	for k in 6:
		ci.draw_circle(Vector2(100.0 + k * 215.0, 42), 9.0, accent.lerp(Color.WHITE, 0.4))
	for x in [40.0, 1160.0]:
		for k in 3:
			ci.draw_rect(Rect2(x, 330.0 + k * 100.0, 90, 96), Color(0.05, 0.03, 0.08, 0.92))
			ci.draw_circle(Vector2(x + 45, 378.0 + k * 100.0), 30.0, Color(0.12, 0.08, 0.18, 1))
			ci.draw_circle(Vector2(x + 45, 378.0 + k * 100.0), 12.0, Color(0.02, 0.02, 0.04, 1))


func _static_server(ci: CanvasItem) -> void:
	var line := accent
	line.a = 0.12
	for k in 6:
		var rx := 30.0 + k * 215.0
		ci.draw_rect(Rect2(rx, 60, 150, 560), Color(0.02, 0.06, 0.05, 0.85))
		ci.draw_rect(Rect2(rx, 60, 150, 560), line, false, 2.0)
		for j in 14:
			ci.draw_rect(Rect2(rx + 10, 76.0 + j * 38.0, 130, 22), Color(0.04, 0.12, 0.09, 1))
			ci.draw_rect(Rect2(rx + 40, 84.0 + j * 38.0, 40.0 + fposmod(j * 37.0 + k * 11.0, 60.0), 6), Color(0.3, 1.0, 0.6, 0.18))


func _static_arena(ci: CanvasItem) -> void:
	# stands: rows of crowd silhouettes + a giant screen
	ci.draw_rect(Rect2(380, 60, 520, 210), Color(0.02, 0.04, 0.1, 0.9))
	ci.draw_rect(Rect2(380, 60, 520, 210), accent, false, 5.0)
	for row in 5:
		var y := 400.0 + row * 46.0
		var dots := PackedVector2Array()
		for k in 34:
			dots.append(Vector2(20.0 + k * 38.0 + (row % 2) * 19.0, y + fposmod(sin(k * 7.3 + row) * 20.0, 10.0)))
		for d in dots:
			ci.draw_circle(d, 12.0, Color(0.03, 0.05, 0.1, 0.9))
			ci.draw_circle(d + Vector2(0, 18), 16.0, Color(0.03, 0.05, 0.1, 0.9))
	for k in 6:
		ci.draw_circle(Vector2(100.0 + k * 215.0, 42), 9.0, accent.lerp(Color.WHITE, 0.4))


func _static_ballroom(ci: CanvasItem) -> void:
	# velvet curtains left/right, checker floor band
	for s in [0.0, 1.0]:
		var x0 := -20.0 if s == 0.0 else 1080.0
		for k in 4:
			ci.draw_rect(Rect2(x0 + k * 55.0, -20, 50, 760), Color(0.45, 0.05, 0.25, 0.85).lerp(Color(0.25, 0.02, 0.15, 0.9), (k % 2) * 0.6))
	for k in 3:
		var cx := 320.0 + k * 320.0
		ci.draw_line(Vector2(cx, -20), Vector2(cx, 100), UIKit.INK, 5.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 34, 120), Vector2(cx + 34, 120), Vector2(cx + 18, 150), Vector2(cx - 18, 150)]), Color(1, 0.9, 0.5, 0.75))


func _static_junkyard(ci: CanvasItem) -> void:
	# scrap heaps, tires, a crane arm
	for k in 7:
		var x := -40.0 + k * 210.0
		var h := 120.0 + fposmod(sin(k * 9.1) * 300.0, 120.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, 560), Vector2(x + 60, 560 - h), Vector2(x + 130, 560 - h * 0.6), Vector2(x + 210, 560)]), Color(0.1, 0.07, 0.05, 0.92))
		ci.draw_circle(Vector2(x + 90, 540), 26.0, Color(0.02, 0.02, 0.03, 1))
		ci.draw_circle(Vector2(x + 90, 540), 10.0, Color(0.15, 0.12, 0.1, 1))
	ci.draw_line(Vector2(1000, 560), Vector2(1000, 120), Color(0.05, 0.04, 0.05), 14.0)
	ci.draw_line(Vector2(1000, 130), Vector2(720, 200), Color(0.05, 0.04, 0.05), 10.0)
	ci.draw_line(Vector2(720, 200), Vector2(720, 280), accent, 4.0)


func _static_void(ci: CanvasItem) -> void:
	# the Rift itself: a huge glowing crack splitting the backdrop
	var crack_pts := PackedVector2Array([Vector2(560, -20), Vector2(610, 120), Vector2(570, 240), Vector2(650, 360), Vector2(600, 500), Vector2(680, 640), Vector2(640, 760)])
	ci.draw_polyline(crack_pts, Color(accent.r, accent.g, accent.b, 0.25), 40.0)
	ci.draw_polyline(crack_pts, Color(accent.r, accent.g, accent.b, 0.6), 14.0)
	ci.draw_polyline(crack_pts, Color.WHITE, 4.0)
