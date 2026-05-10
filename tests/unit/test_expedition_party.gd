extends GdUnitTestSuite

func test_limits_party_to_three_animals() -> void:
	var party := preload("res://scripts/systems/expedition_party.gd").new()
	assert_bool(party.add_member("glowlark")).is_true()
	assert_bool(party.add_member("mossback")).is_true()
	assert_bool(party.add_member("echofin")).is_true()
	assert_bool(party.add_member("extra")).is_false()
