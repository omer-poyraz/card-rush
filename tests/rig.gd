class_name Rig
extends RefCounted
## Builds hand-crafted game states for rule tests. Cards are named with
## CardDefinition.short_name() style: "R5", "G-skip", "B-rev", "Y+2", "W", "W+4".


static func players(n: int, bots := false) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for i in n:
		var p := PlayerState.new()
		p.seat_id = "s%d" % i
		p.display_name = "P%d" % i
		p.is_bot = bots
		out.append(p)
	return out


## hands: Array of Array[String]; top: card name on the discard pile;
## draw_top: names that will be drawn first (in order). Remaining cards fill
## the draw pile below them. `current` takes the turn in PLAYING phase.
static func state(hands: Array, top: String, color := -1, draw_top: Array = [], profile: RuleProfile = null, current := 0) -> GameState:
	var s := GameState.new(profile)
	s.players = players(hands.size())
	var used := {}
	for i in hands.size():
		for name in hands[i]:
			s.players[i].hand.append(_take(s, name, used))
	var top_id := _take(s, top, used)
	s.discard_pile.append(top_id)
	var drawn: Array[int] = []
	for name in draw_top:
		drawn.append(_take(s, name, used))
	var rest: Array[int] = []
	for c in s.cards:
		if not used.has(c.id):
			rest.append(c.id)
	# back of draw_pile = next card drawn
	drawn.reverse()
	s.draw_pile = rest
	s.draw_pile.append_array(drawn)
	s.current_color = color if color >= 0 else s.card(top_id).color
	s.current = current
	s.dealer = posmod(current - 1, hands.size())
	s.phase = GameState.Phase.PLAYING
	s.round_number = 1
	return s


static func id_of(s: GameState, name: String, used := {}) -> int:
	for c in s.cards:
		if c.short_name() == name and not used.has(c.id):
			return c.id
	push_error("Rig: no free card " + name)
	return -1


static func _take(s: GameState, name: String, used: Dictionary) -> int:
	var id := id_of(s, name, used)
	used[id] = true
	return id


static func hand_id(s: GameState, seat: int, name: String) -> int:
	for c in s.players[seat].hand:
		if s.card(c).short_name() == name:
			return c
	return -1


static func play(s: GameState, seat: int, name: String, extra := {}) -> Dictionary:
	var a := {"type": "play", "player": seat, "card": hand_id(s, seat, name)}
	a.merge(extra)
	return RuleEngine.apply(s, a)


static func act(s: GameState, type: String, seat: int, extra := {}) -> Dictionary:
	var a := {"type": type, "player": seat}
	a.merge(extra)
	return RuleEngine.apply(s, a)
