extends CanvasLayer

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const SHORT_NAMES := {"laboratory": "Banco", "lamp": "Luci", "pump": "Pompe", "fan": "Vent.", "furnace": "Fornaci", "gas_converter": "Conv.", "greenhouse": "Serre"}

class LoadMeter extends Control:
	var report: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("121a1d"))
		var x := 0.0
		for id: String in Buildings.CUBE_IDS:
			var width: float = size.x * float(report.get("groups", {}).get(id, 0)) / maxf(float(report.get("potential", 0)), 0.000001)
			if width > 0:
				draw_rect(Rect2(x, 0, width, size.y), Buildings.CUBE_COLORS[id])
				x += width

var outpost: Node2D
var panel: PanelContainer
var heading: Label
var charge_label: Label
var battery: ProgressBar
var load_label: Label
var load_meter: LoadMeter
var legend: GridContainer
var legend_labels: Dictionary = {}
var autonomy: Label
var last_report: Dictionary = {}
var refresh_timer := 0.0

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 328
	panel.size.x = 328
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	heading = UI.label("", 14, Color("8edce1"))
	column.add_child(heading)
	charge_label = UI.label("", 13)
	column.add_child(charge_label)
	battery = ProgressBar.new()
	battery.custom_minimum_size.y = 8
	battery.show_percentage = false
	battery.tooltip_text = "Carica condivisa della batteria della nave"
	var background := StyleBoxFlat.new()
	background.bg_color = Color("121a1d")
	battery.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a7e5b4")
	battery.add_theme_stylebox_override("fill", fill)
	column.add_child(battery)
	load_label = UI.label("", 13)
	column.add_child(load_label)
	load_meter = LoadMeter.new()
	load_meter.custom_minimum_size.y = 10
	load_meter.tooltip_text = "Consumi attuali delle strutture installate; i segmenti scuri sono utenze non alimentate"
	column.add_child(load_meter)
	legend = GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 12)
	legend.add_theme_constant_override("v_separation", 4)
	column.add_child(legend)
	for id: String in Buildings.CUBE_IDS:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 140
		row.add_theme_constant_override("separation", 6)
		legend.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = Buildings.CUBE_COLORS[id]
		swatch.custom_minimum_size = Vector2(6, 6)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := UI.label("", 12)
		row.add_child(label)
		legend_labels[id] = label
	autonomy = UI.label("", 12, Color("b4c5c6"))
	column.add_child(autonomy)
	refresh()

func refresh() -> void:
	var station: Dictionary = outpost.nearby_station()
	panel.visible = not station.is_empty()
	if not panel.visible:
		return
	var lab: Dictionary = station.get("building", {})
	last_report = outpost.power_report(lab)
	heading.text = "ENERGIA / NAVE" if lab.is_empty() else "ENERGIA / LABORATORIO L%d" % lab.get("level", 1)
	charge_label.text = "Batteria nave  %.1f / %.0f kWh" % [last_report.charge, last_report.capacity]
	battery.max_value = last_report.capacity
	battery.value = last_report.charge
	battery.modulate = Color.WHITE if float(last_report.charge) > float(last_report.capacity) * 0.2 else Color("ef876d")
	load_label.text = "%s: %.2f kWh/min" % ["Consumo rete" if lab.is_empty() else "Questo laboratorio", float(last_report.load) * 60]
	load_meter.report = last_report
	load_meter.queue_redraw()
	for id: String in Buildings.CUBE_IDS:
		legend_labels[id].get_parent().visible = int(last_report.counts[id]) > 0
		legend_labels[id].text = "%s x%d: %.2f" % [SHORT_NAMES[id], last_report.counts[id], float(last_report.groups[id]) * 60]
		legend_labels[id].tooltip_text = "%d %s / %.2f kWh al minuto" % [last_report.counts[id], Buildings.NAMES[id].to_lower(), float(last_report.groups[id]) * 60]
		legend_labels[id].modulate = Color.WHITE if float(last_report.groups[id]) > 0 else Color("8a9c9a")
	var network: float = last_report.network
	autonomy.text = "Autonomia rete: %.1f min" % (float(last_report.charge) / network / 60) if network > 0 else "Rete ferma / nessun consumo"
	if not lab.is_empty() and not outpost.operational(lab):
		autonomy.text = "Laboratorio non alimentato"
	var viewport := outpost.get_viewport().get_visible_rect().size
	var top: float = outpost.cargo_ui.compact.get_global_rect().end.y + 8
	legend.visible = viewport.y - 112 - top > 180
	panel.size = Vector2(328, 0)
	panel.position = Vector2(viewport.x - 344, top)

func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer <= 0:
		refresh_timer = 0.15
		refresh()
