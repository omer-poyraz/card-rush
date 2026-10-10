class_name LoopbackTransport
extends NetTransport
## In-memory transport for tests: one server endpoint and any number of
## clients. Can simulate latency, duplicated packets and dropped connections
## (messages still go through encode/decode exactly like the real thing).

var hub: Hub
var my_id := 0
var latency_frames := 0
var duplicate_every := 0     # >0: every Nth packet is delivered twice


class Hub:
	extends RefCounted
	var endpoints := {}      # id -> LoopbackTransport
	var next_id := 2


static func make_server() -> LoopbackTransport:
	var t := LoopbackTransport.new()
	t.hub = Hub.new()
	t.my_id = HOST_ID
	t.is_server = true
	t.hub.endpoints[HOST_ID] = t
	return t


## Creates a client attached to `server`; it "connects" on the next frame.
static func make_client(server: LoopbackTransport) -> LoopbackTransport:
	var t := LoopbackTransport.new()
	t.hub = server.hub
	t.my_id = server.hub.next_id
	server.hub.next_id += 1
	t.is_server = false
	server.hub.endpoints[t.my_id] = t
	(func():
		if t.hub and t.hub.endpoints.has(t.my_id) and server.hub.endpoints.has(HOST_ID):
			server.peer_connected.emit(t.my_id)
			t.connected_to_host.emit()).call_deferred()
	return t


var _sent := 0
var _inbox: Array = []      # [frames_left, from, bytes]


func send(to_id: int, msg: Dictionary, _reliable := true) -> void:
	if hub == null or not hub.endpoints.has(to_id) or not hub.endpoints.has(my_id):
		return
	var dst: LoopbackTransport = hub.endpoints[to_id]
	var bytes := NetProtocol.encode(msg)
	dst._inbox.append([latency_frames, my_id, bytes])
	_sent += 1
	if duplicate_every > 0 and _sent % duplicate_every == 0:
		dst._inbox.append([latency_frames + 1, my_id, bytes])


func _process(_dt: float) -> void:
	var keep := []
	var due := []
	for item in _inbox:
		if item[0] <= 0:
			due.append(item)
		else:
			item[0] -= 1
			keep.append(item)
	_inbox = keep
	for item in due:
		var msg := NetProtocol.decode(item[2], NetProtocol.MAX_PACKET)
		if not msg.is_empty():
			message.emit(item[1], msg)


## Simulates a dropped connection of this client.
func drop() -> void:
	if hub == null or is_server:
		return
	var server: LoopbackTransport = hub.endpoints.get(HOST_ID)
	hub.endpoints.erase(my_id)
	if server:
		server.peer_disconnected.emit(my_id)
	host_lost.emit()


func disconnect_peer(id: int) -> void:
	if hub and hub.endpoints.has(id):
		var c: LoopbackTransport = hub.endpoints[id]
		hub.endpoints.erase(id)
		peer_disconnected.emit(id)
		c.host_lost.emit()


func close() -> void:
	if hub == null:
		return
	if is_server:
		for id in hub.endpoints.keys():
			if id != HOST_ID:
				var c: LoopbackTransport = hub.endpoints[id]
				c.host_lost.emit()
		hub.endpoints.clear()
	else:
		var server: LoopbackTransport = hub.endpoints.get(HOST_ID)
		hub.endpoints.erase(my_id)
		if server:
			server.peer_disconnected.emit(my_id)
	hub = null
