class_name LogoView
extends Control
## The Card Rush wordmark: slanted "CARD" / "RUSH" with speed lines and a
## mini card fan. Drawn procedurally, so it is original and resolution-free.

@export var shine := 0.0:   # 0..1 sweep position of the light pass (animated)
	set(v):
		shine = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var h := size.y
	var f := UiKit.font(800, true)
	var fs := int(h * 0.42)
	var skew := Transform2D(Vector2(1, 0), Vector2(-0.18, 1), Vector2.ZERO)
	# mini fan of cards on the left
	var fan_c := Vector2(h * 0.42, h * 0.55)
	for i in 3:
		var col: Color = [Palette.CORAL, Palette.SUN, Palette.ELECTRIC][i]
		draw_set_transform(fan_c, (i - 1) * 0.32, Vector2.ONE)
		var r := Rect2(Vector2(-h * 0.17, -h * 0.27), Vector2(h * 0.34, h * 0.5))
		draw_colored_polygon(CardArt.rounded_rect_points(r, h * 0.05), Color("f4f6ff"))
		draw_colored_polygon(CardArt.rounded_rect_points(r.grow(-h * 0.025), h * 0.035), col)
		draw_circle(Vector2.ZERO, h * 0.09, Color("f4f6ff"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var x0 := h * 0.95
	# speed lines
	for i in 3:
		var y := h * (0.3 + i * 0.2)
		var w := h * (0.5 - i * 0.1)
		draw_line(Vector2(x0 - w - h * 0.12, y), Vector2(x0 - h * 0.12, y), Color(Palette.ELECTRIC, 0.55 - i * 0.12), maxf(2.0, h * 0.03), true)
	var words := ["CARD", "RUSH"]
	var cols := [[Color("f4f6ff"), Color("c9d2ff")], [Palette.SUN, Palette.CORAL]]
	for wi in 2:
		var y := h * (0.44 + wi * 0.42)
		var x := x0 + wi * h * 0.18
		var m := Transform2D(0, Vector2(x, y)) * skew
		draw_set_transform_matrix(m)
		var s: String = words[wi]
		var cx := 0.0
		for ci in s.length():
			var ch := s[ci]
			var t := float(ci) / maxi(1, s.length() - 1)
			var col: Color = cols[wi][0].lerp(cols[wi][1], t)
			draw_string_outline(f, Vector2(cx, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.16), Color(0.03, 0.02, 0.12, 0.95))
			draw_string(f, Vector2(cx, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			# light pass
			var d := absf(shine * (s.length() + 4) - 2 - ci - wi)
			if d < 1.2 and shine > 0.0:
				draw_string(f, Vector2(cx, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, (1.2 - d) * 0.6))
			cx += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

