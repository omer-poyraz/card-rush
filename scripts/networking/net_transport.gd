class_name NetTransport
extends Node
## Message transport between the room host (peer id 1) and clients. The room
## logic only uses this interface, so ENet, WebRTC or the in-memory test
## transport are interchangeable.

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal message(from_id: int, msg: Dictionary)
signal connected_to_host
signal connection_failed
signal host_lost

const HOST_ID := 1

var is_server := false
var last_error := ""         # error key of the last failure (for the UI)


func send(_to_id: int, _msg: Dictionary, _reliable := true) -> void:
	pass


func disconnect_peer(_id: int) -> void:
	pass


func close() -> void:
	pass


## Remote address of a peer (host side) — used to tell clients where a
## migrated lobby can be found. "" if unknown.
func peer_address(_id: int) -> String:
	return ""
