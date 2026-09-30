class_name UIKit
extends RefCounted
## "Neon Ink Pop / Newgrounds" UI building blocks: fat ink outlines, hard offset shadows,
## tilted stickers, starbursts, halftone. One place so every screen shares the same look.

const INK := Color("120a24")
const NIGHT := Color("1c1040")
const PANEL := Color("2b1657")
const PAPER := Color("fff4dc")
const HOT := Color("ff4fa3")
const CYAN := Color("35e6ff")
const LIME := Color("b6ff4a")
const AMBER := Color("ffb03b")
const YELLOW := Color("fff36b")

static var _font: SystemFont


## Heavy poster font when the system has one (Impact on Windows), else Godot's default.
static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Impact", "Haettenschweiler", "Arial Black", "Bangers", "Comic Sans MS"])
		_font.font_weight = 800
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font


## StyleBox with a hard (comic) offset shadow instead of a soft blur.
static func box(fill: Color, border: Color = INK, border_w := 5, radius := 12, shadow := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if shadow > 0:
		sb.shadow_color = INK
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(shadow, shadow)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func label(text: String, size := 28, color := PAPER, outline := 7) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", INK)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bouncy sticker button, tilted a hair. Focus = loud white outline + bright fill (never colour alone).
static func button(text: String, accent := HOT, size := 30, tilt := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 62)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_stylebox_override("normal", box(PANEL, accent, 5))
	b.add_theme_stylebox_override("hover", box(accent, PAPER, 6))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.2), INK, 6, 12, 2))
	b.add_theme_stylebox_override("focus", box(accent, PAPER, 7, 12, 10))
	b.focus_mode = Control.FOCUS_ALL
	b.rotation = tilt
	GameFeel.juice_button(b)
	return b


static func slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 30)
	s.focus_mode = Control.FOCUS_ALL
	var track := box(NIGHT, INK, 3, 8, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", box(HOT, INK, 3, 8, 0))
	s.add_theme_stylebox_override("grabber_area_highlight", box(AMBER, INK, 3, 8, 0))
	return s


static func check(text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_override("font", font())
	c.add_theme_font_size_override("font_size", 22)
	c.add_theme_color_override("font_color", PAPER)
	c.add_theme_color_override("font_outline_color", INK)
	c.add_theme_constant_override("outline_size", 4)
	c.focus_mode = Control.FOCUS_ALL
	return c


## Full-rect dim + centered column; returns the VBox to fill.
static func modal_column(parent: Control, dim := 0.7, width := 620.0) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(INK.r, INK.g, INK.b, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(NIGHT.lightened(0.05), HOT, 6, 18, 10))
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	return v


## Comic starburst polygon (used behind rating words, banners and the title).
static func burst_points(center: Vector2, r_out: float, r_in: float, spikes: int, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var r := r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2.from_angle(rot + i * PI / spikes) * r)
	return pts


static var _halftone_tex: ImageTexture


## 24x24 tile with two dots (staggered): tiled by one draw call instead of ~1000 draw_circle calls.
static func halftone_texture() -> ImageTexture:
	if _halftone_tex == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for c in [Vector2(6, 6), Vector2(18, 18)]:
			for y in 24:
				for x in 24:
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
					var a := clampf(6.0 - d, 0.0, 1.0)
					if a > 0.0:
						img.set_pixel(x, y, Color(1, 1, 1, a))
		_halftone_tex = ImageTexture.create_from_image(img)
	return _halftone_tex


## Halftone dot field (comic shading), tiled texture: a single cheap draw call.
static func draw_halftone(ci: CanvasItem, rect: Rect2, color: Color, _spacing := 14.0, _max_r := 5.0, _falloff_from := Vector2.ZERO) -> void:
	ci.draw_texture_rect(halftone_texture(), rect, true, color)
