extends RefCounted

const ITEM_IDS := ["soil", "stone", "copper", "crystal", "lamp_kit", "lab_cube", "copper_ingot", "glass", "potato", "ochre_tuber", "verdant_leaf", "frost_berry"]
const NAMES := {"soil": "Terra", "stone": "Pietra", "copper": "Rame", "crystal": "Cristallo", "lamp_kit": "Luce portatile", "lab_cube": "Cubo laboratorio", "copper_ingot": "Lingotto rame", "glass": "Vetro", "potato": "Patata", "ochre_tuber": "Tubero ocra", "verdant_leaf": "Verdura viridia", "frost_berry": "Bacca brina"}
const COLORS := {"soil": Color("cf8272"), "stone": Color("adb0bb"), "copper": Color("edbf75"), "crystal": Color("7be1da"), "lamp_kit": Color("fff3b2"), "lab_cube": Color("a7e5b4"), "copper_ingot": Color("e8a76c"), "glass": Color("a0dce4"), "potato": Color("e6d28b"), "ochre_tuber": Color("e4a57f"), "verdant_leaf": Color("a8db86"), "frost_berry": Color("c7acf0")}
const ITEM_UNITS := {"lab_cube": 4}
const PACK_CAPACITY := 8
var drone_capacity := 12
var backpack: Dictionary = {}
var drone: Dictionary = {}
var drone_only := false
var drone_available := true

func enable_drone_only(capacity: int = 20) -> void:
	drone_capacity = capacity
	drone_only = true
	for id: String in backpack:
		drone[id] = int(drone.get(id, 0)) + int(backpack[id])
	backpack.clear()

func unload_drone(stock: Dictionary, capacity: int) -> int:
	var transferred := 0
	for id: String in ITEM_IDS:
		var amount := mini(maxi(0, capacity - used(stock)) / item_units(id), int(drone.get(id, 0)))
		if amount > 0:
			stock[id] = int(stock.get(id, 0)) + amount
			drone[id] -= amount
			transferred += amount * item_units(id)
	return transferred

func used(stock: Dictionary) -> int:
	var total := 0
	for id: String in ITEM_IDS:
		total += int(stock.get(id, 0)) * item_units(id)
	return total

static func item_units(id: String) -> int:
	return ITEM_UNITS.get(id, 1)

func collectible(id: String, with_drone: bool) -> int:
	if drone_only:
		return maxi(0, drone_capacity - used(drone)) / item_units(id) if with_drone and drone_available else 0
	return (PACK_CAPACITY - used(backpack)) / item_units(id) + ((drone_capacity - used(drone)) / item_units(id) if with_drone else 0)

func free_space(with_drone: bool) -> int:
	if drone_only:
		return maxi(0, drone_capacity - used(drone)) if with_drone and drone_available else 0
	return PACK_CAPACITY - used(backpack) + (drone_capacity - used(drone) if with_drone else 0)

func collect(id: String, amount: int = 1, with_drone: bool = false) -> bool:
	if id not in ITEM_IDS or amount <= 0 or collectible(id, with_drone) < amount:
		return false
	if drone_only:
		drone[id] = int(drone.get(id, 0)) + amount
		return true
	var pack_amount := mini(amount, (PACK_CAPACITY - used(backpack)) / item_units(id))
	backpack[id] = int(backpack.get(id, 0)) + pack_amount
	if amount > pack_amount:
		drone[id] = int(drone.get(id, 0)) + amount - pack_amount
	return true

func available(id: String, with_drone: bool, cache: Dictionary = {}) -> int:
	if drone_only:
		return (int(drone.get(id, 0)) if with_drone and drone_available else 0) + int(cache.get(id, 0))
	return int(backpack.get(id, 0)) + (int(drone.get(id, 0)) if with_drone else 0) + int(cache.get(id, 0))

func can_pay(cost: Dictionary, with_drone: bool, cache: Dictionary = {}) -> bool:
	for id: String in cost:
		if id not in ITEM_IDS or not cost[id] is int or int(cost[id]) < 0 or available(id, with_drone, cache) < int(cost[id]):
			return false
	return true

func carried_sources(with_drone: bool) -> Array:
	var result: Array = []
	if not drone_only:
		result.append(backpack)
	if with_drone and (not drone_only or drone_available):
		result.append(drone)
	return result

func pay(cost: Dictionary, with_drone: bool, cache: Dictionary = {}) -> bool:
	if not can_pay(cost, with_drone, cache):
		return false
	for id: String in cost:
		var remaining := int(cost[id])
		var sources := carried_sources(with_drone)
		sources.append(cache)
		for stock: Dictionary in sources:
			var take := mini(remaining, int(stock.get(id, 0)))
			if take > 0:
				stock[id] = int(stock[id]) - take
				remaining -= take
	return true

func withdraw(stock: Dictionary, id: String, amount: int, with_drone: bool) -> bool:
	if amount <= 0 or int(stock.get(id, 0)) < amount or not collect(id, amount, with_drone):
		return false
	stock[id] = int(stock[id]) - amount
	return true

func deposit(stock: Dictionary, capacity: int, with_drone: bool) -> int:
	var remaining := maxi(0, capacity - used(stock))
	var transferred := 0
	var sources := carried_sources(with_drone)
	for source: Dictionary in sources:
		for id: String in ITEM_IDS:
			var amount := mini(remaining / item_units(id), int(source.get(id, 0)))
			if amount > 0:
				stock[id] = int(stock.get(id, 0)) + amount
				source[id] = int(source[id]) - amount
				remaining -= amount * item_units(id)
				transferred += amount * item_units(id)
	return transferred

func snapshot() -> Dictionary:
	return {"backpack": backpack.duplicate(), "drone": drone.duplicate()}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("backpack") is Dictionary or not data.get("drone") is Dictionary:
		return false
	if not valid_stock(data.backpack, PACK_CAPACITY) or not valid_stock(data.drone, drone_capacity):
		return false
	if drone_only and used(data.backpack) + used(data.drone) > drone_capacity:
		return false
	backpack.clear()
	for id: String in data.backpack:
		backpack[id] = int(data.backpack[id])
	drone.clear()
	for id: String in data.drone:
		drone[id] = int(data.drone[id])
	if drone_only:
		enable_drone_only(drone_capacity)
	return true

static func valid_stock(stock: Dictionary, capacity: int) -> bool:
	var total := 0
	for id in stock:
		var value = stock[id]
		if id not in ITEM_IDS or not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > capacity:
			return false
		total += int(value) * item_units(id)
	return total <= capacity
