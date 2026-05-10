extends Node
class_name GameState

var scanned_species: Dictionary = {}
var materials: Dictionary = {}
var completed_terminals: Dictionary = {}
var crafted_parts: Dictionary = {}

func register_species_scan(species_id: String) -> void:
	scanned_species[species_id] = true

func register_material(material_id: String, amount: int) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount

func complete_base_terminal(terminal_id: String) -> void:
	completed_terminals[terminal_id] = true

func mark_crafted_part(part_id: String) -> void:
	crafted_parts[part_id] = true

func is_hatch_unlocked(hatch_id: String) -> bool:
	if hatch_id != "hatch_biome_01":
		return false
	return scanned_species.has("glowlark") \
		and materials.get("frost_shard", 0) >= 2 \
		and completed_terminals.has("lab_terminal")
