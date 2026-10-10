extends TestCase

const P = GameState.Phase
const RED = CardDefinition.CardColor.RED
const BLUE = CardDefinition.CardColor.BLUE


func _prof(changes: Dictionary) -> RuleProfile:
	var p := RuleProfile.classic()
	for k in changes:
		p.set(k, changes[k])
	return p


func test_stacking_off_by_default() -> void:
	var s := Rig.state([["R+2", "R1"], ["B+2", "G1"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "R+2"))
	eq(s.players[1].hand.size(), 4, "classic: drew immediately, no chance to stack")
	eq(s.current, 2)


func test_stack_draw_two() -> void:
	var s := Rig.state([["R+2", "R1"], ["B+2", "G1"], ["Y1", "Y2"]], "R5", -1, [], _prof({"stack_draw_two": true}))
	ok(Rig.play(s, 0, "R+2"))
	eq(s.current, 1)
	eq(s.pending_draw, 2)
	check(not RuleEngine.can_play(s, 1, Rig.hand_id(s, 1, "G1")), "only stack cards while pending")
	ok(Rig.play(s, 1, "B+2"))
	eq(s.pending_draw, 4)
	eq(s.current, 2)
	ok(Rig.act(s, "draw", 2), "draw = accept the stack")
	eq(s.players[2].hand.size(), 6)
	eq(s.pending_draw, 0)
	eq(s.current, 0, "player 2 lost the turn")


func test_stack_draw_four_and_challenge_not_available_on_chain() -> void:
	var s := Rig.state([["W+4", "B1"], ["W+4", "G1"], ["Y1", "Y2"]], "R5", -1, [], _prof({"stack_draw_four": true}))
	ok(Rig.play(s, 0, "W+4", {"color": BLUE}))
	eq(s.phase, P.CHALLENGE_DECISION, "single +4 can still be challenged")
	ok(Rig.play(s, 1, "W+4", {"color": RED}))
	eq(s.pending_draw, 8)
	eq(s.phase, P.PLAYING)
	rejected(Rig.act(s, "challenge", 2))
	ok(Rig.act(s, "accept", 2))
	eq(s.players[2].hand.size(), 10)


func test_mixed_stacking_requires_flag() -> void:
	var s := Rig.state([["R+2", "R1"], ["W+4", "G1"], ["Y1"]], "R5", -1, [], _prof({"stack_draw_two": true}))
	ok(Rig.play(s, 0, "R+2"))
	check(not RuleEngine.can_play(s, 1, Rig.hand_id(s, 1, "W+4")), "+4 on +2 needs stack_mixed")
	var s2 := Rig.state([["R+2", "R1"], ["W+4", "G1"], ["Y1"]], "R5", -1, [], _prof({"stack_draw_two": true, "stack_mixed": true}))
	ok(Rig.play(s2, 0, "R+2"))
	ok(Rig.play(s2, 1, "W+4", {"color": BLUE}))
	eq(s2.pending_draw, 6)


func test_seven_swaps_hands() -> void:
	var s := Rig.state([["R7", "R1", "R2"], ["G1"], ["Y1", "Y2"]], "R5", -1, [], _prof({"seven_zero": true}))
	rejected(Rig.play(s, 0, "R7"), "ERR_NEED_TARGET")
	ok(Rig.play(s, 0, "R7", {"target": 2}))
	eq(s.players[0].hand.size(), 2, "got player 2's hand")
	eq(s.players[2].hand.size(), 2, "player 2 got the rest")
	eq(s.check_integrity(), "")


func test_zero_rotates_hands() -> void:
	var s := Rig.state([["R0", "R1"], ["G1", "G2", "G3"], ["Y1"]], "R5", -1, [], _prof({"seven_zero": true}))
	var h1 := s.players[1].hand.duplicate()
	ok(Rig.play(s, 0, "R0"))
	eq(s.players[2].hand, h1, "hands move in direction of play")
	eq(s.players[1].hand.size(), 1)
	eq(s.check_integrity(), "")


func test_seven_without_house_rule_is_normal() -> void:
	var s := Rig.state([["R7", "R1"], ["G1"]], "R5")
	ok(Rig.play(s, 0, "R7"))
	eq(s.players[0].hand.size(), 1)


func test_auto_play_drawn() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["R7"], _prof({"auto_play_drawn": true}))
	ok(Rig.act(s, "draw", 0))
	eq(s.card(s.discard_pile.back()).short_name(), "R7", "drawn card auto-played")
	eq(s.current, 1)


func test_auto_play_drawn_wild_still_asks_colour() -> void:
	var s := Rig.state([["G1"], ["Y2"]], "R5", -1, ["W"], _prof({"auto_play_drawn": true}))
	ok(Rig.act(s, "draw", 0))
	eq(s.phase, P.DRAWN_DECISION)


func test_custom_uno_penalty() -> void:
	var s := Rig.state([["R1", "R2"], ["Y2", "Y3"]], "R5", -1, [], _prof({"uno_penalty": 4}))
	ok(Rig.play(s, 0, "R1"))
	ok(Rig.act(s, "catch", 1, {"target": 0}))
	eq(s.players[0].hand.size(), 5)
