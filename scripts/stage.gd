class_name Stage
extends Node2D
## Animated backdrop with a per-song theme (alley / roof / club / server). Drawn
## procedurally. Reacts to the beat, the section accent colour, the barrier "stability",
## the combo (speed lines) and keeps paint splats from hits/misses for a few seconds.

const CENTER := Vector2(640, 320)
const SEGMENTS := 28
const MAX_SPLATS := 28

var theme := "club"
var accent := Color("35e6ff")
var stability := 60.0   ## 0..100, drives how many barrier segments are intact
var beat_pos := 0.0     ## in beats, set by the song scene each frame
var pulse := 0.0        ## 0..1 beat pulse, decays
var flash_alpha := 0.0
var flash_color := Color.WHITE
var crack := 0.0        ## brief red shudder after a miss
var combo_fx := 0.0     ## 0..1, rises with the combo: speed lines + hotter colours

var _seg_jitter := PackedFloat32Array()
var _splat_pos := PackedVector2Array()
var _splat_col := PackedColorArray()
var _splat_age := PackedFloat32Array()
var _splat_r := PackedFloat32Array()
var _splat_seed := PackedFloat32Array()
var _splat_cursor := 0


func _ready() -> void:
	z_index = -100
	_seg_jitter.resize(SEGMENTS)
	for i in SEGMENTS:
		_seg_jitter[i] = fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
	_splat_pos.resize(MAX_SPLATS)
	_splat_col.resize(MAX_SPLATS)
	_splat_age.resize(MAX_SPLATS)
	_splat_r.resize(MAX_SPLATS)
	_splat_seed.resize(MAX_SPLATS)
	_splat_age.fill(99.0)


func reset() -> void:
	pulse = 0.0
	flash_alpha = 0.0
	crack = 0.0
	combo_fx = 0.0
	_splat_age.fill(99.0)
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


func _process(delta: float) -> void:
	pulse = maxf(pulse - delta * 3.2, 0.0)
	flash_alpha = maxf(flash_alpha - delta * 2.5, 0.0)
	crack = maxf(crack - delta * 2.0, 0.0)
	for i in MAX_SPLATS:
		if _splat_age[i] < 10.0:
			_splat_age[i] += delta
	queue_redraw()


func _draw() -> void:
	var anim := 0.0 if Settings.reduced_background else 1.0
	var p := pulse * (0.5 if Settings.reduced_background else 1.0)
	_draw_sky(p)
	_draw_theme(p, anim)
	_draw_splats()
	# spotlights over the two characters
	for x in [200.0, 1080.0]:
		var c := accent
		c.a = 0.05 + p * 0.07
		draw_colored_polygon(PackedVector2Array([Vector2(x - 50, -60), Vector2(x + 50, -60),
				Vector2(x + 210, 720), Vector2(x - 210, 720)]), c)
	_draw_floor(p, anim)
	_draw_rift(p, anim)
	if combo_fx > 0.05 and anim > 0.0:
		_draw_speed_lines()
	# vignette
	var v := UIKit.INK
	v.a = 0.55
	var clear := UIKit.INK
	clear.a = 0.0
	draw_polygon(PackedVector2Array([Vector2(-60, -60), Vector2(260, -60), Vector2(260, 780), Vector2(-60, 780)]),
			PackedColorArray([v, clear, clear, v]))
	draw_polygon(PackedVector2Array([Vector2(1020, -60), Vector2(1340, -60), Vector2(1340, 780), Vector2(1020, 780)]),
			PackedColorArray([clear, v, v, clear]))
	if flash_alpha > 0.0:
		var f := flash_color
		f.a = flash_alpha
		draw_rect(Rect2(-60, -60, 1400, 840), f)


func _draw_sky(p: float) -> void:
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
	var top := top_base.lerp(accent, 0.14 + p * 0.06 + combo_fx * 0.06)
	var bottom := bot_base.lerp(accent, 0.08)
	draw_polygon(PackedVector2Array([Vector2(-60, -60), Vector2(1340, -60), Vector2(1340, 780), Vector2(-60, 780)]),
			PackedColorArray([top, top, bottom, bottom]))


func _draw_theme(p: float, anim: float) -> void:
	var line := accent
	line.a = 0.12
	match theme:
		"alley": # brick wall, hanging neon sign, dumpsters
			for row in 13:
				var y := row * 34.0 - 6.0
				draw_line(Vector2(-40, y), Vector2(1320, y), line, 2.0)
				var off := 35.0 if row % 2 == 0 else 0.0
				for k in 20:
					draw_line(Vector2(off + k * 70.0, y), Vector2(off + k * 70.0, y + 34.0), line, 2.0)
			var sign_c := accent.lerp(Color.WHITE, 0.3 + p * 0.4)
			sign_c.a = 0.85 if int(beat_pos * 2.0) % 11 != 7 else 0.3
			draw_arc(Vector2(640, 110), 70.0, PI, TAU, 20, sign_c, 8.0, true)
			draw_line(Vector2(570, 110), Vector2(570, 160), sign_c, 8.0)
			draw_line(Vector2(710, 110), Vector2(710, 160), sign_c, 8.0)
			for x in [90.0, 1140.0]:
				draw_rect(Rect2(x, 470, 120, 100), Color(0.04, 0.03, 0.08, 0.85))
				draw_rect(Rect2(x - 6, 462, 132, 14), Color(0.08, 0.06, 0.14, 0.95))
		"roof": # moon + skyline
			draw_circle(Vector2(900, 120), 64.0, Color(1.0, 0.97, 0.85, 0.85))
			draw_circle(Vector2(880, 106), 14.0, Color(0.85, 0.82, 0.7, 0.6))
			for layer in 2:
				var x := -20.0
				var seed_i := layer * 17
				while x < 1300.0:
					var w := 60.0 + fposmod(sin((x + seed_i) * 0.37) * 99.0, 50.0)
					var h := 120.0 + fposmod(sin((x + seed_i) * 0.11) * 300.0, 170.0) + layer * 50.0
					var col := Color(0.03, 0.05, 0.12, 0.95) if layer == 0 else Color(0.06, 0.09, 0.2, 0.9)
					draw_rect(Rect2(x, 470.0 - h, w, h + 260.0), col)
					var wi := 0
					var wy := 470.0 - h + 14.0
					while wy < 440.0:
						var wx := x + 8.0
						while wx < x + w - 10.0:
							var on := fposmod(sin((wx * 12.9 + wy * 7.3 + layer) * 43.0) * 9e3, 1.0) > 0.62
							if on:
								draw_rect(Rect2(wx, wy, 7, 9), Color(1.0, 0.9, 0.5, 0.55 if layer == 0 else 0.3))
							wx += 16.0
						wy += 22.0
					x += w + 4.0
		"club": # truss, moving rays, speaker stacks
			draw_rect(Rect2(-40, 28, 1360, 14), Color(0.05, 0.03, 0.08, 0.9))
			for k in 9:
				var lx := 60.0 + k * 145.0
				var ang := sin(beat_pos * 0.5 * anim + k) * 0.35
				var ray := accent
				ray.a = 0.07 + p * 0.06
				var tip := Vector2(lx, 42) + Vector2(sin(ang), cos(ang)) * 560.0
				draw_colored_polygon(PackedVector2Array([Vector2(lx - 6, 42), Vector2(lx + 6, 42), tip + Vector2(46, 0), tip - Vector2(46, 0)]), ray)
				draw_circle(Vector2(lx, 42), 9.0, accent.lerp(Color.WHITE, 0.4))
			for x in [40.0, 1160.0]:
				for k in 3:
					draw_rect(Rect2(x, 330.0 + k * 100.0 - 0.0, 90, 96), Color(0.05, 0.03, 0.08, 0.92))
					draw_circle(Vector2(x + 45, 378.0 + k * 100.0), 30.0 + p * 4.0, Color(0.12, 0.08, 0.18, 1))
					draw_circle(Vector2(x + 45, 378.0 + k * 100.0), 12.0, Color(0.02, 0.02, 0.04, 1))
		"server": # rack columns with blinking LEDs, falling data
			for k in 6:
				var rx := 30.0 + k * 215.0
				draw_rect(Rect2(rx, 60, 150, 560), Color(0.02, 0.06, 0.05, 0.85))
				draw_rect(Rect2(rx, 60, 150, 560), line, false, 2.0)
				for j in 14:
					var on := int(beat_pos * 2.0 * anim + j * 3 + k * 5) % 7 < 3
					var led := Color("b6ff4a") if on else Color("17402c")
					draw_rect(Rect2(rx + 10, 76.0 + j * 38.0, 130, 22), Color(0.04, 0.12, 0.09, 1))
					draw_circle(Vector2(rx + 22, 87.0 + j * 38.0), 4.0, led)
					draw_rect(Rect2(rx + 40, 84.0 + j * 38.0, 40.0 + fposmod(j * 37.0 + k * 11.0, 60.0), 6), Color(0.3, 1.0, 0.6, 0.18))
			for k in 10:
				var x := 40.0 + k * 130.0
				var y := fposmod(beat_pos * 40.0 * anim + k * 97.0, 760.0) - 40.0
				draw_line(Vector2(x, y), Vector2(x, y + 50.0), Color(0.4, 1.0, 0.6, 0.25), 3.0)
	# floating diamonds (parallax drift) for all themes
	for i in 10:
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
	for i in range(-12, 13):
		draw_line(vp, Vector2(640 + i * 220.0, 740), gc, 2.0)
	var scroll := fposmod(beat_pos * 0.5 * anim, 1.0)
	for i in 9:
		var t := (i + scroll) / 9.0
		var y := vp.y + (740.0 - vp.y) * t * t
		draw_line(Vector2(-40, y), Vector2(1320, y), gc, 2.0)


func _draw_rift(p: float, anim: float) -> void:
	var intact := int(round(stability / 100.0 * SEGMENTS))
	var base_r := 270.0 + p * 14.0
	var rot := beat_pos * 0.08 * anim
	for i in SEGMENTS:
		var a0 := rot + i * TAU / SEGMENTS
		var a1 := a0 + TAU / SEGMENTS * 0.8
		if i < intact:
			var c := accent.lerp(Color.WHITE, 0.4 + p * 0.3)
			c.a = 0.55 + p * 0.3
			draw_arc(CENTER, base_r, a0, a1, 6, UIKit.INK, 15.0 + p * 4.0, true)
			draw_arc(CENTER, base_r, a0, a1, 6, c, 9.0 + p * 4.0, true)
		else:
			var c := Color("ff5a7a") if crack > 0.0 else accent.darkened(0.4)
			c.a = 0.25 + crack * 0.5
			var j := _seg_jitter[i]
			draw_arc(CENTER, base_r + (j - 0.5) * 26.0 * (1.0 + crack), a0 + j * 0.1, a0 + 0.07 + j * 0.05, 4, c, 5.0, true)


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
		for j in 14:
			var rr := r * (1.0 if j % 2 == 0 else 0.55) * (0.8 + 0.3 * fposmod(sin(sd + j * 3.1) * 43.0, 1.0))
			pts.append(_splat_pos[i] + Vector2.from_angle(j * TAU / 14.0) * rr)
		draw_colored_polygon(pts, c)


func _draw_speed_lines() -> void:
	# manga-style radial lines from the screen centre, only at the edges so lanes stay clean
	var n := 26
	var col := accent.lerp(Color.WHITE, 0.6)
	col.a = 0.16 * combo_fx
	for i in n:
		var a := i * TAU / n + beat_pos * 0.05
		var d := Vector2.from_angle(a)
		var r0 := 500.0 + fposmod(sin(i * 91.7) * 100.0, 120.0)
		draw_line(CENTER + d * r0, CENTER + d * (r0 + 280.0), col, 3.0 + 2.0 * fposmod(i * 0.37, 1.0))
