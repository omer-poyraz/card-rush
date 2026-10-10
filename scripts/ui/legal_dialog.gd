class_name LegalDialog
extends RefCounted
## Shows the bundled legal texts (legal/<doc>_<lang>.txt). These are drafts
## shipped inside the app; no external URL is presented as live until it exists.


static func open(doc: String) -> Control:
	var titles := {"privacy": "SETTINGS_PRIVACY_POLICY", "terms": "SETTINGS_TERMS", "licenses": "SETTINGS_LICENSES"}
	var pv := Dialogs.titled_panel(TranslationServer.translate(titles.get(doc, "SETTINGS_ABOUT")), 900)
	var v: VBoxContainer = pv[1]
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(840, 430)
	text.add_theme_font_override("normal_font", UiKit.font(600))
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_color_override("default_color", Palette.TEXT_DIM)
	text.text = _load(doc)
	v.add_child(text)
	var close := UiKit.button(TranslationServer.translate("BTN_CLOSE"), UiKit.Variant.PRIMARY, Vector2(220, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	pv[0].set_meta("dismissable", true)
	var host := App.modal(pv[0])
	close.pressed.connect(host.close)
	return host


static func _load(doc: String) -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	for p in ["res://legal/%s_%s.txt" % [doc, lang], "res://legal/%s_en.txt" % doc]:
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return "-"
