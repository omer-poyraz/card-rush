class_name ScreenKit
extends RefCounted
## Common frame for menu screens: back button, title and coin balance.


## Builds the frame inside `screen` and returns [content_vbox, coin_label].
static func frame(screen: Control, title_key: String, on_back: Callable, show_coins := true) -> Array:
	screen.add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	screen.add_child(margin)
	var col := UiKit.vbox(14)
	margin.add_child(col)
	var top := UiKit.hbox(14)
	col.add_child(top)
	var back := UiKit.icon_button("back", TranslationServer.translate("BTN_BACK"), 58)
	back.pressed.connect(on_back)
	top.add_child(back)
	top.add_child(UiKit.title(TranslationServer.translate(title_key), 40))
	top.add_child(UiKit.spacer())
	var coin_label: Label = null
	if show_coins:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.flat(Color(1, 1, 1, 0.06), 24, 2, Color(Palette.SUN, 0.4)))
		var h := UiKit.hbox(8)
		chip.add_child(h)
		var ic := IconView.new()
		ic.icon = "coin"
		ic.color = Palette.SUN
		ic.custom_minimum_size = Vector2(30, 30)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		coin_label = UiKit.label(str(Economy.coins()), 24, Palette.SUN, 800, true)
		h.add_child(coin_label)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chip)
	return [col, coin_label]
