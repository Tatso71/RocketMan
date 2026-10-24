extends RefCounted

const Definition = preload("res://scripts/data/digital_tool_def.gd")
const SLOT_COUNT := 4
static var _tools: Array = []

static func all() -> Array:
	if _tools.is_empty():
		_tools = [
			_tool("pulse", "Pulse", "mine", 1, ["soil", "stone", "copper"], 1, 3, 0.2, Color("64e5d6"), 2),
			_tool("scanner", "Scanner", "scan", 1, [], 0, 4, 0.05, Color("f1cf71"), 1),
			_tool("resonator", "Risonatore", "mine", 2, ["stone", "copper", "crystal"], 2, 3, 0.3, Color("d59beb"), 3),
			_tool("plasma", "Plasma", "mine", 3, ["soil", "stone", "copper", "crystal", "bedrock"], 5, 2.5, 0.6, Color("ef875f"), 5)
		]
	return _tools

static func find(id: String) -> Resource:
	for tool: Resource in all():
		if tool.tool_id == id:
			return tool
	return null

static func _tool(id: String, title: String, mode: String, level: int, materials: Array, power: int, reach: float, energy: float, color: Color, width: float) -> Resource:
	var tool := Definition.new()
	tool.tool_id = id
	tool.display_name = title
	tool.mode = mode
	tool.required_level = level
	tool.materials.assign(materials)
	tool.power = power
	tool.reach_metres = reach
	tool.energy_per_pulse = energy
	tool.beam_color = color
	tool.beam_width = width
	return tool
