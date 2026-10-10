class_name RoundResultPanel
extends RefCounted
## Between-round summary (points mode) and the final match result.


static func _ranked(v: Dictionary) -> Array:
	var rows := []
	for i in v["players"].size():
		var p: Dictionary = v["players"][i]
		rows.append({"seat": i, "name": p["name"], "avatar": p["avatar"], "score": int(p["score"]),
			"left": int(v["last_round_points"].get(i, 0)), "count": int(p["count"])})
	return rows


static func _row(r: Dictionary, me: int, highlight: bool, show_score: bool) -> Control:
	var h := UiKit.hbox(12)
	var av := AvatarView.new()
	av.avatar = int(r["avatar"])
	av.custom_minimum_size = Vector2(40, 40)
	h.add_child(av)
	var name := str(r["name"]) + ("  (" + TranslationServer.translate("TABLE_YOU") + ")" if int(r["seat"]) == me else "")
	var l := UiKit.label(name, 21, Palette.SUN if highlight else Palette.TEXT, 800)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var detail := Loc.t("RESULT_CARDS_LEFT", [int(r["count"]), int(r["left"])])
	h.add_child(UiKit.label(detail, 18, Palette.TEXT_DIM, 700))
	if show_score:
		var s := UiKit.label(str(r["score"]), 24, Palette.TEXT, 800, true)
		s.custom_minimum_size.x = 70
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(s)
	return h


## Points mode: shown after each round. Closes itself when the next deal starts.
static func open(table: TableView, v: Dictionary, e: Dictionary, me: int, client: MatchClient) -> void:
	var winner := int(e["winner"])
	var pv := Dialogs.titled_panel(Loc.t("RESULT_ROUND_WINNER", [table._seat_name(winner), int(e["points"])]), 700)
	var box: VBoxContainer = pv[1]
	var rows := _ranked(v)
	var low := RuleProfile.from_dict(v["rules"]).scoring_mode == RuleProfile.ScoringMode.LOW_TALLY
	rows.sort_custom(func(a, b): return a["score"] < b["score"] if low else a["score"] > b["score"])
	for r in rows:
		box.add_child(_row(r, me, int(r["seat"]) == winner, true))
	var target := RuleProfile.from_dict(v["rules"]).target_score
	box.add_child(UiKit.label(Loc.t("TABLE_TARGET_N", [target]), 18, Palette.TEXT_DIM, 700))
	var countdown := UiKit.label("", 18, Palette.TEXT_MUTED, 700)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(countdown)
	var host := App.modal(pv[0])
	if client.is_host:
		var next := UiKit.button(TranslationServer.translate("RESULT_NEXT_ROUND"), UiKit.Variant.ACCENT, Vector2(260, 62))
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func():
			host.close()
			client.request_next_round())
		box.add_child(next)
	var left := [int(MatchAuthority.ROUND_BREAK_S)]
	var timer := Timer.new()
	timer.wait_time = 1.0
	host.add_child(timer)
	timer.timeout.connect(func():
		left[0] -= 1
		countdown.text = Loc.t("RESULT_NEXT_IN", [maxi(0, left[0])])
		if left[0] <= 0:
			host.close())
	countdown.text = Loc.t("RESULT_NEXT_IN", [left[0]])
	timer.start()
	table.set_meta("round_panel", host)


## Final match result. buttons: rematch / menu callables.
static func open_match(v: Dictionary, me: int, xp_info: Dictionary, on_rematch: Callable, on_menu: Callable, can_rematch: bool) -> Control:
	var winner := int(v["match_winner"])
	var won := winner == me
	var title_text: String = TranslationServer.translate("RESULT_YOU_WIN") if won else Loc.t("RESULT_WINNER", [str(v["players"][winner]["name"])])
	var pv := Dialogs.titled_panel(title_text, 760)
	var box: VBoxContainer = pv[1]
	var crown := UiKit.hbox(14)
	crown.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(crown)
	var av := AvatarView.new()
	av.avatar = int(v["players"][winner]["avatar"])
	av.ring_color = Palette.SUN
	av.custom_minimum_size = Vector2(96, 96)
	crown.add_child(av)
	var ic := IconView.new()
	ic.icon = "crown"
	ic.color = Palette.SUN
	ic.custom_minimum_size = Vector2(54, 54)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crown.add_child(ic)
	var rules := RuleProfile.from_dict(v["rules"])
	var points_mode := rules.scoring_mode != RuleProfile.ScoringMode.SINGLE_ROUND
	var low := rules.scoring_mode == RuleProfile.ScoringMode.LOW_TALLY
	var rows := _ranked(v)
	if low:
		rows.sort_custom(func(a, b): return a["score"] < b["score"])
	elif points_mode:
		rows.sort_custom(func(a, b): return a["score"] > b["score"])
	else:
		rows.sort_custom(func(a, b): return (-1 if a["seat"] == winner else a["left"]) < (-1 if b["seat"] == winner else b["left"]))
	for r in rows:
		box.add_child(_row(r, me, int(r["seat"]) == winner, points_mode))
	if not xp_info.is_empty():
		var xp := UiKit.label(Loc.t("RESULT_XP", [int(xp_info["xp"])]), 24, Palette.TEAL, 800, true)
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(xp)
		if int(xp_info["level_after"]) > int(xp_info["level_before"]):
			var lv := UiKit.label(Loc.t("RESULT_LEVEL_UP", [int(xp_info["level_after"])]), 22, Palette.SUN, 800)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(lv)
	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var host := App.modal(pv[0])
	var menu := UiKit.button(TranslationServer.translate("RESULT_MENU"), UiKit.Variant.SECONDARY, Vector2(240, 64))
	menu.pressed.connect(func():
		host.close()
		on_menu.call())
	row.add_child(menu)
	if can_rematch:
		var again := UiKit.button(TranslationServer.translate("RESULT_REMATCH"), UiKit.Variant.ACCENT, Vector2(260, 64))
		again.pressed.connect(func():
			host.close()
			on_rematch.call())
		row.add_child(again)
		again.grab_focus.call_deferred()
	return host
