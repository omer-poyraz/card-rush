extends Node
## Autoload "Voice". Room voice chat, fully separate from the card game:
## the game runs the same with voice off. Capture: AudioStreamMicrophone on a
## muted "MicCapture" bus with an AudioEffectCapture → mono → 16 kHz →
## voice-activity detection → IMA ADPCM → room connection (unreliable).
## Mic OFF stops the microphone stream itself: nothing is captured or sent.
## Muting someone only affects playback on THIS device.

signal state_changed
signal participants_changed

const CAPTURE_BUS := "MicCapture"

var room_enabled := false          # the room allows voice
var mic_on := false
var deafened := false              # "mute everyone for me"
var participants := {}             # pid -> VoiceParticipant
var names := {}                    # pid -> display name
var my_level := 0.0
var connection: VoiceConnection
var last_error := ""

var _encoder := ImaAdpcm.new()
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _pcm := PackedFloat32Array()
var _resample_pos := 0.0
var _prev_sample := 0.0
var _seq := 0
var _last_speech_ms := -100000
var _noise_floor := 0.004          # adaptive background-noise estimate (RMS)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus()


func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index(CAPTURE_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, CAPTURE_BUS)
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture)
		AudioServer.set_bus_mute(idx, true)  # never play your own mic back
	else:
		_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture


## The player's global switch (Settings) AND the room setting.
func enabled() -> bool:
	return Features.available("voice") and bool(Settings.get_value("voice_enabled")) and room_enabled and connection != null and connection.valid()


func attach(conn: VoiceConnection, room_voice: bool) -> void:
	connection = conn
	room_enabled = room_voice
	if connection:
		connection.set_receive(bool(Settings.get_value("voice_enabled")) and room_voice)
	state_changed.emit()


func detach() -> void:
	set_mic(false)
	connection = null
	room_enabled = false
	for p in participants.values():
		p.queue_free()
	participants.clear()
	names.clear()
	state_changed.emit()
	participants_changed.emit()


func set_room_enabled(on: bool) -> void:
	if room_enabled == on:
		return
	room_enabled = on
	if not on:
		set_mic(false)
	if connection:
		connection.set_receive(on and bool(Settings.get_value("voice_enabled")))
	state_changed.emit()


func update_roster(roster: Dictionary) -> void:
	names = roster.duplicate()
	for pid in participants.keys():
		if not names.has(pid):
			participants[pid].queue_free()
			participants.erase(pid)
	var muted_names := VoiceSettings.muted_names()
	for pid in participants:
		var n: String = names.get(pid, "")
		participants[pid].display_name = n
		participants[pid].muted = muted_names.has(n) or VoiceSettings.is_blocked(n)
	participants_changed.emit()


# --- microphone --------------------------------------------------------------------

## Turns the microphone on/off. Permission is requested only now; a refusal
## simply leaves the mic off — the game continues normally.
func set_mic(on: bool) -> void:
	if on == mic_on:
		return
	if on:
		if not enabled():
			return
		VoicePermissionManager.request(get_tree(), func(granted: bool):
			if not granted:
				last_error = "VOICE_PERMISSION_DENIED"
				mic_on = false
				state_changed.emit()
				return
			_start_capture())
	else:
		_stop_capture()


func _start_capture() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		last_error = "VOICE_INPUT_DISABLED"
		state_changed.emit()
		return
	if _mic_player == null:
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = CAPTURE_BUS
		add_child(_mic_player)
	_capture.clear_buffer()
	_pcm.clear()
	_mic_player.play()
	mic_on = true
	last_error = ""
	state_changed.emit()


func _stop_capture() -> void:
	if _mic_player:
		_mic_player.stop()  # releases the microphone stream
	mic_on = false
	my_level = 0.0
	_pcm.clear()
	if _capture:
		_capture.clear_buffer()
	state_changed.emit()


func set_deafened(on: bool) -> void:
	deafened = on
	if on:
		for p in participants.values():
			p._queue.clear()
	state_changed.emit()


func _process(dt: float) -> void:
	my_level = maxf(0.0, my_level - dt * 2.5)
	if not mic_on:
		return
	if not enabled():
		_stop_capture()
		return
	var avail := _capture.get_frames_available()
	if avail <= 0:
		return
	var buf := _capture.get_buffer(avail)
	_append_resampled(buf, AudioServer.get_mix_rate())
	while _pcm.size() >= VoiceSettings.FRAME_SAMPLES:
		var frame := _pcm.slice(0, VoiceSettings.FRAME_SAMPLES)
		_pcm = _pcm.slice(VoiceSettings.FRAME_SAMPLES)
		submit_frame(frame)


## Downmix to mono and resample (linear) from the mix rate to 16 kHz.
func _append_resampled(buf: PackedVector2Array, src_rate: float) -> void:
	var step := src_rate / VoiceSettings.SAMPLE_RATE
	var n := buf.size()
	var pos := _resample_pos
	while pos < n:
		var i := int(pos)
		var frac := pos - i
		var a := _prev_sample if i == 0 else (buf[i - 1].x + buf[i - 1].y) * 0.5
		var b := (buf[i].x + buf[i].y) * 0.5
		_pcm.append(lerpf(a, b, frac))
		pos += step
	_resample_pos = pos - n
	if n > 0:
		_prev_sample = (buf[n - 1].x + buf[n - 1].y) * 0.5


## Voice-activity gate + encode + send. Public so tests can inject frames.
func submit_frame(frame: PackedFloat32Array) -> bool:
	var sum := 0.0
	for s in frame:
		sum += s * s
	var rms := sqrt(sum / maxf(1.0, frame.size()))
	my_level = maxf(my_level, clampf(rms * 8.0, 0.0, 1.0))
	var now := Time.get_ticks_msec()
	# follow the room's background noise: fast down, slow up
	if rms < _noise_floor:
		_noise_floor = lerpf(_noise_floor, rms, 0.3)
	else:
		_noise_floor = minf(_noise_floor + (rms - _noise_floor) * 0.01, 0.08)
	if rms >= maxf(VoiceSettings.VAD_THRESHOLD, _noise_floor * 2.5):
		_last_speech_ms = now
	_seq += 1
	if now - _last_speech_ms > VoiceSettings.VAD_HANGOVER_MS or connection == null:
		return false
	connection.send(_seq, _encoder.encode(frame))
	return true


# --- incoming ----------------------------------------------------------------------

func receive(pid: int, seq: int, data: PackedByteArray) -> void:
	if not enabled() or deafened or data.size() > VoiceSettings.MAX_PACKET:
		return
	if connection and pid == connection.my_pid():
		return
	var p := participant(pid)
	var samples := ImaAdpcm.decode(data)
	if samples.is_empty():
		return
	p.push(seq, samples)


func participant(pid: int) -> VoiceParticipant:
	if participants.has(pid):
		return participants[pid]
	var p := VoiceParticipant.new()
	p.pid = pid
	p.display_name = names.get(pid, "")
	var muted_names := VoiceSettings.muted_names()
	p.muted = muted_names.has(p.display_name) or VoiceSettings.is_blocked(p.display_name)
	add_child(p)
	participants[pid] = p
	participants_changed.emit()
	return p


func level_for(pid: int) -> float:
	if connection and pid == connection.my_pid():
		return my_level if mic_on else 0.0
	return participants[pid].level if participants.has(pid) and not participants[pid].muted else 0.0


func set_muted(pid: int, muted: bool, remember := false) -> void:
	var p := participant(pid)
	p.muted = muted
	if muted:
		p._queue.clear()
	if remember and p.display_name != "":
		VoiceSettings.set_name_muted(p.display_name, muted)
	participants_changed.emit()


func set_volume(pid: int, v: float) -> void:
	participant(pid).volume = v
