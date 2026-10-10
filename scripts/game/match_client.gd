class_name MatchClient
extends Node
## What the table UI talks to. It receives redacted views + events for ONE
## seat and sends action requests. Offline it wraps a local MatchAuthority;
## online (NetworkMatchClient) it forwards over the network to the host.

signal updated(view: Dictionary, events: Array)
signal action_rejected(error: String)
signal connection_changed(state: String, detail: String)

var seat := 0
var last_view := {}
var is_host := true
var online := false


func send(_action: Dictionary) -> void:
	push_error("MatchClient.send not implemented")


## Leaves the match (closes connections, stops the local authority...).
func leave() -> void:
	pass


func can_pause() -> bool:
	return false


func set_paused(_p: bool) -> void:
	pass


func request_next_round() -> void:
	pass


func _deliver(view: Dictionary, events: Array) -> void:
	last_view = view
	updated.emit(view, events)
