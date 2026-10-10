extends Control
## Local profile: name, avatar, level/XP and statistics. Stored on this device
## only (no global account — see docs/DECISIONS.md).

var _name_edit: LineEdit
var _avatar_buttons: Array = []


func _ready() -> void:
	add_child(Backdrop.new())
	var prof := Save.section("profile")
	var st := Save.section("stats")
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
	top.add_child(UiKit.title(tr("MENU_PROFILE"), 40))

	var body := UiKit.hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	# identity
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := UiKit.vbox(12)
	left.add_child(lv)
	var idrow := UiKit.hbox(16)
	lv.add_child(idrow)
	var big := AvatarView.new()
	big.avatar = int(prof.get("avatar", 0))
	big.ring_color = Palette.ELECTRIC
	big.custom_minimum_size = Vector2(110, 110)
	idrow.add_child(big)
	var idv := UiKit.vbox(6)
	idv.alignment = BoxContainer.ALIGNMENT_CENTER
	idrow.add_child(idv)
	var lvl := Progression.level_info(int(prof.get("xp", 0)))
	idv.add_child(UiKit.label(Loc.t("PROFILE_LEVEL_N", [lvl["level"]]), 28, Palette.SUN, 800, true))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 14)
	bar.show_percentage = false
	bar.max_value = lvl["need"]
	bar.value = lvl["into"]
	bar.add_theme_stylebox_override("background", UiKit.flat(Color(1, 1, 1, 0.08), 7))
	bar.add_theme_stylebox_override("fill", UiKit.flat(Palette.TEAL, 7))
	idv.add_child(bar)
	idv.add_child(UiKit.label("%d / %d XP" % [lvl["into"], lvl["need"]], 16, Palette.TEXT_DIM, 700))

	lv.add_child(UiKit.label(tr("PROFILE_NAME"), 18, Palette.TEXT_DIM, 700))
	var nrow := UiKit.hbox(10)
	lv.add_child(nrow)
	_name_edit = LineEdit.new()
	_name_edit.text = str(prof.get("name", ""))
	_name_edit.max_length = NameFilter.MAX_LEN
	_name_edit.custom_minimum_size = Vector2(300, 54)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(_name_edit)
	var save := UiKit.button(tr("BTN_SAVE"), UiKit.Variant.PRIMARY, Vector2(130, 54))
	save.pressed.connect(_save_name)
	_name_edit.text_submitted.connect(func(_t): _save_name())
	nrow.add_child(save)

	lv.add_child(UiKit.label(tr("PROFILE_AVATAR"), 18, Palette.TEXT_DIM, 700))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	lv.add_child(grid)
	for i in AvatarView.COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var av := AvatarView.new()
		av.avatar = i
		av.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		av.ring_color = Palette.SUN if i == int(prof.get("avatar", 0)) else Color.TRANSPARENT
		b.add_child(av)
		var idx := i
		b.pressed.connect(func():
			prof["avatar"] = idx
			Save.mark_dirty()
			big.avatar = idx
			Audio.play("button")
			for j in _avatar_buttons.size():
				_avatar_buttons[j].ring_color = Palette.SUN if j == idx else Color.TRANSPARENT)
		_avatar_buttons.append(av)
		grid.add_child(b)

	# stats
	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	var rv := UiKit.vbox(8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(rv)
	rv.add_child(UiKit.label(tr("PROFILE_STATS").to_upper(), 16, Palette.ELECTRIC, 800))
	var played := int(st.get("played", 0))
	_stat(rv, "STAT_PLAYED", str(played))
	_stat(rv, "STAT_WON", str(int(st.get("won", 0))))
	_stat(rv, "STAT_WIN_RATE", "%d%%" % roundi(Progression.win_rate(st) * 100.0))
	_stat(rv, "STAT_BEST_STREAK", str(int(st.get("best_streak", 0))))
	_stat(rv, "STAT_CARDS_PLAYED", str(int(st.get("cards_played", 0))))
	_stat(rv, "STAT_UNO_CALLS", str(int(st.get("uno_calls", 0))))
	_stat(rv, "STAT_CATCHES", str(int(st.get("catches", 0))))
	var by: Dictionary = st.get("by_level", {})
	for k in [["0", "BOT_EASY"], ["1", "BOT_NORMAL"], ["2", "BOT_HARD"]]:
		var pair: Array = by.get(k[0], [0, 0])
		_stat(rv, "", "%d / %d" % [int(pair[1]), int(pair[0])], Loc.t("STAT_VS_BOTS", [tr(k[1])]))
	_stat(rv, "STAT_ONLINE", "%d / %d" % [int(st.get("online_won", 0)), int(st.get("online_played", 0))])
	rv.add_child(UiKit.spacer(8))
	rv.add_child(UiKit.label(tr("PROFILE_HISTORY").to_upper(), 16, Palette.ELECTRIC, 800))
	var hist: Array = st.get("history", [])
	if hist.is_empty():
		rv.add_child(UiKit.label(tr("PROFILE_NO_HISTORY"), 17, Palette.TEXT_MUTED, 600))
	for h in hist.slice(0, 10):
		var d := Time.get_datetime_dict_from_unix_time(int(h.get("t", 0)))
		var line := "%02d.%02d  %02d:%02d   %s   ·   %s" % [d["day"], d["month"], d["hour"], d["minute"],
			tr("HIST_WIN") if h.get("won", false) else tr("HIST_LOSS"), Loc.t("HIST_PLAYERS", [int(h.get("players", 0))])]
		rv.add_child(UiKit.label(line, 17, Palette.SUCCESS if h.get("won", false) else Palette.TEXT_DIM, 700))
	rv.add_child(UiKit.spacer(8))
	var note := UiKit.label(tr("PROFILE_LOCAL_NOTE"), 15, Palette.TEXT_MUTED, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(note)


func _stat(parent: Control, key: String, value: String, label_text := "") -> void:
	var h := UiKit.hbox(10)
	parent.add_child(h)
	var l := UiKit.label(label_text if label_text != "" else tr(key), 19, Palette.TEXT, 650)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UiKit.label(value, 21, Palette.SUN, 800, true))


func _save_name() -> void:
	var err := NameFilter.validate(_name_edit.text)
	if err != "":
		App.toast(tr(err), Palette.CORAL)
		return
	Save.section("profile")["name"] = NameFilter.clean(_name_edit.text)
	_name_edit.text = NameFilter.clean(_name_edit.text)
	Save.mark_dirty()
	App.toast(tr("PROFILE_SAVED"), Palette.SUCCESS)


func handle_back() -> void:
	App.goto("menu")
