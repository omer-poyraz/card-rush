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
	state.players[winner].score += total
	var over := state.profile.scoring_mode == RuleProfile.ScoringMode.SINGLE_ROUND \
		or state.players[winner].score >= state.profile.target_score
	return {"winner": winner, "points": total, "per_seat": per_seat, "match_over": over}
