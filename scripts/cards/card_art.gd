class_name CardArt
extends RefCounted
## Procedural Card Rush card art (original design): white rim, gradient colour
## panel with diagonal "rush" stripes, a round medallion with the symbol and
## corner indices. Every colour also has its own shape (triangle / circle /
## square / diamond) so cards are distinguishable without colour vision.

const Kind = CardDefinition.Kind
const CC = CardDefinition.CardColor

## Card back styles (cosmetics). Keys are cosmetic ids.
const BACKS := {
	"back_classic": {"base": Color("15164a"), "base2": Color("0a0b24"), "accent": Color("2fa8ff"), "accent2": Color("ff5a5f")},
	"back_sunset": {"base": Color("4a1538"), "base2": Color("1c0a1f"), "accent": Color("ffd23f"), "accent2": Color("ff5a5f")},
	"back_aurora": {"base": Color("0f3a40"), "base2": Color("06161d"), "accent": Color("19d3c5"), "accent2": Color("9b6bff")},
	"back_gold": {"base": Color("2b2210"), "base2": Color("120d04"), "accent": Color("ffd23f"), "accent2": Color("fff1b8")},
	"back_neon": {"base": Color("200f45"), "base2": Color("0b0520"), "accent": Color("ff3df2"), "accent2": Color("2fa8ff")},
	"back_mint": {"base": Color("103a2b"), "base2": Color("061a12"), "accent": Color("3ee08f"), "accent2": Color("d7fff0")},
}

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = UiKit.font(800, true)
	return _font


static func rounded_rect_points(r: Rect2, radius: float, seg := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position + Vector2(r.size.x - radius, radius), -PI / 2],
		[r.position + Vector2(r.size.x - radius, r.size.y - radius), 0.0],
		[r.position + Vector2(radius, r.size.y - radius), PI / 2],
		[r.position + Vector2(radius, radius), PI],
	]
	for cdata in corners:
		var center: Vector2 = cdata[0]
		var a0: float = cdata[1]
		for i in seg + 1:
			pts.append(center + Vector2.from_angle(a0 + (PI / 2) * i / seg) * radius)
	return pts


static func _gradient_poly(ci: CanvasItem, pts: PackedVector2Array, r: Rect2, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## Draws a soft drop shadow under a card-shaped rect.
static func draw_shadow(ci: CanvasItem, r: Rect2, strength := 1.0, lift := 0.0) -> void:
	var rad := r.size.x * 0.11
	var off := Vector2(r.size.x * 0.03, r.size.x * (0.05 + lift * 0.06))
	for i in 3:
		var grow := r.size.x * (0.015 + i * 0.03)
		var rr := Rect2(r.position + off - Vector2(grow, grow) * 0.5, r.size + Vector2(grow, grow))
		ci.draw_colored_polygon(rounded_rect_points(rr, rad + grow), Color(0, 0, 0, 0.16 * strength / (i + 1)))


## opts: selected, playable, dim, glow_color, back (cosmetic id), shadow, colorblind
static func draw_card(ci: CanvasItem, r: Rect2, d: CardDefinition, opts := {}) -> void:
	var w := r.size.x
	var rad := w * 0.11
	if opts.get("shadow", true):
		draw_shadow(ci, r, 1.0, 1.0 if opts.get("selected", false) else 0.0)
	if opts.get("selected", false) or opts.get("playable", false):
		var gc: Color = opts.get("glow_color", Palette.SUN if opts.get("selected", false) else Palette.ELECTRIC)
		for i in 3:
			var g := w * (0.025 + i * 0.022)
			ci.draw_colored_polygon(rounded_rect_points(r.grow(g), rad + g), Color(gc, 0.32 - i * 0.09))
	if d == null:
		_draw_back(ci, r, str(opts.get("back", "back_classic")))
	else:
		_draw_face(ci, r, d, bool(opts.get("colorblind", Palette._colorblind())))
	if opts.get("dim", false):
		ci.draw_colored_polygon(rounded_rect_points(r, rad), Color(0.02, 0.02, 0.08, 0.5))


static func _draw_face(ci: CanvasItem, r: Rect2, d: CardDefinition, colorblind: bool) -> void:
	var w := r.size.x
	var rad := w * 0.11
	# rim
	ci.draw_colored_polygon(rounded_rect_points(r, rad), Color("f4f6ff"))
	var inner := r.grow(-w * 0.055)
	var base := Palette.card_color(d.color)
	var top := base.lightened(0.18)
	var bottom := base.darkened(0.22)
	if d.is_wild():
		top = Color("2a2a5e")
		bottom = Color("0c0c22")
	var ipts := rounded_rect_points(inner, rad * 0.7)
	_gradient_poly(ci, ipts, inner, top, bottom)
	# diagonal rush stripes (kept inside the inner panel)
	var stripe := Color(1, 1, 1, 0.09)
	for k in 3:
		var y := inner.position.y + inner.size.y * (0.3 + k * 0.2)
		var slant := inner.size.x * 0.35
		var th := inner.size.y * 0.035
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(inner.position.x, y + slant * 0.5), Vector2(inner.end.x, y - slant * 0.5),
			Vector2(inner.end.x, y - slant * 0.5 + th), Vector2(inner.position.x, y + slant * 0.5 + th)]), stripe)
	# gloss
	ci.draw_colored_polygon(PackedVector2Array([
		inner.position + Vector2(rad * 0.4, 0), inner.position + Vector2(inner.size.x * 0.75, 0),
		inner.position + Vector2(0, inner.size.y * 0.42), inner.position + Vector2(0, rad * 0.4)]), Color(1, 1, 1, 0.08))

	# medallion
	var c := r.get_center()
	var mr := w * 0.36
	ci.draw_circle(c + Vector2(0, w * 0.02), mr * 1.04, Color(0, 0, 0, 0.25))
	if d.is_wild():
		_draw_pinwheel(ci, c, mr)
		ci.draw_arc(c, mr, 0, TAU, 40, Color("f4f6ff"), w * 0.035, true)
	else:
		ci.draw_circle(c, mr, Color("f8f9ff"))
		ci.draw_arc(c, mr * 0.86, 0, TAU, 40, Color(base, 0.35), w * 0.02, true)
	_draw_symbol(ci, d, c, mr * 1.25, base, true)
	# corner indices
	var cs := w * 0.2
	var tl := r.position + Vector2(w * 0.17, w * 0.2)
	_draw_symbol(ci, d, tl, cs, base, false)
	if d.color != CC.WILD:
		draw_color_shape(ci, d.color, tl + Vector2(0, cs * (1.25 if colorblind else 1.05)), cs * (0.42 if colorblind else 0.3), Color("f8f9ff"))
	ci.draw_set_transform(r.end - Vector2(w * 0.17, w * 0.2), PI, Vector2.ONE)
	_draw_symbol(ci, d, Vector2.ZERO, cs, base, false)
	if d.color != CC.WILD:
		draw_color_shape(ci, d.color, Vector2(0, cs * (1.25 if colorblind else 1.05)), cs * (0.42 if colorblind else 0.3), Color("f8f9ff"))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if colorblind and d.color != CC.WILD:
		# large shape watermark under the medallion symbol
		draw_color_shape(ci, d.color, c + Vector2(0, mr * 0.62), mr * 0.2, Color(base, 0.9))


static func _draw_pinwheel(ci: CanvasItem, c: Vector2, rad: float) -> void:
	for i in 4:
		var a0 := -PI / 2 + i * PI / 2 + PI / 4
		var pts := PackedVector2Array([c])
		for k in 9:
			pts.append(c + Vector2.from_angle(a0 + (PI / 2) * k / 8.0) * rad)
		ci.draw_colored_polygon(pts, Palette.card_color(i))


## Draws the card's symbol centred at `c`. `size` ~ glyph height.
static func _draw_symbol(ci: CanvasItem, d: CardDefinition, c: Vector2, size: float, base: Color, big: bool) -> void:
	var fill := base if big else Color("f8f9ff")
	var outline := Color(0.05, 0.05, 0.15, 0.85)
	if d.is_wild() and big:
		fill = Color("f8f9ff")
	match d.kind:
		Kind.NUMBER:
			_text(ci, str(d.number), c, size, fill, outline, big)
			if d.number == 6 or d.number == 9:
				var uw := size * 0.32
				var uy := c.y + size * 0.42
				ci.draw_line(Vector2(c.x - uw / 2, uy), Vector2(c.x + uw / 2, uy), fill, size * 0.07)
		Kind.DRAW_TWO:
			_text(ci, "+2", c, size * 0.86, fill, outline, big)
		Kind.WILD_DRAW_FOUR:
			_text(ci, "+4", c, size * 0.86, fill, outline, big)
		Kind.SKIP:
			var rr := size * 0.32
			var lw := size * 0.1
			if not big:
				ci.draw_arc(c, rr, 0, TAU, 28, outline, lw * 1.8, true)
			ci.draw_arc(c, rr, 0, TAU, 28, fill, lw, true)
			ci.draw_line(c + Vector2(-rr, rr) * 0.7, c + Vector2(rr, -rr) * 0.7, fill, lw, true)
		Kind.REVERSE:
			_draw_reverse(ci, c, size * 0.36, fill, outline if not big else Color.TRANSPARENT)
		Kind.WILD:
			if not big:
				_draw_pinwheel(ci, c, size * 0.32)
				ci.draw_arc(c, size * 0.32, 0, TAU, 24, Color("f8f9ff"), size * 0.05, true)


static func _draw_reverse(ci: CanvasItem, c: Vector2, rr: float, fill: Color, outline: Color) -> void:
	var lw := rr * 0.28
	for k in 2:
		var dir := 1.0 if k == 0 else -1.0
		var p0 := c + Vector2(-rr * 0.75, -rr * 0.35) * dir
		var p1 := c + Vector2(rr * 0.55, -rr * 0.35) * dir
		var tip := c + Vector2(rr * 0.95, -rr * 0.35) * dir
		if outline.a > 0:
			ci.draw_line(p0, p1, outline, lw * 1.8, true)
		ci.draw_line(p0, p1, fill, lw, true)
		ci.draw_colored_polygon(PackedVector2Array([tip, p1 + Vector2(0, -rr * 0.32) , p1 + Vector2(0, rr * 0.32)]), fill)


static func _text(ci: CanvasItem, s: String, c: Vector2, size: float, fill: Color, outline: Color, big: bool) -> void:
	var f := font()
	var fs := int(size)
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base_y := c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - fs * 0.08
	var pos := Vector2(c.x - tw / 2.0, base_y)
	var ow := int(maxf(2.0, size * (0.14 if big else 0.18)))
	ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, outline)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)


## Colour-blind helper shapes: red ▲, yellow ●, green ■, blue ◆.
static func draw_color_shape(ci: CanvasItem, color: int, c: Vector2, s: float, col: Color) -> void:
	match color:
		CC.RED:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		CC.YELLOW:
			ci.draw_circle(c, s * 0.85, col)
		CC.GREEN:
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.78, Vector2(s, s) * 1.56), col)
		CC.BLUE:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)


static func _draw_back(ci: CanvasItem, r: Rect2, style_id: String) -> void:
	var st: Dictionary = BACKS.get(style_id, BACKS["back_classic"])
	var w := r.size.x
	var rad := w * 0.11
	ci.draw_colored_polygon(rounded_rect_points(r, rad), Color("f4f6ff"))
	var inner := r.grow(-w * 0.055)
	var ipts := rounded_rect_points(inner, rad * 0.7)
	_gradient_poly(ci, ipts, inner, st["base"], st["base2"])
	# neon frame
	var frame := inner.grow(-w * 0.05)
	ci.draw_polyline(_closed(rounded_rect_points(frame, rad * 0.5)), Color(st["accent"], 0.85), maxf(1.0, w * 0.018), true)
	# rush stripes
	for k in 4:
		var y := inner.position.y + inner.size.y * (0.18 + k * 0.2)
		var slant := inner.size.x * 0.5
		var th := inner.size.y * 0.025
		var col: Color = st["accent"] if k % 2 == 0 else st["accent2"]
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(frame.position.x, y + slant * 0.5), Vector2(frame.end.x, y - slant * 0.5),
			Vector2(frame.end.x, y - slant * 0.5 + th), Vector2(frame.position.x, y + slant * 0.5 + th)]), Color(col, 0.14))
	# logo
	if w >= 40:
		var c := r.get_center()
		ci.draw_set_transform(c, -0.32, Vector2.ONE)
		var f := font()
		var fs := int(w * 0.24)
		for i in 2:
			var s := "CARD" if i == 0 else "RUSH"
			var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(-tw / 2.0, (i - 0.5) * fs * 0.85 + fs * 0.32)
			ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.22), Color(0, 0, 0, 0.6))
			ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, st["accent"] if i == 0 else st["accent2"])
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		ci.draw_circle(r.get_center(), w * 0.18, Color(st["accent"], 0.8))


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out
