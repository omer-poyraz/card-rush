class_name HandView
extends Control
## The local player's hand. Lays cards out in a gentle fan, overlapping as
## needed and scrolling horizontally when there are too many to stay readable.
## Input: tap selects, tap again (or one-tap mode / swipe up / double-click)
## plays. All hit-testing happens here so drag-to-scroll and taps coexist.

signal play_requested(card_id: int)
signal selection_changed(card_id: int)

const MIN_SPACING := 46.0
const LIFT_SELECTED := 38.0
const LIFT_PLAYABLE := 10.0
const LIFT_HOVER := 14.0

var card_size := Vector2(116, 174)
var views := {}                 # card_id -> CardView
var order: Array[int] = []      # sorted ids, left to right
var selected := -1
var playable_ids := {}          # card_id -> true
var my_turn := false
var _scroll := 0.0
var _max_scroll := 0.0
var _press_pos := Vector2.ZERO
var _press_card := -1
var _dragging := false
var _hover := -1
var _defs: Array[CardDefinition] = DeckProfile.build(DeckProfile.CLASSIC_108)
var _last_click_ms := 0
var _last_click_card := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	resized.connect(func(): layout(false))


## Sort: by colour, then numbers before actions, wilds last.
func _sort_key(id: int) -> int:
	var d := _defs[id]
	return d.color * 1000 + d.kind * 20 + maxi(0, d.number)


## Replaces the hand. New cards can be given a start position (global) so they
## appear to fly in; removed cards are returned so the caller can animate them.
func set_cards(ids: Array, spawn_global := Vector2.INF) -> void:
	var keep := {}
	for id in ids:
		keep[int(id)] = true
	for id in views.keys():
		if not keep.has(id):
			views[id].queue_free()
			views.erase(id)
	for id in ids:
		var cid := int(id)
		if not views.has(cid):
			var cv := CardView.new()
			cv.card_id = cid
			cv.set_card_size(card_size)
			add_child(cv)
			if spawn_global != Vector2.INF:
				cv.global_position = spawn_global - card_size / 2.0
			views[cid] = cv
	order.clear()
	for id in ids:
		order.append(int(id))
	order.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
	if not views.has(selected):
		selected = -1
	layout(true)


## Detaches a card view (for the play animation) and returns it.
func take_view(id: int) -> CardView:
	if not views.has(id):
		return null
	var cv: CardView = views[id]
	_kill_tween(cv)
	views.erase(id)
	order.erase(id)
	if selected == id:
		selected = -1
	layout(true)
	return cv


func set_state(turn: bool, playable: Array) -> void:
	my_turn = turn
	playable_ids.clear()
	for id in playable:
		playable_ids[int(id)] = true
	if selected >= 0 and not playable_ids.has(selected):
		selected = -1
	_refresh_flags()
	layout(true)


func _refresh_flags() -> void:
	for id in views:
		var cv: CardView = views[id]
		cv.playable = my_turn and playable_ids.has(id) and selected != id
		cv.selected = selected == id
		cv.dim = my_turn and not playable_ids.has(id)


func slot_global_position(index: int, count: int) -> Vector2:
	var pos := _slot_positions(count)
	if pos.is_empty():
		return global_position + size / 2.0
	return global_position + pos[clampi(index, 0, pos.size() - 1)][0] + card_size / 2.0


func _spacing(n: int) -> float:
	if n <= 1:
		return 0.0
	var ideal := card_size.x * 0.78
	var fit := (size.x - card_size.x) / (n - 1)
	return clampf(fit, MIN_SPACING, ideal)


## Returns [[position, rotation], ...] for n cards (scroll applied).
func _slot_positions(n: int) -> Array:
	var out := []
	if n == 0:
		return out
	var sp := _spacing(n)
	var total := card_size.x + sp * (n - 1)
	_max_scroll = maxf(0.0, total - size.x)
	_scroll = clampf(_scroll, 0.0, _max_scroll)
	var x0 := (size.x - total) / 2.0 if _max_scroll == 0.0 else -_scroll
	var fan := n <= 14 and _max_scroll == 0.0
	for i in n:
		var t := 0.0 if n == 1 else (float(i) / (n - 1)) * 2.0 - 1.0
		var y := size.y - card_size.y
		var rot := 0.0
		if fan:
			y += t * t * 16.0
			rot = t * 0.07
		out.append([Vector2(x0 + i * sp, y), rot])
	return out


func layout(animated := true) -> void:
	var slots := _slot_positions(order.size())
	var k := Settings.anim_scale()
	for i in order.size():
		var id := order[i]
		var cv: CardView = views[id]
		var target: Vector2 = slots[i][0]
		var lift := 0.0
		if id == selected:
			lift = LIFT_SELECTED
		elif my_turn and playable_ids.has(id):
			lift = LIFT_PLAYABLE
		if id == _hover and id != selected:
			lift += LIFT_HOVER
		target.y -= lift
		cv.z_index = i
		_kill_tween(cv)
		if animated and is_inside_tree():
			var tw := cv.create_tween().set_parallel()
			cv.set_meta("layout_tw", tw)
			tw.tween_property(cv, "position", target, 0.22 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "rotation", slots[i][1], 0.22 * k)
			tw.tween_property(cv, "scale", Vector2.ONE, 0.18 * k)
		else:
			cv.position = target
			cv.rotation = slots[i][1]
	queue_redraw()


## A running layout tween must never keep moving a card after it left the hand
## (it would write hand-local coordinates into the card's new parent).
func _kill_tween(cv: CardView) -> void:
	if cv.has_meta("layout_tw"):
		var tw: Tween = cv.get_meta("layout_tw")
		if tw and tw.is_valid():
			tw.kill()
		cv.remove_meta("layout_tw")


func _card_at(local: Vector2) -> int:
	# topmost (rightmost) card whose rect contains the point
	for i in range(order.size() - 1, -1, -1):
		var cv: CardView = views[order[i]]
		var r := Rect2(cv.position, cv.size).grow(4)
		if r.has_point(local):
			return order[i]
	return -1


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_pos = e.position
			_press_card = _card_at(e.position)
			_dragging = false
		else:
			if not _dragging:
				_tap(_press_card)
			elif _press_card >= 0 and _press_pos.y - e.position.y > 70.0 and absf(e.position.x - _press_pos.x) < 90.0:
				play_requested.emit(_press_card)
			_dragging = false
			_press_card = -1
		accept_event()
	elif e is InputEventMouseButton and e.pressed and _max_scroll > 0.0:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_scroll -= 60.0
			layout(false)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_scroll += 60.0
			layout(false)
	elif e is InputEventMouseMotion:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var d: Vector2 = e.position - _press_pos
			if d.length() > 12.0:
				_dragging = true
			if _dragging and _max_scroll > 0.0 and absf(d.x) > absf(d.y):
				_scroll -= e.relative.x
				layout(false)
		else:
			var h := _card_at(e.position)
			if h != _hover:
				_hover = h
				layout(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		layout(true)


func _tap(id: int) -> void:
	if id < 0:
		select(-1)
		return
	var now := Time.get_ticks_msec()
	var dbl := id == _last_click_card and now - _last_click_ms < 350
	_last_click_ms = now
	_last_click_card = id
	if not my_turn or not playable_ids.has(id):
		select(id)
		return
	if id == selected or dbl or bool(Settings.get_value("one_tap_play")):
		play_requested.emit(id)
	else:
		select(id)
		Audio.play("hover", 0.1)


func select(id: int) -> void:
	if selected == id:
		return
	selected = id
	_refresh_flags()
	layout(true)
	selection_changed.emit(id)


## Keyboard navigation: move the selection left/right.
func move_selection(dir: int) -> void:
	if order.is_empty():
		return
	var i := order.find(selected)
	i = clampi(i + dir if i >= 0 else (0 if dir > 0 else order.size() - 1), 0, order.size() - 1)
	select(order[i])
	# keep the selection visible when scrolling
	if _max_scroll > 0.0:
		var cv: CardView = views[order[i]]
		if cv.position.x < 0:
			_scroll += cv.position.x - 10
		elif cv.position.x + card_size.x > size.x:
			_scroll += cv.position.x + card_size.x - size.x + 10
		layout(true)


func _draw() -> void:
	if _max_scroll > 0.0:
		# scroll hint bar
		var w := size.x * size.x / (size.x + _max_scroll)
		var x := (size.x - w) * (_scroll / _max_scroll)
		draw_rect(Rect2(Vector2(0, size.y + 4), Vector2(size.x, 4)), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2(x, size.y + 4), Vector2(w, 4)), Color(Palette.ELECTRIC, 0.7))
