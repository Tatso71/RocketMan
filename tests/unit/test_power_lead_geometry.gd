extends GdUnitTestSuite

const Outpost = preload("res://scripts/prototype/outpost_controller.gd")
const Network = preload("res://scripts/systems/utility_network.gd")

func test_automatic_cables_use_only_horizontal_and_vertical_segments() -> void:
	var outpost: Node2D = auto_free(Outpost.new())
	for ends: Array in [[Vector2(0, -80), Vector2(-140, 100)], [Vector2(-6, 434), Vector2(20, 552)], [Vector2(30, 60), Vector2(30, 200)], [Vector2.ZERO, Vector2.ZERO]]:
		var points: PackedVector2Array = outpost._power_lead_points(ends[0], ends[1])
		assert_vector(points[0]).is_equal(ends[0])
		assert_vector(points[-1]).is_equal(ends[1])
		for index in range(1, points.size()):
			var step := points[index] - points[index - 1]
			assert_bool(is_zero_approx(step.x) or is_zero_approx(step.y)).is_true()

func test_network_colors_distinguish_current_water_and_gas() -> void:
	var energy: Color = Network.COLORS.energy
	var water: Color = Network.COLORS.water
	var gas: Color = Network.COLORS.gas
	assert_bool(energy.r > energy.g * 2.0 and energy.r > energy.b * 1.5).is_true()
	assert_bool(water.b > water.r * 1.5 and water.b > water.g).is_true()
	assert_bool(gas.g > gas.r * 1.5 and gas.g > gas.b * 1.3).is_true()
