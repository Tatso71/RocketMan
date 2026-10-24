extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
var outpost: Node2D
var picker: Window
var tree: Tree
var choice_status: Label
var choose_button: Button
var selected_recipe := ""
var recipe_items: Dictionary = {}
var preview_panel: PanelContainer
var preview_label: Label
var window: Window
var title: Label
var requirements: Label
var transfer: Button
var remove: Button
var site: Dictionary = {}
var target_cell := Vector2i.ZERO
var prompted: Array[Dictionary] = []

func _ready() -> void:
	picker = Window.new()
	picker.title = "Costruisci"
	picker.visible = false
	picker.transient = true
	picker.exclusive = true
	picker.unresizable = true
	picker.close_requested.connect(_cancel_picker)
	picker.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("pause"):
			_cancel_picker()
			picker.set_input_as_handled())
	add_child(picker)
	var choice_panel := PanelContainer.new()
	choice_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_panel.add_theme_stylebox_override("panel", UI.panel_style())
	picker.add_child(choice_panel)
	var choice_column := VBoxContainer.new()
	choice_column.add_theme_constant_override("separation", 12)
	choice_panel.add_child(choice_column)
	choice_column.add_child(UI.label("CUBI CREATORI", 19))
	tree = Tree.new()
	tree.columns = 2
	tree.set_column_title(0, "Progetto")
	tree.set_column_title(1, "Materie prime")
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(470, 150)
	tree.add_theme_font_size_override("font_size", 16)
	tree.item_selected.connect(_select_recipe)
	tree.item_activated.connect(func():
		if not selected_recipe.is_empty():
			_choose(["laboratory", "lamp", "pump"].find(selected_recipe)))
	choice_column.add_child(tree)
	choice_status = UI.label("", 14)
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.custom_minimum_size.y = 48
	choice_column.add_child(choice_status)
	choose_button = UI.button(choice_column, "Posiziona cubo", func(): _choose(["laboratory", "lamp", "pump"].find(selected_recipe)))
	var overlay := CanvasLayer.new()
	add_child(overlay)
	preview_panel = PanelContainer.new()
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_theme_stylebox_override("panel", UI.panel_style())
	preview_panel.hide()
	overlay.add_child(preview_panel)
	preview_label = UI.label("", 14)
	preview_label.custom_minimum_size.x = 300
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_label)
	window = Window.new()
	window.visible = false
	window.transient = true
	window.exclusive = true
	window.unresizable = true
	window.title = "Cubo creatore"
	window.close_requested.connect(window.hide)
	window.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("pause"):
			window.hide()
			window.set_input_as_handled())
	add_child(window)
	var background := ColorRect.new()
	background.color = Color("222b2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	window.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	title = UI.label("", 20)
	column.add_child(title)
	column.add_child(HSeparator.new())
	requirements = UI.label("", 16)
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirements.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(requirements)
	transfer = UI.button(column, "Trasferisci materiali e costruisci", _fund)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	remove = UI.button(footer, "Rimuovi cubo", _remove)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	UI.button(footer, "Non ora", window.hide)

func is_open() -> bool:
	return picker.visible or window.visible

func open_picker(cell: Vector2i, viewport_point: Vector2) -> void:
	target_cell = cell
	selected_recipe = ""
	outpost.build_mode = false
	outpost.preview_fixed = false
	outpost.world.mouse_mining = false
	tree.clear()
	recipe_items.clear()
	var root := tree.create_item()
	var lab := _recipe_item(root, "laboratory", "Laboratorio / 4 x 3 m", "6 pietra + 4 rame")
	if outpost.laboratory_unlocked():
		_recipe_item(lab, "lamp", "Luce / 1 x 1 m", "1 terra + 1 rame")
		_recipe_item(lab, "pump", "Pompa / 2 x 2 m", "3 pietra + 4 rame")
	lab.collapsed = false
	choose_button.disabled = true
	choice_status.text = "" if outpost.laboratory_unlocked() else "Laboratorio non ancora completato"
	var point: Vector2 = outpost.get_viewport().get_screen_transform() * viewport_point
	picker.popup(Rect2i(Vector2i(point), Vector2i(510, 350)))

func _recipe_item(parent: TreeItem, id: String, name: String, cost: String) -> TreeItem:
	var item := tree.create_item(parent)
	item.set_text(0, name)
	item.set_text(1, cost)
	item.set_metadata(0, id)
	var origin: Vector2i = outpost.placement_origin(id, target_cell)
	var reason: String = outpost.placement_blocker(id, origin)
	item.set_tooltip_text(0, reason)
	if not reason.is_empty():
		item.set_custom_color(0, Color("b5aaa7"))
	recipe_items[id] = item
	return item

func _select_recipe() -> void:
	var selected := tree.get_selected()
	if selected == null:
		return
	selected_recipe = str(selected.get_metadata(0))
	outpost.blueprint = selected_recipe
	outpost.origin = outpost.placement_origin(selected_recipe, target_cell)
	outpost.build_mode = true
	outpost.preview_fixed = true
	choose_button.disabled = false
	var reason: String = outpost.placement_blocker(selected_recipe, outpost.origin)
	choice_status.text = "Area libera" if reason.is_empty() else reason

func _cancel_picker() -> void:
	picker.hide()
	outpost.build_mode = false
	outpost.preview_fixed = false

func _choose(id: int) -> void:
	if id < 0 or id >= 3:
		return
	var recipe: String = ["laboratory", "lamp", "pump"][id]
	if not outpost.recipe_visible(recipe):
		return
	picker.hide()
	selected_recipe = recipe
	outpost.blueprint = recipe
	outpost.origin = outpost.placement_origin(recipe, target_cell)
	outpost.build_mode = true
	outpost.preview_fixed = false
	outpost.world.mouse_aim = true

func open_site(building: Dictionary) -> void:
	if building.id == "ladder" or not outpost.site_reachable(building):
		return
	site = building
	if building not in prompted:
		prompted.append(building)
	outpost.world.mouse_mining = false
	_refresh()
	window.popup_centered(Vector2i(540, 370))

func _refresh() -> void:
	title.text = "CUBO / " + {"laboratory": "LABORATORIO", "lamp": "LUCE", "pump": "POMPA"}[site.id]
	var lines: Array[String] = []
	var cost: Dictionary = outpost.site_cost(site)
	for id: String in cost:
		var amount: int = outpost.world.field_cargo.available(id, outpost.world.drone_help_available(), outpost.payment_cache())
		lines.append("%s: %d / %d%s" % [UI.NAMES[id], amount, cost[id], " / mancano %d" % (int(cost[id]) - amount) if amount < int(cost[id]) else ""])
	var reason: String = outpost.funding_blocker(site)
	requirements.text = "\n".join(lines) + "\n\n" + ("Hai tutte le materie prime. Vuoi trasferirle qui e avviare la costruzione?" if reason.is_empty() else reason)
	transfer.disabled = not reason.is_empty()
	transfer.tooltip_text = reason
	remove.disabled = site.get("state") != "planned"

func _fund() -> void:
	if outpost.fund_site(site):
		window.hide()
	else:
		_refresh()

func _remove() -> void:
	if site.get("state") == "planned" and outpost.site_reachable(site):
		outpost.buildings.structures.erase(site)
		window.hide()
		prompted.erase(site)

func _process(_delta: float) -> void:
	preview_panel.visible = outpost.build_mode and not picker.visible and not outpost.world.controls_blocked()
	if preview_panel.visible:
		var reason: String = outpost.placement_blocker(outpost.blueprint, outpost.origin)
		preview_label.text = {"laboratory": "Laboratorio", "lamp": "Luce", "pump": "Pompa"}[outpost.blueprint] + "\n" + ("Area libera" if reason.is_empty() else reason)
		preview_label.modulate = Color("a7e5b4") if reason.is_empty() else Color("ffb18e")
		var bounds := outpost.get_viewport().get_visible_rect().size
		preview_panel.position = (outpost.get_viewport().get_mouse_position() + Vector2(24, 24)).clamp(Vector2(16, 190), bounds - preview_panel.size - Vector2(16, 100))
	if window.visible:
		if not outpost.buildings.structures.has(site) or not outpost.site_reachable(site):
			window.hide()
		else:
			_refresh()
		return
	for previous: Dictionary in prompted.duplicate():
		if not outpost.site_reachable(previous):
			prompted.erase(previous)
	if outpost.world.controls_blocked() or outpost.build_mode:
		return
	for building: Dictionary in outpost.buildings.structures:
		if building.id != "ladder" and building.get("state") == "planned" and building not in prompted and outpost.site_reachable(building):
			open_site(building)
			break
