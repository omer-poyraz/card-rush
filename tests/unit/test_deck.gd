extends TestCase

const K = CardDefinition.Kind


func test_classic_deck_has_108_cards() -> void:
	var d := DeckProfile.build(DeckProfile.CLASSIC_108)
	eq(d.size(), 108, "deck size")
	eq(d.size(), DeckProfile.EXPECTED_COUNTS[DeckProfile.CLASSIC_108], "expected count table")


func test_each_colour_has_correct_cards() -> void:
	var d := DeckProfile.build(DeckProfile.CLASSIC_108)
	for col in CardDefinition.PLAYABLE_COLORS:
		var of_col := d.filter(func(c): return c.color == col)
		eq(of_col.size(), 25, "cards of colour %d" % col)
		eq(of_col.filter(func(c): return c.kind == K.NUMBER and c.number == 0).size(), 1, "zeros")
		for n in range(1, 10):
			eq(of_col.filter(func(c): return c.kind == K.NUMBER and c.number == n).size(), 2, "number %d" % n)
		for k in [K.SKIP, K.REVERSE, K.DRAW_TWO]:
			eq(of_col.filter(func(c): return c.kind == k).size(), 2, "action %d" % k)


func test_wild_cards() -> void:
	var d := DeckProfile.build(DeckProfile.CLASSIC_108)
	eq(d.filter(func(c): return c.kind == K.WILD).size(), 4, "wild")
	eq(d.filter(func(c): return c.kind == K.WILD_DRAW_FOUR).size(), 4, "wild draw four")
	eq(d.filter(func(c): return c.color == CardDefinition.CardColor.WILD).size(), 8, "wild coloured")


func test_unique_ids_match_index() -> void:
	var d := DeckProfile.build(DeckProfile.CLASSIC_108)
	var seen := {}
	for i in d.size():
		eq(d[i].id, i, "id equals index")
		check(not seen.has(d[i].id), "duplicate id")
		seen[d[i].id] = true


func test_card_points() -> void:
	var s := GameState.new()
	eq(s.card(Rig.id_of(s, "R7")).points(), 7)
	eq(s.card(Rig.id_of(s, "G0")).points(), 0)
	for n in ["Y-skip", "B-rev", "G+2"]:
		eq(s.card(Rig.id_of(s, n)).points(), 20, n)
	eq(s.card(Rig.id_of(s, "W")).points(), 50)
	eq(s.card(Rig.id_of(s, "W+4")).points(), 50)


func test_shuffle_preserves_cards() -> void:
	var s := GameState.new()
	s.players = Rig.players(4)
	DeckManager.collect_and_shuffle(s)
	eq(s.check_integrity(), "", "integrity")
	var sorted := s.draw_pile.duplicate()
	sorted.sort()
	eq(sorted[0], 0)
	eq(sorted[107], 107)


func test_two_shuffles_differ() -> void:
	var a := GameState.new()
	var b := GameState.new()
	a.players = Rig.players(2)
	b.players = Rig.players(2)
	DeckManager.collect_and_shuffle(a)
	DeckManager.collect_and_shuffle(b)
	check(a.draw_pile != b.draw_pile, "two secure-seeded shuffles produced the same order")


func test_deal_seven_each() -> void:
	var s := GameState.new()
	eq(RuleEngine.setup_match(s, Rig.players(5), 0), "")
	RuleEngine.start_round(s)
	for p in s.players:
		check(p.hand.size() >= 7, "hand size >= 7 (first-card +2 may add)")
	eq(s.discard_pile.size(), 1, "one discard")
	eq(s.check_integrity(), "", "integrity after deal")
	check(s.card(s.discard_pile[0]).kind != K.WILD_DRAW_FOUR, "first card never W+4")


func test_draw_and_discard_do_not_lose_cards() -> void:
	var s := Rig.state([["R1", "R2"], ["G1"]], "R5")
	var ev := []
	DeckManager.draw_into_hand(s, 0, 10, ev)
	eq(s.players[0].hand.size(), 12)
	eq(s.check_integrity(), "", "integrity")


func test_reshuffle_keeps_top_card() -> void:
	var s := Rig.state([["R1"], ["G1"]], "R5")
	# move all of the draw pile to the discard (under the top card)
	var top: int = s.discard_pile.pop_back()
	s.discard_pile.append_array(s.draw_pile)
	s.discard_pile.append(top)
	s.draw_pile.clear()
	var ev := []
	var got := DeckManager.draw_into_hand(s, 0, 1, ev)
	eq(got.size(), 1, "drew after reshuffle")
	eq(s.discard_pile, [top] as Array[int], "only the top card stays on the discard")
	check(ev.any(func(e): return e["t"] == "reshuffle"), "reshuffle event")
	eq(s.check_integrity(), "", "integrity")


func test_empty_piles_do_not_loop() -> void:
	var s := Rig.state([["R1"], ["G1"]], "R5")
	# give every remaining card to player 1
	s.players[1].hand.append_array(s.draw_pile)
	s.draw_pile.clear()
	var ev := []
	var got := DeckManager.draw_into_hand(s, 0, 4, ev)
	eq(got.size(), 0, "nothing to draw")
	eq(s.check_integrity(), "", "integrity")
	# a normal draw action simply passes the turn
	var r := Rig.act(s, "draw", 0)
	ok(r)
	eq(s.current, 1, "turn passed")
