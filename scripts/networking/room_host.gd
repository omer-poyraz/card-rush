class_name RoomHost
extends Node
## Room authority on the hosting device: lobby membership, codes, reconnect
## tokens, match creation and routing of each seat's redacted view to the
## right peer only. Clients can only send action REQUESTS, which are cleaned,
## de-duplicated (per-player sequence numbers), rate-limited and then
## validated by the MatchAuthority/RuleEngine like any local action.
##
## Security note: the host device holds every hand in memory. A modified host
## app could cheat; this is weaker than a dedicated trusted server (see
## docs/NETWORKING.md). Clients never receive hidden cards.

signal lobby_changed
signal match_started(local_client: LocalMatchClient)
signal match_ended
signal room_closed(reason: String)
signal member_event(kind: String, name: String)

const HOST_PID := 1
const HELLO_TIMEOUT_MS := 6000
const RATE_PER_S := 20.0
const RATE_BURST := 40.0
const RATE_KICK_DROPS := 300

var transport: NetTransport
var code := ""
var salt := ""
var settings := {
	"name": "", "max_players": 4, "bots": [], "public": false, "voice": false,
	"rules": {}, "disconnect_policy": "bot",
}
var members := {}            # pid -> member dict
var peer_to_pid := {}
var authority: MatchAuthority
var local_client: LocalMatchClient
var seat_of_pid := {}
var pid_of_seat := {}
var in_match := false
var lobby_version := 0
var _next_pid := 2
var _pending_peers := {}     # peer -> connect msec (no hello yet)
var _rate := {}              # peer -> [tokens, last_ms, drops]
var _closed := false


func start(t: NetTransport, room_settings: Dictionary, host_name: String, host_avatar: int, fixed_code := "") -> void:
	transport = t
	if t.get_parent() == null:
		add_child(t)
	t.peer_connected.connect(_on_peer_connected)
	t.peer_disconnected.connect(_on_peer_disconnected)
	t.message.connect(_on_message)
	for k in room_settings:
		settings[k] = room_settings[k]
	settings["max_players"] = clampi(int(settings["max_players"]), 2, NetProtocol.MAX_PLAYERS)
	code = fixed_code if fixed_code != "" else RoomCode.generate()
	salt = Crypto.new().generate_random_bytes(6).hex_encode()
	members[HOST_PID] = {
		"pid": HOST_PID, "name": host_name, "avatar": host_avatar, "token": RoomCode.new_token(),
		"peer": 0, "ready": true, "host": true, "connected": true, "seq": 0, "joined": Time.get_ticks_msec(),
	}
	_bump()


func human_count() -> int:
	return members.size()


func total_count() -> int:
	return members.size() + settings["bots"].size()


func lobby_dict() -> Dictionary:
	var ms := []
	var pids := members.keys()
	pids.sort()
	for pid in pids:
		var m: Dictionary = members[pid]
		ms.append({"pid": pid, "name": m["name"], "avatar": m["avatar"], "ready": m["ready"], "host": m["host"], "connected": m["connected"]})
	return {
		"v": lobby_version, "name": settings["name"], "max": settings["max_players"], "bots": settings["bots"].duplicate(),
		"public": settings["public"], "voice": settings["voice"], "rules": settings["rules"].duplicate(),
		"members": ms, "in_match": in_match, "code": code,
	}


## Discovery announcement for the LAN.
func discovery_info(port: int) -> Dictionary:
	var info := {
		"name": settings["name"], "host": members[HOST_PID]["name"], "players": total_count(),
		"max": settings["max_players"], "port": port, "public": settings["public"], "in_match": in_match,
	}
	if settings["public"]:
		info["code"] = code
	else:
		info["h"] = RoomCode.hash_code(code, salt)
		info["salt"] = salt
	return info


func _bump() -> void:
	lobby_version += 1
	_broadcast({"k": NetProtocol.S_LOBBY, "lobby": lobby_dict()})
	lobby_changed.emit()


func _broadcast(msg: Dictionary) -> void:
	for pid in members:
		var m: Dictionary = members[pid]
		if pid != HOST_PID and int(m["peer"]) > 0:
			transport.send(int(m["peer"]), msg)


# --- lobby controls (host UI) ---------------------------------------------------------

func update_settings(changes: Dictionary) -> void:
	if in_match:
		return
	for k in changes:
		settings[k] = changes[k]
	settings["max_players"] = clampi(int(settings["max_players"]), maxi(2, total_count() - settings["bots"].size()), NetProtocol.MAX_PLAYERS)
	while total_count() > settings["max_players"] and not settings["bots"].is_empty():
		settings["bots"].pop_back()
	_bump()


func add_bot(level: int) -> bool:
	if in_match or total_count() >= settings["max_players"]:
		return false
	settings["bots"].append(clampi(level, 0, 2))
	_bump()
	return true


func remove_bot(index := -1) -> void:
	if in_match or settings["bots"].is_empty():
		return
	settings["bots"].remove_at(index if index >= 0 else settings["bots"].size() - 1)
	_bump()


func kick(pid: int) -> void:
	if pid == HOST_PID or not members.has(pid):
		return
	var m: Dictionary = members[pid]
	if int(m["peer"]) > 0:
		transport.send(int(m["peer"]), {"k": NetProtocol.S_KICKED})
		var p := int(m["peer"])
		peer_to_pid.erase(p)
		transport.disconnect_peer.call_deferred(p)
	if in_match and seat_of_pid.has(pid):
		m["peer"] = 0
		m["connected"] = false
		authority.set_connected(seat_of_pid[pid], false)
	else:
		members.erase(pid)
	member_event.emit("kicked", m["name"])
	_bump()


func can_start() -> String:
	if in_match:
		return "ERR_NET_IN_MATCH"
	var rules := RuleProfile.from_dict(settings["rules"])
	var err := rules.validate_player_count(total_count())
	if err != "":
		return err
	for pid in members:
		if not members[pid]["ready"] or not members[pid]["connected"]:
			return "ERR_NET_NOT_READY"
	return ""


func start_match() -> String:
	var err := can_start()
	if err != "":
		return err
	var rules := RuleProfile.from_dict(settings["rules"])
	var players: Array[PlayerState] = []
	var kinds: Array[int] = []
	seat_of_pid.clear()
	pid_of_seat.clear()
	var pids := members.keys()
	pids.sort()
	for pid in pids:
		var m: Dictionary = members[pid]
		var p := PlayerState.new()
		p.seat_id = "p%d" % pid
		p.display_name = m["name"]
		p.avatar = int(m["avatar"])
		seat_of_pid[pid] = players.size()
		pid_of_seat[players.size()] = pid
		players.append(p)
		kinds.append(MatchAuthority.SeatKind.LOCAL if pid == HOST_PID else MatchAuthority.SeatKind.REMOTE)
		m["seq"] = 0
	var names := ["Nova", "Piksel", "Luna", "Zeki", "Kıvılcım", "Rüzgar", "Yıldız", "Tekno", "Mavi"]
	for i in settings["bots"].size():
		var b := PlayerState.new()
		b.display_name = "%s (%s)" % [names[i % names.size()], TranslationServer.translate("TABLE_TAG_BOT")]
		b.bot_level = int(settings["bots"][i])
		b.avatar = (i * 5 + 3) % AvatarView.COUNT
		players.append(b)
		kinds.append(MatchAuthority.SeatKind.BOT)
	if authority:
		authority.queue_free()
	authority = MatchAuthority.new()
	authority.disconnect_grace_s = 20.0
	authority.bot_takeover_enabled = settings.get("disconnect_policy", "bot") == "bot"
	add_child(authority)
	var serr := authority.setup(rules, players, kinds)
	if serr != "":
		return serr
	authority.published.connect(_on_published)
	authority.match_finished.connect(func(_w): match_ended.emit())
	if local_client:
		local_client.queue_free()
	local_client = LocalMatchClient.new()
	local_client.pausable = false
	local_client.is_host = true
	local_client.online = true
	add_child(local_client)
	local_client.attach(authority, seat_of_pid[HOST_PID])
	in_match = true
	for pid in members:
		var m: Dictionary = members[pid]
		if pid != HOST_PID and int(m["peer"]) > 0:
			transport.send(int(m["peer"]), {"k": NetProtocol.S_START, "seat": seat_of_pid[pid], "pids": pid_of_seat.duplicate()})
	_bump()
	match_started.emit(local_client)
	# give clients a moment to open the table before the deal arrives (it is buffered anyway)
	get_tree().create_timer(0.4).timeout.connect(func():
		if authority and in_match and authority.state.phase == GameState.Phase.WAITING:
			authority.start())
	return ""


## Back to the lobby after a finished (or aborted) match.
func end_match() -> void:
	if not in_match:
		return
	in_match = false
	if authority:
		authority.queue_free()
		authority = null
	if local_client:
		local_client.queue_free()
		local_client = null
	# players who dropped during the match are removed from the lobby
	for pid in members.keys():
		if pid != HOST_PID and not members[pid]["connected"]:
			members.erase(pid)
	for pid in members:
		members[pid]["ready"] = pid == HOST_PID
	_bump()


func close(reason := "host_left") -> void:
	if _closed:
		return
	_closed = true
	_broadcast({"k": NetProtocol.S_CLOSED, "reason": reason})
	# let the message flush before tearing down the connection
	await get_tree().create_timer(0.15).timeout
	if transport:
		transport.close()
	room_closed.emit(reason)
	queue_free()


# --- transport events ---------------------------------------------------------------

func _on_peer_connected(peer: int) -> void:
	_pending_peers[peer] = Time.get_ticks_msec()
	_rate[peer] = [RATE_BURST, Time.get_ticks_msec(), 0]


func _on_peer_disconnected(peer: int) -> void:
	_pending_peers.erase(peer)
	_rate.erase(peer)
	if not peer_to_pid.has(peer):
		return
	var pid: int = peer_to_pid[peer]
	peer_to_pid.erase(peer)
	var m: Dictionary = members.get(pid, {})
	if m.is_empty() or int(m["peer"]) != peer:
		return  # an older connection of a player who already reconnected
	m["peer"] = 0
	m["connected"] = false
	if in_match and seat_of_pid.has(pid):
		authority.set_connected(seat_of_pid[pid], false)
	else:
		members.erase(pid)
	member_event.emit("left", m["name"])
	_bump()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	for peer in _pending_peers.keys():
		if now - int(_pending_peers[peer]) > HELLO_TIMEOUT_MS:
			_pending_peers.erase(peer)
			transport.disconnect_peer(peer)


func _allow(peer: int) -> bool:
	var r: Array = _rate.get(peer, [RATE_BURST, Time.get_ticks_msec(), 0])
	var now := Time.get_ticks_msec()
	r[0] = minf(RATE_BURST, float(r[0]) + (now - int(r[1])) / 1000.0 * RATE_PER_S)
	r[1] = now
	if r[0] < 1.0:
		r[2] = int(r[2]) + 1
		_rate[peer] = r
		if int(r[2]) > RATE_KICK_DROPS:
			transport.disconnect_peer(peer)
		return false
	r[0] = float(r[0]) - 1.0
	_rate[peer] = r
	return true


func _on_message(peer: int, msg: Dictionary) -> void:
	if msg["k"] == NetProtocol.C_VOICE:
		_on_voice(peer, msg)  # own budget: voice must not starve game messages
		return
	if not _allow(peer):
		# tell the player instead of silently losing a move
		if msg["k"] == NetProtocol.C_ACT and peer_to_pid.has(peer):
			transport.send(peer, {"k": NetProtocol.S_REJECTED, "seq": NetProtocol.int_field(msg, "seq", 0), "error": "ERR_NET_RATE_LIMIT"})
		return
	var k: String = msg["k"]
	if k == NetProtocol.C_HELLO:
		_on_hello(peer, msg)
		return
	if not peer_to_pid.has(peer):
		return  # must say hello first
	var pid: int = peer_to_pid[peer]
	var m: Dictionary = members[pid]
	match k:
		NetProtocol.C_READY:
			if not in_match:
				m["ready"] = bool(msg.get("ready", false))
				_bump()
		NetProtocol.C_ACT:
			_on_act(pid, m, msg)
		NetProtocol.C_VOICE_PREF:
			m["voice_recv"] = bool(msg.get("recv", true))
		NetProtocol.C_PING:
			transport.send(peer, {"k": NetProtocol.S_PONG, "t": NetProtocol.int_field(msg, "t", 0)}, false)
		NetProtocol.C_LEAVE:
			_on_peer_disconnected(peer)
			if in_match and seat_of_pid.has(pid) and authority:
				# left on purpose: no grace period, apply the policy now
				authority._grace_expired(seat_of_pid[pid])
			transport.disconnect_peer.call_deferred(peer)


func _on_hello(peer: int, msg: Dictionary) -> void:
	if peer_to_pid.has(peer):
		return
	_pending_peers.erase(peer)
	if NetProtocol.int_field(msg, "proto", 0) != NetProtocol.VERSION:
		_reject(peer, "ERR_NET_VERSION")
		return
	var token := NetProtocol.str_field(msg, "token", 64)
	# reconnect with a session token
	if token != "":
		for pid in members:
			var m: Dictionary = members[pid]
			if pid != HOST_PID and RoomCode.equals(str(m["token"]), token):
				var old := int(m["peer"])
				if old > 0 and old != peer:
					# the same player connected twice: the newest connection wins
					peer_to_pid.erase(old)
					transport.disconnect_peer(old)
				m["peer"] = peer
				m["connected"] = true
				peer_to_pid[peer] = pid
				transport.send(peer, {"k": NetProtocol.S_WELCOME, "pid": pid, "token": m["token"], "lobby": lobby_dict(), "code": code, "seq": int(m["seq"])})
				if in_match and seat_of_pid.has(pid):
					var seat: int = seat_of_pid[pid]
					transport.send(peer, {"k": NetProtocol.S_START, "seat": seat, "resume": true, "pids": pid_of_seat.duplicate()})
					authority.set_connected(seat, true)
					# a fresh view: only this player's own cards
					transport.send(peer, {"k": NetProtocol.S_UPDATE, "view": authority.view_for(seat), "ev": []})
				member_event.emit("back", m["name"])
				_bump()
				return
	if not RoomCode.equals(RoomCode.normalize(NetProtocol.str_field(msg, "code", 12)), code):
		_reject(peer, "ERR_NET_BAD_CODE")
		return
	if in_match:
		_reject(peer, "ERR_NET_IN_MATCH")
		return
	if total_count() >= int(settings["max_players"]):
		_reject(peer, "ERR_NET_ROOM_FULL")
		return
	var name := NameFilter.sanitize_remote(NetProtocol.str_field(msg, "name", 24), TranslationServer.translate("DEFAULT_PLAYER_NAME") + str(_next_pid))
	var pid := _next_pid
	_next_pid += 1
	members[pid] = {
		"pid": pid, "name": _unique_name(name), "avatar": NetProtocol.int_field(msg, "avatar", 0, 0, AvatarView.COUNT - 1),
		"token": RoomCode.new_token(), "peer": peer, "ready": false, "host": false, "connected": true, "seq": 0,
		"joined": Time.get_ticks_msec(),
	}
	peer_to_pid[peer] = pid
	transport.send(peer, {"k": NetProtocol.S_WELCOME, "pid": pid, "token": members[pid]["token"], "lobby": lobby_dict(), "code": code})
	member_event.emit("joined", members[pid]["name"])
	_bump()


func _unique_name(name: String) -> String:
	var taken := {}
	for pid in members:
		taken[members[pid]["name"]] = true
	if not taken.has(name):
		return name
	for i in range(2, 20):
		var n := "%s %d" % [name.substr(0, 13), i]
		if not taken.has(n):
			return n
	return name


func _reject(peer: int, reason: String) -> void:
	transport.send(peer, {"k": NetProtocol.S_REJECT, "reason": reason})
	transport.disconnect_peer.call_deferred(peer)


func _on_act(pid: int, m: Dictionary, msg: Dictionary) -> void:
	if not in_match or not seat_of_pid.has(pid) or authority == null:
		return
	var seq := NetProtocol.int_field(msg, "seq", 0, 0)
	if seq <= int(m["seq"]):
		return  # duplicate or replayed message
	m["seq"] = seq
	var action := NetProtocol.clean_action(msg.get("a"))
	if action.is_empty():
		transport.send(int(m["peer"]), {"k": NetProtocol.S_REJECTED, "seq": seq, "error": "ERR_UNKNOWN_ACTION"})
		return
	var r := authority.submit(seat_of_pid[pid], action)
	if not r["ok"]:
		transport.send(int(m["peer"]), {"k": NetProtocol.S_REJECTED, "seq": seq, "error": r["error"]})


# --- voice relay ----------------------------------------------------------------------

const VOICE_MAX_PER_S := 40.0
var _voice_rate := {}        # peer -> [tokens, last_ms]


func _on_voice(peer: int, msg: Dictionary) -> void:
	if not settings.get("voice", false) or not peer_to_pid.has(peer):
		return
	var r: Array = _voice_rate.get(peer, [VOICE_MAX_PER_S, Time.get_ticks_msec()])
	var now := Time.get_ticks_msec()
	r[0] = minf(VOICE_MAX_PER_S, float(r[0]) + (now - int(r[1])) / 1000.0 * VOICE_MAX_PER_S)
	r[1] = now
	if r[0] < 1.0:
		_voice_rate[peer] = r
		return
	r[0] = float(r[0]) - 1.0
	_voice_rate[peer] = r
	var data: Variant = msg.get("d")
	if not data is PackedByteArray or (data as PackedByteArray).size() > VoiceSettings.MAX_PACKET:
		return
	relay_voice(peer_to_pid[peer], NetProtocol.int_field(msg, "s", 0, 0), data)


## Sends a voice packet from `from_pid` to everyone else who wants voice,
## and plays it locally on the host.
func relay_voice(from_pid: int, seq: int, data: PackedByteArray) -> void:
	if not settings.get("voice", false):
		return
	var msg := {"k": NetProtocol.S_VOICE, "f": from_pid, "s": seq, "d": data}
	for pid in members:
		if pid == from_pid or pid == HOST_PID:
			continue
		var m: Dictionary = members[pid]
		if int(m["peer"]) > 0 and m.get("voice_recv", true):
			transport.send(int(m["peer"]), msg, false)
	if from_pid != HOST_PID:
		Voice.receive(from_pid, seq, data)


func roster() -> Dictionary:
	var out := {}
	for pid in members:
		out[pid] = members[pid]["name"]
	return out


func _on_published(seat: int, view: Dictionary, events: Array) -> void:
	if seat < 0 or not pid_of_seat.has(seat):
		return
	var pid: int = pid_of_seat[seat]
	if pid == HOST_PID or not members.has(pid):
		return
	var peer := int(members[pid]["peer"])
	if peer > 0:
		transport.send(peer, {"k": NetProtocol.S_UPDATE, "view": view, "ev": events})
