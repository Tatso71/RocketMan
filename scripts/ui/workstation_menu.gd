extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const ACTION_NAMES := ["Deposita materiali", "Preleva materiali", "Costruisci", "Ripara", "Potenzia laboratorio"]
var outpost: Node2D
var popup: PopupMenu
var window: Window
var column: VBoxContainer
var heading: Label
var feedback: Label
var rows: Array = []
var section := 2

func _ready() -> void:
	popup = PopupMenu.new()
	popup.prefer_native_menu = false
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("v_separation", 14)
	popup.add_theme_stylebox_override("panel", UI.panel_style())
	popup.id_pressed.connect(activate)
	add_child(popup)
	window = Window.new()
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
	var background := ColorRect.new()
	background.color = Color("222b2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	window.add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

func is_open() -> bool:
	return popup.visible or window.visible

func open(viewport_point: Vector2) -> void:
	popup.clear()
	popup.add_separator(outpost.station_name())
	for index in range(ACTION_NAMES.size()):
		popup.add_item(ACTION_NAMES[index], index)
	if outpost.selected_station.get("kind") == "laboratory":
		popup.add_separator()
		popup.add_item("Spegni laboratorio" if outpost.selected_station.building.get("enabled", true) else "Accendi laboratorio", 5)
	var screen_point: Vector2 = outpost.get_viewport().get_screen_transform() * viewport_point
	popup.popup(Rect2i(Vector2i(screen_point), Vector2i(300, 240)))

func activate(id: int) -> void:
	popup.hide()
	if not outpost.station_available(outpost.selected_station):
		return
	if id == 0:
		outpost.cargo_ui.deposit()
		outpost.world._note(outpost.cargo_ui.feedback.text)
	elif id == 1:
		outpost.open_cargo()
		outpost.cargo_ui.picker.grab_focus()
	elif id == 2:
		var world: Node2D = outpost.world
		var anchor: Vector2i = world.Grid.to_cell(world.player.position - Vector2(0, 1))
		outpost.construction.open_picker(anchor, world.player.get_global_transform_with_canvas() * Vector2(0, -60))
	elif id == 5:
		outpost.selected_station.building.enabled = not outpost.selected_station.building.get("enabled", true)
		outpost.world._note("Laboratorio acceso" if outpost.selected_station.building.enabled else "Laboratorio spento: consumo interrotto")
	else:
		show_section(id)

func show_section(id: int) -> void:
	if id == 2:
		activate(2)
		return
	section = id
	rows.clear()
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	window.title = outpost.station_name() + " / " + ACTION_NAMES[id]
	heading = UI.label(ACTION_NAMES[id].to_upper(), 22)
	column.add_child(heading)
	column.add_child(UI.label(outpost.station_name(), 15, Color("a7e5b4")))
	column.add_child(HSeparator.new())
	if id == 2:
		row("laboratory", "Laboratorio 4 x 3 m", "Posiziona", _begin_build.bind("laboratory"))
		row("supplies", "Materiali del laboratorio", "Prepara carico", _prepare)
		row("lamp", "Cubo luce / 1 x 1 m", "Progetta cubo", _begin_build.bind("lamp"))
	elif id == 3:
		row("suit", "Ripristina la tuta", "Ripara", _perform.bind("suit"))
		row("hull", "Ripara lo scafo della nave", "Ripara", _perform.bind("hull"))
	elif id == 4:
		row("upgrade", "Potenziamento della postazione", "Potenzia", _perform.bind("upgrade"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	feedback = UI.label("", 14, Color("f0d281"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 40
	column.add_child(feedback)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UI.button(footer, "Chiudi", window.hide)
	window.popup_centered(Vector2i(760, 600))
	refresh()

func row(key: String, name: String, command: String, callback: Callable) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	column.add_child(line)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(details)
	details.add_child(UI.label(name, 17))
	var info := UI.label("", 13, Color("b4c5c6"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 430
	details.add_child(info)
	var button := UI.button(line, command, callback)
	button.custom_minimum_size.x = 136
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rows.append({"key": key, "info": info, "button": button})

func _begin_build(id: String) -> void:
	window.hide()
	outpost.blueprint = id
	outpost.build_mode = false
	outpost.toggle_build()

func _prepare() -> void:
	if not outpost.station_available(outpost.selected_station):
		return
	outpost.cargo_ui.prepare_lab()
	feedback.text = outpost.cargo_ui.feedback.text
	refresh()

func hull_blocker() -> String:
	var ship: RefCounted = outpost.world.ship_state
	if not outpost.world.aboard_workshop():
		return "Rientra nel laboratorio di bordo"
	if ship == null:
		return "Manutenzione dello scafo disponibile nella spedizione"
	if ship.hull >= ship.hull_capacity():
		return "Scafo gia integro"
	return "" if ship.can_afford({"stone": 2, "copper": 1}) else "Servono 2 pietra + 1 rame nella stiva"

func _perform(action: String) -> void:
	if not outpost.station_available(outpost.selected_station):
		return
	var ok := false
	if action == "lamp":
		ok = outpost.craft_lamp()
	elif action == "suit":
		ok = outpost.repair_suit()
	elif action == "hull" and hull_blocker().is_empty():
		ok = outpost.world.ship_state.repair()
	elif action == "upgrade":
		ok = outpost.upgrade_station()
	feedback.text = {"lamp": "Luce aggiunta al carico", "suit": "Tuta ripristinata al 100%", "hull": "Scafo riparato: +25 integrita", "upgrade": "Laboratorio potenziato"}.get(action, "Operazione completata") if ok else "Operazione non disponibile: controlla requisiti e materiali."
	outpost.cargo_ui.refresh()
	refresh()

func refresh() -> void:
	var aboard: bool = outpost.world.aboard_workshop()
	for item: Dictionary in rows:
		var reason := ""
		var text := ""
		match item.key:
			"laboratory":
				text = "Cubo creatore / 6 pietra + 4 rame da trasferire sul posto"
			"supplies":
				text = "Preleva dalla stiva la pietra e il rame mancanti"
				reason = outpost.cargo_ui.prepare_blocker()
			"lamp":
				text = "Cubo creatore / 1 terra + 1 rame da trasferire sul posto"
			"place_lamp":
				text = "1 kit luce nel carico / pavimento libero"
				reason = "Fabbrica prima una luce" if outpost.world.field_cargo.available("lamp_kit", outpost.world.drone_help_available(), outpost.payment_cache()) <= 0 else ""
			"suit":
				text = "Tuta %.0f%% / %s" % [outpost.world.suit_integrity(), "ripristino gratuito a bordo" if aboard else "2 terra + 1 rame / ripristino al 100%"]
				reason = outpost.suit_repair_blocker()
			"hull":
				text = "2 pietra + 1 rame dalla stiva / +25 integrita"
				reason = hull_blocker()
			"upgrade":
				var ship: RefCounted = outpost.world.ship_state
				if aboard and ship != null:
					text = "Banco strumenti / livello %d di 3" % ship.modules.drill
					if not ship.upgrade_cost("drill").is_empty():
						text += "\nProssimo livello: +1 potenza di scavo, nuovi estrattori\nCosto: %s" % cost_text(ship.upgrade_cost("drill"))
				elif not aboard:
					var lab: Dictionary = outpost.selected_station.building
					text = "Livello %d di 3 / deposito %d unita / luci %.0f m\nAlimentazione dalla nave: %.2f kWh/min" % [lab.get("level", 1), Buildings.cache_capacity(lab), Buildings.light_range(lab), Buildings.power_draw(lab) * 60]
					if not Buildings.upgrade_cost(lab).is_empty():
						text += "\nProssimo livello: +16 unita e +2 m per le luci\nCosto: %s" % cost_text(Buildings.upgrade_cost(lab))
				reason = outpost.upgrade_blocker()
		item.info.text = text + ("\n" + reason if not reason.is_empty() else "")
		item.button.disabled = not reason.is_empty()
		item.button.tooltip_text = reason

func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in cost:
		parts.append("%d %s" % [cost[id], UI.NAMES[id].to_lower()])
	return " + ".join(parts) if not parts.is_empty() else "--"

func _process(_delta: float) -> void:
	if not is_open():
		return
	if not outpost.station_available(outpost.selected_station):
		popup.hide()
		window.hide()
	elif window.visible:
		refresh()
