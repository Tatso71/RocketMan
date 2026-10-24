extends CanvasLayer

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
var world: Node2D
var panel: PanelContainer
var heading: Label
var counter: Label
var title: Label
var detail: Label
var stock: Label
var progress: ProgressBar
var action: Button

func _ready() -> void:
	layer = 1
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.position = Vector2(16, 184)
	panel.custom_minimum_size.x = 304
	panel.size.x = 304
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var icon := TextureRect.new()
	icon.texture = UI.ICONS[1]
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	heading = UI.label("ROBBIE / OCRA", 14, Color("8edce1"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	counter = UI.label("", 14, Color("b4c5c6"))
	header.add_child(counter)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 5
	progress.show_percentage = false
	column.add_child(progress)
	title = UI.label("", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 276
	column.add_child(title)
	detail = UI.label("", 16, Color("b4c5c6"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	stock = UI.label("", 16, Color("f0d281"))
	stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(stock)
	action = UI.button(column, "Riascolta Robbie", _activate)
	action.custom_minimum_size.y = 40
	refresh()

func refresh() -> void:
	panel.visible = world.is_ocra() and not world.guide_state.ocra.definition.is_empty()
	if not panel.visible:
		return
	var tutorial: RefCounted = world.guide_state.ocra
	var step: Dictionary = tutorial.current()
	var total: int = tutorial.definition.steps.size()
	counter.text = "%d / %d" % [mini(tutorial.index() + 1, total), total]
	progress.max_value = total
	progress.value = tutorial.index()
	stock.text = ""
	if tutorial.complete():
		title.text = "Primo laboratorio attivo"
		title.modulate = Color("a7e5b4")
		detail.text = "Hai una base sotterranea. Ora puoi depositare, riparare e costruire le luci."
		action.text = "Apri laboratorio" if not world.outpost.nearby_lab().is_empty() else "Riascolta Robbie"
		return
	if step.is_empty():
		return
	title.text = step.title_it
	title.modulate = Color.WHITE
	detail.text = step.detail_it
	if step.complete_when.has("counter"):
		stock.text = "%d / %d celle scavate" % [mini(tutorial.counters.get(step.complete_when.counter, 0), int(step.complete_when.at_least)), step.complete_when.at_least]
	if step.action == "fabricate_lab":
		var cargo: RefCounted = world.field_cargo
		var source: Dictionary = world.outpost.source_stock() if world.aboard_workshop() else {}
		var cost: Dictionary = world.outpost.lab_definition().get("cost", {})
		stock.text = "Pietra %d / %d   Rame %d / %d" % [cargo.available("stone", world.drone_help_available(), source), cost.get("stone", 0), cargo.available("copper", world.drone_help_available(), source), cost.get("copper", 0)]
		action.text = "Apri officina" if world.aboard_workshop() else "Riascolta Robbie"
	elif step.action == "place_lab":
		var building: Dictionary = world.outpost.buildings.structures.filter(func(item: Dictionary): return item.id == "laboratory").front() if world.outpost.buildings.structures.any(func(item: Dictionary): return item.id == "laboratory") else {}
		if not building.is_empty():
			stock.text = "Montaggio %.0f%%" % (float(building.progress) * 100) if building.state == "building" else "Cantiere precedente / trasferisci le materie mancanti"
		else:
			stock.text = "Cubo nel carico: %d" % world.outpost.lab_cube_count()
		action.text = "Posiziona cubo" if building.is_empty() and world.outpost.lab_cube_count() > 0 else "Riascolta Robbie"
	else:
		action.text = "Apri inventario" if step.action == "inventory" else "Riascolta Robbie"

func _activate() -> void:
	if world.controls_blocked():
		return
	var tutorial: RefCounted = world.guide_state.ocra
	var step: Dictionary = tutorial.current()
	if tutorial.complete() and not world.outpost.nearby_lab().is_empty():
		world.outpost.open_station(world.outpost.nearby_station(), world.player.get_global_transform_with_canvas() * Vector2(0, -40))
	elif step.get("action") == "fabricate_lab" and world.aboard_workshop():
		world.outpost.construction.open_picker(world.Grid.to_cell(world.player.position), Vector2(330, 180), true)
	elif step.get("action") == "place_lab" and world.outpost.lab_cube_count() > 0:
		world.outpost.construction.open_picker(world.Grid.to_cell(world.player.position), Vector2(330, 180))
		world.outpost.construction._choose(0)
	elif step.get("action") == "inventory":
		world.outpost.open_cargo()
	else:
		world.guide.request_help()

func _process(_delta: float) -> void:
	refresh()
