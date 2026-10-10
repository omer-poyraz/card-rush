class_name NetProtocol
extends RefCounted
## Wire protocol constants and strict validation of untrusted messages.
## Messages are Dictionaries encoded with var_to_bytes (never *_with_objects,
## so a peer cannot inject objects/scripts). Every field read from a remote
## message goes through these sanitisers.

const VERSION := 1
const GAME_PORT := 47810
const DISCOVERY_PORT := 47811
const MAX_PACKET := 64 * 1024          # host -> client (views can be a few KB)
const MAX_CLIENT_PACKET := 4 * 1024    # client -> host
const MAX_PLAYERS := 10

# client -> host
const C_HELLO := "hello"
const C_READY := "ready"
const C_ACT := "act"
const C_PING := "ping"
const C_LEAVE := "leave"
# host -> client
const S_WELCOME := "welcome"
const S_REJECT := "reject"
const S_LOBBY := "lobby"
const S_START := "start"
const S_UPDATE := "update"
const S_REJECTED := "rejected"
const S_PONG := "pong"
const S_CLOSED := "closed"
const S_KICKED := "kicked"

const ACTION_TYPES := ["play", "draw", "pass", "accept", "challenge", "choose_color", "uno", "catch"]


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## Returns {} when the packet is not a well-formed message.
static func decode(bytes: PackedByteArray, max_size: int) -> Dictionary:
	if bytes.size() == 0 or bytes.size() > max_size:
		return {}
	var v: Variant = bytes_to_var(bytes)
	if not v is Dictionary or not (v as Dictionary).has("k") or not (v as Dictionary)["k"] is String:
		return {}
	return v


static func int_field(d: Dictionary, key: String, default := -1, lo := -2147483648, hi := 2147483647) -> int:
	var v: Variant = d.get(key, default)
	if not (v is int or v is float):
		return default
	return clampi(int(v), lo, hi)


static func str_field(d: Dictionary, key: String, max_len := 64) -> String:
	var v: Variant = d.get(key, "")
	return (v as String).substr(0, max_len) if v is String else ""


## Rebuilds a client action from scratch: only known keys with sane values.
static func clean_action(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var a := raw as Dictionary
	var t := str_field(a, "type", 16)
	if not ACTION_TYPES.has(t):
		return {}
	var out := {"type": t}
	if a.has("card"):
		out["card"] = int_field(a, "card", -1, -1, 511)
	if a.has("color"):
		out["color"] = int_field(a, "color", -1, -1, 4)
	if a.has("target"):
		out["target"] = int_field(a, "target", -1, -1, MAX_PLAYERS)
	return out
