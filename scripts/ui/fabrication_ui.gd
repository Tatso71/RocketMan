extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Catalog = preload("res://scripts/data/component_catalog.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
var outpost: Node2D
var picker: Window
var activation_popup: PopupMenu
var heading: Label
var choice_status: Label
var craft_bar: ProgressBar
var craft_button: Button
var duration: Label
var resource_labels: Dictionary = {}
var recipe_grid: GridContainer
var recipe_rows: Dictionary = {}
var visible_recipes: Array[String] = []
var collect_button: Button
var site: Dictionary = {}

func _ready() -> void:
	picker = Window.new()
	picker.title = "Laboratorio / produzione componenti"
	picker.visible = false
	picker.transient = true
	picker.exclusive = true
	picker.unresizable = true
	picker.close_requested.connect(picker.hide)
	picker.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("pause"):
			picker.hide()
			picker.set_input_as_handled())
	add_child(picker)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	picker.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = UI.label("PRODUZIONE", 20)
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	recipe_grid = GridContainer.new()
	recipe_grid.columns = 6
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation", 12)
	recipe_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(recipe_grid)
	craft_bar = ProgressBar.new()
	craft_bar.custom_minimum_size.y = 20
	column.add_child(craft_bar)
	choice_status = UI.label("", 14)
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.custom_minimum_size.y = 48
	column.add_child(choice_status)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	collect_button = UI.button(footer, "Ritira componenti", func():
		outpost.collect_fabrication_output()
		refresh())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	UI.button(footer, "Chiudi", picker.hide)
	activation_popup = PopupMenu.new()
	activation_popup.prefer_native_menu = false
	activation_popup.id_pressed.connect(func(id: int):
		if id == 2 and outpost.buildings.structures.has(site) and outpost.site_reachable(site):
			site.enabled = not site.get("enabled", true))
	add_child(activation_popup)
	_sync_recipes()

func _sync_recipes() -> void:
	var next: Array[String] = []
	for id: String in Catalog.RECIPE_IDS:
		if not Catalog.recipe(id).advanced or outpost.laboratory_unlocked():
			next.append(id)
	if next == visible_recipes:
		return
	visible_recipes = next
	for child in recipe_grid.get_children():
		recipe_grid.remove_child(child)
		child.queue_free()
	recipe_rows.clear()
	for text: String in ["Produzione / resa", "Lotti", "Tempo", "Ingredienti disponibili / costo", "Energia", ""]:
		recipe_grid.add_child(UI.label(text, 13, Color("b4c5c6")))
	for id: String in visible_recipes:
		var definition := Catalog.recipe(id)
		var name_row := HBoxContainer.new()
		name_row.custom_minimum_size.x = 205
		recipe_grid.add_child(name_row)
		name_row.add_child(ItemIcons.view(definition.output, 26))
		var title := UI.label(definition.name_it, 15, Cargo.COLORS.get(definition.output, Color("ef816c")))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 168
		name_row.add_child(title)
		var quantity := SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = 4 if id == "bomb" else 20
		quantity.step = 1
		quantity.custom_minimum_size.x = 68
		quantity.value_changed.connect(func(_value): refresh())
		recipe_grid.add_child(quantity)
		var time := UI.label("", 14)
		recipe_grid.add_child(time)
		var ingredients := VBoxContainer.new()
		ingredients.custom_minimum_size.x = 220
		recipe_grid.add_child(ingredients)
		var labels := {}
		for resource: String in definition.cost:
			var ingredient_row := HBoxContainer.new()
			ingredients.add_child(ingredient_row)
			ingredient_row.add_child(ItemIcons.view(resource, 22))
			labels[resource] = UI.label("", 14)
			ingredient_row.add_child(labels[resource])
		var energy := UI.label("", 13)
		recipe_grid.add_child(energy)
		var button := UI.button(recipe_grid, "Crea", _start_craft.bind(id))
		button.custom_minimum_size.x = 72
		recipe_rows[id] = {"button": button, "quantity": quantity, "duration": time, "resources": labels, "energy": energy, "title": title}
		if id == "structural_component":
			craft_button = button
			duration = time
			resource_labels = labels

func is_open() -> bool:
	return picker.visible or activation_popup.visible

func open_picker(cell: Vector2i, point: Vector2, at_station: bool = false) -> void:
	if not at_station or outpost.nearby_station().is_empty():
		outpost.assembly.open_picker(cell, point)
		return
	outpost.build_mode = false
	outpost.world.mouse_mining = false
	refresh()
	picker.popup_centered(Vector2i(1020, 560))

func open_site(building: Dictionary) -> void:
	outpost.assembly.open_site(building)

func open_cube(_cube: Dictionary, _point: Vector2) -> void:
	outpost.world._note("Usa i componenti e scegli un progetto di montaggio")

func open_device(building: Dictionary, point: Vector2) -> void:
	site = building
	activation_popup.clear()
	activation_popup.add_separator(outpost.Buildings.NAMES[building.id])
	activation_popup.add_item("Spegni" if building.get("enabled", true) else "Accendi", 2)
	activation_popup.popup(Rect2i(Vector2i(outpost.get_viewport().get_screen_transform() * point), Vector2i(260, 92)))

func _start_craft(id: String) -> void:
	outpost.fabricate_components(id, int(recipe_rows[id].quantity.value))
	refresh()

func _cancel_picker() -> void:
	picker.hide()

func refresh() -> void:
	if outpost.nearby_station().is_empty():
		picker.hide()
		return
	_sync_recipes()
	heading.text = "%s / LIVELLO %d" % [outpost.station_name().to_upper(), outpost.station_level()]
	for id: String in recipe_rows:
		var row: Dictionary = recipe_rows[id]
		var count := int(row.quantity.value)
		var definition := Catalog.recipe(id)
		row.duration.text = "%.1f s" % (float(definition.seconds) * count / (1.0 + 0.5 * (outpost.station_level() - 1)))
		row.title.text = "%s\n%d pezzi" % [definition.name_it, int(definition.amount) * count]
		row.energy.text = "%.2f kWh" % (float(definition.energy) * count)
		for resource: String in row.resources:
			var available: int = outpost.world.field_cargo.available(resource, outpost.world.drone_help_available(), outpost.fabrication_stock())
			var required: int = definition.cost[resource] * count
			row.resources[resource].text = "%s  %d / %d" % [Cargo.NAMES[resource], available, required]
			row.resources[resource].modulate = Color("a7e5b4") if available >= required else Color("ff7e85")
		var reason: String = outpost.component_blocker(id, count)
		row.button.disabled = not reason.is_empty()
		row.button.tooltip_text = reason
	var job: Dictionary = outpost.fabrication.job_at(outpost.station_identity(outpost.nearby_station()))
	craft_bar.visible = not job.is_empty()
	if not job.is_empty():
		craft_bar.value = float(job.elapsed) / float(job.seconds) * 100
		var reason: String = outpost.fabrication_pause_reason(job)
		choice_status.text = reason if not reason.is_empty() else "Produzione in corso / %.1f s" % (float(job.seconds) - float(job.elapsed))
	else:
		choice_status.text = "Banco disponibile"
	var ready := 0
	for resource: String in Catalog.COMPONENT_IDS:
		ready += int(outpost.fabrication_stock().get(resource, 0)) + int(outpost.fabrication.buffer_at(outpost.station_identity(outpost.nearby_station())).get(resource, 0))
	collect_button.text = "Ritira componenti (%d)" % ready
	collect_button.disabled = ready == 0 or not outpost.world.drone_help_available()

func _process(_delta: float) -> void:
	if picker.visible:
		refresh()
