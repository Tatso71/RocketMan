extends CanvasLayer

const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "lamp_kit": "Luce portatile", "lab_cube": "Cubo laboratorio"}
const COLORS := {"soil": Color("cf8272"), "stone": Color("adb0bb"), "copper": Color("edbf75"), "crystal": Color("7be1da"), "lamp_kit": Color("fff3b2"), "lab_cube": Color("a7e5b4")}
const ICONS := [preload("res://assets/ui/backpack.svg"), preload("res://assets/ui/drone.svg"), preload("res://assets/ui/storage.svg")]
var world: Node2D
var window: Window
var compact: PanelContainer
var compact_counts: Array[Label] = []
var compact_titles: Array[Label] = []
var compact_bars: Array[ProgressBar] = []
var compact_link: Label
var counts: Array = []
var capacities: Array[Label] = []
var bars: Array[ProgressBar] = []
var subtitles: Array[Label] = []
var picker: OptionButton
var amount: SpinBox
var withdraw_button: Button
var deposit_button: Button
var prepare_button: Button
var craft_button: Button
var feedback: Label
var availability: Label
var cost_labels: Array[Label] = []
var preparation_status: Label
var compact_rows: Dictionary = {}

func _ready() -> void:
	_build_compact()
	_build_window()
	refresh()

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("222b2e")
	style.border_color = Color("526266")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func label(text: String, font_size: int = 15, color: Color = Color("e5efeb")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func button(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 36
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _meter(parent: Node, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("121a1d")
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _icon(parent: Node, texture: Texture2D, pixels: int = 28) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)

func _build_compact() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	compact = PanelContainer.new()
	compact.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	compact.offset_left = -296
	compact.offset_right = -16
	compact.offset_top = 76
	compact.add_theme_stylebox_override("panel", panel_style())
	root.add_child(compact)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	compact.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := label("CARICO", 13, Color("a7b6b8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var open := button(header, ">", open_inventory)
	open.custom_minimum_size = Vector2(28, 24)
	open.tooltip_text = "Apri inventario e depositi"
	var holds := HBoxContainer.new()
	holds.add_theme_constant_override("separation", 18)
	column.add_child(holds)
	for index in range(2):
		var hold := VBoxContainer.new()
		hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holds.add_child(hold)
		var row := HBoxContainer.new()
		hold.add_child(row)
		_icon(row, ICONS[index], 22)
		var title_label := label("Zaino" if index == 0 else "Robbie", 16)
		row.add_child(title_label)
		var count := label("", 14)
		hold.add_child(count)
		compact_titles.append(count)
		compact_bars.append(_meter(hold, Color("a7e5b4") if index == 0 else Color("8edce1")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	grid.add_child(label("", 11))
	grid.add_child(label("Zaino", 11, Color("a7e5b4")))
	grid.add_child(label("Robbie", 13, Color("8edce1")))
	for id: String in Cargo.ITEM_IDS:
		var name_label := label(NAMES[id], 15, COLORS[id])
		name_label.custom_minimum_size.x = 128
		grid.add_child(name_label)
		compact_rows[id] = [name_label]
		for index in range(2):
			var count := label("0", 13)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.custom_minimum_size.x = 34
			grid.add_child(count)
			compact_counts.append(count)
			compact_rows[id].append(count)
	compact_link = label("", 12)
	column.add_child(compact_link)

func _build_window() -> void:
	window = Window.new()
	window.title = "Inventario e depositi"
	window.visible = false
	window.transient = true
	window.exclusive = true
	window.unresizable = true
	window.close_requested.connect(window.hide)
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_I]:
			window.hide()
			window.set_input_as_handled())
	window.theme = Theme.new()
	window.theme.default_font_size = 15
	add_child(window)
	var background := ColorRect.new()
	background.color = Color("222b2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	window.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(label("INVENTARIO", 22))
	availability = label("", 14, Color("b4c5c6"))
	column.add_child(availability)
	var holds := HBoxContainer.new()
	holds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holds.add_theme_constant_override("separation", 20)
	column.add_child(holds)
	for index in range(3):
		if index > 0:
			holds.add_child(VSeparator.new())
		var hold := VBoxContainer.new()
		hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hold.add_theme_constant_override("separation", 6)
		holds.add_child(hold)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		hold.add_child(header)
		_icon(header, ICONS[index], 32)
		header.add_child(label(["ZAINO", "ROBBIE", "DEPOSITO"][index], 18))
		var subtitle := label("", 13, Color("b4c5c6"))
		hold.add_child(subtitle)
		subtitles.append(subtitle)
		var capacity := label("", 15)
		hold.add_child(capacity)
		capacities.append(capacity)
		bars.append(_meter(hold, [Color("a7e5b4"), Color("8edce1"), Color("f0d281")][index]))
		var item_counts: Array[Label] = []
		for id: String in Cargo.ITEM_IDS:
			var row := HBoxContainer.new()
			row.custom_minimum_size.y = 28
			hold.add_child(row)
			var swatch := ColorRect.new()
			swatch.color = COLORS[id]
			swatch.custom_minimum_size = Vector2(9, 9)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(swatch)
			var name_label := label(NAMES[id] + (" (4 posti)" if id == "lab_cube" else ""), 14)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var count := label("0", 16)
			count.custom_minimum_size.x = 32
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(count)
			item_counts.append(count)
		counts.append(item_counts)
	column.add_child(HSeparator.new())
	var recipe := HBoxContainer.new()
	recipe.add_theme_constant_override("separation", 18)
	column.add_child(recipe)
	recipe.add_child(label("LABORATORIO", 14))
	for id: String in Buildings.LAB_COST:
		var cost_label := label("", 14)
		recipe.add_child(cost_label)
		cost_labels.append(cost_label)
	var recipe_spacer := Control.new()
	recipe_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe.add_child(recipe_spacer)
	prepare_button = button(recipe, "Fabbrica cubo", open_fabrication)
	prepare_button.tooltip_text = "Officina: trasforma 6 pietra + 4 rame in un cubo da 4 posti"
	preparation_status = label("", 13, Color("b4c5c6"))
	column.add_child(preparation_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	picker = OptionButton.new()
	picker.custom_minimum_size.x = 160
	for id: String in Cargo.ITEM_IDS:
		picker.add_item(NAMES[id])
	actions.add_child(picker)
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 20
	amount.value = 1
	actions.add_child(amount)
	withdraw_button = button(actions, "Preleva", withdraw)
	withdraw_button.tooltip_text = "Dal deposito allo zaino, poi al drone vicino"
	deposit_button = button(actions, "Scarica tutto", deposit)
	deposit_button.tooltip_text = "Deposita lo zaino e, se vicino, anche il drone"
	craft_button = button(actions, "Fabbrica luce", craft)
	craft_button.visible = false
	craft_button.tooltip_text = "Al laboratorio: 1 terra + 1 rame, con spazio per il kit"
	feedback = label("", 14, Color("f0d281"))
	feedback.custom_minimum_size.y = 22
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)

func open_inventory() -> void:
	world.mouse_mining = false
	world.guide_event("inventory_opened")
	feedback.text = ""
	window.popup_centered(Vector2i(960, 660))
	refresh()

func lab_missing() -> Dictionary:
	var missing := {}
	for id: String in Buildings.LAB_COST:
		var count: int = world.field_cargo.available(id, world.drone_help_available(), world.outpost.payment_cache())
		if count < int(Buildings.LAB_COST[id]):
			missing[id] = int(Buildings.LAB_COST[id]) - count
	return missing

func open_fabrication() -> void:
	if not world.aboard_workshop():
		return
	window.hide()
	world.outpost.construction.open_picker(world.Grid.to_cell(world.player.position), Vector2(340, 150), true)

func prepare_blocker() -> String:
	if not world.aboard_workshop():
		return "Prepara il carico nell'officina della nave."
	var missing := lab_missing()
	if missing.is_empty():
		return "Materiali del laboratorio gia disponibili."
	var total := 0
	for id: String in missing:
		total += int(missing[id])
		if int(world.outpost.source_stock().get(id, 0)) < int(missing[id]):
			return "Nel deposito manca %s." % NAMES[id].to_lower()
	var space: int = world.field_cargo.free_space(world.drone_help_available())
	if space < total:
		return "Libera %d posti nel carico prima di prelevare." % (total - space)
	return ""

func prepare_lab() -> void:
	var reason := prepare_blocker()
	if not reason.is_empty():
		feedback.text = reason
		return
	var missing := lab_missing()
	for id: String in missing:
		world.field_cargo.withdraw(world.outpost.source_stock(), id, int(missing[id]), world.drone_help_available())
	feedback.text = "Caricati i materiali: 6 pietra + 4 rame disponibili per il laboratorio."
	refresh()

func withdraw() -> void:
	if not world.outpost.source_available():
		return
	var id: String = Cargo.ITEM_IDS[picker.selected]
	var ok: bool = world.field_cargo.withdraw(world.outpost.source_stock(), id, int(amount.value), world.drone_help_available())
	feedback.text = "Prelevati %d: %s." % [int(amount.value), NAMES[id]] if ok else "Quantita non disponibile nel deposito o spazio nel carico insufficiente."
	refresh()

func deposit() -> void:
	if not world.outpost.source_available():
		return
	var transferred: int = world.field_cargo.deposit(world.outpost.source_stock(), storage_capacity(), world.drone_help_available())
	feedback.text = "Scaricate %d unita nel deposito." % transferred if transferred > 0 else "Nessun trasferimento: carico vuoto o deposito pieno."
	if not world.drone_help_available() and world.field_cargo.used(world.field_cargo.drone) > 0:
		feedback.text += " Il drone deve avvicinarsi per essere scaricato."
	if transferred > 0:
		world.guide_event("deposited")
	refresh()

func craft() -> void:
	feedback.text = "Luce fabbricata: kit aggiunto al carico." if world.outpost.craft_lamp() else "Servono un laboratorio vicino, 1 terra, 1 rame e spazio per il kit."
	refresh()

func storage_capacity() -> int:
	return world.outpost.storage_capacity()

func refresh() -> void:
	var cargo: RefCounted = world.field_cargo
	var connected: bool = world.drone_help_available()
	var stocks: Array = [cargo.backpack, cargo.drone, world.outpost.source_stock()]
	var limits: Array = [Cargo.PACK_CAPACITY, cargo.drone_capacity, storage_capacity()]
	for id: String in compact_rows:
		var visible_row := int(cargo.backpack.get(id, 0)) + int(cargo.drone.get(id, 0)) > 0 or id in ["soil", "stone", "copper"]
		for widget: Control in compact_rows[id]:
			widget.visible = visible_row
	for index in range(2):
		var used: int = cargo.used(stocks[index])
		compact_titles[index].text = "%d / %d%s" % [used, limits[index], " PIENO" if used == limits[index] else ""]
		compact_titles[index].modulate = Color("ffb18e") if used == limits[index] else Color.WHITE
		compact_bars[index].max_value = limits[index]
		compact_bars[index].value = used
		for item in range(Cargo.ITEM_IDS.size()):
			compact_counts[item * 2 + index].text = str(stocks[index].get(Cargo.ITEM_IDS[item], 0))
			compact_counts[item * 2 + index].modulate = Color("829396") if index == 1 and not connected else Color.WHITE
	compact_link.text = "Robbie vicino / carico utilizzabile" if connected else "Robbie lontano / carico escluso"
	compact_link.modulate = Color("a7e5b4") if connected else Color("f0d281")
	if not window.visible:
		return
	var source: bool = world.outpost.source_available()
	for index in range(3):
		var used: int = cargo.used(stocks[index])
		capacities[index].text = "%d / %d unita%s" % [used, limits[index], "  PIENO" if used == limits[index] else ""] if index < 2 or source else "-- / --"
		bars[index].max_value = limits[index]
		bars[index].value = used if index < 2 or source else 0
		for item in range(Cargo.ITEM_IDS.size()):
			counts[index][item].text = str(stocks[index].get(Cargo.ITEM_IDS[item], 0)) if index < 2 or source else "--"
			counts[index][item].modulate = Color.WHITE if index != 1 or connected else Color("829396")
	subtitles[0].text = "Sempre con te"
	subtitles[1].text = "Vicino e collegato" if connected else "Lontano: non utilizzabile"
	subtitles[2].text = ("Officina della nave" if world.aboard_workshop() else "Laboratorio vicino") if source else "Nessun deposito vicino"
	availability.text = "Trasferimenti disponibili / " + subtitles[2].text if source else "Solo consultazione: raggiungi l'officina o un laboratorio per trasferire."
	withdraw_button.disabled = not source or int(stocks[2].get(Cargo.ITEM_IDS[picker.selected], 0)) < int(amount.value) or cargo.collectible(Cargo.ITEM_IDS[picker.selected], connected) < int(amount.value)
	deposit_button.disabled = not source or cargo.used(stocks[2]) >= storage_capacity() or cargo.used(cargo.backpack) + (cargo.used(cargo.drone) if connected else 0) == 0
	prepare_button.disabled = not world.aboard_workshop()
	prepare_button.tooltip_text = "Officina: costo unico di 6 pietra + 4 rame" if not prepare_button.disabled else "Fabbrica il cubo nell'officina della nave"
	preparation_status.text = "Il cubo usa 4 posti nel carico. I materiali si pagano in officina, non una seconda volta nello scavo."
	craft_button.disabled = not world.outpost.lamp_craft_blocker().is_empty()
	craft_button.tooltip_text = world.outpost.lamp_craft_blocker() if craft_button.disabled else "1 terra + 1 rame / fabbrica nel laboratorio vicino"
	var index := 0
	for id: String in Buildings.LAB_COST:
		var available: int = cargo.available(id, connected, stocks[2] if source else {})
		cost_labels[index].text = "%s %d / %d" % [NAMES[id], available, Buildings.LAB_COST[id]]
		cost_labels[index].modulate = Color("a7e5b4") if available >= int(Buildings.LAB_COST[id]) else Color("ffb18e")
		index += 1

func _process(_delta: float) -> void:
	refresh()
