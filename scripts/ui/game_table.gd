extends Control
## Match scene root. Builds the right MatchClient for the mode (offline:
## local authority + bots; online: network client from the lobby), hosts the
## TableView and handles pause, leaving and the end-of-match flow.

const BOT_NAMES := ["Nova", "Piksel", "Luna", "Zeki", "Kıvılcım", "Rüzgar", "Yıldız", "Tekno", "Mavi", "Atlas"]

var authority: MatchAuthority
var client: MatchClient
var table: TableView
var params := {}
var _pause_host: Control
var _recorded := false


func _ready() -> void:
	params = App.params.duplicate(true)
	DisplayServer.screen_set_keep_on(true)
	table = TableView.new()
	add_child(table)
	match str(params.get("mode", "offline")):
		"online":
			client = params.get("client")
			if client.get_parent() == null:
				add_child(client)
		_:
			_start_offline()
	table.back_style = str(Save.section("cosmetics").get("equipped", {}).get("back", "back_classic"))
	table.bind(client)
	table.leave_requested.connect(_open_pause)
	table.match_over.connect(_on_match_over)
	if authority:
		authority.start()
	elif client.last_view.size() > 0:
		table._on_update(client.last_view, [])


func _start_offline() -> void:
	var prof := RuleProfile.from_dict(params.get("profile", {}))
	var levels: Array = params.get("bots", [1, 1, 1])
	var players: Array[PlayerState] = []
	var kinds: Array[int] = []
	var me := PlayerState.new()
	var pr := Save.section("profile")
	me.display_name = str(pr.get("name", "Player"))
	me.avatar = int(pr.get("avatar", 0))
	me.seat_id = "local"
	players.append(me)
	kinds.append(MatchAuthority.SeatKind.LOCAL)
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var used_avatars := {me.avatar: true}
	for i in levels.size():
		var b := PlayerState.new()
		b.display_name = names[i % names.size()]
		b.bot_level = clampi(int(levels[i]), 0, 2)
		b.seat_id = "bot%d" % i
		var av := randi_range(0, AvatarView.COUNT - 1)
		while used_avatars.has(av) and used_avatars.size() < AvatarView.COUNT:
			av = randi_range(0, AvatarView.COUNT - 1)
		used_avatars[av] = true
		b.avatar = av
		players.append(b)
		kinds.append(MatchAuthority.SeatKind.BOT)
	if bool(params.get("autoplay", false)):
		# test/demo mode: a hard bot plays the local seat through the real UI
		kinds[0] = MatchAuthority.SeatKind.BOT
		players[0].bot_level = BotController.Level.HARD
	authority = MatchAuthority.new()
	authority.bot_think_scale = [1.5, 1.0, 0.55][clampi(int(Settings.get_value("bot_speed")), 0, 2)]
	add_child(authority)
	var err := authority.setup(prof, players, kinds)
	if err != "":
		push_error("setup failed: " + err)
	var lc := LocalMatchClient.new()
	add_child(lc)
	lc.attach(authority, 0)
	client = lc


func _open_pause() -> void:
	if _pause_host and is_instance_valid(_pause_host):
		return
	if client.can_pause():
		client.set_paused(true)
	var pv := Dialogs.titled_panel(tr("PAUSE_TITLE"), 460)
	var v: VBoxContainer = pv[1]
	if not client.can_pause():
		var note := UiKit.label(tr("PAUSE_ONLINE_NOTE"), 17, Palette.TEXT_DIM, 600)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 400
		v.add_child(note)
	var resume := UiKit.button(tr("PAUSE_RESUME"), UiKit.Variant.ACCENT, Vector2(400, 62))
	v.add_child(resume)
	var settings := UiKit.button(tr("MENU_SETTINGS"), UiKit.Variant.SECONDARY, Vector2(400, 58))
	v.add_child(settings)
	var rules := UiKit.button(tr("PAUSE_RULES"), UiKit.Variant.SECONDARY, Vector2(400, 58))
	v.add_child(rules)
	var leave := UiKit.button(tr("PAUSE_LEAVE"), UiKit.Variant.DANGER, Vector2(400, 58))
	v.add_child(leave)
	_pause_host = App.modal(pv[0])
	_pause_host.closed.connect(func():
		if client.can_pause():
			client.set_paused(false))
	resume.pressed.connect(_pause_host.close)
	resume.grab_focus.call_deferred()
	settings.pressed.connect(func(): SettingsDialog.open())
	rules.pressed.connect(func(): HelpDialog.open())
	leave.pressed.connect(func():
		Dialogs.message(tr("LEAVE_CONFIRM_TITLE"), tr("LEAVE_CONFIRM_BODY"), [
			[tr("BTN_CANCEL"), UiKit.Variant.SECONDARY, null],
			[tr("PAUSE_LEAVE"), UiKit.Variant.DANGER, func():
				_pause_host.close()
				_leave(true)],
		]))


func _on_match_over(v: Dictionary, _events: Array) -> void:
	var xp := {}
	if not _recorded:
		_recorded = true
		var me := client.seat
		var levels: Array = params.get("bots", [1])
		var avg := 1
		if not levels.is_empty():
			var s := 0
			for l in levels:
				s += int(l)
			avg = roundi(float(s) / levels.size())
		var st := table.stats()
		xp = Progression.record_match({
			"won": int(v["match_winner"]) == me, "players": v["players"].size(), "bot_level": avg,
			"cards_played": st["cards_played"], "uno_calls": st["uno_calls"], "catches": st["catches"],
			"online": str(params.get("mode", "")) == "online", "points": int(v["players"][me]["score"]),
		})
	RoundResultPanel.open_match(v, client.seat, xp, _rematch, func(): _leave(false), str(params.get("mode", "offline")) == "offline")


func _rematch() -> void:
	App.goto("table", params)


func _leave(forfeit: bool) -> void:
	if forfeit and not _recorded and authority and not authority.state.is_over():
		_recorded = true
		Progression.record_match({"won": false, "players": authority.state.players.size(), "bot_level": 1,
			"cards_played": table.stats()["cards_played"], "online": false})
	client.leave()
	DisplayServer.screen_set_keep_on(false)
	App.goto(str(params.get("return_to", "menu")))


func handle_back() -> void:
	_open_pause()


func _notification(what: int) -> void:
	# Pause offline games when the app goes to the background.
	if what == NOTIFICATION_APPLICATION_PAUSED and client and client.can_pause():
		_open_pause()
