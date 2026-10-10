class_name TurnManager
extends RefCounted
## Turn order is derived only from GameState.current/direction, so there is a
## single verifiable source of truth for whose turn it is.


static func advance(state: GameState, steps: int, events: Array) -> void:
	var leaving := state.current
	if leaving >= 0 and leaving < state.players.size():
		state.players[leaving].uno_declared = false
	state.current = state.next_index(state.current, steps)
	state.turn_serial += 1
	state.drawn_card = -1
	state.phase = GameState.Phase.PLAYING
	events.append({"t": "turn", "p": state.current})


static func reverse(state: GameState, events: Array) -> void:
	state.direction = -state.direction
	events.append({"t": "reverse", "dir": state.direction})
