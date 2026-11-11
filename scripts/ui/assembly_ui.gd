extends Node

const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Components = preload("res://scripts/data/component_catalog.gd")
var outpost: Node2D
var popup: PopupMenu
var anchor := Vector2i.ZERO
var site: Dictionary = {}

func _ready() -> void:
	popup = PopupMenu.new()
	popup.prefer_native_menu = false
	popup.add_theme_stylebox_override("panel", UI.panel_style())
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("v_separation", 16)
	popup.id_pressed.connect(_choose)
	add_child(popup)

func is_open() -> bool:
	return popup.visible

func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in cost:
		parts.append("%d %s" % [cost[id], "strutturali" if id == "structural_component" else "elettronici"])
	return " + ".join(parts)

func open_picker(cell: Vector2i, point: Vector2) -> void:
	anchor = cell
	site = {}
	outpost.build_mode = false
	outpost.world.mouse_mining = false
	popup.clear()
	popup.add_separator("MONTAGGIO")
	for index in range(Components.STRUCTURE_IDS.size()):
		var id: String = Components.STRUCTURE_IDS[index]
		if id != "laboratory" and not outpost.laboratory_unlocked():
			continue
		popup.add_item("%s / %s" % [outpost.Buildings.NAMES[id], cost_text(Components.assembly_cost(id))], index)
	popup.add_separator()
	popup.add_item("Scala / gratuita", 100)
	popup.popup(Rect2i(Vector2i(outpost.get_viewport().get_screen_transform() * point), Vector2i(490, 120)))

func _choose(id: int) -> void:
	if id == 1000:
		if not outpost.fund_site(site):
			outpost.world._note(outpost.funding_blocker(site))
		return
	if id == 1001:
		outpost.cancel_plan(site)
		return
	if id == 100:
		outpost.world.place_ladder_at(anchor)
		return
	if id < 0 or id >= Components.STRUCTURE_IDS.size():
		return
	outpost.blueprint = Components.STRUCTURE_IDS[id]
	outpost.origin = outpost.placement_origin(outpost.blueprint, anchor)
	outpost.preview_fixed = false
	outpost.activation_cube_id = 0
	outpost.build_mode = true
	outpost.world.mouse_mining = false
	outpost.world._note("%s / %s" % [outpost.Buildings.NAMES[outpost.blueprint], cost_text(Components.assembly_cost(outpost.blueprint))])

func open_site(building: Dictionary) -> void:
	site = building
	popup.clear()
	popup.add_separator(outpost.Buildings.NAMES[building.id] + " / progetto")
	for id: String in outpost.site_cost(building):
		var owned: int = outpost.world.field_cargo.available(id, outpost.world.drone_help_available())
		popup.add_separator("%s  %d / %d" % [UI.NAMES[id], owned, outpost.site_cost(building)[id]])
	var reason: String = outpost.funding_blocker(building)
	popup.add_item("Monta" if reason.is_empty() else reason, 1000)
	popup.set_item_disabled(popup.item_count - 1, not reason.is_empty())
	popup.add_item("Annulla progetto", 1001)
	popup.popup_centered(Vector2i(520, 210))
