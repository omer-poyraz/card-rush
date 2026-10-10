class_name NameFilter
extends RefCounted
## Basic abuse protection for player names (local profile and names received
## from other players). Not a substitute for server-side moderation.

const MIN_LEN := 3
const MAX_LEN := 16
## Deliberately short list of common TR/EN slurs/profanity stems (lower-case).
const BLOCKED := [
	"amk", "aq", "orospu", "piç", "pic", "sik", "yarak", "göt", "got", "ibne", "pezevenk", "kahpe", "oç", "siktir",
	"fuck", "shit", "bitch", "cunt", "nigg", "fag", "whore", "slut", "dick", "pussy", "rape", "nazi", "hitler",
]


## Returns a cleaned name (may be shortened). Empty string if unusable.
static func clean(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		var code := ch.unicode_at(0)
		var ok := ch == " " or ch == "_" or ch == "-" or ch == "." or (code >= 48 and code <= 57) \
			or ch.to_lower() != ch.to_upper() or "ıİşŞğĞüÜöÖçÇ".contains(ch)
		if ok and code >= 32:
			out += ch
	while out.contains("  "):
		out = out.replace("  ", " ")
	out = out.strip_edges().substr(0, MAX_LEN)
	return out


static func is_offensive(name: String) -> bool:
	var low := name.to_lower().replace(" ", "").replace(".", "").replace("_", "").replace("-", "")
	low = low.replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a").replace("5", "s").replace("@", "a")
	for w in BLOCKED:
		if w.length() <= 3:
			# short stems only match whole words to avoid false positives
			for part in name.to_lower().split(" ", false):
				if part == w:
					return true
		elif low.contains(w):
			return true
	return false


## "" when acceptable, otherwise an error key.
static func validate(name: String) -> String:
	var c := clean(name)
	if c.length() < MIN_LEN:
		return "ERR_NAME_SHORT"
	if is_offensive(c):
		return "ERR_NAME_BLOCKED"
	return ""


## For names coming from the network: always returns something displayable.
static func sanitize_remote(name: String, fallback: String) -> String:
	var c := clean(name)
	if c.length() < MIN_LEN or is_offensive(c):
		return fallback
	return c
