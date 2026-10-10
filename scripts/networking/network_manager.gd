extends Node
## Autoload "Net". Owns the current room (as host or client) and LAN
## discovery across scene changes. Connection methods are adapters:
##   - ENet (LAN / direct IP)            — ENetAdapter          (Stage 5)
##   - WebRTC + signaling (internet)     — planned adapter      (Stage 6)
## The room logic never depends on which adapter is used.

signal room_changed

enum Mode { NONE, HOST, CLIENT }

var mode := Mode.NONE
var host: RoomHost
var client: RoomClient
var discovery: LanDiscovery
var host_port := NetProtocol.GAME_PORT


func _ready() -> void:
	discovery = LanDiscovery.new()
	add_child(discovery)


func is_active() -> bool:
	return mode != Mode.NONE


## Creates a LAN/direct room. Returns "" or an error key.
func create_room(settings: Dictionary, fixed_code := "") -> String:
	leave_room()
	var r := ENetAdapter.host(host_port)
	if not r["ok"]:
		return r["error"]
	return _start_host(r["transport"], settings, fixed_code)


func _start_host(t: NetTransport, settings: Dictionary, fixed_code := "") -> String:
	var prof := Save.section("profile")
	host = RoomHost.new()
	add_child(host)
	host.start(t, settings, str(prof.get("name", "Host")), int(prof.get("avatar", 0)), fixed_code)
	host.lobby_changed.connect(_refresh_ad)
	host.lobby_changed.connect(func():
		if host:
			Voice.set_room_enabled(bool(host.settings.get("voice", false)))
			Voice.update_roster(host.roster()))
	host.room_closed.connect(func(_r): _clear())
	Voice.attach(VoiceConnection.for_host(host), bool(settings.get("voice", false)))
	Voice.update_roster(host.roster())
	mode = Mode.HOST
	discovery.advertise(host.discovery_info(host_port))
	room_changed.emit()
	return ""


func _refresh_ad() -> void:
	if host:
		discovery.update_ad(host.discovery_info(host_port))


func join_room(address: String, port: int, code: String) -> RoomClient:
	leave_room()
	var prof := Save.section("profile")
	client = RoomClient.new()
	add_child(client)
	mode = Mode.CLIENT
	client.state_changed.connect(func(s, _d):
		if s in ["closed", "failed"]:
			_remember_session()
		elif s == "lobby":
			_remember_session())
	client.lobby_updated.connect(func(lobby: Dictionary):
		if Voice.connection == null:
			Voice.attach(VoiceConnection.for_client(client), bool(lobby.get("voice", false)))
		else:
			Voice.set_room_enabled(bool(lobby.get("voice", false)))
		var r := {}
		for m in lobby.get("members", []):
			r[int(m["pid"])] = str(m["name"])
		Voice.update_roster(r))
	client.join(address, port, code, str(prof.get("name", "Player")), int(prof.get("avatar", 0)))
	room_changed.emit()
	return client


## Stores the last session so the player can rejoin after the app restarts.
func _remember_session() -> void:
	if client == null:
		return
	var s := Save.section("net")
	if client.state in [RoomClient.State.LOBBY, RoomClient.State.MATCH]:
		s["last"] = {"address": client.address, "port": client.port, "code": client.code, "token": client.token, "t": int(Time.get_unix_time_from_system())}
	else:
		s.erase("last")
	Save.mark_dirty()


## Re-entrancy safe: references are cleared before anything can emit signals.
func leave_room() -> void:
	var h := host
	var c := client
	_clear()
	discovery.stop()
	if h:
		h.close("host_left")
	if c:
		c.leave()
		get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(c): c.queue_free())


func _clear() -> void:
	var was_active := mode != Mode.NONE
	host = null
	client = null
	mode = Mode.NONE
	Voice.detach()
	if was_active:
		room_changed.emit()


## The match client for this device in the running match (host or remote).
## seat -> pid for the running match (to show who is speaking).
func pid_of_seat() -> Dictionary:
	if host:
		return host.pid_of_seat
	if client:
		return client.pid_of_seat
	return {}


func match_client() -> MatchClient:
	if host and host.local_client:
		return host.local_client
	if client and client.match_client:
		return client.match_client
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave_room()
