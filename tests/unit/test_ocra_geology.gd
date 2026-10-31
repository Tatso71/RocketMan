extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Layout = preload("res://scripts/data/hazard_layout.gd")
const Geology = preload("res://scripts/data/ocra_geology.gd")

func test_authored_pockets_are_disjoint_finite_sealed_and_outside_the_hatch() -> void:
	var site := Site.new(0, 1)
	var occupied := {}
	var totals := {"water": 0, "gas": 0, "oil": 0}
	for pocket: Dictionary in site.pockets():
		for cell: Vector2i in Layout.cells(pocket):
			assert_bool(site.contains(cell)).is_true()
			assert_bool(site.indestructible(cell)).is_false()
			assert_bool(occupied.has(cell)).is_false()
			assert_str(site.material(cell)).is_empty()
			occupied[cell] = true
			totals[pocket.kind] += 1
	assert_dict(totals).is_equal({"water": 10, "gas": 8, "oil": 12})
	for y in range(9):
		assert_str(site.material(Vector2i(0, y))).is_not_empty()
	assert_array(Field.new(site).detect_breaches()).is_empty()

func test_minerals_form_reproducible_coherent_veins() -> void:
	var site := Site.new()
	for vein: Dictionary in Geology.VEINS:
		assert_str(site.material(vein.center)).is_equal(vein.kind)
		assert_str(site.material(vein.center + Vector2i.RIGHT)).is_equal(vein.kind)
	assert_str(site.material(Vector2i(0, 4))).is_equal("copper")
	assert_str(site.material(Vector2i(0, 15))).is_equal("bedrock")
	assert_str(site.material(Vector2i(-18, 7))).is_equal("anchor")
	site.removed[Vector2i(-18, 6)] = true
	assert_str(site.mine(Vector2i(-18, 7), 100000, true)).is_empty()

func test_legacy_layout_keeps_old_rock_and_only_two_pockets() -> void:
	var site := Site.new(0, 0)
	assert_str(site.material(Vector2i(-18, 7))).is_not_equal("anchor")
	assert_int(site.pockets().size()).is_equal(2)
	assert_dict(Field.new(site).oil).is_empty()
	assert_int(Site.new(11).pockets().size()).is_equal(2)

func test_oil_breach_flows_slowly_and_conserves_volume() -> void:
	var site := Site.new(0, 1)
	var field := Field.new(site)
	site.removed[Vector2i(6, 18)] = true
	assert_array(field.detect_breaches()).contains(["oil"])
	assert_array(field.detect_breaches()).is_empty()
	field.advance(0.2)
	assert_float(field.oil.get(Vector2i(6, 18), 0.0)).is_greater(0.0)
	assert_float(field.oil.get(Vector2i(6, 18), 0.0)).is_less(0.5)
	for index in range(100):
		field.advance(0.2)
	var total := 0.0
	for value in field.oil.values():
		total += float(value)
	assert_bool(absf(total - 12) < 0.0001).is_true()
	assert_str(field.reading(Vector2i(5, 17))).contains("Petrolio")
	assert_str(field.reading(Vector2i(5, 17))).contains("perdita")

func test_water_pump_cannot_remove_oil_and_liquids_never_overfill_a_cell() -> void:
	var site := Site.new()
	for x in range(3):
		site.removed[Vector2i(x, 10)] = true
	var field := Field.new(site)
	field.water = {Vector2i(0, 10): 1.0}
	field.oil = {Vector2i(2, 10): 1.0}
	for index in range(50):
		field.advance(0.2)
	for cell: Vector2i in field.oil:
		assert_float(field.oil[cell] + field.water.get(cell, 0.0)).is_less_equal(1.00001)
	var before := field.oil.duplicate()
	field.drain_water(Vector2i(0, 10), 3, 10)
	assert_dict(field.oil).is_equal(before)

func test_oil_json_roundtrip_and_invalid_restore_are_atomic() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var restored := Field.new(site)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(field.snapshot()))
	assert_bool(restored.restore(saved)).is_true()
	assert_dict(restored.oil).is_equal(field.oil)
	var before := restored.snapshot()
	saved.oil.append([0, 0, 1])
	assert_bool(restored.restore(saved)).is_false()
	assert_dict(restored.snapshot()).is_equal(before)
	var legacy := Field.new(Site.new(0, 0))
	var data := legacy.snapshot()
	data.version = 1
	data.erase("oil")
	assert_bool(legacy.restore(JSON.parse_string(JSON.stringify(data)))).is_true()
	assert_dict(legacy.oil).is_empty()
