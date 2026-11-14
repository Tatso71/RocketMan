extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Ship = preload("res://scripts/systems/ship_state.gd")
var world: Node2D
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.outpost.set_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	world.ship_state = Ship.new()
	world.ship_state.modules.drill = 3
	var cell := Vector2i(-10, 3)
	for x in [-2, -1]:
		for y in [-1, 0, 1]: Fixture.carve(world, cell + Vector2i(x, y))
	Fixture.carve(world, cell + Vector2i.RIGHT)
	world.environment.water[cell + Vector2i.RIGHT] = 1.0
	world.player.position = world.Grid.center(cell) + Vector2(-60, 28)
	world.target_cell = cell
	for index in range(3): await physics_frame
	check(world.outpost.hydraulics.place("valve", cell, world.outpost), "mount a real valve on exposed rock beside water")
	var material: String = world.site.material(cell)
	for id: String in ["pulse", "resonator", "plasma"]:
		world.ship_state.tool_slots[0] = id
		world.ship_state.active_tool_slot = 0
		var energy: float = world.ship_energy()
		var personal: float = world.crew_energy()
		var damage: Dictionary = world.site.damage.duplicate()
		world.mine_timer = 0
		world._mine_target()
		check(world.site.material(cell) == material and world.site.damage == damage, id + " cannot damage the valve's rock")
		check(not world.outpost.hydraulics.at(cell).is_empty(), id + " leaves the mounted valve intact")
		check(world.ship_energy() == energy and world.crew_energy() == personal and world.beam_time == 0, id + " refuses without energy cost or mining beam")
		check(world.target_blocker(cell).contains("Rimuovi valvola"), "refusal explains the right-click removal action")
	var ui: Node2D = world.outpost.hydraulic_ui
	var right := InputEventMouseButton.new()
	right.position = world.get_global_transform_with_canvas() * world.Grid.center(cell)
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	check(world.outpost.handle_input(right) and ui.window.visible, "right click opens the mounted valve panel")
	check(ui.remove_button.text == "Rimuovi valvola", "panel explicitly names valve removal")
	ui.remove_button.pressed.emit()
	check(world.outpost.hydraulics.at(cell).is_empty() and world.site.material(cell) == material, "removal button removes the valve without excavating its rock")
	world.ship_state.tool_slots[0] = "pulse"
	for index in range(15):
		if world.site.material(cell).is_empty(): break
		world.mine_timer = 0
		world._mine_target()
	check(world.site.material(cell).is_empty(), "rock becomes mineable again after explicit valve removal")
	print("VALVE BEAM PROTECTION: %d failures" % failures)
	quit(1 if failures else 0)
