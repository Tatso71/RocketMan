extends RefCounted
class_name SpeciesCodex

var scanned: Dictionary = {}

func register_scan(species_id: String) -> void:
	scanned[species_id] = true

func has_scan(species_id: String) -> bool:
	return scanned.has(species_id)
