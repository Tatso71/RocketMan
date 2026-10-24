extends Node2D

const State = preload("res://scripts/systems/expedition_state.gd")
const Planets = preload("res://scripts/data/planet_catalog.gd")
const Modules = preload("res://scripts/data/ship_module_catalog.gd")
const Exterior = preload("res://scripts/prototype/rocket_exterior.gd")
const Home = preload("res://scenes/prototype/rocket_home.tscn")
const PHASE_NAMES := ["Scelta del pianeta", "Volo interplanetario", "Atterraggio verticale", "Esplorazione e scavo", "Decollo"]
const RESOURCE_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo"}
var model := State.new()
var world: Node2D
var exterior: Node2D
var screen: Control
var phase_label: Label
var info_label: Label
var stats_label: Label
var status_label: Label
var planet_list: ItemList
var depart_button: Button
var progress_bar: ProgressBar
var selection_controls: VBoxContainer
var ship_menu: Window
var ship_stats: Label
var module_picker: OptionButton
var module_details: Label
var upgrade_button: Button
var service_status: Label
var discard_picker: OptionButton
var repair_button: Button
var fuel_button: Button
var charge_button: Button
var feedback := ""

func _ready() -> void:
	exterior = Exterior.new()
	add_child(exterior)
	_build_interface()
	_build_ship_menu()
	_sync_phase()

func _process(delta: float) -> void:
	var previous: int = model.phase
	if not ship_menu.visible:
		model.advance(delta)
	if model.phase != previous:
		_sync_phase()
	_refresh_interface()
	if ship_menu.visible:
		_refresh_ship_menu()
	_animate_exterior()
	queue_redraw()

func _sync_phase() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
		world = null
	screen.visible = model.phase != State.Phase.DIGGING
	exterior.visible = model.phase in [State.Phase.FLIGHT, State.Phase.LANDING, State.Phase.TAKEOFF]
	if model.phase != State.Phase.DIGGING:
		get_viewport().canvas_transform = Transform2D.IDENTITY
	if model.phase == State.Phase.DIGGING:
		world = Home.instantiate()
		world.configure(self, Planets.find(model.active_planet), model.ship)
		add_child(world)
		if model.outposts.has(model.active_planet):
			world.restore_state(model.outposts[model.active_planet], false)
	planet_list.select(_selected_index())
	_refresh_interface()

func _selected_index() -> int:
	var planets := Planets.all()
	for index in range(planets.size()):
		if planets[index].planet_id == model.selected_planet:
			return index
	return 0

func select_planet(index: int) -> void:
	var planets := Planets.all()
	if index >= 0 and index < planets.size() and model.choose(planets[index].planet_id):
		planet_list.select(index)
		feedback = ""
		_refresh_interface()

func depart() -> bool:
	if not model.depart():
		_notify(model.ship.flight_blocker(Planets.find(model.selected_planet)))
		return false
	feedback = ""
	_sync_phase()
	return true

func request_takeoff() -> bool:
	if not is_instance_valid(world) or model.phase != State.Phase.DIGGING:
		return false
	if world.player.position.y > -78 or absf(world.player.position.x) > 160:
		_notify("Rientra a bordo prima del decollo")
		return false
	if world.hatch_open:
		_notify("Chiudi la botola prima del decollo")
		return false
	if model.ship.hull < 20 or model.ship.fuel < 6 or model.ship.energy < 2:
		_notify("Ripara lo scafo, rifornisci e ricarica prima del decollo")
		return false
	model.outposts[model.active_planet] = world.capture_state()
	if not model.takeoff():
		return false
	feedback = ""
	_sync_phase()
	return true

func save_campaign() -> bool:
	if is_instance_valid(world):
		model.outposts[model.active_planet] = world.capture_state()
	var ok: bool = SaveManager.write_campaign_save(model.snapshot())
	_notify("Spedizione salvata" if ok else "Salvataggio non riuscito")
	return ok

func load_campaign() -> bool:
	var data: Dictionary = SaveManager.read_campaign_save()
	if not model.restore(data):
		_notify("Nessuna spedizione compatibile da caricare")
		return false
	ship_menu.hide()
	_sync_phase()
	_notify("Spedizione caricata")
	return true

func _notify(message: String) -> void:
	feedback = message
	if is_instance_valid(world):
		world._note(message)
	if is_instance_valid(status_label):
		status_label.text = message

func open_ship_menu() -> void:
	if is_instance_valid(world):
		world.controls_locked = true
	ship_menu.popup_centered(Vector2i(760, 540))
	_refresh_ship_menu()

func _close_ship_menu() -> void:
	ship_menu.hide()
	if is_instance_valid(world):
		world.controls_locked = false

func _animate_exterior() -> void:
	exterior.legs_deployed = model.phase in [State.Phase.LANDING, State.Phase.TAKEOFF]
	exterior.engines_on = true
	exterior.scale = Vector2.ONE * 0.75
	if model.phase == State.Phase.FLIGHT:
		exterior.position = Vector2(860, 570 - model.progress * 35)
		exterior.rotation = -0.3
	elif model.phase == State.Phase.LANDING:
		exterior.rotation = 0
		exterior.position = Vector2(850, lerpf(345, 650, model.progress))
	elif model.phase == State.Phase.TAKEOFF:
		exterior.rotation = 0
		exterior.position = Vector2(850, lerpf(650, 150, model.progress))

func _unhandled_input(event: InputEvent) -> void:
	if ship_menu.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and model.phase == State.Phase.SELECT:
		var planets := Planets.all()
		for index in range(planets.size()):
			if get_global_mouse_position().distance_to(planets[index].map_position) < 65:
				select_planet(index)
	if event.is_action_pressed("pause") and not event.is_echo():
		open_ship_menu()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var header := ColorRect.new()
	header.color = Color("182c36")
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 66
	screen.add_child(header)
	_label(header, "ROCKETMAN / SPEDIZIONE", Vector2(24, 10), Vector2(600, 26), 20)
	phase_label = _label(header, "", Vector2(24, 37), Vector2(600, 20), 14)
	var toolbar := HBoxContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toolbar.offset_left = -300
	toolbar.offset_right = -20
	toolbar.offset_top = 16
	header.add_child(toolbar)
	_button(toolbar, "Nave", open_ship_menu)
	_button(toolbar, "Salva", save_campaign)
	_button(toolbar, "Carica", load_campaign)
	var sidebar := ColorRect.new()
	sidebar.color = Color("223941")
	sidebar.position = Vector2(0, 66)
	sidebar.size = Vector2(410, 616)
	screen.add_child(sidebar)
	selection_controls = VBoxContainer.new()
	selection_controls.position = Vector2(24, 88)
	selection_controls.size.x = 360
	selection_controls.add_theme_constant_override("separation", 14)
	screen.add_child(selection_controls)
	var heading := Label.new()
	heading.text = "DESTINAZIONE"
	heading.add_theme_font_size_override("font_size", 14)
	selection_controls.add_child(heading)
	planet_list = ItemList.new()
	planet_list.custom_minimum_size = Vector2(360, 116)
	planet_list.add_theme_font_size_override("font_size", 19)
	for planet: Resource in Planets.all():
		planet_list.add_item(planet.display_name)
	planet_list.item_selected.connect(select_planet)
	selection_controls.add_child(planet_list)
	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(360, 122)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 16)
	selection_controls.add_child(info_label)
	depart_button = _button(selection_controls, "Avvia volo", depart)
	stats_label = _label(screen, "", Vector2(24, 500), Vector2(360, 162), 14)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(24, 420)
	progress_bar.size = Vector2(360, 12)
	progress_bar.show_percentage = false
	screen.add_child(progress_bar)
	var bottom := ColorRect.new()
	bottom.color = Color("182c36")
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -38
	screen.add_child(bottom)
	status_label = _label(bottom, "", Vector2(24, 8), Vector2(1200, 24), 14)

func _label(parent: Node, text: String, point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 34)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _refresh_interface() -> void:
	var planet := Planets.find(model.selected_planet)
	phase_label.text = PHASE_NAMES[model.phase]
	planet_list.visible = model.phase == State.Phase.SELECT
	depart_button.visible = model.phase == State.Phase.SELECT
	var cost: float = model.ship.route_cost(planet)
	info_label.text = "%s\n\nRotta: %.0f u carburante + 6 u riserva\nUsura atterraggio: %.1f integrita\n\n%s" % [planet.display_name, cost, planet.landing_hazard / int(model.ship.modules.landing_gear), planet.scan_summary]
	depart_button.disabled = not model.ship.flight_blocker(planet).is_empty()
	depart_button.tooltip_text = model.ship.flight_blocker(planet)
	stats_label.text = _ship_summary()
	progress_bar.visible = model.phase in State.DURATIONS
	progress_bar.value = model.progress * 100
	status_label.text = feedback if not feedback.is_empty() else (model.ship.flight_blocker(planet) if model.phase == State.Phase.SELECT else PHASE_NAMES[model.phase])

func _ship_summary() -> String:
	return "ASTRONAVE\n\nScafo   %.0f / %.0f\nCarburante   %.0f / %.0f u\nEnergia   %.1f / %.0f kWh\nStiva   %d / %d unita\nMassa a vuoto   %.0f kg" % [model.ship.hull, model.ship.hull_capacity(), model.ship.fuel, model.ship.fuel_capacity(), model.ship.energy, model.ship.energy_capacity(), model.ship.cargo_used(), model.ship.cargo_capacity(), model.ship.dry_mass_kg()]

func _build_ship_menu() -> void:
	ship_menu = Window.new()
	ship_menu.title = "Astronave / Moduli e manutenzione"
	ship_menu.transient = true
	ship_menu.exclusive = true
	ship_menu.unresizable = true
	ship_menu.visible = false
	ship_menu.close_requested.connect(_close_ship_menu)
	add_child(ship_menu)
	var body := HBoxContainer.new()
	body.position = Vector2(22, 20)
	body.size = Vector2(716, 490)
	body.add_theme_constant_override("separation", 28)
	ship_menu.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	ship_stats = Label.new()
	ship_stats.custom_minimum_size = Vector2(290, 230)
	ship_stats.add_theme_font_size_override("font_size", 16)
	left.add_child(ship_stats)
	repair_button = _button(left, "Ripara (+25 scafo)", func(): _service("repair"))
	repair_button.tooltip_text = "Costo: 2 pietra + 1 rame"
	fuel_button = _button(left, "Rifornisci (+20 u)", func(): _service("refuel"))
	fuel_button.tooltip_text = "Costo: 2 terra (conversione provvisoria)"
	charge_button = _button(left, "Ricarica solare (+15 kWh)", func(): _service("recharge"))
	charge_button.tooltip_text = "Ricarica di emergenza disponibile in orbita o in officina"
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 370
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var title := Label.new()
	title.text = "MODULI"
	right.add_child(title)
	module_picker = OptionButton.new()
	for definition: Resource in Modules.all():
		module_picker.add_item(definition.display_name)
	right.add_child(module_picker)
	module_details = Label.new()
	module_details.custom_minimum_size = Vector2(370, 146)
	module_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(module_details)
	upgrade_button = _button(right, "Installa potenziamento", _upgrade)
	service_status = Label.new()
	service_status.custom_minimum_size = Vector2(370, 64)
	service_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(service_status)
	discard_picker = OptionButton.new()
	for id: String in model.ship.RESOURCE_IDS:
		discard_picker.add_item(RESOURCE_NAMES[id])
	right.add_child(discard_picker)
	_button(right, "Espelli 1 unita", _discard)
	_button(right, "Chiudi", _close_ship_menu)

func _refresh_ship_menu() -> void:
	ship_stats.text = _ship_summary() + "\n\nTerra %d   Pietra %d\nRame %d   Cristalli %d" % [model.ship.resources.soil, model.ship.resources.stone, model.ship.resources.copper, model.ship.resources.crystal]
	var definition: Resource = Modules.all()[module_picker.selected]
	var cost: Dictionary = model.ship.upgrade_cost(definition.module_id)
	var price: Array[String] = []
	for id: String in cost:
		price.append("%d %s" % [cost[id], RESOURCE_NAMES[id]])
	module_details.text = "%s  /  Livello %d di %d\n\n%s\nIngombro: %d x %d m\nCosto: %s" % [definition.display_name, model.ship.modules[definition.module_id], definition.max_level, definition.description, definition.footprint_cells.x, definition.footprint_cells.y, ", ".join(price) if not cost.is_empty() else "livello massimo"]
	upgrade_button.disabled = cost.is_empty() or not model.ship.can_afford(cost)
	var can_service := _can_service()
	upgrade_button.disabled = upgrade_button.disabled or not can_service
	repair_button.disabled = not can_service or model.ship.hull >= model.ship.hull_capacity() or not model.ship.can_afford({"stone": 2, "copper": 1})
	fuel_button.disabled = not can_service or model.ship.fuel >= model.ship.fuel_capacity() or not model.ship.can_afford({"soil": 2})
	charge_button.disabled = not can_service or model.ship.energy >= model.ship.energy_capacity()

func _service(action: String) -> void:
	if not _can_service():
		return
	var ok: bool = model.ship.call(action)
	service_status.text = "Operazione completata" if ok else "Operazione non disponibile"
	_refresh_ship_menu()

func _upgrade() -> void:
	if not _can_service():
		return
	var definition: Resource = Modules.all()[module_picker.selected]
	var ok: bool = model.ship.upgrade(definition.module_id)
	service_status.text = "Modulo potenziato: " + definition.display_name if ok else "Risorse insufficienti o livello massimo"
	_refresh_ship_menu()

func _discard() -> void:
	var id: String = model.ship.RESOURCE_IDS[discard_picker.selected]
	if int(model.ship.resources.get(id, 0)) > 0:
		model.ship.resources[id] = int(model.ship.resources[id]) - 1
		service_status.text = "Espulsa 1 unita di " + RESOURCE_NAMES[id]
	_refresh_ship_menu()

func _can_service() -> bool:
	if model.phase == State.Phase.SELECT:
		return true
	return model.phase == State.Phase.DIGGING and is_instance_valid(world) and absf(world.player.position.x) < 160 and world.player.position.y > -200 and world.player.position.y <= -78

func _draw() -> void:
	if model.phase == State.Phase.DIGGING:
		return
	draw_rect(Rect2(0, 0, 1800, 1200), Color("142332"))
	for index in range(150):
		var point := Vector2(posmod(index * 173, 1280), posmod(index * 97, 720))
		draw_rect(Rect2(point, Vector2.ONE * (1 + index % 2)), Color("809da8"))
	if model.phase == State.Phase.SELECT:
		for planet: Resource in Planets.all():
			var selected: bool = planet.planet_id == model.selected_planet
			draw_line(Vector2(460, 600), planet.map_position, Color("48666d"), 1)
			_planet(planet.map_position, 49, planet.surface_color, planet.rock_color)
			if selected:
				draw_arc(planet.map_position, 61, 0, TAU, 64, Color("edc97e"), 3)
			draw_string(ThemeDB.fallback_font, planet.map_position + Vector2(-52, 90), planet.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e5eee6"))
	else:
		var planet := Planets.find(model.active_planet)
		if model.phase == State.Phase.FLIGHT:
			_planet(Vector2(1120, 650), 260, planet.surface_color, planet.rock_color)
		else:
			draw_rect(Rect2(410, 0, 1400, 720), planet.surface_color)
			for index in range(8):
				var x := 420.0 + index * 130
				draw_colored_polygon(PackedVector2Array([Vector2(x, 650), Vector2(x + 25, 510 - index % 3 * 55), Vector2(x + 75, 490 - index % 3 * 55), Vector2(x + 110, 650)]), planet.rock_color.lightened(0.18))
			draw_rect(Rect2(410, 650, 1400, 70), planet.rock_color)

func _planet(center: Vector2, radius: float, sky: Color, rock: Color) -> void:
	draw_circle(center, radius, sky)
	for index in range(4):
		var offset := Vector2(-radius * 0.5 + index * radius * 0.25, sin(index * 2.4) * radius * 0.45)
		draw_circle(center + offset, radius * 0.22, rock)
	draw_arc(center, radius, -2, 0.7, 48, sky.lightened(0.25), 3)
