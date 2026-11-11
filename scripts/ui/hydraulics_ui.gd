extends Node2D

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Grid = preload("res://scripts/world/world_grid.gd")
const NAMES := {"valve": "Presa stagna", "outlet": "Terminale di scarico"}
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const DIRECTION_NAMES := ["Destra", "Basso", "Sinistra", "Alto"]
var outpost: Node2D
var window: Window
var heading: Label
var status: Label
var details: Label
var feedback: Label
var opened_toggle: CheckButton
var drill_button: Button
var role_picker: OptionButton
var selected: Dictionary = {}
var mode := ""
var direction := Vector2i.RIGHT
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
	role_picker = OptionButton.new()
	role_picker.add_item("Scarico nel mondo")
	role_picker.add_item("Aspirazione dal mondo")
	role_picker.item_selected.connect(func(index: int):
		feedback.text = "Modalita' cambiata: apri il terminale quando il circuito e' pronto" if outpost.hydraulics.set_role(selected, "outlet" if index == 0 else "intake", outpost) else "Terminale non raggiungibile"
		refresh())
	column.add_child(role_picker)
	opened_toggle = CheckButton.new()
	opened_toggle.text = "Aperta"
	opened_toggle.tooltip_text = "Apri o chiudi il passaggio dell'acqua"
	opened_toggle.toggled.connect(func(_value: bool):
		feedback.text = "" if outpost.hydraulics.toggle(selected, outpost) else "Comando non disponibile"
		refresh())
	column.add_child(opened_toggle)
	drill_button = UI.button(column, "Perfora in tenuta", func():
		var reason: String = outpost.hydraulics.drill_blocker(selected, outpost)
		feedback.text = "Perforazione stagna completata" if reason.is_empty() and outpost.hydraulics.drill(selected, outpost) else reason
		refresh())
	drill_button.tooltip_text = "Perfora il blocco di ancoraggio mantenendo la tenuta"
	feedback = UI.label("", 14, Color("efb780"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	UI.button(buttons, "Smonta", func():
		if outpost.hydraulics.remove(selected, outpost):
			reset()
		else:
			feedback.text = "Smontaggio non disponibile")
	UI.button(buttons, "Chiudi", window.hide)

func begin(kind: String) -> void:
	reset()
	if not NAMES.has(kind):
		return
	mode = kind
	direction = Vector2i.RIGHT if kind == "valve" else Vector2i.DOWN
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
	direction = Vector2i.RIGHT
	if is_instance_valid(window):
		window.hide()
	if is_instance_valid(hover):
		hover.hide()
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if tool_active() and event.is_action_pressed("pause"):
		reset()
		return true
	if tool_active() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		direction = DIRECTIONS[(DIRECTIONS.find(direction) + 1) % DIRECTIONS.size()]
		queue_redraw()
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
			var reason: String = outpost.hydraulics.placement_blocker(mode, cell, direction, outpost)
			if not reason.is_empty():
				outpost.world._note(reason)
			elif outpost.hydraulics.place(mode, cell, direction, outpost):
				outpost.world._note(NAMES[mode] + " montato")
			return true
		return false
	if event.button_index != MOUSE_BUTTON_RIGHT or outpost.build_mode or outpost.industry_ui.tool_active():
		return false
	var entry: Dictionary = outpost.hydraulics.at(cell)
	if entry.is_empty():
		return false
	if not outpost.reachable_cell(cell):
		outpost.world._note("Dispositivo fuori portata")
		return true
	selected = entry
	outpost.world.mouse_mining = false
	feedback.text = ""
	refresh()
	window.popup_centered(Vector2i(560, 380))
	return true

func refresh() -> void:
	if selected.is_empty() or not _mounted(selected) or not outpost.reachable_cell(selected.cell):
		window.hide()
		return
	var report: Dictionary = outpost.hydraulics.report(selected, outpost)
	var kind: String = report.get("kind", "valve" if selected.has("drilled") else "outlet")
	heading.text = NAMES.get(kind, "Circuito acqua")
	if kind == "outlet":
		heading.text = "Terminale di aspirazione" if selected.get("role") == "intake" else "Terminale di scarico"
	role_picker.visible = kind == "outlet"
	role_picker.select(1 if selected.get("role") == "intake" else 0)
	status.text = report.get("status", "")
	var destination: Vector2i = selected.cell + selected.direction
	details.text = "Direzione: %s  |  Cella [%d, %d]\n%s [%d, %d]\nPortata effettiva %.2f u/s  |  Trasferiti %.2f u" % [DIRECTION_NAMES[DIRECTIONS.find(selected.direction)], selected.cell.x, selected.cell.y, "Ancoraggio" if kind == "valve" else "Scarico", destination.x, destination.y, float(report.get("rate", 0)), float(report.get("total", 0))]
	opened_toggle.set_pressed_no_signal(selected.get("opened", false))
	opened_toggle.text = "Aperta" if selected.get("opened", false) else "Chiusa"
	opened_toggle.disabled = kind == "valve" and not selected.get("drilled", false)
	drill_button.visible = kind == "valve"
	drill_button.disabled = selected.get("drilled", false)
	drill_button.text = "Perforazione completata" if selected.get("drilled", false) else "Perfora in tenuta"

func _mounted(entry: Dictionary) -> bool:
	return outpost.hydraulics.valves.has(entry) or outpost.hydraulics.outlets.has(entry)

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
		name = outpost.hydraulics.placement_blocker(mode, cell, direction, outpost)
		if name.is_empty():
			name = NAMES[mode] + " / " + DIRECTION_NAMES[DIRECTIONS.find(direction)]
	else:
		var entry: Dictionary = outpost.hydraulics.at(cell)
		if not entry.is_empty() and _visible_cell(cell):
			name = NAMES["valve" if entry.has("drilled") else "outlet"]
		if name.is_empty():
			for building: Dictionary in outpost.buildings.structures:
				if building.id != "pump" or not outpost.Buildings.is_active(building):
					continue
				var ports: Dictionary = outpost.hydraulics.pump_ports(building)
				if _visible_cell(cell) and cell in [ports.input, ports.output]:
					name = "Pompa acqua / " + ("Ingresso" if cell == ports.input else "Uscita")
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
	return outpost.world.site.material(cell).is_empty() and outpost.world._illumination(Grid.center(cell)) > 0.1

func _draw() -> void:
	for entry: Dictionary in outpost.hydraulics.valves:
		_draw_mounted(entry, "valve")
	for entry: Dictionary in outpost.hydraulics.outlets:
		_draw_mounted(entry, "outlet")
	if not tool_active() or outpost.world.controls_blocked():
		return
	var cell := Grid.to_cell(outpost.world.get_global_mouse_position())
	var valid: bool = outpost.hydraulics.placement_blocker(mode, cell, direction, outpost).is_empty()
	var ink := Color("8fe3b6") if valid else Color("f37e80")
	draw_rect(Grid.rect(cell).grow(-2), Color(ink, 0.12))
	draw_rect(Grid.rect(cell).grow(-2), ink, false, 2)
	_draw_device(Grid.center(cell), direction, mode, ink, false, false)

func _draw_mounted(entry: Dictionary, kind: String) -> void:
	if not _visible_cell(entry.cell):
		return
	var report: Dictionary = outpost.hydraulics.report(entry, outpost)
	var point := Grid.center(entry.cell)
	var light: float = outpost.world._illumination(point)
	var ink := Color("18292d").lerp(Color("9cddd9") if kind == "valve" else Color("efcb83"), clampf(light, 0, 1))
	_draw_device(point, entry.direction, kind, ink, entry.get("opened", false), entry.get("drilled", false))
	if float(report.get("rate", 0)) > 0:
		var flow_direction := -Vector2(entry.direction) if kind == "valve" or entry.get("role") == "intake" else Vector2(entry.direction)
		var phase := fposmod(outpost.world.ambient_time * 1.8, 1.0)
		draw_circle(point + flow_direction * lerpf(-17, 17, phase), 2.5, Color("d7faf0"))

func _draw_device(point: Vector2, facing: Vector2i, kind: String, ink: Color, opened: bool, drilled: bool) -> void:
	var axis := Vector2(facing)
	var side := axis.orthogonal()
	draw_line(point - axis * 12, point + axis * 19, ink.darkened(0.45), 9)
	draw_line(point - axis * 12 - side * 2, point + axis * 19 - side * 2, ink, 3)
	if kind == "valve":
		draw_line(point + axis * 18 - side * 13, point + axis * 18 + side * 13, ink, 5)
		var vertices := PackedVector2Array()
		for index in range(6):
			vertices.append(point + Vector2.from_angle(index * TAU / 6) * 10)
		draw_colored_polygon(vertices, ink.darkened(0.2))
		draw_line(point - side * 8, point + side * 8, Color("a8e5ad") if opened else Color("edb18d"), 3)
		if drilled:
			draw_circle(point, 3, ink.lightened(0.3))
	else:
		var tip := point + axis * 17
		draw_line(tip - axis * 5 - side * 9, tip - axis * 5 + side * 9, ink, 4)
		draw_line(point - axis * 6, point + axis * 7, ink.lightened(0.2), 2)
		draw_line(point + axis * 7, point + side * 5, ink.lightened(0.2), 2)
		draw_line(point + axis * 7, point - side * 5, ink.lightened(0.2), 2)
		draw_circle(point - axis * 11, 3, Color("a8e5ad") if opened else Color("edb18d"))
