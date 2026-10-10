class_name RuleProfile
extends RefCounted
## All tunable rules for one match. Defaults reproduce the official Mattel
## basic rules (see docs/GAME_RULES.md). Anything listed in HOUSE_RULE_KEYS is
## NOT part of the classic rules and is shown to players as a house rule.

enum ScoringMode { SINGLE_ROUND, POINTS }
## How a Wild Draw Four is policed.
##  CHALLENGE (official): it may be played as a bluff; the victim can challenge.
##  STRICT: the engine refuses it while the player holds a card of the active colour.
enum Wd4Mode { CHALLENGE, STRICT }
## First discard handling. OFFICIAL applies the official per-card effects;
## NUMBER_ONLY (house) re-buries action/wild cards until a number card shows.
enum FirstCardMode { OFFICIAL, NUMBER_ONLY }

const HOUSE_RULE_KEYS := [
	"stack_draw_two", "stack_draw_four", "stack_mixed", "seven_zero",
	"auto_play_drawn", "first_card_mode",
]

var deck_id := DeckProfile.CLASSIC_108
var hand_size := 7
var min_players := 2
var max_players := 10
var scoring_mode := ScoringMode.SINGLE_ROUND
var target_score := 500
## Official: a player may draw even when holding a playable card.
var draw_when_playable := true
## Official: a drawn card that can be played may be played immediately.
var play_drawn_card := true
var wd4_mode := Wd4Mode.CHALLENGE
var uno_penalty := 2
## Authority-clock window (ms) during which a missed UNO can be caught. The
## window also closes as soon as the next player acts. 0 = no time limit.
var uno_catch_window_ms := 4000
## Per-turn time limit in seconds (0 = unlimited). Enforced by the authority.
var turn_time_s := 0

# --- house rules (all off in the classic profile) ---
var stack_draw_two := false   # +2 may be answered with +2
var stack_draw_four := false  # +4 may be answered with +4
var stack_mixed := false      # +2 on +4 and +4 on +2 (needs the respective stack rule)
var seven_zero := false       # 7 = swap hands with a chosen player, 0 = rotate hands
var auto_play_drawn := false  # a playable drawn non-wild card is played automatically
var first_card_mode := FirstCardMode.OFFICIAL


static func classic() -> RuleProfile:
	return RuleProfile.new()


func is_classic() -> bool:
	return active_house_rules().is_empty()


func active_house_rules() -> Array[String]:
	var out: Array[String] = []
	for k in HOUSE_RULE_KEYS:
		var v: Variant = get(k)
		if (v is bool and v) or (k == "first_card_mode" and v != FirstCardMode.OFFICIAL):
			out.append(k)
	return out


func challenge_enabled() -> bool:
	return wd4_mode == Wd4Mode.CHALLENGE


## Returns "" when the player count is acceptable, otherwise an error key.
func validate_player_count(n: int) -> String:
	var cap := mini(max_players, DeckProfile.max_players(deck_id))
	if n < min_players:
		return "ERR_TOO_FEW_PLAYERS"
	if n > cap:
		return "ERR_TOO_MANY_PLAYERS"
	if n * hand_size + 1 > DeckProfile.EXPECTED_COUNTS.get(deck_id, 0):
		return "ERR_DECK_TOO_SMALL"
	return ""


const _FIELDS := [
	"deck_id", "hand_size", "min_players", "max_players", "scoring_mode", "target_score",
	"draw_when_playable", "play_drawn_card", "wd4_mode", "uno_penalty", "uno_catch_window_ms",
	"turn_time_s", "stack_draw_two", "stack_draw_four", "stack_mixed", "seven_zero",
	"auto_play_drawn", "first_card_mode",
]


func to_dict() -> Dictionary:
	var d := {}
	for f in _FIELDS:
		d[f] = get(f)
	return d


## Unknown keys are ignored and values are type/range checked so a remote
## lobby cannot inject absurd settings.
static func from_dict(d: Dictionary) -> RuleProfile:
	var p := RuleProfile.new()
	for f in _FIELDS:
		if not d.has(f):
			continue
		var cur: Variant = p.get(f)
		var v: Variant = d[f]
		if cur is bool:
			p.set(f, bool(v))
		elif cur is int and (v is int or v is float):
			p.set(f, int(v))
		elif cur is String and v is String:
			p.set(f, v)
	p.hand_size = clampi(p.hand_size, 1, 10)
	p.target_score = clampi(p.target_score, 50, 5000)
	p.uno_penalty = clampi(p.uno_penalty, 1, 6)
	p.uno_catch_window_ms = clampi(p.uno_catch_window_ms, 0, 15000)
	p.turn_time_s = clampi(p.turn_time_s, 0, 120)
	p.scoring_mode = clampi(p.scoring_mode, 0, ScoringMode.size() - 1)
	p.wd4_mode = clampi(p.wd4_mode, 0, Wd4Mode.size() - 1)
	p.first_card_mode = clampi(p.first_card_mode, 0, FirstCardMode.size() - 1)
	if not DeckProfile.EXPECTED_COUNTS.has(p.deck_id):
		p.deck_id = DeckProfile.CLASSIC_108
	return p


func duplicate_profile() -> RuleProfile:
	return RuleProfile.from_dict(to_dict())
