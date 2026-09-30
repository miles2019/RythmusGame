class_name FxLayer
extends Node2D
## Pooled particles, rings/stars and floating text in one draw call site.
## Fixed-size pools (no allocations while playing); the oldest slot is recycled when full.

const MAX_P := 360
const MAX_R := 24
const MAX_T := 14

# particles
var _pp := PackedVector2Array()
var _pv := PackedVector2Array()
var _plife := PackedFloat32Array()
var _pmax := PackedFloat32Array()
var _psize := PackedFloat32Array()
var _pcol := PackedColorArray()
var _pkind := PackedInt32Array()
var _pc := 0
# rings: kind 0 = ring, 1 = star outline
var _rp := PackedVector2Array()
var _rage := PackedFloat32Array()
var _rlife := PackedFloat32Array()
var _r0 := PackedFloat32Array()
var _r1 := PackedFloat32Array()
var _rw := PackedFloat32Array()
var _rcol := PackedColorArray()
var _rkind := PackedInt32Array()
var _rc := 0
# floating text
var _tp := PackedVector2Array()
var _tage := PackedFloat32Array()
var _tlife := PackedFloat32Array()
var _tsize := PackedInt32Array()
var _tcol := PackedColorArray()
var _ttext: Array[String] = []
var _tburst := PackedByteArray()
var _tc := 0
var _any := false

const HIT_WORDS := {
	0: ["POW!", "BAM!", "ZAP!", "WHAM!", "KAPOW!"],
	1: ["BOOM!", "ZING!", "SMASH!"],
	2: ["tap", "tick", "ok"],
}
const MISS_WORDS := ["OUCH!", "OOF!", "BONK!", "YIKES!"]

var _font: Font


func _ready() -> void:
	_font = UIKit.font()
	_tburst.resize(MAX_T)
	_pp.resize(MAX_P); _pv.resize(MAX_P); _plife.resize(MAX_P); _pmax.resize(MAX_P)
	_psize.resize(MAX_P); _pcol.resize(MAX_P); _pkind.resize(MAX_P)
	_rp.resize(MAX_R); _rage.resize(MAX_R); _rlife.resize(MAX_R); _r0.resize(MAX_R)
	_r1.resize(MAX_R); _rw.resize(MAX_R); _rcol.resize(MAX_R); _rkind.resize(MAX_R)
	_tp.resize(MAX_T); _tage.resize(MAX_T); _tlife.resize(MAX_T); _tsize.resize(MAX_T)
	_tcol.resize(MAX_T); _ttext.resize(MAX_T)
	clear()
	GameFeel.hit_fx.connect(_on_hit_fx)
	GameFeel.miss_fx.connect(_on_miss_fx)


func _exit_tree() -> void:
	if GameFeel.hit_fx.is_connected(_on_hit_fx):
		GameFeel.hit_fx.disconnect(_on_hit_fx)
	if GameFeel.miss_fx.is_connected(_on_miss_fx):
		GameFeel.miss_fx.disconnect(_on_miss_fx)


func clear() -> void:
	_plife.fill(0.0)
	_rlife.fill(0.0)
	_tlife.fill(0.0)
	_any = true
	queue_redraw()


func burst(pos: Vector2, color: Color, count: int, speed: float, psize := 6.0, life := 0.5,
		dir := Vector2.UP, spread := TAU, kind := 0) -> void:
	_any = true
	count = roundi(count * Settings.fx_scale())
	for i in count:
		var idx := _pc
		_pc = (_pc + 1) % MAX_P
		var ang := dir.angle() + randf_range(-spread, spread) * 0.5
		var sp := speed * randf_range(0.4, 1.0)
		_pp[idx] = pos
		_pv[idx] = Vector2.from_angle(ang) * sp
		_plife[idx] = life * randf_range(0.7, 1.2)
		_pmax[idx] = _plife[idx]
		_psize[idx] = psize * randf_range(0.6, 1.2)
		_pcol[idx] = color
		_pkind[idx] = kind


func ring(pos: Vector2, color: Color, r0: float, r1: float, life := 0.35, width := 6.0, kind := 0) -> void:
	_any = true
	var idx := _rc
	_rc = (_rc + 1) % MAX_R
	_rp[idx] = pos
	_rage[idx] = 0.0
	_rlife[idx] = life
	_r0[idx] = r0
	_r1[idx] = r1
	_rw[idx] = width
	_rcol[idx] = color
	_rkind[idx] = kind


func float_text(pos: Vector2, text: String, color: Color, size := 28, life := 0.7, burst := false) -> void:
	var idx := _tc
	_tc = (_tc + 1) % MAX_T
	_any = true
	_tburst[idx] = 1 if burst else 0
	_tp[idx] = pos
	_tage[idx] = 0.0
	_tlife[idx] = life
	_tsize[idx] = size
	_tcol[idx] = color
	_ttext[idx] = text


func _on_hit_fx(rating: int, lane: int, pos: Vector2, prof: Dictionary) -> void:
	var lane_col := Settings.lane_color(lane)
	var col: Color = prof.color
	for i in int(prof.rings):
		ring(pos, col if i == 0 else lane_col, 20.0, 90.0 + i * 40.0, 0.32 + i * 0.1, 8.0 - i * 3.0)
	if prof.particles > 0:
		burst(pos, col, prof.particles, 420.0, 7.0, 0.45)
		burst(pos, lane_col, int(prof.particles * 0.6), 300.0, 5.0, 0.4)
	if prof.stars > 0:
		ring(pos, Color.WHITE, 10.0, 70.0, 0.4, 5.0, 1)
		burst(pos, Color.WHITE, prof.stars, 380.0, 12.0, 0.6, Vector2.UP, TAU, 1)
	# comic onomatopoeia instead of a dry rating word (the HUD still spells the rating out)
	var words: Array = HIT_WORDS[rating]
	var big := rating == GameFeel.Rating.PERFECT
	float_text(pos + Vector2(0, -80), words[randi() % words.size()], col, 40 if big else 30, 0.6, big)


func _on_miss_fx(lane: int, pos: Vector2) -> void:
	burst(pos, Color("ff5a7a"), 8, 220.0, 7.0, 0.45, Vector2.DOWN, 1.4)
	ring(pos, Color("ff5a7a"), 10.0, 60.0, 0.25, 5.0)
	float_text(pos + Vector2(0, -70), MISS_WORDS[randi() % MISS_WORDS.size()], Color("ff5a7a"), 34, 0.6, true)


func _process(delta: float) -> void:
	if not _any:
		return # nothing alive: zero cost
	var alive := false
	for i in MAX_P:
		if _plife[i] > 0.0:
			alive = true
			_plife[i] -= delta
			_pv[i].y += 900.0 * delta * (0.5 if _pkind[i] == 1 else 1.0)
			_pv[i] *= 1.0 - 2.0 * delta
			_pp[i] += _pv[i] * delta
	for i in MAX_R:
		if _rlife[i] > 0.0:
			alive = true
			_rage[i] += delta
			if _rage[i] >= _rlife[i]:
				_rlife[i] = 0.0
	for i in MAX_T:
		if _tlife[i] > 0.0:
			alive = true
			_tage[i] += delta
			if _tage[i] >= _tlife[i]:
				_tlife[i] = 0.0
	queue_redraw() # also on the frame everything died, so nothing stale stays on screen
	_any = alive


func _draw() -> void:
	for i in MAX_R:
		if _rlife[i] <= 0.0:
			continue
		var k := _rage[i] / _rlife[i]
		var e := 1.0 - pow(1.0 - k, 3.0) # ease-out
		var r := lerpf(_r0[i], _r1[i], e)
		var c: Color = _rcol[i]
		c.a *= 1.0 - k
		if _rkind[i] == 0:
			draw_arc(_rp[i], r, 0.0, TAU, 40, c, maxf(_rw[i] * (1.0 - k), 1.0), true)
		else:
			_draw_star(_rp[i], r, r * 0.45, c, false, _rw[i] * (1.0 - k) + 1.0, k * 1.2)
	for i in MAX_P:
		if _plife[i] <= 0.0:
			continue
		var k: float = _plife[i] / _pmax[i]
		var c: Color = _pcol[i]
		c.a = clampf(k * 1.5, 0.0, 1.0)
		var s: float = _psize[i] * (0.4 + 0.6 * k)
		if _pkind[i] == 1:
			_draw_star(_pp[i], s * 1.6, s * 0.5, c, true, 0.0, k * 6.0)
		else:
			draw_circle(_pp[i], s, c)
	for i in MAX_T:
		if _tlife[i] <= 0.0:
			continue
		var k := _tage[i] / _tlife[i]
		var pop := 1.0 + 0.5 * exp(-_tage[i] * 14.0) # pops in, then settles
		var size := int(_tsize[i] * pop)
		var pos: Vector2 = _tp[i] + Vector2(0, -50.0 * (1.0 - pow(1.0 - k, 2.0)))
		var c: Color = _tcol[i]
		c.a = 1.0 - maxf(k - 0.6, 0.0) / 0.4
		var oc := UIKit.INK
		oc.a = c.a
		if _tburst[i] == 1:
			# starburst sticker behind the word
			var bc := Color(1.0, 0.95, 0.35, c.a)
			var centre := pos + Vector2(0, -size * 0.3)
			var pts := UIKit.burst_points(centre, size * 1.5 * pop, size * 0.85 * pop, 9, _tage[i] * 2.0)
			draw_colored_polygon(pts, bc)
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, oc, 5.0, true)
			c = Color(1, 1, 1, c.a)
		draw_string_outline(_font, pos + Vector2(-100, 0), _ttext[i], HORIZONTAL_ALIGNMENT_CENTER, 200, size, 8, oc)
		draw_string(_font, pos + Vector2(-100, 0), _ttext[i], HORIZONTAL_ALIGNMENT_CENTER, 200, size, c)


func _draw_star(center: Vector2, r_out: float, r_in: float, color: Color, filled: bool, width: float, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var r := r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2.from_angle(rot + i * PI / 4.0 - PI / 2.0) * r)
	if filled:
		draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		draw_polyline(pts, color, width, true)
