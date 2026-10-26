extends Control

const Texts = preload("res://scripts/data/robbie_texts.gd")
const UI = preload("res://scripts/ui/field_inventory_ui.gd")
var entries: Dictionary = {}
var source := ""
var selected := ""
var filtered: Array[String] = []
var dirty := false
var updating := false
var search: LineEdit
var list: ItemList
var title_edit: LineEdit
var body_edit: TextEdit
var detail_edit: TextEdit
var priority: SpinBox
var identity: Label
var feedback: Label
var preview_title: Label
var preview_body: Label
var preview_detail: Label
var save_button: Button
var reload_dialog: ConfirmationDialog
var close_dialog: ConfirmationDialog

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("151b20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := UI.label("ROBBIE / TESTI", 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	UI.button(header, "Ricarica", request_reload)
	save_button = UI.button(header, "Salva testi", save_changes)
	save_button.tooltip_text = "Salva il catalogo del progetto (Ctrl+S)"
	var columns := HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.split_offset = 250
	column.add_child(columns)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 220
	columns.add_child(sidebar)
	search = LineEdit.new()
	search.placeholder_text = "Cerca un messaggio"
	search.text_changed.connect(func(_value): _filter())
	sidebar.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(index): select_entry(filtered[index]))
	sidebar.add_child(list)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	columns.add_child(content)
	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size.x = 340
	content.add_child(editor)
	identity = UI.label("", 14, Color("8edbd0"))
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	editor.add_child(identity)
	var priority_row := HBoxContainer.new()
	editor.add_child(priority_row)
	priority_row.add_child(UI.label("Priorita", 14))
	priority = SpinBox.new()
	priority.min_value = 0
	priority.max_value = 100
	priority.value_changed.connect(func(_value): _changed())
	priority_row.add_child(priority)
	editor.add_child(UI.label("Titolo", 14))
	title_edit = LineEdit.new()
	title_edit.text_changed.connect(func(_value): _changed())
	editor.add_child(title_edit)
	editor.add_child(UI.label("Balloon", 14))
	body_edit = TextEdit.new()
	body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_edit.custom_minimum_size.y = 140
	body_edit.text_changed.connect(_changed)
	editor.add_child(body_edit)
	editor.add_child(UI.label("Dettaglio obiettivo", 14))
	detail_edit = TextEdit.new()
	detail_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	detail_edit.custom_minimum_size.y = 90
	detail_edit.text_changed.connect(_changed)
	editor.add_child(detail_edit)
	var preview_scroll := ScrollContainer.new()
	preview_scroll.custom_minimum_size.x = 332
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(preview_scroll)
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.x = 312
	preview_scroll.add_child(preview)
	preview.add_child(UI.label("ANTEPRIMA", 13, Color("aab8bb")))
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/ui/drone.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(80, 80)
	preview.add_child(icon)
	var bubble := PanelContainer.new()
	var style := UI.panel_style()
	style.bg_color = Color("edf4ea")
	style.border_color = Color("589d95")
	style.set_border_width_all(2)
	bubble.add_theme_stylebox_override("panel", style)
	preview.add_child(bubble)
	var speech := VBoxContainer.new()
	speech.add_theme_constant_override("separation", 8)
	bubble.add_child(speech)
	preview_title = UI.label("", 13, Color("256c65"))
	preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.add_child(preview_title)
	preview_body = UI.label("", 16, Color("223933"))
	preview_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.add_child(preview_body)
	preview_detail = UI.label("", 14, Color("b7ccbf"))
	preview_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(preview_detail)
	feedback = UI.label("", 14, Color("b7ccbf"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(feedback)
	reload_dialog = ConfirmationDialog.new()
	reload_dialog.title = "Ricarica testi"
	reload_dialog.dialog_text = "Scartare le modifiche non salvate?"
	reload_dialog.confirmed.connect(reload_entries)
	add_child(reload_dialog)
	get_tree().auto_accept_quit = false
	close_dialog = ConfirmationDialog.new()
	close_dialog.title = "Testi non salvati"
	close_dialog.dialog_text = "Uscire senza salvare le modifiche?"
	close_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(close_dialog)
	reload_entries()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if dirty:
			close_dialog.popup_centered()
		else:
			get_tree().quit()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true

func reload_entries() -> void:
	var next_source := FileAccess.get_file_as_string(Texts.PATH)
	var next_entries := Texts.validate(JSON.parse_string(next_source))
	if next_entries.is_empty():
		feedback.text = "Catalogo non valido: nessuna modifica caricata."
		return
	source = next_source
	entries = Texts.with_tutorial_defaults(next_entries)
	dirty = false
	selected = "" if not entries.has(selected) else selected
	_filter()
	feedback.text = "%d dialoghi / %s" % [entries.size(), Texts.PATH.trim_prefix("res://")]
	save_button.disabled = true

func request_reload() -> void:
	if dirty:
		reload_dialog.popup_centered()
	else:
		reload_entries()

func _filter() -> void:
	list.clear()
	filtered.clear()
	var query := search.text.to_lower()
	for id: String in entries:
		var entry: Dictionary = entries[id]
		if not query.is_empty() and not (id + " " + entry.title + " " + entry.body).to_lower().contains(query):
			continue
		filtered.append(id)
		list.add_item(entry.title)
		list.set_item_tooltip(list.item_count - 1, id)
	if filtered.is_empty():
		return
	if selected not in filtered:
		selected = filtered[0]
	list.select(filtered.find(selected))
	select_entry(selected)

func select_entry(id: String) -> void:
	if not entries.has(id):
		return
	selected = id
	var index := filtered.find(id)
	if index >= 0:
		list.select(index)
	updating = true
	var entry: Dictionary = entries[id]
	identity.text = id
	identity.tooltip_text = id
	priority.value = entry.priority
	title_edit.text = entry.title
	body_edit.text = entry.body
	detail_edit.text = entry.detail
	detail_edit.editable = id.begins_with("ocra/")
	updating = false
	_preview()

func _preview() -> void:
	preview_title.text = "ROBBIE / " + title_edit.text.to_upper()
	preview_body.text = body_edit.text
	preview_detail.text = detail_edit.text

func _changed() -> void:
	if updating or selected.is_empty():
		return
	entries[selected] = {"id": selected, "priority": int(priority.value), "title": title_edit.text, "body": body_edit.text, "detail": detail_edit.text}
	dirty = true
	save_button.disabled = false
	feedback.text = "Modifiche non salvate"
	_preview()
	var index := filtered.find(selected)
	if index >= 0:
		list.set_item_text(index, title_edit.text)

func save_changes() -> void:
	if not dirty:
		return
	var error := Texts.save_entries(entries.values(), source)
	if error != OK:
		feedback.text = "Il file e cambiato su disco: ricarica prima di salvare." if error == ERR_ALREADY_IN_USE else "Salvataggio non riuscito: " + error_string(error)
		return
	source = FileAccess.get_file_as_string(Texts.PATH)
	dirty = false
	save_button.disabled = true
	feedback.text = "Testi salvati. Copia precedente: robbie_texts.json.bak"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_S:
		save_changes()
		get_viewport().set_input_as_handled()
