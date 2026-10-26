extends RefCounted

const Catalog = preload("res://scripts/data/ocra_catalog.gd")
const Texts = preload("res://scripts/data/robbie_texts.gd")
var definition: Dictionary
var authored_texts := true
var facts: Dictionary = {}
var counters: Dictionary = {}

func _init(custom_definition: Dictionary = {}) -> void:
	definition = custom_definition if not custom_definition.is_empty() else Catalog.load_data().get("tutorial", {})
	authored_texts = custom_definition.is_empty()

func record(event: String) -> void:
	mark(event)
	var previous := int(counters.get(event, 0))
	if event == "mined":
		previous = maxi(previous, int(counters.get("mined_cells", 0)))
	counters[event] = mini(100000, previous + 1)
	if event == "mined":
		counters["mined_cells"] = counters[event]

func mark(event: String) -> void:
	facts[event] = true

func satisfied(condition: Dictionary) -> bool:
	if condition.has("fact"):
		return facts.get(condition.fact, false)
	return int(counters.get(condition.counter, 0)) >= int(condition.at_least)

func complete() -> bool:
	return not definition.is_empty() and satisfied(definition.finish_when)

func index() -> int:
	if complete() or definition.is_empty():
		return definition.get("steps", []).size()
	for position in range(definition.steps.size()):
		if not satisfied(definition.steps[position].complete_when):
			return position
	return definition.steps.size()

func current() -> Dictionary:
	var position := index()
	if position >= definition.get("steps", []).size():
		return {}
	return Texts.tutorial_step(definition.steps[position]) if authored_texts else definition.steps[position]

func message(id: String) -> Array:
	if not id.begins_with("ocra/"):
		return []
	for step: Dictionary in definition.get("steps", []):
		if id == "ocra/" + step.id:
			if authored_texts and not Texts.message(id).is_empty():
				return Texts.message(id)
			return [65, step.title_it, step.hint_it]
	return []

func snapshot() -> Dictionary:
	return {"version": 1, "facts": facts.duplicate(), "counters": counters.duplicate()}

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version", 1) != 1 or not data.get("facts", {}) is Dictionary or not data.get("counters", {}) is Dictionary:
		return false
	for key in data.get("facts", {}):
		if not (key is String or key is StringName) or str(key).is_empty() or not data.facts[key] is bool:
			return false
	for key in data.get("counters", {}):
		if not (key is String or key is StringName) or str(key).is_empty() or not Catalog.integer(data.counters[key], 0, 100000):
			return false
	facts.clear()
	for key in data.get("facts", {}):
		facts[str(key)] = data.facts[key]
	counters.clear()
	for key in data.get("counters", {}):
		counters[str(key)] = int(data.counters[key])
	if counters.has("mined_cells") or counters.has("mined"):
		var mined := maxi(int(counters.get("mined_cells", 0)), int(counters.get("mined", 0)))
		counters["mined_cells"] = mined
		counters["mined"] = mined
	return true
