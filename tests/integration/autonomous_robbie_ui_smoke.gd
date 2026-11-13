extends SceneTree

const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
const Texts = preload("res://scripts/data/robbie_texts.gd")
var world: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func frames(count: int = 5) -> void:
	for index in range(count): await physics_frame

func status_label(view: Node) -> Label:
	for property: Dictionary in view.get_property_list():
		if property.name == "status_label": return view.get("status_label")
	return null

func setup(variant: String) -> void:
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	world.variant = variant
	root.add_child(world)
	await frames()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide.set_process(false)
	world.guide_state.set_muted(true)
	Fixture.lab_room(world)
	world.player.position = Vector2(-100, 160)
	Fixture.support(world)
	world.field_cargo.drone = {}
	world.local_store = {}

func layout(view: Node, size: Vector2i) -> void:
	root.size = size
	await frames()
	view.open_site(world.outpost.buildings.structures.back())
	await frames()
	var bounds: Rect2 = root.get_screen_transform() * root.get_visible_rect()
	var panel_bounds: Rect2 = view.popup.get_screen_transform() * view.popup.get_visible_rect()
	check(bounds.grow(1).encloses(panel_bounds), "project popup fits native viewport " + str(size))
	for action: Button in view.focus_order:
		check(view.popup.get_visible_rect().encloses(action.get_global_rect()), "project action fits " + str(size))
	var label := status_label(view)
	if label != null:
		check(view.popup.get_visible_rect().encloses(label.get_global_rect()), "queue status fits " + str(size))
		check(label.get_global_rect().end.y <= view.blocker_label.get_global_rect().position.y, "queue status and manual blocker do not overlap")

func show_message(id: String) -> String:
	world.guide_state.offer(id, true)
	world.guide.current_id = ""
	world.guide._update_bubble()
	return world.guide.speech.text

func run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	await setup("explorer")
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "human places unpaid laboratory")
	var site: Dictionary = world.outpost.buildings.structures.back()
	var view: Node = world.outpost.assembly
	world.local_store = {"structural_component": 5, "electronic_component": 1, "iron": 80}
	world.field_cargo.drone = {"structural_component": 2, "electronic_component": 1}
	world.drone.position = Vector2(800, 0)
	view.open_site(site)
	await frames()
	check(view.rows[-1].resource_labels.structural_component.text == "7 / 4" and view.rows[-1].resource_labels.electronic_component.text == "2 / 2", "human costs include finished ship stock and distant worker cargo")
	check(view.rows[-1].affordable and view.mount_button.disabled, "informational affordability does not fund a remote project")
	world.local_store.structural_component = 0
	view.refresh()
	check(not view.rows[-1].affordable and view.rows[-1].resource_labels.structural_component.text == "2 / 4", "live stock deficit updates queued costs without counting raw minerals")
	world.local_store.structural_component = 5
	Fixture.support(world)
	await frames()
	world.drone._rebuild()
	view.refresh()
	var label := status_label(view)
	check(label != null and label.text.contains("coda"), "queued project shows Robbie status separately from manual blocker")
	var stock_before: Dictionary = world.local_store.duplicate()
	var cargo_before: Dictionary = world.field_cargo.drone.duplicate()
	view.refresh()
	check(world.local_store == stock_before and world.field_cargo.drone == cargo_before and site.state == "planned", "popup refresh never transfers or spends stock")
	world.outpost.logistics.target = site
	world.drone.mission = "delivering"
	world.outpost.logistics.status = "Consegna al cantiere"
	await frames(12)
	check(label != null and label.text == "Consegna al cantiere", "open popup polls live worker delivery state")
	site.state = "building"
	site.automatic = true
	world.drone.mission = "building"
	world.outpost.logistics.status = "Montaggio in corso"
	view.refresh()
	check(label != null and label.text == "Montaggio in corso" and view.mount_button.disabled and view.focus_order.back().disabled, "paid construction shows live state without funding or cancellation actions")
	site.state = "planned"
	site.erase("automatic")
	world.outpost.logistics.reset()
	# Dummy headless subwindows expose minimum size, not the native popup size.
	if DisplayServer.get_name() != "headless":
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
			await layout(view, size)
	view.popup.hide()
	await frames()
	check(view.site.is_empty(), "closing popup releases project reference")
	view.open_site(site)
	world.outpost.buildings.structures.erase(site)
	view.refresh()
	check(not view.is_open() and view.site.is_empty(), "refresh closes a canceled project")
	view._choose(1000)
	check(world.local_store == stock_before and world.field_cargo.drone == cargo_before and site.state == "planned", "stale mount action cannot spend components")
	view.open_site(site)
	check(not view.is_open(), "removed project cannot reopen")
	var replacement: Dictionary = site.duplicate(true)
	world.outpost.buildings.structures.append(site)
	view.open_site(site)
	world.outpost.buildings.structures.erase(site)
	world.outpost.buildings.structures.append(replacement)
	view.refresh()
	check(not view.is_open() and view.site.is_empty(), "identical replacement does not preserve a stale project reference")
	world.outpost.buildings.structures.erase(replacement)
	world.outpost.buildings.structures.append(site)
	view.open_site(site)
	view.focus_order.back().pressed.emit()
	check(not world.outpost.buildings.structures.has(site) and view.site.is_empty(), "cancel button acts on selected project before releasing popup reference")
	world.outpost.buildings.structures.append(site)
	site.damaged = true
	view.open_site(site)
	view.popup.hide()
	view._choose(1001)
	check(not world.outpost.buildings.structures.has(site), "same-turn hide then choose cancels an unpaid damaged project")
	world.outpost.buildings.structures.append(site)
	site.erase("damaged")
	Fixture.support(world)
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	view.open_site(site)
	check(not view.mount_button.disabled, "human can optionally mount with real accessible cargo")
	view.mount_button.pressed.emit()
	check(site.state == "building" and world.field_cargo.used(world.field_cargo.drone) == 0 and view.site.is_empty(), "optional mount pays once and clears closed popup reference")
	world.outpost.logistics.automatic = false
	world.drone.position = Vector2(800, 0)
	view.open_picker(Vector2i(-2, 3), Vector2(500, 300))
	check(view.rows[0].resource_labels.structural_component.text == "0 / 4", "explicit manual test mode excludes remote stock")
	view.popup.hide()
	world.outpost.logistics.automatic = true
	world.drone.mission = "collecting"
	world.drone.status = "Percorso ostruito"
	check(world.guide.context() == "path_blocked", "blocked route takes precedence during autonomous missions")
	world.drone.status = "Raccolta minerali"
	world.local_energy = 0
	check(world.guide.context() == "energy_low", "power warning takes precedence during autonomous work")
	world.local_energy = 60
	world.drone.mission = "follow"
	world.guide_state.ocra.mark("lab_built")
	world.guide_state.seen.append("bed_rest")
	Fixture.support(world)
	world.field_cargo.drone = {"iron": 20}
	check(world.guide.context() != "cargo_full", "routine automatic full cargo does not interrupt with manual instructions")
	var human_fund := show_message("tutorial_fund")
	check(not human_fund.contains("Ritira") and human_fund.contains("primo") and human_fund.contains("coda"), "human funding speech explains complete project orders and strict FIFO")
	var human_production := show_message("ocra/laboratory_cube")
	check(human_production.contains("progetto") and not human_production.contains("Ordina 2 lotti"), "human production bubble explains preparation from the placed project")
	check(not show_message("cargo_full").contains("Con Y"), "human cargo bubble never requests Y")
	check(not show_message("drone_delivery").contains("scarico e torno da te"), "delivery speech covers work beyond return-to-follow")
	world.free()
	await setup("robbie")
	check(not world.outpost.logistics.enabled(), "controlled Robbie keeps manual logistics")
	check(world.outpost.place("laboratory", Vector2i(-5, 1)), "controlled Robbie places unpaid laboratory")
	site = world.outpost.buildings.structures.back()
	view = world.outpost.assembly
	world.local_store = {"structural_component": 99, "electronic_component": 99}
	world.field_cargo.drone = {"structural_component": 2, "electronic_component": 1}
	view.open_site(site)
	label = status_label(view)
	check(view.rows[-1].resource_labels.structural_component.text == "2 / 4" and view.mount_button.disabled, "controlled Robbie costs use only carried components")
	check(label == null or not label.visible, "controlled Robbie is not promised an autonomous worker")
	check(show_message("ocra/laboratory_cube").contains("Produci componenti") and show_message("ocra/carry_laboratory").contains("Ritira componenti"), "controlled Robbie retains manual production and collection tutorial")
	check(world.guide_state.message("ocra/laboratory_cube")[1] == "Produci i componenti", "controlled Robbie objective retains manual production title")
	check(show_message("cargo_full").contains("Y"), "controlled Robbie retains manual deposit instructions")
	world.field_cargo.drone = {"structural_component": 4, "electronic_component": 2}
	view.refresh()
	view.mount_button.pressed.emit()
	check(site.state == "building" and world.field_cargo.used(world.field_cargo.drone) == 0, "controlled Robbie manually mounts with a single payment")
	check(not Texts.validate(JSON.parse_string(FileAccess.get_file_as_string(Texts.PATH))).is_empty(), "authored variant catalog remains text-lab editable")
	world.free()
	print("AUTONOMOUS ROBBIE UI: %d failures" % failures)
	quit(1 if failures else 0)
