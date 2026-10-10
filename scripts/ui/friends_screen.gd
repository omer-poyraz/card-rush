extends Control
## Friends (local only): recent players from online rooms and a local block
## list. States clearly that global friends, invites and reports need a
## backend that does not exist yet.

var _body: VBoxContainer


func _ready() -> void:
	var f := ScreenKit.frame(self, "MENU_FRIENDS", handle_back, false)
	var col: VBoxContainer = f[0]
	var note := UiKit.label(tr("FRIENDS_LOCAL_NOTE"), 16, Palette.TEXT_DIM, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = UiKit.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var svc := FriendsService.local()
	_body.add_child(UiKit.label(tr("FRIENDS_RECENT").to_upper(), 16, Palette.ELECTRIC, 800))
	var recent := svc.recent_players()
	if recent.is_empty():
		_body.add_child(UiKit.label(tr("FRIENDS_NO_RECENT"), 17, Palette.TEXT_MUTED, 600))
	for e in recent:
		var name := str(e.get("name", ""))
		var blocked := svc.is_blocked(name)
		var h := UiKit.hbox(12)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.05), 14, 1, Color(1, 1, 1, 0.1)))
		p.add_child(h)
		_body.add_child(p)
		var l := UiKit.label(name, 20, Palette.TEXT_MUTED if blocked else Palette.TEXT, 800)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var d := Time.get_datetime_dict_from_unix_time(int(e.get("t", 0)))
		h.add_child(UiKit.label("%02d.%02d.%d" % [d["day"], d["month"], d["year"]], 15, Palette.TEXT_DIM, 650))
		var b := UiKit.button(tr("FRIENDS_UNBLOCK") if blocked else tr("FRIENDS_BLOCK"), UiKit.Variant.SECONDARY if blocked else UiKit.Variant.DANGER, Vector2(160, 46))
		b.pressed.connect(func():
			svc.set_blocked(name, not blocked)
			_build())
		h.add_child(b)
	var blocked_list: Array = Save.section("social").get("blocked", [])
	var extra := blocked_list.filter(func(n): return not recent.any(func(e): return e.get("name", "") == n))
	if not extra.is_empty():
		_body.add_child(UiKit.label(tr("FRIENDS_BLOCKED").to_upper(), 16, Palette.CORAL, 800))
		for n in extra:
			var h2 := UiKit.hbox(12)
			_body.add_child(h2)
			var l2 := UiKit.label(str(n), 19, Palette.TEXT_MUTED, 700)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h2.add_child(l2)
			var nm := str(n)
			var ub := UiKit.button(tr("FRIENDS_UNBLOCK"), UiKit.Variant.SECONDARY, Vector2(160, 44))
			ub.pressed.connect(func():
				svc.set_blocked(nm, false)
				_build())
			h2.add_child(ub)


func handle_back() -> void:
	App.goto("menu")
