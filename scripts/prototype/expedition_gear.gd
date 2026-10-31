extends Node2D

const Grid = preload("res://scripts/world/world_grid.gd")
const Cargo = preload("res://scripts/systems/field_cargo.gd")
const Buildings = preload("res://scripts/systems/outpost_buildings.gd")
const BOMB_COST := {"stone": 1, "copper": 2}
const BOMB_CAPACITY := 4
const BLAST_RADIUS := Grid.CELL_SIZE * 2.0
const SAFE_DISTANCE := Grid.CELL_SIZE * 4.0
const MAX_BOMBS := 24
var world: Node2D
var bombs: Array = []
var drops: Dictionary = {}
var next_number := 1
var firing := false
var fuse := 0.0
var local_charge := 100.0
var local_workshop_damaged := false
var local_ammo := BOMB_CAPACITY
var flying := false
var repair_menu: PopupMenu
var repair_target: Dictionary = {}
var repair_ship := false
var particle_bursts := 0
var disarm_target: Dictionary = {}

func _ready() -> void:
	z_index = 8
	repair_menu = PopupMenu.new()
	repair_menu.prefer_native_menu = false
	repair_menu.id_pressed.connect(func(id: int):
		if id == 1:
			disarm_selected()
		else:
			repair_selected())
	add_child(repair_menu)

func charge() -> float:
	return world.ship_state.jetpack_charge if world.ship_state != null else local_charge

func set_charge(value: float) -> void:
	if world.ship_state != null:
		world.ship_state.jetpack_charge = clampf(value, 0, 100)
	else:
		local_charge = clampf(value, 0, 100)

func ammo() -> int:
	return world.ship_state.bomb_ammo if world.ship_state != null else local_ammo

func set_ammo(value: int) -> void:
	if world.ship_state != null:
		world.ship_state.bomb_ammo = clampi(value, 0, BOMB_CAPACITY)
	else:
		local_ammo = clampi(value, 0, BOMB_CAPACITY)

func workshop_damaged() -> bool:
	return world.ship_state.workshop_damaged if world.ship_state != null else local_workshop_damaged

func set_workshop_damage(value: bool) -> void:
	if world.ship_state != null:
		world.ship_state.workshop_damaged = value
	else:
		local_workshop_damaged = value

func thrust(delta: float) -> bool:
	flying = world.active_tool().mode == "jetpack" and charge() > 0 and not world.player_environment().wet and (Input.is_action_pressed("jump") or Input.is_action_pressed("climb_up"))
	if flying:
		set_charge(charge() - 20 * delta)
	return flying

func placement_blocker(cell: Vector2i) -> String:
	if firing or bombs.size() >= MAX_BOMBS:
		return "Sequenza in corso o limite di 24 bombe"
	if ammo() <= 0:
		return "Bombe esaurite: fabbricane altre al laboratorio"
	if not world.outpost.fabrication.carried().is_empty():
		return "Posa prima il cubo che trasporti"
	if not world.site.contains(cell) or not world.site.material(cell).is_empty() or not world.outpost.reachable_cell(cell):
		return "Posa la bomba in una cella libera entro 3 m"
	if world.site.material(cell + Vector2i.DOWN).is_empty():
		return "Serve un appoggio sotto la bomba"
	if Grid.rect(cell).intersects(Rect2(world.player.position - Vector2(12, 64), Vector2(24, 64))):
		return "Sposta il personaggio fuori dalla cella"
	if not world.is_robbie() and Grid.rect(cell).grow(10).has_point(world.drone.position):
		return "Aspetta che Robbie liberi la cella"
	if bombs.any(func(bomb: Dictionary): return bomb.cell == cell) or world.ladders.has(cell):
		return "Cella gia occupata"
	for building: Dictionary in world.outpost.buildings.structures:
		if world.outpost.buildings.footprint(building.id, building.origin).has_point(cell):
			return "La bomba non entra nell'installazione"
	for cube: Dictionary in world.outpost.fabrication.cubes:
		if cube.uid != world.outpost.fabrication.carried_id and Grid.rect(cell).intersects(Rect2(cube.position - Vector2(20, 40), Vector2(40, 40))):
			return "Sposta prima il cubo creatore"
	return ""

func place_bomb(cell: Vector2i) -> bool:
	var reason := placement_blocker(cell)
	if not reason.is_empty():
		world._note(reason)
		return false
	set_ammo(ammo() - 1)
	var bomb := {"cell": cell, "number": next_number}
	next_number += 1
	bombs.append(bomb)
	_add_body(bomb)
	world._note("Bomba %d posata / Scorte %d/%d / Enter da almeno 4 m" % [bomb.number, ammo(), BOMB_CAPACITY])
	return true

func _add_body(bomb: Dictionary) -> void:
	bomb.body = world._body(Grid.rect(bomb.cell), self)

func detonation_blocker() -> String:
	if bombs.is_empty():
		return "Nessuna bomba posata"
	var torso: Vector2 = world.player.position - Vector2(0, 32)
	for bomb: Dictionary in bombs:
		if Grid.center(bomb.cell).distance_to(torso) < SAFE_DISTANCE:
			return "Troppo vicino alla bomba %d / Distanza minima 4 m" % bomb.number
	return ""

func detonate() -> bool:
	if firing:
		return false
	var reason := detonation_blocker()
	if not reason.is_empty():
		world._note(reason)
		return false
	firing = true
	fuse = 0.35
	world._note("Sequenza armata / Mantieni la distanza di sicurezza")
	return true

func burst(point: Vector2, ink: Color, explosion: bool = false) -> void:
	var particles := CPUParticles2D.new()
	particles.position = point
	particles.amount = 42 if explosion else 18
	particles.lifetime = 0.7 if explosion else 0.5
	particles.one_shot = true
	particles.explosiveness = 1
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.gravity = Vector2(0, 330)
	particles.initial_velocity_min = 90 if explosion else 50
	particles.initial_velocity_max = 240 if explosion else 130
	particles.scale_amount_min = 2
	particles.scale_amount_max = 5
	particles.color = ink
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)
	particle_bursts += 1

func _explode(bomb: Dictionary) -> void:
	var point := Grid.center(bomb.cell)
	bomb.body.queue_free()
	burst(point, Color("f7b767"), true)
	for building: Dictionary in world.outpost.buildings.structures:
		var rect: Rect2 = world.outpost.buildings.world_rect(building)
		if point.distance_to(point.clamp(rect.position, rect.end)) <= BLAST_RADIUS:
			building.damaged = true
	var ship_collar := Rect2(world.HATCH_RECT.position, Vector2(world.HATCH_RECT.size.x, -world.HATCH_RECT.position.y))
	if point.distance_to(point.clamp(ship_collar.position, ship_collar.end)) <= BLAST_RADIUS:
		set_workshop_damage(true)
		if world.ship_state != null:
			world.ship_state.hull = maxf(0, world.ship_state.hull - 25)
	for y in range(bomb.cell.y - 2, bomb.cell.y + 3):
		for x in range(bomb.cell.x - 2, bomb.cell.x + 3):
			var cell := Vector2i(x, y)
			var kind: String = world.site.material(cell)
			if Grid.center(cell).distance_to(point) > BLAST_RADIUS or kind.is_empty() or kind in ["anchor", "bedrock"] or not world.outpost.mining_blocker(cell).is_empty():
				continue
			world.site.removed[cell] = true
			world.site.damage.erase(cell)
			world.remove_mined_block(cell, kind)
			drops[cell] = world.site.RESOURCE_YIELDS.get(kind, kind)
	for cell: Vector2i in world.ladders.keys():
		if cell.y >= 0 and Grid.center(cell).distance_to(point) <= BLAST_RADIUS:
			world.ladders.erase(cell)
			world.outpost.buildings.structures = world.outpost.buildings.structures.filter(func(item: Dictionary): return not (item.id == "ladder" and item.origin == cell))
	for kind: String in world.outpost.Network.KINDS:
		for cell: Vector2i in world.outpost.network.cells[kind].keys():
			if Grid.center(cell).distance_to(point) <= BLAST_RADIUS:
				world.outpost.network.remove(kind, cell)
	for breach: String in world.environment.detect_breaches():
		world.guide_event(breach + "_leak")
	world._note("Bomba %d esplosa / Installazioni colpite: riparazione necessaria" % bomb.number)

func advance(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	if firing:
		if not detonation_blocker().is_empty():
			firing = false
			world._note("Sequenza sospesa: sei troppo vicino. Allontanati e premi Enter")
		else:
			fuse -= delta
			if fuse <= 0:
				var bomb: Dictionary = bombs.pop_front()
				_explode(bomb)
				fuse = 0.55
				firing = not bombs.is_empty()
	recharge(delta)
	if world.drone_can_collect():
		for cell: Vector2i in drops.keys():
			if world.outpost.reachable_cell(cell) and world.field_cargo.collect(drops[cell], 1, true):
				drops.erase(cell)
	queue_redraw()

func recharge(delta: float) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	var station: Dictionary = world.outpost.nearby_station()
	var powered: bool = not station.is_empty() and not workshop_damaged() if station.get("kind") == "ship" else (not station.is_empty() and world.outpost.operational(station.building))
	if world.is_robbie() and powered and world.outpost.station_rect(station).has_point(world.player.position - Vector2(0, 32)):
		var charge_gain: float = minf(100 - world.crew_energy(), minf(20 * delta, world.ship_energy() / 0.02))
		world._set_crew_energy(world.crew_energy() + charge_gain)
		world._set_ship_energy(world.ship_energy() - charge_gain * 0.02)
		var repair_gain: float = minf(100 - world.suit_integrity(), minf(10 * delta, world.ship_energy() / 0.02))
		world._set_suit(world.suit_integrity() + repair_gain)
		world._set_ship_energy(world.ship_energy() - repair_gain * 0.02)
	if powered and world.outpost.station_rect(station).has_point(world.player.position - Vector2(0, 32)) and not flying and charge() < 100:
		var added: float = minf(100 - charge(), minf(25 * delta, world.ship_energy() / 0.02))
		set_charge(charge() + added)
		world._set_ship_energy(world.ship_energy() - added * 0.02)

func _process(delta: float) -> void:
	if not world.controls_locked and world.controls_blocked():
		flying = false
		recharge(delta)

func repair_cost() -> Dictionary:
	return {"stone": 3, "copper": 2} if repair_ship else Buildings.repair_cost(repair_target)

func repair_selected() -> bool:
	repair_menu.hide()
	if (repair_ship and (not world.aboard_workshop() or not workshop_damaged())) or (not repair_ship and (not world.outpost.buildings.structures.has(repair_target) or not repair_target.get("damaged", false) or not world.outpost.site_reachable(repair_target))):
		return false
	var cache: Dictionary = world.outpost.source_stock() if repair_ship else repair_target.stock
	if not world.field_cargo.pay(repair_cost(), world.drone_help_available(), cache):
		world._note("Materiali insufficienti per la riparazione")
		return false
	if repair_ship:
		set_workshop_damage(false)
	else:
		repair_target.damaged = false
	world._note("Riparazione completata")
	return true

func bomb_reachable(bomb: Dictionary) -> bool:
	var hand: Vector2 = world.player.position - Vector2(0, 32)
	if hand.distance_to(Grid.center(bomb.cell)) > Grid.metres(3):
		return false
	var query := PhysicsRayQueryParameters2D.create(hand, Grid.center(bomb.cell), 1, [world.player.get_rid(), world.drone.get_rid(), bomb.body.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func disarm_selected() -> bool:
	if firing or not bombs.has(disarm_target) or not bomb_reachable(disarm_target):
		return false
	disarm_target.body.queue_free()
	bombs.erase(disarm_target)
	disarm_target = {}
	world._note("Bomba disinnescata e rimossa / Nessun rimborso")
	return true

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_RIGHT:
		return false
	var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
	for bomb: Dictionary in bombs:
		if Grid.rect(bomb.cell).has_point(point) and bomb_reachable(bomb):
			disarm_target = bomb
			repair_menu.clear()
			repair_menu.add_item("Disinnesca bomba %d / Nessun rimborso" % bomb.number, 1)
			repair_menu.set_item_disabled(0, firing)
			repair_menu.popup(Rect2i(Vector2i(world.get_viewport().get_screen_transform() * event.position), Vector2i(390, 70)))
			return true
	repair_target = {}
	repair_ship = workshop_damaged() and world.outpost.SHIP_LAB_RECT.has_point(point) and world.aboard_workshop()
	if not repair_ship:
		for building: Dictionary in world.outpost.buildings.structures:
			if building.get("damaged", false) and world.outpost.buildings.world_rect(building).has_point(point) and world.outpost.site_reachable(building):
				repair_target = building
				break
	if not repair_ship and repair_target.is_empty():
		return false
	repair_menu.clear()
	repair_menu.add_separator("GUASTO / " + ("Laboratorio nave" if repair_ship else Buildings.NAMES.get(repair_target.id, "Struttura")))
	var parts: Array[String] = []
	for id: String in repair_cost():
		parts.append("%d %s" % [repair_cost()[id], Cargo.NAMES[id]])
	repair_menu.add_item("Ripara / " + " + ".join(parts), 0)
	repair_menu.popup(Rect2i(Vector2i(world.get_viewport().get_screen_transform() * event.position), Vector2i(380, 100)))
	return true

func snapshot() -> Dictionary:
	var saved: Array = []
	for bomb: Dictionary in bombs:
		saved.append({"cell": [bomb.cell.x, bomb.cell.y], "number": bomb.number})
	var resources: Array = []
	for cell: Vector2i in drops:
		resources.append({"cell": [cell.x, cell.y], "material": drops[cell]})
	return {"bombs": saved, "next_number": next_number, "drops": resources, "charge": charge(), "workshop_damaged": workshop_damaged(), "ammo": ammo()}

static func valid(data: Variant, site: RefCounted, buildings: RefCounted) -> bool:
	if not data is Dictionary or not data.get("bombs", []) is Array or not data.get("drops", []) is Array or data.get("bombs", []).size() > MAX_BOMBS or data.get("drops", []).size() > 1152:
		return false
	var sequence = data.get("next_number", 1)
	var battery = data.get("charge", 100)
	var ammunition = data.get("ammo", BOMB_CAPACITY)
	if not (ammunition is int or ammunition is float) or not is_finite(ammunition) or ammunition != floorf(ammunition) or ammunition < 0 or ammunition > BOMB_CAPACITY:
		return false
	if not (sequence is int or sequence is float) or not is_finite(sequence) or sequence < 1 or sequence != floorf(sequence) or sequence > 1000000 or not (battery is int or battery is float) or not is_finite(battery) or battery < 0 or battery > 100 or not data.get("workshop_damaged", false) is bool:
		return false
	var cells: Array = []
	var number := 0
	for bomb in data.get("bombs", []):
		if not bomb is Dictionary:
			return false
		var cell = Grid.decode_cell(bomb.get("cell"))
		var ordinal = bomb.get("number")
		if not cell is Vector2i or not site.contains(cell) or not site.material(cell).is_empty() or cell in cells or not (ordinal is int or ordinal is float) or not is_finite(ordinal) or ordinal != floorf(ordinal) or ordinal <= number or ordinal >= sequence:
			return false
		if buildings.structures.any(func(item: Dictionary): return buildings.footprint(item.id, item.origin).has_point(cell)):
			return false
		cells.append(cell)
		number = int(ordinal)
	cells.clear()
	for entry in data.get("drops", []):
		if not entry is Dictionary:
			return false
		var cell = Grid.decode_cell(entry.get("cell"))
		if not cell is Vector2i or not site.contains(cell) or not site.material(cell).is_empty() or cell in cells or entry.get("material") not in ["soil", "stone", "copper", "crystal"]:
			return false
		cells.append(cell)
	return true

func restore(data: Dictionary, restore_shared: bool) -> void:
	for bomb: Dictionary in bombs:
		bomb.body.queue_free()
	bombs.clear()
	drops.clear()
	firing = false
	repair_menu.hide()
	for entry: Dictionary in data.get("bombs", []):
		var bomb := {"cell": Grid.decode_cell(entry.cell), "number": int(entry.number)}
		bombs.append(bomb)
		_add_body(bomb)
	for entry: Dictionary in data.get("drops", []):
		drops[Grid.decode_cell(entry.cell)] = entry.material
	next_number = int(data.get("next_number", 1))
	if restore_shared and world.ship_state == null:
		set_ammo(int(data.get("ammo", BOMB_CAPACITY)))
		set_charge(float(data.get("charge", 100)))
		set_workshop_damage(data.get("workshop_damaged", false))

func _draw() -> void:
	for bomb: Dictionary in bombs:
		var rect := Grid.rect(bomb.cell)
		draw_rect(rect.grow(-3), Color("663d48"))
		draw_rect(rect.grow(-5), Color("da785c"), false, 3)
		draw_line(rect.position + Vector2(8, 10), rect.end - Vector2(8, 10), Color("f3d186"), 3)
		draw_circle(rect.get_center(), 5, Color("ffddd0") if firing else Color("df5658"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, -9), str(bomb.number), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("fff1ce"))
		if world.active_tool().mode == "bomb":
			draw_arc(rect.get_center(), SAFE_DISTANCE, 0, TAU, 64, Color(0.95, 0.4, 0.35, 0.25), 1)
	if world.active_tool().mode == "bomb":
		var rect := Grid.rect(world.target_cell).grow(-2)
		var ink := Color("9ae5af") if placement_blocker(world.target_cell).is_empty() else Color("ef737a")
		draw_rect(rect, Color(ink, 0.12))
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for index in range(4):
			draw_dashed_line(corners[index], corners[(index + 1) % 4], ink, 2, 7)
	for cell: Vector2i in drops:
		if world._illumination(Grid.center(cell)) > 0.1:
			draw_rect(Rect2(Grid.center(cell) - Vector2(5, 5), Vector2(10, 10)), Cargo.COLORS[drops[cell]])
	for building: Dictionary in world.outpost.buildings.structures:
		if building.get("damaged", false):
			var rect: Rect2 = world.outpost.buildings.world_rect(building)
			draw_rect(rect.grow(-2), Color(0.8, 0.2, 0.2, 0.22))
			draw_line(rect.position + Vector2(4, 4), rect.end - Vector2(4, 4), Color("ef7c79"), 3)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(2, -8), "GUASTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10 if rect.size.x <= 40 else 13, Color("ff9c8e"))
	if workshop_damaged():
		draw_rect(world.outpost.SHIP_LAB_RECT.grow(-4), Color("ef737a"), false, 3)
		draw_string(ThemeDB.fallback_font, Vector2(-148, -175), "LAB GUASTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff9c8e"))
	if flying:
		var base: Vector2 = world.player.position + Vector2(-world.player.facing * 11, -12)
		draw_line(base, base + Vector2(0, 24 + sin(world.ambient_time * 50) * 6), Color("f3d184"), 8)
		draw_line(base, base + Vector2(0, 17), Color("9de7f0"), 4)
