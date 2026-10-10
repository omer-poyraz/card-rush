extends Control
## Daily login reward + daily and weekly missions.

var _coins: Label
var _body: VBoxContainer


func _ready() -> void:
	var f := ScreenKit.frame(self, "MENU_MISSIONS", handle_back)
	var col: VBoxContainer = f[0]
	_coins = f[1]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = UiKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	_coins.text = str(Economy.coins())
	var s := Missions.state()
	# daily login
	var login := Missions.login_status()
	var lp := UiKit.panel()
	_body.add_child(lp)
	var lh := UiKit.hbox(14)
	lp.add_child(lh)
	var ic := IconView.new()
	ic.icon = "star"
	ic.color = Palette.SUN
	ic.custom_minimum_size = Vector2(46, 46)
	lh.add_child(ic)
	var lv := UiKit.vbox(2)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lv)
	lv.add_child(UiKit.label(tr("MISSION_LOGIN"), 22, Palette.TEXT, 800))
	lv.add_child(UiKit.label(Loc.t("MISSION_LOGIN_STREAK", [int(login["streak"])]), 16, Palette.TEXT_DIM, 650))
	if login["can_claim"]:
		var b := UiKit.button(Loc.t("MISSION_CLAIM_N", [int(login["reward"])]), UiKit.Variant.ACCENT, Vector2(200, 54))
		b.pressed.connect(func():
			var got := Missions.claim_login()
			if got > 0:
				Audio.play("reward")
				App.toast(Loc.t("STORE_COINS_GRANTED", [got]), Palette.SUCCESS)
			_build())
		lh.add_child(b)
	else:
		lh.add_child(UiKit.label(tr("MISSION_COME_BACK"), 16, Palette.TEXT_MUTED, 650))
	_section("MISSION_DAILY", s.get("daily", []))
	_section("MISSION_WEEKLY", s.get("weekly", []))
	var note := UiKit.label(tr("MISSION_NOTE"), 14, Palette.TEXT_MUTED, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)


func _section(key: String, list: Array) -> void:
	_body.add_child(UiKit.label(tr(key).to_upper(), 16, Palette.ELECTRIC, 800))
	for m in list:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.05), 16, 1, Color(1, 1, 1, 0.1)))
		_body.add_child(p)
		var h := UiKit.hbox(14)
		p.add_child(h)
		var v := UiKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiKit.label(Loc.t("MISSION_" + str(m["stat"]).to_upper(), [int(m["goal"])]), 19, Palette.TEXT, 750))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(300, 12)
		bar.show_percentage = false
		bar.max_value = int(m["goal"])
		bar.value = int(m["progress"])
		bar.add_theme_stylebox_override("background", UiKit.flat(Color(1, 1, 1, 0.08), 6))
		bar.add_theme_stylebox_override("fill", UiKit.flat(Palette.TEAL, 6))
		v.add_child(bar)
		v.add_child(UiKit.label("%d / %d" % [int(m["progress"]), int(m["goal"])], 14, Palette.TEXT_DIM, 650))
		if m["claimed"]:
			h.add_child(UiKit.label(tr("MISSION_CLAIMED"), 17, Palette.SUCCESS, 800))
		else:
			var b := UiKit.button(Loc.t("MISSION_CLAIM_N", [int(m["coins"])]), UiKit.Variant.ACCENT, Vector2(180, 50))
			b.disabled = int(m["progress"]) < int(m["goal"])
			var id: String = m["id"]
			b.pressed.connect(func():
				var got := Missions.claim(id)
				if got > 0:
					Audio.play("reward")
					App.toast(Loc.t("STORE_COINS_GRANTED", [got]), Palette.SUCCESS)
				_build())
			h.add_child(b)


func handle_back() -> void:
	App.goto("menu")
