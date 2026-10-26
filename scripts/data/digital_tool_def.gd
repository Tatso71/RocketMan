extends Resource

@export var tool_id := ""
@export var display_name := ""
@export var mode := "mine"
@export var required_level := 1
@export var materials: Array[String] = []
@export var power := 1
@export var reach_metres := 3.0
@export var energy_per_pulse := 0.2
@export var beam_color := Color("6debdc")
@export var beam_width := 2.0
