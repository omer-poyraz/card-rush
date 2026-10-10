class_name PeerTransport
extends NetTransport
## NetTransport over any Godot MultiplayerPeer (ENetMultiplayerPeer now,
## WebRTCMultiplayerPeer later) using its raw packet API — no RPC node paths,
## no SceneMultiplayer. Polled every frame.

var peer: MultiplayerPeer
var _was_connected := false
var _max_in := NetProtocol.MAX_PACKET


func setup(p: MultiplayerPeer, server: bool) -> void:
	peer = p
	is_server = server
	_max_in = NetProtocol.MAX_CLIENT_PACKET if server else NetProtocol.MAX_PACKET
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(id: int) -> void:
	if is_server:
		peer_connected.emit(id)
	elif id == HOST_ID and not _was_connected:
		_was_connected = true
		connected_to_host.emit()


func _on_peer_disconnected(id: int) -> void:
	if is_server:
		peer_disconnected.emit(id)
	elif id == HOST_ID:
		host_lost.emit()


func _process(_dt: float) -> void:
	if peer == null:
		return
	peer.poll()
	var status := peer.get_connection_status()
	if not is_server and status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if _was_connected:
			_was_connected = false
			peer = null
			host_lost.emit()
		else:
			peer = null
			connection_failed.emit()
		return
	while peer and peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var bytes := peer.get_packet()
		var msg := NetProtocol.decode(bytes, _max_in)
		if msg.is_empty():
			continue  # malformed or oversized: drop silently
		message.emit(from, msg)


func send(to_id: int, msg: Dictionary, reliable := true) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	peer.transfer_channel = 0 if reliable else 1
	peer.set_target_peer(to_id)
	peer.put_packet(NetProtocol.encode(msg))


func disconnect_peer(id: int) -> void:
	if peer and is_server:
		peer.disconnect_peer(id)


func peer_address(id: int) -> String:
	if peer is ENetMultiplayerPeer and is_server:
		var p := (peer as ENetMultiplayerPeer).get_peer(id)
		if p:
			return p.get_remote_address()
	return ""


func close() -> void:
	if peer:
		peer.close()
	peer = null
	_was_connected = false
