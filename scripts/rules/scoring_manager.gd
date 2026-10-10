class_name ScoringManager
extends RefCounted
## Official scoring: the round winner earns the value of every card left in
## the other players' hands (numbers = face value, Skip/Reverse/+2 = 20,
## Wild/Wild +4 = 50). POINTS mode ends the match at `target_score`.


static func hand_points(state: GameState, seat: int) -> int:
	var t := 0
	for c in state.players[seat].hand:
		t += state.card(c).points()
	return t


## Applies round scoring and returns {winner, points, per_seat, match_over}.
static func score_round(state: GameState, winner: int) -> Dictionary:
	var per_seat := {}
	var total := 0
	for i in state.players.size():
		var hp := hand_points(state, i)
		per_seat[i] = hp
		if i != winner:
			total += hp
	var mode := state.profile.scoring_mode
	var match_winner := winner
	var over := false
	if mode == RuleProfile.ScoringMode.LOW_TALLY:
		var top := 0
		for i in state.players.size():
			state.players[i].score += per_seat[i]
			top = maxi(top, state.players[i].score)
		over = top >= state.profile.target_score
		if over:
			# lowest running total wins; ties go to the player who went out this round
			for i in state.players.size():
				if state.players[i].score < state.players[match_winner].score:
					match_winner = i
	else:
		state.players[winner].score += total
		over = mode == RuleProfile.ScoringMode.SINGLE_ROUND or state.players[winner].score >= state.profile.target_score
	return {"winner": winner, "points": total, "per_seat": per_seat, "match_over": over, "match_winner": match_winner}
