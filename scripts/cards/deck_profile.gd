class_name DeckProfile
extends RefCounted
## Builds the card definitions for a named deck profile. Every profile has its
## own expected card count, verified by tests. Extra-card profiles must never
## be mixed into "classic_108".

const CLASSIC_108 := "classic_108"

const EXPECTED_COUNTS := {CLASSIC_108: 108}

static var _cache := {}


static func build(profile_id: String) -> Array[CardDefinition]:
	if _cache.has(profile_id):
		return _cache[profile_id]
	var out: Array[CardDefinition] = []
	match profile_id:
		CLASSIC_108:
			out = _classic_108()
		_:
			push_error("Unknown deck profile: " + profile_id)
	_cache[profile_id] = out
	return out


static func max_players(profile_id: String) -> int:
	return 10 if profile_id == CLASSIC_108 else 0


static func _classic_108() -> Array[CardDefinition]:
	var out: Array[CardDefinition] = []
	const K = CardDefinition.Kind
	for c in CardDefinition.PLAYABLE_COLORS:
		out.append(CardDefinition.new(out.size(), c, K.NUMBER, 0))
		for n in range(1, 10):
			for _i in 2:
				out.append(CardDefinition.new(out.size(), c, K.NUMBER, n))
		for k in [K.SKIP, K.REVERSE, K.DRAW_TWO]:
			for _i in 2:
				out.append(CardDefinition.new(out.size(), c, k))
	for _i in 4:
		out.append(CardDefinition.new(out.size(), CardDefinition.CardColor.WILD, K.WILD))
	for _i in 4:
		out.append(CardDefinition.new(out.size(), CardDefinition.CardColor.WILD, K.WILD_DRAW_FOUR))
	return out
