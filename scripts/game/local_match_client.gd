class_name LocalMatchClient
extends MatchClient
## Offline client: the authority runs in-process. Still goes through the
## exact same submit/validate/publish path as online play.

var authority: MatchAuthority
var pausable := true


func attach(auth: MatchAuthority, my_seat: int) -> void:
	authority = auth
	seat = my_seat
	authority.published.connect(_on_published)


func _on_published(s: int, view: Dictionary, events: Array) -> void:
	if s == seat:
		_deliver(view, events)


func send(action: Dictionary) -> void:
	var r := authority.submit(seat, action)
	if not r["ok"]:
		action_rejected.emit(r["error"])


func can_pause() -> bool:
	return pausable


func set_paused(p: bool) -> void:
	authority.paused = p


func request_next_round() -> void:
	authority.start_next_round()


func leave() -> void:
	if authority and authority.published.is_connected(_on_published):
		authority.published.disconnect(_on_published)
