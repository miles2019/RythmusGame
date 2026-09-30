class_name SlantMenu
extends Control
## FNF-style main menu list: big slanted white text on slanted black bars; the selected item
## turns into a coloured bar, slides out and wobbles. Keyboard (up/down/enter), controller
## and mouse. One control draws everything (cheap, no per-button theme overhead).

signal chosen(index: int)
signal moved(index: int)

var items: Array[String] = []
var colors: Array[Color] = []
var selected := 0
var spacing := 84.0
var font_size := 60
var active := true  ## false while an overlay (options/credits) is open

var _offs := PackedFloat32Array()   # smoothed x offset per item
var _pop := PackedFloat32Array()    # selection pop per item
var _t := 0.0


func setup(labels: Array[String], accent_colors: Array[Color]) -> void:
	items = labels
	colors = accent_colors
	_offs.resize(items.size())
	_pop.resize(items.size())
	custom_minimum_size = Vector2(560, spacing * items.size())
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	for i in items.size():
		var target := 34.0 if i == selected else 0.0
		_offs[i] = lerpf(_offs[i], target, clampf(delta * 14.0, 0.0, 1.0))
		_pop[i] = maxf(_pop[i] - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := UIKit.font()
	for i in items.size():
		var y := i * spacing
		var sel := i == selected
		var x := _offs[i]
		var h := spacing - 10.0
		var slant := 26.0
		var bar := PackedVector2Array([Vector2(x, y), Vector2(x + 520.0, y), Vector2(x + 520.0 - slant, y + h), Vector2(x - slant * 0.2, y + h)])
		var col: Color = colors[i] if sel else UIKit.INK
		# hard offset shadow + bar
		var sh := PackedVector2Array()
		for p in bar:
			sh.append(p + Vector2(7, 7))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
		draw_colored_polygon(bar, col)
		var loop := bar.duplicate()
		loop.append(bar[0])
		draw_polyline(loop, UIKit.PAPER if sel else Color(1, 1, 1, 0.25), 4.0 if sel else 2.0)
		# slanted text (fake italic through a skew transform)
		var wob := sin(_t * 9.0) * 2.0 * _pop[i] if sel else 0.0
		var sc := 1.0 + _pop[i] * 0.06
		var origin := Vector2(x + 26.0, y + h * 0.5 + font_size * 0.36 + wob)
		draw_set_transform_matrix(Transform2D(Vector2(sc, 0), Vector2(-0.24, sc), origin))
		draw_string_outline(font, Vector2.ZERO, items[i], HORIZONTAL_ALIGNMENT_LEFT, 480, font_size, 10, UIKit.INK)
		draw_string(font, Vector2.ZERO, items[i], HORIZONTAL_ALIGNMENT_LEFT, 480, font_size, UIKit.PAPER if sel else Color("e8e0ff"))
		draw_set_transform_matrix(Transform2D.IDENTITY)


func select(i: int, silent := false) -> void:
	i = wrapi(i, 0, items.size())
	if i == selected:
		return
	selected = i
	_pop[i] = 1.0
	if not silent:
		GameFeel.play_sfx("ui_move")
	moved.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_down"):
		select(selected + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		select(selected - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_choose()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		var i := int(event.position.y / spacing)
		if i >= 0 and i < items.size():
			select(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := int(event.position.y / spacing)
		if i >= 0 and i < items.size():
			select(i, true)
			_choose()


func _choose() -> void:
	_pop[selected] = 1.5
	GameFeel.play_sfx("ui_confirm")
	GameFeel.squash(self, 1.03, 0.97, 0.3)
	chosen.emit(selected)
