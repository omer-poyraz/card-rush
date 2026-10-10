class_name ColorTile
extends Button
## Colour choice for wild cards: swatch + colour-blind shape + name + how
## many cards of that colour the player holds.

var color_index := 0
var held := 0


func _init(c := 0, count := 0) -> void:
	color_index = c
	held = count
	custom_minimum_size = Vector2(124, 150)
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "%d" % (c + 1)
	for st in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(func(): _hover(true))
	mouse_exited.connect(func(): _hover(false))
	resized.connect(func(): pivot_offset = size / 2.0)


func _hover(on: bool) -> void:
	create_tween().tween_property(self, "scale", Vector2(1.06, 1.06) if on else Vector2.ONE, 0.1)


func _draw() -> void:
	var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	var col := Palette.card_color(color_index)
	if is_hovered() or has_focus():
		draw_colored_polygon(CardArt.rounded_rect_points(r.grow(6), 26), Color(col, 0.35))
	draw_colored_polygon(CardArt.rounded_rect_points(r, 20), col.darkened(0.15))
	draw_colored_polygon(CardArt.rounded_rect_points(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55)), 20), col)
	CardArt.draw_color_shape(self, color_index, r.position + Vector2(r.size.x / 2.0, r.size.y * 0.36), 22.0, Color("f8f9ff"))
	var f := UiKit.font(800, true)
	var name := Loc.color_name(color_index)
	var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string_outline(f, Vector2(r.get_center().x - tw / 2.0, r.end.y - 34), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.5))
	draw_string(f, Vector2(r.get_center().x - tw / 2.0, r.end.y - 34), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	var cnt := "×%d" % held
	var cw := f.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2(r.get_center().x - cw / 2.0, r.end.y - 10), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.85))
