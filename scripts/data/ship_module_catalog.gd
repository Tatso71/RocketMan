extends RefCounted

const Definition = preload("res://scripts/data/ship_module_def.gd")

static func all() -> Array:
	return [
		_module("hull", "Scafo", "+40 integrita massima per livello", {"structural_component": 4, "electronic_component": 2}, Vector2i(1, 3), 350),
		_module("engine", "Propulsori", "Riduce del 12% il costo delle rotte per livello", {"structural_component": 3, "electronic_component": 4}, Vector2i(2, 3), 500),
		_module("cargo", "Stiva", "+80 unita di carico per livello", {"structural_component": 3, "electronic_component": 1}, Vector2i(3, 3), 300),
		_module("battery", "Accumulatori", "+40 kWh di capacita per livello", {"structural_component": 1, "electronic_component": 4}, Vector2i(2, 2), 200),
		_module("drill", "Banco strumenti", "+1 potenza per livello. Sblocca Risonatore (II) e Plasma (III).", {"structural_component": 2, "electronic_component": 3}, Vector2i(1, 2), 60),
		_module("landing_gear", "Carrelli", "Riduce l'usura da atterraggio", {"structural_component": 3, "electronic_component": 1}, Vector2i(2, 2), 250),
		_module("habitat", "Supporto vitale", "+60 min di riserva nominale e +1 posto equipaggio", {"structural_component": 2, "electronic_component": 4}, Vector2i(3, 3), 400),
		_module("drone", "Drone assistente", "+8 carico, +0.35 m magnete e +5 m rete impianti per livello; seguito senza limite", {"structural_component": 4, "electronic_component": 4}, Vector2i(1, 1), 40)
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
