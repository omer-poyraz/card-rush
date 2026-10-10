class_name Backdrop
extends Control
## Layered night background: vertical gradient, two soft neon glows and a few
## slowly drifting particles. Particle count follows the quality setting and
## animation stops when hidden or in reduced-motion mode.

@export var particles := 36
@export var glow_a := Palette.VIOLET
@export var glow_b := Palette.ELECTRIC

var _dots: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := TextureRect.new()
	grad.texture = _linear(Palette.BG_NIGHT, Palette.BG_DEEP)
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	for g in [[glow_a, Vector2(0.15, 0.2), 0.9], [glow_b, Vector2(0.88, 0.85), 0.8]]:
		var tr_ := TextureRect.new()
		tr_.texture = _radial(Color(g[0], 0.32))
		tr_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr_.stretch_mode = TextureRect.STRETCH_SCALE
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_.set_meta("center", g[1])
		tr_.set_meta("scale", g[2])
		add_child(tr_)
	resized.connect(_layout)
	_layout()
	var q := Settings.quality()
	var n: int = [0, particles / 2, particles][q]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		_dots.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.2, 3.2), rng.randf_range(0.004, 0.018), rng.randf() * TAU,
			[Palette.ELECTRIC, Palette.SUN, Palette.TEAL, Palette.CORAL, Palette.VIOLET][i % 5]])
	set_process(n > 0 and not Settings.reduced_motion())


func _layout() -> void:
	for c in get_children():
		if c.has_meta("center"):
			var k: float = c.get_meta("scale")
			var sz := Vector2(size.x, size.x) * k
			var ctr: Vector2 = c.get_meta("center")
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2(size.x * ctr.x, size.y * ctr.y) - sz / 2.0
			c.size = sz


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	for d in _dots:
		d[0].y -= d[2] * dt
		if d[0].y < -0.02:
			d[0].y = 1.02
	queue_redraw()


func _draw() -> void:
	for d in _dots:
		var p := Vector2(d[0].x * size.x + sin(_t * 0.6 + d[3]) * 12.0, d[0].y * size.y)
		var a := 0.25 + 0.2 * sin(_t * 1.3 + d[3])
		draw_circle(p, d[1] * 2.6, Color(d[4], a * 0.18))
		draw_circle(p, d[1], Color(d[4], a))


static func _linear(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	g.add_point(0.55, top.lerp(Palette.BG_PURPLE, 0.35))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0)
	t.fill_to = Vector2(0.5, 1)
	t.width = 16
	t.height = 256
	return t


static func _radial(c: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t
