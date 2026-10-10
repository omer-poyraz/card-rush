class_name CardView
extends Control
## One drawn card. Purely presentational: it never decides whether a move is
## legal — it only displays the flags its owner sets.

signal pressed(view: CardView)

const BASE_SIZE := Vector2(120, 180)

var card_id := -1:
	set(v):
		card_id = v
		queue_redraw()
var face_up := true:
	set(v):
		face_up = v
		queue_redraw()
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()
var playable := false:
	set(v):
		if playable != v:
			playable = v
			queue_redraw()
var dim := false:
	set(v):
		if dim != v:
			dim = v
			queue_redraw()
var back_style := "back_classic"
var cast_shadow := true
var interactive := false:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

var _defs: Array[CardDefinition] = DeckProfile.build(DeckProfile.CLASSIC_108)


func _init() -> void:
	size = BASE_SIZE
	pivot_offset = BASE_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_card_size(s: Vector2) -> void:
	size = s
	custom_minimum_size = s
	pivot_offset = s / 2.0
	queue_redraw()


func _draw() -> void:
	var d: CardDefinition = _defs[card_id] if face_up and card_id >= 0 else null
	CardArt.draw_card(self, Rect2(Vector2.ZERO, size), d, {
		"selected": selected, "playable": playable, "dim": dim, "back": back_style, "shadow": cast_shadow,
	})


func _gui_input(e: InputEvent) -> void:
	if not interactive:
		return
	# touch arrives as emulated mouse events (default project setting)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		pressed.emit(self)
		accept_event()


func definition() -> CardDefinition:
	return _defs[card_id] if card_id >= 0 else null
