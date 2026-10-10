class_name HelpDialog
extends RefCounted
## Rules & help. Text lives in the translation CSV (HELP_* keys) and mirrors
## what the RuleEngine actually enforces (see docs/GAME_RULES.md).

const SECTIONS := [
	["HELP_TAB_BASICS", "HELP_BASICS"],
	["HELP_TAB_ACTIONS", "HELP_ACTIONS"],
	["HELP_TAB_UNO", "HELP_UNO"],
	["HELP_TAB_WD4", "HELP_WD4"],
	["HELP_TAB_SCORING", "HELP_SCORING"],
	["HELP_TAB_HOUSE", "HELP_HOUSE"],
	["HELP_TAB_CONTROLS", "HELP_CONTROLS"],
]


static func open(start := 0) -> Control:
	var pv := Dialogs.titled_panel(TranslationServer.translate("HELP_TITLE"), 900)
	var v: VBoxContainer = pv[1]
	var tabs := UiKit.hbox(6)
	v.add_child(tabs)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.custom_minimum_size = Vector2(840, 400)
	text.add_theme_font_override("normal_font", UiKit.font(600))
	text.add_theme_font_override("bold_font", UiKit.font(850))
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	text.add_theme_color_override("default_color", Palette.TEXT)
	v.add_child(text)
	var buttons: Array[Button] = []
	for i in SECTIONS.size():
		var b := UiKit.button(TranslationServer.translate(SECTIONS[i][0]), UiKit.Variant.SECONDARY, Vector2(0, 46))
		b.add_theme_font_size_override("font_size", 17)
		buttons.append(b)
		tabs.add_child(b)
	var show := func(idx: int):
		text.text = TranslationServer.translate(SECTIONS[idx][1])
		text.scroll_to_line(0)
		for j in buttons.size():
			UiKit.style_button(buttons[j], UiKit.Variant.PRIMARY if j == idx else UiKit.Variant.SECONDARY)
	for i in buttons.size():
		var idx := i
		buttons[i].pressed.connect(func(): show.call(idx))
	show.call(start)
	var close := UiKit.button(TranslationServer.translate("BTN_CLOSE"), UiKit.Variant.PRIMARY, Vector2(220, 56))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	pv[0].set_meta("dismissable", true)
	var host := App.modal(pv[0])
	close.pressed.connect(host.close)
	return host
