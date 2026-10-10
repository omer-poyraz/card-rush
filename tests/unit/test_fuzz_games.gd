extends TestCase
## Plays many complete random games through the public engine API and checks
## invariants after every action: no card lost or duplicated, every game ends,
## illegal random actions are always rejected without changing state.

const P = GameState.Phase


func _random_game(n: int, prof: RuleProfile, rng: RandomNumberGenerator) -> String:
	var s := GameState.new(prof)
	var err := RuleEngine.setup_match(s, Rig.players(n), rng.randi_range(0, n - 1))
	if err != "":
		return err
	RuleEngine.start_round(s)
	var steps := 0
	var now := 0
	while s.phase != P.MATCH_OVER:
		steps += 1
		now += 500
		if steps > 6000:
			return "game did not finish"
		if s.phase == P.ROUND_OVER:
			RuleEngine.start_round(s)
			continue
		# random UNO noise
		if rng.randf() < 0.15:
			var who := rng.randi_range(0, n - 1)
			RuleEngine.apply(s, {"type": "uno", "player": who})
		if s.uno_vulnerable >= 0 and rng.randf() < 0.5:
			var by := posmod(s.uno_vulnerable + 1, n)
			var r := RuleEngine.apply(s, {"type": "catch", "player": by, "target": s.uno_vulnerable, "now_ms": now})
			if not r["ok"]:
				return "catch rejected: " + r["error"]
		# an illegal action must never change the state
		var before := s.version
		var bad := RuleEngine.apply(s, {"type": "play", "player": posmod(s.current + 1, n), "card": rng.randi_range(0, 107)})
		if bad["ok"]:
			return "accepted out-of-turn play"
		if s.version != before:
			return "rejected action changed version"
		var acts := RuleEngine.legal_actions(s, s.current)
		if acts.is_empty():
			return "no legal action in phase %d" % s.phase
		# mostly play a card when possible so games finish in reasonable time
		var plays := acts.filter(func(x): return x["type"] == "play")
		var pool := plays if not plays.is_empty() and rng.randf() < 0.85 else acts
		var a: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		a["now_ms"] = now
		var res := RuleEngine.apply(s, a)
		if not res["ok"]:
			return "legal action rejected: %s %s" % [str(a), res["error"]]
		var integ := s.check_integrity()
		if integ != "":
			return integ
	return ""


func test_random_classic_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for g in 150:
		var n := 2 + (g % 9)
		var e := _random_game(n, RuleProfile.classic(), rng)
		if e != "":
			check(false, "game %d (%d players): %s" % [g, n, e])
			return


func test_random_points_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	prof.target_score = 300
	for g in 20:
		var e := _random_game(2 + (g % 4), prof, rng)
		if e != "":
			check(false, "game %d: %s" % [g, e])
			return


func test_random_house_rule_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var prof := RuleProfile.classic()
	prof.stack_draw_two = true
	prof.stack_draw_four = true
	prof.stack_mixed = true
	prof.seven_zero = true
	prof.auto_play_drawn = true
	for g in 120:
		var e := _random_game(2 + (g % 9), prof, rng)
		if e != "":
			check(false, "game %d: %s" % [g, e])
			return


func test_random_strict_wd4_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var prof := RuleProfile.classic()
	prof.wd4_mode = RuleProfile.Wd4Mode.STRICT
	for g in 60:
		var e := _random_game(2 + (g % 9), prof, rng)
		if e != "":
			check(false, "game %d: %s" % [g, e])
			return
