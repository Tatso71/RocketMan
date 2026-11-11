extends Button

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
const READY := Color("a7e5b4")
const MISSING := Color("8d999d")
var title: Label
var item_icon: TextureRect
var free_label: Label
var resource_labels := {}
var resource_icons := {}
var affordable := false
var cost := {}
var _stock := {}
var _fresh := true

func configure(id: String, name_text: String, requirements: Dictionary) -> void:
	cost = requirements.duplicate()
	custom_minimum_size = Vector2(352, 38)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	for state: String in ["hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("303d41") if state != "focus" else Color.TRANSPARENT
		style.set_corner_radius_all(4)
		if state == "focus":
			style.set_border_width_all(1)
			style.border_color = Color("8ecfc5")
		add_theme_stylebox_override(state, style)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.offset_top = 4
	line.offset_bottom = -4
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	item_icon = ItemIcons.view(id, 24)
	line.add_child(item_icon)
	title = UI.label(name_text, 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(title)
	var resources := HBoxContainer.new()
	resources.custom_minimum_size.x = 180
	resources.alignment = BoxContainer.ALIGNMENT_END
	resources.add_theme_constant_override("separation", 8)
	resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(resources)
	for resource: String in cost:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resources.add_child(chip)
		var icon := ItemIcons.view(resource, 24)
		chip.add_child(icon)
		resource_icons[resource] = icon
		var amount := UI.label("", 14)
		amount.custom_minimum_size.x = 58
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(amount)
		resource_labels[resource] = amount
	if cost.is_empty():
		free_label = UI.label("Gratis", 14, READY)
		free_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		free_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resources.add_child(free_label)
	refresh({})

func refresh(available: Dictionary) -> void:
	if not _fresh and _stock == available: return
	_fresh = false
	_stock = available.duplicate()
	affordable = true
	var details: Array[String] = []
	for resource: String in cost:
		var owned := int(available.get(resource, 0))
		var enough := owned >= int(cost[resource])
		affordable = affordable and enough
		resource_labels[resource].text = "%d / %d" % [owned, cost[resource]]
		resource_labels[resource].add_theme_color_override("font_color", READY if enough else MISSING)
		details.append("%s: hai %d, servono %d" % [UI.NAMES[resource], owned, cost[resource]])
	title.add_theme_color_override("font_color", READY if affordable else MISSING)
	item_icon.modulate = Color.WHITE if affordable else Color(0.65, 0.65, 0.65)
	tooltip_text = "\n".join(details) if not cost.is_empty() else "Scala gratuita"
