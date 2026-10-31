extends RefCounted

const Tutorial = preload("res://scripts/systems/ocra_tutorial.gd")
const Texts = preload("res://scripts/data/robbie_texts.gd")
const REPEATING := ["cargo_full", "drone_unavailable", "drone_delivery", "signal_limit", "build_resources", "build_space", "gas_danger", "water_danger", "oil_danger", "acid_danger", "gas_leak", "water_leak", "oil_leak", "acid_leak", "energy_low", "robot_charge_low"]
const PERSISTENT := {"tutorial_collect": 20.0, "tutorial_excavate": 20.0, "tutorial_place": 20.0, "tutorial_fund": 25.0, "water_danger": 10.0}
const FACTS := ["mined", "ladder", "lab_built", "lamp_crafted", "lamp_placed", "pump_built", "fan_built", "deposited", "furnace_built", "gas_converter_built", "greenhouse_built", "seeds_found", "seed_pod_seen"]
var seen: Array[String] = []
var facts: Dictionary = {}
var muted := false
var active_id := ""
var remaining := 0.0
var elapsed := 0.0
var gap := 1.0
var context_id := ""
var active_manual := false
var last_shown: Dictionary = {}
var latched: Array[String] = []
var ocra := Tutorial.new()
var variant := "explorer"

func message(id: String) -> Array:
	return ocra.message(id, variant) if id.begins_with("ocra/") else Texts.message(id, variant)

func recurring(id: String) -> bool:
	return id in REPEATING or PERSISTENT.has(id) or id.begins_with("ocra/")

func offer(id: String, manual: bool = false) -> bool:
	var entry := message(id)
	if entry.is_empty():
		return false
	if not manual:
		if muted or (gap > 0 and int(entry[0]) < 80) or (id in seen and not recurring(id)) or id in latched:
			return false
		if elapsed - float(last_shown.get(id, -100)) < (25.0 if id.begins_with("ocra/") else float(PERSISTENT.get(id, 35))):
			return false
		if not active_id.is_empty() and int(entry[0]) <= int(message(active_id)[0]):
			return false
	active_id = id
	active_manual = manual
	remaining = clampf(float(str(entry[2]).length()) / 17.0, 8, 18)
	if id not in seen:
		seen.append(id)
	if id in REPEATING and not PERSISTENT.has(id) and id not in latched:
		latched.append(id)
	last_shown[id] = elapsed
	return true

func tick(delta: float, current_context: String) -> void:
	elapsed += delta
	gap = maxf(0, gap - delta)
	# Re-arm a recurring hint only after its actual condition has cleared.
	for id: String in latched.duplicate():
		if id != current_context and id not in ["gas_leak", "water_leak", "oil_leak", "acid_leak"]:
			latched.erase(id)
	if recurring(active_id) and active_id != current_context and not active_manual and active_id not in ["gas_leak", "water_leak", "oil_leak", "acid_leak"]:
		dismiss()
	context_id = current_context
	remaining = maxf(0, remaining - delta)
	if remaining <= 0 and not active_id.is_empty():
		dismiss()

func dismiss() -> void:
	active_id = ""
	remaining = 0
	active_manual = false
	gap = 2

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		dismiss()

func snapshot() -> Dictionary:
	return {"seen": seen.duplicate(), "facts": facts.duplicate(), "muted": muted, "ocra": ocra.snapshot()}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("seen", []) is Array or not data.get("facts", {}) is Dictionary or not data.get("muted", false) is bool:
		return false
	var next_tutorial := Tutorial.new()
	if not next_tutorial.restore(data.get("ocra", {})):
		return false
	for id in data.get("seen", []):
		if not id is String or message(id).is_empty():
			return false
	for fact in data.get("facts", {}):
		if fact not in FACTS or not data.facts[fact] is bool:
			return false
	seen.assign(data.get("seen", []))
	facts = data.get("facts", {}).duplicate()
	ocra.restore(next_tutorial.snapshot())
	muted = data.get("muted", false)
	active_id = ""
	remaining = 0
	gap = 1
	latched.clear()
	last_shown.clear()
	return true
