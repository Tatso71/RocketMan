extends GdUnitTestSuite

const Saver = preload("res://scripts/core/save_manager.gd")
const Campaign = preload("res://scripts/systems/expedition_state.gd")
const Planets = preload("res://scripts/data/planet_catalog.gd")
const DigSite = preload("res://scripts/systems/dig_site.gd")

func test_component_slots_cannot_overwrite_cube_campaigns() -> void:
	var saver := Saver.new()
	assert_str(saver.campaign_save_path).contains("campaign_components_v1")
	assert_str(saver.rocket_save_path).contains("rocket_home_components_v1")
	assert_str(Saver.variant_path(saver.campaign_save_path, "robbie")).contains("components_v1_robbie")
	saver.free()

func test_campaign_rejects_another_economy_before_mutation() -> void:
	var state := Campaign.new()
	var original := state.snapshot()
	assert_int(original.get("economy_version", 0)).is_equal(2)
	var invalid := original.duplicate(true)
	invalid.economy_version = 1
	assert_bool(state.restore(invalid)).is_false()
	assert_dict(state.snapshot()).is_equal(original)

func test_every_nested_outpost_requires_the_component_economy() -> void:
	var state := Campaign.new()
	var terrain := DigSite.new(Planets.find("frost").terrain_seed)
	state.outposts.frost = {"version": 1, "economy_version": 2, "cell_metres": 1.0, "terrain_seed": terrain.terrain_seed, "layout_version": terrain.layout_version, "removed": terrain.snapshot(), "ladders": [], "materials": {}}
	var original: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	assert_bool(state.restore(original)).is_true()
	original = state.snapshot()
	for marker: int in [-1, 1]:
		var invalid := original.duplicate(true)
		invalid.ship.fuel = 20
		if marker == -1:
			invalid.outposts.frost.erase("economy_version")
		else:
			invalid.outposts.frost.economy_version = marker
		assert_bool(state.restore(invalid)).is_false()
		assert_dict(state.snapshot()).is_equal(original)
