extends SceneTree

const Icons = preload("res://scripts/data/item_icon_catalog.gd")
const UI = preload("res://scripts/ui/field_inventory_ui.gd")
const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var capture := false

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func frames() -> void:
	for index in range(5):
		await physics_frame

func picture(name: String, target: Viewport = root) -> void:
	if capture:
		await frames()
		await RenderingServer.frame_post_draw
		check(target.get_texture().get_image().save_png("res://reports/" + name + ".png") == OK, "capture " + name)

func fits(node: Node, bounds: Rect2) -> bool:
	if node is ScrollContainer:
		if not bounds.grow(1).encloses(node.get_global_rect()):
			return false
		for child in node.get_children():
			if child is Container and child.get_combined_minimum_size().x > node.size.x + 1:
				print("Horizontal scroll overflow: ", child)
				return false
		return true
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and not bounds.grow(1).encloses(child.get_global_rect()):
			print("Overflow: ", child, " ", child.get_global_rect(), " / ", bounds)
			return false
		if not fits(child, bounds):
			return false
	return true

func check_menu(menu: PopupMenu) -> void:
	for index in range(menu.item_count):
		if not menu.is_item_separator(index):
			check(menu.get_item_icon(index) != null, "menu item has icon: " + menu.get_item_text(index))

func run() -> void:
	create_timer(70).timeout.connect(func(): quit(2))
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var sheet := ColorRect.new()
	sheet.color = Color("222b2e")
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	var column := VBoxContainer.new()
	column.position = Vector2(30, 20)
	column.size = Vector2(1220, 680)
	column.add_theme_constant_override("separation", 16)
	sheet.add_child(column)
	column.add_child(UI.label("ROCKETMAN / OGGETTI", 24))
	var grid := GridContainer.new()
	grid.columns = 9 if Icons.catalog().icons.size() > 48 else 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for id: String in Icons.catalog().icons:
		var texture := Icons.texture(id)
		check(texture != null, "imported texture " + id)
		if texture != null:
			var pixels := texture.get_image()
			var opaque := 0
			for y in range(pixels.get_height()):
				for x in range(pixels.get_width()):
					if pixels.get_pixel(x, y).a > 0.1:
						opaque += 1
			check(opaque > 80 and opaque < pixels.get_width() * pixels.get_height() * 0.95, "nonblank transparent icon " + id)
		var item := VBoxContainer.new()
		var item_width := 132 if grid.columns == 9 else 148
		item.custom_minimum_size = Vector2(item_width, 92)
		grid.add_child(item)
		item.add_child(Icons.view(id, 48))
		var name_label := UI.label(Icons.catalog().icons[id].name, 13)
		name_label.custom_minimum_size = Vector2(item_width, 36)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_child(name_label)
	await frames()
	check(fits(sheet, root.get_visible_rect()), "entire item-icon contact sheet fits 720p")
	await picture("item-icons-sheet")
	sheet.queue_free()
	await frames()
	var world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames()
	world.player.set_physics_process(false)
	world.drone.set_physics_process(false)
	world.guide_state.set_muted(true)
	Fixture.workshop(world)
	for id: String in UI.ITEM_IDS:
		world.local_store[id] = 4
	world.field_cargo.drone = {"copper": 2, "iron": 2, "structural_component": 4, "electronic_component": 4}
	var outpost = world.outpost
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await frames()
		outpost.cargo_ui.open_inventory()
		await frames()
		check(fits(outpost.cargo_ui.window, outpost.cargo_ui.window.get_visible_rect()), "inventory layout with icons fits " + str(size))
		check(outpost.cargo_ui.picker.size.y <= 44, "selected inventory icon does not inflate the transfer toolbar")
		await picture("item-icons-inventory-" + str(size.y), outpost.cargo_ui.window)
		outpost.cargo_ui.window.hide()
		outpost.construction.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
		await frames()
		check(outpost.construction.picker.visible, "production picker opens " + str(size))
		check(fits(outpost.construction.picker, outpost.construction.picker.get_visible_rect()), "production ingredients with icons fit " + str(size))
		await picture("item-icons-production-" + str(size.y), outpost.construction.picker)
		outpost.construction.picker.hide()
		for button: Button in world.tool_buttons:
			check(button.icon != null and root.get_visible_rect().encloses(button.get_global_rect()), "tool icon and slot fit " + button.text)
		await picture("item-icons-hud-" + str(size.y))
	root.size = Vector2i(1280, 720)
	world.guide_state.facts.lab_built = true
	outpost.construction.open_picker(Vector2i.ZERO, Vector2.ZERO, true)
	await frames()
	check(outpost.construction.recipe_rows.size() == 5, "first laboratory reveals all five production recipes with icons")
	check(fits(outpost.construction.picker, outpost.construction.picker.get_visible_rect()), "advanced long recipe names and icons fit 720p")
	await picture("item-icons-production-advanced", outpost.construction.picker)
	outpost.construction.picker.hide()
	outpost.assembly.open_picker(Vector2i.ZERO, Vector2(400, 220))
	check(outpost.assembly.rows.size() == 8, "all unlocked structures and the free ladder stay selectable")
	for row: Button in outpost.assembly.rows.values():
		check(row.item_icon.texture != null, "assembly row has an item icon")
	check(outpost.assembly.rows.has(0) and outpost.assembly.rows.has(100), "compact rows preserve assembly IDs")
	outpost.assembly.popup.hide()
	outpost.industry_ui.open_tools()
	for index in range(3):
		check(outpost.industry_ui.menu.get_item_icon(index) != null, "conduit menu has icon")
	outpost.industry_ui.menu.hide()
	world.queue_free()
	await frames()
	print("Item icons smoke: %d failures" % failures)
	quit(1 if failures else 0)
