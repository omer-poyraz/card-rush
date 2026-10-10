extends Node
## Autoload "App". Scene routing with fade transitions, shared parameters for
## the next scene, toasts, modal dialogs and the Android back button.

const SCENES := {
	"boot": "res://scenes/boot/boot.tscn",
	"menu": "res://scenes/menus/main_menu.tscn",
	"bot_setup": "res://scenes/menus/bot_setup.tscn",
	"table": "res://scenes/game/game_table.tscn",
	"lobby": "res://scenes/lobby/lobby.tscn",
	"profile": "res://scenes/menus/profile.tscn",
	"store": "res://scenes/menus/store.tscn",
	"collection": "res://scenes/menus/collection.tscn",
	"missions": "res://scenes/menus/missions.tscn",
	"friends": "res://scenes/menus/friends.tscn",
}

var params := {}             # data handed to the next scene
var capture_mode := false    # set by tools/capture to freeze randomness/ads
var _fade: ColorRect
var _layer: CanvasLayer
var _toast_box: VBoxContainer
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiKit.theme()
	get_tree().root.min_size = Vector2i(960, 540)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Palette.BG_DEEP
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_layer.add_child(_fade)
	_toast_box = VBoxContainer.new()
	_toast_box.theme = UiKit.theme()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_bottom = -110
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_toast_box)
	get_tree().root.size_changed.connect(_on_resize)


func _on_resize() -> void:
	pass


func goto(key: String, p := {}) -> void:
	if _busy:
		return
	_busy = true
	params = p
	var path: String = SCENES.get(key, key)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.18 * Settings.anim_scale())
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.25 * Settings.anim_scale())
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func toast(text: String, color := Palette.TEXT, seconds := 2.4) -> void:
	var p := PanelContainer.new()
	var sb := UiKit.flat(Color(0.06, 0.06, 0.16, 0.94), 18, 2, Color(color, 0.6), 12, Color(0, 0, 0, 0.4))
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 22, color, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 260
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## Shows a modal dialog built by Dialogs and returns it.
func modal(content: Control) -> Control:
	var host := Dialogs.make_modal(content)
	_layer.add_child(host)
	_layer.move_child(_toast_box, -1)
	_layer.move_child(_fade, -1)
	return host


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# close the topmost modal first, then let the scene handle it
		for i in range(_layer.get_child_count() - 1, -1, -1):
			var c := _layer.get_child(i)
			if c.has_meta("modal"):
				c.call("close")
				return
		var scene := get_tree().current_scene
		if scene and scene.has_method("handle_back"):
			scene.call("handle_back")
