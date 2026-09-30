class_name PauseMenu
extends CanvasLayer
## Pause overlay. Always processes (the tree is paused while it is open).
## Resuming plays a short 3-2-1 so the player can find the beat again.

signal resume_finished
signal restart_pressed
signal quit_pressed

var _root: Control
var _column: VBoxContainer
var _count: Label
var _resume_btn: Button
var _counting := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_column = UIKit.modal_column(_root, 0.72, 480.0)
	var title := UIKit.label("PAUSED", 54, UIKit.AMBER, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_resume_btn = UIKit.button("RESUME", UIKit.CYAN)
	var restart := UIKit.button("RESTART", UIKit.LIME)
	var quit := UIKit.button("QUIT TO MENU", UIKit.HOT)
	for b in [_resume_btn, restart, quit]:
		_column.add_child(b)
	_resume_btn.pressed.connect(_on_resume)
	restart.pressed.connect(func():
		_close()
		restart_pressed.emit())
	quit.pressed.connect(func():
		_close()
		quit_pressed.emit())
	_count = UIKit.label("", 140, UIKit.PAPER, 14)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_count)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_counting = false
	_count.text = ""
	_column.get_parent().get_parent().visible = true
	_root.visible = true
	_column.get_parent().visible = true
	_resume_btn.grab_focus()
	GameFeel.play_sfx("ui_back")


func _close() -> void:
	_counting = false
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and not _counting and event.is_action_pressed("ui_cancel"):
		_on_resume()
		get_viewport().set_input_as_handled()


func _on_resume() -> void:
	if _counting:
		return
	_counting = true
	_column.get_parent().visible = false # hide the panel, keep the dim
	var tw := GameFeel.new_tween(_count, "count")
	for n in ["3", "2", "1"]:
		tw.tween_callback(_show_number.bind(n))
		tw.tween_interval(0.5)
	tw.tween_callback(func():
		_close()
		resume_finished.emit())


func _show_number(n: String) -> void:
	_count.text = n
	GameFeel.play_sfx("tick", "UI", 1.0 + (3 - int(n)) * 0.25)
	_count.pivot_offset = _count.size * 0.5
	GameFeel.pop(_count, 0.6, 0.45)
