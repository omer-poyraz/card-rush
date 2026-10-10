class_name Segmented
extends HBoxContainer
## A row of mutually exclusive option buttons.

signal changed(index: int)

var index := 0
var _buttons: Array[Button] = []


func _init(labels: Array = [], selected := 0, min_w := 96.0, font_size := 18) -> void:
	add_theme_constant_override("separation", 6)
	index = selected
	for i in labels.size():
		var b := UiKit.button(str(labels[i]), UiKit.Variant.SECONDARY, Vector2(min_w, 46))
		b.add_theme_font_size_override("font_size", font_size)
		var idx := i
		b.pressed.connect(func(): set_index(idx, true))
		_buttons.append(b)
		add_child(b)
	_restyle()


func set_index(i: int, emit := false) -> void:
	index = clampi(i, 0, _buttons.size() - 1)
	_restyle()
	if emit:
		changed.emit(index)


func _restyle() -> void:
	for i in _buttons.size():
		UiKit.style_button(_buttons[i], UiKit.Variant.PRIMARY if i == index else UiKit.Variant.SECONDARY)


class Stepper:
	extends HBoxContainer
	signal changed(value: int)
	var value := 0
	var min_v := 0
	var max_v := 10
	var step := 1
	var _label: Label
	var _fmt := "%d"

	func _init(v: int, lo: int, hi: int, st := 1, fmt := "%d") -> void:
		value = v
		min_v = lo
		max_v = hi
		step = st
		_fmt = fmt
		add_theme_constant_override("separation", 8)
		var minus := UiKit.button("–", UiKit.Variant.SECONDARY, Vector2(52, 46))
		minus.pressed.connect(func(): set_value(value - step, true))
		add_child(minus)
		_label = UiKit.label("", 24, Palette.TEXT, 800, true)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.custom_minimum_size.x = 90
		add_child(_label)
		var plus := UiKit.button("+", UiKit.Variant.SECONDARY, Vector2(52, 46))
		plus.pressed.connect(func(): set_value(value + step, true))
		add_child(plus)
		set_value(v)

	func set_value(v: int, emit := false) -> void:
		value = clampi(v, min_v, max_v)
		_label.text = _fmt % value
		if emit:
			changed.emit(value)
