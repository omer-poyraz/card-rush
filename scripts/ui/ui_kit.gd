class_name UiKit
extends RefCounted
## Shared UI factory: fonts, the global Theme and styled building blocks.

const FONT_DISPLAY := preload("res://assets/fonts/Baloo2.ttf")
const FONT_BODY := preload("res://assets/fonts/Nunito.ttf")

static var _fonts := {}
static var _theme: Theme


static func font(weight: int, display := false) -> Font:
	var key := "%d_%s" % [weight, display]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = FONT_DISPLAY if display else FONT_BODY
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = fv
	return fv


static func flat(bg: Color, radius := 18, border := 0, border_color := Color.TRANSPARENT, glow := 0, glow_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.shadow_size = glow
	s.shadow_color = glow_color
	s.anti_aliasing = true
	s.corner_detail = 10
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(650)
	t.default_font_size = 22
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.55))

	# Buttons (default = secondary style)
	t.set_font("font", "Button", font(700, true))
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Palette.SUN)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Palette.TEXT_MUTED)
	t.set_stylebox("normal", "Button", flat(Palette.PANEL_LIGHT, 16, 2, Palette.PANEL_EDGE))
	t.set_stylebox("hover", "Button", flat(Palette.PANEL_LIGHT.lightened(0.12), 16, 2, Palette.ELECTRIC, 8, Color(Palette.ELECTRIC, 0.35)))
	t.set_stylebox("pressed", "Button", flat(Palette.PANEL_LIGHT.darkened(0.2), 16, 2, Palette.SUN))
	t.set_stylebox("disabled", "Button", flat(Color(0.12, 0.12, 0.25, 0.7), 16, 2, Color(1, 1, 1, 0.08)))
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, 16, 3, Palette.SUN))

	# Panels
	t.set_stylebox("panel", "PanelContainer", flat(Palette.PANEL, 24, 2, Palette.PANEL_EDGE, 18, Color(0, 0, 0, 0.45)))
	t.set_stylebox("panel", "Panel", flat(Palette.PANEL, 24, 2, Palette.PANEL_EDGE))

	# Inputs
	var le := flat(Color(0.05, 0.05, 0.14, 0.95), 14, 2, Palette.PANEL_EDGE)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", flat(Color(0.05, 0.05, 0.14, 0.95), 14, 2, Palette.ELECTRIC))
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_MUTED)
	t.set_color("caret_color", "LineEdit", Palette.SUN)
	t.set_font_size("font_size", "LineEdit", 24)

	# Sliders
	var track := flat(Color(0.2, 0.2, 0.4), 6)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := flat(Palette.ELECTRIC, 6)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Palette.ELECTRIC.lightened(0.2), 6))
	t.set_icon("grabber", "HSlider", _circle_tex(26, Palette.TEXT))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(28, Palette.SUN))

	# Check buttons / toggles
	t.set_font("font", "CheckButton", font(650))
	t.set_font_size("font_size", "CheckButton", 22)
	t.set_color("font_color", "CheckButton", Palette.TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", Palette.TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_icon("checked", "CheckButton", _toggle_tex(true))
	t.set_icon("unchecked", "CheckButton", _toggle_tex(false))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled", "hover_pressed_mirrored"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "CheckButton", Palette.TEXT_MUTED)
	t.set_icon("checked_disabled", "CheckButton", _toggle_tex(true))
	t.set_icon("unchecked_disabled", "CheckButton", _toggle_tex(false))

	# Option buttons / popups
	t.set_font("font", "OptionButton", font(700))
	t.set_font_size("font_size", "OptionButton", 22)
	t.set_stylebox("panel", "PopupMenu", flat(Palette.BG_NIGHT, 14, 2, Palette.PANEL_EDGE))
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_color("font_color", "PopupMenu", Palette.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Palette.SUN)
	t.set_stylebox("hover", "PopupMenu", flat(Palette.PANEL_LIGHT, 8))

	# Scroll bars: slim
	var sb := flat(Color(1, 1, 1, 0.05), 4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(1, 1, 1, 0.25), 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(1, 1, 1, 0.4), 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(Palette.ELECTRIC, 4))
	t.set_stylebox("scroll", "HScrollBar", sb)
	t.set_stylebox("grabber", "HScrollBar", flat(Color(1, 1, 1, 0.25), 4))

	t.set_stylebox("panel", "TooltipPanel", flat(Palette.BG_NIGHT, 10, 1, Palette.PANEL_EDGE))
	t.set_stylebox("tab_selected", "TabContainer", flat(Palette.PANEL_LIGHT, 12))
	_theme = t
	return t


static func _circle_tex(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


static func _toggle_tex(on: bool) -> ImageTexture:
	var w := 64
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Palette.SUCCESS if on else Color(0.25, 0.25, 0.45)
	var r := h / 2.0
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var col := Color(bg, a)
			var kd := px.distance_to(Vector2(knob_x, r))
			var ka := clampf(r - 3.0 - kd, 0.0, 1.0)
			col = col.blend(Color(1, 1, 1, ka))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --- building blocks ---------------------------------------------------------------

enum Variant { SECONDARY, PRIMARY, ACCENT, DANGER, GHOST, SUCCESS }


static func button(text_key: String, variant := Variant.SECONDARY, min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text_key
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	style_button(b, variant)
	b.pressed.connect(func(): Audio.play("button", 0.05))
	b.mouse_entered.connect(func(): if not b.disabled: Audio.play("hover", 0.1, -8.0))
	return b


static func style_button(b: Button, variant: int) -> void:
	var base: Color
	var edge: Color
	match variant:
		Variant.PRIMARY:
			base = Color("1f6fe0")
			edge = Palette.ELECTRIC
		Variant.ACCENT:
			base = Color("e0a514")
			edge = Palette.SUN
		Variant.DANGER:
			base = Color("c8344a")
			edge = Palette.CORAL
		Variant.SUCCESS:
			base = Color("17996a")
			edge = Palette.SUCCESS
		Variant.GHOST:
			base = Color(1, 1, 1, 0.04)
			edge = Color(1, 1, 1, 0.18)
		_:
			for st in ["normal", "hover", "pressed", "focus"]:
				b.remove_theme_stylebox_override(st)
			for fc in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.remove_theme_color_override(fc)
			return
	b.add_theme_stylebox_override("normal", flat(base, 16, 2, edge, 6, Color(edge, 0.25)))
	b.add_theme_stylebox_override("hover", flat(base.lightened(0.12), 16, 2, edge.lightened(0.3), 12, Color(edge, 0.45)))
	b.add_theme_stylebox_override("pressed", flat(base.darkened(0.2), 16, 2, Palette.SUN, 4, Color(edge, 0.3)))
	b.add_theme_stylebox_override("focus", flat(Color.TRANSPARENT, 16, 3, Palette.SUN))
	if variant == Variant.ACCENT:
		b.add_theme_color_override("font_color", Color("1b1405"))
		b.add_theme_color_override("font_hover_color", Color("1b1405"))
		b.add_theme_color_override("font_pressed_color", Color("1b1405"))


static func label(text: String, size := 22, color := Palette.TEXT, weight := 650, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, display))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 44) -> Label:
	var l := label(text, size, Palette.TEXT, 800, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.1, 0.8))
	return l


static func panel(radius := 24) -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat(Palette.PANEL, radius, 2, Palette.PANEL_EDGE, 20, Color(0, 0, 0, 0.5))
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", s)
	return p


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 0, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	if h == 0 and w == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func icon_button(icon_name: String, tooltip_key := "", size := 56.0, variant := Variant.SECONDARY) -> Button:
	var b := button("", variant, Vector2(size, size))
	var ic := IconView.new()
	ic.icon = icon_name
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = size * 0.2
	ic.offset_top = size * 0.2
	ic.offset_right = -size * 0.2
	ic.offset_bottom = -size * 0.2
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.tooltip_text = tooltip_key
	return b
