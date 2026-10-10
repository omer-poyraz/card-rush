class_name TableView
extends Control
## The match table. Receives authoritative (view, events) updates from a
## MatchClient, animates the events in order and then snaps to the snapshot,
## so animations can never drift from the real state. It only ever sends
## action REQUESTS; the authority decides.

signal leave_requested
signal match_over(view: Dictionary, events: Array)

const Kind = CardDefinition.Kind
const Phase = GameState.Phase
const PILE_SIZE := Vector2(104, 156)

var client: MatchClient
var me := 0
var view := {}
var defs: Array[CardDefinition] = DeckProfile.build(DeckProfile.CLASSIC_108)
var back_style := "back_classic"

var _queue: Array = []
var _busy := false
var _speed := 1.0
var _shown_counts: Array = []
var _rules := RuleProfile.classic()

# nodes
var felt: TableFelt
var piles: Control
var seats_layer: Control
var hand: HandView
var fx: Control
var my_seat: SeatView
var seat_views := {}           # seat -> SeatView
var deck_views: Array[CardView] = []
var discard_views: Array[CardView] = []
var deck_label: Label
var uno_btn: Button
var draw_btn: Button
var hint: Label
var info: Label
var menu_btn: Button
var status_label: Label
var _overlay: Control           # current in-table prompt (colour picker etc.)
var _pending_play := {}
var _target_cb := Callable()
var _last_turn_serial := -1
var _stats := {"cards_played": 0, "uno_calls": 0, "catches": 0}
var _timer_tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	felt = TableFelt.new()
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(felt)
	piles = Control.new()
	piles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	piles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(piles)
	for i in 3:
		var b := CardView.new()
		b.face_up = false
		b.set_card_size(PILE_SIZE)
		b.cast_shadow = i == 0
		piles.add_child(b)
		deck_views.append(b)
	deck_views.back().interactive = true
	deck_views.back().pressed.connect(func(_v): _on_draw_pressed())
	deck_label = UiKit.label("", 16, Palette.TEXT_DIM, 800)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piles.add_child(deck_label)
	seats_layer = Control.new()
	seats_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seats_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seats_layer)

	hand = HandView.new()
	add_child(hand)
	hand.play_requested.connect(_request_play)
	hand.selection_changed.connect(_on_selection)

	hint = UiKit.label("", 19, Palette.TEXT_DIM, 700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	uno_btn = Button.new()
	uno_btn.text = tr("CALL_WORD")
	uno_btn.custom_minimum_size = Vector2(118, 118)
	uno_btn.size = uno_btn.custom_minimum_size
	uno_btn.pivot_offset = uno_btn.size / 2.0
	uno_btn.add_theme_font_override("font", UiKit.font(800, true))
	uno_btn.add_theme_font_size_override("font_size", 34)
	uno_btn.add_theme_color_override("font_color", Color("1b1405"))
	uno_btn.add_theme_color_override("font_hover_color", Color("1b1405"))
	uno_btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	uno_btn.add_theme_stylebox_override("normal", UiKit.flat(Palette.SUN, 59, 4, Color("fff1b8"), 16, Color(Palette.SUN, 0.5)))
	uno_btn.add_theme_stylebox_override("hover", UiKit.flat(Palette.SUN.lightened(0.15), 59, 4, Color.WHITE, 22, Color(Palette.SUN, 0.7)))
	uno_btn.add_theme_stylebox_override("pressed", UiKit.flat(Palette.CORAL, 59, 4, Color.WHITE, 10, Color(Palette.CORAL, 0.5)))
	uno_btn.add_theme_stylebox_override("disabled", UiKit.flat(Color(1, 1, 1, 0.06), 59, 3, Color(1, 1, 1, 0.12)))
	uno_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	uno_btn.pressed.connect(_on_uno_pressed)
	add_child(uno_btn)

	draw_btn = UiKit.button(tr("TABLE_DRAW"), UiKit.Variant.PRIMARY, Vector2(220, 66))
	draw_btn.pressed.connect(_on_draw_pressed)
	add_child(draw_btn)

	my_seat = SeatView.new(-1, false)
	add_child(my_seat)

	menu_btn = UiKit.icon_button("menu", tr("PAUSE_TITLE"), 58)
	menu_btn.pressed.connect(func(): leave_requested.emit())
	add_child(menu_btn)
	info = UiKit.label("", 18, Palette.TEXT_DIM, 800)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	status_label = UiKit.label("", 16, Palette.TEXT_MUTED, 700)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status_label)

	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	resized.connect(_layout)
	_layout()
	Audio.play_music("music_table")


func bind(c: MatchClient) -> void:
	client = c
	me = c.seat
	my_seat.seat = me
	client.updated.connect(_on_update)
	client.action_rejected.connect(_on_rejected)
	client.connection_changed.connect(_on_connection)
	client.flush()


# --- layout ---------------------------------------------------------------------------

func _layout() -> void:
	var W := size.x
	var H := size.y
	if W <= 0:
		return
	var compact_h := H < 680
	felt.center = Vector2(W / 2.0, H * 0.43)
	felt.radii = Vector2(minf(W * 0.36, 560.0), H * 0.27)
	var deck_c := felt.center + Vector2(-92, 0)
	var disc_c := felt.center + Vector2(78, 0)
	felt.discard_center = disc_c
	for i in deck_views.size():
		deck_views[i].position = deck_c - PILE_SIZE / 2.0 + Vector2(-i * 2.0, -i * 2.5)
	deck_label.position = deck_c + Vector2(-60, PILE_SIZE.y / 2.0 + 4)
	deck_label.size = Vector2(120, 22)
	for dv in discard_views:
		dv.position = disc_c - PILE_SIZE / 2.0 + dv.get_meta("off", Vector2.ZERO)
	felt.queue_redraw()

	var cs := Vector2(116, 174) if not compact_h else Vector2(100, 150)
	hand.card_size = cs
	var left := 205.0
	var right := 270.0
	hand.position = Vector2(left, H - cs.y - 14)
	hand.size = Vector2(W - left - right, cs.y)
	hint.position = Vector2(left, H - cs.y - 62)
	hint.size = Vector2(W - left - right, 26)
	my_seat.position = Vector2(18, H - my_seat.size.y - 22)
	uno_btn.position = Vector2(W - 150, H - 300)
	draw_btn.position = Vector2(W - 248, H - 96)
	menu_btn.position = Vector2(18, 16)
	info.position = Vector2(W / 2.0 - 250, 10)
	info.size = Vector2(500, 26)
	status_label.position = Vector2(W - 420, 14)
	status_label.size = Vector2(400, 24)
	_layout_seats()
	hand.layout(false)


func _layout_seats() -> void:
	var n := _shown_counts.size()
	if n == 0:
		return
	var k := n - 1
	var W := size.x
	var H := size.y
	var c := Vector2(W / 2.0, H * 0.47)
	var r := Vector2(W * 0.42, H * 0.37)
	for i in k:
		var seat := posmod(me + 1 + i, n)
		var sv: SeatView = seat_views.get(seat)
		if sv == null:
			continue
		var a: float
		if k == 1:
			a = deg_to_rad(270.0)
		else:
			a = deg_to_rad(lerpf(196.0, 344.0, float(i) / (k - 1)))
		var p := c + Vector2(cos(a) * r.x, sin(a) * r.y)
		sv.position = p - sv.size / 2.0
		sv.position.y = maxf(sv.position.y, 64.0 if absf(p.x - W / 2.0) < 300 else 12.0)


func _ensure_seats(n: int) -> void:
	if seat_views.size() == n - 1:
		return
	for sv in seat_views.values():
		sv.queue_free()
	seat_views.clear()
	var compact := n > 6
	for i in n:
		if i == me:
			continue
		var sv := SeatView.new(i, compact)
		seats_layer.add_child(sv)
		sv.catch_requested.connect(_on_catch)
		sv.seat_pressed.connect(_on_seat_pressed)
		seat_views[i] = sv
	_layout_seats()


# --- update pipeline ---------------------------------------------------------------------

func _on_update(v: Dictionary, events: Array) -> void:
	_queue.append([v, events])
	if not _busy:
		_run_queue()


func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var item: Array = _queue.pop_front()
		# catch up when updates pile up (slow device, fast bots, reconnect burst)
		_speed = 1.0 if _queue.size() <= 1 else (0.45 if _queue.size() <= 3 else 0.12)
		var v: Dictionary = item[0]
		if view.is_empty():
			_first_view(v)
		for e in item[1]:
			await _animate(e, v)
		_sync(v)
		for e in item[1]:
			if e["t"] == "match_end" or (e["t"] == "round_end"):
				await _show_round_result(e, v, item[1])
	_busy = false


func _first_view(v: Dictionary) -> void:
	_rules = RuleProfile.from_dict(v.get("rules", {}))
	_shown_counts = []
	for p in v["players"]:
		_shown_counts.append(int(p["count"]))
	_ensure_seats(v["players"].size())


func _dur(t: float) -> float:
	return t * _speed * Settings.anim_scale()


func _wait(t: float) -> void:
	if t > 0.0:
		await get_tree().create_timer(_dur(t)).timeout


# --- positions ----------------------------------------------------------------------

func _deck_center() -> Vector2:
	return deck_views.back().global_position + PILE_SIZE / 2.0


func _discard_center() -> Vector2:
	return felt.global_position + felt.discard_center


func _seat_center(seat: int) -> Vector2:
	if seat == me:
		return hand.global_position + Vector2(hand.size.x / 2.0, hand.card_size.y / 2.0)
	var sv: SeatView = seat_views.get(seat)
	return sv.card_anchor_global() if sv else global_position + size / 2.0


func _seat_name(seat: int) -> String:
	if seat == me:
		return tr("TABLE_YOU")
	if view.is_empty() or seat < 0 or seat >= view["players"].size():
		return "?"
	return str(view["players"][seat]["name"])


# --- event animations ----------------------------------------------------------------

func _animate(e: Dictionary, v: Dictionary) -> void:
	match e["t"]:
		"deal":
			await _anim_deal(e, v)
		"first_card":
			Audio.play("card_play")
			await _fly_to_discard(int(e["card"]), _deck_center(), true, 0.0)
		"rebury":
			await _wait(0.1)
		"play":
			await _anim_play(e)
		"draw":
			await _anim_draw(e)
		"skip":
			Audio.play("skip")
			_pop_icon("skip", _seat_center(int(e["p"])), Palette.CORAL)
			await _wait(0.35)
		"reverse":
			Audio.play("reverse")
			felt.direction = int(e["dir"])
			_pop_icon("reverse", _discard_center(), Palette.TEAL)
			await _wait(0.4)
		"color":
			Audio.play("color_pick")
			felt.set_active_color(int(e["color"]))
			_float_text(Loc.t("TABLE_COLOR_IS", [Loc.color_name(int(e["color"]))]), _discard_center() + Vector2(0, -110), Palette.card_color(int(e["color"])))
			await _wait(0.3)
		"uno":
			Audio.play("uno")
			_uno_burst(_seat_center(int(e["p"])))
			if int(e["p"]) == me:
				_stats["uno_calls"] += 1
			await _wait(0.35)
		"caught":
			Audio.play("caught")
			_float_text(Loc.t("TABLE_CAUGHT", [_seat_name(int(e["p"])), _rules.uno_penalty]), _seat_center(int(e["p"])) + Vector2(0, -40), Palette.CORAL, 30)
			if int(e["by"]) == me:
				_stats["catches"] += 1
			_shake(6.0)
			await _wait(0.4)
		"challenge":
			var guilty := bool(e["guilty"])
			var loser := int(e["offender"]) if guilty else int(e["p"])
			var key := "TABLE_CHALLENGE_GUILTY" if guilty else "TABLE_CHALLENGE_INNOCENT"
			Audio.play("penalty")
			_banner(Loc.t(key, [_seat_name(loser)]), Palette.CORAL if not guilty else Palette.SUCCESS)
			await _wait(0.7)
		"reshuffle":
			Audio.play("shuffle")
			_float_text(tr("TABLE_RESHUFFLE"), _deck_center() + Vector2(0, -100), Palette.TEXT_DIM, 22)
			await _jiggle_deck()
		"swap":
			Audio.play("card_special")
			_banner(Loc.t("TABLE_SWAP", [_seat_name(int(e["a"])), _seat_name(int(e["b"]))]), Palette.TEAL)
			await _wait(0.6)
		"rotate":
			Audio.play("card_special")
			_banner(tr("TABLE_ROTATE"), Palette.TEAL)
			await _wait(0.6)
		"turn":
			pass
		"connection":
			var p := int(e["p"])
			Audio.play("join" if e["connected"] else "leave")
			App.toast(Loc.t("TABLE_RECONNECTED" if e["connected"] else "TABLE_DISCONNECTED", [_seat_name(p)]), Palette.SUN)


func _anim_deal(e: Dictionary, v: Dictionary) -> void:
	if has_meta("round_panel"):
		var rp: Variant = get_meta("round_panel")
		if is_instance_valid(rp):
			rp.close()
		remove_meta("round_panel")
	Audio.play("shuffle")
	await _jiggle_deck()
	# clear table visuals from the previous round
	for dv in discard_views:
		dv.queue_free()
	discard_views.clear()
	hand.set_cards([])
	var n: int = v["players"].size()
	for i in n:
		_shown_counts[i] = 0
	_refresh_seats(v)
	var hs := int(e["hand_size"])
	var dealer := int(e["dealer"])
	var mine: Array = e["cards"].get(me, [])
	var fast := Settings.reduced_motion() or n * hs > 50
	for r in hs:
		for k in n:
			var seat := posmod(dealer + 1 + k, n)
			var target := _seat_center(seat)
			if seat == me:
				target = hand.slot_global_position(r, hs)
			var cv := _spawn_flyer(-1, false, _deck_center())
			var tw := cv.create_tween().set_parallel()
			var d := _dur(0.22 if not fast else 0.12)
			tw.tween_property(cv, "global_position", target - cv.size / 2.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "scale", Vector2(0.55, 0.55) if seat != me else Vector2.ONE, d)
			tw.chain().tween_callback(cv.queue_free)
			_shown_counts[seat] += 1
			if seat == me and r < mine.size():
				tw.chain().tween_callback(func(): hand.set_cards(mine.slice(0, r + 1)))
			if k % 2 == 0:
				Audio.play("deal", 0.1, -4.0)
			await get_tree().create_timer(_dur(0.035 if not fast else 0.012)).timeout
		_refresh_seats(v)
	await _wait(0.25)
	hand.set_cards(mine)


func _anim_play(e: Dictionary) -> void:
	var p := int(e["p"])
	var cid := int(e["card"])
	var d := defs[cid]
	var from: Vector2
	var cv: CardView = null
	if p == me:
		cv = hand.take_view(cid)
		_stats["cards_played"] += 1
	if cv != null:
		from = cv.global_position + cv.size / 2.0
		var gp := cv.global_position
		cv.get_parent().remove_child(cv)
		fx.add_child(cv)
		cv.global_position = gp
	else:
		from = _seat_center(p)
	if p < _shown_counts.size():
		_shown_counts[p] = maxi(0, _shown_counts[p] - 1)
		_refresh_seats(view if not view.is_empty() else {})
	var special := d.is_action()
	Audio.play("card_special" if special else "card_play", 0.06)
	await _fly_to_discard(cid, from, true, randf_range(-0.3, 0.3), cv)
	if d.is_wild():
		felt.set_active_color(int(e["color"]))
		_float_text(Loc.t("TABLE_COLOR_IS", [Loc.color_name(int(e["color"]))]), _discard_center() + Vector2(0, -110), Palette.card_color(int(e["color"])))
	else:
		felt.set_active_color(d.color)
	if d.kind == Kind.DRAW_TWO or d.kind == Kind.WILD_DRAW_FOUR:
		_shake(5.0 if d.kind == Kind.DRAW_TWO else 9.0)
		_float_text("+2" if d.kind == Kind.DRAW_TWO else "+4", _discard_center() + Vector2(0, -60), Palette.CORAL, 54)
		Audio.play("penalty")


func _anim_draw(e: Dictionary) -> void:
	var p := int(e["p"])
	var n := int(e["n"])
	var reason := str(e.get("reason", "normal"))
	if n == 0:
		_float_text(tr("TABLE_DECK_EMPTY"), _deck_center() + Vector2(0, -100), Palette.TEXT_DIM, 20)
		await _wait(0.3)
		return
	if reason != "normal":
		_float_text("+%d" % n, _seat_center(p) + Vector2(0, -50), Palette.CORAL, 40)
		if p == me:
			Settings.vibrate(60)
	var cards: Array = e.get("cards", [])
	for i in n:
		Audio.play("card_draw", 0.08)
		var face := p == me and i < cards.size()
		var cv := _spawn_flyer(int(cards[i]) if face else -1, false, _deck_center())
		var target := _seat_center(p)
		if p == me:
			target = hand.slot_global_position(hand.order.size(), hand.order.size() + 1)
		var tw := cv.create_tween().set_parallel()
		var d := _dur(0.28)
		tw.tween_property(cv, "global_position", target - cv.size / 2.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if p != me:
			tw.tween_property(cv, "scale", Vector2(0.55, 0.55), d)
		else:
			_flip(cv, d)
		tw.chain().tween_callback(cv.queue_free)
		if p == me and face:
			var cid := int(cards[i])
			tw.chain().tween_callback(func():
				var ids := hand.order.duplicate()
				ids.append(cid)
				hand.set_cards(ids))
		if p < _shown_counts.size():
			_shown_counts[p] += 1
		await get_tree().create_timer(_dur(0.12)).timeout
		_refresh_seats(view if not view.is_empty() else {})
	await _wait(0.2)


func _spawn_flyer(cid: int, face_up: bool, center: Vector2) -> CardView:
	var cv := CardView.new()
	cv.card_id = cid
	cv.face_up = face_up and cid >= 0
	cv.back_style = back_style
	cv.set_card_size(PILE_SIZE)
	fx.add_child(cv)
	cv.global_position = center - PILE_SIZE / 2.0
	cv.set_meta("pending_face", cid)
	return cv


## Squash-and-reveal flip halfway through a flight.
func _flip(cv: CardView, d: float) -> void:
	var tw := cv.create_tween()
	tw.tween_property(cv, "scale:x", 0.0, d * 0.5)
	tw.tween_callback(func():
		var cid := int(cv.get_meta("pending_face", -1))
		if cid >= 0:
			cv.card_id = cid
			cv.face_up = true)
	tw.tween_property(cv, "scale:x", 1.0, d * 0.5)


func _fly_to_discard(cid: int, from: Vector2, _face: bool, rot: float, existing: CardView = null) -> void:
	var cv := existing
	if cv == null:
		cv = _spawn_flyer(cid, true, from)
		cv.card_id = cid
		cv.face_up = true
	var target := _discard_center()
	var off := Vector2(randf_range(-6, 6), randf_range(-6, 6))
	var d := _dur(0.32)
	var tw := cv.create_tween().set_parallel()
	tw.tween_property(cv, "size", PILE_SIZE, d)
	tw.tween_property(cv, "pivot_offset", PILE_SIZE / 2.0, d)
	tw.tween_property(cv, "global_position", target - PILE_SIZE / 2.0 + off, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation", rot, d)
	tw.tween_property(cv, "scale", Vector2(1.12, 1.12), d * 0.5)
	tw.chain().tween_property(cv, "scale", Vector2.ONE, d * 0.35).set_trans(Tween.TRANS_BACK)
	await tw.finished
	if not is_instance_valid(cv):
		return
	# adopt into the discard pile
	var gp := cv.global_position
	cv.get_parent().remove_child(cv)
	piles.add_child(cv)
	cv.global_position = gp
	cv.set_meta("off", off)
	cv.selected = false
	cv.playable = false
	cv.dim = false
	cv.interactive = false
	discard_views.append(cv)
	while discard_views.size() > 6:
		discard_views.pop_front().queue_free()


func _jiggle_deck() -> void:
	var top: CardView = deck_views.back()
	var base := top.position
	var tw := top.create_tween()
	for i in 3:
		tw.tween_property(top, "position", base + Vector2(6, -3), _dur(0.05))
		tw.tween_property(top, "position", base + Vector2(-6, 2), _dur(0.05))
	tw.tween_property(top, "position", base, _dur(0.05))
	await tw.finished


# --- snapshot sync -------------------------------------------------------------------

func _sync(v: Dictionary) -> void:
	var prev := view
	view = v
	_rules = RuleProfile.from_dict(v.get("rules", {}))
	var n: int = v["players"].size()
	_ensure_seats(n)
	_shown_counts.resize(n)
	for i in n:
		_shown_counts[i] = int(v["players"][i]["count"])
	# discard pile must show the real top card
	var top := int(v["top"])
	if top >= 0 and (discard_views.is_empty() or discard_views.back().card_id != top):
		var cv := CardView.new()
		cv.card_id = top
		cv.set_card_size(PILE_SIZE)
		piles.add_child(cv)
		cv.position = felt.discard_center - PILE_SIZE / 2.0
		cv.set_meta("off", Vector2.ZERO)
		discard_views.append(cv)
	felt.direction = int(v["direction"])
	if felt.active_color != int(v["color"]):
		felt.set_active_color(int(v["color"]))
	deck_label.text = str(int(v["draw_count"]))
	for i in deck_views.size():
		deck_views[i].visible = int(v["draw_count"]) > i * 10 or (i == 0 and int(v["draw_count"]) > 0)
	# hand
	var ids: Array = v["hand"]
	if ids.size() != hand.order.size() or not _same_cards(ids, hand.order):
		hand.set_cards(ids)
	var my_turn := int(v["current"]) == me and int(v["phase"]) in [Phase.PLAYING, Phase.DRAWN_DECISION, Phase.CHALLENGE_DECISION]
	hand.set_state(my_turn, _playable_ids(v))
	_refresh_seats(v)
	_update_controls(v)
	# turn start feedback
	if int(v["current"]) == me and int(v["turn_serial"]) != _last_turn_serial and int(v["phase"]) != Phase.ROUND_OVER and int(v["phase"]) != Phase.MATCH_OVER:
		Audio.play("your_turn")
		Settings.vibrate(25)
	_last_turn_serial = int(v["turn_serial"]) if int(v["current"]) == me else -1
	# someone dropped to their last card
	if not prev.is_empty():
		for i in n:
			if i != me and int(v["players"][i]["count"]) == 1 and int(prev["players"][i]["count"]) != 1:
				Audio.play("opponent_last")
	_prompts(v)
	info.text = _info_text(v)


func _same_cards(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y


func _playable_ids(v: Dictionary) -> Array:
	var out := []
	if int(v["current"]) != me:
		return out
	for c in v["hand"]:
		if RuleEngine.is_playable(_rules, defs, v["hand"], int(c), int(v["top"]), int(v["color"]),
				int(v["pending_draw"]), int(v["phase"]), int(v["drawn_card"])):
			out.append(int(c))
	return out


func _refresh_seats(v: Dictionary) -> void:
	if v.is_empty():
		v = view
	if v.is_empty():
		return
	var show_score := _rules.scoring_mode != RuleProfile.ScoringMode.SINGLE_ROUND
	var vul := int(v.get("uno_vulnerable", -1))
	for seat in seat_views:
		var p: Dictionary = v["players"][seat].duplicate()
		p["count"] = _shown_counts[seat] if seat < _shown_counts.size() else p["count"]
		var sv: SeatView = seat_views[seat]
		sv.update(p, int(v["current"]) == seat and int(v["phase"]) < Phase.ROUND_OVER, vul == seat, show_score)
	var mp: Dictionary = v["players"][me].duplicate()
	mp["name"] = str(mp["name"])
	mp["count"] = hand.order.size()
	my_seat.update(mp, int(v["current"]) == me and int(v["phase"]) < Phase.ROUND_OVER, false, show_score)


func _update_controls(v: Dictionary) -> void:
	var ph := int(v["phase"])
	var my_turn := int(v["current"]) == me
	var hand_n: int = v["hand"].size()
	var pending := int(v["pending_draw"])
	# UNO: before playing the second-to-last card, or to save yourself after forgetting
	var can_uno := (my_turn and hand_n == 2 and ph in [Phase.PLAYING, Phase.DRAWN_DECISION, Phase.CHALLENGE_DECISION] \
		and not bool(v["players"][me].get("uno", false))) or int(v["uno_vulnerable"]) == me
	uno_btn.disabled = not can_uno
	_pulse(uno_btn, can_uno)
	draw_btn.disabled = true
	draw_btn.text = tr("TABLE_DRAW")
	if my_turn:
		match ph:
			Phase.PLAYING:
				draw_btn.disabled = false
				draw_btn.text = Loc.t("TABLE_TAKE_N", [pending]) if pending > 0 else tr("TABLE_DRAW")
			Phase.DRAWN_DECISION:
				draw_btn.disabled = false
				draw_btn.text = tr("TABLE_KEEP")
			Phase.CHALLENGE_DECISION:
				draw_btn.disabled = false
				draw_btn.text = Loc.t("TABLE_TAKE_N", [pending])
	UiKit.style_button(draw_btn, UiKit.Variant.DANGER if pending > 0 and my_turn else UiKit.Variant.PRIMARY)
	hint.text = _hint_text(v) if bool(Settings.get_value("show_hints")) or not my_turn else ""


func _pulse(b: Control, on: bool) -> void:
	if b.has_meta("pulse"):
		var old: Tween = b.get_meta("pulse")
		if old and old.is_valid():
			old.kill()
		b.remove_meta("pulse")
	b.scale = Vector2.ONE
	if on and not Settings.reduced_motion():
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		b.set_meta("pulse", tw)


func _hint_text(v: Dictionary) -> String:
	var ph := int(v["phase"])
	var cur := int(v["current"])
	if ph >= Phase.ROUND_OVER:
		return ""
	if cur != me:
		return Loc.t("TABLE_HINT_WAIT", [_seat_name(cur)])
	match ph:
		Phase.CHOOSE_COLOR:
			return tr("TABLE_FIRST_WILD")
		Phase.DRAWN_DECISION:
			return tr("TABLE_HINT_DRAWN")
		Phase.CHALLENGE_DECISION:
			return tr("TABLE_HINT_CHALLENGE")
	if int(v["pending_draw"]) > 0:
		return Loc.t("TABLE_HINT_STACK", [int(v["pending_draw"])])
	if v["hand"].size() == 2:
		return tr("TABLE_HINT_UNO")
	return tr("TABLE_HINT_PLAY")


func _info_text(v: Dictionary) -> String:
	var parts := [Loc.t("TABLE_ROUND_N", [int(v["round"])])]
	if _rules.scoring_mode != RuleProfile.ScoringMode.SINGLE_ROUND:
		parts.append(Loc.t("TABLE_TARGET_N", [_rules.target_score]))
	if not _rules.is_classic():
		parts.append(tr("TABLE_HOUSE_RULES_ON"))
	return "  ·  ".join(parts)


# --- prompts --------------------------------------------------------------------------

func _prompts(v: Dictionary) -> void:
	var ph := int(v["phase"])
	var mine := int(v["current"]) == me
	if _overlay and is_instance_valid(_overlay):
		var kind: String = _overlay.get_meta("kind", "")
		var still := (kind == "first_color" and mine and ph == Phase.CHOOSE_COLOR) \
			or (kind == "challenge" and mine and ph == Phase.CHALLENGE_DECISION) \
			or (kind == "color" and mine and ph in [Phase.PLAYING, Phase.DRAWN_DECISION, Phase.CHALLENGE_DECISION]) \
			or (kind == "target" and mine)
		if not still:
			_close_overlay()
	if not mine:
		return
	if ph == Phase.CHOOSE_COLOR and _overlay == null:
		_show_color_picker("first_color", func(c): client.send({"type": "choose_color", "color": c}), false)
	elif ph == Phase.CHALLENGE_DECISION and _overlay == null:
		_show_challenge(v)


func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	for sv in seat_views.values():
		sv.target_mode = false
		sv.queue_redraw()


func _overlay_panel(kind: String, title_text: String, width := 560.0) -> VBoxContainer:
	_close_overlay()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_meta("kind", kind)
	add_child(host)
	move_child(host, fx.get_index())
	var p := UiKit.panel()
	p.custom_minimum_size.x = width
	host.add_child(p)
	var v := UiKit.vbox(14)
	p.add_child(v)
	var t := UiKit.title(title_text, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_top -= 40
	p.offset_bottom -= 40
	p.pivot_offset = p.get_combined_minimum_size() / 2.0
	p.scale = Vector2(0.85, 0.85)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, _dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_overlay = host
	return v


func _show_color_picker(kind: String, cb: Callable, cancellable := true) -> void:
	var v := _overlay_panel(kind, tr("TABLE_CHOOSE_COLOR"), 600)
	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var counts := [0, 0, 0, 0]
	for c in hand.order:
		var col := defs[c].color
		if col < 4:
			counts[col] += 1
	for c in 4:
		var b := ColorTile.new(c, counts[c])
		var cc := c
		b.pressed.connect(func():
			Audio.play("color_pick")
			_close_overlay()
			cb.call(cc))
		row.add_child(b)
	if cancellable:
		var cancel := UiKit.button(tr("BTN_CANCEL"), UiKit.Variant.GHOST, Vector2(200, 50))
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cancel.pressed.connect(_close_overlay)
		v.add_child(cancel)


func _show_challenge(v: Dictionary) -> void:
	var off := int(v["challenge_offender"])
	var box := _overlay_panel("challenge", tr("TABLE_CHALLENGE_TITLE"), 640)
	var body := UiKit.label(Loc.t("TABLE_CHALLENGE_BODY", [_seat_name(off), _seat_name(off)]), 19, Palette.TEXT_DIM, 650)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 580
	box.add_child(body)
	if not _playable_ids(v).is_empty():
		var stack := UiKit.label(tr("TABLE_CHALLENGE_STACK_HINT"), 17, Palette.TEAL, 700)
		stack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(stack)
	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var acc := UiKit.button(Loc.t("TABLE_ACCEPT_N", [int(v["pending_draw"])]), UiKit.Variant.SECONDARY, Vector2(230, 62))
	acc.pressed.connect(func():
		_close_overlay()
		client.send({"type": "accept"}))
	row.add_child(acc)
	if bool(v["challengeable"]):
		var ch := UiKit.button(tr("TABLE_CHALLENGE"), UiKit.Variant.DANGER, Vector2(230, 62))
		ch.pressed.connect(func():
			_close_overlay()
			client.send({"type": "challenge"}))
		row.add_child(ch)


func _show_target_picker(cb: Callable) -> void:
	var v := _overlay_panel("target", tr("TABLE_PICK_TARGET"), 480)
	var panel: Control = v.get_parent()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	var cancel := UiKit.button(tr("BTN_CANCEL"), UiKit.Variant.GHOST, Vector2(200, 50))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_close_overlay)
	v.add_child(cancel)
	_target_cb = cb
	for sv in seat_views.values():
		sv.target_mode = true
		sv.set_process(true)


# --- input → action requests --------------------------------------------------------

func _request_play(cid: int) -> void:
	if view.is_empty() or int(view["current"]) != me:
		App.toast(tr("ERR_NOT_YOUR_TURN"), Palette.CORAL)
		return
	if not _playable_ids(view).has(cid):
		_explain_unplayable(cid)
		return
	var d := defs[cid]
	var action := {"type": "play", "card": cid}
	var need_target: bool = _rules.seven_zero and d.kind == Kind.NUMBER and d.number == 7 and view["hand"].size() > 1
	var finish := func():
		if need_target:
			_show_target_picker(func(t):
				action["target"] = t
				client.send(action))
		else:
			client.send(action)
	if d.is_wild():
		if d.kind == Kind.WILD_DRAW_FOUR and int(view["pending_draw"]) == 0 \
				and not RuleEngine.wd4_legal(defs, view["hand"], int(view["color"])) and not hand.has_meta("wd4_warned"):
			hand.set_meta("wd4_warned", true)
			App.toast(tr("TABLE_WD4_BLUFF_WARN"), Palette.SUN, 4.0)
		_show_color_picker("color", func(c):
			action["color"] = c
			finish.call())
	else:
		finish.call()


func _explain_unplayable(cid: int) -> void:
	var d := defs[cid]
	if int(view["pending_draw"]) > 0:
		App.toast(Loc.t("TABLE_MUST_STACK_OR_TAKE", [int(view["pending_draw"])]), Palette.SUN)
	elif int(view["phase"]) == Phase.DRAWN_DECISION:
		App.toast(tr("TABLE_ONLY_DRAWN"), Palette.SUN)
	elif d.kind == Kind.WILD_DRAW_FOUR:
		App.toast(tr("ERR_WD4_RESTRICTED"), Palette.SUN)
	else:
		App.toast(tr("TABLE_CARD_NOT_PLAYABLE"), Palette.SUN)


func _on_selection(cid: int) -> void:
	if cid >= 0 and not view.is_empty() and int(view["current"]) == me and not _playable_ids(view).has(cid):
		_explain_unplayable(cid)


func _on_draw_pressed() -> void:
	if view.is_empty() or int(view["current"]) != me:
		return
	match int(view["phase"]):
		Phase.PLAYING:
			client.send({"type": "accept"} if int(view["pending_draw"]) > 0 else {"type": "draw"})
		Phase.DRAWN_DECISION:
			client.send({"type": "pass"})
		Phase.CHALLENGE_DECISION:
			_close_overlay()
			client.send({"type": "accept"})


func _on_uno_pressed() -> void:
	client.send({"type": "uno"})


func _on_catch(seat: int) -> void:
	client.send({"type": "catch", "target": seat})


func _on_seat_pressed(seat: int) -> void:
	if _target_cb.is_valid() and _overlay and is_instance_valid(_overlay) and _overlay.get_meta("kind", "") == "target":
		var cb := _target_cb
		_target_cb = Callable()
		_close_overlay()
		cb.call(seat)
	elif not view.is_empty() and int(view.get("uno_vulnerable", -1)) == seat:
		_on_catch(seat)


func _on_rejected(err: String) -> void:
	App.toast(Loc.error_text(err), Palette.CORAL)


func _on_connection(state: String, detail: String) -> void:
	status_label.text = detail if detail != "" else state


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if _overlay and is_instance_valid(_overlay) and _overlay.get_meta("kind", "") in ["color", "first_color"]:
		if e.keycode >= KEY_1 and e.keycode <= KEY_4:
			for b in _overlay.find_children("*", "ColorTile", true, false):
				if (b as ColorTile).color_index == e.keycode - KEY_1:
					(b as ColorTile).pressed.emit()
			accept_event()
		return
	match e.keycode:
		KEY_LEFT:
			hand.move_selection(-1)
		KEY_RIGHT:
			hand.move_selection(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if hand.selected >= 0:
				_request_play(hand.selected)
		KEY_D:
			_on_draw_pressed()
		KEY_U:
			if not uno_btn.disabled:
				_on_uno_pressed()
		KEY_C:
			if not view.is_empty() and int(view["phase"]) == Phase.CHALLENGE_DECISION and int(view["current"]) == me and bool(view["challengeable"]):
				_close_overlay()
				client.send({"type": "challenge"})
		KEY_ESCAPE:
			leave_requested.emit()
		_:
			return
	accept_event()


func _process(dt: float) -> void:
	# local turn-timer display (authority enforces the real deadline)
	_timer_tick += dt
	if view.is_empty() or int(view.get("turn_ms_total", 0)) <= 0:
		return
	var left := float(view.get("turn_ms_left", -1))
	if left < 0:
		return
	view["turn_ms_left"] = maxf(0.0, left - dt * 1000.0)
	var frac := float(view["turn_ms_left"]) / float(view["turn_ms_total"])
	var cur := int(view["current"])
	if cur == me:
		my_seat.timer_frac = frac
		my_seat.queue_redraw()
	elif seat_views.has(cur):
		seat_views[cur].timer_frac = frac


# --- feedback helpers -----------------------------------------------------------------

func _float_text(text: String, global_pos: Vector2, color: Color, font_size := 26) -> void:
	var l := UiKit.label(text, font_size, color, 800, true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.1, 0.9))
	fx.add_child(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(400, font_size + 20)
	l.global_position = global_pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 30, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func _banner(text: String, color: Color) -> void:
	_float_text(text, global_position + Vector2(size.x / 2.0, size.y * 0.25), color, 34)


func _pop_icon(icon: String, global_pos: Vector2, color: Color) -> void:
	var ic := IconView.new()
	ic.icon = icon
	ic.color = color
	ic.size = Vector2(90, 90)
	ic.pivot_offset = ic.size / 2.0
	fx.add_child(ic)
	ic.global_position = global_pos - ic.size / 2.0
	ic.scale = Vector2(0.3, 0.3)
	var tw := ic.create_tween()
	tw.tween_property(ic, "scale", Vector2(1.2, 1.2), _dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_dur(0.25))
	tw.tween_property(ic, "modulate:a", 0.0, _dur(0.25))
	tw.tween_callback(ic.queue_free)


func _uno_burst(global_pos: Vector2) -> void:
	_float_text(tr("CALL_WORD"), global_pos + Vector2(0, -60), Palette.SUN, 56)
	if Settings.quality() > 0 and not Settings.reduced_motion():
		var p := Confetti.burst(fx, global_pos + Vector2(0, -40), 28, 0.7)
		p.z_index = 10


func _shake(amount: float) -> void:
	if not bool(Settings.get_value("screen_shake")) or Settings.reduced_motion():
		return
	var tw := create_tween()
	for i in 5:
		var k := amount * (1.0 - i / 5.0)
		tw.tween_property(self, "position", Vector2(randf_range(-k, k), randf_range(-k, k)), 0.03)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


# --- round / match results ------------------------------------------------------------

func _show_round_result(e: Dictionary, v: Dictionary, events: Array) -> void:
	var is_match_end := events.any(func(x): return x["t"] == "match_end")
	if e["t"] == "round_end" and is_match_end:
		return  # the match_end entry shows the final panel
	var winner := int(e["winner"])
	if e["t"] == "match_end":
		Audio.play("match_win" if winner == me else "lose")
		if winner == me and Settings.quality() > 0:
			Confetti.rain(fx, size, 90)
		await _wait(0.6)
		match_over.emit(v, events)
		return
	Audio.play("round_win" if winner == me else "card_special")
	var pts := 0
	for x in events:
		if x["t"] == "round_end":
			pts = int(x["points"])
	_banner(Loc.t("RESULT_ROUND_WINNER", [_seat_name(winner), pts]), Palette.SUN)
	await _wait(0.4)
	RoundResultPanel.open(self, v, e, me, client)


func stats() -> Dictionary:
	return _stats


func is_idle() -> bool:
	return not _busy and _queue.is_empty()
