extends HBoxContainer

const ENERGY_COLOR := Color("f1c56b")
const SUIT_COLOR := Color("72d4e4")
var energy_bar: ProgressBar
var suit_bar: ProgressBar
var energy_title: Label
var suit_title: Label
var energy_value: Label
var suit_value: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(304, 27)
	add_theme_constant_override("separation", 16)
	var energy := _meter(ENERGY_COLOR)
	energy_title = energy.title
	energy_value = energy.value
	energy_bar = energy.bar
	var suit := _meter(SUIT_COLOR)
	suit_title = suit.title
	suit_value = suit.value
	suit_bar = suit.bar
	update_values(100, 100)

func _label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("17212a"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _meter(color: Color) -> Dictionary:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title := _label(color)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var value := _label(color)
	value.custom_minimum_size.x = 36
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 4
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("121a1d")
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	return {"title": title, "value": value, "bar": bar}

func update_values(energy: float, suit: float, robot: bool = false) -> void:
	energy_bar.value = clampf(energy, 0, 100)
	suit_bar.value = clampf(suit, 0, 100)
	energy_title.text = "Carica" if robot else "Energia"
	suit_title.text = "Scocca" if robot else "Tuta"
	energy_value.text = "%.0f%%" % energy_bar.value
	suit_value.text = "%.0f%%" % suit_bar.value
