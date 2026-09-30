class_name CameraRig
extends Camera2D
## Subtle 2D camera: beat bob + zoom punches + shake trauma from GameFeel.
## Everything is applied through `offset`/`zoom` each frame from state, so the camera
## can never be left displaced: reset() and _exit_tree() hard-zero it.

@export var bob_pixels := 3.0
@export var zoom_decay := 7.0

var _zoom_punch := 0.0
var _bob := 0.0
var _roll := 0.0
var _roll_v := 0.0
var _roll_sign := 1.0
var clock: BeatClock


func _ready() -> void:
	position = Vector2(640, 360)
	GameFeel.hit_fx.connect(_on_hit_fx)


func _exit_tree() -> void:
	if GameFeel.hit_fx.is_connected(_on_hit_fx):
		GameFeel.hit_fx.disconnect(_on_hit_fx)


func reset() -> void:
	_zoom_punch = 0.0
	_bob = 0.0
	offset = Vector2.ZERO
	_roll = 0.0
	_roll_v = 0.0
	rotation = 0.0
	zoom = Vector2.ONE


func on_beat(strong: bool) -> void:
	_roll_sign = -_roll_sign
	_roll_v += 0.05 * _roll_sign * (1.6 if strong else 1.0)
	_bob = 1.0 if strong else 0.55


func punch(amount: float) -> void:
	_zoom_punch = maxf(_zoom_punch, amount * Settings.motion_scale())


func _on_hit_fx(_rating: int, lane: int, _pos: Vector2, prof: Dictionary) -> void:
	_roll_v += [-1.0, 0.0, 0.0, 1.0][lane] * 0.12 * prof.camera_zoom * 30.0
	punch(prof.camera_zoom)


func _process(delta: float) -> void:
	_zoom_punch = lerpf(_zoom_punch, 0.0, clampf(zoom_decay * delta, 0.0, 1.0))
	_bob = lerpf(_bob, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	var bob := Vector2(0, _bob * bob_pixels * Settings.motion_scale())
	offset = GameFeel.shake_offset() + bob
	zoom = Vector2.ONE * (1.0 + _zoom_punch)
	# slight camera roll (beat sway + lane kick); off when screen shake is off
	_roll_v += (-_roll * 120.0 - _roll_v * 9.0) * delta
	_roll += _roll_v * delta
	rotation = _roll * Settings.motion_scale() if Settings.screen_shake else 0.0
