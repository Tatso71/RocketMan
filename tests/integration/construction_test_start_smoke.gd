extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func run() -> void:
	var campaign: Node2D = load("res://scenes/prototype/expedition.tscn").instantiate()
	root.add_child(campaign)
	campaign.set_process(false)
	var ship: RefCounted = campaign.model.ship
	var supplied := "--construction-test" in OS.get_cmdline_user_args()
	var cargo: RefCounted = ship.field_cargo
	check(int(cargo.drone.get("structural_component", 0)) == (24 if supplied else 0), "structural stock is supplied only in construction-test mode")
	check(int(cargo.drone.get("electronic_component", 0)) == (40 if supplied else 0), "electronic stock is supplied only in construction-test mode")
	check(cargo.used(cargo.drone) <= cargo.drone_capacity, "test supplies fit Robbie's real stack capacity")
	check(not ship.lab_research_unlocked, "first laboratory still unlocks lights normally")
	check(campaign.arrive_immediately(), "test campaign can land on Ocra")
	check(campaign.world.field_cargo == cargo, "landing preserves shared test resources")
	var restored: RefCounted = load("res://scripts/systems/ship_state.gd").new()
	check(restored.restore(JSON.parse_string(JSON.stringify(ship.snapshot()))), "test supplies are valid in a regular JSON ship snapshot")
	if supplied:
		check(cargo.pay({"structural_component": 4, "electronic_component": 2}, true), "one laboratory consumes its normal components")
		check(int(cargo.drone.get("structural_component", 0)) == 20 and int(cargo.drone.get("electronic_component", 0)) == 38, "construction remains paid rather than becoming free")
	print("CONSTRUCTION TEST START: %d failures" % failures)
	quit(1 if failures else 0)
