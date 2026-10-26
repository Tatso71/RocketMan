extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")

func _amount(field: Dictionary) -> float:
	var result := 0.0
	for value in field.values():
		result += float(value)
	return result

func test_pump_removes_finite_water_only_through_connected_open_cells() -> void:
	var site := Site.new()
	site.removed[Vector2i(0, 3)] = true
	site.removed[Vector2i(1, 3)] = true
	var field := Field.new(site)
	field.water.clear()
	field.water[Vector2i(1, 3)] = 1.0
	field.water[Vector2i(3, 3)] = 1.0
	var drained := field.drain_water(Vector2i(0, 3), 4, 5)
	assert_float(drained).is_equal(1.0)
	assert_float(_amount(field.water)).is_equal(1.0)
	assert_bool(field.water.has(Vector2i(3, 3))).is_true()
	site.removed[Vector2i(2, 3)] = true
	assert_float(field.drain_water(Vector2i(0, 3), 4, 5)).is_equal(1.0)
	assert_dict(field.water).is_empty()

func test_pump_rate_budget_and_invalid_values_do_not_create_water() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var before := _amount(field.water)
	assert_float(field.drain_water(Vector2i(3, 3), 3, 0.25)).is_equal(0.25)
	assert_bool(is_equal_approx(_amount(field.water), before - 0.25)).is_true()
	assert_float(field.drain_water(Vector2i(3, 3), 3, NAN)).is_equal(0.0)
	assert_float(field.drain_water(Vector2i(2, 2), 3, 2)).is_equal(0.0)

func test_fan_removes_only_finite_connected_gas_and_never_water() -> void:
	var site := Site.new()
	for cell: Vector2i in [Vector2i(0, 3), Vector2i(1, 3), Vector2i(3, 3)]:
		site.removed[cell] = true
	var field := Field.new(site)
	field.gas = {Vector2i(1, 3): 0.8, Vector2i(3, 3): 0.6}
	var water_before := field.water.duplicate()
	assert_float(field.drain_gas(Vector2i(0, 3), 3, 0.25)).is_equal(0.25)
	assert_bool(is_equal_approx(field.gas[Vector2i(1, 3)], 0.55)).is_true()
	assert_float(field.drain_gas(Vector2i(0, 3), 3, 5)).is_equal(0.55)
	assert_float(field.gas[Vector2i(3, 3)]).is_equal(0.6)
	assert_dict(field.water).is_equal(water_before)
	site.removed[Vector2i(2, 3)] = true
	assert_float(field.drain_gas(Vector2i(0, 3), 3, 1)).is_equal(0.6)
	assert_dict(field.gas).is_empty()

func test_fan_rejects_invalid_budgets_and_cannot_reach_beyond_radius() -> void:
	var site := Site.new()
	for x in range(5):
		site.removed[Vector2i(x, 2)] = true
	var field := Field.new(site)
	field.gas = {Vector2i(4, 2): 1.0}
	var before := field.gas.duplicate()
	for amount in [-1.0, 0.0, NAN, INF]:
		assert_float(field.drain_gas(Vector2i(0, 2), 5, amount)).is_equal(0.0)
	assert_float(field.drain_gas(Vector2i(0, 2), 3, 10)).is_equal(0.0)
	assert_float(field.drain_gas(Vector2i(0, 2), -1, 1)).is_equal(0.0)
	assert_dict(field.gas).is_equal(before)

func test_sealed_pockets_stay_sealed_and_do_not_lose_volume() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var water_before := _amount(field.water)
	var gas_before := _amount(field.gas)
	var oil_before := _amount(field.oil)
	for index in range(100):
		field.advance(0.2)
	assert_bool(field.released.is_empty()).is_true()
	assert_float(_amount(field.water)).is_equal(water_before)
	assert_float(_amount(field.gas)).is_equal(gas_before)
	assert_float(_amount(field.oil)).is_equal(oil_before)

func test_gas_breach_is_reported_once_and_stopped_by_rock() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var before := _amount(field.gas)
	site.removed[Vector2i(-7, 3)] = true
	assert_array(field.detect_breaches()).contains(["gas"])
	assert_array(field.detect_breaches()).is_empty()
	for index in range(20):
		field.advance(0.2)
	assert_float(field.gas.get(Vector2i(-7, 3), 0.0)).is_greater(0.0)
	assert_bool(field.gas.has(Vector2i(-6, 3))).is_false()
	assert_float(_amount(field.gas)).is_less(before)
	assert_float(field.gas[Vector2i(11, 11)]).is_equal(1.0)

func test_water_falls_only_into_air_and_conserves_finite_volume() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var water_before := _amount(field.water)
	var gas_before := _amount(field.gas)
	for cell in [Vector2i(2, 4), Vector2i(2, 5), Vector2i(1, 5)]:
		site.removed[cell] = true
	assert_array(field.detect_breaches()).contains(["water"])
	for index in range(100):
		field.advance(0.2)
	assert_float(field.water.get(Vector2i(2, 5), 0.0)).is_greater(0.0)
	assert_bool(field.water.has(Vector2i(2, 6))).is_false()
	assert_bool(absf(_amount(field.water) - water_before) < 0.001).is_true()
	assert_float(_amount(field.gas)).is_equal(gas_before)

func test_scanner_reads_hazard_beyond_one_sealed_cell_face() -> void:
	var field := Field.new(Site.new())
	assert_str(field.reading(Vector2i(-7, 3))).contains("Gas")
	assert_str(field.reading(Vector2i(-7, 3))).contains("sigillata")
	assert_str(field.reading(Vector2i(2, 4))).contains("Acqua")
	assert_str(field.reading(Vector2i(20, 3))).is_empty()

func test_exposure_respects_head_and_partial_water_height() -> void:
	var field := Field.new(Site.new())
	assert_bool(field.exposure(Vector2(140, 200)).submerged).is_true()
	assert_float(field.exposure(Vector2(-300, 160)).gas).is_equal(1.0)
	field.water.clear()
	field.water[Vector2i(0, 0)] = 0.25
	assert_bool(field.exposure(Vector2(20, 20)).wet).is_false()
	assert_bool(field.exposure(Vector2(20, 40)).wet).is_true()

func test_fluid_snapshot_survives_json_and_rejects_invalid_data_transactionally() -> void:
	var site := Site.new()
	site.removed[Vector2i(2, 4)] = true
	var field := Field.new(site)
	for index in range(30):
		field.advance(0.2)
	var restored := Field.new(site)
	var data: Dictionary = JSON.parse_string(JSON.stringify(field.snapshot()))
	assert_bool(restored.restore(data)).is_true()
	assert_bool(absf(_amount(restored.water) - _amount(field.water)) < 0.001).is_true()
	var before := restored.snapshot()
	data.water.append([12, 12, 0.5])
	assert_bool(restored.restore(data)).is_false()
	assert_dict(restored.snapshot()).is_equal(before)
	data = field.snapshot()
	data.gas[0][2] = INF
	assert_bool(restored.restore(data)).is_false()

func test_legacy_outpost_without_fluid_state_can_initialize_defaults() -> void:
	var site := Site.new(0, 0)
	site.restore([[0, 0]])
	var field := Field.new(site)
	assert_bool(field.restore({})).is_true()
	assert_str(site.material(Vector2i(3, 3))).is_empty()
	assert_float(_amount(field.water)).is_equal(4.0)
