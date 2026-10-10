extends TestCase
## Voice codec, VAD, jitter buffer and host relay (no microphone needed).


func _sine(n: int, freq: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sin(TAU * freq * i / VoiceSettings.SAMPLE_RATE) * amp
	return out


func test_adpcm_round_trip_quality() -> void:
	var enc := ImaAdpcm.new()
	var src := _sine(VoiceSettings.FRAME_SAMPLES * 4, 440.0, 0.5)
	var dec := PackedFloat32Array()
	for k in 4:
		var pkt := enc.encode(src.slice(k * VoiceSettings.FRAME_SAMPLES, (k + 1) * VoiceSettings.FRAME_SAMPLES))
		eq(pkt.size(), 5 + VoiceSettings.FRAME_SAMPLES / 2, "4:1 packet size")
		dec.append_array(ImaAdpcm.decode(pkt))
	eq(dec.size(), src.size())
	var sig := 0.0
	var noise := 0.0
	for i in range(200, src.size()):  # skip the adaptation start
		sig += src[i] * src[i]
		noise += (src[i] - dec[i]) * (src[i] - dec[i])
	var snr := 10.0 * log(sig / maxf(noise, 1e-12)) / log(10.0)
	check(snr > 18.0, "speech-band SNR %.1f dB" % snr)


func test_adpcm_packets_independent() -> void:
	var enc := ImaAdpcm.new()
	enc.encode(_sine(640, 300.0, 0.6))
	var second := enc.encode(_sine(640, 300.0, 0.6))
	# decoding the second packet alone works (header carries predictor/index)
	eq(ImaAdpcm.decode(second).size(), 640)


func test_adpcm_rejects_garbage() -> void:
	eq(ImaAdpcm.decode(PackedByteArray([1, 2])).size(), 0)
	eq(ImaAdpcm.decode(PackedByteArray([0, 0, 200, 255, 255, 1, 2])).size(), 0, "claimed count beyond payload")


func test_vad_sends_speech_not_silence() -> void:
	var sent := []
	var fake := FakeConn.new(sent)
	Voice.connection = fake
	var old_last: int = Voice._last_speech_ms
	Voice._last_speech_ms = -100000
	check(not Voice.submit_frame(_sine(640, 200.0, 0.0005)), "silence not sent")
	check(Voice.submit_frame(_sine(640, 200.0, 0.3)), "speech sent")
	eq(sent.size(), 1)
	check(Voice.submit_frame(_sine(640, 200.0, 0.0005)), "hangover keeps sending briefly")
	Voice.connection = null
	Voice._last_speech_ms = old_last


class FakeConn:
	extends VoiceConnection
	var log_: Array
	func _init(l: Array) -> void:
		log_ = l
	func send(seq: int, data: PackedByteArray) -> void:
		log_.append([seq, data])
	func valid() -> bool:
		return true
	func my_pid() -> int:
		return 99


func test_mic_off_sends_nothing() -> void:
	var sent := []
	Voice.connection = FakeConn.new(sent)
	Voice.mic_on = false
	await frames(5)
	eq(sent.size(), 0, "no capture while the mic is off")
	Voice.connection = null


func test_jitter_buffer_orders_and_drops_duplicates() -> void:
	var p := VoiceParticipant.new()
	runner.add_child(p)
	await frames(1)
	var f := _sine(640, 200.0, 0.2)
	p.push(5, f)
	p.push(3, f)
	p.push(4, f)
	p.push(4, f)
	eq(p.queued_frames(), 3, "duplicate frame merged")
	p.muted = true
	p.push(6, f)
	eq(p.queued_frames(), 3, "muted participant buffers nothing")
	p.queue_free()


func test_host_relays_voice_to_others_only() -> void:
	var server := LoopbackTransport.make_server()
	var h := RoomHost.new()
	runner.add_child(h)
	h.start(server, {"name": "V", "max_players": 4, "voice": true, "rules": {}}, "Host", 0)
	var got := {}
	var clients := []
	for i in 2:
		var c := RoomClient.new()
		c.transport_factory = func(_a, _p): return LoopbackTransport.make_client(server)
		runner.add_child(c)
		c.join("loop", 0, h.code, "P%d" % i, 1)
		clients.append(c)
	var t0 := Time.get_ticks_msec()
	while (clients[0].state != RoomClient.State.LOBBY or clients[1].state != RoomClient.State.LOBBY) and Time.get_ticks_msec() - t0 < 3000:
		await frames(1)
	for c in clients:
		got[c.pid] = []
		var cc: RoomClient = c
		c.transport.message.connect(func(_f, m): if m["k"] == "v": got[cc.pid].append(m))
	var pkt := ImaAdpcm.new().encode(_sine(640, 220.0, 0.3))
	clients[0].transport.send(1, {"k": "v", "s": 1, "d": pkt}, false)
	await frames(4)
	eq(got[clients[0].pid].size(), 0, "speaker does not get its own voice back")
	eq(got[clients[1].pid].size(), 1, "other player receives it")
	if got[clients[1].pid].size() == 1:
		eq(int(got[clients[1].pid][0]["f"]), clients[0].pid, "sender id attached by host")
	# a player who switched voice off receives nothing
	clients[1].transport.send(1, {"k": "vpref", "recv": false})
	await frames(3)
	clients[0].transport.send(1, {"k": "v", "s": 2, "d": pkt}, false)
	await frames(4)
	eq(got[clients[1].pid].size(), 1, "receive preference honoured")
	# voice disabled for the room: nothing relayed
	h.update_settings({"voice": false})
	clients[0].transport.send(1, {"k": "v", "s": 3, "d": pkt}, false)
	await frames(4)
	eq(got[clients[0].pid].size() + got[clients[1].pid].size(), 1, "no relay when room voice is off")
	# oversized packets dropped
	h.update_settings({"voice": true})
	clients[1].transport.send(1, {"k": "vpref", "recv": true})
	await frames(2)
	var big := PackedByteArray()
	big.resize(2000)
	clients[0].transport.send(1, {"k": "v", "s": 4, "d": big}, false)
	await frames(4)
	eq(got[clients[1].pid].size(), 1, "oversized voice packet dropped")
	for c in clients:
		c.queue_free()
	h.queue_free()
	await frames(2)


func test_local_mute_persists_by_name_only_locally() -> void:
	VoiceSettings.set_name_muted("Gürültücü", true)
	check(VoiceSettings.muted_names().has("Gürültücü"))
	VoiceSettings.set_name_muted("Gürültücü", false)
	check(not VoiceSettings.muted_names().has("Gürültücü"))
