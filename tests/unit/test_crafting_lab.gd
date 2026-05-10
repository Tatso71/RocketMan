extends GdUnitTestSuite

func test_unlocks_reactor_seal_when_materials_are_present() -> void:
	var inventory := preload("res://scripts/systems/inventory.gd").new()
	inventory.add_material("frost_shard", 2)
	inventory.add_material("fiber_vine", 1)

	var lab = preload("res://scripts/systems/crafting_lab.gd").new()
	assert_bool(lab.call("craft_reactor_seal", inventory)).is_true()
	assert_int(inventory.get_amount("frost_shard")).is_equal(0)
