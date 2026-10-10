class_name VoicePanel
extends RefCounted
## Per-player voice controls. Every change applies ONLY on this device.


static func open() -> Control:
	var pv := Dialogs.titled_panel(TranslationServer.translate("VOICE_PLAYERS"), 640)
	var v: VBoxContainer = pv[1]
	var note := UiKit.label(TranslationServer.translate("VOICE_LOCAL_NOTE"), 16, Palette.TEXT_DIM, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 580
	v.add_child(note)
	var me := Voice.connection.my_pid() if Voice.connection else -1
	var any := false
	var pids := Voice.names.keys()
	pids.sort()
	for pid in pids:
		if pid == me:
			continue
		any = true
		var p := Voice.participant(pid)
		var row := UiKit.hbox(10)
		v.add_child(row)
		var name := UiKit.label(str(Voice.names[pid]), 20, Palette.TEXT, 800)
		name.custom_minimum_size.x = 170
		name.clip_text = true
		row.add_child(name)
		var vol := HSlider.new()
		vol.min_value = 0.0
		vol.max_value = 2.0
		vol.step = 0.05
		vol.value = p.volume
		vol.custom_minimum_size = Vector2(170, 34)
		vol.value_changed.connect(func(x): Voice.set_volume(pid, x))
		row.add_child(vol)
		var mute := CheckButton.new()
		mute.text = TranslationServer.translate("VOICE_MUTE")
		mute.button_pressed = p.muted
		row.add_child(mute)
		var always := CheckButton.new()
		always.text = TranslationServer.translate("VOICE_ALWAYS")
		always.button_pressed = VoiceSettings.muted_names().has(p.display_name)
		always.tooltip_text = TranslationServer.translate("VOICE_ALWAYS_TIP")
		row.add_child(always)
		var id: int = pid
		mute.toggled.connect(func(on): Voice.set_muted(id, on, false))
		always.toggled.connect(func(on):
			mute.set_pressed_no_signal(on or mute.button_pressed)
			Voice.set_muted(id, on or mute.button_pressed, true))
	if not any:
		v.add_child(UiKit.label(TranslationServer.translate("VOICE_NOBODY"), 18, Palette.TEXT_MUTED, 600))
	var close := UiKit.button(TranslationServer.translate("BTN_CLOSE"), UiKit.Variant.PRIMARY, Vector2(220, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	pv[0].set_meta("dismissable", true)
	var host := App.modal(pv[0])
	close.pressed.connect(host.close)
	return host
