extends GdUnitTestSuite

const Cargo = preload("res://scripts/systems/field_cargo.gd")

func test_backpack_is_limited_and_drone_requires_local_availability() -> void:
	var cargo := Cargo.new()
	assert_bool(cargo.collect("soil", 8)).is_true()
	assert_bool(cargo.collect("soil", 1)).is_false()
	assert_bool(cargo.collect("soil", 12, true)).is_true()
	assert_int(cargo.used(cargo.backpack)).is_equal(8)
	assert_int(cargo.used(cargo.drone)).is_equal(12)
	assert_bool(cargo.collect("stone", 1, true)).is_false()

func test_withdraw_and_payment_are_atomic_and_use_only_accessible_stocks() -> void:
	var cargo := Cargo.new()
	var ship := {"stone": 6, "copper": 4}
	assert_bool(cargo.withdraw(ship, "stone", 6, true)).is_true()
	assert_bool(cargo.withdraw(ship, "copper", 4, true)).is_true()
	var before := cargo.snapshot()
	assert_bool(cargo.pay({"stone": 6, "copper": 4}, false)).is_false()
	assert_dict(cargo.snapshot()).is_equal(before)
	assert_bool(cargo.pay({"stone": 6, "copper": 4}, true)).is_true()
	assert_int(cargo.used(cargo.backpack) + cargo.used(cargo.drone)).is_equal(0)

func test_partial_deposit_preserves_items_that_do_not_fit() -> void:
	var cargo := Cargo.new()
	cargo.collect("soil", 8)
	var store := {"soil": 9}
	assert_int(cargo.deposit(store, 10, false)).is_equal(1)
	assert_int(cargo.backpack.soil).is_equal(7)
	assert_int(store.soil).is_equal(10)

func test_restore_preserves_inventory_reference_and_rejects_overfill() -> void:
	var cargo := Cargo.new()
	var pack: Dictionary = cargo.backpack
	assert_bool(cargo.restore({"backpack": {"lamp_kit": 2.0}, "drone": {}})).is_true()
	assert_int(int(pack.lamp_kit)).is_equal(2)
	assert_bool(cargo.restore({"backpack": {"soil": 9}, "drone": {}})).is_false()
	assert_int(int(pack.lamp_kit)).is_equal(2)
	assert_bool(cargo.restore({"backpack": {"unknown": 1}, "drone": {}})).is_false()

func test_nearby_lab_cache_can_fund_recipe_without_remote_ship_access() -> void:
	var cargo := Cargo.new()
	var cache := {"soil": 2, "copper": 2}
	assert_bool(cargo.pay({"soil": 1, "copper": 1}, false, cache)).is_true()
	assert_bool(cargo.collect("lamp_kit")).is_true()
	assert_int(cache.soil).is_equal(1)
	assert_int(cargo.backpack.lamp_kit).is_equal(1)
