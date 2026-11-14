extends Node2D

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const Network = preload("res://scripts/systems/utility_network.gd")
const NAMES := {"valve": "Valvola blu", "ship": "Serbatoio nave"}
const PORTS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var outpost: Node2D
var window: Window
var heading: Label
var status: Label
var details: Label
var feedback: Label
var opened_toggle: CheckButton
var remove_button: Button
var selected: Dictionary = {}
var mode := ""
var refresh_timer := 0.0
var hover: PanelContainer
var hover_label: Label

func _ready() -> void:
	z_index = 8
	var layer := CanvasLayer.new()
	add_child(layer)
	hover = PanelContainer.new()
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover.add_theme_stylebox_override("panel", UI.panel_style())
	hover.visible = false
	layer.add_child(hover)
	hover_label = UI.label("", 14)
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover.add_child(hover_label)
	window = Window.new()
	window.title = "Circuito acqua"
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
	details = UI.label("", 15)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	opened_toggle = CheckButton.new()
	opened_toggle.text = "Aperta"
	opened_toggle.tooltip_text = "Apri o chiudi il passaggio dell'acqua"
	opened_toggle.toggled.connect(func(_value: bool):
		feedback.text = "" if outpost.hydraulics.toggle(selected, outpost) else "Comando non disponibile"
		refresh())
	column.add_child(opened_toggle)
	feedback = UI.label("", 14, Color("efb780"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	remove_button = UI.button(buttons, "Rimuovi valvola", func():
		if outpost.hydraulics.remove(selected, outpost):
			reset()
		else:
			feedback.text = "Rimozione non disponibile")
	UI.button(buttons, "Chiudi", window.hide)

func begin(kind: String) -> void:
	reset()
	if kind != "valve":
		return
	mode = kind
	outpost.build_mode = false
	outpost.industry_ui.mode = ""
	outpost.industry_ui.dragging = false
	outpost.industry_ui.menu.hide()
	outpost.industry_ui.context_menu.hide()
	outpost.industry_ui.window.hide()
	outpost.world.mouse_mining = false
	outpost.world._note(NAMES[kind])
	queue_redraw()

func tool_active() -> bool:
	return not mode.is_empty()

func is_open() -> bool:
	return is_instance_valid(window) and window.visible

func reset() -> void:
	mode = ""
	selected = {}
	if is_instance_valid(window):
		window.hide()
	if is_instance_valid(hover):
		hover.hide()
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if tool_active() and event.is_action_pressed("pause"):
		reset()
		return true
	if not event is InputEventMouseButton or not event.pressed:
		return false
	var point: Vector2 = outpost.world.get_global_transform_with_canvas().affine_inverse() * event.position
	var cell := Grid.to_cell(point)
	if tool_active():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			reset()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			var reason := _placement_blocker(cell)
			if not reason.is_empty():
				outpost.world._note(reason)
			elif outpost.hydraulics.place(mode, cell, outpost):
				outpost.world._note(NAMES[mode] + " montato")
			return true
		return false
	if event.button_index != MOUSE_BUTTON_RIGHT or outpost.build_mode or outpost.industry_ui.tool_active():
		return false
	var entry: Dictionary = outpost.hydraulics.at(cell)
	if entry.is_empty():
		return false
	if not _reachable_cell(cell):
		outpost.world._note("Dispositivo fuori portata")
		return true
	selected = entry
	outpost.world.mouse_mining = false
	feedback.text = ""
	refresh()
	window.popup_centered(Vector2i(480, 290))
	return true

func refresh() -> void:
	if selected.is_empty() or not _mounted(selected) or not _reachable_cell(selected.cell):
		window.hide()
		return
	var report: Dictionary = outpost.hydraulics.report(selected, outpost)
	var ship_port: bool = _ship_port(selected)
	heading.text = ("Nave / serbatoio sinistro" if selected.cell.x < 0 else "Nave / serbatoio destro") if ship_port else NAMES.valve
	window.title = heading.text
	status.text = report.get("status", "")
	details.text = "Portata %.2f u/s  |  Trasferiti %.2f u" % [float(report.get("rate", 0)), float(report.get("total", 0))]
	if ship_port:
		details.text = "Acqua %.2f / %.0f u\n%s" % [float(report.get("water", 0)), float(report.get("capacity", 40)), details.text]
	opened_toggle.set_pressed_no_signal(selected.get("opened", false))
	opened_toggle.text = "Aperta" if selected.get("opened", false) else "Chiusa"
	remove_button.visible = not ship_port
	remove_button.disabled = ship_port

func _mounted(entry: Dictionary) -> bool:
	return not entry.is_empty() and outpost.hydraulics.at(entry.cell) == entry

func _ship_port(entry: Dictionary) -> bool:
	return entry.get("kind") == "ship"

func _reachable_cell(cell: Vector2i) -> bool:
	if outpost.world.site.material(cell).is_empty():
		return outpost.reachable_cell(cell)
	var hand: Vector2 = outpost.world.player_center()
	if hand.distance_to(Grid.center(cell)) > Grid.metres(3):
		return false
	var ray := PhysicsRayQueryParameters2D.create(hand, Grid.center(cell), 1, [outpost.world.player.get_rid(), outpost.world.drone.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	# Hitting this rock's exposed face is valid; hitting a nearer wall is not.
	return hit.is_empty() or Grid.rect(cell).grow(0.5).has_point(hit.position)

func _placement_blocker(cell: Vector2i) -> String:
	var reason: String = outpost.hydraulics.placement_blocker(mode, cell, outpost)
	return reason if not reason.is_empty() else ("" if _reachable_cell(cell) else "Valvola fuori portata o dietro una parete")

func _process(delta: float) -> void:
	refresh_timer -= delta
	if is_open() and refresh_timer <= 0:
		refresh_timer = 0.1
		refresh()
	_update_hover()
	queue_redraw()

func _update_hover() -> void:
	hover.hide()
	if is_open() or outpost.world.controls_blocked():
		return
	var cell := Grid.to_cell(outpost.world.get_global_mouse_position())
	var name := ""
	if tool_active():
		name = _placement_blocker(cell)
		if name.is_empty():
			name = NAMES[mode]
	else:
		var entry: Dictionary = outpost.hydraulics.at(cell)
		if not entry.is_empty() and _visible_cell(cell):
			var report: Dictionary = outpost.hydraulics.report(entry, outpost)
			name = ("Serbatoio nave" if _ship_port(entry) else NAMES.valve) + " / " + str(report.get("status", ""))
		if name.is_empty():
			for building: Dictionary in outpost.buildings.structures:
				if not outpost.Buildings.is_active(building) or not _visible_cell(cell):
					continue
				if building.id == "pump":
					var ports: Dictionary = outpost.hydraulics.pump_ports(building)
					if cell in [ports.input, ports.output]:
						name = "Pompa acqua / " + ("Ingresso" if cell == ports.input else "Uscita")
				elif building.id in ["water_tank", "greenhouse"] and cell == Network.port(building, "water"):
					name = outpost.Buildings.NAMES[building.id] + " / Porta acqua"
				if not name.is_empty():
					break
	if name.is_empty():
		return
	hover_label.text = name
	var viewport_size := get_viewport_rect().size
	var font := hover_label.get_theme_font("font")
	var width := minf(font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28, minf(420, viewport_size.x - 24))
	var height := font.get_multiline_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, width - 28, 14).y + 24
	hover.size = Vector2(width, height)
	hover.position = (get_viewport().get_mouse_position() + Vector2(18, 20)).clamp(Vector2(8, 8), (viewport_size - hover.size - Vector2(8, 8)).max(Vector2(8, 8)))
	hover.show()

func _visible_cell(cell: Vector2i) -> bool:
	return _ship_port(outpost.hydraulics.at(cell)) or outpost.world._illumination(Grid.center(cell)) > 0.1

func _draw() -> void:
	for entry: Dictionary in outpost.hydraulics.valves:
		_draw_mounted(entry)
	for entry: Dictionary in outpost.hydraulics.ship_ports():
		_draw_mounted(entry)
	if not tool_active() or outpost.world.controls_blocked():
		return
	var cell := Grid.to_cell(outpost.world.get_global_mouse_position())
	var valid := _placement_blocker(cell).is_empty()
	var ink := Color("8fe3b6") if valid else Color("f37e80")
	draw_rect(Grid.rect(cell).grow(-2), Color(ink, 0.12))
	draw_rect(Grid.rect(cell).grow(-2), ink, false, 2)
	_draw_device(Grid.center(cell), ink, false)

func _draw_mounted(entry: Dictionary) -> void:
	if not _visible_cell(entry.cell):
		return
	var report: Dictionary = outpost.hydraulics.report(entry, outpost)
	var point := Grid.center(entry.cell)
	var light: float = 1.0 if _ship_port(entry) else outpost.world._illumination(point)
	var ink := Color("18292d").lerp(Color("338eff"), clampf(light, 0, 1))
	_draw_device(point, ink, entry.get("opened", false))
	if float(report.get("rate", 0)) > 0:
		var phase := fposmod(outpost.world.ambient_time * 1.8, 1.0)
		draw_arc(point, 10, phase * TAU, phase * TAU + PI, 12, Color("d7faf0"), 2)

func _draw_device(point: Vector2, ink: Color, opened: bool) -> void:
	draw_rect(Rect2(point - Vector2(18, 18), Vector2(36, 36)), ink.darkened(0.35))
	draw_rect(Rect2(point - Vector2(16, 16), Vector2(32, 32)), ink)
	for offset: Vector2i in PORTS:
		var axis := Vector2(offset)
		draw_line(point + axis * 11, point + axis * 20, ink.lightened(0.45), 6)
	draw_circle(point, 10, Color("14314a"))
	draw_arc(point, 7, 0, TAU, 16, Color("b6edff"), 2)
	draw_line(point - Vector2(0, 6) if opened else point - Vector2(6, 0), point + Vector2(0, 6) if opened else point + Vector2(6, 0), Color("a8e5ad") if opened else Color("edb18d"), 3)
