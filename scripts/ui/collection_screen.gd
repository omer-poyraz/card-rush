extends Control
## Collection: card backs, table themes and profile frames. Buy with coins,
## unlock by level/premium/pack, equip. Purely cosmetic.

var _coins: Label
var _grid: GridContainer
var _tabs: Segmented
var _type := "back"


func _ready() -> void:
	var f := ScreenKit.frame(self, "MENU_COLLECTION", handle_back)
	var col: VBoxContainer = f[0]
	_coins = f[1]
	_tabs = Segmented.new([tr("COLL_BACKS"), tr("COLL_TABLES"), tr("COLL_FRAMES")], 0, 170)
	_tabs.changed.connect(func(i):
		_type = Cosmetics.TYPES[i]
		_build())
	col.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	Store.entitlements_changed.connect(_build)
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	_coins.text = str(Economy.coins())
	for c in _grid.get_children():
		c.queue_free()
	var equipped := Cosmetics.equipped(_type)
	for it in Cosmetics.of_type(_type):
		_grid.add_child(_tile(it, it["id"] == equipped))


func _tile(it: Dictionary, is_equipped: bool) -> Control:
	var id: String = it["id"]
	var owned := Cosmetics.is_owned(id)
	var p := PanelContainer.new()
	var edge := Palette.SUN if is_equipped else (Color(1, 1, 1, 0.12) if owned else Color(1, 1, 1, 0.06))
	p.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.05 if owned else 0.02), 18, 2, edge))
	p.custom_minimum_size = Vector2(176, 250)
	var v := UiKit.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(150, 140)
	v.add_child(preview)
	match it["type"]:
		"back":
			var cv := CardView.new()
			cv.face_up = false
			cv.back_style = id
			cv.set_card_size(Vector2(84, 126))
			cv.position = Vector2(33, 6)
			preview.add_child(cv)
		"table":
			var sw := TableSwatch.new()
			sw.theme_id = id
			sw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			preview.add_child(sw)
		"frame":
			var av := AvatarView.new()
			av.avatar = int(Save.section("profile").get("avatar", 0))
			av.ring_color = Cosmetics.frame_color(id)
			av.size = Vector2(110, 110)
			av.position = Vector2(20, 14)
			preview.add_child(av)
	if not owned:
		preview.modulate = Color(1, 1, 1, 0.55)
	var name := UiKit.label(tr("COS_" + id.to_upper()), 18, Palette.TEXT, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var action: Button
	if is_equipped:
		action = UiKit.button(tr("COLL_EQUIPPED"), UiKit.Variant.GHOST, Vector2(150, 44))
		action.disabled = true
	elif owned:
		action = UiKit.button(tr("COLL_EQUIP"), UiKit.Variant.PRIMARY, Vector2(150, 44))
		action.pressed.connect(func():
			Cosmetics.equip(id)
			Audio.play("color_pick")
			_build())
	else:
		match str(it.get("unlock", "")):
			"coins":
				action = UiKit.button(Loc.t("COLL_BUY_N", [int(it["price"])]), UiKit.Variant.ACCENT, Vector2(150, 44))
				action.disabled = Economy.coins() < int(it["price"])
				action.pressed.connect(func():
					var err := Cosmetics.buy(id)
					if err != "":
						App.toast(tr(err), Palette.CORAL)
					else:
						Audio.play("reward")
						Cosmetics.equip(id)
					_build())
			"level":
				action = UiKit.button(Loc.t("COLL_LEVEL_N", [int(it["level"])]), UiKit.Variant.GHOST, Vector2(150, 44))
				action.disabled = true
			"premium":
				action = UiKit.button(tr("COLL_PREMIUM"), UiKit.Variant.GHOST, Vector2(150, 44))
				action.pressed.connect(func(): App.goto("store"))
			_:
				action = UiKit.button(tr("COLL_PACK"), UiKit.Variant.GHOST, Vector2(150, 44))
				action.pressed.connect(func(): App.goto("store"))
	action.add_theme_font_size_override("font_size", 17)
	action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(action)
	return p


func handle_back() -> void:
	App.goto("menu")


class TableSwatch:
	extends Control
	var theme_id := "table_night"

	func _draw() -> void:
		var th := Cosmetics.table_theme(theme_id)
		var c := size / 2.0
		var r := Vector2(size.x * 0.46, size.y * 0.38)
		draw_colored_polygon(TableFelt._ellipse(c, r, 40), th["felt"])
		draw_colored_polygon(TableFelt._ellipse(c, r * 0.65, 32), Color(th["felt2"], 0.8))
		var rim := TableFelt._ellipse(c, r, 40)
		rim.append(rim[0])
		draw_polyline(rim, th["rim"], 3.0, true)
