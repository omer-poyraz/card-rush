extends Node
## Manual check: does the real microphone deliver audio through the voice
## pipeline?  godot --path . res://tools/mic_probe.tscn
## Prints captured frame counts, RMS and how many 40 ms packets passed VAD.

func _ready() -> void:
	get_tree().current_scene = null
	var sent := []
	var conn := MicProbeConn.new(sent)
	Voice.connection = conn
	Voice.room_enabled = true
	Voice._start_capture()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(3.0).timeout
	print("MIC_PROBE mic_on=%s mix_rate=%d packets_sent=%d level=%.3f error=%s" % [Voice.mic_on, AudioServer.get_mix_rate(), sent.size(), Voice.my_level, Voice.last_error])
	var dev := AudioServer.get_input_device_list()
	print("MIC_PROBE input devices: ", dev)
	Voice._stop_capture()
	get_tree().quit()


class MicProbeConn:
	extends VoiceConnection
	var log_: Array
	func _init(l: Array) -> void:
		log_ = l
	func send(seq: int, data: PackedByteArray) -> void:
		log_.append(seq)
	func valid() -> bool:
		return true
