class_name TableFelt
extends Control
## The play surface: neon-rimmed oval table, the active-colour ring around the
## discard pile and the rotating direction arrows.

var center := Vector2.ZERO
var radii := Vector2(400, 220)
var discard_center := Vector2.ZERO
var active_color := -1:
	set(v):
		active_color = v
		queue_redraw()
var direction := 1
var _rot := 0.0
var _color_anim := 1.0
var _shown_color := Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not Settings.reduced_motion())


func set_active_color(c: int) -> void:
	var col := Palette.card_color(c) if c >= 0 and c < 4 else Color(1, 1, 1, 0.5)
	if _shown_color == Color.TRANSPARENT:
		_shown_color = col
	var from := _shown_color
	var tw := create_tween()
	tw.tween_method(func(x: float):
		_shown_color = from.lerp(col, x)
		queue_redraw(), 0.0, 1.0, 0.35 * Settings.anim_scale())
	active_color = c


func _process(dt: float) -> void:
	_rot += dt * 0.35 * direction
	queue_redraw()


func _draw() -> void:
	# table oval: layered fills for a soft vignette and a glowing rim
	var pts := _ellipse(center, radii, 64)
	draw_colored_polygon(_ellipse(center + Vector2(0, 14), radii * 1.02, 64), Color(0, 0, 0, 0.35))
	draw_colored_polygon(pts, Color("18144a"))
	for i in 5:
		var k := 1.0 - i * 0.16
		draw_colored_polygon(_ellipse(center, radii * k, 48), Color("1f1a5e").lerp(Color("2a2378"), i / 4.0) * Color(1, 1, 1, 0.55))
	var rim := pts.duplicate()
	rim.append(pts[0])
	for i in 3:
		draw_polyline(rim, Color(Palette.ELECTRIC, 0.12 / (i + 1)), 6.0 + i * 6.0, true)
	draw_polyline(rim, Color(Palette.ELECTRIC, 0.65), 2.5, true)
	# inner decorative ring
	var inner := _ellipse(center, radii * 0.62, 48)
	inner.append(inner[0])
	draw_polyline(inner, Color(1, 1, 1, 0.05), 2.0, true)

	# direction arrows + active colour ring around the discard pile
	var col := _shown_color if _shown_color.a > 0 else Color(1, 1, 1, 0.4)
	var rr := 118.0
	draw_arc(discard_center, rr, 0, TAU, 64, Color(col, 0.18), 18.0, true)
	draw_arc(discard_center, rr, 0, TAU, 64, Color(col, 0.85), 3.0, true)
	for i in 3:
		var a := _rot + i * TAU / 3.0
		var span := 0.55
		draw_arc(discard_center, rr + 18.0, a, a + span, 16, Color(col, 0.75), 4.0, true)
		var tip_a := a + span if direction > 0 else a
		var tip := discard_center + Vector2.from_angle(tip_a) * (rr + 18.0)
		var tangent := Vector2.from_angle(tip_a + PI / 2 * direction)
		var normal := Vector2.from_angle(tip_a)
		draw_colored_polygon(PackedVector2Array([tip + tangent * 12.0, tip - normal * 7.0, tip + normal * 7.0]), Color(col, 0.9))


static func _ellipse(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
