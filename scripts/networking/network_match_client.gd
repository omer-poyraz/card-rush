class_name NetworkMatchClient
extends MatchClient
## Remote player's match client: forwards action requests to the room host
## and receives this seat's redacted views/events.

var room: RoomClient


func _init() -> void:
	online = true
	is_host = false


func send(action: Dictionary) -> void:
	if room:
		room.send_action(action)


func leave() -> void:
	if room:
		room.leave()
