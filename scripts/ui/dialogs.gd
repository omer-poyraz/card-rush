class_name Dialogs
extends RefCounted
## Modal dialog helpers (dimmed backdrop, pop-in animation, back-button aware).


class ModalHost:
	extends Control
	signal closed
	var content: Control

	func _ready() -> void:
		set_meta("modal", true)
		theme = UiKit.theme()  # CanvasLayer children don't inherit the window theme
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.01, 0.01, 0.05, 0.72)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and content.has_meta("dismissable"):
				close())
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		center.add_child(content)
		content.pivot_offset = content.get_combined_minimum_size() / 2.0
		content.scale = Vector2(0.9, 0.9)
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.tween_property(content, "scale", Vector2.ONE, 0.22 * Settings.anim_scale()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func close() -> void:
		if is_queued_for_deletion():
			return
		closed.emit()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		tw.tween_callback(queue_free)


static func make_modal(content: Control) -> Control:
	var h := ModalHost.new()
	h.content = content
	return h


## Standard titled panel. Returns [panel, body_vbox].
static func titled_panel(title_text: String, width := 640.0) -> Array:
	var p := UiKit.panel()
	p.custom_minimum_size.x = width
	var v := UiKit.vbox(16)
	p.add_child(v)
	var t := UiKit.title(title_text, 34)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return [p, v]


## Message box with buttons. buttons: Array of [text, variant, Callable or null].
static func message(title_text: String, body: String, buttons: Array, width := 600.0) -> Control:
	var pv := titled_panel(title_text, width)
	var v: VBoxContainer = pv[1]
	var l := UiKit.label(body, 22, Palette.TEXT_DIM, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = width - 60
	v.add_child(l)
	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var host := App.modal(pv[0])
	for b in buttons:
		var btn := UiKit.button(b[0], b[1], Vector2(200, 60))
		var cb: Variant = b[2] if b.size() > 2 else null
		btn.pressed.connect(func():
			host.close()
			if cb is Callable:
				cb.call())
		row.add_child(btn)
	return host


static func info(title_text: String, body: String) -> Control:
	return message(title_text, body, [[tr_static("BTN_OK"), UiKit.Variant.PRIMARY, null]])


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)
