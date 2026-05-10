extends Node2D

@onready var hatch: StaticBody2D = $HatchBiome01

func _ready() -> void:
	update_hatch_state()

func update_hatch_state() -> void:
	if GameStateStore.is_hatch_unlocked("hatch_biome_01"):
		hatch.modulate = Color(0.6, 1.0, 0.6)
	else:
		hatch.modulate = Color(1.0, 0.5, 0.5)
