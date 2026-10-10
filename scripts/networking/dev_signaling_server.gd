class_name DevSignalingServer
extends Node
## Minimal signaling server written in GDScript, used for local development
## and automated tests (same protocol as server/signaling-worker). Not meant
## for production: no TLS, single process. Run standalone with
##   godot --headless --path . res://tools/signaling_server.tscn -- --port 9080

const MAX_GUESTS := 12
const MAX_MSG := 32 * 1024

var tcp := TCPServer.new()
var peers := {}          # conn id -> {ws, room, role, id}
var rooms := {}          # key -> {host: conn id, guests: {peer id: conn id}, next: int}
var _next_conn := 1


func start(port: int, bind := "127.0.0.1") -> int:
	return tcp.listen(port, bind)


func stop() -> void:
	for c in peers.values():
		c["ws"].close()
	peers.clear()
	rooms.clear()
	tcp.stop()


func _process(_dt: float) -> void:
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		var ws := WebSocketPeer.new()
		ws.accept_stream(stream)
		peers[_next_conn] = {"ws": ws, "room": "", "role": "", "id": -1}
		_next_conn += 1
	for cid in peers.keys():
		var c: Dictionary = peers[cid]
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		match ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var pkt := ws.get_packet()
					if pkt.size() <= MAX_MSG:
						var v: Variant = JSON.parse_string(pkt.get_string_from_utf8())
						if v is Dictionary:
							_handle(cid, v)
			WebSocketPeer.STATE_CLOSED:
				_drop(cid)


func _send(cid: int, msg: Dictionary) -> void:
	if peers.has(cid):
		(peers[cid]["ws"] as WebSocketPeer).send_text(JSON.stringify(msg))


func _handle(cid: int, m: Dictionary) -> void:
	var c: Dictionary = peers[cid]
	match str(m.get("t", "")):
		"join":
			var key := str(m.get("room", "")).substr(0, 32)
			var role := str(m.get("role", ""))
			if key.length() < 8 or not role in ["host", "guest"] or c["room"] != "":
				_send(cid, {"t": "error", "reason": "bad_request"})
				return
			if role == "host":
				if rooms.has(key):
					_send(cid, {"t": "error", "reason": "room_taken"})
					return
				rooms[key] = {"host": cid, "guests": {}, "next": 2}
				c["room"] = key
				c["role"] = "host"
				c["id"] = 1
				_send(cid, {"t": "joined", "id": 1})
			else:
				if not rooms.has(key):
					_send(cid, {"t": "error", "reason": "no_room"})
					return
				var r: Dictionary = rooms[key]
				if r["guests"].size() >= MAX_GUESTS:
					_send(cid, {"t": "error", "reason": "full"})
					return
				var id: int = r["next"]
				r["next"] = id + 1
				r["guests"][id] = cid
				c["room"] = key
				c["role"] = "guest"
				c["id"] = id
				_send(cid, {"t": "joined", "id": id})
				_send(r["host"], {"t": "peer", "id": id})
		"sig":
			if c["room"] == "" or not rooms.has(c["room"]):
				return
			var r: Dictionary = rooms[c["room"]]
			var to := int(m.get("to", -1))
			var target := -1
			if to == 1:
				target = r["host"]
			elif c["role"] == "host" and r["guests"].has(to):
				target = r["guests"][to]
			if target > 0:
				_send(target, {"t": "sig", "from": c["id"], "data": m.get("data", {})})
		"ice":
			_send(cid, {"t": "ice", "servers": []})


func _drop(cid: int) -> void:
	var c: Dictionary = peers.get(cid, {})
	peers.erase(cid)
	if c.is_empty() or c["room"] == "" or not rooms.has(c["room"]):
		return
	var r: Dictionary = rooms[c["room"]]
	if c["role"] == "host":
		for gid in r["guests"]:
			_send(r["guests"][gid], {"t": "host_left"})
		rooms.erase(c["room"])
	else:
		r["guests"].erase(c["id"])
		_send(r["host"], {"t": "peer_left", "id": c["id"]})
