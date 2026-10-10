class_name RuleEngine
extends RefCounted
## The single rules authority. Pure static functions over GameState — no
## nodes, no UI, no timers — so offline play, bots, LAN and online rooms all
## run exactly the same code. Every action is fully validated before any
## state is mutated; a rejected action leaves the state untouched.
##
## Action dictionaries:
##   {type:"play", player, card, color?, target?}  color for wilds, target for 7 (7-0 rule)
##   {type:"draw", player}            draw one card (or take the pending +2/+4 stack)
##   {type:"pass", player}            keep the card just drawn
##   {type:"accept", player}          take the pending +2/+4 penalty
##   {type:"challenge", player}       challenge a Wild Draw Four
##   {type:"choose_color", player, color}   first discard was a Wild
##   {type:"uno", player}             announce UNO
##   {type:"catch", player, target}   catch a player who missed UNO
## Optional: v (expected state version), now_ms (authority clock).

const Phase = GameState.Phase
const Kind = CardDefinition.Kind
const CColor = CardDefinition.CardColor

const TURN_ACTIONS := ["play", "draw", "pass", "accept", "challenge", "choose_color"]


# --- match / round setup ---------------------------------------------------------

static func setup_match(state: GameState, players: Array[PlayerState], dealer := -1) -> String:
	var err := state.profile.validate_player_count(players.size())
	if err != "":
		return err
	state.players = players
	for p in players:
		p.score = 0
	state.dealer = dealer if dealer >= 0 else state.rng.randi_range(0, players.size() - 1)
	state.round_number = 0
	state.match_winner = -1
	state.last_round_winner = -1
	state.phase = Phase.WAITING
	return ""


## Shuffles, deals and turns the first discard. Returns the events.
static func start_round(state: GameState) -> Array:
	var ev := []
	if state.phase == Phase.MATCH_OVER:
		return ev
	var n := state.players.size()
	if state.round_number > 0:
		state.dealer = posmod(state.dealer + 1, n)
	state.round_number += 1
	state.direction = 1
	state.pending_draw = 0
	state.challenge = {}
	state.uno_vulnerable = -1
	state.drawn_card = -1
	state.last_round_points = {}
	for p in state.players:
		p.uno_declared = false
	DeckManager.collect_and_shuffle(state)

	var dealt := {}
	for i in n:
		dealt[i] = []
	for _r in state.profile.hand_size:
		for k in n:
			var seat := posmod(state.dealer + 1 + k, n)
			var c: int = state.draw_pile.pop_back()
			state.players[seat].hand.append(c)
			dealt[seat].append(c)
	ev.append({"t": "deal", "dealer": state.dealer, "hand_size": state.profile.hand_size, "cards": dealt})

	# Turn the first card. Official: a Wild Draw Four is returned and reshuffled.
	var first := -1
	for _guard in state.cards.size() * 2:
		first = state.draw_pile.pop_back()
		var d := state.card(first)
		var rebury := d.kind == Kind.WILD_DRAW_FOUR
		if state.profile.first_card_mode == RuleProfile.FirstCardMode.NUMBER_ONLY:
			rebury = d.kind != Kind.NUMBER
		if not rebury:
			break
		state.draw_pile.append(first)
		DeckManager.shuffle(state.draw_pile, state.rng)
		ev.append({"t": "rebury", "card": first})
	state.discard_pile.append(first)
	var fd := state.card(first)
	state.current_color = fd.color
	state.current = state.next_index(state.dealer)
	state.phase = Phase.PLAYING
	state.turn_serial += 1
	ev.append({"t": "first_card", "card": first})

	match fd.kind:
		Kind.SKIP:
			ev.append({"t": "skip", "p": state.current})
			state.current = state.next_index(state.current)
		Kind.REVERSE:
			# Official: the dealer plays first and play goes the other way.
			TurnManager.reverse(state, ev)
			state.current = state.dealer
		Kind.DRAW_TWO:
			DeckManager.draw_into_hand(state, state.current, 2, ev, "penalty")
			ev.append({"t": "skip", "p": state.current})
			state.current = state.next_index(state.current)
		Kind.WILD:
			state.phase = Phase.CHOOSE_COLOR
	ev.append({"t": "turn", "p": state.current})
	state.version += 1
	return ev


# --- playability (shared with bots and UI via the *_on_view helpers) --------------

## Core playability test, usable both with a full GameState and with a view.
static func is_playable(profile: RuleProfile, cards: Array[CardDefinition], hand: Array, cid: int,
		top_id: int, color: int, pending: int, phase: int, drawn: int) -> bool:
	if not hand.has(cid):
		return false
	var c := cards[cid]
	match phase:
		Phase.PLAYING, Phase.CHALLENGE_DECISION:
			pass
		Phase.DRAWN_DECISION:
			if cid != drawn:
				return false
		_:
			return false
	var top: CardDefinition = cards[top_id] if top_id >= 0 else null
	if pending > 0:
		return _can_stack(profile, c, top, color)
	if phase == Phase.CHALLENGE_DECISION:
		return false
	if c.kind == Kind.WILD:
		return true
	if c.kind == Kind.WILD_DRAW_FOUR:
		if profile.wd4_mode == RuleProfile.Wd4Mode.STRICT:
			return wd4_legal(cards, hand, color)
		return true  # official: may be played as a bluff; the challenge polices it
	if c.color == color:
		return true
	return top != null and not top.is_wild() and c.symbol_key() == top.symbol_key()


static func _can_stack(profile: RuleProfile, c: CardDefinition, top: CardDefinition, color: int) -> bool:
	if top == null:
		return false
	if top.kind == Kind.DRAW_TWO:
		if c.kind == Kind.DRAW_TWO:
			return profile.stack_draw_two
		if c.kind == Kind.WILD_DRAW_FOUR:
			return profile.stack_mixed
	elif top.kind == Kind.WILD_DRAW_FOUR:
		if c.kind == Kind.WILD_DRAW_FOUR:
			return profile.stack_draw_four
		if c.kind == Kind.DRAW_TWO:
			return profile.stack_mixed and c.color == color
	return false


## Official Wild Draw Four condition: no card in hand matches the active COLOUR
## (matching numbers/symbols of other colours do not count; wilds never match).
static func wd4_legal(cards: Array[CardDefinition], hand: Array, color: int) -> bool:
	for id in hand:
		if cards[id].color == color:
			return false
	return true


static func can_play(state: GameState, seat: int, cid: int) -> bool:
	if seat != state.current:
		return false
	var top: int = state.discard_pile.back() if not state.discard_pile.is_empty() else -1
	return is_playable(state.profile, state.cards, state.players[seat].hand, cid, top,
		state.current_color, state.pending_draw, state.phase, state.drawn_card)


static func playable_cards(state: GameState, seat: int) -> Array[int]:
	var out: Array[int] = []
	for c in state.players[seat].hand:
		if can_play(state, seat, c):
			out.append(c)
	return out


## Whether any response to a pending +2/+4 is possible under the house rules.
static func stacking_possible(profile: RuleProfile, top_kind: int) -> bool:
	if top_kind == Kind.DRAW_TWO:
		return profile.stack_draw_two or profile.stack_mixed
	if top_kind == Kind.WILD_DRAW_FOUR:
		return profile.stack_draw_four or profile.stack_mixed
	return false


## Every legal action for `seat` right now (wild colours / 7-0 targets expanded).
static func legal_actions(state: GameState, seat: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.phase in [Phase.WAITING, Phase.ROUND_OVER, Phase.MATCH_OVER] or seat != state.current:
		return out
	if state.phase == Phase.CHOOSE_COLOR:
		for col in CardDefinition.PLAYABLE_COLORS:
			out.append({"type": "choose_color", "player": seat, "color": col})
		return out
	for cid in playable_cards(state, seat):
		var d := state.card(cid)
		var base := {"type": "play", "player": seat, "card": cid}
		var variants: Array[Dictionary] = [base]
		if d.is_wild():
			variants = []
			for col in CardDefinition.PLAYABLE_COLORS:
				var v := base.duplicate()
				v["color"] = col
				variants.append(v)
		if state.profile.seven_zero and d.kind == Kind.NUMBER and d.number == 7 and state.players[seat].hand.size() > 1:
			var expanded: Array[Dictionary] = []
			for v in variants:
				for t in state.players.size():
					if t != seat:
						var w := v.duplicate()
						w["target"] = t
						expanded.append(w)
			variants = expanded
		out.append_array(variants)
	match state.phase:
		Phase.PLAYING:
			if state.pending_draw > 0:
				out.append({"type": "accept", "player": seat})
			elif state.profile.draw_when_playable or out.is_empty():
				out.append({"type": "draw", "player": seat})
		Phase.DRAWN_DECISION:
			out.append({"type": "pass", "player": seat})
		Phase.CHALLENGE_DECISION:
			out.append({"type": "accept", "player": seat})
			if not state.challenge.is_empty() and state.pending_draw == 4:
				out.append({"type": "challenge", "player": seat})
	return out


# --- apply ------------------------------------------------------------------------

## Validates and applies one action. Returns {ok, error, events}.
static func apply(state: GameState, action: Dictionary) -> Dictionary:
	var ev := []
	var err := _apply(state, action, ev)
	if err != "":
		return {"ok": false, "error": err, "events": []}
	state.version += 1
	return {"ok": true, "error": "", "events": ev}


static func _apply(state: GameState, a: Dictionary, ev: Array) -> String:
	if state.phase in [Phase.WAITING, Phase.ROUND_OVER, Phase.MATCH_OVER]:
		return "ERR_NOT_IN_PLAY"
	var t := str(a.get("type", ""))
	var p := int(a.get("player", -1))
	if p < 0 or p >= state.players.size():
		return "ERR_BAD_PLAYER"
	if a.has("v") and int(a["v"]) != state.version:
		return "ERR_STALE"
	if t in TURN_ACTIONS and p != state.current:
		return "ERR_NOT_YOUR_TURN"
	match t:
		"play":
			return _play(state, a, ev)
		"draw":
			return _draw(state, p, ev, int(a.get("now_ms", 0)))
		"pass":
			return _pass(state, p, ev)
		"accept":
			return _accept(state, p, ev)
		"challenge":
			return _challenge(state, p, ev)
		"choose_color":
			return _choose_color(state, p, int(a.get("color", -1)), ev)
		"uno":
			return _call_uno(state, p, ev)
		"catch":
			return _catch(state, p, int(a.get("target", -1)), int(a.get("now_ms", -1)), ev)
	return "ERR_UNKNOWN_ACTION"


static func _close_uno_window(state: GameState) -> void:
	state.uno_vulnerable = -1


static func _play(state: GameState, a: Dictionary, ev: Array) -> String:
	var p := int(a["player"])
	var cid := int(a.get("card", -1))
	if cid < 0 or cid >= state.cards.size():
		return "ERR_BAD_CARD"
	var hand := state.players[p].hand
	if not hand.has(cid):
		return "ERR_CARD_NOT_IN_HAND"
	if not can_play(state, p, cid):
		var d0 := state.card(cid)
		if d0.kind == Kind.WILD_DRAW_FOUR and state.pending_draw == 0 and state.phase == Phase.PLAYING:
			return "ERR_WD4_RESTRICTED"
		return "ERR_CARD_NOT_PLAYABLE"
	var d := state.card(cid)
	var chosen := int(a.get("color", -1))
	if d.is_wild() and not CardDefinition.PLAYABLE_COLORS.has(chosen):
		return "ERR_NEED_COLOR"
	var target := int(a.get("target", -1))
	var is_seven := state.profile.seven_zero and d.kind == Kind.NUMBER and d.number == 7 and hand.size() > 1
	if is_seven and (target < 0 or target >= state.players.size() or target == p):
		return "ERR_NEED_TARGET"

	# --- validated: mutate ---
	_close_uno_window(state)
	var color_before := state.current_color
	hand.erase(cid)
	var guilty := d.kind == Kind.WILD_DRAW_FOUR and not wd4_legal(state.cards, hand, color_before)
	state.discard_pile.append(cid)
	state.current_color = chosen if d.is_wild() else d.color
	state.drawn_card = -1
	state.challenge = {}
	ev.append({"t": "play", "p": p, "card": cid, "color": state.current_color})

	if hand.size() == 1:
		if state.players[p].uno_declared:
			pass  # announced in time
		else:
			state.uno_vulnerable = p
			state.uno_vulnerable_since_ms = int(a.get("now_ms", 0))
			ev.append({"t": "uno_missed", "p": p})
	state.players[p].uno_declared = false

	if hand.is_empty():
		# Official: a closing +2/+4 still makes the next player draw; those cards count.
		var amount := state.pending_draw + d.draw_amount()
		if amount > 0:
			var victim := state.next_index(p)
			DeckManager.draw_into_hand(state, victim, amount, ev, "penalty")
		state.pending_draw = 0
		_end_round(state, p, ev)
		return ""

	match d.kind:
		Kind.NUMBER:
			if is_seven:
				_swap_hands(state, p, target, ev)
			elif state.profile.seven_zero and d.number == 0:
				_rotate_hands(state, ev)
			TurnManager.advance(state, 1, ev)
		Kind.SKIP:
			ev.append({"t": "skip", "p": state.next_index(p)})
			TurnManager.advance(state, 2, ev)
		Kind.REVERSE:
			if state.players.size() == 2:
				ev.append({"t": "skip", "p": state.next_index(p)})
				TurnManager.advance(state, 2, ev)
			else:
				TurnManager.reverse(state, ev)
				TurnManager.advance(state, 1, ev)
		Kind.WILD:
			TurnManager.advance(state, 1, ev)
		Kind.DRAW_TWO, Kind.WILD_DRAW_FOUR:
			state.pending_draw += d.draw_amount()
			var can_stack := stacking_possible(state.profile, d.kind)
			var challengeable := d.kind == Kind.WILD_DRAW_FOUR and state.profile.challenge_enabled() \
				and state.pending_draw == 4
			if can_stack or challengeable:
				TurnManager.advance(state, 1, ev)
				if challengeable:
					state.challenge = {"offender": p, "color_before": color_before, "guilty": guilty}
					state.phase = Phase.CHALLENGE_DECISION
			else:
				var victim := state.next_index(p)
				DeckManager.draw_into_hand(state, victim, state.pending_draw, ev, "penalty")
				state.pending_draw = 0
				ev.append({"t": "skip", "p": victim})
				TurnManager.advance(state, 2, ev)
	return ""


static func _draw(state: GameState, p: int, ev: Array, now_ms := 0) -> String:
	if state.pending_draw > 0 and state.phase in [Phase.PLAYING, Phase.CHALLENGE_DECISION]:
		return _accept(state, p, ev)
	if state.phase != Phase.PLAYING:
		return "ERR_WRONG_PHASE"
	if not state.profile.draw_when_playable and not playable_cards(state, p).is_empty():
		return "ERR_MUST_PLAY"
	_close_uno_window(state)
	var got := DeckManager.draw_into_hand(state, p, 1, ev, "normal")
	if got.is_empty():
		ev.append({"t": "pass", "p": p})
		TurnManager.advance(state, 1, ev)
		return ""
	var c := got[0]
	state.drawn_card = c
	state.phase = Phase.DRAWN_DECISION
	if state.profile.play_drawn_card and can_play(state, p, c):
		var d := state.card(c)
		var needs_choice := d.is_wild() or (state.profile.seven_zero and d.kind == Kind.NUMBER and d.number == 7)
		if state.profile.auto_play_drawn and not needs_choice:
			return _play(state, {"type": "play", "player": p, "card": c, "now_ms": now_ms}, ev)
		return ""
	TurnManager.advance(state, 1, ev)
	return ""


static func _pass(state: GameState, p: int, ev: Array) -> String:
	if state.phase != Phase.DRAWN_DECISION:
		return "ERR_WRONG_PHASE"
	_close_uno_window(state)
	ev.append({"t": "pass", "p": p})
	TurnManager.advance(state, 1, ev)
	return ""


static func _accept(state: GameState, p: int, ev: Array) -> String:
	if state.pending_draw <= 0 or not state.phase in [Phase.PLAYING, Phase.CHALLENGE_DECISION]:
		return "ERR_NOTHING_TO_ACCEPT"
	_close_uno_window(state)
	DeckManager.draw_into_hand(state, p, state.pending_draw, ev, "penalty")
	state.pending_draw = 0
	state.challenge = {}
	ev.append({"t": "skip", "p": p})
	TurnManager.advance(state, 1, ev)
	return ""


static func _challenge(state: GameState, p: int, ev: Array) -> String:
	if state.phase != Phase.CHALLENGE_DECISION or state.challenge.is_empty() or state.pending_draw != 4:
		return "ERR_CANNOT_CHALLENGE"
	_close_uno_window(state)
	var offender := int(state.challenge["offender"])
	var guilty := bool(state.challenge["guilty"])
	state.challenge = {}
	# The verdict is public; the offender's hand is never revealed.
	ev.append({"t": "challenge", "p": p, "offender": offender, "guilty": guilty})
	if guilty:
		DeckManager.draw_into_hand(state, offender, 4, ev, "challenge")
		state.pending_draw = 0
		state.phase = Phase.PLAYING  # challenger now takes a normal turn; colour stays
		if state.players[offender].hand.size() > 1 and state.uno_vulnerable == offender:
			state.uno_vulnerable = -1
	else:
		DeckManager.draw_into_hand(state, p, state.pending_draw + 2, ev, "challenge")
		state.pending_draw = 0
		ev.append({"t": "skip", "p": p})
		TurnManager.advance(state, 1, ev)
	return ""


static func _choose_color(state: GameState, p: int, color: int, ev: Array) -> String:
	if state.phase != Phase.CHOOSE_COLOR:
		return "ERR_WRONG_PHASE"
	if not CardDefinition.PLAYABLE_COLORS.has(color):
		return "ERR_NEED_COLOR"
	state.current_color = color
	state.phase = Phase.PLAYING
	ev.append({"t": "color", "p": p, "color": color})
	return ""


static func _call_uno(state: GameState, p: int, ev: Array) -> String:
	var n := state.players[p].hand.size()
	if n == 1 and state.uno_vulnerable == p:
		state.uno_vulnerable = -1
		ev.append({"t": "uno", "p": p})
		return ""
	if n == 2 and p == state.current and state.phase in [Phase.PLAYING, Phase.DRAWN_DECISION, Phase.CHALLENGE_DECISION]:
		if state.players[p].uno_declared:
			return "ERR_UNO_ALREADY"
		state.players[p].uno_declared = true
		ev.append({"t": "uno", "p": p})
		return ""
	if n == 1:
		return "ERR_UNO_ALREADY"
	return "ERR_UNO_INVALID"


static func _catch(state: GameState, p: int, target: int, now_ms: int, ev: Array) -> String:
	if target < 0 or target >= state.players.size() or target == p:
		return "ERR_BAD_TARGET"
	if state.uno_vulnerable != target or state.players[target].hand.size() != 1:
		return "ERR_NOT_CATCHABLE"
	var window := state.profile.uno_catch_window_ms
	if window > 0 and now_ms >= 0 and now_ms - state.uno_vulnerable_since_ms > window:
		state.uno_vulnerable = -1
		return "ERR_CATCH_EXPIRED"
	state.uno_vulnerable = -1
	ev.append({"t": "caught", "p": target, "by": p})
	DeckManager.draw_into_hand(state, target, state.profile.uno_penalty, ev, "uno")
	return ""


## Expires a missed-UNO window by time (called by the authority's clock).
static func expire_uno_window(state: GameState, now_ms: int) -> bool:
	var window := state.profile.uno_catch_window_ms
	if state.uno_vulnerable >= 0 and window > 0 and now_ms - state.uno_vulnerable_since_ms > window:
		state.uno_vulnerable = -1
		state.version += 1
		return true
	return false


static func _swap_hands(state: GameState, a: int, b: int, ev: Array) -> void:
	var ha := state.players[a].hand
	state.players[a].hand = state.players[b].hand
	state.players[b].hand = ha
	_reset_uno_flags(state)
	ev.append({"t": "swap", "a": a, "b": b})


static func _rotate_hands(state: GameState, ev: Array) -> void:
	var n := state.players.size()
	var hands := []
	for p in state.players:
		hands.append(p.hand)
	for i in n:
		# every hand moves to the next player in the direction of play
		state.players[posmod(i + state.direction, n)].hand = hands[i]
	_reset_uno_flags(state)
	ev.append({"t": "rotate", "dir": state.direction})


static func _reset_uno_flags(state: GameState) -> void:
	state.uno_vulnerable = -1
	for p in state.players:
		p.uno_declared = false


static func _end_round(state: GameState, winner: int, ev: Array) -> void:
	_close_uno_window(state)
	var r := ScoringManager.score_round(state, winner)
	state.last_round_winner = winner
	state.last_round_points = r["per_seat"]
	var scores := []
	for p in state.players:
		scores.append(p.score)
	ev.append({"t": "round_end", "winner": winner, "points": r["points"], "per_seat": r["per_seat"], "scores": scores})
	if r["match_over"]:
		state.phase = Phase.MATCH_OVER
		state.match_winner = int(r["match_winner"])
		ev.append({"t": "match_end", "winner": state.match_winner})
	else:
		state.phase = Phase.ROUND_OVER


# --- event redaction ---------------------------------------------------------------

## Removes card identities a viewer must not learn (other players' draws/deals).
static func redact_events(events: Array, viewer: int) -> Array:
	var out := []
	for e in events:
		var t: String = e["t"]
		if t == "draw" and int(e["p"]) != viewer:
			var c: Dictionary = e.duplicate()
			c.erase("cards")
			out.append(c)
		elif t == "deal":
			var c2: Dictionary = e.duplicate()
			var mine: Array = e["cards"].get(viewer, [])
			var counts := {}
			for k in e["cards"]:
				counts[k] = e["cards"][k].size()
			c2["cards"] = {viewer: mine.duplicate()} if viewer >= 0 else {}
			c2["counts"] = counts
			out.append(c2)
		else:
			out.append(e)
	return out
