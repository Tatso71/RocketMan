extends Node2D

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Catalog = preload("res://scripts/data/industry_catalog.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const ItemIcons = preload("res://scripts/data/item_icon_catalog.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIRECTION_NAMES := ["Alto", "Destra", "Basso", "Sinistra"]
const BUILD_TOOLS := {12: "pump", 13: "greenhouse", 14: "water_tank"}

class PipeRenderer extends Node2D:
	var ui: Node2D
	func _draw() -> void:
		ui._draw_pipes(self)

var outpost: Node2D
var pipe_renderer: Node2D
var window: Window
var menu: PopupMenu
var context_menu: PopupMenu
var heading: Label
var status: Label
var reserves: Label
var progress: ProgressBar
var rows: VBoxContainer
var selected: Dictionary = {}
var mode := ""
var dragging := false
var stroke_started := false
var drag_remove := false
var last_cell := Vector2i(999, 999)
var action_cell := Vector2i.ZERO
var actions: Array = []
var pipe_button: Button
var feedback: Label
var refresh_timer := 0.0
var row_controls: Dictionary = {}
var enabled_toggle: CheckButton
var pump_directions: Array[Button] = []

func _ready() -> void:
	pipe_renderer = PipeRenderer.new()
	pipe_renderer.name = "BackgroundPipes"
	pipe_renderer.ui = self
	# World backgrounds are z0; the separate world ladder layer is z2.
	pipe_renderer.z_index = 1
	add_child(pipe_renderer)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	pipe_button = Button.new()
	pipe_button.icon = ItemIcons.texture("water_conduit")
	pipe_button.expand_icon = true
	pipe_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pipe_button.position = Vector2(18, -92)
	pipe_button.size = Vector2(42, 40)
	pipe_button.tooltip_text = "Impianti (T)\nP: tubo acqua / Maiusc+P: rimuovi"
	pipe_button.pressed.connect(open_tools)
	root.add_child(pipe_button)
	menu = PopupMenu.new()
	menu.prefer_native_menu = false
	for entry: Array in [[10, "valve", "Valvola blu"], [0, "water_conduit", "Tubo acqua (gratuito / P)"], [12, "pump", "Pompa"], [13, "greenhouse", "Serra"], [14, "water_tank", "Contenitore acqua"]]:
		menu.add_icon_item(ItemIcons.texture(entry[1]), entry[2], entry[0])
		menu.set_item_icon_max_width(menu.item_count - 1, 24)
	var utilities := PopupMenu.new()
	utilities.name = "Utilities"
	utilities.prefer_native_menu = false
	menu.add_child(utilities)
	for kind: String in ["gas", "energy"]:
		utilities.add_icon_item(ItemIcons.texture(kind + "_conduit"), Network.NAMES[kind] + (" / 1 strutturale/m" if kind == "gas" else " / 1 elettronico/m"), Network.KINDS.find(kind))
		utilities.set_item_icon_max_width(utilities.item_count - 1, 24)
	utilities.add_item("Smonta scale e condotti", 3)
	utilities.id_pressed.connect(_choose_tool)
	menu.add_separator()
	menu.add_submenu_item("Altri impianti", "Utilities")
	menu.add_item("Termina posa", 4)
	menu.id_pressed.connect(_choose_tool)
	add_child(menu)
	context_menu = PopupMenu.new()
	context_menu.prefer_native_menu = false
	context_menu.id_pressed.connect(_context_action)
	add_child(context_menu)
	window = Window.new()
	window.title = "Impianti"
	window.visible = false
	window.transient = true
	window.exclusive = true
	window.unresizable = true
	window.close_requested.connect(window.hide)
	window.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("pause"):
			window.hide()
			window.set_input_as_handled())
	add_child(window)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	window.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = UI.label("", 22)
	column.add_child(heading)
	status = UI.label("", 17, Color("d4de9b"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	reserves = UI.label("", 15)
	reserves.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reserves)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	column.add_child(progress)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	feedback = UI.label("", 14, Color("efb780"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	enabled_toggle = CheckButton.new()
	enabled_toggle.text = "Alimentazione"
	enabled_toggle.toggled.connect(func(value: bool):
		if outpost.site_reachable(selected):
			selected.enabled = value
		refresh())
	buttons.add_child(enabled_toggle)
	UI.button(buttons, "Chiudi", window.hide)

func is_open() -> bool:
	return window.visible or menu.visible or context_menu.visible

func tool_active() -> bool:
	return not mode.is_empty()

func open_tools() -> void:
	menu.popup_centered(Vector2i(330, 270))

func _choose_tool(id: int) -> void:
	menu.hide()
	mode = ""
	_stop_drag()
	outpost.world.mouse_mining = false
	outpost.world.beam_time = 0.0
	outpost.world.beam_tool = null
	outpost.hydraulic_ui.reset()
	outpost.build_mode = false
	if id == 10:
		outpost.hydraulic_ui.begin("valve")
		return
	if BUILD_TOOLS.has(id):
		outpost.blueprint = BUILD_TOOLS[id]
		outpost.origin = outpost.placement_origin(outpost.blueprint, Grid.to_cell(outpost.world.get_global_mouse_position()))
		outpost.preview_fixed = false
		outpost.activation_cube_id = 0
		outpost.build_mode = true
		outpost.world._note(outpost.Buildings.NAMES[outpost.blueprint])
		return
	mode = Network.KINDS[id] if id >= 0 and id < 3 else ("remove" if id == 3 else "")
	outpost.world._note(Network.NAMES.get(mode, "Smontaggio" if mode == "remove" else "Posa terminata"))

func open_machine(building: Dictionary) -> void:
	selected = building
	mode = ""
	dragging = false
	outpost.hydraulic_ui.reset()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	row_controls.clear()
	pump_directions.clear()
	var data := Catalog.load_data()
	if building.id in ["furnace", "greenhouse"]:
		var definitions: Dictionary = data.smelting if building.id == "furnace" else data.crops
		for id: String in definitions:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			rows.add_child(row)
			row.add_child(ItemIcons.view(id, 30))
			if building.id == "greenhouse":
				row.add_child(ItemIcons.view("seed_" + id, 24))
			var label := UI.label("", 15)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(label)
			var button := UI.button(row, "Avvia" if building.id == "furnace" else "Pianta", _order.bind(id))
			button.custom_minimum_size.x = 92
			row_controls[id] = {"label": label, "button": button}
		var collect := UI.button(rows, "Ritira prodotto" if building.id == "furnace" else "Raccogli", func():
			feedback.text = "Prodotto ritirato" if outpost.industry.collect(selected, outpost) else "Prodotto non pronto o carico pieno"
			refresh())
		row_controls["collect"] = collect
	if building.id == "pump":
		var directions := HBoxContainer.new()
		rows.add_child(directions)
		var group := ButtonGroup.new()
		for index in range(DIRECTIONS.size()):
			var button := UI.button(directions, "", _set_pump_direction.bind(DIRECTIONS[index]))
			button.custom_minimum_size = Vector2(52, 42)
			button.icon = _direction_icon(DIRECTIONS[index])
			button.tooltip_text = "Mandata: " + DIRECTION_NAMES[index]
			button.toggle_mode = true
			button.button_group = group
			pump_directions.append(button)
	feedback.text = ""
	refresh()
	window.popup_centered(Vector2i(800, 530))

func _direction_icon(direction: Vector2i) -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var axis := Vector2(direction)
	for y in range(24):
		for x in range(24):
			var point := Vector2(x, y) - Vector2(11.5, 11.5)
			var along := point.dot(axis)
			var across := absf(point.dot(axis.orthogonal()))
			if (along >= -8 and along <= 6 and across <= 1.5) or (along >= 1 and along <= 8 and absf(across - (8 - along)) <= 1.5):
				image.set_pixel(x, y, Color("ccecf7"))
	return ImageTexture.create_from_image(image)

func _set_pump_direction(direction: Vector2i) -> void:
	feedback.text = "" if outpost.hydraulics.set_pump_direction(selected, direction, outpost) else "Direzione non disponibile"
	refresh()

func _order(id: String) -> void:
	var ok: bool = outpost.industry.start_smelting(selected, id, outpost) if selected.id == "furnace" else outpost.industry.plant(selected, id, outpost)
	feedback.text = "Ordine avviato" if ok else "Ordine non disponibile: controlla materie, semi e stato della macchina"
	refresh()

func refresh() -> void:
	if selected.is_empty() or not outpost.buildings.structures.has(selected) or not outpost.site_reachable(selected):
		window.hide()
		return
	var data := Catalog.load_data()
	var storage: Dictionary = outpost.industry.state(selected)
	enabled_toggle.set_pressed_no_signal(selected.get("enabled", true))
	enabled_toggle.visible = selected.id != "water_tank"
	heading.text = outpost.Buildings.NAMES[selected.id].to_upper() + " / L1"
	status.text = outpost.industry.status(selected, outpost)
	progress.visible = false
	if selected.id == "gas_converter":
		reserves.text = "Energia %.2f / %.0f kWh  |  Prodotta %.2f kWh\nIngresso gas [%d, %d]  /  Uscita energia [%d, %d]" % [storage.energy, data.converter.capacity, storage.produced, Network.port(selected, "gas").x, Network.port(selected, "gas").y, Network.port(selected, "energy").x, Network.port(selected, "energy").y]
		progress.visible = true
		progress.value = float(storage.energy) / float(data.converter.capacity) * 100
	elif selected.id == "pump":
		var direction: Vector2i = outpost.hydraulics.pump_direction(selected)
		for index in range(pump_directions.size()):
			pump_directions[index].set_pressed_no_signal(DIRECTIONS[index] == direction)
		var ports: Dictionary = outpost.hydraulics.pump_ports(selected)
		var report: Dictionary = outpost.hydraulics.pump_report(selected, outpost)
		status.text = report.get("status", "")
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reserves.text = "Acqua conservata %.2f / %.0f u\nPortata effettiva %.2f u/s  |  Trasferiti %.2f u\nIngresso [%d, %d]  /  Uscita [%d, %d]\nAssorbimento nominale %.3f kWh/s" % [storage.water, data.pump_capacity, float(report.get("rate", 0)), float(report.get("total", 0)), ports.input.x, ports.input.y, ports.output.x, ports.output.y, outpost.Buildings.power_draw(selected)]
		progress.visible = true
		progress.value = float(storage.water) / float(data.pump_capacity) * 100
	elif selected.id == "water_tank":
		var port := Network.port(selected, "water")
		reserves.text = "Acqua %.2f / %.0f u\nPorta acqua [%d, %d]" % [float(storage.water), float(data.water_tank_capacity), port.x, port.y]
		progress.visible = true
		progress.value = float(storage.water) / float(data.water_tank_capacity) * 100
	else:
		reserves.text = "Energia collegata %.2f kWh" % outpost.industry.energy_available(selected, outpost)
		if selected.id == "greenhouse":
			var port := Network.port(selected, "water")
			reserves.text += "  |  Acqua %.2f / %.0f u\nPorta acqua [%d, %d]" % [float(storage.water), float(data.greenhouse_capacity), port.x, port.y]
		var current: String = storage.recipe if selected.id == "furnace" else storage.crop
		var definitions: Dictionary = data.smelting if selected.id == "furnace" else data.crops
		if not current.is_empty():
			progress.visible = true
			progress.value = float(storage.elapsed) / float(definitions[current].seconds) * 100
		var ready: bool = not storage.output.is_empty() if selected.id == "furnace" else (not current.is_empty() and float(storage.elapsed) >= float(definitions[current].seconds))
		row_controls.collect.disabled = not ready
		if selected.id == "furnace":
			row_controls.collect.text = "Ritira: " + UI.NAMES[storage.output] if ready else "Ritira prodotto"
		elif not current.is_empty():
			row_controls.collect.text = "Raccogli %d x %s + %d semi" % [definitions[current]["yield"], definitions[current].name_it, definitions[current].seeds]
		else:
			row_controls.collect.text = "Raccogli"
		for id: String in definitions:
			var entry: Dictionary = definitions[id]
			var row: Dictionary = row_controls[id]
			var available := false
			if selected.id == "furnace":
				var costs: Array[String] = []
				for item: String in entry.cost:
					costs.append("%s %d / %d" % [UI.NAMES[item], outpost.world.field_cargo.available(item, true, outpost.payment_cache()), entry.cost[item]])
				row.label.text = "%s / %.0f s / %s" % [entry.name_it, entry.seconds, ", ".join(costs)]
				available = outpost.world.field_cargo.can_pay(entry.cost, true, outpost.payment_cache())
			else:
				var seeds: int = outpost.world.seeds().get(id, 0)
				row.label.text = "%s / Semi %d / %.0f s / %.1f acqua" % [entry.name_it, seeds, entry.seconds, entry.water]
				available = seeds > 0
			row.label.modulate = Color("b5e7ad") if available else Color("f18b87")
			row.button.disabled = not available or not current.is_empty() or ready or not outpost.industry.healthy(selected, outpost)

func _remove_menu(cell: Vector2i, viewport_point: Vector2) -> bool:
	actions.clear()
	context_menu.clear()
	if outpost.world.ladders.has(cell):
		actions.append("ladder")
		context_menu.add_item("Smonta scala", actions.size() - 1)
	for kind: String in Network.KINDS:
		if outpost.network.cells[kind].has(cell):
			actions.append(kind)
			context_menu.add_item("Rimuovi " + Network.NAMES[kind].to_lower(), actions.size() - 1)
	if actions.is_empty():
		return false
	action_cell = cell
	context_menu.popup(Rect2i(Vector2i(outpost.get_viewport().get_screen_transform() * viewport_point), Vector2i(270, 90)))
	return true

func _context_action(index: int) -> void:
	context_menu.hide()
	if index < 0 or index >= actions.size():
		return
	var ok: bool = outpost.world.remove_ladder_at(action_cell) if actions[index] == "ladder" else outpost.remove_conduit(actions[index], action_cell)
	if not ok:
		outpost.world._note("Elemento protetto o fuori portata")

func _stop_drag() -> void:
	dragging = false
	stroke_started = false
	drag_remove = false

static func stroke_cells(first: Vector2i, last: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [first]
	var delta := last - first
	var width := absi(delta.x)
	var height := absi(delta.y)
	# The finite world's longest valid stroke is under 128 cardinal steps.
	if width + height > 128: return []
	var x := 0
	var y := 0
	var cell := first
	while x < width or y < height:
		if x < width and (y == height or (1 + 2 * x) * height <= (1 + 2 * y) * width):
			cell.x += signi(delta.x)
			x += 1
		else:
			cell.y += signi(delta.y)
			y += 1
		cells.append(cell)
	return cells

func _paint_water_to(cell: Vector2i, removing: bool) -> void:
	drag_remove = removing
	var cells: Array[Vector2i] = [cell]
	if stroke_started: cells = stroke_cells(last_cell, cell)
	if cells.is_empty():
		outpost.world._note("Tubo fuori portata")
		return
	for index in range(1 if stroke_started else 0, cells.size()):
		var current: Vector2i = cells[index]
		if removing:
			if not outpost.reachable_cell(current):
				outpost.world._note("Tubo fuori portata o dietro una parete")
				if not stroke_started: dragging = false
				break
			if outpost.network.cells.water.has(current): outpost.remove_conduit("water", current)
		elif not outpost.network.cells.water.has(current):
			var reason: String = outpost.conduit_blocker("water", current)
			if not reason.is_empty():
				outpost.world._note(reason)
				if not stroke_started: dragging = false
				break
			outpost.place_conduit("water", current)
		last_cell = current
		stroke_started = true
	pipe_renderer.queue_redraw()
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if outpost.world.controls_blocked():
		_stop_drag()
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		_choose_tool(0)
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		open_tools()
		return true
	if tool_active() and event.is_action_pressed("pause"):
		mode = ""
		_stop_drag()
		return true
	if mode == "water" and event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var point: Vector2 = outpost.world.get_global_transform_with_canvas().affine_inverse() * event.position
			_paint_water_to(Grid.to_cell(point), event.shift_pressed)
		else:
			_stop_drag()
		return true
	if mode == "water" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			var point: Vector2 = outpost.world.get_global_transform_with_canvas().affine_inverse() * event.position
			_paint_water_to(Grid.to_cell(point), drag_remove)
		_stop_drag()
		return true
	if not event is InputEventMouseButton or not event.pressed:
		return false
	var point: Vector2 = outpost.world.get_global_transform_with_canvas().affine_inverse() * event.position
	var cell := Grid.to_cell(point)
	if tool_active():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mode = ""
			_stop_drag()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "water":
				_stop_drag()
				dragging = true
				_paint_water_to(cell, event.shift_pressed)
			elif mode == "remove":
				_remove_menu(cell, event.position)
			else:
				outpost.place_conduit(mode, cell)
				dragging = true
				last_cell = cell
			return true
	if event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	for building: Dictionary in outpost.buildings.structures:
		if building.id in ["furnace", "gas_converter", "greenhouse", "pump", "water_tank"] and outpost.Buildings.is_active(building) and outpost.buildings.world_rect(building).has_point(point) and outpost.site_reachable(building):
			open_machine(building)
			return true
	for pod: Dictionary in Catalog.seed_sites(outpost.world.site.terrain_seed):
		if pod.cell == cell and pod.id not in outpost.industry.collected_pods and outpost.world.site.material(cell).is_empty():
			outpost.world._note("Semi raccolti: " + Catalog.load_data().crops[pod.crop].name_it if outpost.industry.collect_seed(pod, outpost) else "Semi fuori portata")
			return true
	if not outpost.cube_at(point).is_empty() or not outpost.station_at(point).is_empty():
		return false
	if outpost.buildings.structures.any(func(item: Dictionary): return item.id in ["lamp", "fan"] and outpost.buildings.world_rect(item).has_point(point)):
		return false
	return _remove_menu(cell, event.position) if outpost.reachable_cell(cell) else false

func _process(delta: float) -> void:
	if outpost.world.controls_blocked() or not get_window().has_focus() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_drag()
	var cell := Grid.to_cell(outpost.world.get_global_mouse_position())
	if dragging and mode in Network.KINDS and not outpost.world.controls_blocked() and cell != last_cell:
		if mode == "water":
			_paint_water_to(cell, Input.is_key_pressed(KEY_SHIFT))
		else:
			outpost.place_conduit(mode, cell)
			last_cell = cell
	refresh_timer -= delta
	if window.visible and refresh_timer <= 0:
		refresh_timer = 0.1
		refresh()
	pipe_button.modulate = Network.COLORS.get(mode, Color("f1b298") if mode == "remove" else Color.WHITE)
	pipe_button.tooltip_text = "Tubi acqua (P) / Clic e trascina / Maiusc: rimuovi / Destro: esci" if mode == "water" else "Impianti (T)"
	if not outpost.world.guide_state.facts.get("seed_pod_seen", false):
		for pod: Dictionary in Catalog.seed_sites(outpost.world.site.terrain_seed):
			if pod.id not in outpost.industry.collected_pods and outpost.world.site.material(pod.cell).is_empty() and outpost.reachable_cell(pod.cell):
				outpost.world.guide_event("seed_pod_seen")
				break
	queue_redraw()
	pipe_renderer.queue_redraw()

func _irrigating(building: Dictionary) -> bool:
	return outpost.industry.healthy(building, outpost) and outpost.industry.is_irrigating(building)

func pipe_connections(cell: Vector2i, kind: String) -> Array[Vector2i]:
	var connections: Array[Vector2i] = []
	for offset: Vector2i in Network.OFFSETS:
		if outpost.network.cells[kind].has(cell + offset) or (kind == "water" and not outpost.hydraulics.at(cell + offset).is_empty()):
			connections.append(offset)
	return connections

func _draw_pipes(renderer: Node2D) -> void:
	for kind: String in Network.KINDS:
		var shift := Vector2(0, 6 if kind == "energy" else 0)
		for cell: Vector2i in outpost.network.cells[kind]:
			var point := Grid.center(cell)
			var light: float = outpost.world._illumination(point)
			if tool_active():
				light = maxf(light, 0.35)
			if light < 0.08:
				continue
			var ink := Color("131b20").lerp(Network.COLORS[kind], light)
			var connections := pipe_connections(cell, kind)
			if kind == "water" and connections.is_empty():
				var axis := Vector2.RIGHT if int(outpost.network.water_axes.get(cell, 0)) == 0 else Vector2.DOWN
				renderer.draw_line(point - axis * 14, point + axis * 14, ink, 4)
			for offset: Vector2i in connections:
				renderer.draw_line(point + shift, point + Vector2(offset) * Grid.CELL_SIZE * 0.5 + shift, ink, 4 if kind != "energy" else 2)
			renderer.draw_circle(point + shift, 4, ink)

func _draw() -> void:
	for building: Dictionary in outpost.buildings.structures:
		if (building.id not in Catalog.MACHINE_IDS and building.id != "water_tank") or building.get("state") == "planned":
			continue
		var rect: Rect2 = outpost.buildings.world_rect(building)
		var unfolding: bool = building.get("state") == "building"
		if unfolding and sin(outpost.world.ambient_time * 15) < -0.3:
			continue
		if unfolding:
			var scale_factor := lerpf(0.15, 1, float(building.progress))
			var anchor := Vector2(rect.get_center().x, rect.end.y)
			draw_set_transform(anchor * (1 - scale_factor), 0, Vector2.ONE * scale_factor)
		_draw_machine(building, rect)
		draw_set_transform(Vector2.ZERO)
	for building: Dictionary in outpost.buildings.structures:
		if building.id == "pump" and building.get("state") != "planned":
			_draw_pump_ports(building)
		var kinds: Array = ["gas", "energy"] if building.id == "gas_converter" else (["water", "energy"] if building.id == "greenhouse" else (["energy"] if building.id == "furnace" else (["water"] if building.id == "water_tank" else [])))
		for kind: String in kinds:
			var point := Grid.center(Network.port(building, kind)) + Vector2(6 if kind == "energy" else 0, 0)
			if outpost.world._illumination(point) > 0.1:
				if kind == "water":
					for offset: Vector2i in Network.OFFSETS:
						draw_line(point + Vector2(offset) * 9, point + Vector2(offset) * 16, Network.COLORS.water, 2)
				draw_circle(point, 6, Color("162a30"))
				draw_arc(point, 5, 0, TAU, 16, Network.COLORS[kind], 2)
	for pod: Dictionary in Catalog.seed_sites(outpost.world.site.terrain_seed):
		if pod.id not in outpost.industry.collected_pods and outpost.world.site.material(pod.cell).is_empty():
			var point := Grid.center(pod.cell)
			if outpost.world._illumination(point) > 0.12:
				draw_line(point + Vector2(0, 12), point - Vector2(0, 10), Color("aad67e"), 3)
				draw_circle(point + Vector2(-7, -3), 6, Color("95c975"))
				draw_circle(point + Vector2(7, -7), 6, Color("edbf82"))
				draw_string(ThemeDB.fallback_font, point + Vector2(-26, -18), "Capsula semi", HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color("c7e7a4"))
	if tool_active():
		var cell := Grid.to_cell(outpost.world.get_global_mouse_position())
		var removing := mode == "water" and Input.is_key_pressed(KEY_SHIFT)
		var valid: bool
		if mode == "remove" or removing:
			valid = outpost.reachable_cell(cell)
		elif mode == "water" and outpost.network.cells.water.has(cell):
			valid = true
		else:
			valid = outpost.conduit_blocker(mode, cell).is_empty()
		var ink := (Color("eabf7e") if removing else Network.COLORS.water) if mode == "water" else Color("8fe3b6")
		if not valid: ink = Color("f37e80")
		draw_rect(Grid.rect(cell).grow(-2), Color(ink, 0.12))
		draw_rect(Grid.rect(cell).grow(-2), ink, false, 2)
		if removing:
			draw_line(Grid.center(cell) - Vector2(9, 9), Grid.center(cell) + Vector2(9, 9), ink, 2)
			draw_line(Grid.center(cell) - Vector2(9, -9), Grid.center(cell) + Vector2(9, -9), ink, 2)

func _draw_pump_ports(building: Dictionary) -> void:
	var ports: Dictionary = outpost.hydraulics.pump_ports(building)
	var report: Dictionary = outpost.hydraulics.pump_report(building, outpost)
	for role: String in ["input", "output"]:
		var point := Grid.center(ports[role])
		if outpost.world._illumination(point) <= 0.1:
			continue
		var ink := Color("8fd8f1") if role == "input" else Color("f2cd81")
		draw_circle(point, 8, Color("162a30"))
		draw_arc(point, 7, 0, TAU, 16, ink, 2)
		var direction := Vector2(outpost.hydraulics.pump_direction(building))
		var side := direction.orthogonal()
		var tip := point + direction * 4
		draw_line(point - direction * 5, tip, ink, 2)
		draw_line(tip, tip - direction * 4 + side * 3, ink, 2)
		draw_line(tip, tip - direction * 4 - side * 3, ink, 2)
		if float(report.get("rate", 0)) > 0:
			var phase := fposmod(outpost.world.ambient_time * 1.8, 1.0)
			draw_circle(point + direction * lerpf(-12, 12, phase), 2, Color("e0fbf6"))

func _draw_machine(building: Dictionary, rect: Rect2) -> void:
	var storage: Dictionary = outpost.industry.state(building)
	var active: bool = outpost.industry.healthy(building, outpost)
	var powered: bool = active and (float(storage.energy) > 0.000001 if building.id == "gas_converter" else (true if building.id == "water_tank" else outpost.industry.energy_available(building, outpost) > 0.000001))
	var ink: Color = outpost.Buildings.CUBE_COLORS[building.id]
	draw_rect(rect.grow(-3), Color("203136"))
	draw_rect(rect.grow(-3), ink.darkened(0.25), false, 2)
	if building.id == "furnace":
		draw_rect(Rect2(rect.position + Vector2(12, 14), rect.size - Vector2(24, 18)), Color("826d69"))
		var fire := Rect2(rect.position + Vector2(24, 28), Vector2(52, 37))
		draw_rect(fire, Color("efab60") if powered and not storage.recipe.is_empty() else Color("28343b"))
		for index in range(3):
			var point := fire.position + Vector2(10 + index * 15, 24)
			draw_line(point, point - Vector2(0, 12 + sin(outpost.world.ambient_time * 8 + index) * 4), Color("ffe7a1") if powered and not storage.recipe.is_empty() else Color("727e7f"), 6)
		draw_rect(Rect2(rect.end - Vector2(29, 20), Vector2(18, 12)), Color("dfaf77") if not storage.output.is_empty() else Color("475b62"))
	elif building.id == "gas_converter":
		for x in [14, 43]:
			draw_rect(Rect2(rect.position + Vector2(x, 16), Vector2(22, 48)), Color("788c7d"))
			draw_rect(Rect2(rect.position + Vector2(x + 3, 25), Vector2(16, 22)), Color("c6cc70"))
			draw_line(rect.position + Vector2(x - 1, 20), rect.position + Vector2(x + 23, 20), Color("b6c5ac"), 4)
		_draw_bar(rect, float(storage.energy) / float(Catalog.load_data().converter.capacity), ink)
	elif building.id == "water_tank":
		var chamber := rect.grow(-10)
		var fill := clampf(float(storage.water) / float(Catalog.load_data().water_tank_capacity), 0, 1)
		draw_rect(chamber, Color("172e3b"))
		var height := chamber.size.y * fill
		if height > 0:
			draw_rect(Rect2(Vector2(chamber.position.x, chamber.end.y - height), Vector2(chamber.size.x, height)), Color("459fdd"))
		for fraction in [0.25, 0.5, 0.75]:
			var point := chamber.position + Vector2(0, chamber.size.y * fraction)
			draw_line(point, point + Vector2(7, 0), Color("b8dbe4"), 1)
		_draw_bar(rect, fill, Network.COLORS.water)
	else:
		draw_rect(rect.grow(-10), Color("284e49"))
		var growth := 0.0 if storage.crop.is_empty() else float(storage.elapsed) / float(Catalog.load_data().crops[storage.crop].seconds)
		for index in range(4):
			var base := rect.position + Vector2(24 + index * 36, rect.size.y - 17)
			draw_rect(Rect2(base - Vector2(12, 0), Vector2(26, 10)), Color("9e8773"))
			if not storage.crop.is_empty():
				var top := base - Vector2(0, 12 + growth * 42)
				draw_line(base, top, Color("9dd27f"), 3)
				draw_circle(top + Vector2(-6, 4), 4 + growth * 4, Color("b6d994"))
				draw_circle(top + Vector2(6, -2), 4 + growth * 4, Color("e8d089") if growth >= 1 else Color("8bc386"))
			draw_line(rect.position + Vector2(6 + index * 40, 8), rect.position + Vector2(6 + index * 40, rect.size.y - 6), Color("8ab8b0"), 2)
		_draw_bar(rect, growth, ink)
		if _irrigating(building):
			for index in range(8):
				var phase := fposmod(outpost.world.ambient_time * 1.5 + index * 0.17, 1.0)
				var point := rect.position + Vector2(16 + index * (rect.size.x - 32) / 7, 14 + phase * (rect.size.y - 34))
				draw_line(point, point + Vector2(0, 5), Color("92d9ff"), 1.5)
	var name: String = outpost.Buildings.NAMES[building.id]
	if building.id == "water_tank":
		name = "Acqua %.0f / %.0f u" % [float(storage.water), float(Catalog.load_data().water_tank_capacity)]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -6), name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, ink)
	draw_circle(rect.position + Vector2(rect.size.x - 10, 10), 3, Color("b0ef9f") if powered else Color("f2987b"))

func _draw_bar(rect: Rect2, value: float, ink: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 4)), Color("142329"))
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2((rect.size.x - 10) * clampf(value, 0, 1), 4)), ink)
