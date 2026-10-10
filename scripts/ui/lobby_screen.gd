extends Control
## Online lobby: create a room, join one (nearby LAN rooms, by code, by IP)
## and the waiting room (players, ready states, bots, rules, start).
## params.action: "create" | "join" | "room"

var _root: MarginContainer
var _body: Control
var _form: RulesForm
var _list_box: VBoxContainer
var _code_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _connecting := false


func _ready() -> void:
	add_child(Backdrop.new())
	_root = MarginContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_root.add_theme_constant_override("margin_" + side, 24)
	add_child(_root)
	Audio.play_music("music_menu")
	var action := str(App.params.get("action", "join"))
	if Net.is_active() and action != "create" and action != "join":
		_show_room()
	elif Net.is_active():
		_show_room()
	elif action == "create":
		_show_create()
	else:
		_show_join()


func _clear() -> void:
	for c in _root.get_children():
		c.queue_free()
	_status = null


func _frame(title_key: String) -> VBoxContainer:
	_clear()
	var col := UiKit.vbox(14)
	_root.add_child(col)
	var top := UiKit.hbox(14)
	col.add_child(top)
	var back := UiKit.icon_button("back", tr("BTN_BACK"), 58)
	back.pressed.connect(handle_back)
	top.add_child(back)
	top.add_child(UiKit.title(tr(title_key), 40))
	top.add_child(UiKit.spacer())
	var note := UiKit.label(tr("LOBBY_LAN_NOTE"), 15, Palette.TEXT_MUTED, 600)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(note)
	return col


# --- create ---------------------------------------------------------------------------

func _show_create() -> void:
	var col := _frame("MENU_CREATE_ROOM")
	var saved := Save.section("room_setup")
	var body := UiKit.hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := UiKit.vbox(12)
	left.add_child(lv)
	lv.add_child(UiKit.label(tr("LOBBY_ROOM_NAME"), 18, Palette.TEXT_DIM, 700))
	var name_edit := LineEdit.new()
	name_edit.max_length = 24
	name_edit.text = str(saved.get("name", Loc.t("LOBBY_DEFAULT_ROOM_NAME", [str(Save.section("profile").get("name", ""))])))
	lv.add_child(name_edit)
	var h1 := UiKit.hbox(10)
	lv.add_child(h1)
	var l1 := UiKit.label(tr("LOBBY_MAX_PLAYERS"), 19, Palette.TEXT, 700)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(l1)
	var maxp := Segmented.Stepper.new(int(saved.get("max_players", 4)), 2, 10)
	h1.add_child(maxp)
	lv.add_child(UiKit.label(tr("LOBBY_VISIBILITY"), 19, Palette.TEXT, 700))
	var vis := Segmented.new([tr("LOBBY_PRIVATE"), tr("LOBBY_PUBLIC")], 1 if saved.get("public", false) else 0, 150)
	lv.add_child(vis)
	var vis_note := UiKit.label("", 15, Palette.TEXT_DIM, 600)
	vis_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(vis_note)
	var upd := func(i): vis_note.text = tr("LOBBY_PUBLIC_NOTE" if i == 1 else "LOBBY_PRIVATE_NOTE")
	upd.call(vis.index)
	vis.changed.connect(upd)
	var voice := CheckButton.new()
	voice.text = tr("LOBBY_VOICE")
	voice.disabled = not Features.available("voice")
	voice.tooltip_text = tr("FEATURE_SOON_TIP")
	lv.add_child(voice)
	lv.add_child(UiKit.spacer())
	_status = UiKit.label("", 17, Palette.CORAL, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_status)
	var create := UiKit.button(tr("LOBBY_CREATE"), UiKit.Variant.ACCENT, Vector2(0, 70))
	lv.add_child(create)

	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var prof := RuleProfile.from_dict(saved.get("rules", {}))
	if not saved.has("rules"):
		prof.turn_time_s = 30  # online default: nobody can stall the table
	_form = RulesForm.new(prof)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	create.pressed.connect(func():
		var n := NameFilter.clean(name_edit.text)
		if n.length() < 3 or NameFilter.is_offensive(n):
			n = Loc.t("LOBBY_DEFAULT_ROOM_NAME", [str(Save.section("profile").get("name", ""))])
		var settings := {"name": n, "max_players": maxp.value, "public": vis.index == 1, "voice": voice.button_pressed,
			"rules": _form.profile.to_dict(), "bots": []}
		var s := Save.section("room_setup")
		for k in ["name", "max_players", "public", "rules"]:
			s[k] = settings[k]
		Save.mark_dirty()
		var err := Net.create_room(settings)
		if err != "":
			_status.text = Loc.error_text(err)
			return
		Audio.play("join")
		_show_room())


# --- join -----------------------------------------------------------------------------

func _show_join() -> void:
	var col := _frame("MENU_JOIN_ROOM")
	var body := UiKit.hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	body.add_child(left)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	var hdr := UiKit.hbox(10)
	lv.add_child(hdr)
	var t := UiKit.label(tr("LOBBY_NEARBY").to_upper(), 16, Palette.ELECTRIC, 800)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_list_box = UiKit.vbox(8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)
	if not Net.discovery.listen():
		_list_box.add_child(UiKit.label(tr("LOBBY_DISCOVERY_UNAVAILABLE"), 17, Palette.TEXT_DIM, 600))
	else:
		Net.discovery.rooms_changed.connect(_refresh_rooms)
		_refresh_rooms()

	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rv := UiKit.vbox(10)
	right.add_child(rv)
	rv.add_child(UiKit.label(tr("LOBBY_BY_CODE").to_upper(), 16, Palette.ELECTRIC, 800))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "ABC123"
	_code_edit.max_length = 8
	_code_edit.add_theme_font_override("font", UiKit.font(800, true))
	_code_edit.add_theme_font_size_override("font_size", 32)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_code_edit)
	var by_code := UiKit.button(tr("LOBBY_JOIN"), UiKit.Variant.PRIMARY, Vector2(0, 58))
	by_code.pressed.connect(_join_by_code)
	_code_edit.text_submitted.connect(func(_x): _join_by_code())
	rv.add_child(by_code)
	rv.add_child(UiKit.spacer(8))
	rv.add_child(UiKit.label(tr("LOBBY_BY_IP").to_upper(), 16, Palette.ELECTRIC, 800))
	var ipn := UiKit.label(tr("LOBBY_BY_IP_NOTE"), 15, Palette.TEXT_DIM, 600)
	ipn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(ipn)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.text = str(Save.section("net").get("last_ip", ""))
	rv.add_child(_ip_edit)
	var by_ip := UiKit.button(tr("LOBBY_CONNECT_IP"), UiKit.Variant.SECONDARY, Vector2(0, 54))
	by_ip.pressed.connect(_join_by_ip)
	rv.add_child(by_ip)
	var last: Dictionary = Save.section("net").get("last", {})
	if not last.is_empty() and int(Time.get_unix_time_from_system()) - int(last.get("t", 0)) < 3600:
		var rejoin := UiKit.button(tr("LOBBY_REJOIN"), UiKit.Variant.SUCCESS, Vector2(0, 54))
		rejoin.pressed.connect(func(): _connect(str(last["address"]), int(last["port"]), str(last["code"]), str(last.get("token", ""))))
		rv.add_child(rejoin)
	rv.add_child(UiKit.spacer())
	_status = UiKit.label("", 17, Palette.SUN, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_status)


func _refresh_rooms() -> void:
	if _list_box == null or not is_instance_valid(_list_box):
		return
	for c in _list_box.get_children():
		c.queue_free()
	if Net.discovery.rooms.is_empty():
		var l := UiKit.label(tr("LOBBY_SEARCHING"), 17, Palette.TEXT_DIM, 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list_box.add_child(l)
		return
	for key in Net.discovery.rooms:
		var r: Dictionary = Net.discovery.rooms[key]
		var row := UiKit.hbox(10)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.05), 14, 1, Color(1, 1, 1, 0.1)))
		p.add_child(row)
		var ic := IconView.new()
		ic.icon = "lock" if not r["public"] else "wifi"
		ic.custom_minimum_size = Vector2(30, 30)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UiKit.label(str(r["name"]), 20, Palette.TEXT, 800))
		var sub := Loc.t("LOBBY_ROOM_SUB", [str(r["host"]), int(r["players"]), int(r["max"])])
		if r["in_match"]:
			sub += " · " + tr("LOBBY_IN_MATCH")
		v.add_child(UiKit.label(sub, 15, Palette.TEXT_DIM, 650))
		var join := UiKit.button(tr("LOBBY_JOIN"), UiKit.Variant.PRIMARY, Vector2(130, 50))
		join.disabled = r["in_match"] or int(r["players"]) >= int(r["max"])
		var room := r
		join.pressed.connect(func():
			if room["public"]:
				_connect(room["ip"], int(room["port"]), room["code"])
			else:
				_status.text = tr("LOBBY_ENTER_CODE_PRIVATE")
				_code_edit.grab_focus())
		row.add_child(join)
		_list_box.add_child(p)


func _join_by_code() -> void:
	var code := RoomCode.normalize(_code_edit.text)
	if not RoomCode.is_valid(code):
		_status.text = tr("ERR_NET_BAD_CODE_FORMAT")
		return
	var r := Net.discovery.find_by_code(code)
	if r.is_empty():
		_status.text = tr("LOBBY_CODE_NOT_FOUND")
		return
	_connect(r["ip"], int(r["port"]), code)


func _join_by_ip() -> void:
	var raw := _ip_edit.text.strip_edges()
	var port := NetProtocol.GAME_PORT
	if raw.contains(":"):
		port = int(raw.get_slice(":", 1))
		raw = raw.get_slice(":", 0)
	if not raw.is_valid_ip_address():
		_status.text = tr("ERR_NET_BAD_IP")
		return
	var code := RoomCode.normalize(_code_edit.text)
	if not RoomCode.is_valid(code):
		_status.text = tr("LOBBY_IP_NEEDS_CODE")
		_code_edit.grab_focus()
		return
	Save.section("net")["last_ip"] = _ip_edit.text.strip_edges()
	Save.mark_dirty()
	_connect(raw, port, code)


func _connect(address: String, port: int, code: String, token := "") -> void:
	if _connecting:
		return
	_connecting = true
	if _status:
		_status.text = tr("LOBBY_CONNECTING")
	Net.discovery.stop()
	var c := Net.join_room(address, port, code)
	if token != "":
		c.token = token
	c.state_changed.connect(_on_join_state)


func _on_join_state(s: String, detail: String) -> void:
	match s:
		"lobby":
			_connecting = false
			Audio.play("join")
			_show_room()
		"match":
			_connecting = false
			_go_table(Net.client.match_client)
		"failed":
			_connecting = false
			if _status and is_instance_valid(_status):
				_status.text = Loc.error_text(detail)
			App.toast(Loc.error_text(detail), Palette.CORAL)
			Net.leave_room()
			if is_inside_tree() and _list_box == null:
				_show_join()


# --- waiting room ---------------------------------------------------------------------

var _room_list: VBoxContainer
var _start_btn: Button
var _ready_btn: Button
var _rules_label: Label


func _show_room() -> void:
	var col := _frame("LOBBY_WAITING_ROOM")
	_list_box = null
	var body := UiKit.hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	body.add_child(left)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	lv.add_child(UiKit.label(tr("LOBBY_PLAYERS").to_upper(), 16, Palette.ELECTRIC, 800))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_room_list = UiKit.vbox(8)
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_room_list)
	if Net.host:
		var bots := UiKit.hbox(8)
		lv.add_child(bots)
		bots.add_child(UiKit.label(tr("LOBBY_ADD_BOT"), 18, Palette.TEXT, 700))
		for lvl in 3:
			var b := UiKit.button(tr(["BOT_EASY", "BOT_NORMAL", "BOT_HARD"][lvl]), UiKit.Variant.SECONDARY, Vector2(100, 46))
			b.add_theme_font_size_override("font_size", 17)
			var L := lvl
			b.pressed.connect(func():
				if not Net.host.add_bot(L):
					App.toast(tr("ERR_NET_ROOM_FULL"), Palette.SUN))
			bots.add_child(b)

	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rv := UiKit.vbox(10)
	right.add_child(rv)
	rv.add_child(UiKit.label(tr("LOBBY_ROOM_CODE").to_upper(), 16, Palette.ELECTRIC, 800))
	var code_row := UiKit.hbox(10)
	rv.add_child(code_row)
	var code := Net.host.code if Net.host else str(Net.client.lobby.get("code", Net.client.code))
	var code_l := UiKit.label(code.substr(0, 3) + " " + code.substr(3), 46, Palette.SUN, 800, true)
	code_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code_l)
	var copy := UiKit.icon_button("copy", tr("BTN_COPY"), 56)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(code)
		App.toast(tr("LOBBY_CODE_COPIED"), Palette.SUCCESS))
	code_row.add_child(copy)
	if Net.host:
		var ips := ENetAdapter.local_ipv4()
		var ip_text := Loc.t("LOBBY_HOST_IP", [", ".join(ips) if not ips.is_empty() else "-", NetProtocol.GAME_PORT])
		var ipl := UiKit.label(ip_text, 15, Palette.TEXT_DIM, 650)
		ipl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(ipl)
	var inv := UiKit.label(tr("LOBBY_INVITE_NOTE"), 14, Palette.TEXT_MUTED, 600)
	inv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(inv)
	rv.add_child(UiKit.label(tr("LOBBY_RULES").to_upper(), 16, Palette.ELECTRIC, 800))
	_rules_label = UiKit.label("", 16, Palette.TEXT_DIM, 650)
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_rules_label)
	rv.add_child(UiKit.spacer())
	_status = UiKit.label("", 16, Palette.SUN, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_status)
	if Net.host:
		_start_btn = UiKit.button(tr("LOBBY_START"), UiKit.Variant.ACCENT, Vector2(0, 68))
		_start_btn.pressed.connect(func():
			var err := Net.host.start_match()
			if err != "":
				_status.text = Loc.error_text(err))
		rv.add_child(_start_btn)
		Net.host.lobby_changed.connect(_refresh_room)
		Net.host.match_started.connect(func(lc): _go_table(lc))
		Net.host.member_event.connect(_on_member_event)
	else:
		_ready_btn = UiKit.button(tr("LOBBY_READY"), UiKit.Variant.SUCCESS, Vector2(0, 68))
		_ready_btn.toggle_mode = true
		_ready_btn.toggled.connect(func(on):
			Net.client.set_ready(on)
			_ready_btn.text = tr("LOBBY_NOT_READY") if on else tr("LOBBY_READY"))
		rv.add_child(_ready_btn)
		Net.client.lobby_updated.connect(func(_l): _refresh_room())
		Net.client.match_starting.connect(func(mc, _resume): _go_table(mc))
		Net.client.state_changed.connect(_on_client_state)
	_refresh_room()


func _lobby() -> Dictionary:
	if Net.host:
		return Net.host.lobby_dict()
	if Net.client:
		return Net.client.lobby
	return {}


func _refresh_room() -> void:
	if _room_list == null or not is_instance_valid(_room_list):
		return
	var lob := _lobby()
	if lob.is_empty():
		return
	for c in _room_list.get_children():
		c.queue_free()
	var my_pid := RoomHost.HOST_PID if Net.host else Net.client.pid
	for m in lob.get("members", []):
		var row := _member_row(m["name"], int(m["avatar"]), bool(m["host"]), bool(m["ready"]), bool(m["connected"]), int(m["pid"]) == my_pid)
		if Net.host and not m["host"]:
			var pid := int(m["pid"])
			var kick := UiKit.icon_button("close", tr("LOBBY_KICK"), 44, UiKit.Variant.GHOST)
			kick.pressed.connect(func(): Net.host.kick(pid))
			row.add_child(kick)
		_room_list.add_child(row.get_parent())
	var bots: Array = lob.get("bots", [])
	for i in bots.size():
		var row := _member_row(Loc.t("LOBBY_BOT_N", [tr(["BOT_EASY", "BOT_NORMAL", "BOT_HARD"][clampi(int(bots[i]), 0, 2)])]), (i * 5 + 3) % AvatarView.COUNT, false, true, true, false)
		if Net.host:
			var idx := i
			var rm := UiKit.icon_button("close", tr("LOBBY_REMOVE_BOT"), 44, UiKit.Variant.GHOST)
			rm.pressed.connect(func(): Net.host.remove_bot(idx))
			row.add_child(rm)
		_room_list.add_child(row.get_parent())
	var total: int = lob.get("members", []).size() + bots.size()
	for i in maxi(0, int(lob.get("max", 4)) - total):
		var empty := UiKit.label(tr("LOBBY_EMPTY_SEAT"), 17, Palette.TEXT_MUTED, 600)
		_room_list.add_child(empty)
	var rules := RuleProfile.from_dict(lob.get("rules", {}))
	var mode_key: String = ["RULES_MODE_SINGLE", "RULES_MODE_POINTS", "RULES_MODE_LOW"][rules.scoring_mode]
	var timer := tr("RULES_TIMER_OFF") if rules.turn_time_s == 0 else Loc.t("UNIT_SECONDS_N", [rules.turn_time_s])
	_rules_label.text = "%s\n%s: %s · %s: %s" % [RulesForm.summary_text(rules), tr("RULES_MODE"), tr(mode_key), tr("RULES_TURN_TIMER"), timer]
	if _start_btn:
		var err := Net.host.can_start()
		_start_btn.disabled = err != ""
		_status.text = "" if err == "" else Loc.error_text(err)
	if lob.get("in_match", false) and Net.client and _status:
		_status.text = tr("LOBBY_IN_MATCH")


func _member_row(name: String, avatar: int, is_host: bool, ready: bool, connected: bool, is_me: bool) -> HBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.07 if is_me else 0.04), 14, 1, Color(Palette.ELECTRIC, 0.4) if is_me else Color(1, 1, 1, 0.08)))
	var row := UiKit.hbox(10)
	p.add_child(row)
	var av := AvatarView.new()
	av.avatar = avatar
	av.dimmed = not connected
	av.custom_minimum_size = Vector2(44, 44)
	row.add_child(av)
	var l := UiKit.label(name + ("  (" + tr("TABLE_YOU") + ")" if is_me else ""), 20, Palette.TEXT, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	if is_host:
		var crown := IconView.new()
		crown.icon = "crown"
		crown.color = Palette.SUN
		crown.custom_minimum_size = Vector2(28, 28)
		crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crown)
	var st := UiKit.label(tr("LOBBY_READY_STATE") if ready else tr("LOBBY_WAITING_STATE"), 16, Palette.SUCCESS if ready else Palette.TEXT_MUTED, 800)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(st)
	return row


func _on_member_event(kind: String, name: String) -> void:
	match kind:
		"joined":
			Audio.play("join")
			App.toast(Loc.t("LOBBY_JOINED", [name]), Palette.SUCCESS)
		"left", "kicked":
			Audio.play("leave")
			App.toast(Loc.t("LOBBY_LEFT", [name]), Palette.TEXT_DIM)
		"back":
			Audio.play("join")


func _on_client_state(s: String, detail: String) -> void:
	if s in ["closed", "failed"] and is_inside_tree():
		var key := "LOBBY_KICKED" if detail == "kicked" else ("LOBBY_ROOM_CLOSED" if s == "closed" else detail)
		App.toast(Loc.error_text(key) if key.begins_with("ERR_") else tr(key), Palette.CORAL, 3.5)
		Net.leave_room()
		App.goto("menu")


func _go_table(mc: MatchClient) -> void:
	if not is_inside_tree() or mc == null:
		return
	App.goto("table", {"mode": "online", "client": mc, "return_to": "lobby"})


func handle_back() -> void:
	if Net.is_active():
		var body := tr("LOBBY_LEAVE_HOST_BODY") if Net.host else tr("LOBBY_LEAVE_BODY")
		Dialogs.message(tr("LOBBY_LEAVE_TITLE"), body, [
			[tr("BTN_CANCEL"), UiKit.Variant.SECONDARY, null],
			[tr("LOBBY_LEAVE"), UiKit.Variant.DANGER, func():
				Net.leave_room()
				App.goto("menu")],
		])
	else:
		Net.discovery.stop()
		App.goto("menu")
