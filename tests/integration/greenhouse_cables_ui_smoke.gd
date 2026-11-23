extends "res://tests/integration/mouse_pipe_stroke_smoke.gd"

func stock(amount: int) -> void:
	world.field_cargo.backpack.clear()
	world.field_cargo.drone.clear()
	Fixture.support(world)
	world.field_cargo.drone_available = true
	check(world.field_cargo.collect("electronic_component", amount, true), "fixture carries cable components")

func energy_tool() -> void:
	ui._choose_tool(2)
	check(ui.mode == "energy", "energy menu entry selects cable tool")

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
	ui = world.outpost.industry_ui
	ui.set_process(false)
	for x in range(-11, -4):
		for y in range(1, 7): Fixture.carve(world, Vector2i(x, y))
	world.player.position = Grid.center(Vector2i(-8, 3)) + Vector2(0, world.player.body_size().y / 2)
	for index in range(3): await physics_frame
	var direct := false
	for index in range(ui.menu.item_count):
		if ui.menu.get_item_id(index) == 2: direct = true
	check(direct, "T menu exposes Cavo energia directly alongside water")
	stock(10)
	energy_tool()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(motion(Vector2i(-6, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	for x in range(-10, -5):
		check(world.outpost.network.cells.energy.has(Vector2i(x, 3)), "sparse cable stroke fills cell " + str(x))
	check(world.field_cargo.available("electronic_component", true) == 5, "five cable metres consume five electronic components")
	check(not ui.dragging, "cable mouse release stops stroke")
	var paid: Dictionary = world.field_cargo.snapshot()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	check(world.field_cargo.snapshot() == paid, "duplicate cable stroke never charges twice")
	world.outpost.network.add("water", Vector2i(-8, 3))
	world.ladders[Vector2i(-8, 3)] = true
	ui.handle_input(button(Vector2i(-10, 3), true, true))
	ui.handle_input(motion(Vector2i(-6, 3), true))
	ui.handle_input(button(Vector2i(-6, 3), false, false))
	check(world.outpost.network.cells.energy.is_empty(), "Shift cable drag removes all crossed cables even when Shift releases first")
	check(world.outpost.network.cells.water.has(Vector2i(-8, 3)) and world.ladders.has(Vector2i(-8, 3)), "cable eraser preserves crossing water and ladder")
	check(world.field_cargo.snapshot() == paid, "removing cables creates no refund or charge")
	stock(10)
	energy_tool()
	ui.handle_input(button(Vector2i(-10, 2)))
	ui.handle_input(button(Vector2i(-7, 5), false))
	check(world.outpost.network.connected("energy", Vector2i(-10, 2), Vector2i(-7, 5)), "diagonal cable release creates continuous cardinal elbows")
	for cell: Vector2i in world.outpost.network.cells.energy.keys(): world.outpost.network.remove("energy", cell)
	stock(2)
	energy_tool()
	ui.handle_input(button(Vector2i(-10, 3)))
	ui.handle_input(motion(Vector2i(-6, 3)))
	ui.handle_input(button(Vector2i(-6, 3), false))
	check(world.outpost.network.cells.energy.size() == 2 and not world.outpost.network.cells.energy.has(Vector2i(-8, 3)), "stroke stops when outpost rejects unaffordable cable")
	energy_tool()
	ui.handle_input(button(Vector2i(-10, 3), true, false, MOUSE_BUTTON_RIGHT))
	check(ui.mode.is_empty() and not ui.dragging, "right click cancels cable tool")
	ui.handle_input(key_p())
	check(ui.mode == "water", "P remains the free water shortcut")
	var greenhouse: Dictionary = world.outpost.buildings.install("greenhouse", Vector2i(-8, 2))
	ui.open_machine(greenhouse)
	check(ui.reserves.text.contains("Porta energia [-8, 4]"), "greenhouse panel includes its energy socket coordinates, not only water")
	check(ui.reserves.text.contains("Fonte:"), "greenhouse panel explicitly labels its energy source")
	for x in range(-8, -5): world.outpost.network.add("energy", Vector2i(x, 4))
	for y in range(-2, 5): world.outpost.network.add("energy", Vector2i(-6, y))
	var storage: Dictionary = world.outpost.industry.state(greenhouse)
	storage.crop = "potato"
	storage.water = 4.0
	world._set_ship_energy(0)
	ui.refresh()
	check(ui.reserves.text.contains("Fonte: Nave [-6, -2] / cavo collegato"), "empty battery retains the actual wired ship source and navigation coordinates")
	check(ui.status.text == "Batteria della nave scarica", "panel distinguishes an empty battery from a disconnected cable")
	var converter: Dictionary = world.outpost.buildings.install("gas_converter", Vector2i(-11, 2))
	var converter_state: Dictionary = world.outpost.industry.state(converter)
	converter_state.energy = 1.0
	converter_state.produced = 1.0
	for cell: Vector2i in [Vector2i(-10, 3), Vector2i(-10, 4), Vector2i(-9, 4)]: world.outpost.network.add("energy", cell)
	ui.refresh()
	check(ui.reserves.text.contains("Fonte: Convertitore [-10, 3]"), "panel names the charged converter actually supplying power when the connected ship is empty")
	world.outpost.advance(0.25)
	check(storage.elapsed > 0 and converter_state.energy < 1 and world.ship_energy() == 0, "displayed fallback source matches real crop debit")
	world.outpost.buildings.structures.erase(converter)
	world.outpost.industry.machines.erase(world.outpost.Industry.key(converter))
	world.outpost.network.remove("energy", Vector2i(-6, -2))
	ui.refresh()
	check(ui.reserves.text.contains("Fonte: nessuna") and ui.status.text.contains("senza fonte"), "cut source reports a source-less cable rather than an empty battery")
	for cell: Vector2i in world.outpost.network.cells.energy.keys(): world.outpost.network.remove("energy", cell)
	world.outpost.buildings.install("laboratory", Vector2i(-11, 1))
	world._set_ship_energy(20)
	ui.refresh()
	check(ui.reserves.text.contains("Fonte: Laboratorio [-11, 3] / collegamento locale automatico"), "nearby automatic laboratory remains labeled with its energy socket coordinates")
	ui.window.hide()
	print("GREENHOUSE CABLE UI: %d failures" % failures)
	quit(1 if failures else 0)
