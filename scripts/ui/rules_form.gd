class_name RulesForm
extends VBoxContainer
## Editable rule profile (classic settings + clearly separated house rules).
## Shared by the bot setup screen and the room creation screen.

signal changed

var profile := RuleProfile.classic()
var _summary: Label


func _init(p: RuleProfile = null) -> void:
	if p:
		profile = p
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	_build()


func _t(k: String) -> String:
	return TranslationServer.translate(k)


func _row(key: String, control: Control, tip_key := "") -> void:
	var h := UiKit.hbox(10)
	add_child(h)
	var l := UiKit.label(_t(key), 19, Palette.TEXT, 700)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	if tip_key != "":
		l.tooltip_text = _t(tip_key)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	h.add_child(control)


func _header(key: String, color: Color) -> void:
	add_child(UiKit.spacer(4))
	add_child(UiKit.label(_t(key).to_upper(), 16, color, 800))


func _build() -> void:
	_header("RULES_CLASSIC_SECTION", Palette.ELECTRIC)
	var mode := Segmented.new([_t("RULES_MODE_SINGLE"), _t("RULES_MODE_POINTS"), _t("RULES_MODE_LOW")], profile.scoring_mode, 110, 16)
	mode.changed.connect(func(i):
		profile.scoring_mode = i
		_emit())
	_row("RULES_MODE", mode)
	var target := Segmented.Stepper.new(profile.target_score, 100, 1000, 50)
	target.changed.connect(func(v):
		profile.target_score = v
		_emit())
	_row("RULES_TARGET", target)
	var wd4 := Segmented.new([_t("RULES_WD4_CHALLENGE"), _t("RULES_WD4_STRICT")], profile.wd4_mode, 130)
	wd4.changed.connect(func(i):
		profile.wd4_mode = i
		_emit())
	_row("RULES_WD4", wd4, "RULES_WD4_TIP")
	var pen := Segmented.new(["2", "4"], 0 if profile.uno_penalty == 2 else 1, 60)
	pen.changed.connect(func(i):
		profile.uno_penalty = [2, 4][i]
		_emit())
	_row("RULES_UNO_PENALTY", pen)
	var windows := [2000, 4000, 6000]
	var win := Segmented.new([Loc.t("UNIT_SECONDS_N", [2]), Loc.t("UNIT_SECONDS_N", [4]), Loc.t("UNIT_SECONDS_N", [6])], maxi(0, windows.find(profile.uno_catch_window_ms)), 70)
	win.changed.connect(func(i):
		profile.uno_catch_window_ms = windows[i]
		_emit())
	_row("RULES_UNO_WINDOW", win)
	var timers := [0, 15, 30, 60]
	var tt := Segmented.new([_t("RULES_TIMER_OFF"), Loc.t("UNIT_SECONDS_N", [15]), Loc.t("UNIT_SECONDS_N", [30]), Loc.t("UNIT_SECONDS_N", [60])], maxi(0, timers.find(profile.turn_time_s)), 70, 16)
	tt.changed.connect(func(i):
		profile.turn_time_s = timers[i]
		_emit())
	_row("RULES_TURN_TIMER", tt)

	_header("RULES_HOUSE_SECTION", Palette.SUN)
	var note := UiKit.label(_t("RULES_HOUSE_NOTE"), 16, Palette.TEXT_DIM, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	for k in ["stack_draw_two", "stack_draw_four", "stack_mixed", "seven_zero", "auto_play_drawn"]:
		var c := CheckButton.new()
		c.button_pressed = bool(profile.get(k))
		var key: String = k
		c.toggled.connect(func(on):
			profile.set(key, on)
			_emit())
		_row("HOUSE_" + k.to_upper(), c, "HOUSE_" + k.to_upper() + "_TIP")
	var fc := CheckButton.new()
	fc.button_pressed = profile.first_card_mode == RuleProfile.FirstCardMode.NUMBER_ONLY
	fc.toggled.connect(func(on):
		profile.first_card_mode = RuleProfile.FirstCardMode.NUMBER_ONLY if on else RuleProfile.FirstCardMode.OFFICIAL
		_emit())
	_row("HOUSE_FIRST_CARD_MODE", fc, "HOUSE_FIRST_CARD_MODE_TIP")
	_summary = UiKit.label("", 17, Palette.TEXT_DIM, 700)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_update_summary()


func _emit() -> void:
	_update_summary()
	changed.emit()


func _update_summary() -> void:
	if _summary == null:
		return
	_summary.text = summary_text(profile)


static func summary_text(p: RuleProfile) -> String:
	var house := p.active_house_rules()
	if house.is_empty():
		return TranslationServer.translate("RULES_SUMMARY_CLASSIC")
	var names := []
	for k in house:
		names.append(TranslationServer.translate("HOUSE_" + k.to_upper()))
	return TranslationServer.translate("RULES_SUMMARY_HOUSE") % ", ".join(names)
