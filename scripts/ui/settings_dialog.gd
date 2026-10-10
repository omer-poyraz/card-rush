class_name SettingsDialog
extends RefCounted
## Settings modal. Every control writes through Settings, which persists and
## applies immediately (volumes, language, motion, colour-blind palette...).


static func open() -> Control:
	var pv := Dialogs.titled_panel(TranslationServer.translate("SETTINGS_TITLE"), 760)
	var v: VBoxContainer = pv[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := UiKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_section(body, "SETTINGS_SOUND")
	_slider(body, "SETTINGS_MUSIC", "music_volume")
	_slider(body, "SETTINGS_SFX", "sfx_volume")
	if Features.available("voice"):
		_slider(body, "SETTINGS_VOICE", "voice_volume")
		_toggle(body, "SETTINGS_VOICE_ENABLED", "voice_enabled")

	_section(body, "SETTINGS_LANGUAGE")
	var langs := UiKit.hbox(10)
	body.add_child(langs)
	for l in [["tr", "Türkçe"], ["en", "English"]]:
		var b := UiKit.button(l[1], UiKit.Variant.PRIMARY if Loc.language() == l[0] else UiKit.Variant.SECONDARY, Vector2(170, 54))
		var code: String = l[0]
		b.pressed.connect(func():
			Loc.set_language(code)
			App.toast(TranslationServer.translate("SETTINGS_LANGUAGE_CHANGED")))
		langs.add_child(b)

	_section(body, "SETTINGS_GAMEPLAY")
	_toggle(body, "SETTINGS_ONE_TAP", "one_tap_play")
	_toggle(body, "SETTINGS_HINTS", "show_hints")
	_choice(body, "SETTINGS_BOT_SPEED", "bot_speed", ["BOT_SPEED_0", "BOT_SPEED_1", "BOT_SPEED_2"])

	_section(body, "SETTINGS_DISPLAY")
	_choice(body, "SETTINGS_QUALITY", "quality", ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"])
	_choice(body, "SETTINGS_ANIMATION", "animation", ["ANIM_FULL", "ANIM_REDUCED"])
	_toggle(body, "SETTINGS_SHAKE", "screen_shake")
	_toggle(body, "SETTINGS_COLORBLIND", "colorblind")
	_toggle(body, "SETTINGS_HAPTICS", "haptics")

	_section(body, "SETTINGS_ONLINE")
	var on_note := UiKit.label(TranslationServer.translate("SETTINGS_SIGNALING_NOTE"), 16, Palette.TEXT_DIM, 600)
	on_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(on_note)
	var url_edit := LineEdit.new()
	url_edit.placeholder_text = "wss://…/ws"
	url_edit.text = str(Save.section("net").get("signaling_url", ""))
	url_edit.text_changed.connect(func(t: String):
		var clean := t.strip_edges()
		if clean == "" or clean.begins_with("ws://") or clean.begins_with("wss://"):
			Save.section("net")["signaling_url"] = clean
			Save.mark_dirty())
	body.add_child(url_edit)

	_section(body, "SETTINGS_PRIVACY")
	_toggle(body, "SETTINGS_NOTIFICATIONS", "notifications")
	var priv := UiKit.label(TranslationServer.translate("SETTINGS_PRIVACY_NOTE"), 17, Palette.TEXT_DIM, 600)
	priv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(priv)
	var docs := UiKit.hbox(10)
	body.add_child(docs)
	var pp := UiKit.button(TranslationServer.translate("SETTINGS_PRIVACY_POLICY"), UiKit.Variant.GHOST, Vector2(0, 50))
	pp.pressed.connect(func(): LegalDialog.open("privacy"))
	docs.add_child(pp)
	var tos := UiKit.button(TranslationServer.translate("SETTINGS_TERMS"), UiKit.Variant.GHOST, Vector2(0, 50))
	tos.pressed.connect(func(): LegalDialog.open("terms"))
	docs.add_child(tos)
	var lic := UiKit.button(TranslationServer.translate("SETTINGS_LICENSES"), UiKit.Variant.GHOST, Vector2(0, 50))
	lic.pressed.connect(func(): LegalDialog.open("licenses"))
	docs.add_child(lic)

	_section(body, "SETTINGS_ABOUT")
	body.add_child(UiKit.label("Card Rush v%s  ·  Poyraz Yazılım" % ProjectSettings.get_setting("application/config/version"), 18, Palette.TEXT_DIM))
	body.add_child(UiKit.label(TranslationServer.translate("SETTINGS_PREMIUM_STATUS_NONE"), 17, Palette.TEXT_MUTED))

	var close := UiKit.button(TranslationServer.translate("BTN_CLOSE"), UiKit.Variant.PRIMARY, Vector2(220, 58))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	var host := App.modal(pv[0])
	pv[0].set_meta("dismissable", true)
	close.pressed.connect(host.close)
	return host


static func _section(body: VBoxContainer, key: String) -> void:
	body.add_child(UiKit.spacer(6))
	var l := UiKit.label(TranslationServer.translate(key).to_upper(), 17, Palette.ELECTRIC, 800)
	body.add_child(l)


static func _row(body: VBoxContainer, key: String) -> HBoxContainer:
	var h := UiKit.hbox(12)
	body.add_child(h)
	var l := UiKit.label(TranslationServer.translate(key), 21, Palette.TEXT, 650)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


static func _slider(body: VBoxContainer, key: String, setting: String) -> void:
	var h := _row(body, key)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get_value(setting))
	s.custom_minimum_size = Vector2(300, 36)
	s.value_changed.connect(func(x): Settings.set_value(setting, x))
	if setting == "sfx_volume":
		s.drag_ended.connect(func(_c): Audio.play("card_play"))
	h.add_child(s)


static func _toggle(body: VBoxContainer, key: String, setting: String) -> void:
	var h := _row(body, key)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(setting))
	c.toggled.connect(func(on):
		Settings.set_value(setting, on)
		Audio.play("button"))
	h.add_child(c)


static func _choice(body: VBoxContainer, key: String, setting: String, options: Array) -> void:
	var h := _row(body, key)
	var group := UiKit.hbox(6)
	h.add_child(group)
	var buttons: Array[Button] = []
	for i in options.size():
		var b := UiKit.button(TranslationServer.translate(options[i]), UiKit.Variant.SECONDARY, Vector2(110, 46))
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.button_pressed = int(Settings.get_value(setting)) == i
		buttons.append(b)
		group.add_child(b)
	for i in buttons.size():
		var idx := i
		buttons[i].pressed.connect(func():
			Settings.set_value(setting, idx)
			for j in buttons.size():
				buttons[j].set_pressed_no_signal(j == idx)
				UiKit.style_button(buttons[j], UiKit.Variant.PRIMARY if j == idx else UiKit.Variant.SECONDARY))
		if buttons[i].button_pressed:
			UiKit.style_button(buttons[i], UiKit.Variant.PRIMARY)
