extends Node
func _ready() -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var b := PackedByteArray()
	b.resize(4000)
	for i in 2000:
		b.encode_s16(i * 2, int(sin(i * 0.3) * 20000))
	w.data = b
	DirAccess.make_dir_recursive_absolute("user://testwav")
	w.save_to_wav("user://testwav/ping.wav")
	var p := ProjectSettings.globalize_path("user://testwav/ping.wav")
	print("set: '", Settings.set_hit_sound(2, p), "' stream=", Settings.hit_stream(2) != null, " files=", Settings.hit_sound_files)
	GameFeel.trigger_hit(0, 2, Vector2.ZERO, 5)
	print("reject bad ext: ", Settings.set_hit_sound(1, "C:/x.txt"))
	Settings.clear_hit_sound(2)
	print("cleared: stream=", Settings.hit_stream(2), " files=", Settings.hit_sound_files)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://testwav/ping.wav"))
	get_tree().quit()
