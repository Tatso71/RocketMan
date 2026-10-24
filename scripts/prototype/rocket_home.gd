extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")
const Explorer = preload("res://scripts/player/rocket_explorer.gd")
const InventoryModel = preload("res://scripts/systems/inventory.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const MATERIAL_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "bedrock": "Roccia compatta"}
const MATERIAL_COLORS := {"soil": Color("a45148"), "stone": Color("746b7a"), "copper": Color("bb8162"), "crystal": Color("55c5c6"), "bedrock": Color("454750")}
var site := DigSite.new()
var inventory := InventoryModel.new()
var player: CharacterBody2D
var camera: Camera2D
var terrain := Node2D.new()
var blocks: Dictionary = {}
var ladders: Dictionary = {}
var hatch: StaticBody2D
var hatch_open := false
var show_grid := true
var target_cell := Vector2i.ZERO
var mouse_aim := false
var mine_timer := 0.0
var message_time := 0.0
var ambient_time := 0.0
var resources_label: Label
var location_label: Label
var status_label: Label
var reset_dialog: ConfirmationDialog
var campaign: Node
var planet_def: Resource
var ship_state: RefCounted
var controls_locked := false
var standalone_slot := 0
var scanned: Dictionary = {}
var beam_time := 0.0
var beam_target := Vector2.ZERO
var beam_tool: Resource
var target_zoom := 1.1
var tool_buttons: Array[Button] = []
var metric_label: Label
var mouse_mining := false

func active_tool() -> Resource:
	var slot: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	return Tools.find(slots[slot])

func equip_tool(slot: int) -> bool:
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	if slot < 0 or slot >= Tools.SLOT_COUNT or str(slots[slot]).is_empty():
		return false
	if ship_state != null:
		ship_state.active_tool_slot = slot
	else:
		standalone_slot = slot
	_note(active_tool().display_name)
	return true

func configure(owner_campaign: Node, planet: Resource, ship: RefCounted) -> void:
	campaign = owner_campaign
	planet_def = planet
	ship_state = ship
	site = DigSite.new(planet.terrain_seed)
	inventory.materials = ship.resources

func controls_blocked() -> bool:
	return controls_locked or (is_instance_valid(reset_dialog) and reset_dialog.visible)

func _ready() -> void:
	_register_input()
	add_child(terrain)
	_build_terrain()
	_build_ship_collision()
	for y in range(-2, 4):
		ladders[Vector2i(0, y)] = true
	player = Explorer.new()
	player.world = self
	player.position = Vector2(-60, -80)
	player.z_index = 5
	add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(0, -150)
	camera.zoom = Vector2.ONE * 0.78
	add_child(camera)
	_build_hud()
	_refresh_hud()
	queue_redraw()

func _register_input() -> void:
	_action("climb_up", [KEY_W, KEY_UP], JOY_BUTTON_DPAD_UP)
	_action("climb_down", [KEY_S, KEY_DOWN], JOY_BUTTON_DPAD_DOWN)
	_action("mine", [KEY_F], JOY_BUTTON_RIGHT_SHOULDER)
	_action("place_ladder", [KEY_B], JOY_BUTTON_Y)
	_action("toggle_grid", [KEY_G], JOY_BUTTON_LEFT_STICK)
	_action("return_home", [KEY_HOME], JOY_BUTTON_BACK)
	_action("toggle_zoom", [KEY_C], JOY_BUTTON_RIGHT_STICK)
	_action("next_tool", [KEY_Q], JOY_BUTTON_LEFT_SHOULDER)
	for action in ["climb_up", "climb_down"]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = JOY_AXIS_LEFT_Y
		axis.axis_value = -1 if action == "climb_up" else 1
		if not InputMap.action_has_event(action, axis):
			InputMap.action_add_event(action, axis)

func _action(action: String, keys: Array, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for code in keys:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	var joy := InputEventJoypadButton.new()
	joy.button_index = button
	InputMap.action_add_event(action, joy)

func _body(rectangle: Rect2, parent: Node, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rectangle.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rectangle.size
	shape.shape = box
	shape.one_way_collision = one_way
	body.add_child(shape)
	parent.add_child(body)
	return body

func _build_terrain() -> void:
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			if not site.material(cell).is_empty():
				blocks[cell] = _body(Grid.rect(cell), terrain)
	_body(Rect2(Grid.to_world(Vector2i(site.LEFT, site.DEPTH)), Vector2((site.RIGHT - site.LEFT) * Grid.CELL_SIZE, Grid.CELL_SIZE)), self)
	_body(Rect2(Grid.to_world(Vector2i(site.LEFT - 1, -20)), Vector2(Grid.CELL_SIZE, (site.DEPTH + 20) * Grid.CELL_SIZE)), self)
	_body(Rect2(Grid.to_world(Vector2i(site.RIGHT, -20)), Vector2(Grid.CELL_SIZE, (site.DEPTH + 20) * Grid.CELL_SIZE)), self)

func _build_ship_collision() -> void:
	var half_width := Grid.ROCKET_HALF_WIDTH * Grid.CELL_SIZE
	var ceiling := Grid.metres(Grid.ROCKET_CEILING)
	var bottom := Grid.metres(Grid.ROCKET_FLOORS[-1])
	_body(Rect2(-half_width - 12, ceiling, 12, bottom - ceiling), self)
	_body(Rect2(half_width, ceiling, 12, bottom - ceiling), self)
	_body(Rect2(-half_width, ceiling - 4, half_width * 2, 8), self)
	for floor_cell in Grid.ROCKET_FLOORS.slice(0, 2):
		var floor_y := Grid.metres(floor_cell)
		_body(Rect2(-half_width, floor_y, 240, 8), self)
		_body(Rect2(120, floor_y, 40, 8), self)
	_body(Rect2(-half_width, -80, 120, 8), self)
	_body(Rect2(40, -80, 120, 8), self)
	hatch = _body(Rect2(-40, -80, 80, 8), self)

func on_ladder(feet: Vector2) -> bool:
	if absf(feet.x - 100) < 18 and feet.y >= -376 and feet.y <= -78:
		return true
	if not hatch_open and feet.y < -70:
		return false
	var torso := feet - Vector2(0, Grid.metres(0.8))
	for point in [torso, feet - Vector2(0, 4)]:
		var cell := Grid.to_cell(point)
		if ladders.has(cell) and absf(feet.x - Grid.center(cell).x) < 22:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or controls_blocked():
		return
	if event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		equip_tool(event.physical_keycode - KEY_1)
	if event.is_action_pressed("toggle_zoom"):
		target_zoom = 0.78 if target_zoom > 0.9 else 1.1
	if event.is_action_pressed("next_tool"):
		var current: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
		for offset in range(1, Tools.SLOT_COUNT + 1):
			if equip_tool((current + offset) % Tools.SLOT_COUNT):
				break
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = minf(1.5, target_zoom + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = maxf(0.78, target_zoom - 0.1)
	if event is InputEventMouseMotion:
		mouse_aim = true
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		mouse_aim = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_aim = true
		mouse_mining = event.pressed
		if event.pressed:
			target_cell = Grid.to_cell(get_global_mouse_position())
			_mine_target()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		if player.position.distance_to(Vector2(0, -80)) < Grid.metres(2.5):
			set_hatch(not hatch_open)
		else:
			_note("Botola fuori portata")
	if event.is_action_pressed("place_ladder"):
		place_ladder()
	if event.is_action_pressed("toggle_grid"):
		show_grid = not show_grid
	if event.is_action_pressed("return_home"):
		return_home()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	ambient_time += delta
	beam_time = maxf(0, beam_time - delta)
	mine_timer -= delta
	message_time -= delta
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_mining = false
	var desired := Vector2(player.position.x * 0.65, maxf(-150, player.position.y - 145))
	desired.x = clampf(desired.x, -450, 450)
	desired.y = minf(desired.y, 720)
	camera.position = camera.position.lerp(desired, 1.0 - exp(-delta * 4))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1.0 - exp(-delta * 5))
	if mouse_aim:
		target_cell = Grid.to_cell(get_global_mouse_position())
	else:
		var pads := Input.get_connected_joypads()
		var aim := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y)) if not pads.is_empty() else Vector2.ZERO
		if aim.length() < 0.3:
			aim = Vector2(player.facing, Input.get_axis("climb_up", "climb_down"))
		target_cell = Grid.to_cell(player.position - Vector2(0, 32) + aim.normalized() * 60)
	if (Input.is_action_pressed("mine") or mouse_mining) and mine_timer <= 0 and not controls_blocked():
		_mine_target()
	if player.position.y > Grid.metres(site.DEPTH + 1):
		return_home()
	_refresh_hud()
	queue_redraw()

func can_reach(cell: Vector2i) -> bool:
	var hand := player.position - Vector2(0, Grid.metres(0.8))
	if hand.distance_to(Grid.center(cell)) > Grid.metres(active_tool().reach_metres):
		return false
	# Cast against the same physics rectangles used by movement: no mining through walls.
	var query := PhysicsRayQueryParameters2D.create(hand, Grid.center(cell), 1, [player.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and blocks.get(cell) == hit.collider

func target_blocker(cell: Vector2i) -> String:
	if site.material(cell).is_empty():
		return "Spazio libero"
	if not can_reach(cell):
		return "Fuori portata o percorso ostruito"
	var tool := active_tool()
	if tool.mode == "mine" and site.material(cell) not in tool.materials:
		return "Materiale incompatibile: serve un altro strumento"
	if ship_state != null and ship_state.energy < tool.energy_per_pulse:
		return "Energia esaurita: ricarica in officina"
	if tool.mode == "mine" and ship_state != null and ship_state.cargo_used() >= ship_state.cargo_capacity():
		return "Stiva piena"
	return ""

func _mine_target() -> void:
	if mine_timer > 0:
		return
	mine_timer = 0.22
	var blocker := target_blocker(target_cell)
	if not blocker.is_empty():
		_note(blocker)
		return
	var tool := active_tool()
	beam_time = 0.24
	beam_target = Grid.center(target_cell)
	beam_tool = tool
	player.facing = 1 if beam_target.x >= player.position.x else -1
	if ship_state != null:
		ship_state.energy = maxf(0, ship_state.energy - tool.energy_per_pulse)
	if tool.mode == "scan":
		scanned[target_cell] = site.material(target_cell)
		_note("Analisi: %s / Resistenza %d" % [MATERIAL_NAMES[site.material(target_cell)], site.COST[site.material(target_cell)]])
		return
	var power: int = tool.power + (ship_state.drill_power() - 1 if ship_state != null else 0)
	var collected := site.mine(target_cell, power, "bedrock" in tool.materials)
	if not collected.is_empty():
		var body: StaticBody2D = blocks[target_cell]
		terrain.remove_child(body)
		body.queue_free()
		blocks.erase(target_cell)
		var resource_id: String = site.RESOURCE_YIELDS.get(collected, collected)
		inventory.add_material(resource_id, 1)
		scanned.erase(target_cell)
		_note("+1 " + MATERIAL_NAMES[resource_id])
	queue_redraw()

func set_hatch(open: bool) -> void:
	if not open and player.position.x > -52 and player.position.x < 52 and player.position.y > -80 and player.position.y < -8:
		_note("Passaggio occupato")
		return
	hatch_open = open
	hatch.get_child(0).set_deferred("disabled", open)
	_note("Botola aperta" if open else "Botola chiusa")

func place_ladder() -> bool:
	var cell := Grid.to_cell(player.position - Vector2(0, 20))
	if cell.y < 0 or not site.contains(cell) or not site.material(cell).is_empty() or ladders.has(cell):
		_note("Qui non puoi aggiungere una scala")
		return false
	if not inventory.consume_material("soil", 2):
		_note("Servono 2 unita di terra per una scala")
		return false
	ladders[cell] = true
	_note("Scala installata: 1 m")
	return true

func return_home() -> void:
	player.position = Vector2(-60, -80)
	player.velocity = Vector2.ZERO
	player.climbing = false
	_note("Rientro in officina")

func capture_state() -> Dictionary:
	var saved_ladders: Array = []
	for cell: Vector2i in ladders:
		saved_ladders.append([cell.x, cell.y])
	var readings: Array = []
	for cell: Vector2i in scanned:
		readings.append([cell.x, cell.y])
	return {"version": 1, "cell_metres": Grid.CELL_METRES, "terrain_seed": site.terrain_seed, "removed": site.snapshot(), "ladders": saved_ladders, "scanned": readings, "materials": inventory.materials.duplicate(), "player": [player.position.x, player.position.y], "hatch_open": hatch_open}

func save_run() -> bool:
	if campaign != null:
		return campaign.save_campaign()
	var ok: bool = SaveManager.write_rocket_save(capture_state())
	_note("Avamposto salvato" if ok else "Salvataggio non riuscito")
	return ok

func load_run() -> bool:
	if campaign != null:
		return campaign.load_campaign()
	var data: Dictionary = SaveManager.read_rocket_save()
	return restore_state(data)

func restore_state(data: Dictionary, restore_inventory: bool = true) -> bool:
	if data.get("version") != 1 or data.get("cell_metres") != Grid.CELL_METRES or data.get("terrain_seed", 0) != site.terrain_seed or not data.get("removed") is Array or not data.get("materials") is Dictionary or not data.get("ladders") is Array:
		_note("Nessun salvataggio compatibile")
		return false
	for child in terrain.get_children():
		terrain.remove_child(child)
		child.queue_free()
	blocks.clear()
	site.restore(data.removed)
	scanned.clear()
	if data.get("scanned", []) is Array:
		for entry in data.get("scanned", []):
			var cell = Grid.decode_cell(entry)
			if cell is Vector2i and not site.material(cell).is_empty():
				scanned[cell] = site.material(cell)
	# Rebuild only cell bodies; planet boundaries are persistent nodes.
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			if not site.material(cell).is_empty():
				blocks[cell] = _body(Grid.rect(cell), terrain)
	if restore_inventory:
		inventory.materials.clear()
		for kind: String in ["soil", "stone", "copper", "crystal"]:
			var amount = data.materials.get(kind, 0)
			if (amount is int or amount is float) and amount >= 0:
				inventory.add_material(kind, int(amount))
	ladders.clear()
	for entry in data.ladders:
		var cell = Grid.decode_cell(entry)
		if cell is Vector2i:
			if cell.x >= site.LEFT and cell.x < site.RIGHT and cell.y >= -2 and cell.y < site.DEPTH and site.material(cell).is_empty():
				ladders[cell] = true
	return_home()
	set_hatch(bool(data.get("hatch_open", false)))
	var position_data = data.get("player", [])
	if position_data is Array and position_data.size() == 2 and (position_data[0] is float or position_data[0] is int) and (position_data[1] is float or position_data[1] is int):
		var candidate := Vector2(float(position_data[0]), float(position_data[1]))
		if _safe_position(candidate):
			player.position = candidate
	_note("Avamposto caricato")
	return true

func _safe_position(point: Vector2) -> bool:
	if not point.is_finite() or point.x < Grid.metres(site.LEFT + 1) or point.x > Grid.metres(site.RIGHT - 1) or point.y < -320 or point.y > Grid.metres(site.DEPTH - 1):
		return false
	var shape := CapsuleShape2D.new()
	shape.radius = Grid.metres(Grid.PLAYER_WIDTH_METRES) * 0.5
	shape.height = Grid.metres(Grid.PLAYER_HEIGHT_METRES)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point - Vector2(0, shape.height * 0.5 + 1))
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func _note(message: String) -> void:
	message_time = 3.0
	if is_instance_valid(status_label):
		status_label.text = message

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := ColorRect.new()
	top.color = Color("182c36")
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	root.add_child(top)
	var title := Label.new()
	title.text = "ROCKETMAN  /  " + (planet_def.display_name.to_upper() if planet_def != null else "AVAMPOSTO 01")
	title.position = Vector2(22, 10)
	title.add_theme_font_size_override("font_size", 18)
	top.add_child(title)
	location_label = Label.new()
	location_label.position = Vector2(22, 34)
	location_label.add_theme_font_size_override("font_size", 12)
	location_label.modulate = Color("9ccece")
	top.add_child(location_label)
	resources_label = Label.new()
	resources_label.position = Vector2(405, 20)
	resources_label.add_theme_font_size_override("font_size", 15)
	top.add_child(resources_label)
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools.offset_left = -400 if campaign != null else -300
	tools.offset_right = -16
	tools.offset_top = 13
	tools.add_theme_constant_override("separation", 6)
	top.add_child(tools)
	if campaign != null:
		_button(tools, "Nave", "Stato, riparazioni e moduli", func(): campaign.open_ship_menu())
	_button(tools, "Salva", "Salva questo avamposto", save_run)
	_button(tools, "Carica", "Carica l'avamposto salvato", load_run)
	if campaign != null:
		_button(tools, "Decolla", "Rientra a bordo e chiudi la botola prima del decollo", func(): campaign.request_takeoff())
	else:
		_button(tools, "Nuovo", "Nuovo scavo (il salvataggio resta disponibile)", func(): reset_dialog.popup_centered())
	var bottom := ColorRect.new()
	bottom.color = Color("182c36")
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -38
	root.add_child(bottom)
	status_label = Label.new()
	status_label.position = Vector2(22, 8)
	status_label.add_theme_font_size_override("font_size", 14)
	bottom.add_child(status_label)
	metric_label = Label.new()
	metric_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	metric_label.offset_left = -300
	metric_label.offset_top = 8
	metric_label.add_theme_font_size_override("font_size", 13)
	metric_label.modulate = Color("9ccece")
	bottom.add_child(metric_label)
	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -282
	hotbar.offset_right = 282
	hotbar.offset_top = -90
	hotbar.offset_bottom = -46
	hotbar.add_theme_constant_override("separation", 6)
	root.add_child(hotbar)
	for slot in range(Tools.SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(135, 42)
		button.pressed.connect(equip_tool.bind(slot))
		hotbar.add_child(button)
		tool_buttons.append(button)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Nuovo avamposto"
	reset_dialog.dialog_text = "Abbandonare le modifiche non salvate? Il salvataggio esistente non verra cancellato."
	reset_dialog.confirmed.connect(func(): get_tree().reload_current_scene())
	root.add_child(reset_dialog)

func _button(parent: Node, text: String, tip: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(86, 32)
	button.pressed.connect(callback)
	parent.add_child(button)

func _refresh_hud() -> void:
	resources_label.text = "Terra %d   Pietra %d   Rame %d   Cristalli %d" % [inventory.get_amount("soil"), inventory.get_amount("stone"), inventory.get_amount("copper"), inventory.get_amount("crystal")]
	var depth := maxf(0, player.position.y / Grid.PIXELS_PER_METRE)
	var room := "Sottosuolo" if player.position.y > 0 else ("Officina" if player.position.y > -200 else ("Zona abitativa" if player.position.y > -320 else "Cabina"))
	location_label.text = "%s  |  Profondita %.1f m  |  Botola %s" % [room, depth, "aperta" if hatch_open else "chiusa"]
	var tool := active_tool()
	metric_label.text = "1 CELLA = 1 m  |  %s / %.1f m" % [tool.display_name, tool.reach_metres]
	var slots: Array = ship_state.tool_slots if ship_state != null else ["pulse", "scanner", "", ""]
	var active: int = ship_state.active_tool_slot if ship_state != null else standalone_slot
	for slot in range(tool_buttons.size()):
		var definition := Tools.find(slots[slot])
		tool_buttons[slot].text = "%d  %s" % [slot + 1, definition.display_name if definition != null else "Vuoto"]
		tool_buttons[slot].disabled = definition == null
		tool_buttons[slot].modulate = definition.beam_color if slot == active else Color("ccd9d8")
		tool_buttons[slot].tooltip_text = "%.1f m / %.2f kWh per impulso" % [definition.reach_metres, definition.energy_per_pulse] if definition != null else "Nessuno strumento assegnato"
	if message_time <= 0:
		var blocker := target_blocker(target_cell)
		status_label.text = blocker if not blocker.is_empty() else ("%s / [%d, %d] m" % [MATERIAL_NAMES.get(scanned.get(target_cell, ""), "Blocco non analizzato"), target_cell.x, target_cell.y])

func _draw() -> void:
	_draw_landscape()
	_draw_terrain()
	_draw_ship()
	if show_grid:
		_draw_metric_overlay()
		if is_instance_valid(player):
			draw_arc(player.position - Vector2(0, 32), Grid.metres(active_tool().reach_metres), 0, TAU, 72, Color(active_tool().beam_color, 0.22), 1, true)
	for cell: Vector2i in ladders:
		_ladder(Grid.to_world(cell) + Vector2(20, 0), 40)
	if site.contains(target_cell) and not site.material(target_cell).is_empty():
		var available := target_blocker(target_cell).is_empty() if is_instance_valid(player) else false
		draw_rect(Grid.rect(target_cell).grow(-1), active_tool().beam_color if available else Color("ff6265"), false, 2.5)
		var damage := float(site.damage.get(target_cell, 0))
		if damage > 0:
			var origin := Grid.to_world(target_cell)
			draw_line(origin + Vector2(8, 4), origin + Vector2(22, 22), Color("2b252f"), 2)
			draw_line(origin + Vector2(22, 22), origin + Vector2(14, 36), Color("2b252f"), 2)
	if beam_time > 0 and beam_tool != null:
		_draw_beam()

func _draw_landscape() -> void:
	draw_rect(Rect2(-4000, -3000, 8000, 6000), planet_def.surface_color if planet_def != null else Color("75bac4"))
	draw_circle(Vector2(570, -410), 190, Color("acd9cf"))
	draw_arc(Vector2(570, -410), 230, -0.2, 2.9, 50, Color("d2e4d3"), 8)
	for index in range(-8, 9):
		var x := index * 170.0
		var height := 90 + posmod(index * 73, 190)
		_polygon([Vector2(x - 80, 30), Vector2(x - 65, -height), Vector2(x - 20, -height - 20), Vector2(x + 25, -height + 30), Vector2(x + 70, 30)], Color("b18d9a"))
		_polygon([Vector2(x - 20, -height - 20), Vector2(x + 25, -height + 30), Vector2(x + 70, 30), Vector2(x - 5, 30)], Color("9e8497"))
	draw_rect(Rect2(-3000, -6, 6000, 16), Color("d98b72"))

func _draw_terrain() -> void:
	var darkness := Color("101721")
	draw_rect(Rect2(Grid.to_world(Vector2i(site.LEFT, 0)), Grid.to_world(Vector2i(site.RIGHT - site.LEFT, site.DEPTH))), darkness)
	for y in range(site.DEPTH):
		for x in range(site.LEFT, site.RIGHT):
			var cell := Vector2i(x, y)
			var rect := Grid.rect(cell)
			var kind := site.material(cell)
			var light := _illumination(Grid.center(cell))
			if kind.is_empty():
				draw_rect(rect, darkness.lerp(Color("41444c"), light * 0.85))
				if show_grid and light > 0.15:
					draw_rect(rect, Color(0.65, 0.7, 0.73, light * 0.18), false, 1)
				continue
			var tint: Color = MATERIAL_COLORS[kind]
			if planet_def != null and kind == "soil":
				tint = planet_def.rock_color
			var variation := float(posmod(x * 13 + y * 23, 9)) * 0.012
			tint = tint.lightened(variation)
			tint = darkness.lerp(tint, light)
			draw_rect(rect, tint)
			var p := rect.position
			if light > 0.12:
				_polygon([p, p + Vector2(40, 0), p + Vector2(29, 13), p + Vector2(7, 8)], tint.lightened(light * 0.1))
				_polygon([p + Vector2(40, 0), p + Vector2(40, 40), p + Vector2(27, 34), p + Vector2(29, 13)], tint.darkened(light * 0.13))
			if light > 0.3 and (kind == "copper" or kind == "crystal"):
				var ore := Color("8ae8df") if kind == "crystal" else Color("e9b66d")
				_polygon([p + Vector2(9, 29), p + Vector2(13, 12), p + Vector2(22, 7), p + Vector2(27, 24), p + Vector2(20, 32)], ore)
				_polygon([p + Vector2(22, 7), p + Vector2(27, 24), p + Vector2(20, 32), p + Vector2(18, 17)], ore.darkened(0.2))
			if show_grid and light > 0.2:
				draw_rect(rect, Color(0.14, 0.12, 0.17, 0.3), false, 1)
	_lamp(Vector2(-160, 86))
	_crate(Vector2(-180, 132), Vector2(32, 28))

func _illumination(point: Vector2) -> float:
	var hand := player.position - Vector2(0, 32) if is_instance_valid(player) else Vector2(0, -100)
	var reach := Grid.metres(active_tool().reach_metres)
	var distance := point.distance_to(hand)
	var light := 1.0 - smoothstep(reach * 0.65, reach * 1.4, distance)
	var lamp := 1.0 - smoothstep(35, 100, point.distance_to(Vector2(-160, 86)))
	return maxf(light, lamp * 0.65)

func _draw_beam() -> void:
	var start := player.position + Vector2(player.facing * 46, -34)
	var direction := (beam_target - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for index in range(25):
		var t := index / 24.0
		var wave := sin(t * 24 + ambient_time * 55) * 3 * sin(t * PI)
		points.append(start.lerp(beam_target, t) + normal * wave)
	var color: Color = beam_tool.beam_color
	draw_polyline(points, Color(color, 0.18), beam_tool.beam_width + 8, true)
	draw_polyline(points, color, beam_tool.beam_width, true)
	draw_polyline(points, Color("f4fff2"), maxf(1, beam_tool.beam_width * 0.3), true)
	draw_circle(beam_target, 4 + beam_tool.beam_width, Color(color, 0.6))

func _draw_ship() -> void:
	# All structural boundaries are whole-metre coordinates; bevels are visual only.
	for side in [-1, 1]:
		var x: float = side * 200.0
		draw_line(Vector2(side * 152, -100), Vector2(side * 216, -8), Color("4c5360"), 15)
		draw_line(Vector2(side * 152, -100), Vector2(side * 216, -8), Color("e8b553"), 9)
		draw_rect(Rect2(side * 216 - 28, -8, 56, 8), Color("46525c"))
		_polygon([Vector2(x - 34, -110), Vector2(x - 34, -260), Vector2(x - 20, -284), Vector2(x + 20, -284), Vector2(x + 34, -260), Vector2(x + 34, -110)], Color("d6e0d7"))
		draw_rect(Rect2(x - 34, -132, 68, 22), Color("db9f3f"))
		draw_rect(Rect2(x - 22, -110, 44, 18), Color("394854"))
		draw_rect(Rect2(x - 7, -248, 14, 82), Color("254751"))
		draw_rect(Rect2(x - 3, -244, 6, 74), Color("76e2d9"))
		_polygon([Vector2(x + side * 34, -215), Vector2(x + side * 65, -95), Vector2(x + side * 34, -112)], Color("e3ad4c"))
	_polygon([Vector2(-174, -80), Vector2(-174, -429), Vector2(-138, -456), Vector2(138, -456), Vector2(174, -429), Vector2(174, -80)], Color("e1e4d8"))
	_polygon([Vector2(-138, -456), Vector2(0, -520), Vector2(138, -456)], Color("e8ad42"))
	_polygon([Vector2(0, -520), Vector2(48, -456), Vector2(138, -456)], Color("f7ce69"))
	_polygon([Vector2(-138, -456), Vector2(0, -520), Vector2(-45, -456)], Color("c78b35"))
	for floor_cell in Grid.ROCKET_FLOORS:
		var floor_y := Grid.metres(floor_cell)
		draw_rect(Rect2(-160, floor_y - 112, 320, 112), Color("64585a"))
		draw_rect(Rect2(-150, floor_y - 103, 300, 95), Color("8d7a6a"))
		draw_rect(Rect2(-148, floor_y - 100, 296, 89), Color("ab9479"))
		for seam_x in range(-120, 151, 40):
			draw_line(Vector2(seam_x, floor_y - 98), Vector2(seam_x, floor_y - 13), Color(0.3, 0.27, 0.27, 0.15), 1)
		_lamp(Vector2(-25, floor_y - 106))
		var span := 120 if floor_y == -80 else 240
		draw_rect(Rect2(-160, floor_y, span, 8), Color("49525a"))
		draw_line(Vector2(-160, floor_y), Vector2(-160 + span, floor_y), Color("dce5dc"), 3)
		draw_rect(Rect2(40 if floor_y == -80 else 120, floor_y, 120 if floor_y == -80 else 40, 8), Color("49525a"))
		draw_rect(Rect2(-174, floor_y - 12, 14, 20), Color("e7ae47"))
		draw_rect(Rect2(160, floor_y - 12, 14, 20), Color("e7ae47"))
	_ladder(Vector2(100, -440), 360)
	_draw_cockpit()
	_draw_bedroom()
	_draw_workshop()
	for x in [-167, 167]:
		for y in range(-380, -80, 40):
			draw_circle(Vector2(x, y), 2, Color("81948f"))
	draw_rect(Rect2(-47, -72, 94, 72), Color("4b5961"), false, 7)
	if not hatch_open:
		draw_rect(Rect2(-40, -80, 80, 8), Color("e8b553"))
		draw_line(Vector2(-12, -76), Vector2(12, -76), Color("54636a"), 2)
	draw_circle(Vector2(-52, -94), 4, Color("7cddd1") if hatch_open else Color("f1bd5a"))

func _draw_cockpit() -> void:
	draw_circle(Vector2(-45, -370), 33, Color("e7b35a"))
	draw_circle(Vector2(-45, -370), 27, Color("76bdc7"))
	draw_arc(Vector2(-45, -370), 24, 3.4, 5.6, 20, Color("c7e7dc"), 3)
	draw_rect(Rect2(-125, -349, 173, 12), Color("3f5059"))
	for x in [-115, -68, -21]:
		draw_rect(Rect2(x, -345, 32, 12), Color("264957"))
		draw_rect(Rect2(x + 3, -343, 26, 6), Color("78d6cf"))
	draw_line(Vector2(-114, -337), Vector2(-114, -320), Color("49525a"), 5)
	draw_rect(Rect2(-25, -354, 24, 22), Color("405664"))
	draw_rect(Rect2(-31, -332, 36, 7), Color("405664"))
	draw_line(Vector2(-13, -325), Vector2(-13, -320), Color("c4cabd"), 4)

func _draw_bedroom() -> void:
	draw_rect(Rect2(-138, -226, 117, 26), Color("49525b"))
	draw_rect(Rect2(-138, -235, 117, 15), Color("e3e4cf"))
	draw_rect(Rect2(-102, -235, 81, 19), Color("dba751"))
	draw_rect(Rect2(-134, -236, 30, 12), Color("f4efda"))
	draw_rect(Rect2(20, -244, 42, 44), Color("4a6770"))
	for y in [-239, -220]:
		draw_rect(Rect2(24, y, 34, 14), Color("809d9c"))
		draw_line(Vector2(36, y + 5), Vector2(48, y + 5), Color("d8dfc8"), 2)
	draw_rect(Rect2(-137, -284, 62, 5), Color("52636a"))
	for x in [-131, -112, -94]:
		draw_rect(Rect2(x, -299, 11, 15), Color("90b6a3"))
	var bob := sin(ambient_time * 2) * 1.5
	draw_circle(Vector2(-54, -249 + bob), 12, Color("8bc680"))
	draw_circle(Vector2(-62, -261 + bob), 5, Color("8bc680"))
	draw_circle(Vector2(-46, -261 + bob), 5, Color("8bc680"))
	draw_circle(Vector2(-59, -251 + bob), 2, Color("283e43"))
	draw_circle(Vector2(-49, -251 + bob), 2, Color("283e43"))

func _draw_workshop() -> void:
	draw_rect(Rect2(-142, -158, 37, 78), Color("3b6370"))
	draw_rect(Rect2(-136, -150, 25, 56), Color("67d5cb"))
	for y in [-138, -123, -108]:
		draw_line(Vector2(-137, y), Vector2(-110, y), Color("c0ebe0"), 2)
	draw_rect(Rect2(-97, -127, 112, 8), Color("d7ad5f"))
	draw_rect(Rect2(-92, -119, 8, 39), Color("52616a"))
	draw_rect(Rect2(0, -119, 8, 39), Color("52616a"))
	draw_rect(Rect2(-92, -181, 101, 45), Color("736e67"))
	for x in [-75, -45, -15]:
		draw_line(Vector2(x, -172), Vector2(x, -148), Color("cad6cc"), 4)
		draw_circle(Vector2(x, -171), 5, Color("cad6cc"), false, 2)
	_crate(Vector2(49, -112), Vector2(26, 32))

func _ladder(top: Vector2, height: float) -> void:
	draw_line(top + Vector2(-14, 0), top + Vector2(-14, height), Color("dfb15a"), 3)
	draw_line(top + Vector2(14, 0), top + Vector2(14, height), Color("dfb15a"), 3)
	for y in range(8, int(height), 16):
		draw_line(top + Vector2(-14, y), top + Vector2(14, y), Color("e4c78b"), 3)

func _lamp(point: Vector2) -> void:
	draw_circle(point + Vector2(0, 8), 28, Color(1, 0.81, 0.45, 0.045))
	draw_circle(point + Vector2(0, 8), 18, Color(1, 0.81, 0.45, 0.08))
	draw_rect(Rect2(point - Vector2(13, 0), Vector2(26, 5)), Color("4c5960"))
	draw_line(point + Vector2(-8, 5), point + Vector2(8, 5), Color("ffdf95"), 4)

func _crate(point: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(point, size), Color("687a7b"))
	draw_rect(Rect2(point, size), Color("adb6a5"), false, 2)
	draw_rect(Rect2(point + Vector2(size.x * 0.4, 0), Vector2(5, size.y)), Color("d5b775"))

func _polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw_metric_overlay() -> void:
	for y in range(Grid.ROCKET_CEILING, Grid.ROCKET_FLOORS[-1]):
		for x in range(-Grid.ROCKET_HALF_WIDTH, Grid.ROCKET_HALF_WIDTH):
			draw_rect(Grid.rect(Vector2i(x, y)), Color(0.85, 0.96, 0.91, 0.09), false, 1)
	var ink := Color("d6eee5")
	var top := Grid.metres(Grid.ROCKET_CEILING)
	var bottom := top + Grid.metres(Grid.ROOM_HEIGHT)
	var ruler_x := Grid.metres(-7.5)
	draw_line(Vector2(ruler_x, top), Vector2(ruler_x, bottom), ink, 1)
	for y in [top, bottom]:
		draw_line(Vector2(ruler_x - 5, y), Vector2(ruler_x + 5, y), ink, 1)
	draw_string(ThemeDB.fallback_font, Vector2(ruler_x - 36, (top + bottom) * 0.5 + 5), "3 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
