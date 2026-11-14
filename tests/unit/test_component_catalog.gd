extends GdUnitTestSuite

const Cargo = preload("res://scripts/systems/field_cargo.gd")
const CATALOG_PATH := "res://scripts/data/component_catalog.gd"

func test_solar_panel_assembly_is_validated_without_an_industrial_recipe() -> void:
	var catalog = load(CATALOG_PATH)
	var data: Dictionary = catalog.load_data()
	assert_dict(catalog.assembly_cost("solar_panel")).is_equal({"structural_component": 2, "electronic_component": 1})
	assert_bool(data.recipes.has("solar_panel")).is_false()
	var bad := data.duplicate(true)
	bad.assembly.erase("solar_panel")
	assert_dict(catalog.validate(bad)).is_empty()
	bad = data.duplicate(true)
	bad.assembly.solar_panel = {"structural_component": 2, "copper": 1}
	assert_dict(catalog.validate(bad)).is_empty()

func test_component_recipes_and_assembly_costs_share_a_validated_catalog() -> void:
	assert_bool(ResourceLoader.exists(CATALOG_PATH)).is_true()
	if not ResourceLoader.exists(CATALOG_PATH):
		return
	var catalog = load(CATALOG_PATH)
	var data: Dictionary = catalog.load_data()
	assert_dict(data).is_not_empty()
	assert_dict(catalog.recipe("electronic_component").cost).is_equal({"copper": 3, "crystal": 1})
	assert_int(catalog.recipe("electronic_component").amount).is_equal(2)
	assert_dict(catalog.recipe("structural_component").cost).is_equal({"iron": 4})
	assert_dict(catalog.assembly_cost("laboratory")).is_equal({"structural_component": 4, "electronic_component": 2})
	assert_dict(catalog.assembly_cost("lamp")).is_equal({"electronic_component": 1})
	var bad := data.duplicate(true)
	bad.recipes.electronic_component.cost = {"stone": 1}
	assert_dict(catalog.validate(bad)).is_empty()
	bad = data.duplicate(true)
	bad.recipes.structural_component.amount = -1
	assert_dict(catalog.validate(bad)).is_empty()

func test_components_use_partial_stacks_and_atomic_payments() -> void:
	var cargo := Cargo.new()
	cargo.enable_drone_only(2)
	assert_bool(cargo.collect("structural_component", 5, true)).is_true()
	assert_int(cargo.used(cargo.drone)).is_equal(2)
	assert_bool(cargo.pay({"structural_component": 1}, true)).is_true()
	assert_int(cargo.used(cargo.drone)).is_equal(1)
	assert_bool(cargo.collect("electronic_component", 4, true)).is_true()
	var before := cargo.snapshot()
	assert_bool(cargo.pay({"structural_component": 5, "electronic_component": 1}, true)).is_false()
	assert_dict(cargo.snapshot()).is_equal(before)
	assert_bool(cargo.pay({"structural_component": 2, "electronic_component": 3}, false)).is_false()
	assert_dict(cargo.snapshot()).is_equal(before)

func test_partial_stack_transfer_and_json_capacity_do_not_lose_pieces() -> void:
	var cargo := Cargo.new()
	cargo.enable_drone_only(2)
	cargo.collect("electronic_component", 8, true)
	var store := {"electronic_component": 3}
	assert_int(cargo.deposit(store, 1, true)).is_greater(0)
	assert_int(store.electronic_component).is_equal(4)
	assert_int(cargo.drone.electronic_component).is_equal(7)
	assert_bool(cargo.restore(JSON.parse_string(JSON.stringify(cargo.snapshot())))).is_true()
	assert_bool(Cargo.valid_stock({"electronic_component": 8.0}, 2)).is_true()
	assert_bool(Cargo.valid_stock({"electronic_component": 9}, 2)).is_false()
	assert_int(cargo.collectible("electronic_component", true)).is_equal(1)
