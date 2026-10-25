extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
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
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	heading = UI.label("", 20)
	column.add_child(heading)
	column.add_child(UI.label("Materiali comuni: zaino + Robbie + deposito di questo laboratorio", 14, Color("b4c5c6")))
	column.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for text: String in ["Oggetto", "Livello", "Tempo", "Risorse disponibili / costo", ""]:
		grid.add_child(UI.label(text, 14, Color("b4c5c6")))
	var name_label := UI.label("Laboratorio", 18)
	name_label.custom_minimum_size.x = 130
	grid.add_child(name_label)
	grid.add_child(UI.label("1", 18))
	duration = UI.label("", 17)
	duration.custom_minimum_size.x = 68
	grid.add_child(duration)
	var ingredients := VBoxContainer.new()
	ingredients.custom_minimum_size.x = 214
	grid.add_child(ingredients)
	for id: String in outpost.lab_definition().get("cost", {}):
		var label := UI.label("", 16)
		ingredients.add_child(label)
		resource_labels[id] = label
	craft_button = UI.button(grid, "Crea", _start_craft)
	craft_button.custom_minimum_size.x = 92
	craft_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(HSeparator.new())
	craft_bar = ProgressBar.new()
	craft_bar.custom_minimum_size.y = 22
	craft_bar.show_percentage = true
	column.add_child(craft_bar)
	choice_status = UI.label("", 16)
	choice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_status.custom_minimum_size.y = 52
	column.add_child(choice_status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
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
			outpost.activate_cube(site))
	add_child(activation_popup)

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
	picker.popup_centered(Vector2i(840, 380))

func open_cube(cube: Dictionary, viewport_point: Vector2) -> void:
	site = cube
	activation_popup.clear()
	activation_popup.add_separator("Cubo laboratorio / livello 1")
	activation_popup.add_item("Attiva laboratorio / 4 x 3 m", 0)
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

func _legacy_fund(id: int) -> void:
	if id == 1:
		if not outpost.fund_site(site):
			outpost.world._note(outpost.funding_blocker(site))
		activation_popup.hide()

func _start_craft() -> void:
	outpost.fabricate_lab_cube()
	refresh()

func _cancel_picker() -> void:
	picker.hide()

func refresh() -> void:
	var station: Dictionary = outpost.nearby_station()
	if station.is_empty():
		picker.hide()
		return
	heading.text = "%s / LIVELLO %d" % [outpost.station_name().to_upper(), outpost.station_level(station)]
	duration.text = "%.1f s" % outpost.fabrication_seconds(station)
	for id: String in resource_labels:
		var available: int = outpost.fabrication_amount(id)
		var required: int = outpost.lab_definition().cost[id]
		resource_labels[id].text = "%s  %d / %d" % [UI.NAMES[id], available, required]
		resource_labels[id].modulate = Color("a7e5b4") if available >= required else Color("ff7e85")
	var reason: String = outpost.fabrication_blocker()
	craft_button.disabled = not reason.is_empty()
	craft_button.tooltip_text = reason
	var job: Dictionary = outpost.fabrication.job_at(outpost.station_identity(station))
	craft_bar.visible = not job.is_empty()
	if not job.is_empty():
		craft_bar.value = float(job.elapsed) / float(job.seconds) * 100
		var pause_reason: String = outpost.fabrication_pause_reason(job)
		choice_status.text = pause_reason if not pause_reason.is_empty() else "Materializzazione sul banco / %.1f s rimanenti" % (float(job.seconds) - float(job.elapsed))
	else:
		choice_status.text = reason if not reason.is_empty() else "Banco pronto"
	choice_status.modulate = Color("a7e5b4") if reason.is_empty() or not outpost.fabrication.output_at(outpost.station_identity(station)).is_empty() else Color("e5efeb")

func _process(_delta: float) -> void:
	if picker.visible:
		refresh()
