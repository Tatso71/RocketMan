extends GdUnitTestSuite

const Site = preload("res://scripts/systems/dig_site.gd")
const Field = preload("res://scripts/systems/environment_field.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")

func _room(site: RefCounted) -> void:
	for y in range(1, 4):
		for x in range(-5, -1):
			site.removed[Vector2i(x, y)] = true

func test_lab_requires_excavation_and_full_four_metre_floor() -> void:
	var site := Site.new()
	var field := Field.new(site)
	var buildings := Buildings.new()
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).is_not_empty()
	_room(site)
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).is_empty()
	site.removed[Vector2i(-4, 4)] = true
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("pavimento")

func test_fluid_and_overlapping_structures_block_placement() -> void:
	var site := Site.new()
	_room(site)
	var field := Field.new(site)
	var buildings := Buildings.new()
	field.water[Vector2i(-5, 3)] = 0.5
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("sicura")
	field.water.erase(Vector2i(-5, 3))
	buildings.install("laboratory", Vector2i(-5, 1))
	assert_str(buildings.blocker("laboratory", Vector2i(-5, 1), site, field)).contains("occupato")

func test_structure_and_local_cache_survive_json_roundtrip() -> void:
	var site := Site.new()
	_room(site)
	var buildings := Buildings.new()
	var lab := buildings.install("laboratory", Vector2i(-5, 1))
	lab.stock.soil = 12
	var data: Array = JSON.parse_string(JSON.stringify(buildings.snapshot()))
	var restored := Buildings.new()
	assert_bool(restored.restore(data, site)).is_true()
	assert_int(int(restored.structures[0].stock.soil)).is_equal(12)
	data[0].stock.soil = 33
	assert_bool(restored.restore(data, site)).is_false()
	assert_int(int(restored.structures[0].stock.soil)).is_equal(12)
