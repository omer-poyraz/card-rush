extends Control
## "Play vs Bots" setup: player count, bot difficulty and the rule profile.
## Fully offline — no network needed.

var _players: Segmented.Stepper
var _difficulty: Segmented
var _form: RulesForm


func _ready() -> void:
	add_child(Backdrop.new())
	var saved := Save.section("bot_setup")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := UiKit.vbox(14)
	margin.add_child(col)

	var top := UiKit.hbox(14)
	col.add_child(top)
	var back := UiKit.icon_button("back", tr("BTN_BACK"), 58)
	back.pressed.connect(handle_back)
	top.add_child(back)
	top.add_child(UiKit.title(tr("MENU_BOTS"), 40))

	var body := UiKit.hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# left: table setup
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := UiKit.vbox(14)
	left.add_child(lv)
	lv.add_child(UiKit.label(tr("SETUP_TABLE").to_upper(), 16, Palette.ELECTRIC, 800))
	var h1 := UiKit.hbox(10)
	lv.add_child(h1)
	var l1 := UiKit.label(tr("SETUP_PLAYERS"), 20, Palette.TEXT, 700)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(l1)
	_players = Segmented.Stepper.new(int(saved.get("players", 4)), 2, 10)
	h1.add_child(_players)
	lv.add_child(UiKit.label(tr("SETUP_PLAYERS_NOTE"), 16, Palette.TEXT_DIM, 600))
	lv.add_child(UiKit.label(tr("SETUP_DIFFICULTY"), 20, Palette.TEXT, 700))
	_difficulty = Segmented.new([tr("BOT_EASY"), tr("BOT_NORMAL"), tr("BOT_HARD"), tr("BOT_MIXED")], int(saved.get("difficulty", 1)), 112)
	lv.add_child(_difficulty)
	var desc := UiKit.label("", 16, Palette.TEXT_DIM, 600)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 420
	lv.add_child(desc)
	var set_desc := func(i): desc.text = tr(["BOT_EASY_DESC", "BOT_NORMAL_DESC", "BOT_HARD_DESC", "BOT_MIXED_DESC"][i])
	set_desc.call(_difficulty.index)
	_difficulty.changed.connect(set_desc)
	lv.add_child(UiKit.spacer())
	var start := UiKit.button(tr("SETUP_START"), UiKit.Variant.ACCENT, Vector2(0, 76))
	start.add_theme_font_size_override("font_size", 30)
	start.pressed.connect(_start)
	lv.add_child(start)

	# right: rules (scrollable)
	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_form = RulesForm.new(RuleProfile.from_dict(saved.get("profile", {})))
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	start.grab_focus.call_deferred()


func _start() -> void:
	var n := _players.value
	var err := _form.profile.validate_player_count(n)
	if err != "":
		App.toast(Loc.error_text(err), Palette.CORAL)
		return
	var levels := []
	for i in n - 1:
		levels.append(i % 3 if _difficulty.index == 3 else _difficulty.index)
	var s := Save.section("bot_setup")
	s["players"] = n
	s["difficulty"] = _difficulty.index
	s["profile"] = _form.profile.to_dict()
	Save.mark_dirty()
	App.goto("table", {"mode": "offline", "profile": _form.profile.to_dict(), "bots": levels, "return_to": "bot_setup"})


func handle_back() -> void:
	App.goto("menu")
