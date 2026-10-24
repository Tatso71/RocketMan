extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const InventoryUI = preload("res://scripts/ui/field_inventory_ui.gd")
const ITEM_NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "lamp_kit": "Luce portatile"}
var world: Node2D
var buildings := Buildings.new()
var build_mode := false
var blueprint := "laboratory"
var origin := Vector2i.ZERO
var build_picker: OptionButton
var build_status: Label
var cargo_window: Window
var cargo_ui: CanvasLayer
var cost_labels: Array[Label] = []
var menu: HBoxContainer
var light_sources: Array = []
var stick_timer := 0.0

func toggle_build() -> void:
	build_mode = not build_mode
	world.mouse_mining = false
	if build_mode:
		origin = Grid.to_cell(world.player.position) - Vector2i(4, 3)

func _ready() -> void:
	_build_interface()

func signal_range() -> float:
	return world.ship_state.drone_range_metres() if world.ship_state != null else 15.0

func operational(building: Dictionary) -> bool:
	if building.id != "laboratory" or buildings.world_rect(building).get_center().distance_to(Vector2(0, -80)) > Grid.metres(signal_range()):
		return false
	if world.ship_state != null and world.ship_state.energy <= 0:
		return false
	var rect := buildings.footprint(building.id, building.origin)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if float(world.environment.water.get(cell, 0)) > 0.05 or float(world.environment.gas.get(cell, 0)) > 0.03:
				return false
	return true

func has_lab() -> bool:
	return buildings.labs().any(func(building: Dictionary): return operational(building))

func nearby_lab() -> Dictionary:
	var point: Vector2 = world.player.position - Vector2(0, 32)
	for building: Dictionary in buildings.labs():
		var rect := buildings.world_rect(building)
		if operational(building) and point.distance_to(point.clamp(rect.position, rect.end)) <= Grid.metres(1.5):
			return building
	return {}

func payment_cache() -> Dictionary:
	var lab := nearby_lab()
	return lab.stock if not lab.is_empty() else {}

func source_stock() -> Dictionary:
	if world.aboard_workshop():
		return world.ship_state.resources if world.ship_state != null else world.local_store
	return payment_cache()

func source_available() -> bool:
	return world.aboard_workshop() or not nearby_lab().is_empty()

func placement_blocker(id: String, cell: Vector2i) -> String:
	var reason := buildings.blocker(id, cell, world.site, world.environment)
	if not reason.is_empty():
		return reason
	var rect := Rect2(Grid.to_world(cell), Grid.to_world(buildings.size_for(id)))
	var body := Rect2(world.player.position - Vector2(12, 64), Vector2(24, 64))
	if id != "laboratory" and rect.intersects(body):
		return "Spostati fuori dall'ingombro del progetto"
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	if torso.distance_to(rect.get_center()) > Grid.metres(3):
		return "Cantiere fuori portata"
	if not world.drone_help_available():
		return "Serve il drone collegato vicino al cantiere"
	if id == "laboratory" and rect.get_center().distance_to(Vector2(0, -80)) > Grid.metres(signal_range()):
		return "Laboratorio fuori dal segnale della nave"
	if id == "lamp" and not has_lab():
		return "Costruisci prima un laboratorio operativo"
	if id == "lamp" and not buildings.labs().any(func(lab: Dictionary): return operational(lab) and buildings.world_rect(lab).get_center().distance_to(rect.get_center()) <= Grid.metres(8)):
		return "Luce fuori dal collegamento del laboratorio (8 m)"
	var cost: Dictionary = Buildings.LAB_COST if id == "laboratory" else {"lamp_kit": 1}
	if not world.field_cargo.can_pay(cost, world.drone_help_available(), payment_cache()):
		var missing: Array[String] = []
		for item: String in cost:
			var amount: int = int(cost[item]) - world.field_cargo.available(item, world.drone_help_available(), payment_cache())
			if amount > 0:
				missing.append("%d %s" % [amount, ITEM_NAMES[item].to_lower()])
		return "Mancano nel carico: " + ", ".join(missing)
	return ""

func place(id: String, cell: Vector2i) -> bool:
	var reason := placement_blocker(id, cell)
	if not reason.is_empty():
		world._note(reason)
		return false
	var cost: Dictionary = Buildings.LAB_COST if id == "laboratory" else {"lamp_kit": 1}
	if not world.field_cargo.pay(cost, world.drone_help_available(), payment_cache()):
		return false
	buildings.install(id, cell)
	if id == "laboratory" and world.ship_state != null:
		world.ship_state.lab_research_unlocked = true
	world._note("Laboratorio installato: ricerca e luci disponibili" if id == "laboratory" else "Luce installata")
	world.guide_event("lab_built" if id == "laboratory" else "lamp_placed")
	build_mode = false
	_refresh_light_sources()
	queue_redraw()
	return true

func craft_lamp() -> bool:
	var lab := nearby_lab()
	if lab.is_empty():
		world._note("Raggiungi un laboratorio operativo")
		return false
	var with_drone: bool = world.drone_help_available()
	var trial := Cargo.new()
	trial.drone_capacity = world.field_cargo.drone_capacity
	trial.restore(world.field_cargo.snapshot())
	var stock: Dictionary = lab.stock.duplicate()
	if not trial.pay(Buildings.LAMP_RECIPE, with_drone, stock) or not trial.collect("lamp_kit", 1, with_drone):
		world._note("Servono 1 terra, 1 rame e spazio nel carico")
		return false
	world.field_cargo.pay(Buildings.LAMP_RECIPE, with_drone, lab.stock)
	world.field_cargo.collect("lamp_kit", 1, with_drone)
	world._note("Luce portatile fabbricata")
	world.guide_event("lamp_crafted")
	return true

func light_at(point: Vector2) -> float:
	var light := 0.0
	for source: Dictionary in light_sources:
		light = maxf(light, 1.0 - smoothstep(source.inner, source.outer, point.distance_to(source.point)))
	return light

func _refresh_light_sources() -> void:
	light_sources.clear()
	var lab_points: Array[Vector2] = []
	for lab: Dictionary in buildings.labs():
		if operational(lab):
			var point := buildings.world_rect(lab).get_center()
			lab_points.append(point)
			light_sources.append({"point": point, "inner": Grid.metres(1.5), "outer": Grid.metres(4)})
	for building: Dictionary in buildings.structures:
		if building.id == "lamp":
			var point := Grid.center(building.origin)
			if lab_points.any(func(lab: Vector2): return lab.distance_to(point) <= Grid.metres(8)):
				light_sources.append({"point": point, "inner": Grid.metres(1.2), "outer": Grid.metres(3.5)})

func mining_blocker(cell: Vector2i) -> String:
	for building: Dictionary in buildings.structures:
		var rect := buildings.footprint(building.id, building.origin)
		if cell.y == rect.end.y and cell.x >= rect.position.x and cell.x < rect.end.x:
			return "Pavimento portante della struttura: scava altrove"
	return ""

func _process(delta: float) -> void:
	_refresh_light_sources()
	if build_mode:
		if world.mouse_aim:
			origin = Grid.to_cell(world.get_global_mouse_position())
		else:
			stick_timer -= delta
			var pads := Input.get_connected_joypads()
			if not pads.is_empty() and stick_timer <= 0:
				var aim := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
				if aim.length() > 0.5:
					origin += Vector2i(signi(int(aim.x * 10)), signi(int(aim.y * 10)))
					stick_timer = 0.18
		var reason := placement_blocker(blueprint, origin)
		build_status.text = "Pronto per costruire" if reason.is_empty() else reason
		build_status.modulate = Color("a9ead5") if reason.is_empty() else Color("ef9892")
	else:
		build_status.text = "Laboratorio operativo" if has_lab() else "Obiettivo: installare un laboratorio"
	var cost: Dictionary = Buildings.LAB_COST if blueprint == "laboratory" else {"lamp_kit": 1}
	for index in range(cost_labels.size()):
		cost_labels[index].visible = index < cost.size()
		if index < cost.size():
			var id: String = cost.keys()[index]
			var available: int = world.field_cargo.available(id, world.drone_help_available(), payment_cache())
			cost_labels[index].text = "%s %d / %d" % [ITEM_NAMES[id], available, cost[id]]
			cost_labels[index].modulate = Color("a7e5b4") if available >= int(cost[id]) else Color("ffb18e")
	queue_redraw()

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_build") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and Input.is_joy_button_pressed(event.device, JOY_BUTTON_LEFT_SHOULDER)):
		toggle_build()
		return true
	if build_mode and (event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)):
		build_mode = false
		return true
	if build_mode and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			build_mode = false
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			place(blueprint, Grid.to_cell(world.get_global_mouse_position()))
			return true
	if build_mode and event.is_action_pressed("interact"):
		place(blueprint, origin)
		return true
	return false

func open_cargo() -> void:
	cargo_ui.open_inventory()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 132)
	panel.custom_minimum_size.x = 310
	panel.add_theme_stylebox_override("panel", InventoryUI.panel_style())
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(InventoryUI.label("CANTIERE", 13, Color("a7b6b8")))
	menu = HBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	column.add_child(menu)
	build_picker = OptionButton.new()
	build_picker.add_item("Laboratorio 4 x 3 m")
	build_picker.add_item("Luce 1 x 1 m")
	build_picker.item_selected.connect(func(index: int): blueprint = "laboratory" if index == 0 else "lamp")
	menu.add_child(build_picker)
	var build := Button.new()
	build.text = "Costruisci"
	build.tooltip_text = "Anteprima sulla griglia; il personaggio puo restare dentro il laboratorio"
	build.pressed.connect(toggle_build)
	menu.add_child(build)
	build_status = Label.new()
	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 22)
	column.add_child(costs)
	for index in range(2):
		var cost := InventoryUI.label("", 14)
		costs.add_child(cost)
		cost_labels.append(cost)
	build_status.custom_minimum_size = Vector2(282, 42)
	build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_status.add_theme_font_size_override("font_size", 14)
	column.add_child(build_status)
	cargo_ui = InventoryUI.new()
	cargo_ui.world = world
	add_child(cargo_ui)
	cargo_window = cargo_ui.window

func _draw() -> void:
	for building: Dictionary in buildings.structures:
		var rect := buildings.world_rect(building)
		if building.id == "laboratory":
			var color := Color("8bd9c3") if operational(building) else Color("c3936d")
			draw_rect(rect.grow(-4), Color(0.11, 0.21, 0.24, 0.6))
			draw_rect(rect.grow(-4), color, false, 3)
			draw_line(rect.position + Vector2(6, 6), rect.position + Vector2(rect.size.x - 6, 6), Color("e2c27d"), 6)
			var base := rect.position + Vector2(20, rect.size.y - 38)
			draw_rect(Rect2(base, Vector2(110, 32)), Color("577a80"))
			draw_rect(Rect2(base + Vector2(45, -24), Vector2(38, 23)), Color("263e4c"))
			draw_rect(Rect2(base + Vector2(49, -20), Vector2(30, 14)), color)
			for x in [5, 22, 38]:
				draw_rect(Rect2(base + Vector2(x, -14), Vector2(9, 13)), Color("dcb65b"))
		else:
			var center := rect.get_center()
			draw_line(center + Vector2(0, 15), center - Vector2(0, 12), Color("7b9499"), 4)
			draw_rect(Rect2(center - Vector2(13, 16), Vector2(26, 8)), Color("f6d683") )
	if build_mode:
		var rect := Rect2(Grid.to_world(origin), Grid.to_world(buildings.size_for(blueprint)))
		var valid := placement_blocker(blueprint, origin).is_empty()
		var color := Color("87e4c0") if valid else Color("f16d72")
		draw_rect(rect, Color(color, 0.14))
		draw_rect(rect, color, false, 2)
