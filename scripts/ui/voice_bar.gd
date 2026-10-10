class_name VoiceBar
extends HBoxContainer
## Voice chat controls: microphone, "mute everyone for me" and the per-player
## panel. Hidden when voice is unavailable (room setting, global switch).
## While the microphone is live a red "Mic on" badge is always visible.

var _mic: Button
var _deaf: Button
var _people: Button
var _live: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_live = UiKit.label(tr("VOICE_MIC_LIVE"), 15, Color.WHITE, 800)
	var sb := UiKit.flat(Palette.DANGER, 10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_live.add_theme_stylebox_override("normal", sb)
	_live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_live)
	_mic = UiKit.icon_button("mic_off", tr("VOICE_MIC"), 52)
	_mic.pressed.connect(func():
		Voice.set_mic(not Voice.mic_on)
		if VoicePermissionManager.denied:
			App.toast(tr("VOICE_PERMISSION_DENIED"), Palette.SUN, 4.0))
	add_child(_mic)
	_deaf = UiKit.icon_button("speaker", tr("VOICE_DEAFEN"), 52)
	_deaf.pressed.connect(func(): Voice.set_deafened(not Voice.deafened))
	add_child(_deaf)
	_people = UiKit.icon_button("friends", tr("VOICE_PLAYERS"), 52)
	_people.pressed.connect(func(): VoicePanel.open())
	add_child(_people)
	Voice.state_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = Voice.enabled()
	_live.visible = Voice.mic_on
	(_mic.get_child(0) as IconView).icon = "mic" if Voice.mic_on else "mic_off"
	UiKit.style_button(_mic, UiKit.Variant.DANGER if Voice.mic_on else UiKit.Variant.SECONDARY)
	(_deaf.get_child(0) as IconView).icon = "speaker_off" if Voice.deafened else "speaker"
	if Voice.last_error != "":
		App.toast(tr(Voice.last_error), Palette.SUN, 4.0)
		Voice.last_error = ""
