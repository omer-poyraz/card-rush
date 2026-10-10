class_name SeatView
extends Control
## An opponent (or the local player) badge: avatar, name, card count, turn
## glow + timer arc, UNO / bot / connection markers and the catch button.

signal catch_requested(seat: int)
signal seat_pressed(seat: int)

var seat := -1
var compact := false
var is_turn := false
var catchable := false
var speaking := 0.0           # 0..1 voice level (Stage 6)
var timer_frac := -1.0        # 0..1 remaining turn time, -1 hidden
var target_mode := false      # 7-0 target picking highlight

var _avatar: AvatarView
var _name: Label
var _count: Label
var _score: Label
var _tag: Label
var _catch_btn: Button
var _data := {}
var _pulse := 0.0


func _init(p_seat := -1, p_compact := false) -> void:
	seat = p_seat
	compact = p_compact
	custom_minimum_size = Vector2(150, 92) if not compact else Vector2(118, 80)
	size = custom_minimum_size


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var av_size := 54.0 if not compact else 44.0
	_avatar = AvatarView.new()
	_avatar.size = Vector2(av_size, av_size)
	_avatar.position = Vector2(8, (size.y - av_size) / 2.0)
	add_child(_avatar)
	var x := av_size + 16.0
	_name = UiKit.label("", 17 if not compact else 15, Palette.TEXT, 800)
	_name.position = Vector2(x, 8)
	_name.size = Vector2(size.x - x - 6, 22)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_name)
	_count = UiKit.label("", 24 if not compact else 20, Palette.SUN, 800, true)
	_count.position = Vector2(x + 22, size.y * 0.36)
	add_child(_count)
	_score = UiKit.label("", 14, Palette.TEXT_DIM, 700)
	_score.position = Vector2(x, size.y - 24)
	add_child(_score)
	_tag = UiKit.label("", 13, Color("1b1405"), 800)
	var sb := UiKit.flat(Palette.SUN, 8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	_tag.add_theme_stylebox_override("normal", sb)
	_tag.position = Vector2(size.x - 50, -12)
	_tag.visible = false
	add_child(_tag)
	_catch_btn = UiKit.button(tr("TABLE_CATCH"), UiKit.Variant.DANGER, Vector2(size.x - 10, 40))
	_catch_btn.add_theme_font_size_override("font_size", 18)
	_catch_btn.position = Vector2(5, size.y + 6)
	_catch_btn.visible = false
	_catch_btn.pressed.connect(func(): catch_requested.emit(seat))
	add_child(_catch_btn)


func update(p: Dictionary, turn: bool, can_catch: bool, show_score: bool) -> void:
	_data = p
	is_turn = turn
	catchable = can_catch
	_avatar.avatar = int(p.get("avatar", 0))
	_avatar.dimmed = not bool(p.get("connected", true))
	_name.text = str(p.get("name", ""))
	_count.text = "×%d" % int(p.get("count", 0))
	_score.text = Loc.t("TABLE_POINTS_N", [int(p.get("score", 0))]) if show_score else ""
	var tag := ""
	if not bool(p.get("connected", true)):
		tag = tr("TABLE_TAG_OFFLINE")
	elif bool(p.get("uno", false)) and int(p.get("count", 0)) == 1:
		tag = tr("CALL_WORD_SHORT")
	elif bool(p.get("is_bot", false)):
		tag = tr("TABLE_TAG_BOT")
	_tag.text = tag
	_tag.visible = tag != ""
	_catch_btn.visible = can_catch
	set_process(turn or can_catch or speaking > 0.0 or target_mode)
	queue_redraw()


func card_anchor_global() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y * 0.5)


func _process(dt: float) -> void:
	_pulse += dt
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		seat_pressed.emit(seat)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var glow := 0.0
	var gc := Palette.ELECTRIC
	if is_turn:
		glow = 0.6 + 0.25 * sin(_pulse * 5.0)
		gc = Palette.SUN
	if target_mode:
		glow = 0.7 + 0.3 * sin(_pulse * 7.0)
		gc = Palette.TEAL
	if catchable:
		glow = 0.7 + 0.3 * sin(_pulse * 9.0)
		gc = Palette.CORAL
	if glow > 0.0:
		for i in 3:
			var g := 3.0 + i * 4.0
			draw_colored_polygon(CardArt.rounded_rect_points(r.grow(g), 18 + g), Color(gc, 0.18 * glow / (i + 1)))
	draw_colored_polygon(CardArt.rounded_rect_points(r, 18), Color(0.07, 0.07, 0.19, 0.9))
	draw_polyline(_closed(CardArt.rounded_rect_points(r, 18)), Color(gc, 0.85) if glow > 0.0 else Color(1, 1, 1, 0.12), 2.0, true)
	# mini card icon next to the count
	var ic := Rect2(Vector2(_avatar.size.x + 16.0, size.y * 0.42), Vector2(16, 22))
	draw_colored_polygon(CardArt.rounded_rect_points(ic, 3), Color("f4f6ff"))
	draw_colored_polygon(CardArt.rounded_rect_points(ic.grow(-2), 2), Color("2a2a6e"))
	# turn timer arc around the avatar
	var ac := _avatar.position + _avatar.size / 2.0
	var ar := _avatar.size.x / 2.0 + 4.0
	if timer_frac >= 0.0 and is_turn:
		var col := Palette.SUCCESS.lerp(Palette.CORAL, 1.0 - timer_frac)
		draw_arc(ac, ar, -PI / 2, -PI / 2 + TAU * timer_frac, 32, col, 4.0, true)
	if speaking > 0.05:
		draw_arc(ac, ar + 4.0, 0, TAU, 32, Color(Palette.TEAL, 0.4 + speaking * 0.6), 3.0, true)


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var out := p.duplicate()
	out.append(p[0])
	return out
