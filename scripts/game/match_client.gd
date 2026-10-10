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


## Updates that arrive before the table UI is bound (scene change in progress)
## are buffered so no event (e.g. the deal) is lost.
var _pending: Array = []
var _bound := false


func _deliver(view: Dictionary, events: Array) -> void:
	last_view = view
	if _bound:
		updated.emit(view, events)
	else:
		_pending.append([view, events])


func flush() -> void:
	_bound = true
	var items := _pending
	_pending = []
	for it in items:
		updated.emit(it[0], it[1])


func unbind() -> void:
	_bound = false
