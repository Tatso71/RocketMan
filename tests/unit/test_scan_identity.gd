extends GdUnitTestSuite

const Scanner = preload("res://scripts/ui/scanner_pulse_view.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Fluids = preload("res://scripts/data/fluid_catalog.gd")
const Icons = preload("res://scripts/data/item_icon_catalog.gd")
const Tools = preload("res://scripts/data/digital_tool_catalog.gd")
const Grid = preload("res://scripts/world/world_grid.gd")

class ScanWorld extends Node2D:
	const MATERIAL_NAMES := {"bedrock": "Roccia compatta"}
	var target_cell := Vector2i.ZERO
	var player: Node2D
	var locked := false
	var tool: Resource = preload("res://scripts/data/digital_tool_def.gd").new()
	func _init() -> void:
		tool.mode = "scan"
		tool.reach_metres = 4.0
		player = Node2D.new()
		player.position = Vector2(20, 52)
		add_child(player)
	func active_tool() -> Resource:
		return tool
	func controls_blocked() -> bool:
		return locked
	func player_center() -> Vector2:
		return player.position - Vector2(0, 32)

func test_identity_uses_catalogs_and_explains_hard_formations() -> void:
	var view: Node2D = auto_free(Scanner.new())
	assert_bool(view.has_method("material_identity")).is_true()
	if not view.has_method("material_identity"):
		return
	for kind: String in ["copper", "iron", "crystal", "silica", "cobalt", "water", "acid", "oil", "gas"]:
		var identity: Dictionary = view.call("material_identity", kind, {})
		assert_str(identity.name).is_not_empty()
		assert_str(identity.icon).is_equal(Icons.path(kind))
		assert_bool(identity.color == (Fluids.KINDS[kind].edge if Fluids.KINDS.has(kind) else Cargo.COLORS[kind])).is_true()
	assert_str(view.call("material_identity", "copper", {"copper": "Rame locale"}).name).is_equal("Rame locale")
	var anchor: Dictionary = view.call("material_identity", "anchor", {})
	assert_str(anchor.name).is_equal("Indistruttibile")
	assert_str(anchor.detail.to_lower()).contains("aggirare")
	var bedrock: Dictionary = view.call("material_identity", "bedrock", {})
	assert_str(bedrock.name).is_equal("Roccia compatta")
	assert_str(bedrock.detail).contains("Plasma")
	assert_str(view.call("material_identity", "cobalt", {}).detail).contains("Risonatore")
	assert_dict(view.call("material_identity", "unknown", {})).is_empty()

func test_identification_ranges_are_capped_without_changing_detection() -> void:
	var tool: Resource = Tools.find("scanner").duplicate()
	assert_bool(tool.has_method("identification_reach_metres")).is_true()
	if not tool.has_method("identification_reach_metres"):
		return
	var identification := [2.5, 4.0, 5.5, 7.0]
	var detection := [4.0, 5.0, 6.0, 7.0]
	for index in range(4):
		tool.scanner_level = index + 1
		assert_float(tool.call("identification_reach_metres")).is_equal(identification[index])
		assert_float(tool.effective_reach_metres()).is_equal(detection[index])
	tool.scanner_level = 0
	assert_float(tool.call("identification_reach_metres")).is_equal(2.5)
	tool.scanner_level = 99
	assert_float(tool.call("identification_reach_metres")).is_equal(7.0)
	tool.scanner_level = 1
	tool.reach_metres = 1.0
	assert_float(tool.call("identification_reach_metres")).is_equal(1.0)
	tool.mode = "mine"
	assert_float(tool.call("identification_reach_metres")).is_equal(0.0)

func test_aimed_readout_never_falls_back_to_historical_or_unrevealed_cells() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	var cell := Vector2i(3, 4)
	world.player.position = Grid.center(cell) + Vector2(0, 32)
	assert_dict(view.call("aimed_identity", cell)).is_empty()
	view.revealed[cell] = {"kind": "bedrock", "until": 2.0, "duration": 2.0}
	assert_str(view.call("aimed_identity", cell).name).is_equal("Roccia compatta")
	assert_dict(view.call("aimed_identity", Vector2i.ZERO)).is_empty()
	view.clock = 2.0
	assert_dict(view.call("aimed_identity", cell)).is_empty()

func test_identity_uses_current_torso_distance_at_every_level() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	var cell := Vector2i(4, 4)
	view.revealed[cell] = {"kind": "iron", "until": 2.0, "duration": 2.0}
	var ranges := [100.0, 160.0, 220.0, 280.0]
	for index in range(4):
		world.tool.scanner_level = index + 1
		world.player.position = Grid.center(cell) + Vector2(ranges[index], 32)
		assert_str(view.aimed_identity(cell).get("kind", "")).is_equal("iron")
		world.player.position.x += 0.1
		assert_dict(view.aimed_identity(cell)).is_empty()
		world.player.position = Grid.center(cell) + Vector2(0, 32)
		assert_str(view.aimed_identity(cell).get("kind", "")).is_equal("iron")
	world.tool.mode = "mine"
	assert_dict(view.aimed_identity(cell)).is_empty()
	world.tool.mode = "scan"
	world.locked = true
	assert_dict(view.aimed_identity(cell)).is_empty()

func test_cobalt_needs_level_three_even_when_close() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	view.revealed[Vector2i.ZERO] = {"kind": "cobalt", "until": 2.0, "duration": 2.0}
	for level in [1, 2]:
		world.tool.scanner_level = level
		assert_dict(view.aimed_identity(Vector2i.ZERO)).is_empty()
	for level in [3, 4]:
		world.tool.scanner_level = level
		assert_str(view.aimed_identity(Vector2i.ZERO).get("kind", "")).is_equal("cobalt")

func test_each_revealed_cell_has_a_centered_icon_without_grouping() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	assert_bool(view.has_method("cell_marker")).is_true()
	if not view.has_method("cell_marker"):
		return
	for cell: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]:
		view.revealed[cell] = {"kind": "copper", "until": 2.0, "duration": 2.0}
		var marker: Dictionary = view.call("cell_marker", cell)
		assert_bool(marker.rect.get_center() == Grid.center(cell)).is_true()
		assert_bool(Grid.rect(cell).encloses(marker.rect)).is_true()
		assert_bool(marker.texture == Icons.texture("copper")).is_true()
		assert_bool(marker.identified).is_true()
	assert_dict(view.call("cell_marker", Vector2i.DOWN)).is_empty()
	view.clock = 1.0
	assert_float(view.call("cell_marker", Vector2i.ZERO).color.a).is_equal(0.5)
	view.clock = 2.0
	assert_dict(view.call("cell_marker", Vector2i.ZERO)).is_empty()
	view.clock = 0.0
	world.tool.mode = "mine"
	assert_dict(view.call("cell_marker", Vector2i.ZERO)).is_empty()
	world.tool.mode = "scan"
	world.locked = true
	assert_dict(view.call("cell_marker", Vector2i.ZERO)).is_empty()

func test_unknown_markers_do_not_leak_material_even_after_approaching_and_retreating() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	assert_bool(view.has_method("cell_marker")).is_true()
	if not view.has_method("cell_marker"):
		return
	var cell := Vector2i(3, 0)
	var unknown: Dictionary = {}
	for kind: String in ["iron", "crystal", "cobalt", "anchor", "bedrock", "water", "acid", "oil", "gas"]:
		view.revealed[cell] = {"kind": kind, "until": 2.0, "duration": 2.0}
		var marker: Dictionary = view.call("cell_marker", cell)
		assert_bool(marker.identified).is_false()
		assert_dict(view.aimed_identity(cell)).is_empty()
		assert_bool(marker.color.r == marker.color.g and marker.color.g == marker.color.b).is_true()
		assert_bool(marker.has("name") or marker.has("kind") or marker.has("detail")).is_false()
		if unknown.is_empty():
			unknown = marker
		else:
			assert_dict(marker).is_equal(unknown)
	view.revealed[cell].kind = "iron"
	world.player.position.x += 40
	assert_bool(view.call("cell_marker", cell).identified).is_true()
	world.player.position.x -= 40
	assert_dict(view.call("cell_marker", cell)).is_equal(unknown)
	var image: Image = unknown.texture.get_image()
	assert_bool(image.is_empty()).is_false()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			assert_bool(is_equal_approx(pixel.r, pixel.g) and is_equal_approx(pixel.g, pixel.b)).is_true()

func test_scanner_adds_no_standalone_controls_or_popup_layers() -> void:
	var world: Node2D = auto_free(ScanWorld.new())
	add_child(world)
	var view: Node2D = Scanner.new()
	view.world = world
	world.add_child(view)
	view.set_process(false)
	assert_array(view.find_children("*", "Control", true, false)).is_empty()
	assert_array(view.find_children("*", "CanvasLayer", true, false)).is_empty()

func test_only_recognized_cells_have_fading_content_borders() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	view.revealed[Vector2i.ZERO] = {"kind": "water", "until": 2.0, "duration": 2.0}
	view.revealed[Vector2i(3, 0)] = {"kind": "water", "until": 2.0, "duration": 2.0}
	var near: Dictionary = view.cell_marker(Vector2i.ZERO)
	assert_bool(near.has("border_rect") and near.has("border_color")).is_true()
	if not near.has("border_rect"):
		return
	assert_bool(near.border_rect == Grid.rect(Vector2i.ZERO).grow(-1)).is_true()
	assert_bool(near.border_color == Fluids.KINDS.water.edge).is_true()
	assert_bool(view.cell_marker(Vector2i(3, 0)).has("border_rect")).is_false()
	view.clock = 1.0
	assert_float(view.cell_marker(Vector2i.ZERO).border_color.a).is_equal(0.5)
	world.tool.mode = "mine"
	assert_dict(view.cell_marker(Vector2i.ZERO)).is_empty()

func test_hard_formation_markers_also_have_real_icons() -> void:
	var view: Node2D = auto_free(Scanner.new())
	var world: Node2D = auto_free(ScanWorld.new())
	view.world = world
	for kind: String in ["anchor", "bedrock"]:
		view.revealed[Vector2i.ZERO] = {"kind": kind, "until": 2.0, "duration": 2.0}
		assert_bool(view.cell_marker(Vector2i.ZERO).texture != null).is_true()
