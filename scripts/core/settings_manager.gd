extends Node
## Autoload "Settings". Typed access to user settings stored in Save.data.settings.

signal changed(key: String)

const DEFAULTS := {
	"language": "",            # "" = follow device on first run
	"music_volume": 0.6,
	"sfx_volume": 0.85,
	"voice_volume": 1.0,
	"animation": 0,            # 0 full, 1 reduced
	"quality": 1,              # 0 low, 1 medium, 2 high
	"haptics": true,
	"colorblind": false,
	"notifications": true,
	"one_tap_play": false,
	"show_hints": true,
	"bot_speed": 1,            # 0 relaxed, 1 normal, 2 fast
	"screen_shake": true,
	"ad_personalization": false,  # only meaningful after the consent flow (Stage 7)
	"voice_enabled": true,        # global voice chat switch (separate from game sounds)
}


func _ready() -> void:
	var s := Save.section("settings")
	for k in DEFAULTS:
		if not s.has(k) or typeof(s[k]) != typeof(DEFAULTS[k]) and not (DEFAULTS[k] is float and s[k] is int):
			s[k] = DEFAULTS[k]
	if OS.has_feature("mobile") and not Save.section("flags").has("quality_set"):
		s["quality"] = 1


func get_value(key: String) -> Variant:
	return Save.section("settings").get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	var s := Save.section("settings")
	if s.get(key) == value:
		return
	s[key] = value
	if key == "quality":
		Save.section("flags")["quality_set"] = true
	Save.mark_dirty()
	changed.emit(key)


func reduced_motion() -> bool:
	return int(get_value("animation")) == 1


func quality() -> int:
	return int(get_value("quality"))


## Multiplier for animation durations.
func anim_scale() -> float:
	return 0.45 if reduced_motion() else 1.0


func vibrate(ms := 30) -> void:
	if bool(get_value("haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
