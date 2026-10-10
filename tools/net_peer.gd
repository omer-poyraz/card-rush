extends Node
## Two-process multiplayer check over real ENet sockets with the real table UI.
##   godot --path . res://tools/net_peer.tscn -- --role host   --code ABCDEF --port 47820 --out /tmp/h.png
##   godot --path . res://tools/net_peer.tscn -- --role client --code ABCDEF --port 47820 --out /tmp/c.png
## Each process drives its own seat with a bot brain that only sees its view.
## Prints "NETPEER_RESULT ..." lines and exits.

var args := {}
var bot: BotController
var acted := {}
var started_ms := 0
var shot_taken := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--"):
			args[a[i].substr(2)] = a[i + 1] if i + 1 < a.size() and not a[i + 1].begins_with("--") else "1"
		i += 1
	get_tree().current_scene = null
	App.capture_mode = true
	Save.path = "user://netpeer_%s.json" % args.get("role", "x")
	Save.data = Save.defaults()
	Save.section("profile")["name"] = "Host" if args.get("role") == "host" else "Misafir"
	Save.section("profile")["avatar"] = 1 if args.get("role") == "host" else 5
	Settings.set_value("animation", 1)
	Loc.set_language(args.get("lang", "tr"))
	var port := int(args.get("port", "47820"))
	var code: String = args.get("code", "ABCDEF")
	if args.get("role") == "host":
		Net.host_port = port
		var err := Net.create_room({"name": "Test", "max_players": 3, "bots": [1], "voice": args.has("voice"), "rules": RuleProfile.classic().to_dict()}, code)
		print("NETPEER host create: ", err if err != "" else "ok")
		Net.host.lobby_changed.connect(_host_lobby)
		Net.host.match_started.connect(func(lc): _open_table(lc))
	else:
		await get_tree().create_timer(1.0).timeout
		var c := Net.join_room("127.0.0.1", port, code)
		c.state_changed.connect(func(s, d):
			print("NETPEER client state ", s, " ", d)
			if s == "lobby":
				c.set_ready(true))
		c.match_starting.connect(func(mc, _r): _open_table(mc))
	get_tree().create_timer(float(args.get("timeout", "90"))).timeout.connect(_finish.bind("timeout"))


func _host_lobby() -> void:
	if Net.host and not Net.host.in_match and Net.host.can_start() == "" and Net.host.members.size() >= 2:
		print("NETPEER host starting")
		Net.host.start_match()


func _open_table(mc: MatchClient) -> void:
	bot = BotController.new(BotController.Level.NORMAL, mc.seat)
	started_ms = Time.get_ticks_msec()
	App.params = {"mode": "online", "client": mc, "return_to": "lobby"}
	get_tree().change_scene_to_file(App.SCENES["table"])


var _tone_t := 0.0
var _tone_acc := 0.0
var voice_max_level := 0.0
var voice_frames := 0


func _voice_probe(dt: float) -> void:
	if not args.has("voice") or Net.match_client() == null:
		return
	if args.get("role") == "host":
		# speak a 300 Hz tone as if from the microphone
		_tone_acc += dt
		while _tone_acc >= 0.04:
			_tone_acc -= 0.04
			var f := PackedFloat32Array()
			f.resize(VoiceSettings.FRAME_SAMPLES)
			for i in f.size():
				f[i] = sin(_tone_t) * 0.3
				_tone_t += TAU * 300.0 / VoiceSettings.SAMPLE_RATE
			Voice.submit_frame(f)
	else:
		if Voice.participants.has(1):
			var p: VoiceParticipant = Voice.participants[1]
			voice_max_level = maxf(voice_max_level, p.level)
			voice_frames = maxi(voice_frames, p.queued_frames())


func _process(dt: float) -> void:
	_voice_probe(dt)
	var mc := Net.match_client()
	if mc == null or bot == null:
		return
	if Net.host and Net.host.authority:
		Net.host.authority.bot_think_scale = 0.3
	var v := mc.last_view
	if not shot_taken and started_ms > 0 and Time.get_ticks_msec() - started_ms > int(float(args.get("shot_after", "6")) * 1000):
		shot_taken = true
		var img := get_viewport().get_texture().get_image()
		img.save_png(args.get("out", "/tmp/netpeer.png"))
		print("NETPEER shot saved")
	if v.is_empty():
		return
	if int(v["phase"]) == GameState.Phase.MATCH_OVER:
		_finish("over")
		return
	if int(v["current"]) != mc.seat or int(v["phase"]) >= GameState.Phase.ROUND_OVER:
		return
	var key := int(v["version"])
	if acted.has(key) and Engine.get_process_frames() - int(acted[key]) < 60:
		return
	acted[key] = Engine.get_process_frames()
	var a := bot.choose_action(v)
	if a["type"] == "play" and v["hand"].size() == 2:
		mc.send({"type": "uno"})
	mc.send(a)


var _done := false


func _finish(why: String) -> void:
	if _done:
		return
	_done = true
	var mc := Net.match_client()
	var v: Dictionary = mc.last_view if mc else {}
	var line := "NETPEER_RESULT role=%s why=%s version=%s winner=%s hand=%d" % [args.get("role"), why, v.get("version", -1), v.get("match_winner", -1), v.get("hand", []).size()]
	if args.has("voice"):
		line += " voice_enabled=%s voice_peak=%.2f" % [Voice.enabled(), voice_max_level]
	if Net.host and Net.host.authority:
		line += " authority_version=%d integrity=%s" % [Net.host.authority.state.version, Net.host.authority.state.check_integrity()]
	print(line)
	if not shot_taken:
		get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/netpeer.png"))
	await get_tree().create_timer(1.5).timeout
	Net.leave_room()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
