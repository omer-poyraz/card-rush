class_name LanDiscovery
extends Node
## Finds rooms on the local network with small UDP broadcasts.
## Host: `advertise(info)` sends an announcement every second.
## Client: `listen()` collects announcements into `rooms`.
## Public rooms announce their code; private rooms announce only a salted
## hash, so a player must already know the code to find them.
## Note: some Android devices filter broadcast packets unless the app holds a
## Wi-Fi multicast lock — direct IP join is always offered as a fallback.

signal rooms_changed

const INTERVAL := 1.0
const EXPIRE_MS := 3500
const MAGIC := "cardrush"

var rooms := {}               # "ip:port" -> info (+ "ip", "seen")
var _udp: PacketPeerUDP
var _listening := false
var _ad := {}
var _timer := 0.0
var extra_targets: Array[String] = []   # tests: e.g. ["127.0.0.1"]
var port := NetProtocol.DISCOVERY_PORT


func advertise(info: Dictionary) -> void:
	stop()
	_ad = info.duplicate()
	_ad["magic"] = MAGIC
	_ad["v"] = NetProtocol.VERSION
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_timer = 0.0
	set_process(true)


func update_ad(info: Dictionary) -> void:
	for k in info:
		_ad[k] = info[k]


func listen() -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(port, "*")
	if err != OK:
		_udp = null
		return false
	_listening = true
	rooms.clear()
	set_process(true)
	return true


func stop() -> void:
	if _udp:
		_udp.close()
	_udp = null
	_listening = false
	_ad = {}
	set_process(false)


func _ready() -> void:
	set_process(false)


func _process(dt: float) -> void:
	if _udp == null:
		return
	if not _ad.is_empty():
		_timer -= dt
		if _timer <= 0.0:
			_timer = INTERVAL
			_broadcast()
	if _listening:
		var changed := false
		while _udp.get_available_packet_count() > 0:
			var bytes := _udp.get_packet()
			var ip := _udp.get_packet_ip()
			var info := _parse(bytes)
			if info.is_empty():
				continue
			info["ip"] = ip
			info["seen"] = Time.get_ticks_msec()
			var key := "%s:%d" % [ip, int(info.get("port", 0))]
			if not rooms.has(key) or rooms[key].get("players") != info.get("players") or rooms[key].get("in_match") != info.get("in_match"):
				changed = true
			rooms[key] = info
		var now := Time.get_ticks_msec()
		for key in rooms.keys():
			if now - int(rooms[key]["seen"]) > EXPIRE_MS:
				rooms.erase(key)
				changed = true
		if changed:
			rooms_changed.emit()


func _broadcast() -> void:
	var bytes := JSON.stringify(_ad).to_utf8_buffer()
	var targets: Array[String] = ["255.255.255.255"]
	for ip in ENetAdapter.local_ipv4():
		var parts := ip.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	targets.append_array(extra_targets)
	for t in targets:
		_udp.set_dest_address(t, port)
		_udp.put_packet(bytes)


static func _parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > 1024:
		return {}
	var v: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not v is Dictionary or v.get("magic", "") != MAGIC or int(v.get("v", 0)) != NetProtocol.VERSION:
		return {}
	var d := v as Dictionary
	return {
		"name": NameFilter.sanitize_remote(NetProtocol.str_field(d, "name", 24), "Card Rush"),
		"host": NameFilter.sanitize_remote(NetProtocol.str_field(d, "host", 16), "?"),
		"players": NetProtocol.int_field(d, "players", 0, 0, 10),
		"max": NetProtocol.int_field(d, "max", 4, 2, 10),
		"port": NetProtocol.int_field(d, "port", NetProtocol.GAME_PORT, 1024, 65535),
		"public": bool(d.get("public", false)),
		"code": RoomCode.normalize(NetProtocol.str_field(d, "code", 8)),
		"h": NetProtocol.str_field(d, "h", 16),
		"salt": NetProtocol.str_field(d, "salt", 16),
		"in_match": bool(d.get("in_match", false)),
	}


## Finds a discovered room by code (public: plain match, private: hash match).
func find_by_code(code: String) -> Dictionary:
	for key in rooms:
		var r: Dictionary = rooms[key]
		if r["public"] and RoomCode.equals(r["code"], code):
			return r
		if not r["public"] and r["h"] != "" and RoomCode.equals(r["h"], RoomCode.hash_code(code, r["salt"])):
			return r
	return {}
