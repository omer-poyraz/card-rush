class_name SignalingClient
extends Node
## WebSocket client for the Card Rush signaling server. It only relays WebRTC
## connection setup (SDP offers/answers and ICE candidates) and learns nothing
## but a hash of the room code. Game data never passes through it.
##
## Protocol (JSON text frames):
##   -> {"t":"join","room":<key>,"role":"host"|"guest","v":1}
##   <- {"t":"joined","id":n} | {"t":"error","reason":...}
##   <- {"t":"peer","id":n} / {"t":"peer_left","id":n}        (host only)
##   -> {"t":"sig","to":id,"data":{...}}  <- {"t":"sig","from":id,"data":{...}}
##   <- {"t":"host_left"}                                      (guests)
##   -> {"t":"ice"}  <- {"t":"ice","servers":[...]}            (optional TURN)

signal joined(id: int)
signal peer_joined(id: int)
signal peer_left(id: int)
signal signal_received(from_id: int, data: Dictionary)
signal ice_servers(servers: Array)
signal host_left
signal failed(reason: String)

const VERSION := 1
const CONNECT_TIMEOUT_MS := 8000

var ws := WebSocketPeer.new()
var my_id := -1
var _join_msg := {}
var _opened := false
var _started_ms := 0
var _closed := false


static func room_key(code: String) -> String:
	return RoomCode.hash_code(code, "cardrush-signal-v1")


func open(url: String, key: String, role: String) -> void:
	_join_msg = {"t": "join", "room": key, "role": role, "v": VERSION}
	_started_ms = Time.get_ticks_msec()
	ws.inbound_buffer_size = 256 * 1024
	# the room key in the URL lets the server route to the right room instance
	var base := url
	if base.get_slice("://", 1).find("/") == -1:
		base += "/"  # "ws://host:port" needs a path before the query
	var full := base + ("&" if base.contains("?") else "?") + "room=" + key
	var err := ws.connect_to_url(full)
	if err != OK:
		_fail("ERR_NET_SIGNAL_UNREACHABLE")


func send_signal(to_id: int, data: Dictionary) -> void:
	_send({"t": "sig", "to": to_id, "data": data})


func request_ice() -> void:
	_send({"t": "ice"})


func _send(msg: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))


func close() -> void:
	_closed = true
	if ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
		ws.close()


func _process(_dt: float) -> void:
	if _closed:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _opened:
			_opened = true
			_send(_join_msg)
		while ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet()
			if pkt.size() > 64 * 1024:
				continue
			var v: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if v is Dictionary:
				_handle(v)
	elif st == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - _started_ms > CONNECT_TIMEOUT_MS:
			_fail("ERR_NET_SIGNAL_UNREACHABLE")
	elif st == WebSocketPeer.STATE_CLOSED:
		_fail("ERR_NET_SIGNAL_UNREACHABLE" if not _opened else "ERR_NET_SIGNAL_CLOSED")


func _handle(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"joined":
			my_id = NetProtocol.int_field(m, "id", -1, 1, 1 << 30)
			joined.emit(my_id)
		"peer":
			peer_joined.emit(NetProtocol.int_field(m, "id", -1, 2, 1 << 30))
		"peer_left":
			peer_left.emit(NetProtocol.int_field(m, "id", -1, 2, 1 << 30))
		"sig":
			var d: Variant = m.get("data")
			if d is Dictionary:
				signal_received.emit(NetProtocol.int_field(m, "from", -1, 1, 1 << 30), d)
		"ice":
			var s: Variant = m.get("servers")
			ice_servers.emit(s if s is Array else [])
		"host_left":
			host_left.emit()
		"error":
			_fail("ERR_NET_SIGNAL_" + NetProtocol.str_field(m, "reason", 24).to_upper())


func _fail(reason: String) -> void:
	if _closed:
		return
	_closed = true
	ws.close()
	failed.emit(reason)
