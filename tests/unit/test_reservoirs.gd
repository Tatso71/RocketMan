extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func volume(field: Dictionary) -> float:
	var total := 0.0
	for amount in field.values():
		total += float(amount)
	return total

func test_new_reservoirs_are_connected_sealed_and_disjoint() -> void:
	var site := Site.new()
	var occupied := {}
	assert_int(site.layout_version).is_equal(2)
	assert_int(site.pockets().size()).is_equal(7)
	for pocket: Dictionary in site.pockets():
		var cells := Layout.cells(pocket)
		var connected: Array[Vector2i] = [cells[0]]
		var head := 0
		while head < connected.size():
			var cell: Vector2i = connected[head]
			head += 1
			for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if cell + offset in cells and cell + offset not in connected:
					connected.append(cell + offset)
		assert_int(connected.size()).is_equal(cells.size())
		for cell: Vector2i in cells:
			assert_bool(site.contains(cell) and not site.indestructible(cell) and not occupied.has(cell)).is_true()
			assert_str(site.material(cell)).is_empty()
			occupied[cell] = true
		for cell: Vector2i in Layout.boundary(pocket):
			assert_str(site.material(cell)).is_not_empty()
		if pocket.has("rows"):
			assert_bool(cells.size() < pocket.size.x * pocket.size.y).is_true()
	assert_array(Field.new(site).detect_breaches()).is_empty()

func test_filled_irregular_basins_stay_static_until_a_wall_is_opened() -> void:
	var field := Field.new(Site.new())
	var before := field.snapshot()
	for step in range(100):
		field.advance(0.2)
	assert_dict(field.snapshot()).is_equal(before)

func test_acid_breach_flows_downward_and_stops_at_solid_rock() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var before := volume(field.acid)
	for cell: Vector2i in [Vector2i(-18, 15), Vector2i(-18, 16), Vector2i(-17, 16)]:
		site.removed[cell] = true
	assert_array(field.detect_breaches()).contains(["acid"])
	assert_array(field.detect_breaches()).is_empty()
	for step in range(100):
		field.advance(0.2)
	assert_float(float(field.acid.get(Vector2i(-17, 16), 0))).is_greater(0.0)
	assert_bool(field.acid.has(Vector2i(-17, 17))).is_false()
	assert_bool(absf(volume(field.acid) - before) < 0.0001).is_true()

func test_opening_a_liquid_roof_does_not_empty_the_basin_upward() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var before := field.acid.duplicate()
	site.removed[Vector2i(-18, 10)] = true
	assert_array(field.detect_breaches()).contains(["acid"])
	for step in range(50):
		field.advance(0.2)
	assert_dict(field.acid).is_equal(before)
	assert_bool(field.acid.has(Vector2i(-18, 10))).is_false()

func test_all_liquids_share_cell_capacity_without_losing_volume() -> void:
	var site := Site.new()
	for x in range(-2, 3):
		site.removed[Vector2i(x, 8)] = true
	var field := Field.new(site)
	field.water = {Vector2i(-2, 8): 1.0}
	field.acid = {Vector2i(0, 8): 1.0}
	field.oil = {Vector2i(2, 8): 1.0}
	for step in range(100):
		field.advance(0.2)
	for x in range(-2, 3):
		assert_float(field.liquid_volume(Vector2i(x, 8))).is_less_equal(1.00001)
	for kind: String in Field.Fluids.LIQUID_IDS:
		assert_bool(absf(volume(field.get(kind)) - 1) < 0.0001).is_true()

func test_liquid_layers_use_the_same_geometry_for_contact_and_rendering() -> void:
	var field := Field.new(Site.new())
	field.acid = {Vector2i(0, 0): 0.25}
	field.water = {Vector2i(0, 0): 0.25}
	field.oil = {Vector2i(0, 0): 0.25}
	assert_bool(field.liquid_rect(Vector2i(0, 0), "acid") == Rect2(0, 30, 40, 10)).is_true()
	assert_bool(field.liquid_rect(Vector2i(0, 0), "water") == Rect2(0, 20, 40, 10)).is_true()
	assert_bool(field.liquid_rect(Vector2i(0, 0), "oil") == Rect2(0, 10, 40, 10)).is_true()
	assert_bool(field.exposure(Vector2(20, 39)).acid).is_true()
	assert_bool(field.exposure(Vector2(20, 19)).acid).is_false()

func test_acid_is_not_water_and_ordinary_pumps_cannot_remove_it() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var before := field.acid.duplicate()
	assert_float(field.drain_water(Vector2i(-19, 12), 10, 100)).is_equal(0.0)
	assert_dict(field.acid).is_equal(before)
	assert_bool(Buildings.environment_safe("pump", 0, 0, 0, 1)).is_false()
	assert_bool(field.exposure(Vector2(-740, 560)).acid).is_true()
	assert_bool(field.exposure(Vector2(-740, 560)).wet).is_true()
	assert_str(field.reading(Vector2i(-18, 15))).contains("Acido")

func test_gas_rises_and_cannot_cross_rock_or_a_full_liquid_cell() -> void:
	var site := Site.new()
	for cell: Vector2i in [Vector2i(0, 8), Vector2i(0, 7), Vector2i(0, 9), Vector2i(1, 8)]:
		site.removed[cell] = true
	var field := Field.new(site)
	field.water = {Vector2i(1, 8): 1.0}
	field.gas = {Vector2i(0, 8): 1.0}
	field._step_gas()
	assert_float(float(field.gas.get(Vector2i(0, 7), 0))).is_greater(float(field.gas.get(Vector2i(0, 9), 0)))
	assert_bool(field.gas.has(Vector2i(-1, 8))).is_false()
	assert_bool(field.gas.has(Vector2i(1, 8))).is_false()

func test_acid_save_roundtrip_and_corrupt_liquid_totals_are_atomic() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var loaded := Field.new(site)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(field.snapshot()))
	assert_bool(loaded.restore(saved)).is_true()
	assert_dict(loaded.acid).is_equal(field.acid)
	var before := loaded.snapshot()
	saved.water.append([-19, 12, 1])
	assert_bool(loaded.restore(saved)).is_false()
	assert_dict(loaded.snapshot()).is_equal(before)
	for invalid in [NAN, INF, -1, 1.1]:
		saved = field.snapshot()
		saved.acid[0][2] = invalid
		assert_bool(loaded.restore(saved)).is_false()
		assert_dict(loaded.snapshot()).is_equal(before)

func test_legacy_layouts_keep_their_old_cavities_without_new_acid() -> void:
	for version in [0, 1]:
		var site := Site.new(0, version)
		var field := Field.new(site)
		var saved := field.snapshot()
		saved.version = 2
		saved.erase("acid")
		assert_bool(field.restore(saved)).is_true()
		assert_dict(field.acid).is_empty()
		assert_int(site.pockets().size()).is_equal(2 if version == 0 else 6)
		assert_str(site.material(Vector2i(-19, 12))).is_not_empty()
