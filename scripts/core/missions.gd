class_name Missions
extends RefCounted
## Daily / weekly missions and the daily login reward. Rewards are coins
## (cosmetic only). Claims use unique ledger keys, so nothing is paid twice.
## Local and offline: not anti-cheat safe, never used for rankings.

const DAILY_POOL := [
	{"id": "d_play3", "stat": "matches", "goal": 3, "coins": 40},
	{"id": "d_win1", "stat": "wins", "goal": 1, "coins": 40},
	{"id": "d_cards30", "stat": "cards", "goal": 30, "coins": 30},
	{"id": "d_actions8", "stat": "actions", "goal": 8, "coins": 30},
	{"id": "d_uno2", "stat": "uno_calls", "goal": 2, "coins": 30},
	{"id": "d_catch1", "stat": "catches", "goal": 1, "coins": 40},
	{"id": "d_hard1", "stat": "hard_wins", "goal": 1, "coins": 60},
]
const WEEKLY_POOL := [
	{"id": "w_play15", "stat": "matches", "goal": 15, "coins": 150},
	{"id": "w_win6", "stat": "wins", "goal": 6, "coins": 200},
	{"id": "w_cards200", "stat": "cards", "goal": 200, "coins": 150},
	{"id": "w_online3", "stat": "online", "goal": 3, "coins": 200},
	{"id": "w_points1", "stat": "points_wins", "goal": 1, "coins": 150},
]
const LOGIN_REWARDS := [20, 30, 40, 50, 60, 80, 120]
const DAILY_COUNT := 3
const WEEKLY_COUNT := 3


static func today() -> String:
	return Time.get_date_string_from_system()


static func this_week() -> String:
	var days := int(Time.get_unix_time_from_system() / 86400.0)
	return "w%d" % int((days + 3) / 7)


static func _pick(pool: Array, n: int, seed_text: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var copy := pool.duplicate(true)
	var out := []
	while out.size() < n and not copy.is_empty():
		var m: Dictionary = copy.pop_at(rng.randi_range(0, copy.size() - 1))
		m["progress"] = 0
		m["claimed"] = false
		out.append(m)
	return out


## Rolls over to new missions when the day/week changed. Returns the state.
static func state() -> Dictionary:
	var s := Save.section("missions")
	var d := today()
	if str(s.get("day", "")) != d:
		s["day"] = d
		s["daily"] = _pick(DAILY_POOL, DAILY_COUNT, "daily:" + d)
		Save.mark_dirty()
	var w := this_week()
	if str(s.get("week", "")) != w:
		s["week"] = w
		s["weekly"] = _pick(WEEKLY_POOL, WEEKLY_COUNT, "weekly:" + w)
		Save.mark_dirty()
	return s


## Feeds a finished match into mission progress.
## r: {won, cards_played, actions, uno_calls, catches, online, bot_level, points_mode}
static func on_match(r: Dictionary) -> void:
	var s := state()
	var inc := {
		"matches": 1, "wins": 1 if r.get("won", false) else 0, "cards": int(r.get("cards_played", 0)),
		"actions": int(r.get("actions", 0)), "uno_calls": int(r.get("uno_calls", 0)),
		"catches": int(r.get("catches", 0)), "online": 1 if r.get("online", false) else 0,
		"hard_wins": 1 if r.get("won", false) and int(r.get("bot_level", 0)) >= 2 and not r.get("online", false) else 0,
		"points_wins": 1 if r.get("won", false) and r.get("points_mode", false) else 0,
	}
	for list_key in ["daily", "weekly"]:
		for m in s.get(list_key, []):
			if not m["claimed"]:
				m["progress"] = mini(int(m["goal"]), int(m["progress"]) + int(inc.get(m["stat"], 0)))
	Save.mark_dirty()


static func claimable_count() -> int:
	var s := state()
	var n := 0
	for list_key in ["daily", "weekly"]:
		for m in s.get(list_key, []):
			if not m["claimed"] and int(m["progress"]) >= int(m["goal"]):
				n += 1
	if login_status()["can_claim"]:
		n += 1
	return n


## Returns the coins paid, or 0 if not claimable / already claimed.
static func claim(mission_id: String) -> int:
	var s := state()
	for list_key in ["daily", "weekly"]:
		var period: String = s["day"] if list_key == "daily" else s["week"]
		for m in s.get(list_key, []):
			if m["id"] != mission_id or m["claimed"] or int(m["progress"]) < int(m["goal"]):
				continue
			if Economy.grant(int(m["coins"]), "mission:" + mission_id, "m:%s:%s" % [period, mission_id]):
				m["claimed"] = true
				Save.section("profile")["xp"] = int(Save.section("profile").get("xp", 0)) + 15
				Save.mark_dirty()
				return int(m["coins"])
	return 0


# --- daily login ---------------------------------------------------------------------

static func login_status() -> Dictionary:
	var l: Dictionary = Save.section("missions").get("login", {})
	var last := str(l.get("last", ""))
	var streak := int(l.get("streak", 0))
	var d := today()
	if last == d:
		return {"can_claim": false, "streak": streak, "next_reward": LOGIN_REWARDS[mini(streak, LOGIN_REWARDS.size() - 1)]}
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var next_streak := streak + 1 if last == yesterday else 1
	return {"can_claim": true, "streak": next_streak, "reward": LOGIN_REWARDS[mini(next_streak - 1, LOGIN_REWARDS.size() - 1)]}


static func claim_login() -> int:
	var st := login_status()
	if not st["can_claim"]:
		return 0
	var d := today()
	if not Economy.grant(int(st["reward"]), "daily_login", "login:" + d):
		return 0
	var s := Save.section("missions")
	s["login"] = {"last": d, "streak": int(st["streak"])}
	Save.mark_dirty()
	return int(st["reward"])
