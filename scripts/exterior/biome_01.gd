extends Node2D

func _ready() -> void:
	GameStateStore.register_species_scan("glowlark")
	GameStateStore.register_material("frost_shard", 2)
	GameStateStore.register_material("fiber_vine", 1)
