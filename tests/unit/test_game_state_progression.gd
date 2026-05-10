extends GdUnitTestSuite

func test_unlocks_first_hatch_after_scanning_species() -> void:
	var state := preload("res://scripts/core/game_state.gd").new()
	state.register_species_scan("glowlark")
	state.register_material("frost_shard", 2)
	state.complete_base_terminal("lab_terminal")

	assert_bool(state.is_hatch_unlocked("hatch_biome_01")).is_true()
	state.free()
