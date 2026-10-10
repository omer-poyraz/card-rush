extends TestCase
## Multiplayer room tests. Most use the in-memory LoopbackTransport (same
## encode/decode path as the real thing); one test uses real ENet on localhost.

const P = GameState.Phase

var _nodes: Array = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await frames(3)


func _host(settings := {}) -> RoomHost:
	var server := LoopbackTransport.make_server()
	var h := RoomHost.new()
	runner.add_child(h)
	_nodes.append(h)
	var s := {"name": "Test", "max_players": 4, "bots": [], "rules": RuleProfile.classic().to_dict()}
	s.merge(settings, true)
	h.start(server, s, "Host", 0)
	return h


func _client(h: RoomHost, code: String, name := "Guest") -> RoomClient:
	var c := RoomClient.new()
	var server: LoopbackTransport = h.transport
	c.transport_factory = func(_a, _p): return LoopbackTransport.make_client(server)
	runner.add_child(c)
	_nodes.append(c)
	c.join("loop", 0, code, name, 3)
	return c


func _until(cond: Callable, timeout_ms := 4000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return false
		await frames(1)
	return true


# --- lobby ---------------------------------------------------------------------------

func test_join_with_code_and_lobby_sync() -> void:
	var h := _host()
	var c := _client(h, h.code)
	check(await _until(func(): return c.state == RoomClient.State.LOBBY), "client reached lobby")
	eq(h.members.size(), 2)
	eq(c.lobby["members"].size(), 2, "client sees both members")
	check(c.token.length() == 32, "session token issued")
	c.set_ready(true)
	check(await _until(func(): return h.members[c.pid]["ready"]), "ready flag reached host")
	h.add_bot(1)
	check(await _until(func(): return c.lobby["bots"].size() == 1), "bot visible to client")
	eq(h.can_start(), "")


func test_code_is_case_and_separator_insensitive() -> void:
	var h := _host()
	var messy := h.code.substr(0, 3).to_lower() + "-" + h.code.substr(3)
	var c := _client(h, messy)
	check(await _until(func(): return c.state == RoomClient.State.LOBBY), "joined with formatted code")


func test_wrong_code_rejected() -> void:
	var h := _host()
	var c := _client(h, "ZZZZZZ" if h.code != "ZZZZZZ" else "YYYYYY")
	var got := [""]
	c.rejected.connect(func(r): got[0] = r)
	check(await _until(func(): return got[0] != ""), "rejected")
	eq(got[0], "ERR_NET_BAD_CODE")
	eq(h.members.size(), 1, "no member added")


func test_room_full() -> void:
	var h := _host({"max_players": 2})
	var a := _client(h, h.code, "A")
	check(await _until(func(): return a.state == RoomClient.State.LOBBY))
	var b := _client(h, h.code, "B")
	var got := [""]
	b.rejected.connect(func(r): got[0] = r)
	check(await _until(func(): return got[0] != ""))
	eq(got[0], "ERR_NET_ROOM_FULL")


func test_cannot_start_until_ready() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	eq(h.can_start(), "ERR_NET_NOT_READY")
	c.set_ready(true)
	await _until(func(): return h.members[c.pid]["ready"])
	eq(h.can_start(), "")


func test_room_codes_unique_and_valid() -> void:
	var seen := {}
	for i in 300:
		var code := RoomCode.generate(seen)
		check(RoomCode.is_valid(code), "valid code " + code)
		check(not seen.has(code), "duplicate code")
		seen[code] = true
	check(not RoomCode.equals("ABCDEF", "ABCDEG"))
	check(RoomCode.equals("ABCDEF", "ABCDEF"))


func test_names_are_sanitised_and_unique() -> void:
	var h := _host()
	var a := _client(h, h.code, "Host")
	await _until(func(): return a.state == RoomClient.State.LOBBY)
	check(h.members[a.pid]["name"] != "Host", "duplicate name made unique")
	var b := _client(h, h.code, "fuck you")
	await _until(func(): return b.state == RoomClient.State.LOBBY)
	check(not str(h.members[b.pid]["name"]).to_lower().contains("fuck"), "offensive name replaced")


# --- match ---------------------------------------------------------------------------

## Drives every human seat with a bot brain that only sees that seat's view.
func _play_humans(clients: Array, bots: Array, acted: Dictionary) -> void:
	for i in clients.size():
		var mc: MatchClient = clients[i]
		var v := mc.last_view
		if v.is_empty() or int(v["phase"]) >= P.ROUND_OVER:
			continue
		if int(v["current"]) != mc.seat:
			continue
		var key := "%d:%d" % [mc.seat, int(v["version"])]
		# like a real player, try again if nothing happened for a while
		if acted.has(key) and Engine.get_process_frames() - int(acted[key]) < 40:
			continue
		acted[key] = Engine.get_process_frames()
		var bc: BotController = bots[i]
		var a := bc.choose_action(v)
		if a["type"] == "play" and v["hand"].size() == 2:
			mc.send({"type": "uno"})
		mc.send(a)


func _start_match(h: RoomHost, clients: Array) -> Array:
	for c in clients:
		c.set_ready(true)
	await _until(func(): return h.can_start() == "")
	eq(h.start_match(), "")
	var mcs := [h.local_client]
	for c in clients:
		await _until(func(): return c.match_client != null)
		c.match_client.flush()
		mcs.append(c.match_client)
	h.local_client.flush()
	await _until(func(): return h.authority.state.phase != P.WAITING, 3000)
	h.authority.time_scale = 0.02
	return mcs


func test_full_online_match_humans_and_bot() -> void:
	var h := _host({"max_players": 4})
	var c1 := _client(h, h.code, "Ali")
	var c2 := _client(h, h.code, "Ayşe")
	await _until(func(): return c1.state == RoomClient.State.LOBBY and c2.state == RoomClient.State.LOBBY)
	h.add_bot(2)
	var mcs := await _start_match(h, [c1, c2])
	var bots := []
	for mc in mcs:
		bots.append(BotController.new(BotController.Level.NORMAL, mc.seat))
	var acted := {}
	var auth := h.authority
	var t0 := Time.get_ticks_msec()
	while not auth.state.is_over() and Time.get_ticks_msec() - t0 < 30000:
		_play_humans(mcs, bots, acted)
		await frames(1)
	check(auth.state.is_over(), "online match finished")
	await frames(3)
	for mc in mcs:
		eq(int(mc.last_view["version"]), auth.state.version, "seat %d in sync" % mc.seat)
		eq(mc.last_view["hand"], auth.state.players[mc.seat].hand, "seat %d hand matches" % mc.seat)
	eq(auth.state.check_integrity(), "")


func test_remote_never_receives_hidden_cards() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	var raw: Array = []
	(c.transport as LoopbackTransport).message.connect(func(_f, m): raw.append(m))
	var mcs := await _start_match(h, [c])
	await frames(5)
	var seat: int = c.match_client.seat
	var others: Array = []
	for i in h.authority.state.players.size():
		if i != seat:
			others.append_array(h.authority.state.players[i].hand)
	for m in raw:
		if m["k"] != NetProtocol.S_UPDATE:
			continue
		var hand: Array = m["view"]["hand"]
		for cid in others:
			check(not hand.has(cid), "opponent card in my hand list")
		for e in m["ev"]:
			if e["t"] == "draw" and int(e["p"]) != seat:
				check(not e.has("cards"), "opponent draw leaked card ids")
			if e["t"] == "deal":
				for k in e["cards"]:
					check(int(k) == seat, "deal leaked another seat's cards")


func test_duplicate_packets_are_ignored() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	(c.transport as LoopbackTransport).duplicate_every = 1  # every packet twice
	var mcs := await _start_match(h, [c])
	var auth := h.authority
	# play until the remote seat has acted a few times; versions must stay consistent
	var bots := [BotController.new(1, mcs[0].seat), BotController.new(1, mcs[1].seat)]
	var acted := {}
	var t0 := Time.get_ticks_msec()
	while not auth.state.is_over() and Time.get_ticks_msec() - t0 < 30000:
		_play_humans(mcs, bots, acted)
		await frames(1)
		eq(auth.state.check_integrity(), "")
		if not failures.is_empty():
			return
	if not auth.state.is_over():
		print("STALL cur=%d phase=%d ver=%d pending=%d vul=%d" % [auth.state.current, auth.state.phase, auth.state.version, auth.state.pending_draw, auth.state.uno_vulnerable])
		for mc in mcs:
			print("  seat %d view ver=%s cur=%s" % [mc.seat, mc.last_view.get("version"), mc.last_view.get("current")])
		print("  jobs=", auth._jobs.map(func(j): return j["key"]), " bots=", auth.bots.keys(), " dc=", auth._dc_since)
		print("  legal=", RuleEngine.legal_actions(auth.state, auth.state.current))
	check(auth.state.is_over(), "finished despite duplicated packets")


func test_spoofed_seat_and_garbage_rejected() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	var mcs := await _start_match(h, [c])
	var auth := h.authority
	auth.time_scale = 100.0  # freeze bots
	var host_seat: int = mcs[0].seat
	# deterministic: it is the HOST's turn, so a remote "draw" must be refused
	auth.state.current = host_seat
	auth.state.phase = P.PLAYING
	auth.state.pending_draw = 0
	var before := auth.state.version
	# remote claims to be the host seat and sends junk fields
	c.transport.send(1, {"k": "act", "seq": 999, "a": {"type": "draw", "player": host_seat, "evil": [1, 2]}})
	c.transport.send(1, {"k": "act", "seq": 1000, "a": "not a dict"})
	c.transport.send(1, {"k": "nonsense"})
	await frames(5)
	eq(auth.state.version, before, "spoofed action for host seat had no effect")
	eq(auth.state.current, host_seat)
	check(NetProtocol.clean_action({"type": "play", "card": 5, "player": 3, "x": 1}).has("player") == false, "player field stripped")
	eq(NetProtocol.clean_action({"type": "rm -rf"}), {}, "unknown type dropped")
	eq(NetProtocol.decode(PackedByteArray([1, 2, 3]), 100), {}, "garbage bytes dropped")
	eq(NetProtocol.decode(NetProtocol.encode({"k": "x", "pad": "a".repeat(5000)}), NetProtocol.MAX_CLIENT_PACKET), {}, "oversized dropped")


func test_disconnect_and_reconnect_with_token() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	var mcs := await _start_match(h, [c])
	var seat: int = c.match_client.seat
	var auth := h.authority
	auth.time_scale = 100.0
	(c.transport as LoopbackTransport).drop()
	check(await _until(func(): return not auth.state.players[seat].connected), "host saw the drop")
	eq(c.state, RoomClient.State.RECONNECTING)
	check(await _until(func(): return c.state == RoomClient.State.MATCH, 8000), "client reconnected with its token")
	check(auth.state.players[seat].connected, "seat reconnected")
	eq(c.match_client.seat, seat, "same seat after reconnect")
	await frames(3)
	eq(c.match_client.last_view["hand"], auth.state.players[seat].hand, "fresh view with own cards")


func test_second_connection_with_same_token_replaces_first() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	var token := c.token
	var dup := RoomClient.new()
	var server: LoopbackTransport = h.transport
	dup.transport_factory = func(_a, _p): return LoopbackTransport.make_client(server)
	runner.add_child(dup)
	_nodes.append(dup)
	dup.join("loop", 0, "", "Clone", 1)
	dup.token = token
	check(await _until(func(): return dup.state == RoomClient.State.LOBBY), "token login")
	eq(h.members.size(), 2, "still one seat for that player")
	eq(dup.pid, c.pid, "same player id")
	eq(h.peer_to_pid.size(), 1, "old connection unmapped")


func test_host_close_notifies_clients() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	h.close("host_left")
	check(await _until(func(): return c.state == RoomClient.State.CLOSED), "client informed")


func test_back_to_lobby_after_match() -> void:
	var h := _host()
	var c := _client(h, h.code)
	await _until(func(): return c.state == RoomClient.State.LOBBY)
	await _start_match(h, [c])
	h.end_match()
	check(await _until(func(): return c.state == RoomClient.State.LOBBY and not c.lobby["in_match"]), "client back in lobby")
	eq(h.members[c.pid]["ready"], false, "ready reset")


# --- real sockets ----------------------------------------------------------------------

func test_enet_localhost_round_trip() -> void:
	var port := 47890
	var r := ENetAdapter.host(port)
	check(r["ok"], "enet host")
	if not r["ok"]:
		return
	var h := RoomHost.new()
	runner.add_child(h)
	_nodes.append(h)
	h.start(r["transport"], {"name": "Enet", "max_players": 3, "bots": [1], "rules": RuleProfile.classic().to_dict()}, "Host", 0)
	var c := RoomClient.new()
	c.transport_factory = func(a, p):
		var j := ENetAdapter.join(a, p)
		return j["transport"] if j["ok"] else null
	runner.add_child(c)
	_nodes.append(c)
	c.join("127.0.0.1", port, h.code, "Remote", 2)
	check(await _until(func(): return c.state == RoomClient.State.LOBBY, 6000), "joined over ENet")
	var mcs := await _start_match(h, [c])
	check(await _until(func(): return c.match_client.last_view.size() > 0, 4000), "view received over ENet")
	var v: Dictionary = c.match_client.last_view
	eq(v["hand"].size() >= 7, true, "own hand received")
	h.close("test")
	await frames(10)


func test_lan_discovery_public_and_private() -> void:
	var adv := LanDiscovery.new()
	var lis := LanDiscovery.new()
	adv.port = 47895
	lis.port = 47895
	adv.extra_targets = ["127.0.0.1"]
	runner.add_child(adv)
	runner.add_child(lis)
	_nodes.append_array([adv, lis])
	check(lis.listen(), "listen")
	adv.advertise({"name": "Salon", "host": "Ömer", "players": 2, "max": 4, "port": 47810, "public": false,
		"h": RoomCode.hash_code("ABCDEF", "s1"), "salt": "s1"})
	check(await _until(func(): return not lis.rooms.is_empty(), 4000), "room discovered")
	if lis.rooms.is_empty():
		return
	var r: Dictionary = lis.rooms.values()[0]
	eq(r["code"], "", "private code not broadcast")
	check(not lis.find_by_code("ABCDEF").is_empty(), "found by code hash")
	check(lis.find_by_code("ABCDEG").is_empty(), "wrong code not found")
	adv.stop()
	lis.stop()
