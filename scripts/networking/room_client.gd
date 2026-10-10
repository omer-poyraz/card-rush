class_name RoomClient
extends Node
## A player's connection to a room host. Handles the hello/token handshake,
## lobby updates, match start, action requests (with sequence numbers) and
## automatic reconnection with the session token when the link drops.

signal state_changed(state: String, detail: String)
signal lobby_updated(lobby: Dictionary)
signal match_starting(client: NetworkMatchClient, resume: bool)
signal rejected(reason: String)

const RECONNECT_WINDOW_MS := 30000
const RECONNECT_EVERY_S := 2.0

enum State { IDLE, CONNECTING, LOBBY, MATCH, RECONNECTING, CLOSED, FAILED }

var state := State.IDLE
var transport: NetTransport
var address := ""
var port := NetProtocol.GAME_PORT
var code := ""
var token := ""
var pid := -1
var lobby := {}
var match_client: NetworkMatchClient
var player_name := ""
var avatar := 0
var latency_ms := -1
var pid_of_seat := {}        # seat -> pid in the running match (voice indicators)
## Builds a transport for (address, port). Tests inject a loopback factory.
var transport_factory: Callable
var _seq := 0
var _closing := false
var _reconnect_until := 0
var _ping_timer := 0.0


func _ready() -> void:
	if not transport_factory.is_valid():
		transport_factory = func(addr: String, p: int) -> NetTransport:
			var r := ENetAdapter.join(addr, p)
			return r["transport"] if r["ok"] else null


func join(addr: String, p: int, room_code: String, name: String, av: int) -> void:
	address = addr
	port = p
	code = RoomCode.normalize(room_code)
	player_name = name
	avatar = av
	token = ""
	_set_state(State.CONNECTING, "")
	_connect()


func _connect() -> void:
	if transport:
		transport.queue_free()
		transport = null
	var t: NetTransport = transport_factory.call(address, port)
	if t == null:
		_fail("ERR_NET_JOIN_FAILED")
		return
	transport = t
	add_child(t)
	t.connected_to_host.connect(_on_connected)
	t.connection_failed.connect(_on_connection_failed)
	t.host_lost.connect(_on_host_lost)
	t.message.connect(_on_message)


func _on_connected() -> void:
	transport.send(NetTransport.HOST_ID, {
		"k": NetProtocol.C_HELLO, "proto": NetProtocol.VERSION, "name": player_name, "avatar": avatar,
		"code": code, "token": token, "app": str(ProjectSettings.get_setting("application/config/version")),
	})


func _on_connection_failed() -> void:
	if state == State.RECONNECTING:
		return  # keep retrying until the window closes
	_fail(transport.last_error if transport and transport.last_error != "" else "ERR_NET_JOIN_FAILED")


func _on_host_lost() -> void:
	if _closing or state in [State.CLOSED, State.FAILED]:
		return
	if token == "":
		_fail("ERR_NET_JOIN_FAILED")
		return
	_reconnect_until = Time.get_ticks_msec() + RECONNECT_WINDOW_MS
	_set_state(State.RECONNECTING, "")
	if match_client:
		match_client.connection_changed.emit("reconnecting", TranslationServer.translate("NET_RECONNECTING"))
	_retry_later()


func _retry_later() -> void:
	await get_tree().create_timer(RECONNECT_EVERY_S).timeout
	if state != State.RECONNECTING or _closing:
		return
	if Time.get_ticks_msec() > _reconnect_until:
		_fail("ERR_NET_HOST_GONE")
		return
	_connect()
	await get_tree().create_timer(RECONNECT_EVERY_S).timeout
	if state == State.RECONNECTING:
		_retry_later()


func _on_message(_from: int, msg: Dictionary) -> void:
	match msg["k"]:
		NetProtocol.S_WELCOME:
			pid = NetProtocol.int_field(msg, "pid", -1)
			token = NetProtocol.str_field(msg, "token", 64)
			# continue after the host's last accepted sequence (survives app restarts)
			_seq = maxi(_seq, NetProtocol.int_field(msg, "seq", 0, 0))
			if msg.get("lobby") is Dictionary:
				lobby = msg["lobby"]
			var was_reconnecting := state == State.RECONNECTING
			_set_state(State.MATCH if bool(lobby.get("in_match", false)) and was_reconnecting else State.LOBBY, "")
			if match_client and was_reconnecting:
				match_client.connection_changed.emit("connected", "")
			lobby_updated.emit(lobby)
		NetProtocol.S_REJECT:
			var reason := NetProtocol.str_field(msg, "reason", 40)
			rejected.emit(reason)
			_fail(reason)
		NetProtocol.S_LOBBY:
			if msg.get("lobby") is Dictionary:
				lobby = msg["lobby"]
				if not bool(lobby.get("in_match", false)) and state == State.MATCH:
					_set_state(State.LOBBY, "")
				lobby_updated.emit(lobby)
		NetProtocol.S_START:
			var seat := NetProtocol.int_field(msg, "seat", -1, 0, NetProtocol.MAX_PLAYERS - 1)
			if seat < 0:
				return
			var resume := bool(msg.get("resume", false))
			if match_client == null or not resume:
				if match_client:
					match_client.queue_free()
				match_client = NetworkMatchClient.new()
				match_client.room = self
				add_child(match_client)
			match_client.seat = seat
			if msg.get("pids") is Dictionary:
				pid_of_seat.clear()
				for k in msg["pids"]:
					pid_of_seat[int(k)] = int(msg["pids"][k])
			_set_state(State.MATCH, "")
			match_starting.emit(match_client, resume)
		NetProtocol.S_UPDATE:
			if match_client and msg.get("view") is Dictionary and msg.get("ev") is Array:
				match_client._deliver(msg["view"], msg["ev"])
		NetProtocol.S_REJECTED:
			if match_client:
				match_client.action_rejected.emit(NetProtocol.str_field(msg, "error", 40))
		NetProtocol.S_VOICE:
			var d: Variant = msg.get("d")
			if d is PackedByteArray:
				Voice.receive(NetProtocol.int_field(msg, "f", -1), NetProtocol.int_field(msg, "s", 0, 0), d)
		NetProtocol.S_PONG:
			latency_ms = Time.get_ticks_msec() - NetProtocol.int_field(msg, "t", 0)
		NetProtocol.S_CLOSED:
			_closing = true
			_set_state(State.CLOSED, NetProtocol.str_field(msg, "reason", 40))
		NetProtocol.S_KICKED:
			_closing = true
			_set_state(State.CLOSED, "kicked")


func _process(dt: float) -> void:
	_ping_timer -= dt
	if _ping_timer <= 0.0 and transport and state in [State.LOBBY, State.MATCH]:
		_ping_timer = 3.0
		transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_PING, "t": Time.get_ticks_msec()}, false)


func send_action(a: Dictionary) -> void:
	if transport == null or state != State.MATCH:
		if match_client:
			match_client.action_rejected.emit("ERR_NET_NOT_CONNECTED")
		return
	_seq += 1
	var clean := a.duplicate()
	clean.erase("player")
	transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_ACT, "seq": _seq, "a": clean})


func set_ready(r: bool) -> void:
	if transport and state == State.LOBBY:
		transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_READY, "ready": r})


func leave() -> void:
	if state in [State.CLOSED, State.FAILED] and transport == null:
		return
	_closing = true
	if transport and state in [State.LOBBY, State.MATCH, State.CONNECTING]:
		transport.send(NetTransport.HOST_ID, {"k": NetProtocol.C_LEAVE})
		await get_tree().create_timer(0.15).timeout
	if transport:
		transport.close()
		transport = null
	if state != State.CLOSED and state != State.FAILED:
		_set_state(State.CLOSED, "left")


func _fail(reason: String) -> void:
	if transport:
		transport.close()
	_set_state(State.FAILED, reason)


func _set_state(s: int, detail: String) -> void:
	state = s
	state_changed.emit(State.keys()[s].to_lower(), detail)
