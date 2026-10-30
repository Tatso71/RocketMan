extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
var failures := 0
var world: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func picture(name: String, viewport: Viewport = null) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	world._refresh_hud()
	world.queue_redraw()
	world.gear.queue_redraw()
	await frames(4)
	await RenderingServer.frame_post_draw
	var target: Viewport = root if viewport == null else viewport
	check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, name + " screenshot")

func _run() -> void:
	create_timer(120).timeout.connect(func(): push_error("Equipment test timeout"); quit(2))
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.guide_state.set_muted(true)
	world.guide._update_bubble()
	check(world.field_cargo.drone_only and world.field_cargo.drone_capacity == 20 and world.field_cargo.backpack.is_empty(), "all new cargo belongs to Robbie with the original total capacity")
	check(world.equip_tool(2) and world.active_tool().tool_id == "bomb" and world.equip_tool(3) and world.active_tool().tool_id == "jetpack", "slots three and four select bomb and jetpack")
	world.equip_tool(0)
	world.set_hatch(true)
	for y in range(5):
		Fixture.carve(world, Vector2i(0, y))
		world.ladders[Vector2i(0, y)] = true
	world.player.position = Vector2(20, 200)
	for index in range(1000):
		if world.drone_can_collect():
			break
		await physics_frame
	print("DRONE EXIT: %s / %s" % [world.drone.position, world.drone.status])
	check(world.drone.position.y > 0 and world.drone_can_collect(), "Robbie leaves from the real cockpit through internal floors and the one-cell hatch")
	world.field_cargo.drone_available = true
	check(world.field_cargo.collect("soil", 20, true) and world.field_cargo.backpack.is_empty(), "only Robbie receives mined materials")
	check(world.drone.send_to_ship() and not world.drone_can_collect() and not world.field_cargo.collect("stone", 1, true), "Y dispatches real cargo and suspends collection while the drone is away")
	var delivery: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(delivery))) and world.drone.mission == "outbound", "a delivery resumes after save/load without duplicating its cargo")
	for index in range(1800):
		if world.drone.mission == "follow":
			break
		await physics_frame
	print("DRONE DELIVERY: %s / %s / %s" % [world.drone.position, world.drone.mission, world.drone.status])
	check(world.local_store.get("soil", 0) == 20 and world.field_cargo.used(world.field_cargo.drone) == 0, "Robbie physically reaches the workshop and unloads exactly once")
	check(world.drone.mission == "follow" and world.drone_can_collect(), "Robbie returns through the hatch into collecting range")
	world.drone.set_physics_process(false)
	for x in range(-13, 3):
		for y in range(2, 5):
			Fixture.carve(world, Vector2i(x, y))
	world.environment.gas.clear()
	world.environment.water.clear()
	world.environment.oil.clear()
	await frames(4)
	world.player.position = Vector2(-160, 140)
	world.drone.position = Vector2(-260, 100)
	await frames(4)
	world.field_cargo.drone_available = true
	check(world.field_cargo.collect("stone", 8, true) and world.field_cargo.collect("copper", 8, true), "prepare finite explosive and repair materials in Robbie")
	world.equip_tool(2)
	check(world.gear.place_bomb(Vector2i(-5, 4)), "first paid one-cell bomb is placed")
	await frames(3)
	check(world.gear.place_bomb(Vector2i(-3, 4)), "second paid bomb is placed")
	check(world.gear.bombs.size() == 2 and world.gear.bombs[0].number == 1 and world.gear.bombs[1].number == 2, "bombs have stable increasing placement numbers")
	check(world.gear.bombs[0].body.get_child(0).shape.size == Vector2(40, 40), "bomb collision occupies the full metre cell")
	check(not world.gear.detonate(), "Enter rejects unsafe detonation")
	var lab: Dictionary = world.outpost.buildings.install("laboratory", Vector2i(-10, 2))
	var lamp: Dictionary = world.outpost.buildings.install("lamp", Vector2i(-6, 4))
	world.guide_state.facts.lab_built = true
	world.player.position = Vector2(-420, 200)
	world.camera.position = Vector2(-180, 120)
	world.gear.queue_redraw()
	await picture("equipment-numbered-bombs-720p")
	var saved: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(saved))), "numbered physical bombs survive JSON save and restore")
	lab = world.outpost.buildings.structures[0]
	lamp = world.outpost.buildings.structures[1]
	world.field_cargo.drone_available = false
	check(world.gear.detonate(), "Enter arms the sequence at a safe distance")
	world.gear.advance(0.36)
	check(world.gear.bombs.size() == 1 and world.gear.bombs[0].number == 2, "the first placed bomb explodes first")
	check(lab.get("damaged", false) and lamp.get("damaged", false) and not world.outpost.operational(lab), "blast disables every nearby installation including its supplying lab")
	check(world.gear.particle_bursts > 0 and not world.gear.drops.is_empty(), "explosion emits particles and preserves uncollected materials on the ground")
	check(world.site.material(Vector2i(-5, 6)) == "anchor", "explosives cannot remove indestructible cores")
	world.player.position = Vector2(-100, 180)
	world.gear.advance(0.56)
	check(not world.gear.firing and world.gear.bombs.size() == 1, "returning inside the safety radius suspends remaining detonations")
	world.player.position = Vector2(-420, 200)
	world.gear.detonate()
	world.gear.advance(0.36)
	check(world.gear.bombs.is_empty() and not world.gear.firing, "remaining bombs detonate sequentially without double charging")
	await frames(3)
	await picture("equipment-blast-damage-720p")
	var damaged: Dictionary = world.capture_state()
	check(world.restore_state(JSON.parse_string(JSON.stringify(damaged))) and world.outpost.buildings.structures[0].damaged, "damaged installations and loose ore persist without becoming operational on load")
	lab = world.outpost.buildings.structures[0]
	world.player.position = Vector2(-420, 200)
	world.drone.position = Vector2(-380, 100)
	world.field_cargo.drone_available = true
	world.gear.repair_target = lab
	world.gear.repair_ship = false
	var before: int = world.field_cargo.drone.stone
	check(world.gear.repair_selected() and not lab.damaged and world.field_cargo.drone.stone == before - 3, "repair consumes required materials once and restores operation")
	check(not world.gear.repair_selected(), "intact installation cannot charge a duplicate repair")
	world.return_home()
	world.gear.set_charge(10)
	world.local_energy = 10
	world.gear.flying = false
	world.gear.advance(1)
	check(is_equal_approx(world.gear.charge(), 35) and world.local_energy < 10, "standing inside the ship lab recharges the separate jetpack battery using ship energy")
	world.local_energy = 0
	world.gear.advance(1)
	check(is_equal_approx(world.gear.charge(), 35), "empty supply battery cannot recharge the jetpack for free")
	world.local_energy = 20
	world.outpost.cargo_ui.open_inventory()
	world.gear._process(1)
	check(is_equal_approx(world.gear.charge(), 60), "passive jetpack charging continues while consulting a laboratory menu")
	world.outpost.cargo_ui.window.hide()
	world.gear.set_charge(35)
	world.player.position = Vector2(-320, 200)
	world.gear.advance(1)
	check(is_equal_approx(world.gear.charge(), 60), "standing inside an operational underground lab also recharges")
	lab.damaged = true
	world.gear.advance(1)
	check(is_equal_approx(world.gear.charge(), 60), "damaged lab cannot recharge the jetpack")
	world.player.position = Vector2(20, 180)
	world.player.velocity = Vector2.ZERO
	world.player.climbing = false
	world.gear.set_charge(100)
	world.equip_tool(3)
	world.player.set_physics_process(true)
	Input.action_press("jump")
	await frames(60)
	Input.action_release("jump")
	world.player.set_physics_process(false)
	check(world.player.position.y < 110 and world.gear.charge() < 90, "holding Space in slot four produces real upward flight and battery drain")
	world.gear.set_charge(0)
	Input.action_press("jump")
	check(not world.gear.thrust(1) and world.gear.charge() == 0, "empty jetpack has no thrust and cannot produce negative charge")
	Input.action_release("jump")
	world.equip_tool(0)
	world.player.position = Vector2(-500, 200)
	world.drone.position = Vector2(-460, 140)
	world.field_cargo.drone.clear()
	world.field_cargo.drone_available = true
	world.target_cell = Vector2i(-14, 4)
	await frames(3)
	world.mine_timer = 0
	var bursts: int = world.gear.particle_bursts
	world._mine_target()
	world.mine_timer = 0
	world._mine_target()
	check(world.gear.particle_bursts > bursts and world.field_cargo.used(world.field_cargo.drone) > 0 and world.field_cargo.backpack.is_empty(), "normal mining also emits debris and credits Robbie rather than a backpack")
	root.size = Vector2i(1920, 1080)
	world.camera.position = Vector2(-180, 120)
	await picture("equipment-cargo-1080p")
	world.outpost.cargo_ui.open_inventory()
	await picture("equipment-inventory-1080p", world.outpost.cargo_ui.window)
	world.outpost.cargo_ui.window.hide()
	# A blast against the ship's lower collar also disables the onboard workshop.
	Fixture.carve(world, Vector2i(-1, 0))
	world.site.removed.erase(Vector2i(0, 1))
	world.blocks[Vector2i(0, 1)] = world._body(world.Grid.rect(Vector2i(0, 1)), world.terrain)
	world.ladders.erase(Vector2i(0, 0))
	world.player.position = Vector2(-60, 0)
	world.drone.position = Vector2(-60, -50)
	world.field_cargo.drone_available = true
	world.field_cargo.collect("stone", 5, true)
	world.field_cargo.collect("copper", 4, true)
	world.equip_tool(2)
	await frames(4)
	check(world.gear.place_bomb(Vector2i(0, 0)), "bomb can be placed beside the lower ship collar")
	world.player.position = Vector2(-420, 200)
	world.gear.detonate()
	world.gear.advance(0.36)
	check(world.gear.workshop_damaged() and not world.outpost.station_available({"kind": "ship"}), "blast near the ship collar disables onboard workshop services")
	world.return_home()
	world.drone.position = Vector2(-120, -120)
	world.field_cargo.drone_available = true
	world.gear.set_charge(10)
	world.gear.flying = false
	world.gear.advance(1)
	check(world.gear.charge() == 10, "damaged onboard lab cannot recharge the jetpack")
	world.gear.repair_ship = true
	check(world.gear.repair_selected() and not world.gear.workshop_damaged(), "onboard workshop can be restored with finite repair materials")
	world.player.position = Vector2(20, 200)
	world.drone.position = Vector2(-60, 170)
	world.field_cargo.drone_available = true
	world.field_cargo.collect("copper", 1, true)
	await frames(4)
	check(world.gear.place_bomb(Vector2i(1, 4)), "prepare an unwanted bomb for safe removal")
	world.gear.disarm_target = world.gear.bombs[0]
	var paid: Dictionary = world.field_cargo.snapshot()
	check(world.gear.disarm_selected() and world.gear.bombs.is_empty() and world.field_cargo.snapshot() == paid, "right-click disarming removes the physical obstacle without refund duplication")
	world.return_home()
	world.equip_tool(3)
	world.gear.set_charge(80)
	world.outpost.fabrication.add_cube(Vector2(-80, -80), ["ship"])
	world.player.set_physics_process(true)
	await frames(8)
	Input.action_press("jump")
	await frames(6)
	check(world.outpost.fabrication.carried_id != 0 and absf(world.player.position.y + 80) < 1 and world.gear.charge() == 80, "Space picks up a cube without accidentally engaging the jetpack")
	Input.action_release("jump")
	await frames(4)
	Input.action_press("jump")
	await frames(6)
	check(world.outpost.fabrication.carried_id == 0 and absf(world.player.position.y + 80) < 1 and world.gear.charge() == 80, "Space drops a cube without launching the explorer")
	Input.action_release("jump")
	print("EQUIPMENT SMOKE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
