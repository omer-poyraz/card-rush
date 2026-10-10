extends TestCase
## Instantiates every screen headless and plays a full bot-driven match through
## the real table UI (local seat on autoplay) to catch runtime errors.

const SCREENS := ["menu", "bot_setup", "profile"]


func test_screens_instantiate() -> void:
	for key in SCREENS:
		var scene: PackedScene = load(App.SCENES[key])
		var node := scene.instantiate()
		runner.add_child(node)
		await frames(5)
		check(node.get_child_count() > 0, key + " built its UI")
		node.queue_free()
		await frames(2)


func test_dialogs_open_and_close() -> void:
	for fn in [func(): return SettingsDialog.open(), func(): return HelpDialog.open(3), func(): return LegalDialog.open("privacy")]:
		var host: Control = fn.call()
		await frames(3)
		check(is_instance_valid(host) and host.is_inside_tree(), "dialog shown")
		host.close()
		await frames(15)


func test_full_match_through_table_ui() -> void:
	Settings.set_value("animation", 1)
	App.params = {"mode": "offline", "profile": RuleProfile.classic().to_dict(), "bots": [0, 1, 2], "autoplay": true}
	var table: Node = load(App.SCENES["table"]).instantiate()
	runner.add_child(table)
	await frames(2)
	var auth: MatchAuthority = table.authority
	check(auth != null, "offline authority")
	auth.time_scale = 0.05
	auth.bot_think_scale = 0.2
	var t0 := Time.get_ticks_msec()
	while not auth.state.is_over() and Time.get_ticks_msec() - t0 < 60000:
		await frames(2)
	check(auth.state.is_over(), "match finished through the UI")
	eq(auth.state.check_integrity(), "")
	# let the table finish animating and show the result panel
	var tv: TableView = table.table
	var t1 := Time.get_ticks_msec()
	while not tv.is_idle() and Time.get_ticks_msec() - t1 < 30000:
		await frames(2)
	check(tv.is_idle(), "UI drained its event queue")
	eq(tv.view.get("version", -1), auth.state.version, "UI ended on the authoritative snapshot")
	eq(tv.hand.order.size(), auth.state.players[0].hand.size(), "hand matches state")
	for c in App.get_children():
		if c is CanvasLayer:
			for m in c.get_children():
				if m.has_meta("modal"):
					m.queue_free()
	table.queue_free()
	Settings.set_value("animation", 0)
	await frames(3)


func test_points_match_round_flow() -> void:
	Settings.set_value("animation", 1)
	var prof := RuleProfile.classic()
	prof.scoring_mode = RuleProfile.ScoringMode.POINTS
	prof.target_score = 100
	App.params = {"mode": "offline", "profile": prof.to_dict(), "bots": [2], "autoplay": true}
	var table: Node = load(App.SCENES["table"]).instantiate()
	runner.add_child(table)
	await frames(2)
	var auth: MatchAuthority = table.authority
	auth.time_scale = 0.03
	auth.bot_think_scale = 0.2
	var t0 := Time.get_ticks_msec()
	while not auth.state.is_over() and Time.get_ticks_msec() - t0 < 90000:
		await frames(2)
	check(auth.state.is_over(), "points match finished")
	check(auth.state.round_number >= 1, "rounds played")
	check(auth.state.players[auth.state.match_winner].score >= 100, "winner reached target")
	for c in App.get_children():
		if c is CanvasLayer:
			for m in c.get_children():
				if m.has_meta("modal"):
					m.queue_free()
	table.queue_free()
	Settings.set_value("animation", 0)
	await frames(3)
