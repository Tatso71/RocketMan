extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Components = preload("res://scripts/data/component_catalog.gd")
const CostRow = preload("res://scripts/ui/assembly_cost_row.gd")
var outpost: Node2D
var popup: PopupPanel
var anchor := Vector2i.ZERO
var site: Dictionary = {}
var rows := {}
var column: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var mount_button: Button
var blocker_label: Label
var focus_order: Array[Button] = []
var refresh_timer := 0.0

func _ready() -> void:
	popup = PopupPanel.new()
	popup.visible = false
	popup.add_theme_stylebox_override("panel", UI.panel_style())
	popup.window_input.connect(_popup_input)
	add_child(popup)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
	popup.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	heading = UI.label("Montaggio", 16)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(UI.label("Hai / Servono", 12, Color("a5b4b6")))
	layout.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	scroll.add_child(column)

func _popup_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		popup.hide()
		popup.set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var buttons := _focus_buttons()
		if buttons.is_empty(): return
		var current := buttons.find(popup.gui_get_focus_owner())
		var step := 1 if event.is_action_pressed("ui_down") else -1
		buttons[wrapi(current + step, 0, buttons.size())].grab_focus()
		popup.set_input_as_handled()

func _focus_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button: Button in focus_order:
		if is_instance_valid(button) and button.is_inside_tree() and not button.disabled:
			buttons.append(button)
	return buttons

func _focus_first() -> void:
	var buttons := _focus_buttons()
	if is_open() and not buttons.is_empty():
		buttons[0].grab_focus()

func _clear() -> void:
	rows.clear()
	focus_order.clear()
	mount_button = null
	blocker_label = null
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func _add_row(key: int, id: String, cost: Dictionary) -> Button:
	var row := CostRow.new()
	row.configure(id, "Scala" if id == "ladder" else outpost.Buildings.NAMES[id], cost)
	column.add_child(row)
	rows[key] = row
	row.pressed.connect(_choose.bind(key))
	focus_order.append(row)
	return row

func _show(point: Vector2) -> void:
	refresh()
	var owner_window := outpost.get_window()
	var size := Vector2i(mini(400, owner_window.size.x - 24), mini(72 + rows.size() * 40 + (140 if not site.is_empty() else 0), owner_window.size.y - 96))
	var screen_point: Vector2 = outpost.get_viewport().get_screen_transform() * point
	var position := Vector2i(screen_point).clamp(Vector2i(12, 64), owner_window.size - size - Vector2i(12, 32))
	popup.popup(Rect2i(position, size))
	_focus_first.call_deferred()

func refresh() -> void:
	var stock := {}
	var world: Node2D = outpost.world
	for resource: String in Components.COMPONENT_IDS:
		stock[resource] = world.field_cargo.available(resource, world.drone_help_available())
	for row: Button in rows.values(): row.refresh(stock)
	if is_instance_valid(mount_button):
		var reason: String = outpost.funding_blocker(site)
		mount_button.disabled = not reason.is_empty()
		mount_button.modulate = CostRow.READY if reason.is_empty() else CostRow.MISSING
		mount_button.tooltip_text = reason
		blocker_label.text = reason if not reason.is_empty() else "Pronto al montaggio"
		blocker_label.add_theme_color_override("font_color", Color("ffb18e") if not reason.is_empty() else CostRow.READY)

func _process(delta: float) -> void:
	if not is_open(): return
	refresh_timer -= delta
	if refresh_timer <= 0:
		refresh_timer = 0.15
		refresh()

func is_open() -> bool:
	return popup.visible

func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in cost:
		parts.append("%d %s" % [cost[id], "strutturali" if id == "structural_component" else "elettronici"])
	return " + ".join(parts)

func open_picker(cell: Vector2i, point: Vector2) -> void:
	anchor = cell
	site = {}
	outpost.build_mode = false
	outpost.world.mouse_mining = false
	_clear()
	heading.text = "Montaggio"
	for index in range(Components.STRUCTURE_IDS.size()):
		var id: String = Components.STRUCTURE_IDS[index]
		if id != "laboratory" and not outpost.laboratory_unlocked():
			continue
		_add_row(index, id, Components.assembly_cost(id))
	column.add_child(HSeparator.new())
	_add_row(100, "ladder", {})
	_show(point)

func _choose(id: int) -> void:
	popup.hide()
	if id == 1000:
		if not outpost.fund_site(site):
			outpost.world._note(outpost.funding_blocker(site))
		return
	if id == 1001:
		outpost.cancel_plan(site)
		return
	if id == 100:
		outpost.world.place_ladder_at(anchor)
		return
	if id < 0 or id >= Components.STRUCTURE_IDS.size():
		return
	outpost.blueprint = Components.STRUCTURE_IDS[id]
	outpost.origin = outpost.placement_origin(outpost.blueprint, anchor)
	outpost.preview_fixed = false
	outpost.activation_cube_id = 0
	outpost.build_mode = true
	outpost.world.mouse_mining = false
	outpost.world._note("%s / %s" % [outpost.Buildings.NAMES[outpost.blueprint], cost_text(Components.assembly_cost(outpost.blueprint))])

func open_site(building: Dictionary) -> void:
	site = building
	_clear()
	heading.text = "Progetto"
	var row := _add_row(-1, building.id, outpost.site_cost(building))
	row.disabled = true
	focus_order.clear()
	blocker_label = UI.label("", 14)
	blocker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blocker_label.custom_minimum_size.y = 48
	blocker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(blocker_label)
	column.add_child(HSeparator.new())
	mount_button = UI.button(column, "Monta", _choose.bind(1000))
	focus_order.append(mount_button)
	focus_order.append(UI.button(column, "Annulla progetto", _choose.bind(1001)))
	_show(outpost.get_viewport_rect().size * 0.5 - Vector2(200, 100))
