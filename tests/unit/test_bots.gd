extends TestCase

const P = GameState.Phase
const L = BotController.Level


func _authority(n: int, levels: Array, prof: RuleProfile = null) -> MatchAuthority:
	var auth := MatchAuthority.new()
	var players := Rig.players(n)
	var kinds: Array[int] = []
	for i in n:
		players[i].bot_level = levels[i % levels.size()]
		kinds.append(MatchAuthority.SeatKind.BOT)
	eq(auth.setup(prof if prof else RuleProfile.classic(), players, kinds), "")
	return auth


## Runs a bot-only match synchronously. Returns "" or an error.
func _run(auth: MatchAuthority, max_actions := 5000) -> String:
	auth.start()
	var s := auth.state
	var n := 0
	while s.phase != P.MATCH_OVER:
		if s.phase == P.ROUND_OVER:
			auth.start_next_round()
			continue
		n += 1
		if n > max_actions:
			return "match did not finish"
		var seat := s.current
		for a in auth.bot_actions(seat):
			var r := auth.submit(seat, a)
			if not r["ok"]:
				return "bot (level %d) produced illegal action %s: %s" % [s.players[seat].bot_level, str(a), r["error"]]
		if s.uno_vulnerable >= 0:
			var catcher := posmod(s.uno_vulnerable + 1, s.players.size())
			auth.submit(catcher, {"type": "catch", "target": s.uno_vulnerable})
		var integ := s.check_integrity()
		if integ != "":
			return integ
	return ""


func test_all_levels_finish_games() -> void:
	for lvl in [L.EASY, L.NORMAL, L.HARD]:
		for n in [2, 4, 7, 10]:
			var auth := _authority(n, [lvl])
			var e := _run(auth)
			auth.free()
			if e != "":
				check(false, "level %d, %d players: %s" % [lvl, n, e])
				return


func test_mixed_levels_points_mode() -> void:
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	prof.target_score = 200
	for i in 3:
		var auth := _authority(4, [L.EASY, L.NORMAL, L.HARD], prof)
		eq(_run(auth, 20000), "")
		check(auth.state.players[auth.state.match_winner].score >= 200, "winner reached target")
		auth.free()


func test_bots_with_house_rules() -> void:
	var prof := RuleProfile.classic()
	prof.stack_draw_two = true
	prof.stack_draw_four = true
	prof.stack_mixed = true
	prof.seven_zero = true
	for i in 6:
		var auth := _authority(3 + i, [L.EASY, L.NORMAL, L.HARD], prof)
		eq(_run(auth), "")
		auth.free()


func test_bot_never_plays_invalid_card() -> void:
	var s := Rig.state([["G1", "B2", "W"], ["R1"]], "R5")
	for lvl in [L.EASY, L.NORMAL, L.HARD]:
		var bot := BotController.new(lvl, 0)
		for _i in 50:
			var a := bot.choose_action(s.view_for(0))
			check(a["type"] == "play" and s.card(a["card"]).short_name() == "W", "only the wild is legal (level %d) got %s" % [lvl, str(a)])
			check(int(a.get("color", -1)) in CardDefinition.PLAYABLE_COLORS, "wild colour chosen")


func test_bot_draws_without_playable_card() -> void:
	var s := Rig.state([["G1", "B2"], ["R1"]], "R5", -1, ["Y9"])
	for lvl in [L.EASY, L.NORMAL, L.HARD]:
		var bot := BotController.new(lvl, 0)
		eq(bot.choose_action(s.view_for(0))["type"], "draw")
	ok(Rig.act(s, "draw", 0))
	eq(s.current, 1, "unplayable draw passes the turn")


func test_bot_plays_drawn_playable_card() -> void:
	var s := Rig.state([["G1", "B2"], ["R1"]], "R5", -1, ["R9"])
	ok(Rig.act(s, "draw", 0))
	var bot := BotController.new(L.NORMAL, 0)
	var a := bot.choose_action(s.view_for(0))
	eq(a["type"], "play")
	eq(s.card(a["card"]).short_name(), "R9")


func test_bot_picks_majority_colour() -> void:
	var s := Rig.state([["W", "B1", "B2", "B3", "G4"], ["R1"]], "R5")
	var bot := BotController.new(L.HARD, 0)
	var hand: Array = s.players[0].hand.duplicate()
	hand.erase(Rig.hand_id(s, 0, "W"))
	var wins := 0
	for _i in 20:
		if bot.choose_color(s.view_for(0), hand) == CardDefinition.CardColor.BLUE:
			wins += 1
	check(wins >= 18, "hard bot chooses its dominant colour (%d/20)" % wins)


func test_hard_bot_never_bluffs_wd4() -> void:
	# holds a red card: +4 would be illegal, so the hard bot must not play it
	var s := Rig.state([["W+4", "R2", "G7"], ["R1"]], "R5")
	var bot := BotController.new(L.HARD, 0)
	for _i in 60:
		var a := bot.choose_action(s.view_for(0))
		check(not (a["type"] == "play" and s.card(a["card"]).short_name() == "W+4"), "bluffed +4")


func test_bot_responds_to_challenge_phase() -> void:
	var s := Rig.state([["W+4", "B9"], ["G2", "G3"], ["Y1"]], "R5")
	ok(Rig.play(s, 0, "W+4", {"color": CardDefinition.CardColor.BLUE}))
	for lvl in [L.EASY, L.NORMAL, L.HARD]:
		var a := BotController.new(lvl, 1).choose_action(s.view_for(1))
		check(a["type"] in ["accept", "challenge"], "challenge-phase answer: " + str(a))


func test_bot_view_has_no_hidden_cards() -> void:
	var s := Rig.state([["G1", "B2"], ["R1", "R2", "R3"]], "R5")
	var v := s.view_for(0)
	for c in s.players[1].hand:
		check(not v["hand"].has(c), "opponent card visible to bot")


func test_authority_overrides_spoofed_player() -> void:
	var auth := _authority(3, [L.NORMAL])
	auth.start()
	var s := auth.state
	var other := posmod(s.current + 1, 3)
	# seat `other` claims to be the current player
	var r := auth.submit(other, {"type": "draw", "player": s.current})
	if s.phase == P.PLAYING:
		rejected(r, "ERR_NOT_YOUR_TURN")
	auth.free()


func test_authority_bot_takeover_on_disconnect() -> void:
	var auth := MatchAuthority.new()
	var players := Rig.players(3)
	var kinds: Array[int] = [MatchAuthority.SeatKind.LOCAL, MatchAuthority.SeatKind.BOT, MatchAuthority.SeatKind.BOT]
	auth.setup(RuleProfile.classic(), players, kinds, 2)
	auth.start()
	check(not auth.is_bot_seat(0))
	auth.set_connected(0, false)
	check(auth.is_bot_seat(0), "bot took over")
	eq(auth.state.players[0].connected, false)
	auth.set_connected(0, true)
	check(not auth.is_bot_seat(0), "human back in control")
	auth.free()


func test_authority_runs_real_time_bot_match() -> void:
	# Exercise the scheduler (timers, catch jobs, round breaks) in the scene tree.
	var auth := _authority(4, [L.EASY, L.NORMAL, L.HARD])
	auth.time_scale = 0.01
	runner.add_child(auth)
	auth.start()
	var t0 := Time.get_ticks_msec()
	while not auth.state.is_over() and Time.get_ticks_msec() - t0 < 20000:
		await frames(1)
	check(auth.state.is_over(), "real-time bot match finished")
	eq(auth.state.check_integrity(), "")
	auth.queue_free()
