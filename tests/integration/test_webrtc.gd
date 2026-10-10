extends TestCase
## Real WebRTC data channels (webrtc-native) brokered by the dev signaling
## server, driving the normal RoomHost/RoomClient room logic.

const PORT := 47930
var _nodes: Array = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n is DevSignalingServer:
				n.stop()
			n.queue_free()
	_nodes.clear()
	await frames(5)


func _until(cond: Callable, timeout_ms := 8000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return false
		await frames(1)
	return true


func _server(port: int) -> DevSignalingServer:
	var s := DevSignalingServer.new()
	runner.add_child(s)
	_nodes.append(s)
	eq(s.start(port), OK, "signaling listen")
	return s


func test_webrtc_supported_on_this_platform() -> void:
	check(WebRTCTransport.is_supported(), "webrtc-native extension loaded")


func test_webrtc_room_join_and_match() -> void:
	if not WebRTCTransport.is_supported():
		check(false, "webrtc unsupported")
		return
	_server(PORT)
	var url := "ws://127.0.0.1:%d" % PORT
	var code := "WRTC22"
	var ht := WebRTCTransport.new()
	var h := RoomHost.new()
	runner.add_child(h)
	_nodes.append(h)
	h.start(ht, {"name": "Net", "max_players": 3, "bots": [1], "rules": RuleProfile.classic().to_dict()}, "Host", 0, code)
	ht.start_host(url, code)
	await frames(10)
	var c := RoomClient.new()
	c.transport_factory = func(_a, _p):
		var t := WebRTCTransport.new()
		t.start_guest(url, code)
		return t
	runner.add_child(c)
	_nodes.append(c)
	c.join("internet", 0, code, "Uzak", 2)
	check(await _until(func(): return c.state == RoomClient.State.LOBBY, 15000), "joined over WebRTC (state %d)" % c.state)
	if c.state != RoomClient.State.LOBBY:
		return
	c.set_ready(true)
	check(await _until(func(): return h.can_start() == ""), "ready over data channel")
	eq(h.start_match(), "")
	check(await _until(func(): return c.match_client != null and c.match_client.last_view.size() > 0, 6000), "game view over WebRTC")
	if c.match_client:
		check(c.match_client.last_view["hand"].size() >= 7, "own hand received")


func test_wrong_code_finds_no_room() -> void:
	_server(PORT + 1)
	var url := "ws://127.0.0.1:%d" % (PORT + 1)
	var t := WebRTCTransport.new()
	runner.add_child(t)
	_nodes.append(t)
	var reason := [""]
	t.setup_failed.connect(func(r): reason[0] = r)
	t.start_guest(url, "NOROOM")
	check(await _until(func(): return reason[0] != "", 6000), "failed cleanly")
	eq(reason[0], "ERR_NET_SIGNAL_NO_ROOM")


func test_signaling_unreachable() -> void:
	var t := WebRTCTransport.new()
	runner.add_child(t)
	_nodes.append(t)
	var reason := [""]
	t.setup_failed.connect(func(r): reason[0] = r)
	t.start_guest("ws://127.0.0.1:1", "ABCDEF")
	check(await _until(func(): return reason[0] != "", 10000), "failed cleanly")
	eq(reason[0], "ERR_NET_SIGNAL_UNREACHABLE")
