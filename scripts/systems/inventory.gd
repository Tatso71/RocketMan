extends RefCounted
class_name Inventory

var materials: Dictionary = {}

func add_material(material_id: String, amount: int) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount

func get_amount(material_id: String) -> int:
	return materials.get(material_id, 0)

func consume_material(material_id: String, amount: int) -> bool:
	if get_amount(material_id) < amount:
		return false
	materials[material_id] -= amount
	return true
