extends Control
## Store: Premium, cosmetic pack, coins from rewarded ads. Prices come only
## from the platform store; nothing here works as a fake purchase. On
## platforms without a store (Windows/desktop) the screen says so plainly.

var _coins: Label
var _body: VBoxContainer
var _status: Label


func _ready() -> void:
	var f := ScreenKit.frame(self, "MENU_STORE", handle_back)
	var col: VBoxContainer = f[0]
	_coins = f[1]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = UiKit.vbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_status = UiKit.label("", 17, Palette.SUN, 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	Store.products_updated.connect(_build)
	Store.entitlements_changed.connect(_build)
	Store.availability_changed.connect(func(_a): _build())
	Store.purchase_state_changed.connect(_on_purchase_state)
	Ads.rewarded_availability_changed.connect(func(_a): _build())
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	for c in _body.get_children():
		c.queue_free()
	_coins.text = str(Economy.coins())
	var row := UiKit.hbox(16)
	_body.add_child(row)
	row.add_child(_premium_card())
	var right := UiKit.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_pack_card())
	right.add_child(_coins_card())
	var foot := UiKit.hbox(12)
	_body.add_child(foot)
	var restore := UiKit.button(tr("STORE_RESTORE"), UiKit.Variant.SECONDARY, Vector2(260, 54))
	restore.disabled = not Store.is_available()
	restore.pressed.connect(func():
		_status.text = tr("STORE_RESTORING")
		Store.restore())
	foot.add_child(restore)
	var url := Store.manage_subscriptions_url()
	if url != "" and Store.product("cardrush_premium_monthly").size() > 0:
		var manage := UiKit.button(tr("STORE_MANAGE_SUBS"), UiKit.Variant.GHOST, Vector2(0, 54))
		manage.pressed.connect(func(): OS.shell_open(url))
		foot.add_child(manage)
	var note := UiKit.label(_availability_note(), 15, Palette.TEXT_DIM, 600)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)


func _availability_note() -> String:
	match Store.backend_kind():
		"unavailable":
			return tr("STORE_UNAVAILABLE_PLATFORM")
		"mock":
			return tr("STORE_MOCK_NOTE")
	if not Store.is_available():
		return tr("STORE_NOT_CONNECTED")
	return tr("STORE_NOTE")


func _card(title_key: String, accent: Color) -> VBoxContainer:
	var p := UiKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiKit.flat(Palette.PANEL, 24, 2, Color(accent, 0.6), 18, Color(accent, 0.18)))
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.label(tr(title_key), 28, accent, 800, true))
	return v


func _premium_card() -> Control:
	var v := _card("STORE_PREMIUM", Palette.SUN)
	var p: Control = v.get_parent()
	p.size_flags_stretch_ratio = 1.2
	for k in ["STORE_PREMIUM_B1", "STORE_PREMIUM_B2", "STORE_PREMIUM_B3"]:
		var h := UiKit.hbox(8)
		var ic := IconView.new()
		ic.icon = "check"
		ic.color = Palette.SUCCESS
		ic.custom_minimum_size = Vector2(24, 24)
		h.add_child(ic)
		var l := UiKit.label(tr(k), 18, Palette.TEXT, 650)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	if Store.is_premium():
		v.add_child(UiKit.label(tr("STORE_PREMIUM_ACTIVE"), 22, Palette.SUCCESS, 800))
		return p
	for pid in ["cardrush_premium", "cardrush_premium_yearly", "cardrush_premium_monthly"]:
		if Store.product(pid).is_empty():
			continue
		var price := Store.price_of(pid)
		var label := tr("STORE_" + pid.to_upper())
		var b := UiKit.button("%s  ·  %s" % [label, price if price != "" else tr("STORE_PRICE_UNKNOWN")],
			UiKit.Variant.ACCENT if pid == "cardrush_premium" else UiKit.Variant.SECONDARY, Vector2(0, 58))
		b.disabled = not Store.is_available() or price == ""
		var id: String = pid
		b.pressed.connect(func(): Store.purchase(id))
		v.add_child(b)
	return p


func _pack_card() -> Control:
	var v := _card("STORE_PACK_NEON", Palette.VIOLET)
	var row := UiKit.hbox(10)
	v.add_child(row)
	for back in ["back_neon", "back_gold", "back_mint"]:
		var cv := CardView.new()
		cv.face_up = false
		cv.back_style = back
		cv.set_card_size(Vector2(64, 96))
		row.add_child(cv)
	var desc := UiKit.label(tr("STORE_PACK_NEON_DESC"), 16, Palette.TEXT_DIM, 600)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc)
	if Store.owns("cardrush_pack_neon"):
		v.add_child(UiKit.label(tr("STORE_OWNED"), 20, Palette.SUCCESS, 800))
	else:
		var price := Store.price_of("cardrush_pack_neon")
		var b := UiKit.button(price if price != "" else tr("STORE_PRICE_UNKNOWN"), UiKit.Variant.PRIMARY, Vector2(220, 54))
		b.disabled = not Store.is_available() or price == ""
		b.pressed.connect(func(): Store.purchase("cardrush_pack_neon"))
		v.add_child(b)
	return v.get_parent()


func _coins_card() -> Control:
	var v := _card("STORE_COINS", Palette.TEAL)
	var l := UiKit.label(tr("STORE_COINS_DESC"), 16, Palette.TEXT_DIM, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	if Ads.can_offer_rewarded():
		var b := UiKit.button(Loc.t("STORE_WATCH_AD", [AdConfig.REWARDED_COINS]), UiKit.Variant.SUCCESS, Vector2(0, 56))
		b.pressed.connect(func():
			b.disabled = true
			Ads.show_rewarded("rewarded_ad", AdConfig.REWARDED_COINS, func(granted: bool):
				if granted:
					Audio.play("reward")
					App.toast(Loc.t("STORE_COINS_GRANTED", [AdConfig.REWARDED_COINS]), Palette.SUCCESS)
				else:
					App.toast(tr("STORE_AD_NO_REWARD"), Palette.TEXT_DIM)
				_build()))
		v.add_child(b)
	else:
		var why := tr("STORE_AD_PREMIUM") if Store.is_premium() else (tr("STORE_AD_NONE") if not Ads.has_ads() else tr("STORE_AD_NOT_READY"))
		var n := UiKit.label(why, 15, Palette.TEXT_MUTED, 600)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	var go := UiKit.button(tr("STORE_TO_COLLECTION"), UiKit.Variant.GHOST, Vector2(0, 50))
	go.pressed.connect(func(): App.goto("collection"))
	v.add_child(go)
	return v.get_parent()


func _on_purchase_state(pid: String, state: String, msg: String) -> void:
	match state:
		"started":
			_status.text = tr("STORE_PURCHASING")
		"purchased", "already_owned":
			_status.text = tr("STORE_THANKS")
		"pending":
			_status.text = tr("STORE_PENDING")
		"canceled":
			_status.text = tr("STORE_CANCELED")
		_:
			_status.text = Loc.error_text(msg) if msg.begins_with("ERR_") else tr("STORE_FAILED")
	_build()


func handle_back() -> void:
	App.goto("menu")
