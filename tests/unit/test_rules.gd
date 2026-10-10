extends TestCase

const P = GameState.Phase
const RED = CardDefinition.CardColor.RED
const YELLOW = CardDefinition.CardColor.YELLOW
const GREEN = CardDefinition.CardColor.GREEN
const BLUE = CardDefinition.CardColor.BLUE


# --- matching -----------------------------------------------------------------------

func test_valid_cards_playable() -> void:
	var s := Rig.state([["R1", "G5", "B-skip", "W", "Y3"], ["G1"]], "G-skip")
	check(RuleEngine.can_play(s, 0, Rig.hand_id(s, 0, "G5")), "same colour")
	check(RuleEngine.can_play(s, 0, Rig.hand_id(s, 0, "B-skip")), "same symbol")
	check(RuleEngine.can_play(s, 0, Rig.hand_id(s, 0, "W")), "wild")
	check(not RuleEngine.can_play(s, 0, Rig.hand_id(s, 0, "R1")), "no match")
	check(not RuleEngine.can_play(s, 0, Rig.hand_id(s, 0, "Y3")), "no match 2")


func test_same_number_other_colour() -> void:
	var s := Rig.state([["B7", "B8"], ["G1"]], "R7")
	ok(Rig.play(s, 0, "B7"))
	eq(s.current_color, BLUE)
	eq(s.current, 1)


func test_invalid_card_rejected_by_engine() -> void:
	var s := Rig.state([["R1", "G2"], ["G1"]], "B5")
	var before := s.version
	rejected(Rig.play(s, 0, "R1"), "ERR_CARD_NOT_PLAYABLE")
	eq(s.version, before, "state untouched")
	eq(s.players[0].hand.size(), 2)


func test_not_your_turn() -> void:
	var s := Rig.state([["R1"], ["R2", "R3"]], "R5")
	rejected(Rig.play(s, 1, "R2"), "ERR_NOT_YOUR_TURN")
	rejected(Rig.act(s, "draw", 1), "ERR_NOT_YOUR_TURN")


func test_card_not_in_hand() -> void:
	var s := Rig.state([["R1", "R3"], ["R2"]], "R5")
	var foreign := Rig.hand_id(s, 1, "R2")
	rejected(RuleEngine.apply(s, {"type": "play", "player": 0, "card": foreign}), "ERR_CARD_NOT_IN_HAND")


func test_same_card_cannot_be_played_twice() -> void:
	var s := Rig.state([["R1", "R3"], ["R2", "R4"], ["R6", "R8"]], "R5")
	var id := Rig.hand_id(s, 0, "R1")
	ok(RuleEngine.apply(s, {"type": "play", "player": 0, "card": id}))
	rejected(RuleEngine.apply(s, {"type": "play", "player": 0, "card": id}))


func test_stale_version_rejected() -> void:
	var s := Rig.state([["R1", "R3"], ["R2", "R4"]], "R5")
	var v := s.version
	ok(RuleEngine.apply(s, {"type": "play", "player": 0, "card": Rig.hand_id(s, 0, "R1"), "v": v}))
	# replaying the same message (old version) is ignored
	rejected(RuleEngine.apply(s, {"type": "play", "player": 1, "card": Rig.hand_id(s, 1, "R2"), "v": v}), "ERR_STALE")


# --- action cards --------------------------------------------------------------------

func test_skip_skips_next_player() -> void:
	var s := Rig.state([["R-skip", "R1"], ["R2"], ["R3"], ["R4"]], "R5")
	ok(Rig.play(s, 0, "R-skip"))
	eq(s.current, 2, "player 1 skipped")


func test_reverse_changes_direction() -> void:
	var s := Rig.state([["R-rev", "R1"], ["R2"], ["R3"], ["R4"]], "R5")
	ok(Rig.play(s, 0, "R-rev"))
	eq(s.direction, -1)
	eq(s.current, 3, "goes to the previous player")


func test_reverse_two_players_acts_as_skip() -> void:
	var s := Rig.state([["R-rev", "R1"], ["R2"]], "R5")
	ok(Rig.play(s, 0, "R-rev"))
	eq(s.current, 0, "same player plays again")


func test_skip_two_players() -> void:
	var s := Rig.state([["R-skip", "R1"], ["R2"]], "R5")
	ok(Rig.play(s, 0, "R-skip"))
	eq(s.current, 0)


func test_draw_two_penalty() -> void:
	var s := Rig.state([["R+2", "R1"], ["G2"], ["B3"]], "R5")
	ok(Rig.play(s, 0, "R+2"))
	eq(s.players[1].hand.size(), 3, "victim drew two")
	eq(s.current, 2, "victim lost turn")
	eq(s.pending_draw, 0)


func test_draw_two_on_draw_two_matches_symbol() -> void:
	var s := Rig.state([["B+2", "R1"], ["G2"], ["B3"]], "R+2")
	ok(Rig.play(s, 0, "B+2"), "+2 on +2 by symbol (not a stack, top penalty already resolved)")


func test_wild_sets_colour() -> void:
	var s := Rig.state([["W", "R1"], ["G2"]], "R5")
	rejected(Rig.play(s, 0, "W"), "ERR_NEED_COLOR")
	ok(Rig.play(s, 0, "W", {"color": GREEN}))
	eq(s.current_color, GREEN)
	eq(s.current, 1)
	check(RuleEngine.can_play(s, 1, Rig.hand_id(s, 1, "G2")), "green now playable")


# --- wild draw four ----------------------------------------------------------------

func test_wd4_restriction_detects_colour_only() -> void:
	var s := Rig.state([["W+4", "B5", "W"], ["G2"]], "R5")
	# holds a 5 of another colour and a wild: still legal (only colour matters)
	check(RuleEngine.wd4_legal(s.cards, s.players[0].hand, s.current_color), "legal: no red card")
	var s2 := Rig.state([["W+4", "R9"], ["G2"]], "R5")
	check(not RuleEngine.wd4_legal(s2.cards, s2.players[0].hand, s2.current_color), "illegal: holds red")


func test_wd4_strict_mode_blocks_illegal_play() -> void:
	var prof := RuleProfile.classic()
	prof.wd4_mode = RuleProfile.Wd4Mode.STRICT
	var s := Rig.state([["W+4", "R9"], ["G2"]], "R5", -1, [], prof)
	rejected(Rig.play(s, 0, "W+4", {"color": BLUE}), "ERR_WD4_RESTRICTED")
	var s2 := Rig.state([["W+4", "B9"], ["G2"]], "R5", -1, [], prof)
	ok(Rig.play(s2, 0, "W+4", {"color": BLUE}))
	eq(s2.players[1].hand.size(), 5, "no challenge in strict mode: victim drew 4")
	eq(s2.current, 0, "victim skipped (2 players)")


func test_wd4_accept() -> void:
	var s := Rig.state([["W+4", "B9"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	eq(s.phase, P.CHALLENGE_DECISION)
	eq(s.current, 1)
	ok(Rig.act(s, "accept", 1))
	eq(s.players[1].hand.size(), 5)
	eq(s.current, 2, "victim skipped")
	eq(s.current_color, BLUE)


func test_wd4_challenge_succeeds_when_bluffing() -> void:
	var s := Rig.state([["W+4", "R9", "G1"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	var r := Rig.act(s, "challenge", 1)
	ok(r)
	eq(s.players[0].hand.size(), 6, "offender drew 4")
	eq(s.players[1].hand.size(), 1, "challenger drew nothing")
	eq(s.current, 1, "challenger takes a normal turn")
	eq(s.phase, P.PLAYING)
	eq(s.current_color, BLUE, "chosen colour stays")
	var ev: Array = r["events"]
	check(ev.any(func(e): return e["t"] == "challenge" and e["guilty"]), "guilty verdict event")


func test_wd4_challenge_same_number_other_colour_is_not_guilty() -> void:
	# Holding a 5 of another colour does not make a +4 on a red 5 illegal.
	var s := Rig.state([["W+4", "B5", "G1"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	ok(Rig.act(s, "challenge", 1))
	eq(s.players[1].hand.size(), 7, "challenger drew 6")
	eq(s.players[0].hand.size(), 2, "offender drew nothing")
	eq(s.current, 2, "challenger lost the turn")


func test_wd4_challenge_fails() -> void:
	var s := Rig.state([["W+4", "B9", "G1"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	ok(Rig.act(s, "challenge", 1))
	eq(s.players[1].hand.size(), 7)
	eq(s.current, 2)


func test_challenge_only_by_victim_and_only_once() -> void:
	var s := Rig.state([["W+4", "B9", "G1"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	rejected(Rig.act(s, "challenge", 2), "ERR_NOT_YOUR_TURN")
	ok(Rig.act(s, "challenge", 1))
	rejected(Rig.act(s, "challenge", 2))


func test_challenge_view_does_not_leak_hand() -> void:
	var s := Rig.state([["W+4", "R9", "G1"], ["G2"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	var v := s.view_for(1)
	eq(v["hand"].size(), 1, "victim only sees own hand")
	check(not str(v).contains("guilty"), "guilt is not visible before the challenge")


# --- drawing ----------------------------------------------------------------------

func test_draw_playable_card_then_play_it() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["R7"])
	ok(Rig.act(s, "draw", 0))
	eq(s.phase, P.DRAWN_DECISION)
	eq(s.current, 0)
	# only the drawn card may be played
	rejected(Rig.play(s, 0, "G1"))
	ok(Rig.play(s, 0, "R7"))
	eq(s.current, 1)


func test_draw_playable_card_and_keep_it() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["R7"])
	ok(Rig.act(s, "draw", 0))
	ok(Rig.act(s, "pass", 0))
	eq(s.players[0].hand.size(), 2)
	eq(s.current, 1)


func test_draw_unplayable_card_ends_turn() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["B7"])
	ok(Rig.act(s, "draw", 0))
	eq(s.current, 1)
	eq(s.phase, P.PLAYING)
	rejected(Rig.act(s, "pass", 0))


func test_draw_allowed_with_playable_card_official() -> void:
	var s := Rig.state([["R1"], ["Y2"]], "R5", -1, ["B7"])
	ok(Rig.act(s, "draw", 0), "official rules allow drawing instead of playing")


func test_cannot_draw_twice() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["R7", "R8"])
	ok(Rig.act(s, "draw", 0))
	rejected(Rig.act(s, "draw", 0), "ERR_WRONG_PHASE")


# --- UNO -----------------------------------------------------------------------------

func test_uno_called_in_time_is_safe() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"], ["B1", "B2"]], "R5")
	ok(Rig.act(s, "uno", 0))
	ok(Rig.play(s, 0, "R1"))
	eq(s.uno_vulnerable, -1)
	rejected(Rig.act(s, "catch", 1, {"target": 0}), "ERR_NOT_CATCHABLE")


func test_uno_missed_and_caught() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"], ["B1", "B2"]], "R5")
	ok(Rig.play(s, 0, "R1", {"now_ms": 1000}))
	eq(s.uno_vulnerable, 0)
	ok(Rig.act(s, "catch", 2, {"target": 0, "now_ms": 1500}))
	eq(s.players[0].hand.size(), 3, "penalty two cards")
	# same violation cannot be punished twice
	rejected(Rig.act(s, "catch", 1, {"target": 0, "now_ms": 1600}), "ERR_NOT_CATCHABLE")


func test_uno_self_call_after_playing() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"]], "R5")
	ok(Rig.play(s, 0, "R1"))
	ok(Rig.act(s, "uno", 0))
	rejected(Rig.act(s, "catch", 1, {"target": 0}))


func test_uno_window_closes_when_next_player_acts() -> void:
	var s := Rig.state([["R1", "R2"], ["R3", "Y3"], ["B1", "B2"]], "R5")
	ok(Rig.play(s, 0, "R1"))
	ok(Rig.play(s, 1, "R3"))
	rejected(Rig.act(s, "catch", 2, {"target": 0}), "ERR_NOT_CATCHABLE")


func test_uno_window_expires_by_time() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"]], "R5")
	ok(Rig.play(s, 0, "R1", {"now_ms": 1000}))
	rejected(Rig.act(s, "catch", 1, {"target": 0, "now_ms": 1000 + s.profile.uno_catch_window_ms + 1}), "ERR_CATCH_EXPIRED")


func test_cannot_catch_self_or_safe_player() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"]], "R5")
	ok(Rig.play(s, 0, "R1"))
	rejected(Rig.act(s, "catch", 0, {"target": 0}), "ERR_BAD_TARGET")
	rejected(Rig.act(s, "catch", 0, {"target": 1}), "ERR_NOT_CATCHABLE")


func test_uno_invalid_with_many_cards() -> void:
	var s := Rig.state([["R1", "R2", "R3"], ["Y2"]], "R5")
	rejected(Rig.act(s, "uno", 0), "ERR_UNO_INVALID")


# --- round end and scoring -----------------------------------------------------------

func test_last_card_wins_round_single_mode() -> void:
	var s := Rig.state([["R1"], ["Y2", "W", "G-skip"]], "R5")
	var r := Rig.play(s, 0, "R1")
	ok(r)
	eq(s.phase, P.MATCH_OVER)
	eq(s.match_winner, 0)
	eq(s.players[0].score, 2 + 50 + 20, "classic points")
	rejected(Rig.act(s, "draw", 1), "ERR_NOT_IN_PLAY")


func test_points_mode_continues_until_target() -> void:
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	prof.target_score = 500
	var s := Rig.state([["R1"], ["Y2", "W"]], "R5", -1, [], prof)
	ok(Rig.play(s, 0, "R1"))
	eq(s.phase, P.ROUND_OVER)
	eq(s.players[0].score, 52)
	RuleEngine.start_round(s)
	eq(s.round_number, 2)
	eq(s.phase in [P.PLAYING, P.CHOOSE_COLOR], true)
	eq(s.check_integrity(), "")
	eq(s.players[0].score, 52, "scores persist across rounds")


func test_points_mode_reaches_target() -> void:
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	prof.target_score = 100
	var s := Rig.state([["R1"], ["Y2", "W", "W+4"]], "R5", -1, [], prof)
	ok(Rig.play(s, 0, "R1"))
	eq(s.phase, P.MATCH_OVER)
	eq(s.players[0].score, 102)


func test_final_draw_two_counts() -> void:
	var s := Rig.state([["R+2"], ["Y2"], ["B1"]], "R5", -1, ["G9", "B-skip"])
	ok(Rig.play(s, 0, "R+2"))
	eq(s.players[1].hand.size(), 3, "next player still draws")
	eq(s.players[0].score, 2 + 9 + 20 + 1, "drawn cards are scored")


func test_final_wd4_counts() -> void:
	var s := Rig.state([["W+4"], ["Y2"]], "R5", -1, ["G9", "G8", "G7", "G6"])
	ok(Rig.play(s, 0, "W+4", {"color": RED}))
	eq(s.players[1].hand.size(), 5)
	eq(s.players[0].score, 2 + 9 + 8 + 7 + 6)
	eq(s.phase, P.MATCH_OVER)


func test_no_actions_after_game_over() -> void:
	var s := Rig.state([["R1"], ["R2", "R3"]], "R5")
	ok(Rig.play(s, 0, "R1"))
	rejected(Rig.play(s, 1, "R2"), "ERR_NOT_IN_PLAY")
	rejected(Rig.act(s, "uno", 1), "ERR_NOT_IN_PLAY")


# --- first card ----------------------------------------------------------------------

func test_first_card_rules_via_start_round() -> void:
	# Run many real deals and check each first-card effect against the official rules.
	var seen := {}
	for _i in 400:
		var s := GameState.new()
		RuleEngine.setup_match(s, Rig.players(4), 0)
		RuleEngine.start_round(s)
		var first := s.card(s.discard_pile[0])
		seen[first.kind] = true
		eq(s.check_integrity(), "", "integrity")
		check(first.kind != CardDefinition.Kind.WILD_DRAW_FOUR, "W+4 never starts")
		match first.kind:
			CardDefinition.Kind.NUMBER:
				eq(s.current, 1, "number: left of dealer starts")
			CardDefinition.Kind.SKIP:
				eq(s.current, 2, "skip: first player skipped")
			CardDefinition.Kind.REVERSE:
				eq(s.current, 0, "reverse: dealer starts")
				eq(s.direction, -1)
			CardDefinition.Kind.DRAW_TWO:
				eq(s.players[1].hand.size(), 9, "draw two: first player draws 2")
				eq(s.current, 2)
			CardDefinition.Kind.WILD:
				eq(s.phase, P.CHOOSE_COLOR)
				eq(s.current, 1)
		if not failures.is_empty():
			return
	check(seen.size() >= 4, "covered several first-card kinds")


func test_first_wild_choose_colour() -> void:
	for _i in 300:
		var s := GameState.new()
		RuleEngine.setup_match(s, Rig.players(3), 0)
		RuleEngine.start_round(s)
		if s.phase != P.CHOOSE_COLOR:
			continue
		rejected(Rig.act(s, "draw", s.current), "ERR_WRONG_PHASE")
		rejected(Rig.act(s, "choose_color", (s.current + 1) % 3, {"color": RED}), "ERR_NOT_YOUR_TURN")
		ok(Rig.act(s, "choose_color", s.current, {"color": YELLOW}))
		eq(s.current_color, YELLOW)
		eq(s.phase, P.PLAYING)
		return
	check(false, "no wild first card seen in 300 deals")


func test_number_only_first_card_house_rule() -> void:
	var prof := RuleProfile.classic()
	prof.first_card_mode = RuleProfile.FirstCardMode.NUMBER_ONLY
	for _i in 100:
		var s := GameState.new(prof)
		RuleEngine.setup_match(s, Rig.players(4), 0)
		RuleEngine.start_round(s)
		eq(s.card(s.discard_pile[0]).kind, CardDefinition.Kind.NUMBER)
		eq(s.check_integrity(), "")


func test_dealer_rotates_each_round() -> void:
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	var s := GameState.new(prof)
	RuleEngine.setup_match(s, Rig.players(3), 0)
	RuleEngine.start_round(s)
	eq(s.dealer, 0)
	s.phase = P.ROUND_OVER
	RuleEngine.start_round(s)
	eq(s.dealer, 1)


# --- player count / profile ------------------------------------------------------------

func test_player_count_limits() -> void:
	var prof := RuleProfile.classic()
	eq(prof.validate_player_count(1), "ERR_TOO_FEW_PLAYERS")
	eq(prof.validate_player_count(2), "")
	eq(prof.validate_player_count(10), "")
	eq(prof.validate_player_count(11), "ERR_TOO_MANY_PLAYERS")


func test_ten_players_full_deal() -> void:
	var s := GameState.new()
	eq(RuleEngine.setup_match(s, Rig.players(10), 3), "")
	RuleEngine.start_round(s)
	eq(s.check_integrity(), "")
	check(s.draw_pile.size() >= 108 - 70 - 1 - 2, "enough cards left")


func test_profile_round_trip_and_sanitising() -> void:
	var prof := RuleProfile.classic()
	prof.stack_draw_two = true
	prof.target_score = 250
	var back := RuleProfile.from_dict(prof.to_dict())
	eq(back.to_dict(), prof.to_dict())
	var evil := RuleProfile.from_dict({"hand_size": 99, "target_score": -5, "deck_id": "x", "uno_penalty": 50})
	eq(evil.hand_size, 10)
	eq(evil.target_score, 50)
	eq(evil.deck_id, DeckProfile.CLASSIC_108)
	eq(evil.uno_penalty, 6)


func test_classic_profile_has_no_house_rules() -> void:
	var prof := RuleProfile.classic()
	check(prof.is_classic())
	prof.seven_zero = true
	eq(prof.active_house_rules(), ["seven_zero"] as Array[String])


func test_state_view_hides_other_hands() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3", "Y4"]], "R5")
	var v := s.view_for(0)
	eq(v["hand"].size(), 2)
	eq(v["players"][1]["count"], 3)
	check(not v["players"][1].has("hand"), "no opponent hand in view")
	var ev := RuleEngine.redact_events([{"t": "draw", "p": 1, "n": 1, "cards": [5]}], 0)
	check(not ev[0].has("cards"), "opponent draw redacted")
	var ev2 := RuleEngine.redact_events([{"t": "draw", "p": 0, "n": 1, "cards": [5]}], 0)
	check(ev2[0].has("cards"), "own draw visible")


func test_state_serialisation_round_trip() -> void:
	var s := Rig.state([["R1", "W+4"], ["Y2", "Y3"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": GREEN}))
	var copy := GameState.from_dict(s.to_dict())
	eq(copy.check_integrity(), "")
	eq(copy.phase, s.phase)
	eq(copy.pending_draw, 4)
	eq(copy.challenge, s.challenge)
	eq(copy.players[1].hand, s.players[1].hand)
