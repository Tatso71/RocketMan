extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var world: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func frames(count: int = 4) -> void:
	for index in range(count): await physics_frame

func run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	world.field_cargo.drone_available = true
	world.field_cargo.drone = {"structural_component": 2}
	world.local_store = {"structural_component": 99, "electronic_component": 99}
	var view: Node = world.outpost.assembly
	check(view.has_method("refresh"), "compact assembly panel supports live cargo refresh")
	if not view.has_method("refresh"):
		quit(1)
		return
	view.open_picker(Vector2i(-2, 3), Vector2(1255, 690))
	await frames()
	check(view.rows.size() == 2 and view.rows.has(0) and view.rows.has(100), "before the first lab only laboratory and free ladder are listed")
	check(view.rows[0].resource_labels.structural_component.text == "2 / 4" and view.rows[0].resource_labels.electronic_component.text == "0 / 2", "owned/needed shows accessible cargo, never remote depot")
	check(not view.rows[0].affordable and not view.rows[0].disabled and view.rows[100].affordable, "unaffordable plans stay selectable while ladder remains free")
	check(not world.outpost.build_mode, "opening picker alone does not show a placement footprint")
	view.rows[0].pressed.emit()
	check(world.outpost.build_mode and world.outpost.blueprint == "laboratory" and not view.popup.visible, "gray row selects an unpaid blueprint and closes the popup")
	check(world.field_cargo.drone.structural_component == 2, "selection never spends or invents components")
	await frames()
	world.guide_state.facts.lab_built = true
	view.open_picker(Vector2i(-2, 3), Vector2(1255, 690))
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	view.refresh()
	check(view.rows.size() == 8 and view.rows[0].affordable and view.rows[1].affordable, "unlocked structures show live green affordability")
	world.drone.position = Vector2(800, 0)
	view.refresh()
	check(not view.rows[0].affordable and view.rows[0].resource_labels.structural_component.text == "0 / 4", "distant Robbie cargo is not advertised as available")
	Fixture.support(world)
	world.field_cargo.drone_available = true
	view.refresh()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	await frames()
	check(view.popup.visible and view.rows[0].has_focus(), "new popup opens with its first structure focused")
	view._popup_input(down)
	check(view.rows[1].has_focus(), "arrow navigation moves focus to the next structure")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	view._popup_input(escape)
	check(not view.popup.visible and not world.outpost.build_mode, "Escape closes picker without selecting a blueprint")
	world.field_cargo.drone = {"structural_component": 2, "electronic_component": 1}
	if "--capture" in OS.get_cmdline_user_args():
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = size
			await frames()
			view.open_picker(Vector2i(-2, 3), world.get_viewport_rect().size - Vector2(25, 30))
			await frames()
			var bounds: Rect2 = root.get_screen_transform() * root.get_visible_rect()
			var panel_bounds: Rect2 = view.popup.get_screen_transform() * view.popup.get_visible_rect()
			check(bounds.grow(1).encloses(panel_bounds), "popup remains inside native viewport " + str(size))
			for row: Button in view.rows.values():
				check(row.title.get_rect().end.x <= row.resource_labels.values()[0].get_parent().get_parent().position.x - 4 if not row.resource_labels.is_empty() else true, "name and cost tracks never overlap")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://reports/assembly-popup-%dp.png" % size.y) == OK, "capture compact assembly %dp" % size.y)
	view.popup.hide()
	await frames()
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "create an unpaid plan for popup funding")
	var site: Dictionary = world.outpost.buildings.structures.back()
	view.open_site(site)
	await frames()
	check(view.mount_button.disabled and view.rows[-1].resource_labels.structural_component.text == "2 / 4", "pending plan uses the same compact requirements and disables unpaid assembly")
	check(view.focus_order.back().has_focus(), "unaffordable project initially focuses cancellation rather than the disabled funding action")
	for action: Button in view.focus_order:
		check(view.popup.get_visible_rect().encloses(action.get_global_rect()), "project actions remain fully visible inside popup")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://reports/assembly-project-popup.png") == OK, "capture pending-project popup")
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	view.refresh()
	check(not view.mount_button.disabled, "funding action becomes available when accessible components are complete")
	view.mount_button.pressed.emit()
	check(site.state == "building" and world.field_cargo.used(world.field_cargo.drone) == 0 and not view.popup.visible, "funding starts paid assembly exactly once and closes popup")
	await frames()
	world.outpost.advance(6)
	world.player.position = Vector2(-140, 160)
	Fixture.support(world)
	Fixture.carve(world, Vector2i(-6, 2))
	check(world.outpost.place("lamp", Vector2i(-6, 2)), "create an unpaid device plan for cancellation")
	var pending: Dictionary = world.outpost.buildings.structures.back()
	world.player.position = Vector2(-180, 150)
	view.open_site(pending)
	await frames()
	view.focus_order.back().pressed.emit()
	check(not world.outpost.buildings.structures.has(pending) and world.field_cargo.used(world.field_cargo.drone) == 0, "cancel action removes plan without creating free components")
	await frames()
	world.player.position = Vector2(20, 160)
	world.ladders.erase(Vector2i(0, 3))
	view.open_picker(Vector2i(0, 3), Vector2(500, 300))
	view.rows[100].pressed.emit()
	check(world.ladders.has(Vector2i(0, 3)) and world.field_cargo.used(world.field_cargo.drone) == 0, "free ladder still builds immediately from compact picker")
	print("ASSEMBLY POPUP: %d failures" % failures)
	quit(1 if failures else 0)
