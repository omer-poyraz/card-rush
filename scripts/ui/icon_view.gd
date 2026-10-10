class_name IconView
extends Control
## Original vector icon set drawn with primitives — crisp at any DPI, no files.

@export var icon := "play":
	set(v):
		icon = v
		queue_redraw()
@export var color := Palette.TEXT:
	set(v):
		color = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_icon(self, icon, Rect2(Vector2.ZERO, size), color)


static func draw_icon(ci: CanvasItem, name: String, r: Rect2, col: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var c := r.get_center()
	var w := maxf(2.0, s * 0.09)
	var u := s / 2.0  # unit
	match name:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.55, -u * 0.75), c + Vector2(u * 0.8, 0), c + Vector2(-u * 0.55, u * 0.75)]), col)
		"bot":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.75, -u * 0.45), Vector2(u * 1.5, u * 1.15)), col, false, w)
			ci.draw_circle(c + Vector2(-u * 0.32, u * 0.08), u * 0.14, col)
			ci.draw_circle(c + Vector2(u * 0.32, u * 0.08), u * 0.14, col)
			ci.draw_line(c + Vector2(0, -u * 0.45), c + Vector2(0, -u * 0.8), col, w)
			ci.draw_circle(c + Vector2(0, -u * 0.85), u * 0.12, col)
		"plus":
			ci.draw_line(c + Vector2(-u * 0.7, 0), c + Vector2(u * 0.7, 0), col, w * 1.4)
			ci.draw_line(c + Vector2(0, -u * 0.7), c + Vector2(0, u * 0.7), col, w * 1.4)
		"join":
			ci.draw_arc(c + Vector2(u * 0.2, 0), u * 0.7, -PI * 0.6, PI * 0.6, 20, col, w)
			ci.draw_line(c + Vector2(-u * 0.9, 0), c + Vector2(u * 0.25, 0), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.35, 0), c + Vector2(0, -u * 0.3), c + Vector2(0, u * 0.3)]), col)
		"friends":
			ci.draw_circle(c + Vector2(-u * 0.32, -u * 0.3), u * 0.26, col)
			ci.draw_arc(c + Vector2(-u * 0.32, u * 0.65), u * 0.5, PI, TAU, 16, col, w)
			ci.draw_circle(c + Vector2(u * 0.4, -u * 0.38), u * 0.22, col)
			ci.draw_arc(c + Vector2(u * 0.4, u * 0.45), u * 0.42, PI * 1.1, TAU, 14, col, w)
		"profile":
			ci.draw_circle(c + Vector2(0, -u * 0.3), u * 0.33, col)
			ci.draw_arc(c + Vector2(0, u * 0.85), u * 0.7, PI * 1.05, TAU - PI * 0.05, 20, col, w * 1.2)
		"collection":
			for i in 3:
				var o := Vector2(-u * 0.35 + i * u * 0.35, -u * 0.1 * (1 - i))
				ci.draw_set_transform(c + o, (i - 1) * 0.25, Vector2.ONE)
				ci.draw_rect(Rect2(Vector2(-u * 0.35, -u * 0.55), Vector2(u * 0.7, u * 1.05)), col, false, w)
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"missions":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.65, -u * 0.8), Vector2(u * 1.3, u * 1.6)), col, false, w)
			for i in 3:
				var y := -u * 0.4 + i * u * 0.4
				ci.draw_polyline(PackedVector2Array([c + Vector2(-u * 0.4, y), c + Vector2(-u * 0.28, y + u * 0.12), c + Vector2(-u * 0.1, y - u * 0.12)]), col, w * 0.8)
				ci.draw_line(c + Vector2(u * 0.02, y), c + Vector2(u * 0.45, y), col, w * 0.8)
		"store":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-u * 0.75, -u * 0.6), c + Vector2(-u * 0.5, -u * 0.6), c + Vector2(-u * 0.3, u * 0.35), c + Vector2(u * 0.6, u * 0.35), c + Vector2(u * 0.75, -u * 0.3), c + Vector2(-u * 0.42, -u * 0.3)]), col, w)
			ci.draw_circle(c + Vector2(-u * 0.2, u * 0.65), u * 0.13, col)
			ci.draw_circle(c + Vector2(u * 0.5, u * 0.65), u * 0.13, col)
		"settings":
			ci.draw_arc(c, u * 0.42, 0, TAU, 24, col, w * 1.3)
			for i in 8:
				var a := i * TAU / 8.0
				ci.draw_line(c + Vector2.from_angle(a) * u * 0.55, c + Vector2.from_angle(a) * u * 0.85, col, w * 1.6)
			ci.draw_circle(c, u * 0.14, col)
		"help":
			ci.draw_arc(c, u * 0.85, 0, TAU, 28, col, w)
			ci.draw_arc(c + Vector2(0, -u * 0.18), u * 0.3, -PI, PI * 0.4, 12, col, w)
			ci.draw_line(c + Vector2(u * 0.09, u * 0.08), c + Vector2(0, u * 0.25), col, w)
			ci.draw_circle(c + Vector2(0, u * 0.5), w * 0.8, col)
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(u * 0.25, -u * 0.65), c + Vector2(-u * 0.4, 0), c + Vector2(u * 0.25, u * 0.65)]), col, w * 1.4)
		"close":
			ci.draw_line(c + Vector2(-u * 0.55, -u * 0.55), c + Vector2(u * 0.55, u * 0.55), col, w * 1.4)
			ci.draw_line(c + Vector2(u * 0.55, -u * 0.55), c + Vector2(-u * 0.55, u * 0.55), col, w * 1.4)
		"pause", "menu":
			for i in 3:
				var y := (i - 1) * u * 0.5
				ci.draw_line(c + Vector2(-u * 0.6, y), c + Vector2(u * 0.6, y), col, w * 1.3)
		"mic", "mic_off":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.22, -u * 0.8), Vector2(u * 0.44, u * 0.9)), col)
			ci.draw_arc(c + Vector2(0, -u * 0.05), u * 0.45, 0, PI, 14, col, w)
			ci.draw_line(c + Vector2(0, u * 0.4), c + Vector2(0, u * 0.75), col, w)
			if name == "mic_off":
				ci.draw_line(c + Vector2(-u * 0.75, -u * 0.75), c + Vector2(u * 0.75, u * 0.75), Palette.CORAL, w * 1.3)
		"speaker", "speaker_off":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.8, -u * 0.25), c + Vector2(-u * 0.4, -u * 0.25), c + Vector2(0, -u * 0.65), c + Vector2(0, u * 0.65), c + Vector2(-u * 0.4, u * 0.25), c + Vector2(-u * 0.8, u * 0.25)]), col)
			if name == "speaker":
				ci.draw_arc(c + Vector2(u * 0.05, 0), u * 0.35, -PI * 0.35, PI * 0.35, 10, col, w)
				ci.draw_arc(c + Vector2(u * 0.05, 0), u * 0.65, -PI * 0.35, PI * 0.35, 12, col, w)
			else:
				ci.draw_line(c + Vector2(u * 0.25, -u * 0.3), c + Vector2(u * 0.8, u * 0.3), Palette.CORAL, w * 1.2)
				ci.draw_line(c + Vector2(u * 0.8, -u * 0.3), c + Vector2(u * 0.25, u * 0.3), Palette.CORAL, w * 1.2)
		"wifi":
			for i in 3:
				ci.draw_arc(c + Vector2(0, u * 0.6), u * (0.35 + i * 0.35), -PI * 0.75, -PI * 0.25, 12, col, w)
			ci.draw_circle(c + Vector2(0, u * 0.6), w, col)
		"crown":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.8, u * 0.5), c + Vector2(-u * 0.8, -u * 0.4), c + Vector2(-u * 0.4, 0), c + Vector2(0, -u * 0.6), c + Vector2(u * 0.4, 0), c + Vector2(u * 0.8, -u * 0.4), c + Vector2(u * 0.8, u * 0.5)]), col)
		"coin":
			ci.draw_circle(c, u * 0.85, col)
			ci.draw_arc(c, u * 0.6, 0, TAU, 24, col.darkened(0.35), w)
			ci.draw_rect(Rect2(c - Vector2(u * 0.12, u * 0.3), Vector2(u * 0.24, u * 0.6)), col.darkened(0.35))
		"copy":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.7, -u * 0.45), Vector2(u * 0.95, u * 1.15)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.3, -u * 0.8), Vector2(u * 0.95, u * 1.15)), col, false, w)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.6, -u * 0.1), Vector2(u * 1.2, u * 0.9)), col)
			ci.draw_arc(c + Vector2(0, -u * 0.1), u * 0.4, PI, TAU, 14, col, w * 1.2)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-u * 0.6, 0), c + Vector2(-u * 0.15, u * 0.45), c + Vector2(u * 0.65, -u * 0.5)]), col, w * 1.5)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := u * (0.85 if i % 2 == 0 else 0.38)
				pts.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 10.0) * rr)
			ci.draw_colored_polygon(pts, col)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.55, -u * 0.75), c + Vector2(u * 0.55, -u * 0.75), c + Vector2(u * 0.4, -u * 0.05), c + Vector2(0, u * 0.2), c + Vector2(-u * 0.4, -u * 0.05)]), col)
			ci.draw_arc(c + Vector2(-u * 0.55, -u * 0.45), u * 0.25, PI * 0.5, PI * 1.5, 10, col, w)
			ci.draw_arc(c + Vector2(u * 0.55, -u * 0.45), u * 0.25, -PI * 0.5, PI * 0.5, 10, col, w)
			ci.draw_line(c + Vector2(0, u * 0.2), c + Vector2(0, u * 0.55), col, w * 1.4)
			ci.draw_rect(Rect2(c + Vector2(-u * 0.4, u * 0.55), Vector2(u * 0.8, u * 0.22)), col)
		"card":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.5, -u * 0.75), Vector2(u * 1.0, u * 1.5)), col, false, w)
			ci.draw_circle(c, u * 0.22, col)
		"draw":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.6, -u * 0.55), Vector2(u * 0.9, u * 1.3)), col, false, w)
			ci.draw_line(c + Vector2(u * 0.55, -u * 0.75), c + Vector2(u * 0.55, -u * 0.05), col, w * 1.2)
			ci.draw_line(c + Vector2(u * 0.2, -u * 0.4), c + Vector2(u * 0.9, -u * 0.4), col, w * 1.2)
		"skip":
			ci.draw_arc(c, u * 0.7, 0, TAU, 28, col, w * 1.4)
			ci.draw_line(c + Vector2(-u * 0.5, u * 0.5), c + Vector2(u * 0.5, -u * 0.5), col, w * 1.4)
		"reverse":
			ci.draw_arc(c, u * 0.62, PI * 1.1, PI * 1.85, 14, col, w * 1.3)
			ci.draw_arc(c, u * 0.62, PI * 0.1, PI * 0.85, 14, col, w * 1.3)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(PI * 1.85) * u * 0.62 + Vector2(u * 0.25, -u * 0.05), c + Vector2.from_angle(PI * 1.85) * u * 0.62 + Vector2(-u * 0.12, -u * 0.25), c + Vector2.from_angle(PI * 1.85) * u * 0.62 + Vector2(-u * 0.05, u * 0.2)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(PI * 0.85) * u * 0.62 + Vector2(-u * 0.25, u * 0.05), c + Vector2.from_angle(PI * 0.85) * u * 0.62 + Vector2(u * 0.12, u * 0.25), c + Vector2.from_angle(PI * 0.85) * u * 0.62 + Vector2(u * 0.05, -u * 0.2)]), col)
		"link":
			ci.draw_arc(c + Vector2(-u * 0.3, u * 0.3), u * 0.32, PI * 0.25, PI * 1.75, 12, col, w)
			ci.draw_arc(c + Vector2(u * 0.3, -u * 0.3), u * 0.32, -PI * 0.75, PI * 0.75, 12, col, w)
			ci.draw_line(c + Vector2(-u * 0.2, u * 0.2), c + Vector2(u * 0.2, -u * 0.2), col, w)
		"block":
			ci.draw_arc(c, u * 0.7, 0, TAU, 28, col, w * 1.3)
			ci.draw_line(c + Vector2(-u * 0.5, -u * 0.5), c + Vector2(u * 0.5, u * 0.5), col, w * 1.3)
		"flag":
			ci.draw_line(c + Vector2(-u * 0.55, -u * 0.8), c + Vector2(-u * 0.55, u * 0.8), col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.5, -u * 0.75), c + Vector2(u * 0.7, -u * 0.45), c + Vector2(-u * 0.5, -u * 0.1)]), col)
		"ad":
			ci.draw_rect(Rect2(c + Vector2(-u * 0.85, -u * 0.55), Vector2(u * 1.7, u * 1.1)), col, false, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.2, -u * 0.3), c + Vector2(u * 0.35, 0), c + Vector2(-u * 0.2, u * 0.3)]), col)
		"refresh":
			ci.draw_arc(c, u * 0.6, -PI * 0.2, PI * 1.5, 20, col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.6, -u * 0.6), c + Vector2(u * 0.75, -u * 0.05), c + Vector2(u * 0.2, -u * 0.2)]), col)
		_:
			ci.draw_circle(c, u * 0.5, col)
