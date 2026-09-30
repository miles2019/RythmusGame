class_name Character
extends Node2D
## Base for animated stage characters ("Newgrounds cartoon" look: big head, noodle limbs,
## fat ink outlines that boil at ~11 fps).
##
## Pose = a handful of spring-driven values (lean, crouch, arms, head, mouth) plus impulse
## springs for bounce (bob), squash/stretch (sx) and dash (off). States only set *targets*;
## the springs supply the overshoot, so nothing moves linearly.
##
## `damage` (0..1) makes the body visibly suffer: sweat, plasters, black eye, blood, bandages,
## dizzy stars, slumped posture, smoke.
##
## SPRITE HOOK: add an AnimatedSprite2D child named "Sprite" whose SpriteFrames contain
## animations named like STATE_NAMES. If present it plays those and procedural drawing stops.

signal state_changed(state: int)

enum State { IDLE, BEAT_IDLE, INPUT_LEFT, INPUT_DOWN, INPUT_UP, INPUT_RIGHT, MISS, HURT, VICTORY, DEFEAT, INTRO, OUTRO }
const STATE_NAMES := ["idle", "beat_idle", "input_left", "input_down", "input_up", "input_right",
		"miss", "hurt", "victory", "defeat", "intro", "outro"]

const P_LEAN := 0
const P_CROUCH := 1
const P_ARM_L := 2
const P_ARM_R := 3
const P_HEAD := 4
const P_MOUTH := 5
const P_COUNT := 6

# lean, crouch, arm_l, arm_r, head_tilt, mouth
const POSES := {
	State.IDLE: [0.0, 0.0, -0.25, 0.25, 0.0, 0.0],
	State.BEAT_IDLE: [0.0, 0.14, -0.55, 0.55, 0.0, 0.0],
	State.INPUT_LEFT: [-0.34, 0.15, -2.2, 0.5, -0.22, 0.3],
	State.INPUT_DOWN: [0.05, 0.62, -0.9, 0.9, 0.12, 0.4],
	State.INPUT_UP: [0.0, -0.18, -2.85, 2.85, 0.0, 0.5],
	State.INPUT_RIGHT: [0.34, 0.15, -0.5, 2.2, 0.22, 0.3],
	State.MISS: [0.18, 0.4, -0.1, 0.15, 0.4, 0.9],
	State.HURT: [-0.5, 0.5, -1.9, 1.3, -0.5, 1.0],
	State.VICTORY: [0.0, -0.2, -3.0, 3.0, 0.0, 1.0],
	State.DEFEAT: [0.3, 0.95, -0.1, 0.1, 0.6, 0.0],
	State.INTRO: [0.2, 0.55, -0.4, 2.3, 0.1, 0.3],
	State.OUTRO: [0.0, 0.05, -0.3, 2.7, 0.15, 0.4],
}
# 0 open, 1 happy, 2 ouch, 3 determined, 4 knocked out
const EYES := {State.MISS: 2, State.HURT: 2, State.VICTORY: 1, State.DEFEAT: 4, State.OUTRO: 1,
		State.INTRO: 3, State.INPUT_UP: 3, State.INPUT_DOWN: 3}
# Seconds until a state falls back to beat idle (0 = stays until changed).
const HOLD_TIMES := {State.INPUT_LEFT: 0.3, State.INPUT_DOWN: 0.3, State.INPUT_UP: 0.3, State.INPUT_RIGHT: 0.3,
		State.MISS: 0.55, State.HURT: 0.5, State.INTRO: 1.1}

@export var facing := 1.0                ## -1 mirrors the character (rival looks left)
@export var stiffness := 190.0           ## spring constant; higher = snappier
@export var damping := 12.0              ## lower = bouncier (underdamped on purpose)
@export var beat_delay_max := 0.0        ## random lag on beat reactions -> less mechanical
@export var accent := Color("ff8a3d")
@export var skin := Color("ffd9c2")
@export var hair := Color("ff4f8a")
@export var body := Color("ff8a3d")
@export var legs := Color("2a1a4a")
@export var eye_color := Color("3a1a5a")
@export var blood := Color("ff2e63")     ## "paint" used for injuries
@export var head_r := 40.0

var state: int = State.IDLE
var eye_style := 0
var pulse := 0.0                         ## 0..1 beat pulse for gear/glow
var damage := 0.0                        ## 0..1 target injury level, set by the song scene

var _x := PackedFloat32Array()
var _v := PackedFloat32Array()
var _t := PackedFloat32Array()
var _bob := 0.0
var _bob_v := 0.0
var _sx := 1.0
var _sx_v := 0.0
var _off := 0.0
var _off_v := 0.0
var _timer := 0.0
var _sway := 1.0
var _beat_delay := -1.0
var _beat_strong := false
var _clock := 0.0
var _dmg := 0.0                          ## smoothed damage
var _impact := 0.0                       ## comic impact star timer after a hit
var _boil := 0
var _boil_t := 0.0
var _redraw_acc := 0.0
var _sprite: AnimatedSprite2D

# skeleton, recomputed each draw
var hip := Vector2.ZERO
var shoulder := Vector2.ZERO
var head_pos := Vector2.ZERO
var sh_l := Vector2.ZERO
var sh_r := Vector2.ZERO
var perp := Vector2.RIGHT
var lean_dir := Vector2.UP
var _hand_l := Vector2.ZERO
var _hand_r := Vector2.ZERO


func _ready() -> void:
	_x.resize(P_COUNT)
	_v.resize(P_COUNT)
	_t.resize(P_COUNT)
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	reset()


## Instant, allocation-free return to a clean starting pose (also clears injuries).
func reset() -> void:
	_bob = 0.0; _bob_v = 0.0; _sx = 1.0; _sx_v = 0.0; _off = 0.0; _off_v = 0.0
	_timer = 0.0; _beat_delay = -1.0; pulse = 0.0; damage = 0.0; _dmg = 0.0; _impact = 0.0
	set_state(State.IDLE)
	for i in P_COUNT:
		_x[i] = _t[i]
		_v[i] = 0.0
	queue_redraw()


func set_state(s: int, hold := -1.0) -> void:
	state = s
	var pose: Array = POSES[s]
	for i in P_COUNT:
		_t[i] = pose[i]
	eye_style = EYES.get(s, 0)
	_timer = HOLD_TIMES.get(s, 0.0) if hold < 0.0 else hold
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(STATE_NAMES[s]):
		_sprite.play(STATE_NAMES[s])
	state_changed.emit(s)


func is_free_for_beat() -> bool:
	return state == State.IDLE or state == State.BEAT_IDLE


## Beat reaction with per-beat variation so the idle never looks like a metronome.
func on_beat(strong: bool) -> void:
	pulse = 1.0
	if beat_delay_max > 0.0:
		_beat_delay = randf() * beat_delay_max
		_beat_strong = strong
	else:
		_do_beat(strong)


func _do_beat(strong: bool) -> void:
	var variation := randf_range(0.8, 1.25)
	var m := Settings.motion_scale()
	_bob_v -= 240.0 * variation * (1.6 if strong else 1.0) * m * (1.0 - _dmg * 0.5) # hurt = tired bounce
	_sx_v -= 3.5 * variation * m
	if is_free_for_beat():
		if state == State.IDLE:
			set_state(State.BEAT_IDLE)
		_sway = -_sway
		_t[P_LEAN] = 0.1 * _sway * variation
		_t[P_HEAD] = -0.08 * _sway * variation
		_t[P_ARM_L] = -0.55 - 0.35 * (1.0 if _sway > 0.0 else 0.0) * variation
		_t[P_ARM_R] = 0.55 + 0.35 * (1.0 if _sway < 0.0 else 0.0) * variation


## Player hit something: pose in that direction plus a squash/kick impulse.
func hit(lane: int, rating: int) -> void:
	var m := Settings.motion_scale()
	set_state(State.INPUT_LEFT + lane)
	var power: float = [1.0, 0.65, 0.35][mini(rating, 2)]
	_sx_v += 6.0 * power * m           # squash wide, spring overshoots into a stretch
	_bob_v += 150.0 * power * m
	_off_v += [-160.0, 0.0, 0.0, 160.0][lane] * power * m * facing
	pulse = 1.0


## Mistake: the character takes a proper beating (recoil, impact star, flinch).
func miss() -> void:
	var m := Settings.motion_scale()
	set_state(State.MISS)
	_sx_v -= 3.0 * m
	_bob_v += 260.0 * m
	_off_v -= 200.0 * m * facing
	_impact = 0.4


func hurt(power := 1.0) -> void:
	var m := Settings.motion_scale()
	set_state(State.HURT)
	_off_v -= 300.0 * power * m * facing
	_sx_v += 5.0 * power * m
	_impact = 0.45


## While a hold note is held the input pose stays on; releasing returns to beat idle.
func hold_pose(lane: int, on: bool) -> void:
	if on:
		set_state(State.INPUT_LEFT + lane, 0.0)
	elif state >= State.INPUT_LEFT and state <= State.INPUT_RIGHT:
		set_state(State.BEAT_IDLE)


func _process(delta: float) -> void:
	# Hit-pause: while GameFeel says freeze, the character holds its pose (only visuals).
	var dt := minf(delta, 1.0 / 30.0) * GameFeel.anim_scale()
	_boil_t += delta
	if _boil_t > 0.09:
		_boil_t = 0.0
		_boil += 1
	if dt > 0.0:
		_clock += dt
		pulse = maxf(pulse - dt * 4.0, 0.0)
		_impact = maxf(_impact - dt, 0.0)
		_dmg = lerpf(_dmg, damage, clampf(dt * 4.0, 0.0, 1.0))
		if _beat_delay >= 0.0:
			_beat_delay -= dt
			if _beat_delay < 0.0:
				_do_beat(_beat_strong)
		if _timer > 0.0:
			_timer -= dt
			if _timer <= 0.0:
				set_state(State.BEAT_IDLE)
		var step := dt * 0.5
		for _i in 2: # two sub-steps keep the stiff springs stable at low fps
			for i in P_COUNT:
				_v[i] += ((_t[i] - _x[i]) * stiffness - _v[i] * damping) * step
				_x[i] += _v[i] * step
			_bob_v += (-_bob * 260.0 - _bob_v * 11.0) * step
			_bob += _bob_v * step
			_sx_v += ((1.0 - _sx) * 300.0 - _sx_v * 14.0) * step
			_sx = clampf(_sx + _sx_v * step, 0.6, 1.5)
			_off_v += (-_off * 200.0 - _off_v * 12.0) * step
			_off += _off_v * step
	# redraw at ~45 fps: the springs are smooth enough and drawing is the main cost of a character
	_redraw_acc += delta
	if _sprite == null and _redraw_acc >= 0.021:
		_redraw_acc = 0.0
		queue_redraw()


# ---------------------------------------------------------------- drawing

func _skeleton() -> void:
	var c := _x[P_CROUCH] + _dmg * 0.22
	var lean := _x[P_LEAN] + _dmg * 0.14
	hip = Vector2(0, -62.0 + c * 24.0 + _bob)
	lean_dir = Vector2(sin(lean), -cos(lean))
	shoulder = hip + lean_dir * 54.0 * (1.0 - 0.15 * c)
	var head_ang := lean + _x[P_HEAD] * 0.6 + sin(_clock * 9.0) * 0.05 * _dmg * _dmg
	head_pos = shoulder + Vector2(sin(head_ang), -cos(head_ang)) * (head_r * 0.85 + 8.0)
	perp = Vector2(cos(lean), sin(lean))
	sh_l = shoulder - perp * 21.0
	sh_r = shoulder + perp * 21.0


## Deterministic "line boil": the same vertex wobbles differently every ~90 ms.
func _jit(i: int, amount := 1.8) -> Vector2:
	return Vector2(sin(i * 7.1 + _boil * 1.9), cos(i * 5.3 + _boil * 2.7)) * amount


func _draw() -> void:
	if _sprite != null:
		return
	_skeleton()
	# ground shadow (not squashed with the body)
	draw_set_transform(Vector2(_off, 4.0), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 62.0 * (1.0 - _bob * 0.004), Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(_off, 0.0), 0.0, Vector2(_sx * facing, 1.0 / _sx))
	_draw_back()
	_draw_legs()
	_draw_torso()
	_draw_arms()
	_draw_head()
	_draw_face()
	_draw_damage_face()
	_draw_front()
	_draw_damage_overlay()
	if _impact > 0.0:
		_draw_impact_star()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_legs() -> void:
	var c := _x[P_CROUCH] + _dmg * 0.22
	for side in [-1.0, 1.0]:
		var h: Vector2 = hip + Vector2(14.0 * side, 0)
		var foot := Vector2(25.0 * side, 0)
		var knee := (h + foot) * 0.5 + Vector2(side * (5.0 + c * 22.0), 0)
		ink_limb(h, knee, 19.0, legs)
		ink_limb(knee, foot - Vector2(0, 6), 19.0, legs)
		ink_oval(foot + Vector2(5, -4), 21.0, 12.0, accent, true) # big cartoon shoe


func _draw_torso() -> void:
	var pts := PackedVector2Array([hip - Vector2(22, 0), hip + Vector2(22, 0), (hip + sh_r) * 0.5 + perp * 9.0,
			sh_r + perp * 6.0, sh_l - perp * 6.0, (hip + sh_l) * 0.5 - perp * 9.0])
	ink_poly(pts, body)
	_draw_torso_detail()


func _draw_arms() -> void:
	for side in [-1, 1]:
		var sh: Vector2 = sh_l if side < 0 else sh_r
		var a: float = _x[P_ARM_L] if side < 0 else _x[P_ARM_R]
		var elbow := sh + Vector2(sin(a), cos(a)) * 30.0
		var a2 := a * 1.2
		var hand := elbow + Vector2(sin(a2), cos(a2)) * 30.0
		ink_limb(sh, elbow, 15.0, body)
		ink_limb(elbow, hand, 13.0, skin)
		ink_disc(hand, 12.0, skin)
		if side < 0:
			_hand_l = hand
		else:
			_hand_r = hand


func _draw_head() -> void:
	ink_disc(head_pos, head_r, skin)


func _draw_face() -> void:
	var c := head_pos + Vector2(5, 4)
	var m: float = _x[P_MOUTH]
	match eye_style:
		0, 3:
			for s in [-1.0, 1.0]:
				var e: Vector2 = c + Vector2(15.0 * s, -4)
				ink_oval(e, 11.0, 14.0, Color.WHITE)
				var look := Vector2(3.0 + _x[P_LEAN] * 8.0, 2.0)
				draw_circle(e + look, 6.0, eye_color)
				draw_circle(e + look + Vector2(-1.5, -2.5), 2.2, Color.WHITE)
			if eye_style == 3:
				draw_line(c + Vector2(-28, -22), c + Vector2(-5, -12), UIKit.INK, 6.0)
				draw_line(c + Vector2(34, -22), c + Vector2(8, -12), UIKit.INK, 6.0)
		1:
			for s in [-1.0, 1.0]:
				draw_arc(c + Vector2(15.0 * s, 0), 9.0, PI, TAU, 10, UIKit.INK, 5.5)
		2:
			draw_polyline(PackedVector2Array([c + Vector2(-27, -14), c + Vector2(-8, -3), c + Vector2(-27, 8)]), UIKit.INK, 5.5)
			draw_polyline(PackedVector2Array([c + Vector2(33, -14), c + Vector2(14, -3), c + Vector2(33, 8)]), UIKit.INK, 5.5)
		4:
			for s in [-1.0, 1.0]:
				var e: Vector2 = c + Vector2(15.0 * s, -2)
				draw_line(e + Vector2(-9, -9), e + Vector2(9, 9), UIKit.INK, 5.5)
				draw_line(e + Vector2(-9, 9), e + Vector2(9, -9), UIKit.INK, 5.5)
	var mp := c + Vector2(2, 24)
	if m > 0.15:
		ink_oval(mp, 8.0 + m * 3.0, 4.0 + m * 10.0, UIKit.INK)
		draw_circle(mp + Vector2(0, 4.0 + m * 5.0), 5.0, Color("ff6b8a"))
	elif eye_style == 1:
		draw_arc(mp + Vector2(0, -5), 10.0, 0.2, PI - 0.2, 10, UIKit.INK, 4.5)
	else:
		draw_line(mp + Vector2(-7, 0), mp + Vector2(7, 0), UIKit.INK, 4.5)


## Injuries that live on the face. Thresholds stack: the worse it gets, the more you see.
func _draw_damage_face() -> void:
	if _dmg < 0.12:
		return
	var c := head_pos + Vector2(5, 4)
	# sweat drops (nervous)
	var sweat := Color("bfe9ff")
	var drip := fposmod(_clock * 1.5, 1.0)
	draw_circle(c + Vector2(-34, -24 + drip * 26.0), 4.5 * (1.0 - drip * 0.4), sweat)
	if _dmg > 0.3:
		# plaster across the cheek
		var p := c + Vector2(24, 18)
		draw_rect(Rect2(p.x - 14, p.y - 6, 28, 12), UIKit.INK)
		draw_rect(Rect2(p.x - 12, p.y - 4, 24, 8), Color("ffd9a8"))
		draw_circle(p, 2.0, Color("d9a066"))
	if _dmg > 0.45:
		# black eye: bruise ring around the near eye
		draw_arc(c + Vector2(15, -4), 15.0, 0.0, TAU, 16, Color("7a3a9a"), 6.0)
	if _dmg > 0.6:
		# nose / mouth bleeding + missing tooth
		draw_polyline(PackedVector2Array([c + Vector2(4, 12), c + Vector2(6, 22 + sin(_clock * 4.0) * 2.0), c + Vector2(4, 32)]), blood, 4.5)
		draw_circle(c + Vector2(4, 33), 3.5, blood)
		draw_circle(c + Vector2(12, 26), 3.0, Color("fff4dc"))
	if _dmg > 0.75:
		# tears
		draw_line(c + Vector2(-16, 6), c + Vector2(-19, 30), Color("bfe9ff"), 4.0)
		draw_line(c + Vector2(28, 6), c + Vector2(31, 28), Color("bfe9ff"), 4.0)


## Body-level injuries drawn over everything: head bandage, dizzy stars, smoke.
func _draw_damage_overlay() -> void:
	if _dmg < 0.12:
		return
	var h := head_pos
	if _dmg > 0.55:
		# head bandage with a red stain
		draw_arc(h + Vector2(0, -2), head_r - 4.0, PI * 1.12, PI * 1.88, 12, UIKit.INK, 15.0)
		draw_arc(h + Vector2(0, -2), head_r - 4.0, PI * 1.12, PI * 1.88, 12, Color("fff4dc"), 10.0)
		draw_circle(h + Vector2(14, -head_r + 4.0), 5.0, blood)
	if _dmg > 0.4:
		# forearm wrap + torn-sleeve zigzag on the shoulder
		for k in 3:
			var p := _hand_r.lerp(sh_r, 0.35 + k * 0.08)
			draw_circle(p, 8.0, Color("fff4dc"))
			draw_arc(p, 8.0, 0.0, TAU, 10, UIKit.INK, 2.5)
		draw_polyline(PackedVector2Array([sh_l + Vector2(-8, 4), sh_l + Vector2(0, 14), sh_l + Vector2(6, 6),
				sh_l + Vector2(12, 18)]), UIKit.INK, 4.0)
	if _dmg > 0.3:
		# scuff / bruise smudges on the torso
		var m := hip.lerp(shoulder, 0.5)
		draw_circle(m + Vector2(10, 4), 9.0, Color(0.2, 0.05, 0.25, 0.45))
		draw_circle(m + Vector2(-8, -10), 6.0, Color(0.2, 0.05, 0.25, 0.35))
	if _dmg > 0.75:
		# dizzy stars orbiting the head
		for k in 3:
			var a := _clock * 4.0 + k * TAU / 3.0
			_star(h + Vector2(cos(a) * (head_r + 10.0), -head_r - 14.0 + sin(a) * 8.0), 9.0, Color("fff36b"))
	if _dmg > 0.88:
		# smoking head
		for k in 3:
			var ph := fposmod(_clock * 0.8 + k * 0.33, 1.0)
			var c := Color(0.3, 0.3, 0.35, 0.55 * (1.0 - ph))
			draw_circle(h + Vector2(-10 + k * 12 + sin(ph * 9.0) * 6.0, -head_r - 14.0 - ph * 50.0), 7.0 + ph * 10.0, c)


func _draw_impact_star() -> void:
	# comic POW burst over the torso: spiky polygon that pops and fades
	var k := _impact / 0.45
	var center := hip.lerp(shoulder, 0.5) + Vector2(0, -10)
	var r := 52.0 * (1.0 + (1.0 - k) * 0.6)
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(center + Vector2.from_angle(i * TAU / 16.0 + _boil * 0.3) * (r if i % 2 == 0 else r * 0.55))
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.3, clampf(k * 1.6, 0.0, 1.0)))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(UIKit.INK, clampf(k * 1.6, 0.0, 1.0)), 5.0)


func _star(p: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(p + Vector2.from_angle(i * PI / 5.0 - PI / 2.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, UIKit.INK, 2.5)


# Subclass hooks (drawn in this order: back, legs, torso+detail, arms, head, face, front).
func _draw_back() -> void:
	pass


func _draw_torso_detail() -> void:
	pass


func _draw_front() -> void:
	pass


# ---------------------------------------------------------------- draw helpers

func ink_disc(p: Vector2, r: float, color: Color) -> void:
	draw_circle(p, r + 4.0, UIKit.INK)
	draw_circle(p, r, color)


func ink_limb(a: Vector2, b: Vector2, w: float, color: Color) -> void:
	var o := w + 8.0
	draw_line(a, b, UIKit.INK, o)
	draw_circle(a, o * 0.5, UIKit.INK)
	draw_circle(b, o * 0.5, UIKit.INK)
	draw_line(a, b, color, w)
	draw_circle(a, w * 0.5, color)
	draw_circle(b, w * 0.5, color)


## Filled polygon with a fat, wobbly (boiling) ink outline.
func ink_poly(pts: PackedVector2Array, fill: Color, ink_w := 7.0) -> void:
	draw_colored_polygon(pts, fill)
	var o := PackedVector2Array()
	for i in pts.size():
		o.append(pts[i] + _jit(i))
	o.append(o[0])
	draw_polyline(o, UIKit.INK, ink_w)


func ink_oval(center: Vector2, rx: float, ry: float, color: Color, outline := false) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
	if outline or color != UIKit.INK:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, UIKit.INK, 4.5)
