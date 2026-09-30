class_name InputProfile
extends RefCounted
## Maps physical keys / gamepad buttons to the four lanes (0=left 1=down 2=up 3=right).
## Only *detection* lives here: timing evaluation and visuals are somebody else's job.

const LANES := 4
const LANE_NAMES := ["LEFT", "DOWN", "UP", "RIGHT"]
const SLOTS := 2 # slot 0 = arrows, slot 1 = WASD by default; both freely rebindable

const DEFAULT_KEYS := [
	[KEY_LEFT, KEY_A],
	[KEY_DOWN, KEY_S],
	[KEY_UP, KEY_W],
	[KEY_RIGHT, KEY_D],
]
# Gamepad: d-pad plus face buttons (fixed, so a controller works out of the box).
const PAD_BUTTONS := [
	[JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_X],
	[JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A],
	[JOY_BUTTON_DPAD_UP, JOY_BUTTON_Y],
	[JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B],
]

var keys: Array = []  # keys[lane][slot] = physical keycode (int)


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	keys = []
	for lane in LANES:
		keys.append(DEFAULT_KEYS[lane].duplicate())


## Returns the lane an event belongs to, or -1. Echo events never count.
func lane_for_event(ev: InputEvent) -> int:
	if ev is InputEventKey:
		if ev.echo:
			return -1
		var code: int = ev.physical_keycode
		for lane in LANES:
			for slot in SLOTS:
				if keys[lane][slot] == code:
					return lane
	elif ev is InputEventJoypadButton:
		for lane in LANES:
			for b in PAD_BUTTONS[lane]:
				if b == ev.button_index:
					return lane
	return -1


## Human readable key hint for a lane, e.g. "← / A".
func lane_hint(lane: int) -> String:
	var parts: PackedStringArray = []
	for slot in SLOTS:
		parts.append(key_name(keys[lane][slot]))
	return " / ".join(parts)


static func key_name(code: int) -> String:
	match code:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		0: return "-"
	return OS.get_keycode_string(code)


## Assign a key; a key can only live on one lane, so it is stolen from any other slot.
func rebind(lane: int, slot: int, code: int) -> void:
	for l in LANES:
		for s in SLOTS:
			if keys[l][s] == code:
				keys[l][s] = 0
	keys[lane][slot] = code


func to_array() -> Array:
	return keys.duplicate(true)


func from_array(a: Variant) -> void:
	if not (a is Array) or a.size() != LANES:
		return
	for lane in LANES:
		if not (a[lane] is Array) or a[lane].size() != SLOTS:
			return
	for lane in LANES:
		for slot in SLOTS:
			keys[lane][slot] = int(a[lane][slot])
