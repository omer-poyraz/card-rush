class_name DeckManager
extends RefCounted
## Pile operations on a GameState. Cards only ever move between piles/hands,
## so the 108-card invariant holds by construction (see GameState.check_integrity).


static func shuffle(arr: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := arr[i]
		arr[i] = arr[j]
		arr[j] = t


## Gathers every card into a fresh shuffled draw pile and empties hands/discard.
static func collect_and_shuffle(state: GameState) -> void:
	state.draw_pile.clear()
	state.discard_pile.clear()
	for p in state.players:
		p.hand.clear()
	for c in state.cards:
		state.draw_pile.append(c.id)
	shuffle(state.draw_pile, state.rng)


## Keeps the top discard, shuffles the rest into a new draw pile.
## Returns the number of cards recycled (0 when nothing could be recycled).
static func reshuffle_discard(state: GameState, events: Array) -> int:
	if state.discard_pile.size() <= 1:
		return 0
	var top: int = state.discard_pile.pop_back()
	var recycled := state.discard_pile.duplicate()
	state.discard_pile = [top]
	shuffle(recycled, state.rng)
	recycled.append_array(state.draw_pile)  # (draw pile is empty when we get here)
	state.draw_pile = recycled
	events.append({"t": "reshuffle", "n": recycled.size()})
	return recycled.size()


## Draws up to `n` cards into a player's hand. If both piles are exhausted
## (every card is in someone's hand) fewer cards are drawn — never loops.
static func draw_into_hand(state: GameState, seat: int, n: int, events: Array, reason := "normal") -> Array[int]:
	var got: Array[int] = []
	for _i in n:
		if state.draw_pile.is_empty() and reshuffle_discard(state, events) == 0:
			break
		var c: int = state.draw_pile.pop_back()
		state.players[seat].hand.append(c)
		got.append(c)
	events.append({"t": "draw", "p": seat, "n": got.size(), "cards": got.duplicate(), "reason": reason, "asked": n})
	return got
