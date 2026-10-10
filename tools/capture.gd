extends Node
## Renders a scene in a real window and saves a screenshot (visual QA, store art).
##   godot --path . --resolution 1280x720 res://tools/capture.tscn -- --scene menu --wait 2.5 --out /abs/menu.png
## --scene: boot | menu | bot_setup | profile | table | cards | settings | help
## Table options: --players N --autoplay 1 --wait S --lang tr|en --colorblind 1

var args := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--"):
			args[a[i].substr(2)] = a[i + 1] if i + 1 < a.size() and not a[i + 1].begins_with("--") else "1"
		i += 1
	App.capture_mode = true
	# keep this node alive across scene changes
	get_tree().current_scene = null
	Save.path = "user://capture_save.json"
	Save.backup_path = "user://capture_save.bak.json"
	Save.data = Save.defaults()
	Save.section("profile")["name"] = "Ömer"
	Save.section("profile")["xp"] = 640
	Settings._ready()
	if args.has("lang"):
		Loc.set_language(args["lang"])
	if args.has("colorblind"):
		Settings.set_value("colorblind", true)
	if args.has("reduced"):
		Settings.set_value("animation", 1)
	if args.has("quality"):
		Settings.set_value("quality", int(args["quality"]))
	var scene: String = args.get("scene", "menu")
	match scene:
		"table":
			var n := int(args.get("players", "4"))
			var levels := []
			for k in n - 1:
				levels.append(k % 3)
			var prof := RuleProfile.classic()
			if args.has("points"):
				prof.scoring_mode = RuleProfile.ScoringMode.POINTS
			App.params = {"mode": "offline", "profile": prof.to_dict(), "bots": levels, "autoplay": args.has("autoplay")}
			get_tree().change_scene_to_file(App.SCENES["table"])
		"cards":
			_card_sheet()
		"settings":
			get_tree().change_scene_to_file(App.SCENES["menu"])
			await get_tree().create_timer(0.5).timeout
			SettingsDialog.open()
		"help":
			get_tree().change_scene_to_file(App.SCENES["menu"])
			await get_tree().create_timer(0.5).timeout
			HelpDialog.open(int(args.get("tab", "0")))
		_:
			get_tree().change_scene_to_file(App.SCENES.get(scene, scene))
	if args.has("challenge"):
		# force a +4 challenge prompt for the local seat (UI check)
		await get_tree().create_timer(3.5).timeout
		var gt := get_tree().current_scene
		var auth: MatchAuthority = gt.authority
		auth.paused = true
		auth.state.current = 0
		auth.state.phase = GameState.Phase.CHALLENGE_DECISION
		auth.state.pending_draw = 4
		auth.state.challenge = {"offender": 1, "color_before": 0, "guilty": false}
		auth._publish([])
	await get_tree().create_timer(float(args.get("wait", "2.0"))).timeout
	var img := get_viewport().get_texture().get_image()
	var out: String = args.get("out", "/tmp/card_rush_capture.png")
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit()


func _card_sheet() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(root)
	var bg := ColorRect.new()
	bg.color = Palette.BG_NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var ids := [0, 1, 3, 19, 20, 21, 22, 23, 24, 25, 26, 45, 46, 72, 73, 95, 97, 99, 100, 104]
	for k in ids.size():
		var cv := CardView.new()
		cv.card_id = ids[k]
		cv.set_card_size(Vector2(110, 165))
		cv.position = Vector2(20 + (k % 10) * 124, 30 + (k / 10) * 190)
		root.add_child(cv)
	for k in 3:
		var b := CardView.new()
		b.face_up = false
		b.back_style = ["back_classic", "back_sunset", "back_aurora"][k]
		b.set_card_size(Vector2(110, 165))
		b.position = Vector2(20 + k * 124, 420)
		root.add_child(b)
	for k in 4:
		var sm := CardView.new()
		sm.card_id = [7, 40, 60, 105][k]
		sm.set_card_size(Vector2(60, 90))
		sm.position = Vector2(420 + k * 70, 440)
		root.add_child(sm)
	var hl := CardView.new()
	hl.card_id = 50
	hl.playable = true
	hl.set_card_size(Vector2(110, 165))
	hl.position = Vector2(740, 420)
	root.add_child(hl)
	var sel := CardView.new()
	sel.card_id = 80
	sel.selected = true
	sel.set_card_size(Vector2(110, 165))
	sel.position = Vector2(870, 420)
	root.add_child(sel)
	var dim := CardView.new()
	dim.card_id = 30
	dim.dim = true
	dim.set_card_size(Vector2(110, 165))
	dim.position = Vector2(1000, 420)
	root.add_child(dim)
