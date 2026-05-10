extends RefCounted
class_name CraftingLab

func craft_reactor_seal(inventory) -> bool:
	if inventory.get_amount("frost_shard") < 2:
		return false
	if inventory.get_amount("fiber_vine") < 1:
		return false
	inventory.consume_material("frost_shard", 2)
	inventory.consume_material("fiber_vine", 1)
	return true
