extends Resource

@export var tool_id := ""
@export var display_name := ""
@export var mode := "mine"
@export var required_level := 1
@export var materials: Array[String] = []
@export var power := 1
@export var reach_metres := 3.0
@export_range(1, 4, 1) var scanner_level := 1
@export var energy_per_pulse := 0.2
@export var beam_color := Color("6debdc")
@export var beam_width := 2.0

func effective_reach_metres() -> float:
	return reach_metres + clampi(scanner_level, 1, 4) - 1 if mode == "scan" else reach_metres
