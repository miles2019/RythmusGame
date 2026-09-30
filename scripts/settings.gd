extends Node
## Autoload "Settings": options, accessibility flags, audio buses, key profile.
## Everything that tunes feel for accessibility funnels through here so effects
## elsewhere only ever ask "how much?" (fx_scale / motion_scale) and never hard-code it.

signal changed

const SAVE_PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_UI := "UI"
const BUS_HITS := "Hits"
const BUS_VOICE := "Voice"

var input_profile := InputProfile.new()

var music_volume := 0.8
var ui_volume := 0.8
var hit_volume := 0.9
var voice_volume := 0.8

var screen_shake := true
var reduced_background := false
var reduced_particles := false
var reduced_animation := false  # dampens squash/pop/hit-pause, not gameplay
var alt_colors := false
var note_scale := 1.0           # 0.8 .. 1.4
var latency_ms := 0.0           # positive = audio arrives late -> notes shift later
var timing_scale := 1.0         # widens/narrows all hit windows

# Lane palette. Shapes (arrows) always differ, colours are only a helper.
const LANE_COLORS := [Color("ff4fa3"), Color("35e6ff"), Color("b6ff4a"), Color("ffb03b")]
const LANE_COLORS_ALT := [Color("cc79a7"), Color("56b4e9"), Color("f0e442"), Color("e69f00")]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_audio()


func lane_color(lane: int) -> Color:
	return LANE_COLORS_ALT[lane] if alt_colors else LANE_COLORS[lane]


## 0..1 multiplier for particles / rings.
func fx_scale() -> float:
	return 0.35 if reduced_particles else 1.0


## 0..1 multiplier for squash, pop and hit-pause amplitude.
func motion_scale() -> float:
	return 0.3 if reduced_animation else 1.0


func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_UI, BUS_HITS, BUS_VOICE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_audio() -> void:
	_set_bus(BUS_MUSIC, music_volume)
	_set_bus(BUS_UI, ui_volume)
	_set_bus(BUS_HITS, hit_volume)
	_set_bus(BUS_VOICE, voice_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func notify_changed() -> void:
	apply_audio()
	changed.emit()
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in ["music_volume", "ui_volume", "hit_volume", "voice_volume", "screen_shake",
			"reduced_background", "reduced_particles", "reduced_animation", "alt_colors",
			"note_scale", "latency_ms", "timing_scale"]:
		cfg.set_value("options", key, get(key))
	cfg.set_value("input", "keys", input_profile.to_array())
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # first start: defaults
	for key in ["music_volume", "ui_volume", "hit_volume", "voice_volume", "screen_shake",
			"reduced_background", "reduced_particles", "reduced_animation", "alt_colors",
			"note_scale", "latency_ms", "timing_scale"]:
		if cfg.has_section_key("options", key):
			set(key, cfg.get_value("options", key))
	input_profile.from_array(cfg.get_value("input", "keys", null))
