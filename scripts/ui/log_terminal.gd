extends StaticBody2D

func interact() -> void:
	GameStateStore.complete_base_terminal("lab_terminal")

	var inventory = preload("res://scripts/systems/inventory.gd").new()
	inventory.materials = GameStateStore.materials.duplicate(true)
	var lab = preload("res://scripts/systems/crafting_lab.gd").new()

	if lab.craft_reactor_seal(inventory):
		GameStateStore.materials = inventory.materials
		GameStateStore.mark_crafted_part("reactor_seal")
		print("Terminal: Reactor seal crafted.")
	else:
		print("Terminal: Reactor seal schema requires 2 frost shards and 1 fiber vine.")
