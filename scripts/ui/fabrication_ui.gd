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
var maintenance_button: Button
var robot_status: Label
var stock_labels: Dictionary = {}
var queue_scroll: ScrollContainer
var queue_column: VBoxContainer
var queue_heading: Label
var queue_rows: Array = []
var queue_signature: Array = []
var current_station: Dictionary = {}
var feedback: Label
var site: Dictionary = {}

func _ready() -> void:
	picker = Window.new()
	picker.title = "Computer del laboratorio"
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
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	heading = UI.label("PRODUZIONE", 20)
	column.add_child(heading)
	column.add_child(UI.label("SEMILAVORATI / ORDINI DI PRODUZIONE", 14, Color("b4c5c6")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	recipe_grid = GridContainer.new()
	recipe_grid.columns = 6
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation", 10)
	recipe_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(recipe_grid)
	column.add_child(HSeparator.new())
	var overview := HBoxContainer.new()
	overview.custom_minimum_size.y = 224
	overview.add_theme_constant_override("separation", 18)
	column.add_child(overview)
	var production := VBoxContainer.new()
	production.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	production.size_flags_stretch_ratio = 1.2
	production.add_theme_constant_override("separation", 6)
	overview.add_child(production)
	queue_heading = UI.label("ORDINI PAGATI", 14, Color("b4c5c6"))
	production.add_child(queue_heading)
	choice_status = UI.label("", 14)
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.custom_minimum_size.y = 36
	production.add_child(choice_status)
	craft_bar = ProgressBar.new()
	craft_bar.custom_minimum_size.y = 18
	production.add_child(craft_bar)
	queue_scroll = ScrollContainer.new()
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	production.add_child(queue_scroll)
	queue_column = VBoxContainer.new()
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_column.add_theme_constant_override("separation", 6)
	queue_scroll.add_child(queue_column)
	var inventory := VBoxContainer.new()
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory.add_theme_constant_override("separation", 8)
	overview.add_child(inventory)
	inventory.add_child(UI.label("SCORTE PRONTE", 14, Color("b4c5c6")))
	var stocks := GridContainer.new()
	stocks.columns = 5
	stocks.add_theme_constant_override("h_separation", 12)
	stocks.add_theme_constant_override("v_separation", 6)
	inventory.add_child(stocks)
	for title: String in ["Componenti", "Nave", "Locale", "Banco", "Robbie"]:
		stocks.add_child(UI.label(title, 13, Color("b4c5c6")))
	for id: String in Catalog.COMPONENT_IDS:
		var item := HBoxContainer.new()
		stocks.add_child(item)
		item.add_child(ItemIcons.view(id, 22))
		item.add_child(UI.label("Strutturali" if id == "structural_component" else "Elettronici", 14))
		var labels := {}
		for key: String in ["ship", "local", "buffer", "cargo"]:
			labels[key] = UI.label("0", 14)
			stocks.add_child(labels[key])
		stock_labels[id] = labels
	inventory.add_child(HSeparator.new())
	robot_status = UI.label("", 14)
	robot_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	robot_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory.add_child(robot_status)
	feedback = UI.label("", 14, Color("f0d281"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 20
	column.add_child(feedback)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	collect_button = UI.button(footer, "Ritira componenti", _collect_output)
	maintenance_button = UI.button(footer, "Gestione postazione", _open_actions)
	maintenance_button.custom_minimum_size.x = 220
	maintenance_button.icon = preload("res://assets/ui/storage.svg")
	maintenance_button.expand_icon = true
	maintenance_button.add_theme_constant_override("icon_max_width", 20)
	maintenance_button.tooltip_text = "Deposito, prelievo, riparazioni e potenziamenti"
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
	for text: String in ["Produzione / resa", "Lotti", "Tempo", "Ingredienti / Hai / Servono", "Energia", "Ordine"]:
		recipe_grid.add_child(UI.label(text, 13, Color("b4c5c6")))
	for id: String in visible_recipes:
		var definition := Catalog.recipe(id)
		var name_row := HBoxContainer.new()
		name_row.custom_minimum_size.x = 210
		recipe_grid.add_child(name_row)
		name_row.add_child(ItemIcons.view(definition.output, 26))
		var title := UI.label(definition.name_it, 15, Color.WHITE)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 168
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		ingredients.custom_minimum_size.x = 230
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
		var action := VBoxContainer.new()
		action.custom_minimum_size.x = 180
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_grid.add_child(action)
		var button := UI.button(action, "Ordina", _start_craft.bind(id))
		var reason := UI.label("", 12, Color("b4c5c6"))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.add_child(reason)
		recipe_rows[id] = {"button": button, "quantity": quantity, "duration": time, "resources": labels, "energy": energy, "title": title, "reason": reason}
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
	current_station = outpost.nearby_station()
	outpost.selected_station = current_station
	feedback.text = ""
	outpost.build_mode = false
	outpost.world.mouse_mining = false
	refresh()
	var viewport_size: Vector2i = outpost.get_viewport().get_visible_rect().size
	picker.popup_centered(Vector2i(mini(1140, viewport_size.x - 48), mini(720, viewport_size.y - 80)))
	craft_button.grab_focus()

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
	if not _station_accessible():
		picker.hide()
		return
	outpost.selected_station = current_station
	var count := int(recipe_rows[id].quantity.value)
	var reason := _order_blocker(id, count)
	if not reason.is_empty():
		feedback.text = reason
	elif outpost.fabricate_components(id, count):
		feedback.text = "Ordine pagato: %s / %d lotti" % [Catalog.recipe(id).name_it, count]
	else:
		feedback.text = outpost.component_blocker(id, count)
	refresh()

func _open_actions() -> void:
	if not _station_accessible():
		picker.hide()
		return
	outpost.selected_station = current_station
	picker.hide()
	outpost.station_menu.open_actions(outpost.get_viewport().get_visible_rect().get_center())

func _collect_output() -> void:
	if not _station_accessible():
		picker.hide()
		return
	outpost.selected_station = current_station
	var reason := _collection_blocker()
	if not reason.is_empty():
		feedback.text = reason
	else:
		feedback.text = "Componenti caricati: %d" % outpost.collect_fabrication_output()
	refresh()

func _collection_blocker() -> String:
	if current_station.kind == "ship" and outpost.world.gear.workshop_damaged():
		return "Ripara il laboratorio di bordo"
	if not outpost.world.drone_help_available():
		return "Robbie non accessibile"
	var ready := false
	var buffer: Dictionary = outpost.fabrication.buffer_at(outpost.station_identity(current_station))
	for id: String in Catalog.COMPONENT_IDS:
		if int(_local_stock().get(id, 0)) + int(buffer.get(id, 0)) <= 0:
			continue
		ready = true
		if outpost.world.field_cargo.collectible(id, true) > 0:
			return ""
	return "Carico di Robbie pieno" if ready else "Nessun componente pronto"

func _station_accessible() -> bool:
	if current_station.get("kind") == "ship":
		return outpost.world.aboard_workshop()
	return outpost.station_available(current_station)

func _order_blocker(id: String, count: int) -> String:
	if current_station.get("kind") == "ship" and outpost.world.gear.workshop_damaged():
		return "Ripara il laboratorio di bordo"
	return outpost.component_blocker(id, count)

func _cancel_picker() -> void:
	picker.hide()

func refresh() -> void:
	if not _station_accessible():
		picker.hide()
		return
	outpost.selected_station = current_station
	_sync_recipes()
	heading.text = "%s / LIVELLO %d" % ["LABORATORIO DI BORDO" if current_station.kind == "ship" else "LABORATORIO SOTTERRANEO", outpost.station_level(current_station)]
	for id: String in recipe_rows:
		var row: Dictionary = recipe_rows[id]
		var count := int(row.quantity.value)
		var definition := Catalog.recipe(id)
		row.duration.text = "%.1f s" % (float(definition.seconds) * count / (1.0 + 0.5 * (outpost.station_level(current_station) - 1)))
		row.title.text = "%s\n%d pezzi" % [definition.name_it, int(definition.amount) * count]
		row.energy.text = "%.2f kWh" % (float(definition.energy) * count)
		for resource: String in row.resources:
			var available: int = outpost.world.field_cargo.available(resource, outpost.world.drone_help_available(), _local_stock())
			var required: int = definition.cost[resource] * count
			row.resources[resource].text = "%s  %d / %d" % [Cargo.NAMES[resource], available, required]
			row.resources[resource].modulate = Color("a7e5b4") if available >= required else Color("829396")
		var reason: String = _order_blocker(id, count)
		row.button.disabled = not reason.is_empty()
		row.button.tooltip_text = reason if not reason.is_empty() else "Prenota ingredienti ed energia / aggiungi alla coda"
		row.reason.text = reason
		row.title.modulate = Color("a7e5b4") if reason.is_empty() else Color("829396")
		row.button.modulate = Color("a7e5b4") if reason.is_empty() else Color("829396")
	_refresh_queue()
	_refresh_stock()

func _local_stock() -> Dictionary:
	return outpost.logistics.stock() if current_station.kind == "ship" else current_station.building.stock

func _refresh_queue() -> void:
	var identity: Array = outpost.station_identity(current_station)
	var orders: Array = []
	var signature: Array = []
	for job: Dictionary in outpost.fabrication.jobs:
		if job.station == identity:
			orders.append(job)
			signature.append([job.id, job.get("batches", 1), job.seconds])
	if signature != queue_signature:
		queue_signature = signature
		for child in queue_column.get_children():
			queue_column.remove_child(child)
			child.queue_free()
		queue_rows.clear()
		for index in range(orders.size()):
			var job: Dictionary = orders[index]
			var definition := Catalog.recipe(job.id)
			var line := HBoxContainer.new()
			queue_column.add_child(line)
			line.add_child(ItemIcons.view(definition.get("output", job.id), 22))
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(details)
			var title := UI.label("%d. %s / %d lotti" % [index + 1, definition.get("name_it", job.id), job.get("batches", 1)], 13)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(title)
			var status := UI.label("", 12, Color("b4c5c6"))
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			details.add_child(status)
			var bar := ProgressBar.new()
			bar.custom_minimum_size.y = 6
			bar.show_percentage = false
			details.add_child(bar)
			queue_rows.append({"title": title, "status": status, "bar": bar})
	queue_heading.text = "ORDINI PAGATI / %d" % orders.size()
	for index in range(orders.size()):
		var job: Dictionary = orders[index]
		var row: Dictionary = queue_rows[index]
		row.bar.value = float(job.elapsed) / float(job.seconds) * 100 if index == 0 else 0
		var reason: String = outpost.fabrication_pause_reason(job) if index == 0 else ""
		row.status.text = ("In corso / %.1f s rimanenti" % (float(job.seconds) - float(job.elapsed)) if reason.is_empty() else reason) if index == 0 else "In coda / %.1f s" % job.seconds
		row.status.modulate = Color("f0d281") if not reason.is_empty() else Color.WHITE
	var job: Dictionary = outpost.fabrication.job_at(identity)
	craft_bar.visible = not job.is_empty()
	if not job.is_empty():
		craft_bar.value = float(job.elapsed) / float(job.seconds) * 100
		var reason: String = outpost.fabrication_pause_reason(job)
		choice_status.text = "%s / %s" % [Catalog.recipe(job.id).get("name_it", job.id), reason if not reason.is_empty() else "In corso / %.1f s rimanenti" % (float(job.seconds) - float(job.elapsed))]
	else:
		choice_status.text = "Nessun ordine / Banco disponibile"

func _refresh_stock() -> void:
	var identity: Array = outpost.station_identity(current_station)
	var buffer: Dictionary = outpost.fabrication.buffer_at(identity)
	var ship: Dictionary = outpost.logistics.stock()
	var local: Dictionary = current_station.building.stock if current_station.kind == "laboratory" else {}
	var ready := 0
	for resource: String in Catalog.COMPONENT_IDS:
		var labels: Dictionary = stock_labels[resource]
		labels.ship.text = str(ship.get(resource, 0))
		labels.local.text = str(local.get(resource, 0)) if current_station.kind == "laboratory" else "-"
		labels.buffer.text = str(buffer.get(resource, 0))
		labels.cargo.text = str(outpost.world.field_cargo.drone.get(resource, 0))
		ready += int(_local_stock().get(resource, 0)) + int(buffer.get(resource, 0))
	collect_button.visible = outpost.world.is_robbie()
	collect_button.text = "Ritira componenti (%d)" % ready
	var collection_reason := _collection_blocker()
	collect_button.disabled = not collection_reason.is_empty()
	collect_button.tooltip_text = collection_reason if collect_button.disabled else "Carica i componenti pronti nel cargo di Robbie"
	robot_status.text = "ROBBIE / Controllo manuale" if outpost.world.is_robbie() else "ROBBIE / " + outpost.logistics.status
	if not outpost.world.is_robbie():
		var target: Dictionary = outpost.logistics.target
		if target.is_empty():
			for building: Dictionary in outpost.buildings.structures:
				if building.get("state") in ["planned", "building"]:
					target = building
					break
		if not target.is_empty():
			var status: String = outpost.logistics.project_status(target)
			if status != outpost.logistics.status:
				robot_status.text += "\n" + status

func _process(_delta: float) -> void:
	if picker.visible:
		refresh()
