class_name VoiceSettings
extends RefCounted
## Voice chat constants and the player's local voice preferences.

const SAMPLE_RATE := 16000
const FRAME_SAMPLES := 640          # 40 ms per packet (25 packets/s while talking)
const JITTER_FRAMES := 3            # ~120 ms of buffering before playback starts
const MAX_QUEUE_FRAMES := 12        # drop old audio beyond ~0.5 s of backlog
const VAD_THRESHOLD := 0.012        # RMS that counts as speech
const VAD_HANGOVER_MS := 350        # keep sending briefly after speech stops
const MAX_PACKET := 512


## Persistent per-player mute list (by display name — no global accounts).
static func muted_names() -> Dictionary:
	var social := Save.section("social")
	var out := {}
	for n in social.get("muted", []):
		out[str(n)] = true
	return out


static func set_name_muted(name: String, muted: bool) -> void:
	var social := Save.section("social")
	var list: Array = social.get("muted", [])
	if muted and not list.has(name):
		list.append(name)
	elif not muted:
		list.erase(name)
	social["muted"] = list
	Save.mark_dirty()


static func is_blocked(name: String) -> bool:
	return Save.section("social").get("blocked", []).has(name)
