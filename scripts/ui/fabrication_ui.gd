extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const ICONS := {"laboratory": preload("res://assets/design/icons/mod_lab.svg"), "lamp": preload("res://assets/design/icons/mod_light.svg"), "pump": preload("res://assets/design/icons/mod_pump.svg"), "fan": preload("res://assets/design/icons/mod_gas_filter.svg"), "furnace": preload("res://assets/design/icons/mod_heater.svg"), "gas_converter": preload("res://assets/design/icons/mod_fuel_plant.svg"), "greenhouse": preload("res://assets/design/icons/mod_greenhouse.svg")}
var outpost: Node2D
var picker: Window
var activation_popup: PopupMenu
var heading: Label
var choice_status: Label
var craft_button: Button
var craft_bar: ProgressBar
var duration: Label
var resource_labels: Dictionary = {}
var site: Dictionary = {}
var fabrication_mode := true
var recipe_grid: GridContainer
var recipe_rows: Dictionary = {}
var visible_recipes: Array[String] = []

func _ready() -> void:
	picker = Window.new()
	picker.title = "Laboratorio / fabbricazione"
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
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	heading = UI.label("", 20)
	column.add_child(heading)
	column.add_child(UI.label("Materiali comuni: zaino + Robbie + deposito di questo laboratorio", 14, Color("b4c5c6")))
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	recipe_grid = GridContainer.new()
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.columns = 5
	recipe_grid.add_theme_constant_override("h_separation", 20)
	recipe_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(recipe_grid)
	column.add_child(HSeparator.new())
	craft_bar = ProgressBar.new()
	craft_bar.custom_minimum_size.y = 22
	craft_bar.show_percentage = true
	column.add_child(craft_bar)
	choice_status = UI.label("", 16)
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.custom_minimum_size.y = 44
	column.add_child(choice_status)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UI.button(footer, "Chiudi", picker.hide)
	activation_popup = PopupMenu.new()
	activation_popup.prefer_native_menu = false
	activation_popup.add_theme_font_size_override("font_size", 16)
	activation_popup.add_theme_constant_override("v_separation", 14)
	activation_popup.add_theme_stylebox_override("panel", UI.panel_style())
	activation_popup.id_pressed.connect(func(id: int):
		activation_popup.hide()
		if id == 0:
			outpost.activate_cube(site)
		elif id == 2 and outpost.buildings.structures.has(site) and site.get("id") in Buildings.DEVICE_IDS and Buildings.is_active(site) and outpost.site_reachable(site):
			site.enabled = not site.get("enabled", true)
			outpost.world._note(Buildings.NAMES[site.id] + (" acceso" if site.enabled else " spento")))
	add_child(activation_popup)
	_sync_recipes()

func _sync_recipes() -> void:
	var next: Array[String] = []
	for id: String in Buildings.CUBE_IDS:
		if outpost.recipe_visible(id) and not outpost.recipe_definition(id).is_empty():
			next.append(id)
	if next == visible_recipes:
		return
	visible_recipes = next
	for child in recipe_grid.get_children():
		recipe_grid.remove_child(child)
		child.queue_free()
	recipe_rows.clear()
	for text: String in ["Oggetto", "Livello", "Tempo", "Risorse disponibili / costo", ""]:
		recipe_grid.add_child(UI.label(text, 14, Color("b4c5c6")))
	for id: String in visible_recipes:
		var definition: Dictionary = outpost.recipe_definition(id)
		var name_row := HBoxContainer.new()
		name_row.custom_minimum_size.x = 195
		name_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_theme_constant_override("separation", 8)
		recipe_grid.add_child(name_row)
		var icon := TextureRect.new()
		icon.texture = ICONS[id]
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		name_row.add_child(icon)
		name_row.add_child(UI.label(definition.name_it, 17, Buildings.CUBE_COLORS[id]))
		recipe_grid.add_child(UI.label("1", 17))
		var time := UI.label("", 16)
		time.custom_minimum_size.x = 68
		recipe_grid.add_child(time)
		var ingredients := VBoxContainer.new()
		ingredients.custom_minimum_size.x = 214
		ingredients.add_theme_constant_override("separation", 2)
		recipe_grid.add_child(ingredients)
		var labels := {}
		for resource: String in definition.cost:
			var label := UI.label("", 15)
			ingredients.add_child(label)
			labels[resource] = label
		var button := UI.button(recipe_grid, "Crea", _start_craft.bind(id))
		button.custom_minimum_size.x = 92
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		recipe_rows[id] = {"button": button, "duration": time, "resources": labels}
		if id == "laboratory":
			craft_button = button
			duration = time
			resource_labels = labels

func is_open() -> bool:
	return picker.visible or activation_popup.visible

func open_picker(_cell: Vector2i, _viewport_point: Vector2, at_station: bool = false) -> void:
	if not at_station or outpost.nearby_station().is_empty():
		outpost.world._note("Fabbrica il cubo al laboratorio, poi prendilo e posalo con Spazio")
		return
	outpost.build_mode = false
	outpost.activation_cube_id = 0
	outpost.world.mouse_mining = false
	refresh()
	picker.popup_centered(Vector2i(940, 600))

func open_cube(cube: Dictionary, viewport_point: Vector2) -> void:
	site = cube
	activation_popup.clear()
	var size: Vector2i = outpost.buildings.size_for(cube.id)
	activation_popup.add_separator("Cubo %s / livello %d" % [Buildings.NAMES[cube.id].to_lower(), cube.level])
	activation_popup.add_item("Attiva %s / %d x %d m" % [Buildings.NAMES[cube.id].to_lower(), size.x, size.y], 0)
	var point: Vector2 = outpost.get_viewport().get_screen_transform() * viewport_point
	activation_popup.popup(Rect2i(Vector2i(point), Vector2i(330, 92)))

func open_site(building: Dictionary) -> void:
	# Compatibility for unfunded cubes in earlier saves; never creates new plans.
	if building.get("state") == "planned" and outpost.site_reachable(building):
		site = building
		activation_popup.clear()
		activation_popup.add_separator("Cantiere precedente")
		activation_popup.add_item("Completa con i materiali comuni", 1)
		if not activation_popup.id_pressed.is_connected(_legacy_fund):
			activation_popup.id_pressed.connect(_legacy_fund)
		activation_popup.popup_centered(Vector2i(350, 92))

func open_device(building: Dictionary, viewport_point: Vector2) -> void:
	site = building
	activation_popup.clear()
	activation_popup.add_separator(Buildings.NAMES[building.id])
	activation_popup.add_item("Spegni" if building.get("enabled", true) else "Accendi", 2)
	var point: Vector2 = outpost.get_viewport().get_screen_transform() * viewport_point
	activation_popup.popup(Rect2i(Vector2i(point), Vector2i(260, 92)))

func _legacy_fund(id: int) -> void:
	if id == 1:
		if not outpost.fund_site(site):
			outpost.world._note(outpost.funding_blocker(site))
		activation_popup.hide()

func _start_craft(id: String = "laboratory") -> void:
	outpost.fabricate_cube(id)
	refresh()

func _cancel_picker() -> void:
	picker.hide()

func refresh() -> void:
	var station: Dictionary = outpost.nearby_station()
	if station.is_empty():
		picker.hide()
		return
	_sync_recipes()
	heading.text = "%s / LIVELLO %d" % [outpost.station_name().to_upper(), outpost.station_level(station)]
	var any_ready := false
	var bench_blocker := ""
	for id: String in recipe_rows:
		var row: Dictionary = recipe_rows[id]
		var definition: Dictionary = outpost.recipe_definition(id)
		row.duration.text = "%.1f s" % outpost.fabrication_seconds(station, id)
		for resource: String in row.resources:
			var available: int = outpost.fabrication_amount(resource)
			var required: int = definition.cost[resource]
			row.resources[resource].text = "%s  %d / %d" % [UI.NAMES[resource], available, required]
			row.resources[resource].modulate = Color("a7e5b4") if available >= required else Color("ff7e85")
		var reason: String = outpost.fabrication_blocker(id)
		row.button.disabled = not reason.is_empty()
		row.button.tooltip_text = reason
		any_ready = any_ready or reason.is_empty()
		if not reason.is_empty() and not reason.begins_with("Mancano:"):
			bench_blocker = reason
	var job: Dictionary = outpost.fabrication.job_at(outpost.station_identity(station))
	var output: Dictionary = outpost.fabrication.output_at(outpost.station_identity(station))
	craft_bar.visible = not job.is_empty()
	if not job.is_empty():
		craft_bar.value = float(job.elapsed) / float(job.seconds) * 100
		var pause_reason: String = outpost.fabrication_pause_reason(job)
		choice_status.text = pause_reason if not pause_reason.is_empty() else "%s sul banco / %.1f s rimanenti" % [Buildings.NAMES[job.id], float(job.seconds) - float(job.elapsed)]
	elif not output.is_empty():
		choice_status.text = "%s pronto / avvicinati al cubo e premi Spazio" % Buildings.NAMES[output.id]
	elif not bench_blocker.is_empty():
		choice_status.text = bench_blocker
	else:
		choice_status.text = "Banco pronto" if any_ready else "Risorse insufficienti: controlla i requisiti di ogni ricetta"
	choice_status.modulate = Color("a7e5b4") if any_ready or not output.is_empty() else Color("e5efeb")

func _process(_delta: float) -> void:
	if picker.visible:
		refresh()
