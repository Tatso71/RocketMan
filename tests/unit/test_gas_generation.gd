extends GdUnitTestSuite

const Layout = preload("res://scripts/data/hazard_layout.gd")
const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const SEEDS := [-7, -1, 0, 1, 2, 11, 42, 1001]

var previous_gas_pockets_enabled: bool

func before_test() -> void:
	previous_gas_pockets_enabled = Layout.gas_pockets_enabled

func after_test() -> void:
	Layout.gas_pockets_enabled = previous_gas_pockets_enabled

func test_default_worlds_have_no_natural_gas_in_any_layout() -> void:
	assert_bool(Layout.gas_pockets_enabled).is_false()
	for seed_value: int in SEEDS:
		for version in range(Layout.CURRENT_VERSION + 1):
			var site := Site.new(seed_value, version)
			assert_dict(Field.new(site).gas).is_empty()
			for pocket: Dictionary in site.pockets():
				assert_str(pocket.kind).is_not_equal("gas")

func test_suspended_gas_chambers_remain_solid_terrain() -> void:
	for seed_value: int in SEEDS:
		for version in range(Layout.CURRENT_VERSION + 1):
			var site := Site.new(seed_value, version)
			var west := -9 - posmod(seed_value, 3)
			for y in [2, 3]:
				for x in [west, west + 1]:
					assert_bool(site.removed.has(Vector2i(x, y))).is_false()
					assert_str(site.material(Vector2i(x, y))).is_not_empty()
	for version in [1, 2]:
		var site := Site.new(0, version)
		var deep_cells: Array[Vector2i] = [Vector2i(11, 11), Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12)]
		if version == 2:
			deep_cells = [Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10), Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11), Vector2i(14, 11), Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12), Vector2i(11, 13), Vector2i(12, 13)]
		for cell: Vector2i in deep_cells:
			assert_bool(site.removed.has(cell)).is_false()
			assert_str(site.material(cell)).is_not_empty()

func test_explicit_qa_opt_in_restores_gas_without_changing_other_reservoirs() -> void:
	for seed_value: int in SEEDS:
		for version in range(Layout.CURRENT_VERSION + 1):
			Layout.gas_pockets_enabled = true
			var qa_site := Site.new(seed_value, version)
			var qa_field := Field.new(qa_site)
			var deep_gas := seed_value == 0 and version >= 1
			assert_int(qa_field.gas.size()).is_equal((18 if version >= 2 else 8) if deep_gas else 4)
			var gas_count := 0
			var liquid_pockets := []
			for pocket: Dictionary in qa_site.pockets():
				if pocket.kind != "gas":
					liquid_pockets.append(pocket)
					continue
				gas_count += 1
				for cell: Vector2i in Layout.cells(pocket):
					assert_str(qa_site.material(cell)).is_empty()
					assert_float(qa_field.gas.get(cell, 0.0)).is_equal(1.0)
			assert_int(gas_count).is_equal(2 if deep_gas else 1)
			assert_array(qa_field.detect_breaches()).is_empty()
			Layout.gas_pockets_enabled = false
			var ordinary_site := Site.new(seed_value, version)
			var ordinary_field := Field.new(ordinary_site)
			assert_array(ordinary_site.pockets()).is_equal(liquid_pockets)
			assert_dict(ordinary_field.gas).is_empty()
			for kind: String in ["water", "oil", "acid"]:
				assert_dict(ordinary_field.get(kind)).is_equal(qa_field.get(kind))
