extends RefCounted

const Definition = preload("res://scripts/data/planet_def.gd")

static func all() -> Array:
	return [
		_planet("ochre", "Ocra", 0, 10, 3, "Superficie stabile. Tracce di rame. Atmosfera non verificata.", Color("75bac4"), Color("a45148"), Vector2(650, 280)),
		_planet("verdant", "Viridia", 11, 16, 6, "Segnali biologici. Venti moderati. Abitabilita sconosciuta.", Color("9fbd91"), Color("6e8572"), Vector2(1010, 225)),
		_planet("frost", "Brina", 23, 23, 10, "Depositi cristallini. Gelo e terreno accidentato. Aria ignota.", Color("a6c7d7"), Color("7a7898"), Vector2(890, 490))
	]

static func find(planet_id: String) -> Resource:
	for planet: Resource in all():
		if planet.planet_id == planet_id:
			return planet
	return null

static func _planet(id: String, title: String, seed_value: int, fuel: float, hazard: float, summary: String, sky: Color, rock: Color, location: Vector2) -> Resource:
	var planet := Definition.new()
	planet.planet_id = id
	planet.display_name = title
	planet.terrain_seed = seed_value
	planet.route_fuel = fuel
	planet.landing_hazard = hazard
	planet.scan_summary = summary
	planet.surface_color = sky
	planet.rock_color = rock
	planet.map_position = location
	return planet
