extends GdUnitTestSuite

const Network = preload("res://scripts/systems/utility_network.gd")
const Site = preload("res://scripts/systems/dig_site.gd")

func test_aboveground_energy_cable_roundtrip() -> void:
	var network := Network.new()
	network.add("energy", Vector2i(5, -2))
	network.add("energy", Vector2i(5, -1))
	var restored := Network.new()
	assert_bool(restored.restore(network.snapshot(), Site.new())).is_true()
	assert_bool(restored.connected("energy", Vector2i(5, -2), Vector2i(5, -1))).is_true()

func test_solid_rock_and_aboveground_gas_remain_invalid() -> void:
	var network := Network.new()
	network.add("energy", Vector2i(8, 0))
	assert_bool(Network.new().restore(network.snapshot(), Site.new())).is_false()
	network = Network.new()
	network.add("gas", Vector2i(5, -2))
	assert_bool(Network.new().restore(network.snapshot(), Site.new())).is_false()
