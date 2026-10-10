class_name Progression
extends RefCounted
## Local XP / level / statistics. Offline progress is stored locally only and
## is NOT anti-cheat safe — it is never used for competitive rankings.

const HISTORY_MAX := 30


## Level n -> n+1 costs 100 + 50*(n-1) XP.
static func level_info(xp: int) -> Dictionary:
	var level := 1
	var need := 100
	var rest := xp
	while rest >= need and level < 999:
		rest -= need
		level += 1
		need = 100 + 50 * (level - 1)
	return {"level": level, "into": rest, "need": need}


static func xp_for_match(won: bool, players: int, bot_level: int, cards_played: int) -> int:
	var xp := 20 + mini(cards_played, 30)
	if won:
		xp += 30 + 6 * (players - 2) + 10 * maxi(0, bot_level)
	return xp


## Records a finished match. result: {won, players, bot_level, cards_played,
## uno_calls, catches, online, points}. Returns {xp, level_before, level_after}.
static func record_match(result: Dictionary) -> Dictionary:
	var st := Save.section("stats")
	var prof := Save.section("profile")
	var won := bool(result.get("won", false))
	st["played"] = int(st.get("played", 0)) + 1
	if won:
		st["won"] = int(st.get("won", 0)) + 1
		st["streak"] = int(st.get("streak", 0)) + 1
		st["best_streak"] = maxi(int(st.get("best_streak", 0)), int(st["streak"]))
	else:
		st["streak"] = 0
	st["cards_played"] = int(st.get("cards_played", 0)) + int(result.get("cards_played", 0))
	st["uno_calls"] = int(st.get("uno_calls", 0)) + int(result.get("uno_calls", 0))
	st["catches"] = int(st.get("catches", 0)) + int(result.get("catches", 0))
	if bool(result.get("online", false)):
		st["online_played"] = int(st.get("online_played", 0)) + 1
		if won:
			st["online_won"] = int(st.get("online_won", 0)) + 1
	else:
		var bl := str(clampi(int(result.get("bot_level", 1)), 0, 2))
		var by: Dictionary = st.get("by_level", {})
		var pair: Array = by.get(bl, [0, 0])
		pair = [int(pair[0]) + 1, int(pair[1]) + (1 if won else 0)]
		by[bl] = pair
		st["by_level"] = by
	var hist: Array = st.get("history", [])
	hist.push_front({"t": int(Time.get_unix_time_from_system()), "won": won, "players": int(result.get("players", 0)),
		"online": bool(result.get("online", false)), "points": int(result.get("points", 0))})
	while hist.size() > HISTORY_MAX:
		hist.pop_back()
	st["history"] = hist
	var before: int = level_info(int(prof.get("xp", 0)))["level"]
	var xp := xp_for_match(won, int(result.get("players", 2)), int(result.get("bot_level", 1)), int(result.get("cards_played", 0)))
	prof["xp"] = int(prof.get("xp", 0)) + xp
	var after: int = level_info(int(prof["xp"]))["level"]
	Save.mark_dirty()
	return {"xp": xp, "level_before": before, "level_after": after}


static func win_rate(st: Dictionary) -> float:
	var p := int(st.get("played", 0))
	return float(st.get("won", 0)) / p if p > 0 else 0.0
