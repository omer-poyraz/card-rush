class_name BotController
extends RefCounted
## Decision making for one bot seat. A bot only ever sees the same redacted
## view a human client gets (GameState.view_for) plus the public event stream —
## it never reads hidden hands. Every decision it returns is an ordinary action
## that the RuleEngine validates like any other.

enum Level { EASY, NORMAL, HARD }

const Kind = CardDefinition.Kind
const Phase = GameState.Phase
const COLORS := CardDefinition.PLAYABLE_COLORS

## [min, max] thinking time in seconds per level.
const THINK := [[0.9, 1.6], [0.75, 1.35], [0.65, 1.15]]
## Chance of forgetting to announce UNO.
const FORGET_UNO := [0.3, 0.1, 0.0]
## Chance to notice a missed UNO and its reaction time range.
const CATCH_CHANCE := [0.3, 0.6, 0.92]
const CATCH_DELAY := [[1.8, 3.2], [1.1, 2.2], [0.5, 1.3]]

var level := Level.NORMAL
var seat := -1
var rng := RandomNumberGenerator.new()
var cards: Array[CardDefinition] = DeckProfile.build(DeckProfile.CLASSIC_108)

# --- public-information memory ---
var lacks := {}            # seat -> {color: true} inferred from draws
var seen_color := [0, 0, 0, 0]   # colour cards seen on the discard this round
var _color := -1           # running active colour while replaying events
var _color_before_wd4 := -1  # active colour when the last +4 was played
var _profile_cache := {}
var _profile: RuleProfile


func _init(p_level := Level.NORMAL, p_seat := -1) -> void:
	level = p_level
	seat = p_seat
	rng.randomize()


func think_time() -> float:
	var r: Array = THINK[level]
	return rng.randf_range(r[0], r[1])


# --- memory ------------------------------------------------------------------

func observe(events: Array) -> void:
	for e in events:
		match e["t"]:
			"deal":
				lacks.clear()
				seen_color = [0, 0, 0, 0]
			"first_card":
				var d := cards[int(e["card"])]
				_color = d.color
				_count_seen(d)
			"play":
				var d := cards[int(e["card"])]
				_count_seen(d)
				var who := int(e["p"])
				if not d.is_wild() and lacks.has(who):
					lacks[who].erase(d.color)
				if d.kind == Kind.WILD_DRAW_FOUR:
					_color_before_wd4 = _color
				_color = int(e["color"])
			"color":
				_color = int(e["color"])
			"draw":
				var who := int(e["p"])
				if who == seat:
					continue
				if e.get("reason", "") == "normal" and _color in COLORS:
					if not lacks.has(who):
						lacks[who] = {}
					lacks[who][_color] = true
				elif int(e.get("n", 0)) >= 2:
					lacks.erase(who)  # several fresh random cards: forget
			"swap", "rotate":
				lacks.clear()


func _count_seen(d: CardDefinition) -> void:
	if d.color in COLORS:
		seen_color[d.color] += 1


# --- decisions -------------------------------------------------------------------

func profile_of(view: Dictionary) -> RuleProfile:
	var rules: Dictionary = view.get("rules", {})
	if _profile == null or rules != _profile_cache:
		_profile_cache = rules
		_profile = RuleProfile.from_dict(rules)
	return _profile


func playable(view: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var prof := profile_of(view)
	for c in view["hand"]:
		if RuleEngine.is_playable(prof, cards, view["hand"], int(c), int(view["top"]), int(view["color"]),
				int(view["pending_draw"]), int(view["phase"]), int(view["drawn_card"])):
			out.append(int(c))
	return out


## Whether the bot announces UNO before playing its second-to-last card.
func will_call_uno() -> bool:
	return rng.randf() >= FORGET_UNO[level]


## Seconds until the bot tries to catch a player who missed UNO, or -1.
func catch_delay() -> float:
	if rng.randf() >= CATCH_CHANCE[level]:
		return -1.0
	var r: Array = CATCH_DELAY[level]
	return rng.randf_range(r[0], r[1])


## The turn action for the current view (the bot must be the current player).
func choose_action(view: Dictionary) -> Dictionary:
	var phase := int(view["phase"])
	var me := int(view["me"])
	if phase == Phase.CHOOSE_COLOR:
		return {"type": "choose_color", "player": me, "color": choose_color(view)}
	var options := playable(view)
	if phase == Phase.CHALLENGE_DECISION:
		if not options.is_empty() and (level != Level.EASY or rng.randf() < 0.7):
			return _play_action(view, _pick(view, options))
		if bool(view["challengeable"]) and _should_challenge(view):
			return {"type": "challenge", "player": me}
		return {"type": "accept", "player": me}
	if int(view["pending_draw"]) > 0:
		if not options.is_empty() and (level != Level.EASY or rng.randf() < 0.7):
			return _play_action(view, _pick(view, options))
		return {"type": "accept", "player": me}
	if phase == Phase.DRAWN_DECISION:
		if not options.is_empty():
			# Normal/Hard keep a drawn wild if they can afford to; Easy always plays.
			var c := cards[options[0]]
			if level != Level.EASY and c.is_wild() and _danger(view) == 0 and view["hand"].size() > 3:
				return {"type": "pass", "player": me}
			return _play_action(view, options[0])
		return {"type": "pass", "player": me}
	if options.is_empty():
		return {"type": "draw", "player": me}
	return _play_action(view, _pick(view, options))


func _play_action(view: Dictionary, cid: int) -> Dictionary:
	var me := int(view["me"])
	var a := {"type": "play", "player": me, "card": cid}
	var d := cards[cid]
	if d.is_wild():
		var hand: Array = view["hand"].duplicate()
		hand.erase(cid)
		a["color"] = choose_color(view, hand)
	var prof := profile_of(view)
	if prof.seven_zero and d.kind == Kind.NUMBER and d.number == 7 and view["hand"].size() > 1:
		a["target"] = _swap_target(view)
	return a


func _pick(view: Dictionary, options: Array[int]) -> int:
	if level == Level.EASY:
		# mostly random, but keeps wilds for later 60% of the time
		var plain := options.filter(func(c): return not cards[c].is_wild())
		if not plain.is_empty() and rng.randf() < 0.6:
			return plain[rng.randi_range(0, plain.size() - 1)]
		return options[rng.randi_range(0, options.size() - 1)]
	var best := options[0]
	var best_score := -INF
	var scores := {}
	for c in options:
		var sc := _score(view, c)
		scores[c] = sc
		if sc > best_score:
			best_score = sc
			best = c
	if level == Level.HARD:
		# softmax sampling: mostly the best move, occasionally a close alternative
		var total := 0.0
		var weights := {}
		for c in options:
			var w := exp((float(scores[c]) - best_score) / 1.5)
			weights[c] = w
			total += w
		var r := rng.randf() * total
		for c in options:
			r -= weights[c]
			if r <= 0.0:
				return c
	return best


## Heuristic value of playing card `cid` now.
func _score(view: Dictionary, cid: int) -> float:
	var d := cards[cid]
	var hand: Array = view["hand"]
	var counts := _color_counts(hand)
	var danger := _danger(view)            # 0 = relaxed .. 3 = next player about to win
	var next_count := _next_count(view)
	var s := 0.0
	# keep options open: play from the colour we hold most of
	if d.color in COLORS:
		s += counts[d.color] * 1.2
		s += d.points() * 0.04             # shed points
	match d.kind:
		Kind.WILD:
			s -= 6.0 - danger * 1.5
		Kind.WILD_DRAW_FOUR:
			s -= 7.0 - danger * 2.5
			# never bluff
			if not RuleEngine.wd4_legal(cards, hand, int(view["color"])):
				s -= 100.0
		Kind.SKIP, Kind.REVERSE:
			s += danger * 2.5
		Kind.DRAW_TWO:
			s += danger * 3.0 + (1.0 if next_count <= 3 else 0.0)
	if level == Level.HARD:
		# when an opponent is close to winning, dump high-value cards
		if _min_opponent_count(view) <= 2:
			s += d.points() * 0.08
		# colour changes towards a colour the next player seems to lack
		var nxt := _next_seat(view)
		if d.color in COLORS and lacks.has(nxt) and lacks[nxt].has(d.color):
			s += 3.0
		# keep the last card a playable one: avoid ending with a lone wild-less colour
		if hand.size() == 2:
			var other: int = hand[0] if hand[1] == cid else hand[1]
			if cards[other].is_wild():
				s += 2.0
	return s


func choose_color(view: Dictionary, hand: Array = []) -> int:
	if hand.is_empty():
		hand = view["hand"]
	var counts := _color_counts(hand)
	if level == Level.EASY and rng.randf() < 0.35:
		return COLORS[rng.randi_range(0, 3)]
	var best: int = COLORS[rng.randi_range(0, 3)]
	var best_v := -INF
	for c in COLORS:
		var v := float(counts[c]) * 3.0
		for id in hand:
			if cards[id].color == c:
				v += cards[id].points() * 0.05
		if level == Level.HARD:
			var nxt := _next_seat(view)
			if lacks.has(nxt) and lacks[nxt].has(c):
				v += 2.5
			v -= seen_color[c] * 0.05  # many seen = fewer left for others? (weak)
		v += rng.randf() * 0.5
		if v > best_v:
			best_v = v
			best = c
	return best


func _should_challenge(view: Dictionary) -> bool:
	if level == Level.EASY:
		return rng.randf() < 0.1
	var off := int(view["challenge_offender"])
	var n := int(view["players"][off]["count"])
	# P(guilty) ~ P(at least one card of the previous colour among n cards)
	var p := 1.0 - pow(0.77, n)
	if level == Level.HARD:
		var prev := _color_before_wd4
		if prev >= 0 and lacks.has(off) and lacks[off].has(prev):
			p *= 0.25
	else:
		p += rng.randf_range(-0.15, 0.15)
	# Challenge when expected cards drawn is lower: 6*(1-p) < 4  =>  p > 1/3
	return p > 0.34 + (0.08 if level == Level.NORMAL else 0.0)


func _swap_target(view: Dictionary) -> int:
	var me := int(view["me"])
	var best := -1
	var best_n := 999
	for i in view["players"].size():
		if i == me:
			continue
		var n := int(view["players"][i]["count"])
		if level == Level.EASY:
			n = rng.randi_range(0, 20)
		if n < best_n:
			best_n = n
			best = i
	return best


# --- helpers ----------------------------------------------------------------------

func _color_counts(hand: Array) -> Array:
	var c := [0, 0, 0, 0]
	for id in hand:
		var col := cards[int(id)].color
		if col in COLORS:
			c[col] += 1
	return c


func _next_seat(view: Dictionary) -> int:
	return posmod(int(view["me"]) + int(view["direction"]), view["players"].size())


func _next_count(view: Dictionary) -> int:
	return int(view["players"][_next_seat(view)]["count"])


func _min_opponent_count(view: Dictionary) -> int:
	var m := 999
	for i in view["players"].size():
		if i != int(view["me"]):
			m = mini(m, int(view["players"][i]["count"]))
	return m


func _danger(view: Dictionary) -> int:
	var n := _next_count(view)
	if n <= 1:
		return 3
	if n == 2:
		return 2
	if n <= 4:
		return 1
	return 0
