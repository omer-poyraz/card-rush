class_name AvatarView
extends Control
## Procedural avatar: gradient disc with a simple original mascot face/emblem.
## Index-based so it is tiny to send over the network.

const COUNT := 12
const BG := [
	[Color("ff5a5f"), Color("b3264b")], [Color("2fa8ff"), Color("1d4bd6")], [Color("ffd23f"), Color("e07b14")],
	[Color("19d3c5"), Color("0d7f8a")], [Color("9b6bff"), Color("5a2fc9")], [Color("3ee08f"), Color("13895a")],
	[Color("ff8ad8"), Color("b93a9a")], [Color("ffa64d"), Color("c4511a")], [Color("7fd1ff"), Color("3a6fd8")],
	[Color("c6ff6b"), Color("5aa31f")], [Color("ff6b6b"), Color("6b2fd1")], [Color("f4f6ff"), Color("8a95c9")],
]

@export var avatar := 0:
	set(v):
		avatar = posmod(v, COUNT)
		queue_redraw()
@export var ring_color := Color.TRANSPARENT:
	set(v):
		ring_color = v
		queue_redraw()
@export var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	var cols: Array = BG[avatar]
	if ring_color.a > 0:
		draw_circle(c, r, ring_color)
	var rr := r * (0.88 if ring_color.a > 0 else 1.0)
	# fake radial gradient with a few concentric discs
	for i in 6:
		var t := i / 5.0
		draw_circle(c + Vector2(-rr, -rr) * 0.12 * t, rr * (1.0 - t * 0.55), cols[1].lerp(cols[0], t))
	var ink := Color(0.06, 0.05, 0.16, 0.9)
	var u := rr
	match avatar % 4:
		0:  # happy face
			draw_circle(c + Vector2(-u * 0.3, -u * 0.12), u * 0.11, ink)
			draw_circle(c + Vector2(u * 0.3, -u * 0.12), u * 0.11, ink)
			draw_arc(c + Vector2(0, u * 0.08), u * 0.38, 0.2, PI - 0.2, 14, ink, u * 0.09, true)
		1:  # cool shades
			draw_rect(Rect2(c + Vector2(-u * 0.6, -u * 0.3), Vector2(u * 0.52, u * 0.28)), ink)
			draw_rect(Rect2(c + Vector2(u * 0.08, -u * 0.3), Vector2(u * 0.52, u * 0.28)), ink)
			draw_line(c + Vector2(-u * 0.25, u * 0.35), c + Vector2(u * 0.25, u * 0.35), ink, u * 0.09, true)
		2:  # wink
			draw_line(c + Vector2(-u * 0.45, -u * 0.12), c + Vector2(-u * 0.15, -u * 0.12), ink, u * 0.1, true)
			draw_circle(c + Vector2(u * 0.3, -u * 0.12), u * 0.12, ink)
			draw_arc(c + Vector2(0, u * 0.1), u * 0.3, 0.3, PI - 0.3, 12, ink, u * 0.09, true)
		3:  # star eyes
			for sx in [-1, 1]:
				var e := c + Vector2(sx * u * 0.3, -u * 0.12)
				var pts := PackedVector2Array()
				for k in 10:
					pts.append(e + Vector2.from_angle(-PI / 2 + k * TAU / 10.0) * u * (0.18 if k % 2 == 0 else 0.08))
				draw_colored_polygon(pts, ink)
			draw_circle(c + Vector2(0, u * 0.35), u * 0.12, ink)
	if dimmed:
		draw_circle(c, r, Color(0.02, 0.02, 0.08, 0.6))
