extends Control
## Main menu. Built in code from UiKit pieces so every string goes through tr().

var _floaters: Array[CardView] = []
var _t := 0.0
var _profile_chip: Button


func _ready() -> void:
	add_child(Backdrop.new())
	if Settings.quality() > 0:
		_add_floating_cards()
	_build()
	Audio.play_music("music_menu")
	Loc.locale_changed.connect(_rebuild)
	if Save.recovered_from != "":
		App.toast(tr("SAVE_RECOVERED"), Palette.SUN, 4.0)
		Save.recovered_from = ""


func _rebuild() -> void:
	for c in get_children():
		if c.has_meta("menu_ui"):
			c.queue_free()
	_build()


func _add_floating_cards() -> void:
	var ids := [94, 104, 40]
	for i in ids.size():
		var cv := CardView.new()
		cv.card_id = ids[i]
		cv.set_card_size(Vector2(150, 225))
		cv.modulate.a = 0.22
		cv.set_anchors_preset(Control.PRESET_CENTER)
		add_child(cv)
		cv.set_meta("base", Vector2(-90 + i * 150, -40 + (i % 2) * 70))
		cv.rotation = -0.3 + i * 0.3
		_floaters.append(cv)
	set_process(not Settings.reduced_motion())


func _process(dt: float) -> void:
	_t += dt
	var ctr := size / 2.0
	for i in _floaters.size():
		var cv := _floaters[i]
		var b: Vector2 = cv.get_meta("base")
		cv.position = ctr + b + Vector2(0, sin(_t * 0.7 + i * 1.7) * 10.0) - cv.size / 2.0
		cv.rotation = -0.3 + i * 0.3 + sin(_t * 0.5 + i) * 0.04


func _mark(c: Control) -> Control:
	c.set_meta("menu_ui", true)
	add_child(c)
	return c


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	root.add_theme_constant_override("margin_left", 44)
	root.add_theme_constant_override("margin_right", 44)
	_mark(root)
	var col := UiKit.vbox(10)
	root.add_child(col)

	# --- top bar ---
	var top := UiKit.hbox(14)
	col.add_child(top)
	_profile_chip = _make_profile_chip()
	top.add_child(_profile_chip)
	top.add_child(UiKit.spacer())
	var coins := UiKit.button("", UiKit.Variant.GHOST, Vector2(130, 60))
	var ch := UiKit.hbox(8)
	ch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.add_child(ch)
	var cic := IconView.new()
	cic.icon = "coin"
	cic.color = Palette.SUN
	cic.custom_minimum_size = Vector2(28, 28)
	cic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(cic)
	var cl := UiKit.label(str(Economy.coins()), 22, Palette.SUN, 800, true)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(cl)
	coins.pressed.connect(func(): App.goto("store"))
	top.add_child(coins)
	var help_btn := UiKit.icon_button("help", tr("MENU_HELP"), 60)
	help_btn.pressed.connect(func(): HelpDialog.open())
	top.add_child(help_btn)
	var set_btn := UiKit.icon_button("settings", tr("MENU_SETTINGS"), 60)
	set_btn.pressed.connect(func(): SettingsDialog.open())
	top.add_child(set_btn)

	# --- body: left CTA column, right tiles ---
	var body := UiKit.hbox(30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var left := UiKit.vbox(14)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var logo := LogoView.new()
	logo.custom_minimum_size = Vector2(470, 140)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(logo)
	left.add_child(UiKit.spacer(6))

	var quick := _big_button("MENU_QUICK_PLAY", "MENU_QUICK_PLAY_SUB", "play", UiKit.Variant.ACCENT)
	quick.pressed.connect(_quick_play)
	left.add_child(quick)
	var bots := _big_button("MENU_BOTS", "MENU_BOTS_SUB", "bot", UiKit.Variant.PRIMARY)
	bots.pressed.connect(func(): App.goto("bot_setup"))
	left.add_child(bots)
	var row := UiKit.hbox(14)
	left.add_child(row)
	var create := _small_cta("MENU_CREATE_ROOM", "plus", "create_room")
	create.pressed.connect(func(): App.goto("lobby", {"action": "create"}))
	row.add_child(create)
	var join := _small_cta("MENU_JOIN_ROOM", "join", "join_room")
	join.pressed.connect(func(): App.goto("lobby", {"action": "join"}))
	row.add_child(join)

	var right := GridContainer.new()
	right.columns = 2
	right.add_theme_constant_override("h_separation", 14)
	right.add_theme_constant_override("v_separation", 14)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(right)
	for entry in [["MENU_FRIENDS", "friends", "friends"], ["MENU_PROFILE", "profile", "profile"],
			["MENU_COLLECTION", "collection", "collection"], ["MENU_MISSIONS", "missions", "missions"],
			["MENU_STORE", "store", "store"], ["MENU_HELP", "help", "help"]]:
		var tile := _tile(entry[0], entry[1], entry[2])
		right.add_child(tile)
		match entry[2]:
			"help":
				tile.pressed.connect(func(): HelpDialog.open())
			"missions":
				var n := Missions.claimable_count()
				if n > 0:
					_badge(tile, str(n))
				tile.pressed.connect(func(): App.goto("missions"))
			_:
				var target: String = entry[2]
				tile.pressed.connect(func(): App.goto(target))

	# --- footer ---
	var foot := UiKit.hbox(10)
	col.add_child(foot)
	var ver := UiKit.label("Card Rush v%s" % ProjectSettings.get_setting("application/config/version"), 16, Palette.TEXT_MUTED)
	foot.add_child(ver)
	foot.add_child(UiKit.spacer())
	var mode := UiKit.label(tr("MENU_OFFLINE_READY") + "  ·  " + tr("MENU_LAN_READY"), 16, Palette.TEXT_MUTED)
	foot.add_child(mode)


func _make_profile_chip() -> Button:
	var prof := Save.section("profile")
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 72)
	b.add_theme_stylebox_override("normal", UiKit.flat(Color(1, 1, 1, 0.05), 36, 2, Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", UiKit.flat(Color(1, 1, 1, 0.1), 36, 2, Palette.ELECTRIC))
	b.add_theme_stylebox_override("pressed", UiKit.flat(Color(1, 1, 1, 0.06), 36, 2, Palette.SUN))
	var h := UiKit.hbox(12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var av := AvatarView.new()
	av.avatar = int(prof.get("avatar", 0))
	av.ring_color = Cosmetics.frame_color()
	av.custom_minimum_size = Vector2(56, 56)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(av)
	var v := UiKit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiKit.label(str(prof.get("name", "")), 22, Palette.TEXT, 800))
	var lvl := Progression.level_info(int(prof.get("xp", 0)))
	v.add_child(UiKit.label(Loc.t("PROFILE_LEVEL_N", [lvl["level"]]), 16, Palette.SUN, 700))
	b.pressed.connect(func(): App.goto("profile"))
	return b


func _big_button(key: String, sub_key: String, icon: String, variant: int) -> Button:
	var b := UiKit.button("", variant, Vector2(470, 92))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := UiKit.hbox(16)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := IconView.new()
	ic.icon = icon
	ic.custom_minimum_size = Vector2(44, 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dark := variant == UiKit.Variant.ACCENT
	ic.color = Color("1b1405") if dark else Palette.TEXT
	h.add_child(ic)
	var v := UiKit.vbox(-4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var t := UiKit.label(tr(key), 32, Color("1b1405") if dark else Palette.TEXT, 800, true)
	v.add_child(t)
	v.add_child(UiKit.label(tr(sub_key), 17, Color("3a2a08") if dark else Palette.TEXT_DIM, 700))
	_pop_on_hover(b)
	return b


func _small_cta(key: String, icon: String, feature: String) -> Button:
	var b := UiKit.button("", UiKit.Variant.SECONDARY, Vector2(228, 66))
	var h := UiKit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := IconView.new()
	ic.icon = icon
	ic.custom_minimum_size = Vector2(30, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UiKit.label(tr(key), 22, Palette.TEXT, 800, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	_apply_availability(b, feature, ic)
	_pop_on_hover(b)
	return b


func _tile(key: String, icon: String, feature: String) -> Button:
	var b := UiKit.button("", UiKit.Variant.SECONDARY, Vector2(176, 128))
	var v := UiKit.vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := IconView.new()
	ic.icon = icon
	ic.custom_minimum_size = Vector2(46, 46)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.color = [Palette.ELECTRIC, Palette.SUN, Palette.TEAL, Palette.CORAL, Palette.VIOLET, Palette.TEXT][hash(icon) % 6]
	v.add_child(ic)
	var l := UiKit.label(tr(key), 20, Palette.TEXT, 800, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_apply_availability(b, feature, ic)
	_pop_on_hover(b)
	return b


func _apply_availability(b: Button, feature: String, ic: IconView) -> void:
	if Features.available(feature):
		return
	b.disabled = true
	b.tooltip_text = tr("FEATURE_SOON_TIP")
	ic.color = Palette.TEXT_MUTED
	var badge := UiKit.label(tr("BADGE_SOON"), 14, Color("1b1405"), 800)
	var sb := UiKit.flat(Palette.SUN, 10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", sb)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-6, -10)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.add_child(badge)


func _badge(b: Control, text: String) -> void:
	var badge := UiKit.label(text, 15, Color.WHITE, 800)
	var sb := UiKit.flat(Palette.DANGER, 12)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", sb)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-8, -10)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.add_child(badge)


func _pop_on_hover(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func():
		if not b.disabled and not Settings.reduced_motion():
			b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))


func _quick_play() -> void:
	var prof := RuleProfile.classic()
	App.goto("table", {"mode": "offline", "profile": prof.to_dict(), "bots": [1, 1, 1], "quick": true})


func handle_back() -> void:
	Dialogs.message(tr("QUIT_TITLE"), tr("QUIT_BODY"), [
		[tr("BTN_CANCEL"), UiKit.Variant.SECONDARY, null],
		[tr("BTN_QUIT"), UiKit.Variant.DANGER, func(): get_tree().quit()],
	])
