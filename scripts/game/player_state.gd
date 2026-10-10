class_name PlayerState
extends RefCounted
## One seat at the table. `hand` holds card ids and is secret to everyone but
## the owner and the authority.

var seat_id := ""          # stable identifier (peer/session based in online games)
var display_name := ""
var avatar := 0
var is_bot := false
var bot_level := 1         # BotController.Level
var connected := true
var hand: Array[int] = []
var score := 0
## True when the player announced UNO while holding two cards on their turn.
var uno_declared := false


func to_dict() -> Dictionary:
	return {
		"seat_id": seat_id, "name": display_name, "avatar": avatar, "is_bot": is_bot,
		"bot_level": bot_level, "connected": connected, "hand": hand.duplicate(),
		"score": score, "uno_declared": uno_declared,
	}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.seat_id = str(d.get("seat_id", ""))
	p.display_name = str(d.get("name", ""))
	p.avatar = int(d.get("avatar", 0))
	p.is_bot = bool(d.get("is_bot", false))
	p.bot_level = int(d.get("bot_level", 1))
	p.connected = bool(d.get("connected", true))
	for c in d.get("hand", []):
		p.hand.append(int(c))
	p.score = int(d.get("score", 0))
	p.uno_declared = bool(d.get("uno_declared", false))
	return p
