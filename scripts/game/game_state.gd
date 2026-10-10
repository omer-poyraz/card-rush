class_name GameState
extends RefCounted
## The complete, authoritative state of one match. Only the authority (offline
## controller or room host) holds a full GameState; everybody else receives
## redacted views built by `view_for()`.

enum Phase {
	WAITING,             # not dealt yet
	CHOOSE_COLOR,        # first discard was a Wild: current player picks the colour
	PLAYING,             # current player must play or draw (or answer a +2 stack)
	DRAWN_DECISION,      # current player drew a playable card: play it or keep it
	CHALLENGE_DECISION,  # current player was hit by +4: accept / challenge / stack
	ROUND_OVER,
	MATCH_OVER,
}

var profile: RuleProfile
var cards: Array[CardDefinition] = []
var players: Array[PlayerState] = []
var draw_pile: Array[int] = []      # back = top
var discard_pile: Array[int] = []   # back = top
var current_color := CardDefinition.CardColor.WILD
var current := 0
var direction := 1
var dealer := 0
var phase := Phase.WAITING
var pending_draw := 0               # accumulated +2/+4 not yet drawn
var drawn_card := -1                # card the current player just drew (DRAWN_DECISION)
## Set while a +4 can be challenged: {offender, color_before, guilty}
var challenge := {}
var uno_vulnerable := -1            # seat that can currently be caught
var uno_vulnerable_since_ms := 0
var round_number := 0
var version := 0                    # increments on every accepted action
var turn_serial := 0                # increments each time the turn moves
var last_round_winner := -1
var match_winner := -1
var last_round_points := {}         # seat index -> remaining hand points (last round)
var rng := RandomNumberGenerator.new()


func _init(p_profile: RuleProfile = null) -> void:
	profile = p_profile if p_profile != null else RuleProfile.classic()
	cards = DeckProfile.build(profile.deck_id)
	reseed_secure()


## Seeds the shuffler from the OS cryptographic RNG so deals are unpredictable.
func reseed_secure() -> void:
	var bytes := Crypto.new().generate_random_bytes(8)
	rng.seed = bytes.decode_u64(0)


func card(id: int) -> CardDefinition:
	return cards[id]


func top_card() -> CardDefinition:
	return cards[discard_pile.back()] if not discard_pile.is_empty() else null


func player_count() -> int:
	return players.size()


func next_index(from: int, steps := 1) -> int:
	var n := players.size()
	return posmod(from + direction * steps, n)


func is_over() -> bool:
	return phase == Phase.MATCH_OVER


## Every card id appears exactly once across hands and piles (invariant check).
func all_card_ids() -> Array[int]:
	var out: Array[int] = []
	out.append_array(draw_pile)
	out.append_array(discard_pile)
	for p in players:
		out.append_array(p.hand)
	return out


func check_integrity() -> String:
	var ids := all_card_ids()
	if ids.size() != cards.size():
		return "card count %d != %d" % [ids.size(), cards.size()]
	var seen := {}
	for i in ids:
		if seen.has(i):
			return "duplicate card %d" % i
		seen[i] = true
	return ""


# --- views ------------------------------------------------------------------------

## What seat `viewer` may legally know. viewer = -1 builds a spectator view.
func view_for(viewer: int) -> Dictionary:
	var ps := []
	for i in players.size():
		var p := players[i]
		ps.append({
			"name": p.display_name, "avatar": p.avatar, "is_bot": p.is_bot,
			"connected": p.connected, "count": p.hand.size(), "score": p.score,
			"uno": p.uno_declared or (p.hand.size() == 1 and uno_vulnerable != i),
		})
	var v := {
		"version": version,
		"phase": phase,
		"me": viewer,
		"players": ps,
		"hand": players[viewer].hand.duplicate() if viewer >= 0 and viewer < players.size() else [],
		"top": discard_pile.back() if not discard_pile.is_empty() else -1,
		"discard_count": discard_pile.size(),
		"draw_count": draw_pile.size(),
		"color": current_color,
		"current": current,
		"direction": direction,
		"dealer": dealer,
		"pending_draw": pending_draw,
		"drawn_card": drawn_card if viewer == current else -1,
		"challengeable": not challenge.is_empty() and pending_draw == 4,
		"challenge_offender": challenge.get("offender", -1),
		"uno_vulnerable": uno_vulnerable,
		"round": round_number,
		"turn_serial": turn_serial,
		"last_round_winner": last_round_winner,
		"match_winner": match_winner,
		"last_round_points": last_round_points.duplicate(),
		"rules": profile.to_dict(),
	}
	return v


# --- full serialisation (authority hand-over / save) ---------------------------------

func to_dict() -> Dictionary:
	var ps := []
	for p in players:
		ps.append(p.to_dict())
	return {
		"profile": profile.to_dict(), "players": ps, "draw": draw_pile.duplicate(),
		"discard": discard_pile.duplicate(), "color": current_color, "current": current,
		"direction": direction, "dealer": dealer, "phase": phase, "pending": pending_draw,
		"drawn": drawn_card, "challenge": challenge.duplicate(), "uno_v": uno_vulnerable,
		"round": round_number, "version": version, "turn_serial": turn_serial,
		"lrw": last_round_winner, "mw": match_winner,
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new(RuleProfile.from_dict(d.get("profile", {})))
	for pd in d.get("players", []):
		s.players.append(PlayerState.from_dict(pd))
	for c in d.get("draw", []):
		s.draw_pile.append(int(c))
	for c in d.get("discard", []):
		s.discard_pile.append(int(c))
	s.current_color = int(d.get("color", CardDefinition.CardColor.WILD))
	s.current = int(d.get("current", 0))
	s.direction = int(d.get("direction", 1))
	s.dealer = int(d.get("dealer", 0))
	s.phase = int(d.get("phase", Phase.WAITING))
	s.pending_draw = int(d.get("pending", 0))
	s.drawn_card = int(d.get("drawn", -1))
	s.challenge = d.get("challenge", {})
	s.uno_vulnerable = int(d.get("uno_v", -1))
	s.round_number = int(d.get("round", 0))
	s.version = int(d.get("version", 0))
	s.turn_serial = int(d.get("turn_serial", 0))
	s.last_round_winner = int(d.get("lrw", -1))
	s.match_winner = int(d.get("mw", -1))
	# Never resume the old RNG stream after a hand-over: reseed so a former
	# client that saw the serialised state cannot predict future draws.
	s.reseed_secure()
	return s
