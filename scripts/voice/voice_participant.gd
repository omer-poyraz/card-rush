class_name VoiceParticipant
extends Node
## Playback of one remote speaker: a small jitter buffer ordered by sequence
## number feeding an AudioStreamGenerator on the "Voice" bus. Volume and mute
## are local to this device only.

var pid := -1
var display_name := ""
var volume := 1.0:
	set(v):
		volume = clampf(v, 0.0, 2.0)
		if _player:
			_player.volume_db = linear_to_db(maxf(volume, 0.001))
var muted := false
var level := 0.0                 # 0..1 speaking indicator (decays)

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _queue := {}                 # seq -> PackedFloat32Array
var _next_seq := -1
var _started := false
var _last_rx_ms := 0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = VoiceSettings.SAMPLE_RATE
	gen.buffer_length = 0.4
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "Voice"
	_player.volume_db = linear_to_db(maxf(volume, 0.001))
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


## A decoded frame arrived (seq increases by 1 per 40 ms frame).
func push(seq: int, samples: PackedFloat32Array) -> void:
	_last_rx_ms = Time.get_ticks_msec()
	var peak := 0.0
	for i in range(0, samples.size(), 8):
		peak = maxf(peak, absf(samples[i]))
	level = maxf(level, clampf(peak * 3.0, 0.0, 1.0))
	if muted:
		return
	if _next_seq >= 0 and seq < _next_seq:
		return  # late or duplicate
	_queue[seq] = samples
	if _queue.size() > VoiceSettings.MAX_QUEUE_FRAMES:
		var keys := _queue.keys()
		keys.sort()
		for k in keys.slice(0, keys.size() - VoiceSettings.JITTER_FRAMES):
			_queue.erase(k)
		_next_seq = -1


func _process(dt: float) -> void:
	level = maxf(0.0, level - dt * 2.5)
	if _playback == null:
		return
	if not _started:
		if _queue.size() >= VoiceSettings.JITTER_FRAMES:
			_started = true
		else:
			return
	while _playback.get_frames_available() >= VoiceSettings.FRAME_SAMPLES:
		if _queue.is_empty():
			_started = false
			_next_seq = -1
			return
		if _next_seq < 0 or not _queue.has(_next_seq):
			var keys := _queue.keys()
			keys.sort()
			_next_seq = keys[0]
		var frame: PackedFloat32Array = _queue[_next_seq]
		_queue.erase(_next_seq)
		_next_seq += 1
		var stereo := PackedVector2Array()
		stereo.resize(frame.size())
		for i in frame.size():
			stereo[i] = Vector2(frame[i], frame[i])
		_playback.push_buffer(stereo)


func queued_frames() -> int:
	return _queue.size()
