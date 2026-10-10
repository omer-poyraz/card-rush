class_name WebRTCTransport
extends PeerTransport
## Internet transport: WebRTC data channels (godotengine/webrtc-native) in a
## star topology — the room host is peer 1 and every guest connects only to
## the host. A SignalingClient brokers the connection setup; after that game
## and voice traffic flow directly between devices (or through a TURN relay
## when both sides are behind strict NATs and TURN servers are configured).

signal setup_failed(reason: String)

const CONNECT_TIMEOUT_MS := 20000
const DEFAULT_STUN := [{"urls": ["stun:stun.l.google.com:19302"]}]

var sig: SignalingClient
var rtc: WebRTCMultiplayerPeer
var ice: Array = DEFAULT_STUN.duplicate(true)
var _pcs := {}               # peer id -> WebRTCPeerConnection
var _role := ""
var _deadline := 0


static func is_supported() -> bool:
	return ClassDB.class_exists("WebRTCPeerConnection") and WebRTCPeerConnection.new().initialize({}) == OK


func start_host(url: String, code: String, extra_ice: Array = []) -> void:
	_role = "host"
	_begin(url, code, extra_ice)


func start_guest(url: String, code: String, extra_ice: Array = []) -> void:
	_role = "guest"
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	_begin(url, code, extra_ice)


func _begin(url: String, code: String, extra_ice: Array) -> void:
	ice.append_array(extra_ice)
	sig = SignalingClient.new()
	add_child(sig)
	sig.joined.connect(_on_joined)
	sig.peer_joined.connect(_on_peer_joined)
	sig.peer_left.connect(_on_peer_left)
	sig.signal_received.connect(_on_signal)
	sig.ice_servers.connect(func(s: Array): ice.append_array(s))
	sig.host_left.connect(func(): if not is_server: host_lost.emit())
	sig.failed.connect(_on_sig_failed)
	sig.open(url, SignalingClient.room_key(code), _role)


func _on_sig_failed(reason: String) -> void:
	# After the data channel is up the signaling link is no longer needed
	# (except for new guests joining the host).
	if not is_server and rtc and rtc.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_server and rtc:
		push_warning("signaling lost: new players can't join until it is back (%s)" % reason)
		return
	last_error = reason
	setup_failed.emit(reason)
	connection_failed.emit()


## Calls cb once the signaling server accepted us (host: room registered).
func sig_joined_once(cb: Callable) -> void:
	if sig and sig.my_id > 0:
		cb.call()
	else:
		_joined_cbs.append(cb)


var _joined_cbs: Array = []


func _on_joined(id: int) -> void:
	for cb in _joined_cbs:
		cb.call()
	_joined_cbs.clear()
	sig.request_ice()
	rtc = WebRTCMultiplayerPeer.new()
	if _role == "host":
		rtc.create_server()
		setup(rtc, true)
	else:
		rtc.create_client(id)
		setup(rtc, false)
		# the guest waits for the host's offer
		_new_pc(NetTransport.HOST_ID)


func _new_pc(id: int) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	pc.initialize({"iceServers": ice})
	pc.session_description_created.connect(func(type: String, sdp: String):
		pc.set_local_description(type, sdp)
		sig.send_signal(id, {"type": type, "sdp": sdp}))
	pc.ice_candidate_created.connect(func(mid: String, index: int, cand: String):
		sig.send_signal(id, {"type": "cand", "mid": mid, "index": index, "cand": cand}))
	rtc.add_peer(pc, id)
	_pcs[id] = pc
	return pc


func _on_peer_joined(id: int) -> void:
	if _role != "host" or rtc == null or _pcs.has(id):
		return
	var pc := _new_pc(id)
	pc.create_offer()


func _on_peer_left(id: int) -> void:
	if _pcs.has(id):
		_pcs.erase(id)
		if rtc and rtc.has_peer(id):
			rtc.remove_peer(id)


func _on_signal(from_id: int, d: Dictionary) -> void:
	if not _pcs.has(from_id):
		return
	var pc: WebRTCPeerConnection = _pcs[from_id]
	match str(d.get("type", "")):
		"offer", "answer":
			var sdp := NetProtocol.str_field(d, "sdp", 16000)
			if sdp != "":
				pc.set_remote_description(str(d["type"]), sdp)
		"cand":
			pc.add_ice_candidate(NetProtocol.str_field(d, "mid", 64), NetProtocol.int_field(d, "index", 0, 0, 64),
				NetProtocol.str_field(d, "cand", 1024))


func _process(dt: float) -> void:
	super._process(dt)
	if _role == "guest" and _deadline > 0 and Time.get_ticks_msec() > _deadline:
		if rtc == null or rtc.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			_deadline = 0
			last_error = "ERR_NET_WEBRTC_TIMEOUT"
			setup_failed.emit("ERR_NET_WEBRTC_TIMEOUT")
			connection_failed.emit()
		else:
			_deadline = 0


func close() -> void:
	if sig:
		sig.close()
	_pcs.clear()
	super.close()
