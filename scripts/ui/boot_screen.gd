extends Control
## Splash: cards fly in and fan out, gather into a stack, the logo pops in with
## a light pass, then the main menu. About 2.3 s; any tap skips.

var _cards: Array[CardView] = []
var _logo: LogoView
var _done := false


func _ready() -> void:
	add_child(Backdrop.new())
	_ensure_profile()
	var center := get_viewport_rect().size / 2.0
	var picks := [7, 33, 58, 83, 105, 21, 46, 71, 101]  # a colourful spread of card ids
	for i in picks.size():
		var cv := CardView.new()
		cv.card_id = picks[i]
		cv.set_card_size(Vector2(96, 144))
		cv.position = center - cv.size / 2.0 + Vector2.from_angle(i * TAU / picks.size()) * 900.0
		cv.rotation = randf_range(-1.5, 1.5)
		add_child(cv)
		_cards.append(cv)
	_logo = LogoView.new()
	_logo.custom_minimum_size = Vector2(560, 170)
	_logo.size = Vector2(560, 170)
	_logo.position = center - _logo.size / 2.0
	_logo.pivot_offset = _logo.size / 2.0
	_logo.scale = Vector2(0.6, 0.6)
	_logo.modulate.a = 0.0
	add_child(_logo)
	Audio.play_music("music_menu")
	_animate()


func _ensure_profile() -> void:
	var prof := Save.section("profile")
	if str(prof.get("name", "")) == "":
		prof["name"] = tr("DEFAULT_PLAYER_NAME") + str(randi_range(1000, 9999))
		prof["avatar"] = randi_range(0, AvatarView.COUNT - 1)
		Save.mark_dirty()


func _animate() -> void:
	var k := Settings.anim_scale()
	var center := get_viewport_rect().size / 2.0
	Audio.play("shuffle")
	var tw := create_tween().set_parallel()
	for i in _cards.size():
		var cv := _cards[i]
		var ang := lerpf(-0.9, 0.9, float(i) / (_cards.size() - 1))
		var target := center - cv.size / 2.0 + Vector2(sin(ang) * 330.0, -cos(ang) * 60.0 + 40.0)
		tw.tween_property(cv, "position", target, 0.55 * k).set_delay(i * 0.04 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(cv, "rotation", ang * 0.55, 0.55 * k).set_delay(i * 0.04 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if _done:
		return
	var tw2 := create_tween().set_parallel()
	for i in _cards.size():
		var cv := _cards[i]
		tw2.tween_property(cv, "position", center - cv.size / 2.0 + Vector2(0, 150) + Vector2(i * 1.5, -i * 1.5), 0.35 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw2.tween_property(cv, "rotation", 0.0, 0.35 * k)
		tw2.tween_property(cv, "modulate:a", 0.0, 0.3 * k).set_delay(0.25 * k)
	tw2.tween_property(_logo, "modulate:a", 1.0, 0.3 * k).set_delay(0.2 * k)
	tw2.tween_property(_logo, "scale", Vector2.ONE, 0.45 * k).set_delay(0.2 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	if _done:
		return
	Audio.play("card_special")
	var tw3 := create_tween()
	tw3.tween_property(_logo, "shine", 1.0, 0.6 * k)
	tw3.tween_interval(0.25 * k)
	await tw3.finished
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	App.goto("menu")


func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed):
		_finish()
