extends RefCounted

const Definition = preload("res://scripts/data/ship_module_def.gd")

static func all() -> Array:
	return [
		_module("hull", "Scafo", "+40 integrita massima per livello", {"stone": 8, "copper": 4}, Vector2i(1, 3), 350),
		_module("engine", "Propulsori", "Riduce del 12% il costo delle rotte per livello", {"copper": 8, "crystal": 2}, Vector2i(2, 3), 500),
		_module("cargo", "Stiva", "+80 unita di carico per livello", {"stone": 6, "copper": 4}, Vector2i(3, 3), 300),
		_module("battery", "Accumulatori", "+40 kWh di capacita per livello", {"copper": 5, "crystal": 2}, Vector2i(2, 2), 200),
		_module("drill", "Banco strumenti", "+1 potenza per livello. Sblocca Risonatore (II) e Plasma (III).", {"stone": 4, "copper": 6}, Vector2i(1, 2), 60),
		_module("landing_gear", "Carrelli", "Riduce l'usura da atterraggio", {"stone": 6, "copper": 3}, Vector2i(2, 2), 250),
		_module("habitat", "Supporto vitale", "+60 min di riserva nominale e +1 posto equipaggio", {"copper": 6, "crystal": 3}, Vector2i(3, 3), 400)
	]

static func find(id: String) -> Resource:
	for definition: Resource in all():
		if definition.module_id == id:
			return definition
	return null

static func _module(id: String, title: String, effect: String, price: Dictionary, footprint: Vector2i, mass: float) -> Resource:
	var definition := Definition.new()
	definition.module_id = id
	definition.display_name = title
	definition.description = effect
	definition.base_cost = price
	definition.footprint_cells = footprint
	definition.mass_kg = mass
	return definition
