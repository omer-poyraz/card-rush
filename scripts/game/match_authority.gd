class_name MatchAuthority
extends Node
## Game controller with authority over one match (offline, or the room host
## online). It owns the only full GameState, validates every action through
## RuleEngine, drives bots and timers with its own clock, and publishes a
## redacted view + events to each seat. Clients (local UI, remote peers) only
## ever send action requests.

signal published(seat: int, view: Dictionary, events: Array)
signal match_finished(winner: int)
signal round_finished(winner: int)

enum SeatKind { LOCAL, BOT, REMOTE }

const ROUND_BREAK_S := 6.0
## Bots hold back at least this long when someone can be caught, so humans get a fair chance.
const HUMAN_CATCH_GRACE_S := 1.6

var state: GameState
var seat_kinds: Array[int] = []
var bots := {}                 # seat -> BotController (permanent bots and takeovers)
var takeover := {}             # seat -> true while a bot plays for a disconnected human
var bot_takeover_enabled := true
## Seconds a disconnected player's seat is held before the policy applies.
var disconnect_grace_s := 20.0
## After the grace period: a temporary bot plays the seat (true) or the seat
## only takes automatic timeout moves (draw/pass/accept) (false).
var _dc_since := {}            # seat -> msec when it disconnected
var time_scale := 1.0          # tests use small values
var bot_think_scale := 1.0     # "bot speed" setting
var paused := false:
	set(v):
		if v == paused:
			return
		paused = v
		if v:
			_paused_at = now_ms()
		else:
			# shift every timer by the paused duration
			var d := now_ms() - _paused_at
			for j in _jobs:
				j["at"] += d
			if _turn_deadline_ms > 0:
				_turn_deadline_ms += d
			_hold_until_ms += d
var _paused_at := 0
var auto_next_round := true

var _jobs: Array = []          # {at: msec, fn: Callable, key: String}
var _turn_deadline_ms := 0
var _hold_until_ms := 0
var _log_actions := false


func setup(profile: RuleProfile, players: Array[PlayerState], kinds: Array[int], dealer := -1) -> String:
	state = GameState.new(profile)
	seat_kinds = kinds
	bots.clear()
	for i in players.size():
		if kinds[i] == SeatKind.BOT:
			players[i].is_bot = true
			bots[i] = BotController.new(players[i].bot_level, i)
	return RuleEngine.setup_match(state, players, dealer)


func start() -> void:
	_hold_for_deal()
	var ev := RuleEngine.start_round(state)
	_publish(ev)


## Gives clients time to play the deal animation before the first bot move.
func _hold_for_deal() -> void:
	var n := state.players.size() * state.profile.hand_size
	_hold_until_ms = now_ms() + int((1200 + n * 40) * time_scale)


func now_ms() -> int:
	return Time.get_ticks_msec()


# --- incoming actions ----------------------------------------------------------------

## Single entry point for every action. `seat` is who sent it — the action's
## "player" field is overwritten so nobody can act for somebody else.
func submit(seat: int, action: Dictionary) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "ERR_NO_MATCH", "events": []}
	var a := action.duplicate()
	a["player"] = seat
	a["now_ms"] = now_ms()
	var r := RuleEngine.apply(state, a)
	if r["ok"]:
		if _log_actions:
			print("[authority] ", seat, " ", a)
		_publish(r["events"])
	return r


func set_connected(seat: int, connected: bool) -> void:
	if seat < 0 or seat >= state.players.size() or state.players[seat].connected == connected:
		return
	state.players[seat].connected = connected
	if connected:
		_dc_since.erase(seat)
		_cancel("dc_%d" % seat)
		if takeover.has(seat):
			bots.erase(seat)
			takeover.erase(seat)
	else:
		_dc_since[seat] = now_ms()
		if disconnect_grace_s <= 0.0:
			_grace_expired(seat)
	state.version += 1
	_publish([{"t": "connection", "p": seat, "connected": connected}])


func _grace_expired(seat: int) -> void:
	if state.players[seat].connected or bots.has(seat):
		return
	if bot_takeover_enabled:
		var b := BotController.new(BotController.Level.NORMAL, seat)
		bots[seat] = b
		takeover[seat] = true
	if state.phase < GameState.Phase.ROUND_OVER:
		_schedule()


func is_disconnected_waiting(seat: int) -> bool:
	return _dc_since.has(seat) and not bots.has(seat)


func start_next_round() -> void:
	if state.phase != GameState.Phase.ROUND_OVER:
		return
	_cancel("next_round")
	_hold_for_deal()
	var ev := RuleEngine.start_round(state)
	_publish(ev)


func is_bot_seat(seat: int) -> bool:
	return bots.has(seat)


# --- publishing ---------------------------------------------------------------------

func _publish(events: Array) -> void:
	_schedule()  # first, so the published views carry the fresh turn deadline
	var left := turn_time_left_ms()
	for i in state.players.size():
		var red := RuleEngine.redact_events(events, i)
		if bots.has(i):
			bots[i].observe(red)
		published.emit(i, _view(i, left), red)
	published.emit(-1, _view(-1, left), RuleEngine.redact_events(events, -1))
	for e in events:
		if e["t"] == "round_end":
			round_finished.emit(int(e["winner"]))
		elif e["t"] == "match_end":
			match_finished.emit(int(e["winner"]))


func _view(seat: int, turn_left: int) -> Dictionary:
	var v := state.view_for(seat)
	v["turn_ms_left"] = turn_left
	v["turn_ms_total"] = state.profile.turn_time_s * 1000
	v["takeover"] = takeover.keys()
	return v


## Fresh view for a (re)connecting seat.
func view_for(seat: int) -> Dictionary:
	return _view(seat, turn_time_left_ms())


# --- scheduling ---------------------------------------------------------------------

func _process(_dt: float) -> void:
	if paused or _jobs.is_empty():
		return
	var t := now_ms()
	var due := _jobs.filter(func(j): return j["at"] <= t)
	if due.is_empty():
		return
	_jobs = _jobs.filter(func(j): return j["at"] > t)
	for j in due:
		j["fn"].call()


func _after(seconds: float, key: String, fn: Callable) -> void:
	_cancel(key)
	_jobs.append({"at": now_ms() + int(seconds * 1000.0 * time_scale), "fn": fn, "key": key})


func _cancel(key: String) -> void:
	_jobs = _jobs.filter(func(j): return j["key"] != key)


func _has_humans() -> bool:
	for i in state.players.size():
		if not bots.has(i):
			return true
	return false


func _schedule() -> void:
	var ph := state.phase
	if ph == GameState.Phase.MATCH_OVER:
		_jobs.clear()
		return
	if ph == GameState.Phase.ROUND_OVER:
		_jobs.clear()
		if auto_next_round:
			_after(ROUND_BREAK_S, "next_round", start_next_round)
		return
	var serial := state.turn_serial
	var version := state.version
	# missed-UNO window: bots may catch, and the window expires on the authority clock
	if state.uno_vulnerable >= 0:
		var target := state.uno_vulnerable
		for seat in bots:
			if seat == target:
				continue
			var d: float = bots[seat].catch_delay()
			if d >= 0.0:
				_after(d, "catch_%d" % seat, func(): _bot_catch(seat, target, serial))
		if state.profile.uno_catch_window_ms > 0:
			_after(state.profile.uno_catch_window_ms / 1000.0 + 0.05, "uno_expire", _expire_uno)
	# current player's turn
	var cur := state.current
	if bots.has(cur):
		var delay: float = bots[cur].think_time() * bot_think_scale
		if takeover.has(cur):
			delay += 1.0
		if state.uno_vulnerable >= 0 and _has_humans():
			delay = maxf(delay, HUMAN_CATCH_GRACE_S)
		delay = maxf(delay, (_hold_until_ms - now_ms()) / 1000.0 / maxf(time_scale, 0.001))
		_after(delay, "bot_turn", func(): _bot_turn(cur, version))
		_turn_deadline_ms = 0
	elif is_disconnected_waiting(cur):
		# hold the seat for the grace period, then apply the policy
		_cancel("bot_turn")
		var left := disconnect_grace_s - (now_ms() - int(_dc_since[cur])) / 1000.0
		if bot_takeover_enabled:
			_after(maxf(left, 0.0), "dc_%d" % cur, func(): _grace_expired(cur))
		else:
			_after(maxf(left, 0.0), "dc_%d" % cur, func():
				_timeout(cur, serial))
	else:
		_cancel("bot_turn")
		_arm_turn_timer(cur, serial)


func _arm_turn_timer(seat: int, serial: int) -> void:
	var limit := state.profile.turn_time_s
	if limit <= 0:
		_turn_deadline_ms = 0
		_cancel("turn_timeout")
		return
	# keep the existing deadline when the same turn continues (e.g. after drawing)
	if _jobs.any(func(j): return j["key"] == "turn_timeout") and _turn_serial_armed == serial:
		return
	_turn_serial_armed = serial
	var hold := maxi(0, _hold_until_ms - now_ms())
	_turn_deadline_ms = now_ms() + hold + limit * 1000
	_after(limit + hold / 1000.0, "turn_timeout", func(): _timeout(seat, serial))


var _turn_serial_armed := -1


func turn_time_left_ms() -> int:
	return maxi(0, _turn_deadline_ms - now_ms()) if _turn_deadline_ms > 0 else -1


func _expire_uno() -> void:
	if RuleEngine.expire_uno_window(state, now_ms()):
		_publish([{"t": "uno_window_closed"}])


func _bot_catch(seat: int, target: int, serial: int) -> void:
	if state.uno_vulnerable == target and state.turn_serial == serial and bots.has(seat):
		submit(seat, {"type": "catch", "target": target})


func _bot_turn(seat: int, version: int) -> void:
	if state.version != version or state.current != seat or not bots.has(seat):
		return
	for a in bot_actions(seat):
		var r := submit(seat, a)
		if not r["ok"]:
			push_warning("bot action rejected %s %s" % [str(a), r["error"]])
			# never stall: fall back to the simplest legal action
			var legal := RuleEngine.legal_actions(state, seat)
			if not legal.is_empty():
				submit(seat, legal.back())
			return


## The action(s) a bot takes for its turn (an UNO call may precede a play).
func bot_actions(seat: int) -> Array[Dictionary]:
	var bot: BotController = bots[seat]
	var view := state.view_for(seat)
	var a := bot.choose_action(view)
	var out: Array[Dictionary] = []
	if a["type"] == "play" and view["hand"].size() == 2 and bot.will_call_uno():
		out.append({"type": "uno"})
	out.append(a)
	return out


## Turn timer ran out for a human: take the least harmful automatic action.
func _timeout(seat: int, serial: int) -> void:
	if state.turn_serial != serial or state.current != seat:
		return
	var a := {}
	match state.phase:
		GameState.Phase.CHOOSE_COLOR:
			a = {"type": "choose_color", "color": BotController.new(BotController.Level.NORMAL, seat).choose_color(state.view_for(seat))}
		GameState.Phase.CHALLENGE_DECISION:
			a = {"type": "accept"}
		GameState.Phase.DRAWN_DECISION:
			a = {"type": "pass"}
		_:
			a = {"type": "accept"} if state.pending_draw > 0 else {"type": "draw"}
	var r := submit(seat, a)
	if r["ok"] and state.phase == GameState.Phase.DRAWN_DECISION and state.current == seat:
		submit(seat, {"type": "pass"})
