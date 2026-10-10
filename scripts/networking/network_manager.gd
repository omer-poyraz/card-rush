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
var internet := false        # current room uses the internet (WebRTC) adapter


func _ready() -> void:
	discovery = LanDiscovery.new()
	add_child(discovery)


func is_active() -> bool:
	return mode != Mode.NONE


## Creates a LAN/direct room. Returns "" or an error key.
func create_room(settings: Dictionary, fixed_code := "") -> String:
	leave_room()
	internet = false
	var r := ENetAdapter.host(host_port)
	if not r["ok"]:
		return r["error"]
	return _start_host(r["transport"], settings, fixed_code)


# --- internet (WebRTC + signaling) -----------------------------------------------------

## Signaling server URL: project setting (release) or a local override (dev/self-host).
func signaling_url() -> String:
	var o := str(Save.section("net").get("signaling_url", ""))
	if o != "":
		return o
	return str(ProjectSettings.get_setting("card_rush/online/signaling_url", ""))


## "" when internet rooms can be used, otherwise the reason key.
func internet_unavailable_reason() -> String:
	if not WebRTCTransport.is_supported():
		return "NET_INTERNET_UNSUPPORTED"
	if signaling_url() == "":
		return "NET_INTERNET_NOT_CONFIGURED"
	return ""


## Creates an internet room. Codes are random; a (rare) clash on the signaling
## server is retried with a new code. Calls cb(err) when ready or failed.
func create_internet_room(settings: Dictionary, cb: Callable, attempt := 0) -> void:
	leave_room()
	var reason := internet_unavailable_reason()
	if reason != "":
		cb.call(reason)
		return
	var code := RoomCode.generate()
	var t := WebRTCTransport.new()
	_start_host(t, settings, code)
	internet = true
	discovery.stop()  # internet rooms are not announced on the LAN
	var done := [false]
	t.sig_joined_once(func():
		if not done[0]:
			done[0] = true
			cb.call(""))
	t.setup_failed.connect(func(r: String):
		if done[0]:
			return
		done[0] = true
		if r == "ERR_NET_SIGNAL_ROOM_TAKEN" and attempt < 3:
			create_internet_room(settings, cb, attempt + 1)
		else:
			leave_room()
			cb.call(r))
	t.start_host(signaling_url(), code)


func join_internet_room(code: String) -> RoomClient:
	var c := join_room("internet", 0, code)
	internet = true
	return c


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
	if not (t is WebRTCTransport):
		discovery.advertise(host.discovery_info(host_port))
	room_changed.emit()
	return ""


func _refresh_ad() -> void:
	if host and not internet:
		discovery.update_ad(host.discovery_info(host_port))


func join_room(address: String, port: int, code: String) -> RoomClient:
	leave_room()
	internet = false
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
	if address == "internet":
		var url := signaling_url()
		client.transport_factory = func(_a, _p):
			var t := WebRTCTransport.new()
			t.start_guest(url, code)
			return t
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
## Reports this device's answer to a shared ad event (host or client).
func report_ad_result(event_id: String, status: String) -> void:
	if host:
		host.report_ad_result(RoomHost.HOST_PID, event_id, status)
	elif client:
		client.send_ad_result(event_id, status)


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
