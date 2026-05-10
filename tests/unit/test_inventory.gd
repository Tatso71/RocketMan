extends GdUnitTestSuite

func test_adds_and_spends_materials() -> void:
	var inventory := preload("res://scripts/systems/inventory.gd").new()
	inventory.add_material("frost_shard", 3)

	assert_int(inventory.get_amount("frost_shard")).is_equal(3)
	assert_bool(inventory.consume_material("frost_shard", 2)).is_true()
	assert_int(inventory.get_amount("frost_shard")).is_equal(1)
