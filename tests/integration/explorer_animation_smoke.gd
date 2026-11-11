extends SceneTree

const Explorer = preload("res://scripts/player/rocket_explorer.gd")
const Fixture = preload("res://tests/fixtures/dig_site_fixture.gd")
var failures := 0
var world: Node2D

class EmptyFabrication extends RefCounted:
	func carried() -> Dictionary: return {}

class PoseWorld extends Node2D:
	var beam_time := 0.0
	var beam_target := Vector2(160, -65)
	var robot := false
	var gear := {"flying": false}
	var outpost := {"fabrication": EmptyFabrication.new()}
	func active_tool() -> Resource: return preload("res://scripts/data/digital_tool_catalog.gd").find("pulse")
	func is_robbie() -> bool: return robot
	func suit_integrity() -> float: return 100.0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	print(("PASS: " if value else "FAIL: ") + description)
	if not value: failures += 1

func frames(count: int) -> void:
	for index in range(count): await physics_frame

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	world = load("res://scenes/prototype/rocket_home.tscn").instantiate()
	root.add_child(world)
	await frames(4)
	world.guide_state.set_muted(true)
	world.return_home()
	await frames(5)
	var collider: CollisionShape2D = world.player.get_child(0)
	var initial_size := Vector2(collider.shape.radius, collider.shape.height)
	Input.action_press("move_right")
	await frames(12)
	check(world.player.animation.state == "walk", "real horizontal input animates walking")
	Input.action_release("move_right")
	await frames(5)
	check(world.player.animation.state == "idle", "stopping returns to idle")
	world.player.position.x = 100
	Input.action_press("climb_up")
	await frames(12)
	check(world.player.animation.state == "climb_up", "ship ladder animates upward climbing")
	Input.action_release("climb_up")
	Input.action_press("climb_down")
	await frames(10)
	check(world.player.animation.state == "climb_down", "ship ladder animates downward climbing")
	Input.action_release("climb_down")
	await frames(3)
	check(world.player.animation.state == "climb_idle", "ladder idle holds its pose")
	world.return_home()
	await frames(4)
	Input.action_press("jump")
	await frames(3)
	check(world.player.animation.state == "jump", "normal jump has an airborne pose")
	Input.action_release("jump")
	var landed := false
	for index in range(90):
		await physics_frame
		landed = landed or world.player.animation.state == "land"
	check(landed, "real floor contact triggers the landing animation")
	world.return_home()
	world.equip_tool(3)
	world.gear.set_charge(100)
	await frames(4)
	Input.action_press("jump")
	await frames(3)
	check(world.player.animation.state == "jet_launch", "jetpack input starts with tucked launch legs")
	await frames(16)
	check(world.player.animation.state == "jetpack", "launch transitions to sustained flight")
	Input.action_release("jump")
	world.equip_tool(0)
	world.player.set_physics_process(false)
	Fixture.starter_tunnel(world)
	world.player.position = Vector2(-90, 160)
	world.target_cell = Vector2i(-3, 4)
	world.mine_timer = 0
	world._mine_target()
	check(world.player.animation.pose().recoil > 0, "an actual mining pulse triggers recoil")
	check(world.player.beam_origin().distance_to(world.player.position - Vector2(0, 32)) > 25, "beam starts at the weapon rather than the torso")
	var animation_clock: float = world.player.animation.clock
	world.controls_locked = true
	world.player.set_physics_process(true)
	await frames(3)
	check(not world.player._firing() and world.player.animation.pose().recoil == 0, "opening a menu cancels firing visuals")
	check(world.player.animation.clock == animation_clock, "menus pause locomotion animation")
	world.player.set_physics_process(false)
	world.controls_locked = false
	world.equip_tool(1)
	check(world.player.animation.pose().recoil == 0, "changing tool clears recoil")
	world.player.mining_pulse()
	world.equip_tool(0)
	world.beam_time = 0.24
	world.beam_tool = world.active_tool()
	world.return_home()
	check(world.player.animation.state == "idle" and world.player.animation.pose().recoil == 0 and not world.player._firing() and world.beam_time == 0, "teleport resets animation and stale beam")
	check(Vector2(collider.shape.radius, collider.shape.height) == initial_size and world.player.scale == Vector2.ONE and world.player.rotation == 0, "all poses preserve collider and physics transform")
	if "--capture" in OS.get_cmdline_user_args():
		await contact_sheet()
	print("EXPLORER ANIMATION: %d failures" % failures)
	quit(1 if failures else 0)

func contact_sheet() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("15232c")
	viewport.add_child(background)
	var names := ["Idle", "Cammina A", "Cammina B", "Salto", "Partenza jetpack", "Jetpack", "Caduta", "Atterraggio", "Scala su", "Scala giu", "Raggio destra", "Raggio sinistra"]
	var actors: Array[Node2D] = []
	for index in range(names.size()):
		var stage := PoseWorld.new()
		stage.position = Vector2(160 + (index % 4) * 320, 184 + (index / 4) * 235)
		viewport.add_child(stage)
		var label := Label.new()
		label.text = names[index]
		label.position = Vector2(-140, -175)
		label.add_theme_font_size_override("font_size", 20)
		stage.add_child(label)
		var actor := Explorer.new()
		actor.world = stage
		actor.scale = Vector2.ONE * 2
		stage.add_child(actor)
		actor.set_physics_process(false)
		actors.append(actor)
		actor.animation.advance(0.01, Vector2.ZERO, true, false, false)
		match index:
			1: actor.animation.advance(0.1, Vector2(190, 0), true, false, false)
			2: actor.animation.advance(0.35, Vector2(190, 0), true, false, false)
			3: actor.animation.advance(0.1, Vector2(0, -330), false, false, false)
			4: actor.animation.advance(0.01, Vector2(0, -120), false, false, true)
			5:
				actor.animation.advance(0.01, Vector2(120, -200), false, false, true)
				actor.animation.advance(0.3, Vector2(120, -200), false, false, true)
			6: actor.animation.advance(0.1, Vector2(0, 400), false, false, false)
			7:
				actor.animation.advance(0.1, Vector2(0, 500), false, false, false)
				actor.animation.advance(0.01, Vector2.ZERO, true, false, false)
				actor.animation.advance(0.1, Vector2.ZERO, true, false, false)
			8: actor.animation.advance(0.15, Vector2(0, -150), false, true, false)
			9: actor.animation.advance(0.15, Vector2(0, 150), false, true, false)
			10, 11:
				actor.facing = 1 if index == 10 else -1
				stage.beam_time = 0.2
				stage.beam_target = Vector2(actor.facing * 160, -65)
				actor.mining_pulse()
		actor.queue_redraw()
	await frames(4)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image.save_png("res://reports/explorer-poses-720.png") == OK, "save 720p animation contact sheet")
	check(image.get_region(Rect2i(70, 50, 180, 145)).get_data() != image.get_region(Rect2i(390, 50, 180, 145)).get_data(), "walking changes rendered character pixels")
	viewport.size = Vector2i(1920, 1080)
	viewport.canvas_transform = Transform2D(0, Vector2.ZERO).scaled(Vector2.ONE * 1.5)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png("res://reports/explorer-poses-1080.png") == OK, "save 1080p animation contact sheet")
	check(actors[10].beam_origin().x > 0 and actors[11].beam_origin().x < 0, "animated muzzle mirrors with the firing direction")
	var human_pixels := viewport.get_texture().get_image().get_region(Rect2i(100, 70, 280, 220)).get_data()
	actors[0].world.robot = true
	actors[0].mining_pulse()
	await frames(2)
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_region(Rect2i(100, 70, 280, 220)).get_data() != human_pixels, "playable Robbie still renders with the same animation integration")
	viewport.queue_free()
