extends Node
## Autoload "Audio". Separate Music / SFX / Voice buses so game sounds and
## voice chat are controlled independently. SFX use a small player pool.

const SFX_DIR := "res://assets/audio/"
const SFX := [
	"card_draw", "card_play", "card_special", "shuffle", "deal", "color_pick", "uno", "your_turn",
	"opponent_last", "penalty", "skip", "reverse", "round_win", "match_win", "lose", "button",
	"hover", "transition", "join", "leave", "caught", "reward",
]
const POOL := 8

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_key := ""
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	for k in SFX:
		var p: String = SFX_DIR + k + ".wav"
		if ResourceLoader.exists(p):
			_streams[k] = load(p)
	for i in POOL:
		var pl := AudioStreamPlayer.new()
		pl.bus = "SFX"
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()
	Settings.changed.connect(func(k): if k.ends_with("_volume"): apply_volumes())


func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	_set_bus("Music", float(Settings.get_value("music_volume")))
	_set_bus("SFX", float(Settings.get_value("sfx_volume")))
	_set_bus("Voice", float(Settings.get_value("voice_volume")))


func _set_bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## Plays an effect. Identical sounds within 40 ms are merged to avoid stacking.
func play(key: String, pitch_jitter := 0.0, volume_db := 0.0) -> void:
	if not _streams.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(key, -1000)) < 40:
		return
	_last_play[key] = now
	var pl: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			pl = p
			break
	if pl == null:
		pl = _pool[0]
	pl.stream = _streams[key]
	pl.volume_db = volume_db
	pl.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	pl.play()


func play_music(key: String) -> void:
	if key == _music_key and _music.playing:
		return
	_music_key = key
	var p := SFX_DIR + key + ".ogg"
	if not ResourceLoader.exists(p):
		_music.stop()
		return
	var s: AudioStream = load(p)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -30.0, 0.4)
	tw.tween_callback(func():
		_music.stream = s
		_music.volume_db = -30.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, 0.8)


func stop_music() -> void:
	_music_key = ""
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 0.5)
	tw.tween_callback(_music.stop)
