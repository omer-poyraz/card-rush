class_name CardDefinition
extends RefCounted
## Immutable description of one physical card in a deck profile.
## A "card instance" in play is just its integer id (index into the deck's
## definition array) — compact for the network and impossible to duplicate.

enum CardColor { RED, YELLOW, GREEN, BLUE, WILD }
enum Kind { NUMBER, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR }

const PLAYABLE_COLORS: Array[int] = [CardColor.RED, CardColor.YELLOW, CardColor.GREEN, CardColor.BLUE]
const COLOR_KEYS := ["red", "yellow", "green", "blue", "wild"]
const KIND_KEYS := ["number", "skip", "reverse", "draw_two", "wild", "wild_draw_four"]

var id: int
var color: int
var kind: int
var number: int  # 0-9 for NUMBER cards, -1 otherwise


func _init(p_id: int, p_color: int, p_kind: int, p_number := -1) -> void:
	id = p_id
	color = p_color
	kind = p_kind
	number = p_number


func is_wild() -> bool:
	return kind == Kind.WILD or kind == Kind.WILD_DRAW_FOUR


func is_action() -> bool:
	return kind != Kind.NUMBER


func draw_amount() -> int:
	match kind:
		Kind.DRAW_TWO:
			return 2
		Kind.WILD_DRAW_FOUR:
			return 4
	return 0


## Official scoring values.
func points() -> int:
	match kind:
		Kind.NUMBER:
			return number
		Kind.SKIP, Kind.REVERSE, Kind.DRAW_TWO:
			return 20
	return 50


## Two cards "share a symbol" when this key is equal (same number or same action).
func symbol_key() -> String:
	return "n%d" % number if kind == Kind.NUMBER else KIND_KEYS[kind]


func short_name() -> String:
	var c: String = "W" if color == CardColor.WILD else String(COLOR_KEYS[color]).substr(0, 1).to_upper()
	match kind:
		Kind.NUMBER:
			return "%s%d" % [c, number]
		Kind.SKIP:
			return c + "-skip"
		Kind.REVERSE:
			return c + "-rev"
		Kind.DRAW_TWO:
			return c + "+2"
		Kind.WILD:
			return "W"
	return "W+4"
